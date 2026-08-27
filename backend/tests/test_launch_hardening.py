from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.core.security import hash_password
from app.services.admin_bootstrap import ADMIN_EMAIL, ensure_admin_user
from app.services.upload_service import UploadError, UploadService


def test_validate_for_launch_rejects_default_jwt():
    settings = Settings.model_construct(
        env="production",
        debug=False,
        jwt_secret_key="change-me-in-production",
        cors_origins="https://admin.strollwise.app",
    )
    with pytest.raises(RuntimeError, match="JWT_SECRET_KEY"):
        settings.validate_for_launch()


def test_validate_for_launch_rejects_localhost_cors():
    settings = Settings.model_construct(
        env="production",
        debug=False,
        jwt_secret_key="a-sufficiently-long-production-secret",
        cors_origins="http://localhost:5173",
    )
    with pytest.raises(RuntimeError, match="CORS_ORIGINS"):
        settings.validate_for_launch()


def test_validate_for_launch_accepts_production_shape():
    settings = Settings.model_construct(
        env="production",
        debug=False,
        jwt_secret_key="a-sufficiently-long-production-secret",
        cors_origins="https://admin.strollwise.app,https://app.strollwise.app",
    )
    settings.validate_for_launch()


def test_health_includes_database(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["database"] == "ok"
    assert "redis" in body


def test_legal_pages_are_public(client):
    privacy = client.get("/privacy")
    terms = client.get("/terms")
    assert privacy.status_code == 200
    assert terms.status_code == 200
    assert "Privacy Policy" in privacy.text
    assert "Terms of Use" in terms.text


def test_docs_disabled_in_production(monkeypatch):
    from app.core import config as config_mod
    from app.main import create_app

    monkeypatch.setattr(config_mod.settings, "env", "production")
    monkeypatch.setattr(config_mod.settings, "debug", False)
    monkeypatch.setattr(
        config_mod.settings,
        "jwt_secret_key",
        "a-sufficiently-long-production-secret",
    )
    monkeypatch.setattr(
        config_mod.settings,
        "cors_origins",
        "https://admin.strollwise.app,https://app.strollwise.app",
    )
    monkeypatch.setattr(
        config_mod.settings,
        "trusted_hosts",
        "testserver,api.strollwise.app,localhost",
    )
    prod_app = create_app()
    with TestClient(prod_app, base_url="https://api.strollwise.app") as prod_client:
        assert prod_client.get("/docs").status_code == 404
        assert prod_client.get("/redoc").status_code == 404
        assert prod_client.get("/openapi.json").status_code == 404


def test_auth_rate_limit(client, monkeypatch):
    from app.core import config as config_mod
    from app.core.rate_limit import limiter

    limiter.reset()
    monkeypatch.setattr(config_mod.settings, "rate_limit_enabled", True)
    monkeypatch.setattr(config_mod.settings, "rate_limit_auth_per_minute", 2)
    payload = {"email": "limit@example.com", "password": "wrongpassword"}
    assert client.post("/api/v1/auth/login", json=payload).status_code == 401
    assert client.post("/api/v1/auth/login", json=payload).status_code == 401
    blocked = client.post("/api/v1/auth/login", json=payload)
    assert blocked.status_code == 429
    limiter.reset()


def test_ensure_admin_does_not_reset_existing_password(db_session):
    admin = ensure_admin_user(db_session)
    admin.password_hash = hash_password("already-changed-pass")
    db_session.commit()
    stored = admin.password_hash
    again = ensure_admin_user(db_session)
    assert again.email == ADMIN_EMAIL
    assert again.password_hash == stored


def test_seed_refuses_production(monkeypatch):
    import seed
    from app.core import config as config_mod

    monkeypatch.setattr(config_mod.settings, "env", "production")
    with pytest.raises(SystemExit, match="production"):
        seed.main()


@pytest.mark.asyncio
async def test_upload_requires_object_storage_in_production(monkeypatch, tmp_path):
    from app.core import config as config_mod

    monkeypatch.setattr(config_mod.settings, "env", "production")
    monkeypatch.setattr(config_mod.settings, "s3_bucket_name", None)
    monkeypatch.setattr(config_mod.settings, "s3_access_key", None)
    monkeypatch.setattr(config_mod.settings, "s3_secret_key", None)
    monkeypatch.setattr(config_mod.settings, "upload_local_dir", str(tmp_path))
    upload = MagicMock()
    upload.content_type = "image/jpeg"
    upload.filename = "shot.jpg"
    upload.read = AsyncMock(return_value=b"jpeg-bytes")
    with pytest.raises(UploadError, match="Object storage"):
        await UploadService().save(upload)


@pytest.mark.asyncio
async def test_local_upload_returns_http_path_not_file_uri(monkeypatch, tmp_path):
    from app.core import config as config_mod

    monkeypatch.setattr(config_mod.settings, "env", "development")
    monkeypatch.setattr(config_mod.settings, "s3_bucket_name", None)
    monkeypatch.setattr(config_mod.settings, "s3_access_key", None)
    monkeypatch.setattr(config_mod.settings, "s3_secret_key", None)
    monkeypatch.setattr(config_mod.settings, "public_base_url", "http://127.0.0.1:8000")
    monkeypatch.setattr(config_mod.settings, "upload_local_dir", str(tmp_path))
    upload = MagicMock()
    upload.content_type = "image/png"
    upload.filename = "shot.png"
    upload.read = AsyncMock(return_value=b"png-bytes")
    result = await UploadService().save(upload)
    assert result["file_url"].startswith("http://127.0.0.1:8000/media/")
    assert not result["file_url"].startswith("file://")
