from __future__ import annotations

from collections.abc import Iterable
from uuid import UUID

from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session

from app.models.report import Report


def _tag_filter_matches(tag_l: str, tags_lower: list[str]) -> bool:
    """Exact token match, or substring for tokens with length >= 3 (e.g. uspf ⊂ uspf campus)."""
    for t in tags_lower:
        if t == tag_l:
            return True
        if len(tag_l) >= 3 and tag_l in t:
            return True
    return False


class ReportRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(self, report: Report) -> Report:
        self.db.add(report)
        self.db.flush()
        return report

    def get_by_id(self, report_id: UUID) -> Report | None:
        return self.db.get(Report, report_id)

    def list_recent(self, limit: int = 50) -> list[Report]:
        stmt = (
            select(Report)
            .where(Report.visibility_status == "visible")
            .order_by(desc(Report.created_at))
            .limit(limit)
        )
        return list(self.db.execute(stmt).scalars())

    def list_by_h3_indexes(self, h3_indexes: Iterable[str]) -> list[Report]:
        h3_list = list(h3_indexes)
        if not h3_list:
            return []
        stmt = (
            select(Report)
            .where(
                Report.h3_index.in_(h3_list),
                Report.visibility_status == "visible",
            )
            .order_by(desc(Report.created_at))
        )
        return list(self.db.execute(stmt).scalars())

    def list_pending_by_h3_index(self, h3_index: str) -> list[Report]:
        stmt = (
            select(Report)
            .where(
                Report.h3_index == h3_index,
                Report.visibility_status == "pending",
            )
            .order_by(desc(Report.created_at))
        )
        return list(self.db.execute(stmt).scalars())

    def list_in_viewport_with_tag(
        self,
        min_lat: float,
        max_lat: float,
        min_lng: float,
        max_lng: float,
        tag: str,
        *,
        limit: int = 120,
        scan_cap: int = 500,
    ) -> list[Report]:
        """Reports in a lat/lng box with pending or visible status; tag matches a token or substring."""
        lo_lat, hi_lat = (min_lat, max_lat) if min_lat <= max_lat else (max_lat, min_lat)
        lo_lng, hi_lng = (min_lng, max_lng) if min_lng <= max_lng else (max_lng, min_lng)
        tag_l = tag.strip().lower()
        stmt = (
            select(Report)
            .where(
                Report.latitude_raw >= lo_lat,
                Report.latitude_raw <= hi_lat,
                Report.longitude_raw >= lo_lng,
                Report.longitude_raw <= hi_lng,
                Report.visibility_status.in_(("pending", "visible")),
            )
            .order_by(desc(Report.created_at))
            .limit(scan_cap)
        )
        rows = list(self.db.execute(stmt).scalars())
        out: list[Report] = []
        for report in rows:
            tags = [str(t).lower() for t in (report.tags_json or [])]
            if _tag_filter_matches(tag_l, tags):
                out.append(report)
            if len(out) >= limit:
                break
        return out

    def list_for_user(self, user_id: UUID, *, limit: int = 20) -> list[Report]:
        stmt = (
            select(Report)
            .where(Report.user_id == user_id)
            .order_by(desc(Report.created_at))
            .limit(limit)
        )
        return list(self.db.execute(stmt).scalars())

    def count_grouped_by_visibility(self, user_id: UUID) -> dict[str, int]:
        stmt = (
            select(Report.visibility_status, func.count())
            .where(Report.user_id == user_id)
            .group_by(Report.visibility_status)
        )
        rows = self.db.execute(stmt).all()
        return {str(status): int(c) for status, c in rows}

    def count_visible_in_category(self, user_id: UUID, category: str) -> int:
        cat = category.strip().lower()
        stmt = select(func.count()).select_from(Report).where(
            Report.user_id == user_id,
            Report.visibility_status == "visible",
            Report.category == cat,
        )
        return int(self.db.scalar(stmt) or 0)

    def list_own_pending_in_viewport(
        self,
        user_id: UUID,
        min_lat: float,
        max_lat: float,
        min_lng: float,
        max_lng: float,
        *,
        limit: int = 80,
    ) -> list[Report]:
        """Pending reports by this user in a lat/lng box (private draft pins on map)."""
        lo_lat, hi_lat = (min_lat, max_lat) if min_lat <= max_lat else (max_lat, min_lat)
        lo_lng, hi_lng = (min_lng, max_lng) if min_lng <= max_lng else (max_lng, min_lng)
        stmt = (
            select(Report)
            .where(
                Report.user_id == user_id,
                Report.visibility_status == "pending",
                Report.latitude_raw >= lo_lat,
                Report.latitude_raw <= hi_lat,
                Report.longitude_raw >= lo_lng,
                Report.longitude_raw <= hi_lng,
            )
            .order_by(desc(Report.created_at))
            .limit(limit)
        )
        return list(self.db.execute(stmt).scalars())
