from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.core.security import verify_password
from app.models.password_reset import PasswordResetToken
from app.models.user import User
from app.repositories.user_repository import UserRepository


def _register(client, email: str, password: str = "supersecret123"):
    return client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "display_name": "Reset User",
            "country_of_origin": "Philippines",
            "city_of_origin": "Cebu City",
            "user_type": "local_resident",
            "accepted_research_consent": True,
        },
    )


def test_forgot_password_unknown_email_is_generic(client):
    resp = client.post(
        "/api/v1/auth/forgot-password",
        json={"email": "nobody@example.com"},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert "reset code" in data["message"].lower()
    assert data.get("reset_code") is None


def test_forgot_and_reset_password_recovers_account(client, db_session, monkeypatch):
    monkeypatch.setattr(
        "app.services.auth_service.send_password_reset_code",
        lambda email, code: False,
    )
    email = "recover@example.com"
    assert _register(client, email).status_code == 201

    forgot = client.post("/api/v1/auth/forgot-password", json={"email": email})
    assert forgot.status_code == 200, forgot.text
    code = forgot.json()["reset_code"]
    assert code and len(code) == 6

    old_login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "newpass999"},
    )
    assert old_login.status_code == 401

    reset = client.post(
        "/api/v1/auth/reset-password",
        json={"email": email, "code": code, "new_password": "newpass999"},
    )
    assert reset.status_code == 200, reset.text

    login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "newpass999"},
    )
    assert login.status_code == 200, login.text
    assert login.json()["access_token"]

    reuse = client.post(
        "/api/v1/auth/reset-password",
        json={"email": email, "code": code, "new_password": "anotherpass1"},
    )
    assert reuse.status_code == 400


def test_reset_rejects_wrong_code(client, monkeypatch):
    monkeypatch.setattr(
        "app.services.auth_service.send_password_reset_code",
        lambda email, code: False,
    )
    email = "wrongcode@example.com"
    _register(client, email)
    client.post("/api/v1/auth/forgot-password", json={"email": email})
    resp = client.post(
        "/api/v1/auth/reset-password",
        json={"email": email, "code": "000000", "new_password": "newpass999"},
    )
    assert resp.status_code == 400


def test_reset_rejects_expired_code(client, db_session, monkeypatch):
    monkeypatch.setattr(
        "app.services.auth_service.send_password_reset_code",
        lambda email, code: False,
    )
    email = "expired@example.com"
    _register(client, email)
    forgot = client.post("/api/v1/auth/forgot-password", json={"email": email})
    code = forgot.json()["reset_code"]
    token = db_session.query(PasswordResetToken).one()
    token.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
    db_session.commit()
    resp = client.post(
        "/api/v1/auth/reset-password",
        json={"email": email, "code": code, "new_password": "newpass999"},
    )
    assert resp.status_code == 400


def test_default_researcher_admin_email_can_reset(client, db_session, monkeypatch):
    from app.services.admin_bootstrap import ADMIN_EMAIL, ensure_admin_user

    monkeypatch.setattr(
        "app.services.auth_service.send_password_reset_code",
        lambda email, code: False,
    )
    ensure_admin_user(db_session, reset_password=True)

    forgot = client.post("/api/v1/auth/forgot-password", json={"email": ADMIN_EMAIL})
    assert forgot.status_code == 200, forgot.text
    code = forgot.json()["reset_code"]
    assert code and len(code) == 6

    reset = client.post(
        "/api/v1/auth/reset-password",
        json={"email": ADMIN_EMAIL, "code": code, "new_password": "console-new-pass"},
    )
    assert reset.status_code == 200, reset.text
    login = client.post(
        "/api/v1/auth/login",
        json={"email": ADMIN_EMAIL, "password": "console-new-pass"},
    )
    assert login.status_code == 200, login.text
    assert login.json()["user"]["is_admin"] is True


def test_admin_can_reset_and_keep_admin_flag(client, db_session, monkeypatch):
    monkeypatch.setattr(
        "app.services.auth_service.send_password_reset_code",
        lambda email, code: False,
    )
    email = "ops@example.com"
    _register(client, email)
    user = UserRepository(db_session).get_by_email(email)
    assert user is not None
    user.is_admin = True
    db_session.commit()

    forgot = client.post("/api/v1/auth/forgot-password", json={"email": email})
    code = forgot.json()["reset_code"]
    reset = client.post(
        "/api/v1/auth/reset-password",
        json={"email": email, "code": code, "new_password": "adminnewpass"},
    )
    assert reset.status_code == 200
    login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "adminnewpass"},
    )
    assert login.status_code == 200
    assert login.json()["user"]["is_admin"] is True
    db_session.expire_all()
    stored = db_session.get(User, user.id)
    assert stored is not None
    assert verify_password("adminnewpass", stored.password_hash)


def test_forgot_does_not_echo_code_when_email_sends(client, monkeypatch):
    monkeypatch.setattr(
        "app.services.auth_service.send_password_reset_code",
        lambda email, code: True,
    )
    monkeypatch.setattr("app.services.auth_service.mail_configured", lambda: True)
    email = "mailed@example.com"
    assert _register(client, email).status_code == 201
    forgot = client.post("/api/v1/auth/forgot-password", json={"email": email})
    assert forgot.status_code == 200, forgot.text
    data = forgot.json()
    assert data.get("reset_code") is None
    assert data["delivery"] == "email"
