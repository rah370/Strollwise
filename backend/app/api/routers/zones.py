from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.cache import (
    build_viewport_cache_key,
    cache_get,
    cache_set,
)
from app.core.config import settings
from app.core.database import get_db
from app.repositories.zone_repository import ZoneRepository
from app.schemas.common import Centroid
from app.schemas.zone import CurrentZoneOverview, ZoneDetail, ZoneLaunchContext, ZoneListItem
from app.services.ranking_service import RankingService
from app.services import h3_service
from app.utils.geo_utils import haversine_km, polygon_intersects_bbox

router = APIRouter(prefix="/zones", tags=["zones"])


@router.get("", response_model=list[ZoneListItem])
def zones_in_viewport(
    min_lat: float = Query(..., ge=-90.0, le=90.0),
    min_lng: float = Query(..., ge=-180.0, le=180.0),
    max_lat: float = Query(..., ge=-90.0, le=90.0),
    max_lng: float = Query(..., ge=-180.0, le=180.0),
    zoom: float | None = Query(default=None, ge=0, le=22),
    filter: str | None = Query(default=None, max_length=32),
    user_lat: float | None = Query(default=None, ge=-90.0, le=90.0),
    user_lng: float | None = Query(default=None, ge=-180.0, le=180.0),
    db: Session = Depends(get_db),
) -> list[ZoneListItem]:
    if min_lat > max_lat or min_lng > max_lng:
        raise HTTPException(status_code=400, detail="Invalid bounding box")

    cache_key = build_viewport_cache_key(
        min_lat, min_lng, max_lat, max_lng, zoom=zoom, filter_key=filter
    )
    cached = cache_get(cache_key)
    if cached is not None:
        return [ZoneListItem.model_validate(item) for item in cached]

    repo = ZoneRepository(db)
    # Fast path: ask PostGIS via ST_Intersects.
    in_viewport = repo.list_active_in_bbox(min_lat, min_lng, max_lat, max_lng)
    if in_viewport is None:
        # Fallback for non-PostGIS backends (e.g. SQLite tests): filter in Python.
        in_viewport = [
            z
            for z in repo.list_active()
            if polygon_intersects_bbox(
                _flatten_polygon_rings(z.polygon_geojson),
                min_lat,
                min_lng,
                max_lat,
                max_lng,
            )
        ]
    ranked = RankingService.rank(
        in_viewport,
        filter_key=filter,
        user_lat=user_lat,
        user_lng=user_lng,
    )
    response = [_to_list_item(z) for z in ranked]
    cache_set(
        cache_key,
        [item.model_dump(mode="json") for item in response],
        settings.cache_ttl_zones_seconds,
    )
    return response


@router.get("/current", response_model=CurrentZoneOverview)
def current_zone_overview(
    lat: float = Query(..., ge=-90.0, le=90.0),
    lng: float = Query(..., ge=-180.0, le=180.0),
    ring: int = Query(1, ge=1, le=2),
    limit: int = Query(8, ge=1, le=20),
    db: Session = Depends(get_db),
) -> CurrentZoneOverview:
    repo = ZoneRepository(db)
    zones = repo.list_active()
    if not zones:
        return CurrentZoneOverview(
            current_zone=None,
            nearby_zones=[],
            alternative_zones=[],
            context=ZoneLaunchContext(
                city_activity="quiet",
                crowd_level_percent=0,
                local_presence_percent=0,
                peak_time_window=None,
            ),
        )

    current = _find_current_zone(zones, lat=lat, lng=lng)
    nearby = _nearby_ranked(
        zones,
        lat=lat,
        lng=lng,
        include_zone_id=current.zone_id if current is not None else None,
        limit=limit,
        radius_km=2.4 if ring == 1 else 4.8,
    )
    alternatives = (
        RankingService.recommend_alternatives(current, nearby + ([current] if current else []))
        if current is not None and current.crowd_level >= 0.6
        else []
    )
    context_source = current if current is not None else nearby[0]
    city_activity = _city_activity_label(context_source.crowd_level)
    crowd_percent = min(max(context_source.crowd_level * 100, 0), 100)

    return CurrentZoneOverview(
        current_zone=_to_list_item(current) if current is not None else None,
        nearby_zones=[_to_list_item(z) for z in nearby],
        alternative_zones=[_to_list_item(z) for z in alternatives],
        context=ZoneLaunchContext(
            city_activity=city_activity,
            crowd_level_percent=round(crowd_percent, 1),
            local_presence_percent=round(context_source.local_presence_percent, 1),
            peak_time_window=context_source.peak_time_label,
        ),
    )


