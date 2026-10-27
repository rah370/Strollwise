from __future__ import annotations

from datetime import datetime

from sqlalchemy import desc, func, or_, select
from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog


class AuditRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_paginated(
        self,
        *,
        page: int = 1,
        page_size: int = 50,
        action_type: str | None = None,
        entity_type: str | None = None,
        action_types: list[str] | None = None,
        q: str | None = None,
        since: datetime | None = None,
        until: datetime | None = None,
    ) -> tuple[list[AuditLog], int]:
        stmt = select(AuditLog)
        count_stmt = select(func.count()).select_from(AuditLog)
        if action_type:
            stmt = stmt.where(AuditLog.action_type == action_type)
            count_stmt = count_stmt.where(AuditLog.action_type == action_type)
        if action_types:
            stmt = stmt.where(AuditLog.action_type.in_(action_types))
            count_stmt = count_stmt.where(AuditLog.action_type.in_(action_types))
        if entity_type:
            stmt = stmt.where(AuditLog.entity_type == entity_type)
            count_stmt = count_stmt.where(AuditLog.entity_type == entity_type)
        if q:
            pattern = f"%{q.strip()}%"
            clause = or_(
                AuditLog.action_type.ilike(pattern),
                AuditLog.entity_type.ilike(pattern),
            )
            stmt = stmt.where(clause)
            count_stmt = count_stmt.where(clause)
        if since:
            stmt = stmt.where(AuditLog.created_at >= since)
            count_stmt = count_stmt.where(AuditLog.created_at >= since)
        if until:
            stmt = stmt.where(AuditLog.created_at <= until)
            count_stmt = count_stmt.where(AuditLog.created_at <= until)
        total = int(self.db.scalar(count_stmt) or 0)
        offset = max(page - 1, 0) * page_size
        stmt = stmt.order_by(desc(AuditLog.created_at)).offset(offset).limit(page_size)
        return list(self.db.execute(stmt).scalars()), total

    def list_all(
        self,
        *,
        action_type: str | None = None,
        entity_type: str | None = None,
        limit: int = 5000,
    ) -> list[AuditLog]:
        stmt = select(AuditLog)
        if action_type:
            stmt = stmt.where(AuditLog.action_type == action_type)
        if entity_type:
            stmt = stmt.where(AuditLog.entity_type == entity_type)
        stmt = stmt.order_by(desc(AuditLog.created_at)).limit(limit)
        return list(self.db.execute(stmt).scalars())
