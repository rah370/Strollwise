from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.repositories.zone_repository import ZoneRepository
from app.schemas.common import Centroid, MessageResponse
from app.schemas.user import UserPublic, UserUpdate
from app.schemas.zone import ZoneListItem
from app.services.audit_service import AuditService

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserPublic)
def get_me(current_user: User = Depends(get_current_user)) -> UserPublic:
    return UserPublic.model_validate(current_user)


@router.patch("/me", response_model=UserPublic)
def update_me(
    payload: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> UserPublic:
    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(current_user, key, value)
    UserRepository(db).save(current_user)
    db.commit()
    db.refresh(current_user)
    return UserPublic.model_validate(current_user)


@router.get("/me/saved-zones", response_model=list[ZoneListItem])
def list_saved_zones(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[ZoneListItem]:
    repo = ZoneRepository(db)
    saved = repo.list_saved_by_user(current_user.id)
    items: list[ZoneListItem] = []
    for entry in saved:
        zone = repo.get(entry.zone_id)
        if zone is None:
            continue
        items.append(_to_list_item(zone))
    return items


@router.post("/me/saved-zones/{zone_id}", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def save_zone(
    zone_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MessageResponse:
    repo = ZoneRepository(db)
    zone = repo.get(zone_id)
    if zone is None:
        raise HTTPException(status_code=404, detail="Zone not found")
    existing = repo.find_saved(current_user.id, zone_id)
    if existing is not None:
        return MessageResponse(message="Zone already saved")
    repo.save_zone(current_user.id, zone_id)
    AuditService(db).record(
        actor_user_id=current_user.id,
        action_type="saved_zone.create",
        entity_type="merged_zone",
        entity_id=zone_id,
    )
    db.commit()
    return MessageResponse(message="Zone saved")


@router.delete("/me/saved-zones/{zone_id}", response_model=MessageResponse)
def unsave_zone(
    zone_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MessageResponse:
    repo = ZoneRepository(db)
    existing = repo.find_saved(current_user.id, zone_id)
    if existing is None:
        raise HTTPException(status_code=404, detail="Saved zone not found")
    repo.unsave_zone(existing)
    AuditService(db).record(
        actor_user_id=current_user.id,
        action_type="saved_zone.delete",
        entity_type="merged_zone",
        entity_id=zone_id,
    )
    db.commit()
    return MessageResponse(message="Zone removed from saved list")


def _to_list_item(zone) -> ZoneListItem:
    return ZoneListItem(
        zone_id=zone.zone_id,
        display_name=zone.display_name,
        behavior_type=zone.behavior_type,
        function_type=zone.function_type,
        summary=zone.summary,
        live_status=zone.live_status,
        polygon_geojson=zone.polygon_geojson,
        centroid=Centroid(lat=zone.centroid_lat, lng=zone.centroid_lng),
        crowd_level=zone.crowd_level,
        local_presence_percent=zone.local_presence_percent,
        peak_time_label=zone.peak_time_label,
        confidence_score=zone.confidence_score,
        priority_score=zone.priority_score,
    )
