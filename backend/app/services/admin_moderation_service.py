"""Researcher review of pending/flagged tags.

Approve/reject/flag changes `visibility_status` and can trigger the same
aggregate rebuild as auto-threshold. List payloads are privacy-safe: cell
context and counts, not a public trail of the tagger.
"""
from __future__ import annotations

import logging
from collections import Counter
from collections.abc import Iterable
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.cache import cache_delete_pattern
from app.models.enums import VisibilityStatus
from app.models.report import Report
from app.models.user import User
from app.repositories.report_repository import ReportRepository
from app.schemas.admin import (
    MODERATION_REASONS,
    AdminCellContext,
    AdminReportDetail,
    AdminReportListResponse,
    AdminReportSummary,
    ModerationAction,
    ModerationActionResult,
    ModerationBulkRequest,
    ModerationBulkResult,
    ModerationQueueFilter,
)
from app.services import h3_service
from app.services.admin_events import publish_report_event, publish_zones_updated
from app.services.aggregation_service import AggregationService
from app.services.audit_service import AuditService
from app.services.place_service import PlaceService
from app.services.report_service import _distinct_contributors
from app.services.system_settings_service import SystemSettingsService
from app.services.zone_merge_service import ZoneMergeService

log = logging.getLogger(__name__)

_ACTIONS_NEEDING_REASON = {ModerationAction.REJECT, ModerationAction.FLAG}
# Derived queues used to scan 500 pending rows and then run 3+ queries per
# row. That hung behind Render's proxy timeout, so the admin UI stayed on
# "Loading…". Cap the scan; batching below keeps a page to a few round-trips.
_SPECIAL_QUEUE_SCAN = 150


class ModerationValidationError(Exception):
    pass


