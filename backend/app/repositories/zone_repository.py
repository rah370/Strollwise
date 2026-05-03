from __future__ import annotations

import logging
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.models.merged_zone import MergedZone
from app.models.saved_zone import SavedZone
from app.models.zone_snapshot import ZoneSnapshot

log = logging.getLogger(__name__)


class ZoneRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_active(self) -> list[MergedZone]:
        stmt = select(MergedZone).where(MergedZone.is_active.is_(True))
        return list(self.db.execute(stmt).scalars())

    def list_active_in_bbox(
        self,
        min_lat: float,
        min_lng: float,
        max_lat: float,
        max_lng: float,
    ) -> list[MergedZone] | None:
        """Spatial lookup using PostGIS ST_Intersects.

        Returns None if the backing database doesn't support PostGIS (e.g.
        the SQLite test harness) so the caller can fall back to Python
        filtering.
        """
        envelope = func.ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)
        stmt = (
            select(MergedZone)
            .where(
                MergedZone.is_active.is_(True),
                MergedZone.polygon_geometry.is_not(None),
                func.ST_Intersects(MergedZone.polygon_geometry, envelope),
            )
        )
        try:
            return list(self.db.execute(stmt).scalars())
        except SQLAlchemyError as exc:
            log.debug("PostGIS viewport query unavailable, falling back: %s", exc)
            self.db.rollback()
            return None

    def list_by_slug(self, slug: str) -> MergedZone | None:
        stmt = select(MergedZone).where(MergedZone.slug == slug)
        return self.db.execute(stmt).scalar_one_or_none()

    def get(self, zone_id: UUID) -> MergedZone | None:
        return self.db.get(MergedZone, zone_id)

    def upsert(self, zone: MergedZone) -> MergedZone:
        self.db.add(zone)
        self.db.flush()
        return zone

    def delete(self, zone: MergedZone) -> None:
        self.db.delete(zone)

    def list_snapshots(self, zone_id: UUID, limit: int = 90) -> list[ZoneSnapshot]:
        stmt = (
            select(ZoneSnapshot)
            .where(ZoneSnapshot.zone_id == zone_id)
            .order_by(ZoneSnapshot.snapshot_date.desc())
            .limit(limit)
        )
        return list(self.db.execute(stmt).scalars())

    def add_snapshot(self, snapshot: ZoneSnapshot) -> ZoneSnapshot:
        self.db.add(snapshot)
        self.db.flush()
        return snapshot

    def list_saved_by_user(self, user_id: UUID) -> list[SavedZone]:
        stmt = select(SavedZone).where(SavedZone.user_id == user_id)
        return list(self.db.execute(stmt).scalars())

    def find_saved(self, user_id: UUID, zone_id: UUID) -> SavedZone | None:
        stmt = select(SavedZone).where(
            SavedZone.user_id == user_id, SavedZone.zone_id == zone_id
        )
        return self.db.execute(stmt).scalar_one_or_none()

    def save_zone(self, user_id: UUID, zone_id: UUID) -> SavedZone:
        saved = SavedZone(user_id=user_id, zone_id=zone_id)
        self.db.add(saved)
        self.db.flush()
        return saved

    def unsave_zone(self, saved: SavedZone) -> None:
        self.db.delete(saved)
