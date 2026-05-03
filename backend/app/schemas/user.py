from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import EmailStr, Field

from app.schemas.common import ORMModel


class UserPublic(ORMModel):
    id: UUID
    email: EmailStr
    display_name: str | None = None
    traveler_type: str
    nationality: str | None = None
    age_range: str | None = None
    gender: str | None = None
    avatar_url: str | None = None
    is_admin: bool = False
    created_at: datetime


class UserUpdate(ORMModel):
    display_name: str | None = Field(default=None, max_length=120)
    traveler_type: str | None = None
    nationality: str | None = Field(default=None, max_length=8)
    age_range: str | None = Field(default=None, max_length=16)
    gender: str | None = Field(default=None, max_length=16)
    avatar_url: str | None = Field(default=None, max_length=500)
