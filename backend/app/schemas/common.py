from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Centroid(BaseModel):
    lat: float
    lng: float


class MessageResponse(BaseModel):
    message: str
    data: dict[str, Any] | None = None
