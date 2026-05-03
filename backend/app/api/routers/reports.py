from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.repositories.zone_repository import ZoneRepository
from app.schemas.report import ReportCreate, ReportPublic
from app.services.report_service import ReportService, ReportValidationError

router = APIRouter(prefix="/reports", tags=["reports"])


@router.post("", response_model=ReportPublic, status_code=status.HTTP_201_CREATED)
def submit_report(
    payload: ReportCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ReportPublic:
    try:
        report = ReportService(db).create_report(payload, current_user)
    except ReportValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)
        )
    return ReportPublic.model_validate(report)


@router.get("/feed", response_model=list[ReportPublic])
def report_feed(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
) -> list[ReportPublic]:
    reports = ReportService(db).recent_feed(limit)
    return [ReportPublic.model_validate(r) for r in reports]


@router.get("/by-zone/{zone_id}", response_model=list[ReportPublic])
def reports_by_zone(
    zone_id: UUID,
    db: Session = Depends(get_db),
) -> list[ReportPublic]:
    zone = ZoneRepository(db).get(zone_id)
    if zone is None:
        raise HTTPException(status_code=404, detail="Zone not found")
    reports = ReportService(db).reports_in_zone(zone.source_h3_indexes_json or [])
    return [ReportPublic.model_validate(r) for r in reports]
