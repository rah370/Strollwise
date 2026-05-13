from __future__ import annotations

from app.models.enums import BehaviorType, FunctionType
from app.models.h3_cell_aggregate import H3CellAggregate
from app.models.report import Report
from app.services import h3_service
from app.services.aggregation_service import AggregationService
from app.services.zone_merge_service import ZoneMergeService


def _seed_food_reports(
    db_session,
    *,
    user_id,
    center_lat=10.3306,
    center_lng=123.9056,
    count=18,
):
    """Create adjacent H3 cells' worth of food reports.

    Uses small lat offsets so the reports spread across a handful of
    neighbouring H3 cells at resolution 8 — enough to trigger merging
    into a multi-cell zone.
    """
    reports = []
    for i in range(count):
        lat = center_lat + (i % 6) * 0.0004
        lng = center_lng + (i // 6) * 0.0004
        h3_index = h3_service.latlng_to_cell(lat, lng, 8)
        r = Report(
            user_id=user_id,
            h3_index=h3_index,
            resolution=8,
            latitude_raw=lat,
            longitude_raw=lng,
            category="food",
            tags_json=["food", "cafe", "restaurant"],
            traveler_type_snapshot="local",
            source_type="user",
            visibility_status="visible",
        )
        db_session.add(r)
        reports.append(r)
    db_session.commit()
    return reports


def _create_user(db_session):
    from app.models.user import User

    user = User(
        email="merge-tester@example.com",
        password_hash="x",
        display_name="Tester",
        traveler_type="local",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def test_merge_creates_zone_with_landmark_name(db_session):
    user = _create_user(db_session)
    reports = _seed_food_reports(db_session, user_id=user.id)
    affected_cells = {r.h3_index for r in reports}

    AggregationService(db_session).recompute_cells(affected_cells)
    db_session.commit()

    zones = ZoneMergeService(db_session).recompute_near(list(affected_cells))

    assert zones, "expected at least one per-cell zone"
    # Each active H3 cell is its own zone (single hex, no multi-cell merge).
    assert all(len(z.source_h3_indexes_json) == 1 for z in zones)
    assert all(z.behavior_type == BehaviorType.LOCAL_AREA.value for z in zones)
    assert all(z.function_type == FunctionType.FOOD_HOTSPOT.value for z in zones)
    zone = zones[0]
    # Name follows the `<function> near <landmark>` template.
    assert " near " in zone.display_name, zone.display_name
    # Polygon was persisted (single hex => Polygon).
    assert zone.polygon_geojson is not None
    assert zone.polygon_geojson.get("type") in ("Polygon", "MultiPolygon")


def test_merge_separates_cells_with_different_behavior(db_session):
    """Two nearby cells with different behavior types should NOT merge into one zone."""
    user = _create_user(db_session)

    # Cell A: local food
    a_lat, a_lng = 10.3306, 123.9056
    a_idx = h3_service.latlng_to_cell(a_lat, a_lng, 8)
    # Cell B: adjacent H3 neighbor, tourist food
    neighbors = [n for n in h3_service.get_neighbors(a_idx, 1) if n != a_idx]
    assert neighbors, "expected at least one neighbor"
    b_idx = neighbors[0]
    from app.services.h3_service import cell_centroid

    b_lat, b_lng = cell_centroid(b_idx)

    for _ in range(6):
        db_session.add(
            Report(
                user_id=user.id,
                h3_index=a_idx,
                resolution=8,
                latitude_raw=a_lat,
                longitude_raw=a_lng,
                category="food",
                tags_json=["food", "cafe"],
                traveler_type_snapshot="local",
                source_type="user",
                visibility_status="visible",
            )
        )
    for _ in range(6):
        db_session.add(
            Report(
                user_id=user.id,
                h3_index=b_idx,
                resolution=8,
                latitude_raw=b_lat,
                longitude_raw=b_lng,
                category="food",
                tags_json=["food", "cafe"],
                traveler_type_snapshot="international",
                source_type="user",
                visibility_status="visible",
            )
        )
    db_session.commit()

    AggregationService(db_session).recompute_cells({a_idx, b_idx})
    db_session.commit()

    # Sanity: the two cells got different behavior classifications.
    a_cell = db_session.get(H3CellAggregate, a_idx)
    b_cell = db_session.get(H3CellAggregate, b_idx)
    assert a_cell.behavior_type == BehaviorType.LOCAL_AREA.value
    assert b_cell.behavior_type == BehaviorType.TOURIST_AREA.value

    zones = ZoneMergeService(db_session).recompute_near([a_idx, b_idx])

    # Different behavior types => at least two zones, one per behavior.
    behaviors = {z.behavior_type for z in zones}
    assert BehaviorType.LOCAL_AREA.value in behaviors
    assert BehaviorType.TOURIST_AREA.value in behaviors
