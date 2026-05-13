from __future__ import annotations


def _register(client):
    resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": "report@example.com",
            "password": "supersecret123",
            "traveler_type": "local",
        },
    )
    assert resp.status_code == 201
    return resp.json()["access_token"]


def test_create_report_converts_latlng_into_h3(client):
    token = _register(client)
    first = client.post(
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
    assert first.status_code == 201, first.text
    # First submission stays pending; second matching report crosses threshold.
    resp = client.post(
        "/api/v1/reports",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "latitude": 10.3157,
            "longitude": 123.8854,
            "category": "food",
            "tags": ["food", "cafe"],
            "note_text": "Another confirmation",
        },
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["h3_index"]
    assert data["resolution"] == 8
    assert data["category"] == "food"
    assert data["aggregation"]["matching_count"] == 2
    assert data["aggregation"]["threshold_met"] is True
    assert data["aggregation"]["remaining_to_threshold"] == 0


def test_zones_endpoint_returns_list(client):
    token = _register(client)
    # Two matching reports in the same H3 cell trigger approval/publication.
    for lat in (10.3157, 10.31571):
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


def test_report_rejects_sensitive_area(client):
    token = _register(client)
    resp = client.post(
        "/api/v1/reports",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "latitude": 10.2968,
            "longitude": 123.8946,
            "category": "food",
            "tags": ["canteen"],
        },
    )
    assert resp.status_code == 422
    assert "sensitive" in resp.json()["detail"]


def test_report_feed_only_includes_approved_reports(client):
    token = _register(client)
    first = client.post(
        "/api/v1/reports",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "latitude": 10.3201,
            "longitude": 123.9021,
            "category": "transport",
            "tags": ["traffic"],
        },
    )
    assert first.status_code == 201
    feed = client.get("/api/v1/reports/feed")
    assert feed.status_code == 200
    assert feed.json() == []
