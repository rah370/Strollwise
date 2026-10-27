from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_admin
from app.core.database import get_db
from app.models.user import User
from app.schemas.admin import (
    AdminReportDetail,
    AdminReportListResponse,
    ModerationAction,
    ModerationActionRequest,
    ModerationActionResult,
    ModerationBulkRequest,
    ModerationBulkResult,
    ModerationQueueFilter,
)
from app.services.admin_moderation_service import (
    AdminModerationService,
    ModerationValidationError,
)

router = APIRouter(prefix="/moderation", tags=["admin"])


def _apply(
    db: Session,
    report_id: UUID,
    action: ModerationAction,
    admin: User,
    payload: ModerationActionRequest | None,
) -> ModerationActionResult:
    try:
        result = AdminModerationService(db).apply_action(
            report_id,
            action,
            admin,
            reason=payload.reason if payload else None,
        )
    except ModerationValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)
        ) from exc
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found")
    return result


@router.get("/reports", response_model=AdminReportListResponse)
def list_reports(
    queue: ModerationQueueFilter = Query(default=ModerationQueueFilter.PENDING),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    search: str | None = Query(default=None),
    category: str | None = Query(default=None),
    tag: str | None = Query(default=None),
    contributor_id: UUID | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> AdminReportListResponse:
    return AdminModerationService(db).list_reports(
        queue=queue,
        page=page,
        page_size=page_size,
        search=search,
        category=category,
        tag=tag,
        contributor_id=contributor_id,
    )


@router.get("/reports/{report_id}", response_model=AdminReportDetail)
def get_report(
    report_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> AdminReportDetail:
    detail = AdminModerationService(db).get_report(report_id)
    if detail is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found")
    return detail


@router.post("/reports/{report_id}/approve", response_model=ModerationActionResult)
def approve_report(
    report_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
    payload: ModerationActionRequest | None = Body(default=None),
) -> ModerationActionResult:
    return _apply(db, report_id, ModerationAction.APPROVE, admin, payload)


@router.post("/reports/{report_id}/reject", response_model=ModerationActionResult)
def reject_report(
    report_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
    payload: ModerationActionRequest | None = Body(default=None),
) -> ModerationActionResult:
    return _apply(db, report_id, ModerationAction.REJECT, admin, payload)


@router.post("/reports/{report_id}/flag", response_model=ModerationActionResult)
def flag_report(
    report_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
    payload: ModerationActionRequest | None = Body(default=None),
) -> ModerationActionResult:
    return _apply(db, report_id, ModerationAction.FLAG, admin, payload)


@router.post("/reports/bulk", response_model=ModerationBulkResult)
def bulk_moderation(
    payload: ModerationBulkRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
) -> ModerationBulkResult:
    return AdminModerationService(db).bulk_action(payload, admin)
