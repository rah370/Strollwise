from __future__ import annotations


def _register(client):
    resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": "report@strollwise.test",
            "password": "supersecret123",
            "traveler_type": "local",
        },
    )
    assert resp.status_code == 201
    return resp.json()["access_token"]


def test_create_report_converts_latlng_into_h3(client):
    token = _register(client)
    resp = client.post(
        "/api/v1/reports",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "latitude": 10.3157,
            "longitude": 123.8854,
            "category": "food",
            "tags": ["food", "cafe"],
            "note_text": "Great spot",
        },
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["h3_index"]
    assert data["resolution"] == 8
    assert data["category"] == "food"


def test_zones_endpoint_returns_list(client):
    token = _register(client)
    # Create a couple of reports so merging has something to chew on.
    for lat in (10.3157, 10.3162, 10.3170):
        client.post(
            "/api/v1/reports",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "latitude": lat,
                "longitude": 123.8854,
                "category": "food",
                "tags": ["food", "cafe", "restaurant"],
            },
        )
    resp = client.get(
        "/api/v1/zones",
        params={
            "min_lat": 10.2,
            "min_lng": 123.8,
            "max_lat": 10.4,
            "max_lng": 124.0,
            "zoom": 14,
        },
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_report_rejects_unknown_category(client):
    token = _register(client)
    resp = client.post(
        "/api/v1/reports",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "latitude": 10.3157,
            "longitude": 123.8854,
            "category": "teleportation",
            "tags": [],
        },
    )
    assert resp.status_code == 422
