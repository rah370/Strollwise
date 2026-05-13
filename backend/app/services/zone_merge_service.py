"""Builds one frontend-facing zone per active H3 cell (no multi-cell merge).

Each aggregate cell becomes its own zone with a single-hex footprint so
polygons never overlap across zone types and the map reads as individual
hexes rather than one large merged blob. Partial recomputes delete any prior
zones whose H3 sources intersect the affected area before re-inserting.
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
from app.repositories.h3_repository import H3Repository
from app.repositories.zone_repository import ZoneRepository
from app.services import h3_service
from app.services.landmark_service import landmark_for_centroid
from app.services.polygon_service import PolygonService
from app.utils.enum_utils import slugify
from app.utils.time_utils import label_for_peak_hours

FUNCTION_GROUPS: dict[str, str] = {
    FunctionType.FOOD_HOTSPOT.value: "food",
    FunctionType.STUDENT_AREA.value: "education",
    FunctionType.TRANSPORT_ZONE.value: "transport",
    FunctionType.COMMERCIAL_ZONE.value: "commercial",
    FunctionType.RESIDENTIAL_ZONE.value: "residential",
    FunctionType.SAFETY_CONCERN.value: "safety",
    FunctionType.BUSY_ZONE.value: "busy",
    FunctionType.TOURIST_HOTSPOT.value: "tourist",
    FunctionType.EMERGING_ZONE.value: "emerging",
    FunctionType.UNKNOWN.value: "general",
}

BEHAVIOR_PREFIX = {
    BehaviorType.LOCAL_AREA.value: "Local",
    BehaviorType.TOURIST_AREA.value: "Tourist",
    BehaviorType.MIXED_AREA.value: "Mixed",
}

FUNCTION_DISPLAY_LABEL = {
    FunctionType.FOOD_HOTSPOT.value: "Food Hotspot",
    FunctionType.STUDENT_AREA.value: "Student Area",
    FunctionType.TRANSPORT_ZONE.value: "Transport Zone",
    FunctionType.COMMERCIAL_ZONE.value: "Commercial Zone",
    FunctionType.RESIDENTIAL_ZONE.value: "Residential Zone",
    FunctionType.SAFETY_CONCERN.value: "Safety Concern",
    FunctionType.BUSY_ZONE.value: "Busy Zone",
    FunctionType.TOURIST_HOTSPOT.value: "Tourist Hotspot",
    FunctionType.EMERGING_ZONE.value: "Emerging Zone",
    FunctionType.UNKNOWN.value: "Area",
}

LANDMARK_ZONE_INTELLIGENCE: dict[str, dict[str, object]] = {
    "IT Park": {
        "title": "IT Park Commercial + Food Zone",
        "summary": (
            "Mixed commercial food zone around Sugbo Mercado, cafes, coworking, "
            "study spots, and nightlife. Strong evening and night activity."
        ),
        "activities": ["food crawl", "work", "nightlife", "study", "coworking"],
    },
    "Sugbo Mercado": {
        "title": "IT Park Night Food + Social Zone",
        "summary": (
            "Mixed night-food cluster where office workers, students, and visitors "
            "overlap for food crawl and social hangout behavior."
        ),
        "activities": ["food crawl", "nightlife", "social hangout", "cafes"],
    },
    "Colon Street": {
        "title": "Colon Heritage + Local Food Zone",
        "summary": (
            "Local-heavy historical commercial corridor linking heritage walks, "
            "Carbon market movement, street food, shopping, and daytime errands."
        ),
        "activities": ["heritage walk", "shopping", "local food", "street market"],
    },
    "Carbon Market": {
        "title": "Carbon Market Local Food + Shopping Zone",
        "summary": (
            "Local-heavy wet-market and street-food behavior with practical shopping, "
            "budget meals, and daytime crowd movement."
        ),
        "activities": ["wet market food", "shopping", "budget meals", "local errands"],
    },
    "Basilica Minore del Santo Niño": {
        "title": "Basilica Heritage Walk Zone",
        "summary": (
            "Heritage and visitor movement zone connected to Basilica, Magellan's Cross, "
            "Fort San Pedro, and nearby local food stops."
        ),
        "activities": ["heritage walk", "museum", "local food", "sightseeing"],
    },
    "Fuente Osmeña": {
        "title": "Fuente Transit + Food Zone",
        "summary": (
            "Local-heavy transport and food node around Robinsons, Larsian, shopping, "
            "commute routes, and evening movement."
        ),
        "activities": ["commute", "food", "shopping", "evening errands"],
    },
    "Larsian Fuente": {
        "title": "Larsian Local BBQ Food Zone",
        "summary": (
            "Local food behavior zone for barbecue streets, budget meals, late snacks, "
            "and practical group dining near Fuente."
        ),
        "activities": ["barbecue streets", "budget meals", "local food", "late night"],
    },
    "USC Main": {
        "title": "USC Main Student Activity Zone",
        "summary": (
            "Student-centered area shaped by study hubs, budget meals, campus edges, "
            "cafes, and after-class movement."
        ),
        "activities": ["study", "budget meals", "cafes", "student activity"],
    },
    "USC Talamban": {
        "title": "USC Talamban Student + Cafe Zone",
        "summary": (
            "Local student route with campus movement, cheap food areas, study cafes, "
            "and commute patterns."
        ),
        "activities": ["study", "budget meals", "coworking", "commute"],
    },
    "Busay / Tops": {
        "title": "Busay Nature + Sunset Zone",
        "summary": (
            "Tourist-heavy nature escape zone for Tops, Temple of Leah, mountain cafes, "
            "sightseeing, coffee, and sunset drives."
        ),
        "activities": ["sightseeing", "coffee", "mountain drive", "sunset"],
    },
    "Temple of Leah": {
        "title": "Temple of Leah Sightseeing Zone",
        "summary": (
            "Tourist-heavy sightseeing cluster connected to Busay viewpoints, mountain "
            "cafes, photo stops, and sunset activity."
        ),
        "activities": ["sightseeing", "photo spot", "coffee", "sunset"],
    },
    "Cebu Taoist Temple": {
        "title": "Taoist Temple Cultural Viewpoint Zone",
        "summary": (
            "Tourist-heavy cultural viewpoint with city views, quiet walking, "
            "photo stops, and daytime sightseeing movement."
        ),
        "activities": ["sightseeing", "photo spot", "quiet walk", "culture"],
    },
    "Sirao Flower Garden": {
        "title": "Sirao Flower Garden Nature Zone",
        "summary": (
            "Highland tourist nature zone for flower garden visits, photo stops, "
            "mountain drives, and weekend sightseeing."
        ),
        "activities": ["nature escape", "photo spot", "mountain drive", "weekend"],
    },
    "Mactan Resort Area": {
        "title": "Mactan Resort + Beach Zone",
        "summary": (
            "Tourist-heavy resort and hotel behavior zone with beach clubs, diving, "
            "seafood restaurants, buffets, and afternoon leisure."
        ),
        "activities": ["beach", "diving", "resorts", "seafood", "nightlife"],
    },
    "Magellan's Cross": {
        "title": "Magellan's Cross Heritage Walk Zone",
        "summary": (
            "Heritage trail zone linked to Basilica, Fort San Pedro, museums, "
            "walking tours, and downtown local food stops."
        ),
        "activities": ["heritage walk", "museum", "sightseeing", "local food"],
    },
    "Fort San Pedro": {
        "title": "Fort San Pedro Heritage Zone",
        "summary": (
            "Historic fort and museum behavior zone near the downtown heritage "
            "trail, waterfront movement, and local food stops."
        ),
        "activities": ["heritage walk", "museum", "waterfront", "local food"],
    },
    "South Bus Terminal": {
        "title": "South Bus Terminal Backpacker Transit Zone",
        "summary": (
            "Budget traveler and local commute zone shaped by bus transfers, "
            "cheap inns, local eateries, and early trip departures."
        ),
        "activities": ["budget travel", "commute", "local eateries", "transit"],
    },
    "Mango Avenue": {
        "title": "Mango Avenue Nightlife + Food Zone",
        "summary": (
            "Evening activity corridor for nightlife, budget food, social hangouts, "
            "and visible late-night movement."
        ),
        "activities": ["nightlife", "food crawl", "social hangout", "late night"],
    },
    "IL Corso / SRP": {
        "title": "SRP Family + Seaside Walk Zone",
        "summary": (
            "Weekend family behavior zone around IL Corso, Ocean Park, seaside walking, "
            "dining, and relaxed group activity."
        ),
        "activities": ["family bonding", "dining", "walking", "weekend local"],
    },
}


class ZoneMergeService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.h3_repo = H3Repository(db)
        self.zone_repo = ZoneRepository(db)

    def rebuild_all(self) -> list[MergedZone]:
        cells = self.h3_repo.list_all_active()
        return self._rebuild_from_cells(cells, rebuild_all=True)

    def recompute_near(self, seed_h3_indexes: Iterable[str]) -> list[MergedZone]:
        # Expand seed cells with a 2-ring neighborhood to catch boundary flips.
        expanded: set[str] = set()
        for idx in seed_h3_indexes:
            expanded.add(idx)
            expanded.update(h3_service.get_neighbors(idx, ring_size=2))
        cells = self.h3_repo.list_by_indexes(expanded)
        if not cells:
            return []
        return self._rebuild_from_cells(cells, rebuild_all=False)

    # ---------------------------------------------------------------- core

    def _rebuild_from_cells(
        self,
        cells: list[H3CellAggregate],
        *,
        rebuild_all: bool,
    ) -> list[MergedZone]:
        new_zones: list[MergedZone] = []
        used_slugs: set[str] = set()

        if rebuild_all:
            for zone in self.zone_repo.list_active():
                self.zone_repo.delete(zone)
            self.db.flush()
        else:
            touched = {c.h3_index for c in cells}
            self._delete_zones_touching_h3_indexes(touched)
            self.db.flush()

        for cell in cells:
            if cell.report_count == 0:
                continue
            function_group = FUNCTION_GROUPS.get(cell.function_type, "general")
            zone = self._build_zone(
                cell.behavior_type, function_group, [cell], used_slugs
            )
            if zone is not None:
                self.zone_repo.upsert(zone)
                new_zones.append(zone)

        self.db.commit()
        cache_delete_pattern("zones:vp:*")
        cache_delete_pattern("zones:feed*")
        cache_delete_pattern("city:pulse:*")
        return new_zones

    def _delete_zones_touching_h3_indexes(self, indexes: set[str]) -> None:
        """Remove merged zones that used any of these cells so we never stack
        stale geometry on top of fresh per-cell footprints."""
        if not indexes:
            return
        for zone in list(self.zone_repo.list_active()):
            existing = set(zone.source_h3_indexes_json or [])
            if existing & indexes:
                self.zone_repo.delete(zone)

    # ---------------------------------------------------------- zone assembly

    def _build_zone(
        self,
        behavior: str,
        function_group: str,
        cells: list[H3CellAggregate],
        used_slugs: set[str],
    ) -> MergedZone | None:
        if not cells:
            return None
        # Use the dominant function type within the component for display.
        function_counter: dict[str, int] = {}
        for c in cells:
            function_counter[c.function_type] = function_counter.get(c.function_type, 0) + 1
        dominant_function = max(function_counter.items(), key=lambda kv: kv[1])[0]

        h3_indexes = [c.h3_index for c in cells]
        polygon = PolygonService.cells_to_geojson_polygon(h3_indexes)
        centroid_lat, centroid_lng = PolygonService.centroid_of_cells(h3_indexes)

        report_count = sum(c.report_count for c in cells)
        if report_count == 0:
            return None

        local_presence = 0.0
        total_travelers = sum(c.local_count + c.international_count for c in cells)
        if total_travelers > 0:
            local_presence = (
                sum(c.local_count for c in cells) / total_travelers * 100.0
            )

        crowd_level = sum(c.crowd_score for c in cells) / len(cells)
        confidence = sum(c.confidence_score for c in cells) / len(cells)
        popularity = sum(c.popularity_score for c in cells) / len(cells)

        peak_hours: list[int] = []
        for c in cells:
            peak_hours.extend(c.peak_hours_json or [])
        peak_label = label_for_peak_hours(peak_hours)

        top_activities = self._top_activities(cells)
        label = FUNCTION_DISPLAY_LABEL.get(dominant_function, "Area")
        prefix = BEHAVIOR_PREFIX.get(behavior, "")
        landmark_name, _ = landmark_for_centroid(centroid_lat, centroid_lng)
        profile = self._landmark_profile(landmark_name)
        display_name = self._compose_display_name(prefix, label, landmark_name, profile)

        slug_base = slugify(f"{display_name} {h3_indexes[0][:6]}")
        slug = slug_base
        counter = 1
        while slug in used_slugs or self.zone_repo.list_by_slug(slug):
            counter += 1
            slug = f"{slug_base}-{counter}"
        used_slugs.add(slug)

        live_status = self._live_status(behavior, dominant_function, crowd_level)
        summary = self._summary(
            behavior,
            dominant_function,
            report_count,
            local_presence,
            profile=profile,
        )
        top_activities = self._merge_profile_activities(top_activities, profile)
        priority = self._priority(report_count, crowd_level, confidence, popularity)

        return MergedZone(
            zone_id=uuid4(),
            display_name=display_name,
            slug=slug,
            behavior_type=behavior,
            function_type=dominant_function,
            summary=summary,
            live_status=live_status,
            polygon_geojson=polygon,
            polygon_geometry=PolygonService.geojson_to_postgis_geometry(
                polygon,
                dialect_name=self.db.get_bind().dialect.name,
            ),
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
            updated_at=datetime.utcnow(),
            created_at=datetime.utcnow(),
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
    def _landmark_profile(landmark: str) -> dict[str, object] | None:
        return LANDMARK_ZONE_INTELLIGENCE.get(landmark)

    @staticmethod
    def _merge_profile_activities(
        activities: list[str], profile: dict[str, object] | None
    ) -> list[str]:
        if not profile:
            return activities
        profile_activities = profile.get("activities")
        if not isinstance(profile_activities, list):
            return activities
        merged: list[str] = []
        for activity in [*profile_activities, *activities]:
            if isinstance(activity, str) and activity not in merged:
                merged.append(activity)
        return merged[:6]

    @staticmethod
    def _summary(
        behavior: str,
        function_type: str,
        report_count: int,
        local_presence: float,
        *,
        profile: dict[str, object] | None = None,
    ) -> str:
        if profile and isinstance(profile.get("summary"), str):
            return (
                f"{profile['summary']} Confidence comes from {report_count} recent "
                f"community tags with about {local_presence:.0f}% local presence."
            )
        function_label = FUNCTION_DISPLAY_LABEL.get(function_type, "Area")
        behavior_label = {
            BehaviorType.LOCAL_AREA.value: "locals",
            BehaviorType.TOURIST_AREA.value: "visitors",
            BehaviorType.MIXED_AREA.value: "locals and visitors",
        }.get(behavior, "travelers")
        return (
            f"{function_label} with {report_count} recent community tags. "
            f"Approximately {local_presence:.0f}% local presence, driven by {behavior_label}."
        )

    @staticmethod
    def _live_status(behavior: str, function_type: str, crowd_level: float) -> str:
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
