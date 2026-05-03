"""Handles the full lifecycle of a user report submission."""
from __future__ import annotations

from uuid import UUID

from sqlalchemy.orm import Session

from app.core.cache import cache_delete_pattern
from app.core.config import settings
from app.models.enums import ReportCategory, VisibilityStatus
from app.models.media import Media
from app.models.report import Report
from app.models.user import User
from app.repositories.media_repository import MediaRepository
from app.repositories.report_repository import ReportRepository
from app.schemas.report import ReportCreate
from app.services import h3_service
from app.services.aggregation_service import AggregationService
from app.services.audit_service import AuditService
from app.services.zone_merge_service import ZoneMergeService


class ReportValidationError(Exception):
    pass


class ReportService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.reports = ReportRepository(db)
        self.media = MediaRepository(db)
        self.audit = AuditService(db)

    def create_report(self, payload: ReportCreate, user: User) -> Report:
        self._validate(payload)
        h3_index = h3_service.latlng_to_cell(
            payload.latitude, payload.longitude, settings.h3_resolution
        )
        report = Report(
            user_id=user.id,
            h3_index=h3_index,
            resolution=settings.h3_resolution,
            latitude_raw=payload.latitude,
            longitude_raw=payload.longitude,
            category=payload.category.lower(),
            tags_json=[t.lower() for t in payload.tags],
            note_text=payload.note_text,
            image_url=payload.image_url,
            source_type=payload.source_type,
            traveler_type_snapshot=user.traveler_type,
            visibility_status=VisibilityStatus.VISIBLE.value,
        )
        self.reports.create(report)
        self.db.flush()

        # Persist media row if the client attached an uploaded image.
        if payload.image_url:
            self.media.create(
                Media(
                    report_id=report.id,
                    file_url=payload.image_url,
                    mime_type=payload.image_mime_type or "image/jpeg",
                    size_bytes=payload.image_size_bytes,
                )
            )

        # Audit trail.
        self.audit.record(
            actor_user_id=user.id,
            action_type="report.create",
            entity_type="report",
            entity_id=report.id,
            payload={
                "h3_index": h3_index,
                "category": report.category,
                "tags": report.tags_json,
                "has_image": bool(payload.image_url),
            },
        )

        self.db.commit()
        self.db.refresh(report)

        # Synchronously recompute the affected cell + neighbours, then merge.
        affected = {h3_index}
        affected.update(h3_service.get_neighbors(h3_index, ring_size=1))
        AggregationService(self.db).recompute_cells(affected)
        self.db.commit()

        ZoneMergeService(self.db).recompute_near([h3_index])

        cache_delete_pattern("zones:vp:*")
        cache_delete_pattern("city:pulse:*")
        return report

    # --- helpers ---------------------------------------------------------

    @staticmethod
    def _validate(payload: ReportCreate) -> None:
        try:
            ReportCategory(payload.category.lower())
        except ValueError:
            raise ReportValidationError(
                f"Unsupported report category: {payload.category}"
            )
        if len(payload.tags) > 12:
            raise ReportValidationError("A report can include at most 12 tags")
        for tag in payload.tags:
            if len(tag) > 32:
                raise ReportValidationError("Tags must be 32 characters or fewer")

    def recent_feed(self, limit: int = 50) -> list[Report]:
        return self.reports.list_recent(limit)

    def reports_in_zone(self, zone_h3_indexes: list[str]) -> list[Report]:
        return self.reports.list_by_h3_indexes(zone_h3_indexes)

    def report_by_id(self, report_id: UUID) -> Report | None:
        return self.reports.get_by_id(report_id)
