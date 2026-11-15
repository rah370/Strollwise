from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Float, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.merged_zone import _PostGISMultiPolygon


class Place(Base):
    """Named Cebu footprint (IT Park, Colon, Fuente, …).

    Places come from the curated catalog (`place_catalog.py`) and are filled by
    live H3 cells whose centroids fall inside the polygon. `place_type` is
    *what the area is* (food, school, commercial). Traveler mix lives on the
    zone, not here — so the map can color "who uses it" independently of type.
    """

    __tablename__ = "places"

    place_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    slug: Mapped[str] = mapped_column(String(80), nullable=False, unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(160), nullable=False)
    place_type: Mapped[str] = mapped_column(
        String(32), nullable=False, default="general", index=True
    )
    source: Mapped[str] = mapped_column(String(16), nullable=False, default="catalog")

    polygon_geojson: Mapped[dict] = mapped_column(JSONB, nullable=False)
    polygon_geometry: Mapped[Optional[object]] = mapped_column(
        _PostGISMultiPolygon(),
        nullable=True,
    )
    centroid_lat: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    centroid_lng: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)

    source_h3_indexes_json: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, default=list, server_default="[]"
    )
    report_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    confidence_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, index=True
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
