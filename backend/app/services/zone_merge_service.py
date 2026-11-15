"""Builds one frontend-facing zone per active place (strategy B).

Each place spans many H3 cells; the zone polygon matches the place footprint.
Zones expose traveler mix (local / mixed / international) only — place type
(school, food, etc.) lives on the Place model.
"""
from __future__ import annotations

from collections import defaultdict
from collections.abc import Iterable
from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from app.core.cache import cache_delete_pattern
from app.models.enums import BehaviorType, FunctionType, LiveStatus
from app.models.h3_cell_aggregate import H3CellAggregate
from app.models.merged_zone import MergedZone
from app.models.place import Place
from app.repositories.h3_repository import H3Repository
from app.repositories.place_repository import PlaceRepository
from app.repositories.zone_repository import ZoneRepository
from app.services.place_catalog import catalog_by_slug
from app.services.polygon_service import PolygonService
from app.services.zone_catalog import catalog_entry_for_name
from app.utils.enum_utils import slugify
from app.utils.time_utils import label_for_peak_hours
from app.utils.traveler_mix_utils import traveler_mix_from_counts

TRAVELER_MIX_LABEL = {
    "local": "Mostly local",
    "mixed": "Mixed crowd",
    "international": "Mostly international",
}

TRAVELER_MIX_TO_BEHAVIOR = {
    "local": BehaviorType.LOCAL_AREA.value,
    "mixed": BehaviorType.MIXED_AREA.value,
    "international": BehaviorType.TOURIST_AREA.value,
}


