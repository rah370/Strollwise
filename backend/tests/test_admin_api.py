from __future__ import annotations

from uuid import UUID

import pytest

from app.core.security import hash_password
from app.models.enums import VisibilityStatus
from app.models.report import Report
from app.models.user import User
from app.utils.user_type_utils import apply_user_type_to_user


def _register(client, email: str, **overrides):
    body = {
        "email": email,
        "password": "supersecret123",
        "display_name": "Test User",
        "country_of_origin": "Philippines",
        "city_of_origin": "Cebu City",
        "user_type": "local_resident",
        "accepted_research_consent": True,
    }
    body.update(overrides)
    return client.post("/api/v1/auth/register", json=body)


def _make_admin(db_session, email: str = "admin@test.com") -> User:
    from app.repositories.user_repository import UserRepository

    existing = UserRepository(db_session).get_by_email(email)
    if existing is not None:
        existing.is_admin = True
        db_session.commit()
        db_session.refresh(existing)
        return existing
    user = User(
        email=email,
        password_hash=hash_password("supersecret123"),
        display_name="Admin",
        traveler_type="local",
        user_type="local_resident",
        is_admin=True,
        accepted_research_consent=True,
    )
    apply_user_type_to_user(user)
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _admin_headers(client, db_session, email: str = "admin@test.com") -> dict[str, str]:
    _make_admin(db_session, email)
    login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "supersecret123"},
    )
    token = login.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _user_headers(client, email: str = "user@test.com") -> dict[str, str]:
    _register(client, email)
    login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "supersecret123"},
    )
    token = login.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _pending_report(db_session, user_id: UUID, h3_index: str = "8828308281fffff") -> Report:
    report = Report(
        user_id=user_id,
        h3_index=h3_index,
        resolution=8,
        latitude_raw=10.31,
        longitude_raw=123.89,
        category="food",
        tags_json=["good food"],
        visibility_status=VisibilityStatus.PENDING.value,
    )
    db_session.add(report)
    db_session.commit()
    db_session.refresh(report)
    return report


def test_non_admin_forbidden(client, db_session):
    headers = _user_headers(client)
    resp = client.get("/api/v1/admin/moderation/reports", headers=headers)
    assert resp.status_code == 403


def test_admin_openapi_schema_requires_admin(client, db_session):
    denied = client.get("/api/v1/admin/openapi.json")
    assert denied.status_code == 401
    traveler = _user_headers(client, "docs-traveler@test.com")
    forbidden = client.get("/api/v1/admin/openapi.json", headers=traveler)
    assert forbidden.status_code == 403
    headers = _admin_headers(client, db_session, "docs-admin@test.com")
    schema = client.get("/api/v1/admin/openapi.json", headers=headers)
    assert schema.status_code == 200
    body = schema.json()
    assert body["info"]["title"]
    assert "/api/v1/reports" in body["paths"]
    ui = client.get("/api/v1/admin/docs", headers=headers)
    assert ui.status_code == 200
    assert "swagger" in ui.text.lower()