@router.get("/{zone_id}", response_model=ZoneDetail)
def zone_detail(zone_id: UUID, db: Session = Depends(get_db)) -> ZoneDetail:
    repo = ZoneRepository(db)
    zone = repo.get(zone_id)
    if zone is None:
        raise HTTPException(status_code=404, detail="Zone not found")

    nearby = _nearby_zone_ids(repo, zone)
    return ZoneDetail(
        zone_id=zone.zone_id,
        display_name=zone.display_name,
        behavior_type=zone.behavior_type,
        function_type=zone.function_type,
        summary=zone.summary,
        live_status=zone.live_status,
        polygon_geojson=zone.polygon_geojson,
        centroid=Centroid(lat=zone.centroid_lat, lng=zone.centroid_lng),
        crowd_level=zone.crowd_level,
        local_presence_percent=zone.local_presence_percent,
        peak_time_label=zone.peak_time_label,
        top_activities=list(zone.top_activities_json or []),
        confidence_score=zone.confidence_score,
        why_visit=_why_visit(zone),
        live_update=_live_update(zone),
        nearby_zone_ids=nearby,
        source_h3_indexes=list(zone.source_h3_indexes_json or []),
        source_h3_rings=_display_h3_rings(zone),
        report_count=zone.report_count,
    )


@router.get("/{zone_id}/nearby", response_model=list[ZoneListItem])
def zone_nearby(
    zone_id: UUID,
    radius_km: float = Query(3.0, gt=0, le=25.0),
    limit: int = Query(10, ge=1, le=40),
    db: Session = Depends(get_db),
) -> list[ZoneListItem]:
    repo = ZoneRepository(db)
    zone = repo.get(zone_id)
    if zone is None:
        raise HTTPException(status_code=404, detail="Zone not found")
    all_zones = repo.list_active()
    distances: list[tuple[float, object]] = []
    for other in all_zones:
        if other.zone_id == zone.zone_id:
            continue
        d = haversine_km(
            zone.centroid_lat, zone.centroid_lng, other.centroid_lat, other.centroid_lng
        )
        if d <= radius_km:
            distances.append((d, other))
    distances.sort(key=lambda pair: pair[0])
    return [_to_list_item(o) for _, o in distances[:limit]]


def _to_list_item(zone) -> ZoneListItem:
    return ZoneListItem(
        zone_id=zone.zone_id,
        display_name=zone.display_name,
        behavior_type=zone.behavior_type,
        function_type=zone.function_type,
        summary=zone.summary,
        live_status=zone.live_status,
        polygon_geojson=zone.polygon_geojson,
        centroid=Centroid(lat=zone.centroid_lat, lng=zone.centroid_lng),
        crowd_level=zone.crowd_level,
        local_presence_percent=zone.local_presence_percent,
        peak_time_label=zone.peak_time_label,
        confidence_score=zone.confidence_score,
        priority_score=zone.priority_score,
        source_h3_rings=_display_h3_rings(zone),
    )


def _close_ring(ring: list[list[float]]) -> list[list[float]]:
    if not ring:
        return []
    if ring[0] == ring[-1]:
        return ring
    return [*ring, ring[0]]


def _display_h3_rings(zone) -> list[list[list[float]]]:
    source = [idx for idx in (zone.source_h3_indexes_json or []) if idx]
    if not source:
        return []

    # Render with finer hexes than aggregation resolution so the map reads as
    # small manageable cells instead of one large chunky region.
    target_resolution = min(settings.h3_resolution + 1, 10)
    try:
        display_indexes = h3_service.expand_cells(source, target_resolution)
    except Exception:
        display_indexes = source

    # Keep payload bounded in very dense areas.
    unique = list(dict.fromkeys(display_indexes))
    if len(unique) > 600:
        unique = unique[:600]

    return [_close_ring(h3_service.cell_to_lnglat_ring(idx)) for idx in unique]