class ZoneMergeService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.h3_repo = H3Repository(db)
        self.place_repo = PlaceRepository(db)
        self.zone_repo = ZoneRepository(db)

    def rebuild_all(self) -> list[MergedZone]:
        from app.services.place_service import PlaceService

        PlaceService(self.db).sync_catalog_places()
        places = self.place_repo.list_all_catalog()
        rebuilt = self._rebuild_from_places(places, used_slugs=set())
        kept = {z.place_id for z in rebuilt}
        self._delete_zones_except_places(kept)
        return rebuilt

    def recompute_for_places(self, place_ids: Iterable) -> list[MergedZone]:
        ids = {pid for pid in place_ids if pid is not None}
        if not ids:
            return []
        places = [self.place_repo.get(pid) for pid in ids]
        places = [p for p in places if p is not None and p.report_count > 0]
        rebuilt = self._rebuild_from_places(places, used_slugs=set())
        kept = {z.place_id for z in rebuilt}
        stale = ids - kept
        if stale:
            self._delete_zones_for_places(stale)
            self.db.commit()
        return rebuilt

    # ---------------------------------------------------------------- core

    def _rebuild_from_places(
        self, places: list[Place], *, used_slugs: set[str]
    ) -> list[MergedZone]:
        new_zones: list[MergedZone] = []
        cells_by_place: dict = {}
        for cell in self.h3_repo.list_active_by_place_ids(
            [place.place_id for place in places]
        ):
            cells_by_place.setdefault(cell.place_id, []).append(cell)

        for place in places:
            cells = cells_by_place.get(place.place_id, [])
            zone = self._build_zone_from_place(place, cells, used_slugs)
            if zone is not None:
                self.zone_repo.upsert(zone)
                new_zones.append(zone)

        self.db.commit()
        cache_delete_pattern("zones:vp:*")
        cache_delete_pattern("zones:feed*")
        cache_delete_pattern("city:pulse:*")
        return new_zones

    def _delete_zones_for_places(self, place_ids: set) -> None:
        for zone in list(self.zone_repo.list_active()):
            if zone.place_id in place_ids:
                self.zone_repo.delete(zone)

    def _delete_zones_except_places(self, keep_place_ids: set) -> None:
        stale = [
            zone
            for zone in self.zone_repo.list_active()
            if zone.place_id not in keep_place_ids
        ]
        if not stale:
            return
        for zone in stale:
            self.zone_repo.delete(zone)
        self.db.commit()

    # ---------------------------------------------------------- zone assembly

    @staticmethod
    def _traveler_mix_from_catalog_ratio(ratio: float) -> str:
        if ratio >= 0.75:
            return "local"
        if ratio <= 0.30:
            return "international"
        return "mixed"

    def _build_zone_from_place(
        self,
        place: Place,
        cells: list[H3CellAggregate],
        used_slugs: set[str],
    ) -> MergedZone | None:
        catalog = catalog_by_slug(place.slug)
        catalog_entry = catalog_entry_for_name(place.display_name)
        if not cells and (catalog is None or catalog_entry is None):
            return None

        h3_indexes = place.source_h3_indexes_json or [c.h3_index for c in cells]
        if catalog is not None:
            polygon = catalog.polygon_geojson
        else:
            polygon = place.polygon_geojson or PolygonService.cells_to_geojson_polygon(
                h3_indexes
            )
        centroid_lat = place.centroid_lat
        centroid_lng = place.centroid_lng

        report_count = sum(c.report_count for c in cells) if cells else 0
        if catalog_entry is not None:
            traveler_mix = self._traveler_mix_from_catalog_ratio(
                catalog_entry.default_local_ratio
            )
            local_presence = catalog_entry.default_local_ratio * 100.0
        else:
            local_total = sum(c.local_count for c in cells)
            intl_total = sum(c.international_count for c in cells)
            traveler_mix = traveler_mix_from_counts(local_total, intl_total)
            local_presence = 0.0
            total_travelers = local_total + intl_total
            if total_travelers > 0:
                local_presence = local_total / total_travelers * 100.0
        behavior = TRAVELER_MIX_TO_BEHAVIOR[traveler_mix]

        if cells:
            crowd_level = sum(c.crowd_score for c in cells) / len(cells)
            confidence = sum(c.confidence_score for c in cells) / len(cells)
            popularity = sum(c.popularity_score for c in cells) / len(cells)
            peak_hours: list[int] = []
            for c in cells:
                peak_hours.extend(c.peak_hours_json or [])
            peak_label = label_for_peak_hours(peak_hours)
            top_activities = self._top_activities(cells)
        else:
            crowd_level = 0.5
            confidence = 50.0
            popularity = 50.0
            peak_label = "4PM-9PM"
            top_activities = list(catalog_entry.characteristics[:4]) if catalog_entry else []

        from app.services.sensitive_sites import public_place_name

        display_name = public_place_name(
            place.display_name, float(centroid_lat), float(centroid_lng)
        )

        existing_zone = self.zone_repo.get_by_place_id(place.place_id)
        slug_base = slugify(f"{place.slug}-{traveler_mix}")
        slug = slug_base
        counter = 1
        while True:
            taken = self.zone_repo.list_by_slug(slug)
            own_slug = existing_zone is not None and taken is not None and taken.zone_id == existing_zone.zone_id
            if slug not in used_slugs and (taken is None or own_slug):
                break
            counter += 1
            if counter > 50:
                slug = f"{slug_base}-{uuid4().hex[:8]}"
                break
            slug = f"{slug_base}-{counter}"
        used_slugs.add(slug)

        live_status = self._live_status(behavior, None, crowd_level)
        summary = self._traveler_summary(
            display_name,
            traveler_mix,
            report_count,
            local_presence,
        )
        priority = self._priority(report_count, crowd_level, confidence, popularity)
        geometry = PolygonService.geojson_to_postgis_geometry(
            polygon,
            dialect_name=self.db.get_bind().dialect.name,
        )
        now = datetime.utcnow()
        if existing_zone is not None:
            existing_zone.display_name = display_name
            existing_zone.slug = slug
            existing_zone.behavior_type = behavior
            existing_zone.function_type = None
            existing_zone.traveler_mix = traveler_mix
            existing_zone.summary = summary
            existing_zone.live_status = live_status
            existing_zone.polygon_geojson = polygon
            existing_zone.polygon_geometry = geometry
            existing_zone.centroid_lat = float(centroid_lat)
            existing_zone.centroid_lng = float(centroid_lng)
            existing_zone.source_h3_indexes_json = h3_indexes
            existing_zone.crowd_level = float(round(crowd_level, 3))
            existing_zone.local_presence_percent = float(round(local_presence, 2))
            existing_zone.peak_time_label = peak_label
            existing_zone.top_activities_json = top_activities
            existing_zone.confidence_score = float(round(confidence, 2))
            existing_zone.priority_score = float(round(priority, 2))
            existing_zone.report_count = report_count
            existing_zone.is_active = True
            existing_zone.updated_at = now
            return existing_zone

        return MergedZone(
            zone_id=uuid4(),
            display_name=display_name,
            slug=slug,
            behavior_type=behavior,
            function_type=None,
            traveler_mix=traveler_mix,
            place_id=place.place_id,
            summary=summary,
            live_status=live_status,
            polygon_geojson=polygon,
            polygon_geometry=geometry,
            centroid_lat=float(centroid_lat),
            centroid_lng=float(centroid_lng),
            source_h3_indexes_json=h3_indexes,
            crowd_level=float(round(crowd_level, 3)),
            local_presence_percent=float(round(local_presence, 2)),
            peak_time_label=peak_label,
            top_activities_json=top_activities,
            confidence_score=float(round(confidence, 2)),
            priority_score=float(round(priority, 2)),
            report_count=report_count,
            is_active=True,
            updated_at=now,
            created_at=now,
        )

    @staticmethod
    def _traveler_summary(
        place_name: str,
        traveler_mix: str,
        report_count: int,
        local_presence: float,
    ) -> str:
        label = TRAVELER_MIX_LABEL.get(traveler_mix, "Mixed crowd")
        return (
            f"{label} area around {place_name}. "
            f"Based on {report_count} recent tags with about {local_presence:.0f}% local presence."
        )

    @staticmethod
    def _compose_display_name(
        prefix: str,
        label: str,
        landmark: str,
        profile: dict[str, object] | None = None,
    ) -> str:
        """Produces strings like `Food Hotspot near Colon Street` or
        `Tourist Area near IT Park`.

        Rules:
        - If the function label is generic ("Area"), fall back to `<prefix> Area near <landmark>`.
        - Otherwise use `<label> near <landmark>` — the behavior prefix is
          implied by the function (Tourist Hotspot, Student Area, etc.).
        """
        if profile and isinstance(profile.get("title"), str):
            return f"{profile['title']} near {landmark}"
        label = label.strip()
        if label in {"Area", "Emerging Zone"} and prefix:
            return f"{prefix} Area near {landmark}"
        if prefix and label.lower().startswith("local"):
            # Avoid "Local Local Area".
            return f"{label} near {landmark}"
        return f"{label} near {landmark}"

    @staticmethod
    def _top_activities(cells: list[H3CellAggregate]) -> list[str]:
        tag_counts: dict[str, int] = defaultdict(int)
        for cell in cells:
            for tag, count in (cell.tag_counts_json or {}).items():
                tag_counts[tag] += int(count)
        return [tag for tag, _ in sorted(tag_counts.items(), key=lambda kv: kv[1], reverse=True)[:5]]

    @staticmethod
    def _live_status(behavior: str, function_type: str | None, crowd_level: float) -> str:
        if function_type == FunctionType.SAFETY_CONCERN.value:
            return LiveStatus.CAUTION_NOW.value
        if crowd_level >= 0.8:
            return LiveStatus.PEAK_NOW.value
        if crowd_level >= 0.55:
            return LiveStatus.BUSY_NOW.value
        if crowd_level >= 0.25:
            return LiveStatus.ACTIVE_NOW.value
        return LiveStatus.QUIET_NOW.value

    @staticmethod
    def _priority(
        report_count: int,
        crowd_level: float,
        confidence: float,
        popularity: float,
    ) -> float:
        return (
            min(report_count, 80) * 0.4
            + crowd_level * 100 * 0.25
            + confidence * 0.2
            + popularity * 0.15
        )
