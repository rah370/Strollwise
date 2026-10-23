from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.models.merged_zone import MergedZone
from app.models.report import Report
from app.services import h3_service


def _insert_zone(db_session, h3_index: str) -> MergedZone:
    zone = MergedZone(
        zone_id=uuid4(),
        display_name="Escario",
        slug=f"escario-{uuid4().hex[:8]}",
        behavior_type="mixed_area",
        function_type="commercial_zone",
        traveler_mix="mixed",
        summary="Capitol Site commercial strip",
        live_status="quiet_now",
        polygon_geojson={
            "type": "Polygon",
            "coordinates": [
                [
                    [123.89, 10.31],
                    [123.90, 10.31],
                    [123.90, 10.32],
                    [123.89, 10.32],
                    [123.89, 10.31],
                ]
            ],
        },
        centroid_lat=10.3155,
        centroid_lng=123.8962,
        source_h3_indexes_json=[h3_index],
        crowd_level=0.04,
        local_presence_percent=55.0,
        peak_time_label="6AM–11AM",
        confidence_score=69.0,
        report_count=14,
        is_active=True,
    )
    db_session.add(zone)
    db_session.commit()
    db_session.refresh(zone)
    return zone


def _insert_report(
    db_session,
    *,
    h3_index: str,
    category: str,
    created_at: datetime,
    lat: float = 10.3155,
    lng: float = 123.8962,
) -> None:
    db_session.add(
        Report(
            h3_index=h3_index,
            resolution=8,
            latitude_raw=lat,
            longitude_raw=lng,
            category=category,
            tags_json=[category],
            visibility_status="visible",
            created_at=created_at,
        )
    )


def test_category_trends_distinguishes_growth_from_volume(db_session, client):
    h3_index = h3_service.latlng_to_cell(10.3155, 123.8962)
    zone = _insert_zone(db_session, h3_index)
    now = datetime.now(timezone.utc)
    # Current 30 days: 6 food, 3 transport.
    for i in range(6):
        _insert_report(
            db_session,
            h3_index=h3_index,
            category="food",
            created_at=now - timedelta(days=2 + i),
        )
    for i in range(3):
        _insert_report(
            db_session,
            h3_index=h3_index,
            category="transport",
            created_at=now - timedelta(days=3 + i),
        )
    # Previous 30 days: 1 food, 4 transport.
    _insert_report(
        db_session,
        h3_index=h3_index,
        category="food",
        created_at=now - timedelta(days=40),
    )
    for i in range(4):
        _insert_report(
            db_session,
            h3_index=h3_index,
            category="transport",
            created_at=now - timedelta(days=35 + i),
        )
    db_session.commit()

    resp = client.get(f"/api/v1/analytics/zone/{zone.zone_id}/category-trends")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["window_days"] == 30
    assert body["current_total"] == 9
    assert body["enough_data"] is True
    by_cat = {row["category"]: row for row in body["categories"]}
    assert by_cat["food"]["growing"] is True
    assert by_cat["food"]["delta"] == 5
    assert by_cat["transport"]["growing"] is False
    assert by_cat["transport"]["current_count"] == 3
    assert by_cat["transport"]["previous_count"] == 4


def test_category_trends_marks_small_samples(db_session, client):
    h3_index = h3_service.latlng_to_cell(10.3155, 123.8962)
    zone = _insert_zone(db_session, h3_index)
    now = datetime.now(timezone.utc)
    _insert_report(
        db_session,
        h3_index=h3_index,
        category="food",
        created_at=now - timedelta(days=1),
    )
    db_session.commit()
    resp = client.get(
        f"/api/v1/analytics/zone/{zone.zone_id}/category-trends",
        params={"window_days": 30},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["current_total"] == 1
    assert body["enough_data"] is False
    assert body["min_sample"] == 8
