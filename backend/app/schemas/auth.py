from __future__ import annotations

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.user import UserPublic
from app.utils.user_type_utils import ALLOWED_USER_TYPES


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=120)
    country_of_origin: str = Field(min_length=1, max_length=120)
    city_of_origin: str = Field(min_length=1, max_length=120)
    user_type: str = Field(min_length=1, max_length=32)
    nationality: str | None = Field(default=None, max_length=8)
    age_range: str | None = Field(default=None, max_length=16)
    accepted_research_consent: bool = False

    @field_validator("display_name", "country_of_origin", "city_of_origin")
    @classmethod
    def strip_text(cls, v: str) -> str:
        return v.strip()

    @field_validator("accepted_research_consent")
    @classmethod
    def require_research_consent(cls, v: bool) -> bool:
        if not v:
            raise ValueError(
                "Privacy and research consent is required to create an account"
            )
        return v

    @field_validator("user_type")
    @classmethod
    def normalize_user_type(cls, v: str) -> str:
        key = v.strip().lower()
        if key not in ALLOWED_USER_TYPES:
            raise ValueError(
                "user_type must be one of: local_resident, international_visitor, "
                "domestic_traveler"
            )
        return key


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserPublic


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str
    delivery: str
    reset_code: str | None = None


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=8)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("code")
    @classmethod
    def digits_only(cls, v: str) -> str:
        raw = v.strip()
        if not raw.isdigit():
            raise ValueError("Reset code must be the 6-digit number from your email")
        return raw


class ResetPasswordResponse(BaseModel):
    message: str
