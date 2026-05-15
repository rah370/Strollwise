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
    # Submissions 2–5 stay below the cell threshold; the sixth matching report
    # crosses the default threshold (>5 people, same cell/category).
    for i in range(2, 6):
        mid = client.post(
            "/api/v1/reports",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "latitude": 10.3157,
                "longitude": 123.8854,
                "category": "food",
                "tags": ["food", "cafe"],
                "note_text": f"Confirmation {i}",
            },
        )
        assert mid.status_code == 201, mid.text
        body = mid.json()
        assert body["aggregation"]["matching_count"] == i
        assert body["aggregation"]["threshold_met"] is False

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
    assert data["aggregation"]["matching_count"] == 6
    assert data["aggregation"]["threshold_met"] is True
    assert data["aggregation"]["remaining_to_threshold"] == 0


def test_zones_endpoint_returns_list(client):
    token = _register(client)
    # Six matching food reports in the same H3 cell trigger approval/publication.
    for lat in (
        10.3157,
        10.31571,
        10.31572,
        10.31573,
        10.31574,
        10.31575,
    ):
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


def test_uspf_tag_triggers_single_report_approval(client):
    token = _register(client)
    lat, lng = 10.3380, 123.9010
    resp = client.post(
        "/api/v1/reports",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "latitude": lat,
            "longitude": lng,
            "category": "school",
            "tags": ["uspf campus", "school", "public", "exact_road_spot"],
        },
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["aggregation"]["threshold_met"] is True


def test_place_markers_returns_uspf_pins(client):
    token = _register(client)
    lat, lng = 10.3380, 123.9010
    assert (
        client.post(
            "/api/v1/reports",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "latitude": lat,
                "longitude": lng,
                "category": "school",
                "tags": ["uspf campus", "school", "public", "exact_road_spot"],
            },
        ).status_code
        == 201
    )
    mr = client.get(
        "/api/v1/reports/place-markers",
        params={
            "min_lat": 10.32,
            "max_lat": 10.36,
            "min_lng": 123.88,
            "max_lng": 123.92,
            "tag": "uspf",
        },
    )
    assert mr.status_code == 200
    markers = mr.json()
    assert len(markers) >= 1
    assert markers[0]["validated"] is True
    assert abs(markers[0]["latitude"] - lat) < 0.01
    assert abs(markers[0]["longitude"] - lng) < 0.01


def test_my_pending_pins_lists_only_own_pending(client):
    token = _register(client)
    lat, lng = 10.3215, 123.9012
    assert (
        client.post(
            "/api/v1/reports",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "latitude": lat,
                "longitude": lng,
                "category": "food",
                "tags": ["pending_map_test"],
            },
        ).status_code
        == 201
    )
    res = client.get(
        "/api/v1/reports/my-pending-pins",
        headers={"Authorization": f"Bearer {token}"},
        params={
            "min_lat": 10.31,
            "max_lat": 10.33,
            "min_lng": 123.89,
            "max_lng": 123.91,
        },
    )
    assert res.status_code == 200
    pins = res.json()
    assert len(pins) >= 1
    assert all(p["validated"] is False for p in pins)
    assert any(abs(float(p["latitude"]) - lat) < 0.02 for p in pins)


def test_me_contributions_reflects_submitted_reports(client):
    import uuid

    email = f"contrib_{uuid.uuid4().hex[:10]}@example.com"
    reg = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "supersecret123",
            "traveler_type": "local",
        },
    )
    assert reg.status_code == 201, reg.text
    token = reg.json()["access_token"]
    empty = client.get(
        "/api/v1/users/me/contributions",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert empty.status_code == 200
    assert empty.json()["stats"]["submitted"] == 0

    assert (
        client.post(
            "/api/v1/reports",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "latitude": 10.3157,
                "longitude": 123.8854,
                "category": "food",
                "tags": ["food", "cafe"],
            },
        ).status_code
        == 201
    )
    filled = client.get(
        "/api/v1/users/me/contributions",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert filled.status_code == 200
    body = filled.json()
    assert body["stats"]["submitted"] >= 1
    assert body["recent_reports"]
    assert body["contributor_label"]
    assert body["recent_reports"][0]["category"] == "food"
