from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Report(Base):
    """One crowd-sourced tag from a signed-in traveler.

    Raw lat/lng are kept for the owner's visit history and for H3 conversion.
    Public APIs do not list other users' coordinates. `h3_index` is the spatial
    key used for aggregation. `traveler_type_snapshot` / `user_type_snapshot`
    freeze who the tagger was at submit time so later profile edits cannot
    rewrite historical mix counts.
    """

    __tablename__ = "reports"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    h3_index: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    resolution: Mapped[int] = mapped_column(Integer, nullable=False, default=8)

    latitude_raw: Mapped[float] = mapped_column(Float, nullable=False)
    longitude_raw: Mapped[float] = mapped_column(Float, nullable=False)

    category: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    tags_json: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, default=list, server_default="[]"
    )
    note_text: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    source_type: Mapped[str] = mapped_column(String(16), nullable=False, default="user")
    traveler_type_snapshot: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    user_type_snapshot: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    country_of_origin_snapshot: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    city_of_origin_snapshot: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    visibility_status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="visible", index=True
    )
    # Phone clock when the traveler tagged. Null on tags sent while online
    # before this column existed.
    client_created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # True when the phone stored the tag and uploaded it after reconnecting.
    submitted_offline: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), index=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    user = relationship("User", back_populates="reports")
    media = relationship("Media", back_populates="report", cascade="all, delete-orphan")
