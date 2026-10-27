from __future__ import annotations

from datetime import date, datetime, time
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_admin
from app.core.database import get_db
from app.models.user import User
from app.schemas.admin import AdminAuditListResponse
from app.services.admin_service import AdminService

router = APIRouter(prefix="/audit", tags=["admin"])
_MANILA = ZoneInfo("Asia/Manila")


def _day_bound(value: date | None, *, end: bool) -> datetime | None:
    if value is None:
        return None
    clock = time.max if end else time.min
    return datetime.combine(value, clock, tzinfo=_MANILA)


@router.get("", response_model=AdminAuditListResponse)
def list_audit(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    action_type: str | None = Query(default=None),
    entity_type: str | None = Query(default=None),
    scope: str | None = Query(default=None),
    q: str | None = Query(default=None),
    since: date | None = Query(default=None),
    until: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> AdminAuditListResponse:
    return AdminService(db).list_audit(
        page=page,
        page_size=page_size,
        action_type=action_type,
        entity_type=entity_type,
        scope=scope,
        q=q,
        since=_day_bound(since, end=False),
        until=_day_bound(until, end=True),
    )
