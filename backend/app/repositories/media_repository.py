from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.media import Media


class MediaRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(self, media: Media) -> Media:
        self.db.add(media)
        self.db.flush()
        return media
