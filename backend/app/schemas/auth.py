from __future__ import annotations

from pydantic import BaseModel, EmailStr, Field

from app.schemas.user import UserPublic


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, max_length=120)
    traveler_type: str = Field(default="mixed")
    nationality: str | None = Field(default=None, max_length=8)
    age_range: str | None = Field(default=None, max_length=16)
    accepted_research_consent: bool = False


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserPublic
