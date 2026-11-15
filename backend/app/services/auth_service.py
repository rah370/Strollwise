"""Register, login, and password reset for travelers and researchers.

Same user table for both apps. Forgot-password always returns a generic
message so emails cannot be enumerated. The 6-digit code is hashed at rest;
it is echoed in JSON only when `password_reset_echo_code` is on (local tests).
"""
from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import create_access_token, hash_password, verify_password
from app.models.password_reset import PasswordResetToken
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.auth import (
    ForgotPasswordResponse,
    LoginRequest,
    RegisterRequest,
    ResetPasswordResponse,
    TokenResponse,
)
from app.schemas.user import UserPublic
from app.services.mailer import mail_configured, send_password_reset_code
from app.utils.user_type_utils import apply_user_type_to_user

_GENERIC_FORGOT_MESSAGE = (
    "If that email is registered, we sent a 6-digit reset code. "
    "It expires in 15 minutes."
)


class AuthError(Exception):
    """Authentication or registration failure."""


class AuthService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.users = UserRepository(db)

    def register(self, payload: RegisterRequest) -> TokenResponse:
        email = payload.email.lower()
        if self.users.get_by_email(email) is not None:
            raise AuthError("Email already registered")
        user = User(
            email=email,
            password_hash=hash_password(payload.password),
            display_name=payload.display_name,
            country_of_origin=payload.country_of_origin,
            city_of_origin=payload.city_of_origin,
            user_type=payload.user_type,
            traveler_type="mixed",
            nationality=payload.nationality,
            age_range=payload.age_range,
            accepted_research_consent=payload.accepted_research_consent,
            accepted_privacy_terms_at=(
                datetime.now(timezone.utc)  # noqa: UP017
                if payload.accepted_research_consent
                else None
            ),
        )
        apply_user_type_to_user(user)
        self.users.create(user)
        self.db.commit()
        self.db.refresh(user)
        return self._token_for(user)

    def login(self, payload: LoginRequest) -> TokenResponse:
        user = self.users.get_by_email(payload.email.lower())
        if user is None or not verify_password(payload.password, user.password_hash):
            raise AuthError("Invalid email or password")
        if not user.is_active:
            raise AuthError("Account disabled")
        return self._token_for(user)

    def request_password_reset(self, email: str) -> ForgotPasswordResponse:
        user = self.users.get_by_email(email.lower())
        if user is None or not user.is_active:
            return ForgotPasswordResponse(
                message=_GENERIC_FORGOT_MESSAGE,
                delivery="none",
            )
        now = datetime.now(timezone.utc)
        self.db.execute(
            update(PasswordResetToken)
            .where(
                PasswordResetToken.user_id == user.id,
                PasswordResetToken.used_at.is_(None),
            )
            .values(used_at=now)
        )
        code = f"{secrets.randbelow(1_000_000):06d}"
        token = PasswordResetToken(
            user_id=user.id,
            code_hash=self._hash_reset_code(user.email, code),
            expires_at=now + timedelta(minutes=settings.password_reset_minutes),
        )
        self.db.add(token)
        self.db.commit()
        emailed = send_password_reset_code(user.email, code)
        echo = settings.password_reset_echo_code or not mail_configured()
        return ForgotPasswordResponse(
            message=_GENERIC_FORGOT_MESSAGE
            if emailed
            else (
                "If that email is registered, use the 6-digit code to set a "
                "new password. It expires in 15 minutes."
            ),
            delivery="email" if emailed else "on_screen",
            reset_code=code if echo else None,
        )

    def reset_password(
        self, email: str, code: str, new_password: str
    ) -> ResetPasswordResponse:
        user = self.users.get_by_email(email.lower())
        if user is None or not user.is_active:
            raise AuthError("Invalid or expired reset code")
        now = datetime.now(timezone.utc)
        hashed = self._hash_reset_code(user.email, code.strip())
        stmt = (
            select(PasswordResetToken)
            .where(
                PasswordResetToken.user_id == user.id,
                PasswordResetToken.code_hash == hashed,
                PasswordResetToken.used_at.is_(None),
            )
            .order_by(PasswordResetToken.created_at.desc())
        )
        token = self.db.execute(stmt).scalars().first()
        if token is None:
            raise AuthError("Invalid or expired reset code")
        expires = token.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < now:
            raise AuthError("Invalid or expired reset code")
        token.used_at = now
        user.password_hash = hash_password(new_password)
        self.users.save(user)
        self.db.commit()
        return ResetPasswordResponse(message="Password updated. You can sign in now.")

    def _hash_reset_code(self, email: str, code: str) -> str:
        payload = f"{email.lower()}:{code.strip()}".encode()
        digest = hmac.new(
            settings.jwt_secret_key.encode(),
            payload,
            hashlib.sha256,
        ).hexdigest()
        return digest

    def _token_for(self, user: User) -> TokenResponse:
        token = create_access_token(user.id, extra_claims={"email": user.email})
        return TokenResponse(
            access_token=token,
            token_type="bearer",
            user=UserPublic.model_validate(user),
        )
