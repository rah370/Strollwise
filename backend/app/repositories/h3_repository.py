from __future__ import annotations

from collections.abc import Iterable

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.h3_cell_aggregate import H3CellAggregate


class H3Repository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get(self, h3_index: str) -> H3CellAggregate | None:
        return self.db.get(H3CellAggregate, h3_index)

    def upsert(self, cell: H3CellAggregate) -> H3CellAggregate:
        self.db.merge(cell)
        self.db.flush()
        return cell

    def list_all_active(self) -> list[H3CellAggregate]:
        stmt = select(H3CellAggregate).where(H3CellAggregate.report_count > 0)
        return list(self.db.execute(stmt).scalars())

    def list_by_indexes(self, h3_indexes: Iterable[str]) -> list[H3CellAggregate]:
        idxs = list(h3_indexes)
        if not idxs:
            return []
        stmt = select(H3CellAggregate).where(H3CellAggregate.h3_index.in_(idxs))
        return list(self.db.execute(stmt).scalars())