def test_admin_lists_pending_reports(client, db_session):
    admin = _make_admin(db_session)
    _pending_report(db_session, admin.id)
    headers = _admin_headers(client, db_session, admin.email)
    resp = client.get("/api/v1/admin/moderation/reports", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1
    item = data["items"][0]
    assert "h3_index" in item
    assert "latitude_raw" not in item
    assert "user_id" not in item


def test_admin_approve_creates_audit_log(client, db_session):
    admin = _make_admin(db_session, "admin-approve@test.com")
    report = _pending_report(db_session, admin.id)
    headers = _admin_headers(client, db_session, admin.email)
    resp = client.post(
        f"/api/v1/admin/moderation/reports/{report.id}/approve",
        headers=headers,
    )
    assert resp.status_code == 200
    assert resp.json()["report"]["visibility_status"] == "visible"

    audit = client.get("/api/v1/admin/audit", headers=headers)
    assert audit.status_code == 200
    actions = [e["action_type"] for e in audit.json()["items"]]
    assert "report.admin_approve" in actions


def test_admin_reject_and_flag(client, db_session):
    admin = _make_admin(db_session, "admin-flag@test.com")
    report = _pending_report(db_session, admin.id, h3_index="8828308283fffff")
    headers = _admin_headers(client, db_session, admin.email)

    missing = client.post(
        f"/api/v1/admin/moderation/reports/{report.id}/reject",
        headers=headers,
    )
    assert missing.status_code == 422

    reject = client.post(
        f"/api/v1/admin/moderation/reports/{report.id}/reject",
        headers=headers,
        json={"reason": "wrong_location"},
    )
    assert reject.status_code == 200
    assert reject.json()["report"]["visibility_status"] == "removed"

    report2 = _pending_report(db_session, admin.id, h3_index="8828308285fffff")
    flag = client.post(
        f"/api/v1/admin/moderation/reports/{report2.id}/flag",
        headers=headers,
        json={"reason": "sensitive"},
    )
    assert flag.status_code == 200
    assert flag.json()["report"]["visibility_status"] == "flagged"


def test_admin_queue_has_contributor_label_not_email(client, db_session):
    admin = _make_admin(db_session, "admin-queue@test.com")
    _pending_report(db_session, admin.id)
    headers = _admin_headers(client, db_session, admin.email)
    resp = client.get("/api/v1/admin/moderation/reports?queue=pending", headers=headers)
    assert resp.status_code == 200
    item = resp.json()["items"][0]
    assert "email" not in item
    assert "user_id" not in item
    assert item["contributor_id"] == str(admin.id)
    assert item["contributor_label"] == "Admin"


def test_admin_pause_account_writes_audit(client, db_session):
    admin = _make_admin(db_session, "admin-pause@test.com")
    traveler = User(
        email="paused@test.com",
        password_hash=hash_password("supersecret123"),
        display_name="Traveler One",
        traveler_type="local",
        user_type="local_resident",
        is_admin=False,
        accepted_research_consent=True,
    )
    apply_user_type_to_user(traveler)
    db_session.add(traveler)
    db_session.commit()
    db_session.refresh(traveler)
    headers = _admin_headers(client, db_session, admin.email)
    resp = client.patch(
        f"/api/v1/admin/users/{traveler.id}",
        headers=headers,
        json={"is_active": False},
    )
    assert resp.status_code == 200
    assert resp.json()["is_active"] is False
    audit = client.get("/api/v1/admin/audit?scope=admin", headers=headers)
    actions = [e["action_type"] for e in audit.json()["items"]]
    assert "user.pause" in actions


def test_admin_audit_tabs_and_dates(client, db_session):
    from datetime import date

    admin = _make_admin(db_session, "admin-audit-tab@test.com")
    headers = _admin_headers(client, db_session, admin.email)
    report = _pending_report(db_session, admin.id)
    client.post(
        f"/api/v1/admin/moderation/reports/{report.id}/approve",
        headers=headers,
    )
    today = date.today().isoformat()
    travelers = client.get(
        f"/api/v1/admin/audit?scope=travelers&since={today}&until={today}",
        headers=headers,
    )
    assert travelers.status_code == 200
    decisions = client.get(
        f"/api/v1/admin/audit?scope=admin&since={today}&until={today}",
        headers=headers,
    )
    assert decisions.status_code == 200
    actions = [e["action_type"] for e in decisions.json()["items"]]
    assert "report.admin_approve" in actions
    item = next(e for e in decisions.json()["items"] if e["action_type"] == "report.admin_approve")
    assert item["result"] == "Published"
    assert item["actor_label"]
    assert "id" in item


def test_config_update_writes_audit(client, db_session):
    headers = _admin_headers(client, db_session, "admin-config-audit@test.com")
    patch = client.patch(
        "/api/v1/admin/config",
        headers=headers,
        json={"pending_min_reports_per_cell": 3},
    )
    assert patch.status_code == 200
    audit = client.get("/api/v1/admin/audit?scope=admin", headers=headers)
    assert "config.update" in [e["action_type"] for e in audit.json()["items"]]


def test_admin_config_get_and_patch(client, db_session):
    headers = _admin_headers(client, db_session)
    get_resp = client.get("/api/v1/admin/config", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["pending_min_reports_per_cell"] == 3

    patch = client.patch(
        "/api/v1/admin/config",
        headers=headers,
        json={"pending_min_reports_per_cell": 4},
    )
    assert patch.status_code == 200
    assert patch.json()["pending_min_reports_per_cell"] == 4


def test_admin_export_reports_anonymized(client, db_session):
    admin = _make_admin(db_session)
    _pending_report(db_session, admin.id)
    headers = _admin_headers(client, db_session)
    resp = client.get("/api/v1/admin/analytics/export/reports?fmt=json", headers=headers)
    assert resp.status_code == 200
    body = resp.text
    assert "latitude" not in body
    assert "email" not in body


def test_admin_dashboard_stats(client, db_session):
    headers = _admin_headers(client, db_session)
    resp = client.get("/api/v1/admin/dashboard/stats", headers=headers)
    assert resp.status_code == 200
    assert "pending_reports" in resp.json()


def test_admin_users_list(client, db_session):
    admin = _make_admin(db_session, "admin-users@test.com")
    headers = _admin_headers(client, db_session, admin.email)
    resp = client.get("/api/v1/admin/users", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["total"] >= 1
    assert "snapshot" in resp.json()
    assert resp.json()["snapshot"]["admins"] >= 1


def test_admin_users_search_by_city(client, db_session):
    _register(client, "cebu-user@test.com", city_of_origin="Cebu City")
    _register(
        client,
        "manila-user@test.com",
        city_of_origin="Manila",
        country_of_origin="Philippines",
    )
    admin = _make_admin(db_session, "admin-city-search@test.com")
    headers = _admin_headers(client, db_session, admin.email)
    resp = client.get("/api/v1/admin/users?search=Cebu", headers=headers)
    assert resp.status_code == 200
    emails = {u["email"] for u in resp.json()["items"]}
    assert "cebu-user@test.com" in emails
    assert "manila-user@test.com" not in emails


def test_admin_moderation_search_by_tag(client, db_session):
    admin = _make_admin(db_session, "admin-tag-search@test.com")
    _pending_report(db_session, admin.id)
    headers = _admin_headers(client, db_session, admin.email)
    hit = client.get(
        "/api/v1/admin/moderation/reports?search=good%20food", headers=headers
    )
    miss = client.get(
        "/api/v1/admin/moderation/reports?search=nightlife", headers=headers
    )
    assert hit.status_code == 200
    assert hit.json()["total"] >= 1
    assert miss.json()["total"] == 0


def _traveler(db_session, email: str, name: str) -> User:
    user = User(
        email=email,
        password_hash=hash_password("supersecret123"),
        display_name=name,
        traveler_type="local",
        user_type="local_resident",
        is_admin=False,
        accepted_research_consent=True,
    )
    apply_user_type_to_user(user)
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def test_admin_moderation_queues_return_without_n_plus_one(client, db_session):
    admin = _make_admin(db_session, "admin-mod-batch@test.com")
    h3 = "88283082d9fffff"
    people = [
        _traveler(db_session, f"mod-batch-{i}@test.com", f"Traveler {i}")
        for i in range(4)
    ]
    for person in people:
        _pending_report(db_session, person.id, h3_index=h3)
    other = _pending_report(
        db_session, people[0].id, h3_index="88283082dbfffff"
    )
    other.category = "nightlife"
    db_session.commit()

    headers = _admin_headers(client, db_session, admin.email)
    pending = client.get(
        "/api/v1/admin/moderation/reports?queue=pending&page_size=20",
        headers=headers,
    )
    assert pending.status_code == 200
    body = pending.json()
    assert body["total"] >= 5
    clustered = next(item for item in body["items"] if item["h3_index"] == h3)
    assert clustered["contributor_count"] == 4
    assert clustered["contributor_label"].startswith("Traveler")
    assert "email" not in clustered

    duplicates = client.get(
        "/api/v1/admin/moderation/reports?queue=duplicates", headers=headers
    )
    near = client.get(
        "/api/v1/admin/moderation/reports?queue=near_threshold", headers=headers
    )
    mixed = client.get(
        "/api/v1/admin/moderation/reports?queue=mixed_agreement", headers=headers
    )
    flagged = client.get(
        "/api/v1/admin/moderation/reports?queue=flagged", headers=headers
    )
    assert duplicates.status_code == 200
    assert near.status_code == 200
    assert mixed.status_code == 200
    assert flagged.status_code == 200
    assert any(item["h3_index"] == h3 for item in duplicates.json()["items"])
    assert near.json()["total"] >= 1
    detail = client.get(
        f"/api/v1/admin/moderation/reports/{clustered['id']}",
        headers=headers,
    )
    assert detail.status_code == 200
    ctx = detail.json()["cell_context"]
    assert ctx["distinct_contributors"] == 4
    assert ctx["pending_count"] == 4


def test_admin_export_reports_csv_is_readable(client, db_session):
    admin = _make_admin(db_session, "admin-csv@test.com")
    _pending_report(db_session, admin.id)
    headers = _admin_headers(client, db_session, admin.email)
    resp = client.get("/api/v1/admin/analytics/export/reports?fmt=csv", headers=headers)
    assert resp.status_code == 200
    text = resp.text
    assert "Place or area" in text
    assert "Number of tags" in text
    assert "latitude" not in text
    assert "email" not in text


def test_admin_zone_validation_counts_waiting_tags(client, db_session):
    from uuid import uuid4

    from app.models.merged_zone import MergedZone

    admin = _make_admin(db_session, "admin-validation@test.com")
    h3_index = "8828308281fffff"
    _pending_report(db_session, admin.id, h3_index=h3_index)
    zone = MergedZone(
        zone_id=uuid4(),
        display_name="IT Park Business Zone",
        slug=f"it-park-{uuid4().hex[:8]}",
        behavior_type="mixed",
        function_type="food",
        traveler_mix="mixed",
        live_status="active_now",
        polygon_geojson={"type": "Polygon", "coordinates": []},
        centroid_lat=10.331,
        centroid_lng=123.905,
        source_h3_indexes_json=[h3_index],
        confidence_score=82.0,
        report_count=12,
        is_active=True,
    )
    db_session.add(zone)
    db_session.commit()
    headers = _admin_headers(client, db_session, admin.email)
    resp = client.get(f"/api/v1/admin/zones/{zone.zone_id}/validation", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["pending_signals"] >= 1
    assert body["total_signals"] >= 1
    assert "waiting for review" in body["plain_summary"]


def test_admin_dashboard_plain_summary(client, db_session):
    admin = _make_admin(db_session, "admin-summary@test.com")
    _pending_report(db_session, admin.id)
    headers = _admin_headers(client, db_session, admin.email)
    resp = client.get("/api/v1/admin/dashboard/stats", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert "plain_summary" in body
    assert "waiting" in body["plain_summary"].lower()


def test_admin_catalog_list(client, db_session):
    headers = _admin_headers(client, db_session)
    resp = client.get("/api/v1/admin/catalog/zones", headers=headers)
    assert resp.status_code == 200
    entries = resp.json()
    assert len(entries) >= 1
    assert "zone_name" in entries[0]


def test_admin_event_stream_does_not_hold_a_db_dependency():
    import inspect

    from app.api.routers.admin.events import admin_event_stream

    assert "db" not in inspect.signature(admin_event_stream).parameters
