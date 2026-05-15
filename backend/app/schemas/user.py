from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import EmailStr, Field

from app.schemas.common import ORMModel
from app.schemas.report import ReportPublic


class UserPublic(ORMModel):
    id: UUID
    email: EmailStr
    display_name: str | None = None
    manual_map_lat: float | None = None
    manual_map_lng: float | None = None
    traveler_type: str
    nationality: str | None = None
    age_range: str | None = None
    gender: str | None = None
    avatar_url: str | None = None
    is_admin: bool = False
    accepted_research_consent: bool = False
    accepted_privacy_terms_at: datetime | None = None
    created_at: datetime


class UserUpdate(ORMModel):
    display_name: str | None = Field(default=None, max_length=120)
    manual_map_lat: float | None = None
    manual_map_lng: float | None = None
    traveler_type: str | None = None
    nationality: str | None = Field(default=None, max_length=8)
    age_range: str | None = Field(default=None, max_length=16)
    gender: str | None = Field(default=None, max_length=16)
    avatar_url: str | None = Field(default=None, max_length=500)


class ProfileBadge(ORMModel):
    key: str
    label: str


class UserContributionStats(ORMModel):
    submitted: int
    approved: int
    pending: int


class UserContributionsResponse(ORMModel):
    stats: UserContributionStats
    recent_reports: list[ReportPublic]
    badges: list[ProfileBadge]
    contributor_label: str
