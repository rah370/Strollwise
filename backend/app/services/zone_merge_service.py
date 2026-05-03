"""Merges adjacent similar H3 cells into frontend-facing zones."""
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

# Confidence and activity similarity thresholds used during merging.
CONFIDENCE_SIMILARITY = 40.0  # cells within 40 confidence points merge
CROWD_SIMILARITY = 0.5

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
        groups = self._group_cells(cells)
        new_zones: list[MergedZone] = []

        # Track slugs we're creating this pass to handle collisions gracefully.
        used_slugs: set[str] = set()

        components = []
        for key, cells_in_group in groups.items():
            behavior, function_group = key
            components_for_group = self._connected_components(cells_in_group)
            for component in components_for_group:
                if not component:
                    continue
                components.append((behavior, function_group, component))

        # When a full rebuild was requested, wipe existing zones so stale geometry disappears.
        if rebuild_all:
            for zone in self.zone_repo.list_active():
                self.zone_repo.delete(zone)
            self.db.flush()

        for behavior, function_group, cells_in_component in components:
            zone = self._build_zone(behavior, function_group, cells_in_component, used_slugs)
            if zone is not None:
                self.zone_repo.upsert(zone)
                new_zones.append(zone)

        self.db.commit()
        cache_delete_pattern("zones:vp:*")
        cache_delete_pattern("city:pulse:*")
        return new_zones

    def _group_cells(
        self, cells: list[H3CellAggregate]
    ) -> dict[tuple[str, str], list[H3CellAggregate]]:
        groups: dict[tuple[str, str], list[H3CellAggregate]] = defaultdict(list)
        for cell in cells:
            function_group = FUNCTION_GROUPS.get(cell.function_type, "general")
            key = (cell.behavior_type, function_group)
            groups[key].append(cell)
        return groups

    def _connected_components(
        self, cells: list[H3CellAggregate]
    ) -> list[list[H3CellAggregate]]:
        by_index: dict[str, H3CellAggregate] = {c.h3_index: c for c in cells}
        indexes = set(by_index.keys())
        visited: set[str] = set()
        components: list[list[H3CellAggregate]] = []

        for idx in indexes:
            if idx in visited:
                continue
            stack = [idx]
            component: list[H3CellAggregate] = []
            root_cell = by_index[idx]
            while stack:
                current = stack.pop()
                if current in visited:
                    continue
                visited.add(current)
                cell = by_index[current]
                if not self._similar(root_cell, cell):
                    continue
                component.append(cell)
                for neighbor in h3_service.get_neighbors(current, ring_size=1):
                    if neighbor in indexes and neighbor not in visited:
                        neighbor_cell = by_index[neighbor]
                        if self._similar(root_cell, neighbor_cell):
                            stack.append(neighbor)
            if component:
                components.append(component)
        return components

    @staticmethod
    def _similar(a: H3CellAggregate, b: H3CellAggregate) -> bool:
        if a.behavior_type != b.behavior_type:
            return False
        if FUNCTION_GROUPS.get(a.function_type) != FUNCTION_GROUPS.get(b.function_type):
            return False
        if abs(a.confidence_score - b.confidence_score) > CONFIDENCE_SIMILARITY:
            return False
        if abs(a.crowd_score - b.crowd_score) > CROWD_SIMILARITY:
            return False
        return True

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
        display_name = self._compose_display_name(prefix, label, landmark_name)

        slug_base = slugify(f"{display_name} {h3_indexes[0][:6]}")
        slug = slug_base
        counter = 1
        while slug in used_slugs or self.zone_repo.list_by_slug(slug):
            counter += 1
            slug = f"{slug_base}-{counter}"
        used_slugs.add(slug)

        live_status = self._live_status(behavior, dominant_function, crowd_level)
        summary = self._summary(behavior, dominant_function, report_count, local_presence)
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
            polygon_geometry=PolygonService.geojson_to_postgis_geometry(polygon),
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
    def _compose_display_name(prefix: str, label: str, landmark: str) -> str:
        """Produces strings like `Food Hotspot near Colon Street` or
        `Tourist Area near IT Park`.

        Rules:
        - If the function label is generic ("Area"), fall back to `<prefix> Area near <landmark>`.
        - Otherwise use `<label> near <landmark>` — the behavior prefix is
          implied by the function (Tourist Hotspot, Student Area, etc.).
        """
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
    def _summary(
        behavior: str, function_type: str, report_count: int, local_presence: float
    ) -> str:
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
