from __future__ import annotations


def test_register_returns_token_and_user(client):
    resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": "demo@example.com",
            "password": "supersecret123",
            "display_name": "Demo",
            "accepted_research_consent": True,
        },
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["access_token"]
    assert data["user"]["email"] == "demo@example.com"
    assert data["user"]["accepted_research_consent"] is True
    assert data["user"]["accepted_privacy_terms_at"] is not None


def test_login_flow(client):
    client.post(
        "/api/v1/auth/register",
        json={
            "email": "loginuser@example.com",
            "password": "supersecret123",
        },
    )
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "loginuser@example.com", "password": "supersecret123"},
    )
    assert login.status_code == 200
    token = login.json()["access_token"]

    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == "loginuser@example.com"


def test_login_rejects_wrong_password(client):
    client.post(
        "/api/v1/auth/register",
        json={"email": "pw@example.com", "password": "supersecret123"},
    )
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": "pw@example.com", "password": "wrongpassword"},
    )
    assert resp.status_code == 401