def _find_current_zone(zones: list, *, lat: float, lng: float):
    containing = [z for z in zones if _zone_contains_point(z.polygon_geojson, lat=lat, lng=lng)]
    if containing:
        containing.sort(key=lambda z: float(z.priority_score or 0), reverse=True)
        return containing[0]
    distances = [
        (
            haversine_km(lat, lng, zone.centroid_lat, zone.centroid_lng),
            zone,
        )
        for zone in zones
    ]
    distances.sort(key=lambda pair: pair[0])
    return distances[0][1] if distances else None


def _nearby_ranked(
    zones: list,
    *,
    lat: float,
    lng: float,
    include_zone_id: UUID | None,
    limit: int,
    radius_km: float,
) -> list:
    ranked: list[tuple[float, object]] = []
    for zone in zones:
        if include_zone_id is not None and zone.zone_id == include_zone_id:
            continue
        distance_km = haversine_km(lat, lng, zone.centroid_lat, zone.centroid_lng)
        if distance_km <= radius_km:
            ranked.append((distance_km, zone))
    ranked.sort(key=lambda pair: pair[0])
    return [z for _, z in ranked[:limit]]


def _zone_contains_point(geojson: dict, *, lat: float, lng: float) -> bool:
    if not geojson:
        return False
    geom_type = geojson.get("type")
    coords = geojson.get("coordinates", [])
    if geom_type == "Polygon":
        polygons = [coords]
    elif geom_type == "MultiPolygon":
        polygons = coords
    else:
        return False
    for polygon in polygons:
        if not polygon:
            continue
        outer_ring = polygon[0]
        if _point_in_ring(outer_ring, lat=lat, lng=lng):
            return True
    return False


def _point_in_ring(ring: list[list[float]], *, lat: float, lng: float) -> bool:
    inside = False
    if len(ring) < 3:
        return False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        intersects = (yi > lat) != (yj > lat) and lng < (xj - xi) * (lat - yi) / (
            (yj - yi) or 1e-12
        ) + xi
        if intersects:
            inside = not inside
        j = i
    return inside


def _city_activity_label(crowd_level: float) -> str:
    if crowd_level >= 0.75:
        return "peak"
    if crowd_level >= 0.55:
        return "active"
    if crowd_level >= 0.35:
        return "steady"
    return "quiet"


def _flatten_polygon_rings(geojson: dict) -> list[list[list[float]]]:
    if not geojson:
        return []
    if geojson.get("type") == "Polygon":
        return geojson.get("coordinates", [])
    if geojson.get("type") == "MultiPolygon":
        polys = geojson.get("coordinates", [])
        flat: list[list[list[float]]] = []
        for poly in polys:
            if poly:
                flat.append(poly[0])
        return flat
    return []


def _nearby_zone_ids(repo: ZoneRepository, zone) -> list[UUID]:
    ids: list[tuple[float, UUID]] = []
    for other in repo.list_active():
        if other.zone_id == zone.zone_id:
            continue
        d = haversine_km(
            zone.centroid_lat, zone.centroid_lng, other.centroid_lat, other.centroid_lng
        )
        ids.append((d, other.zone_id))
    ids.sort(key=lambda pair: pair[0])
    return [zid for _, zid in ids[:5]]


def _why_visit(zone) -> str:
    activities = ", ".join(list(zone.top_activities_json or [])[:3]) or "mixed activity"
    return (
        f"Recent travelers reported {activities}. "
        f"Confidence score is {zone.confidence_score:.0f}/100."
    )


def _live_update(zone) -> str | None:
    return {
        "peak_now": "Very active right now — expect crowds.",
        "busy_now": "Busier than usual this hour.",
        "active_now": "A steady flow of reports in the last hour.",
        "quiet_now": "Calm right now — a good time to wander.",
        "caution_now": "Several recent safety reports. Stay alert.",
    }.get(zone.live_status)