class AdminModerationService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.reports = ReportRepository(db)
        self.audit = AuditService(db)
        self.cfg = SystemSettingsService(db).get_effective_settings()
        self._cell_ctx_cache: dict[str, AdminCellContext] = {}
        self._contributor_label_cache: dict[UUID, str] = {}

    def list_reports(
        self,
        *,
        queue: ModerationQueueFilter = ModerationQueueFilter.PENDING,
        page: int = 1,
        page_size: int = 50,
        search: str | None = None,
        category: str | None = None,
        tag: str | None = None,
        contributor_id: UUID | None = None,
    ) -> AdminReportListResponse:
        location_h3s = self._h3_indexes_for_place_search(search)
        if queue == ModerationQueueFilter.DUPLICATES:
            items = self._filter_summaries(
                self._list_duplicates(page=1, page_size=_SPECIAL_QUEUE_SCAN),
                search=search,
                category=category,
                tag=tag,
                contributor_id=contributor_id,
            )
            start = max(page - 1, 0) * page_size
            return AdminReportListResponse(
                items=items[start : start + page_size],
                total=len(items),
                page=page,
                page_size=page_size,
            )
        if queue == ModerationQueueFilter.NEAR_THRESHOLD:
            items = self._filter_summaries(
                self._list_near_threshold(page=1, page_size=_SPECIAL_QUEUE_SCAN),
                search=search,
                category=category,
                tag=tag,
                contributor_id=contributor_id,
            )
            start = max(page - 1, 0) * page_size
            return AdminReportListResponse(
                items=items[start : start + page_size],
                total=len(items),
                page=page,
                page_size=page_size,
            )
        if queue == ModerationQueueFilter.MIXED_AGREEMENT:
            items = self._filter_summaries(
                self._list_mixed_agreement(page=1, page_size=_SPECIAL_QUEUE_SCAN),
                search=search,
                category=category,
                tag=tag,
                contributor_id=contributor_id,
            )
            start = max(page - 1, 0) * page_size
            return AdminReportListResponse(
                items=items[start : start + page_size],
                total=len(items),
                page=page,
                page_size=page_size,
            )

        status = None if queue == ModerationQueueFilter.ALL else queue.value
        rows, total = self.reports.list_admin(
            visibility_status=status,
            page=page,
            page_size=page_size,
            search=search,
            category=category,
            tag=tag,
            location_h3_indexes=location_h3s,
            user_id=contributor_id,
        )
        return AdminReportListResponse(
            items=self._summaries_for_reports(rows),
            total=total,
            page=page,
            page_size=page_size,
        )

    def get_report(self, report_id: UUID) -> AdminReportDetail | None:
        report = self.reports.get_by_id(report_id)
        if report is None:
            return None
        summary = self._to_summary(report)
        ctx = self._cell_context(report.h3_index)
        return AdminReportDetail(**summary.model_dump(), cell_context=ctx)

    def apply_action(
        self,
        report_id: UUID,
        action: ModerationAction,
        admin: User,
        *,
        reason: str | None = None,
        require_high_agreement: bool = False,
    ) -> ModerationActionResult | None:
        report = self.reports.get_by_id(report_id)
        if report is None:
            return None

        if action in _ACTIONS_NEEDING_REASON:
            # Hold/reject must name why so the audit log and traveler
            # "removed" status are not a silent delete. The admin UI has to
            # collect this before POST — an empty body is a 422, not a reject.
            if reason not in MODERATION_REASONS:
                raise ModerationValidationError(
                    "Choose a reason: wrong location, wrong kind, spam, sensitive, or other."
                )

        pipeline_triggered = False
        if action == ModerationAction.APPROVE:
            if require_high_agreement:
                ctx = self._cell_context(report.h3_index)
                if ctx.category_agreement < self.cfg.pending_agreement_ratio:
                    raise ModerationValidationError(
                        "Bulk publish is only for areas where people already agree."
                    )
            report.visibility_status = VisibilityStatus.VISIBLE.value
            audit_action = "report.admin_approve"
        elif action == ModerationAction.REJECT:
            report.visibility_status = VisibilityStatus.REMOVED.value
            audit_action = "report.admin_reject"
        elif action == ModerationAction.FLAG:
            report.visibility_status = VisibilityStatus.FLAGGED.value
            audit_action = "report.admin_flag"
        else:
            report.visibility_status = VisibilityStatus.PENDING.value
            audit_action = "report.admin_keep_pending"

        self.db.commit()
        self.db.refresh(report)

        self.audit.record(
            actor_user_id=admin.id,
            action_type=audit_action,
            entity_type="report",
            entity_id=report.id,
            payload={
                "h3_index": report.h3_index,
                "category": report.category,
                "tags": list(report.tags_json or []),
                "visibility_status": report.visibility_status,
                "reason": reason,
            },
        )
        self.db.commit()

        if action == ModerationAction.APPROVE:
            pipeline_triggered = self._run_pipeline(report.h3_index)
            publish_report_event("approved", report_id=str(report.id), h3_index=report.h3_index)
            publish_zones_updated(source="admin_moderation")
        elif action in (ModerationAction.REJECT, ModerationAction.FLAG):
            event = "rejected" if action == ModerationAction.REJECT else "flagged"
            publish_report_event(event, report_id=str(report.id), h3_index=report.h3_index)

        return ModerationActionResult(
            report=self._to_summary(report),
            cell_context=self._cell_context(report.h3_index),
            pipeline_triggered=pipeline_triggered,
        )

    def bulk_action(
        self,
        payload: ModerationBulkRequest,
        admin: User,
    ) -> ModerationBulkResult:
        updated = 0
        failed: list[UUID] = []
        for report_id in payload.report_ids:
            try:
                result = self.apply_action(
                    report_id,
                    payload.action,
                    admin,
                    reason=payload.reason,
                    require_high_agreement=payload.action == ModerationAction.APPROVE,
                )
            except ModerationValidationError:
                failed.append(report_id)
                continue
            if result is None:
                failed.append(report_id)
            else:
                updated += 1
        return ModerationBulkResult(updated=updated, failed=failed)

    def _to_summary(self, report: Report) -> AdminReportSummary:
        summaries = self._summaries_for_reports([report])
        return summaries[0]

    def _summaries_for_reports(self, reports: list[Report]) -> list[AdminReportSummary]:
        if not reports:
            return []
        h3s = list(dict.fromkeys(r.h3_index for r in reports))
        contexts = self._cell_contexts_for(h3s)
        duplicate_counts = self._duplicate_counts_for(reports)
        labels = self._contributor_labels_for(r.user_id for r in reports)
        items: list[AdminReportSummary] = []
        for report in reports:
            ctx = contexts.get(report.h3_index, self._empty_cell_context(report.h3_index))
            items.append(
                AdminReportSummary(
                    id=report.id,
                    h3_index=report.h3_index,
                    category=report.category,
                    tags=list(report.tags_json or []),
                    note_text=report.note_text,
                    visibility_status=report.visibility_status,
                    confidence_score=round(ctx.category_agreement * 100, 1),
                    contributor_count=ctx.distinct_contributors,
                    duplicate_count=duplicate_counts.get(report.id, 0),
                    created_at=report.created_at,
                    image_url=report.image_url,
                    area_name=self._area_name(report.h3_index),
                    contributor_id=report.user_id,
                    contributor_label=labels.get(report.user_id, "Traveler")
                    if report.user_id
                    else "Traveler",
                )
            )
        return items

    def _empty_cell_context(self, h3_index: str) -> AdminCellContext:
        threshold = max(self.cfg.pending_min_reports_per_cell, 1)
        return AdminCellContext(
            h3_index=h3_index,
            pending_count=0,
            visible_count=0,
            flagged_count=0,
            distinct_contributors=0,
            top_category=None,
            category_agreement=0.0,
            threshold=threshold,
            threshold_met=False,
        )

    def _cell_context(self, h3_index: str) -> AdminCellContext:
        return self._cell_contexts_for([h3_index]).get(
            h3_index, self._empty_cell_context(h3_index)
        )

    def _cell_contexts_for(self, h3_indexes: list[str]) -> dict[str, AdminCellContext]:
        cells = list(dict.fromkeys(idx for idx in h3_indexes if idx))
        missing = [h3 for h3 in cells if h3 not in self._cell_ctx_cache]
        if missing:
            grouped: dict[str, list[Report]] = {h3: [] for h3 in missing}
            for report in self.reports.list_by_h3_indexes_for_admin(missing):
                grouped.setdefault(report.h3_index, []).append(report)
            threshold = max(self.cfg.pending_min_reports_per_cell, 1)
            ratio = self.cfg.pending_agreement_ratio
            for h3 in missing:
                rows = grouped.get(h3, [])
                pending = [
                    r
                    for r in rows
                    if r.visibility_status == VisibilityStatus.PENDING.value
                ]
                visible_count = sum(
                    1
                    for r in rows
                    if r.visibility_status == VisibilityStatus.VISIBLE.value
                )
                flagged_count = sum(
                    1
                    for r in rows
                    if r.visibility_status == VisibilityStatus.FLAGGED.value
                )
                contributors = _distinct_contributors(pending)
                category_counts = Counter((r.category or "").lower() for r in pending)
                top_category = (
                    category_counts.most_common(1)[0][0] if category_counts else None
                )
                top_count = max(category_counts.values(), default=0)
                agreement = (top_count / len(pending)) if pending else 0.0
                self._cell_ctx_cache[h3] = AdminCellContext(
                    h3_index=h3,
                    pending_count=len(pending),
                    visible_count=visible_count,
                    flagged_count=flagged_count,
                    distinct_contributors=contributors,
                    top_category=top_category,
                    category_agreement=round(agreement, 3),
                    threshold=threshold,
                    threshold_met=contributors >= threshold and agreement >= ratio,
                )
        return {h3: self._cell_ctx_cache[h3] for h3 in cells}

    def _duplicate_counts_for(self, reports: list[Report]) -> dict[UUID, int]:
        if not reports:
            return {}
        since = datetime.now(timezone.utc) - timedelta(
            hours=max(self.cfg.report_cooldown_hours_per_cell, 24)
        )
        siblings = self.reports.list_by_h3_indexes_and_categories_since(
            (r.h3_index for r in reports),
            (r.category for r in reports),
            since,
        )
        by_key: dict[tuple[str, str], list[Report]] = {}
        for sibling in siblings:
            by_key.setdefault(
                (sibling.h3_index, (sibling.category or "").lower()), []
            ).append(sibling)
        counts: dict[UUID, int] = {}
        for report in reports:
            group = by_key.get((report.h3_index, (report.category or "").lower()), [])
            counts[report.id] = sum(1 for sibling in group if sibling.id != report.id)
        return counts

    def _list_duplicates(self, *, page: int, page_size: int) -> list[AdminReportSummary]:
        rows, _ = self.reports.list_admin(
            visibility_status=VisibilityStatus.PENDING.value,
            page=1,
            page_size=page_size,
        )
        out = [s for s in self._summaries_for_reports(rows) if s.duplicate_count >= 1]
        start = max(page - 1, 0) * page_size
        return out[start : start + page_size]

    def _list_near_threshold(self, *, page: int, page_size: int) -> list[AdminReportSummary]:
        threshold = max(self.cfg.pending_min_reports_per_cell, 1)
        cells = self.reports.list_near_threshold_cells(threshold, limit=80)
        if not cells:
            return []
        pending = [
            r
            for r in self.reports.list_by_h3_indexes_for_admin(cells)
            if r.visibility_status == VisibilityStatus.PENDING.value
        ]
        out = self._summaries_for_reports(pending)
        start = max(page - 1, 0) * page_size
        return out[start : start + page_size]

    def _list_mixed_agreement(self, *, page: int, page_size: int) -> list[AdminReportSummary]:
        rows, _ = self.reports.list_admin(
            visibility_status=VisibilityStatus.PENDING.value,
            page=1,
            page_size=page_size,
        )
        ratio_pct = self.cfg.pending_agreement_ratio * 100
        out = [
            s
            for s in self._summaries_for_reports(rows)
            if s.confidence_score < ratio_pct
        ]
        start = max(page - 1, 0) * page_size
        return out[start : start + page_size]

    def _contributor_label(self, user_id: UUID | None) -> str:
        if user_id is None:
            return "Traveler"
        return self._contributor_labels_for([user_id]).get(user_id, "Traveler")

    def _contributor_labels_for(self, user_ids: Iterable[UUID | None]) -> dict[UUID, str]:
        ids = list(dict.fromkeys(uid for uid in user_ids if uid is not None))
        missing = [uid for uid in ids if uid not in self._contributor_label_cache]
        if missing:
            from app.repositories.user_repository import UserRepository

            users = UserRepository(self.db).get_by_ids(missing)
            for uid in missing:
                user = users.get(uid)
                name = (user.display_name or "").strip() if user else ""
                self._contributor_label_cache[uid] = name or "Traveler"
        return {uid: self._contributor_label_cache[uid] for uid in ids}

    def _area_names(self) -> dict[str, str]:
        cached = getattr(self, "_area_name_cache", None)
        if cached is not None:
            return cached
        from sqlalchemy import select
        from sqlalchemy.orm import load_only

        from app.models.merged_zone import MergedZone
        from app.models.place import Place

        names: dict[str, str] = {}
        zones = list(
            self.db.execute(
                select(MergedZone).options(
                    load_only(
                        MergedZone.display_name, MergedZone.source_h3_indexes_json
                    )
                )
            ).scalars()
        )
        for zone in zones:
            for idx in zone.source_h3_indexes_json or []:
                names.setdefault(idx, zone.display_name)
        places = list(
            self.db.execute(
                select(Place)
                .where(Place.is_active.is_(True), Place.report_count > 0)
                .options(
                    load_only(Place.display_name, Place.source_h3_indexes_json)
                )
            ).scalars()
        )
        for place in places:
            for idx in place.source_h3_indexes_json or []:
                names.setdefault(idx, place.display_name)
        self._area_name_cache = names
        return names

    def _area_name(self, h3_index: str) -> str | None:
        return self._area_names().get(h3_index)

    def _h3_indexes_for_place_search(self, search: str | None) -> list[str]:
        if not search or not search.strip():
            return []
        needle = search.strip().lower()
        return [
            idx
            for idx, name in self._area_names().items()
            if needle in name.lower()
        ]

    def _filter_summaries(
        self,
        items: list[AdminReportSummary],
        *,
        search: str | None,
        category: str | None,
        tag: str | None,
        contributor_id: UUID | None = None,
    ) -> list[AdminReportSummary]:
        rows = items
        if contributor_id:
            rows = [r for r in rows if r.contributor_id == contributor_id]
        if category:
            rows = [r for r in rows if r.category == category.lower()]
        if tag:
            needle = tag.lower()
            rows = [r for r in rows if any(needle in t.lower() for t in r.tags)]
        if search:
            q = search.lower()
            rows = [
                r
                for r in rows
                if q in r.category
                or q in r.h3_index.lower()
                or q in (r.note_text or "").lower()
                or q in (r.area_name or "").lower()
                or any(q in t.lower() for t in r.tags)
            ]
        return rows

    def _run_pipeline(self, h3_index: str) -> bool:
        affected = {h3_index}
        affected.update(h3_service.get_neighbors(h3_index, ring_size=1))
        try:
            AggregationService(self.db).recompute_cells(affected)
            self.db.commit()
            places = PlaceService(self.db).rebuild_places_for_cells(affected)
            place_ids = [p.place_id for p in places]
            ZoneMergeService(self.db).recompute_for_places(place_ids)
            self.db.commit()
            cache_delete_pattern("zones:vp:*")
            cache_delete_pattern("zones:feed*")
            cache_delete_pattern("city:pulse:*")
            cache_delete_pattern(f"reports:pending:{h3_index}")
            return True
        except Exception:
            log.exception("Admin pipeline failed for h3_index=%s", h3_index)
            self.db.rollback()
            return False
