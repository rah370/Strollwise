from __future__ import annotations

from collections.abc import Iterable
from uuid import UUID

from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.models.report import Report


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
