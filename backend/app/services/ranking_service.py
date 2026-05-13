"""Scoring for the built-in filters (Popular Now, Local Picks, Food, etc.)."""
from __future__ import annotations

import heapq
from collections.abc import Iterable

from app.models.enums import BehaviorType, FunctionType
from app.models.merged_zone import MergedZone
from app.utils.geo_utils import haversine_km


class RankingService:
    FILTERS = {
        "for_you",
        "popular_now",
        "local_picks",
        "food",
        "transport",
        "commercial",
        "tourist",
        "safe_areas",
    }

    @classmethod
    def rank(
        cls,
        zones: Iterable[MergedZone],
        *,
        filter_key: str | None,
        user_lat: float | None = None,
        user_lng: float | None = None,
        limit: int | None = None,
    ) -> list[MergedZone]:
        zones_list = list(zones)
        if filter_key is None:
            if limit is None:
                return sorted(
                    zones_list, key=lambda z: float(z.priority_score or 0), reverse=True
                )
            return heapq.nlargest(
                min(limit, len(zones_list)),
                zones_list,
                key=lambda z: float(z.priority_score or 0),
            )

        key = filter_key.lower()
        if key not in cls.FILTERS:

            def priority_only(z: MergedZone) -> float:
                return float(z.priority_score or 0)

            if limit is None:
                return sorted(zones_list, key=priority_only, reverse=True)
            return heapq.nlargest(min(limit, len(zones_list)), zones_list, key=priority_only)

        def score(zone: MergedZone) -> float:
            base = float(zone.priority_score or 0)
            if key == "popular_now":
                base += zone.crowd_level * 30 + zone.report_count * 0.25
            elif key == "local_picks":
                base += zone.local_presence_percent * 0.8
                if zone.behavior_type == BehaviorType.LOCAL_AREA.value:
                    base += 20
            elif key == "food":
                if zone.function_type == FunctionType.FOOD_HOTSPOT.value:
                    base += 40
            elif key == "transport":
                if zone.function_type == FunctionType.TRANSPORT_ZONE.value:
                    base += 35
            elif key == "commercial":
                if zone.function_type == FunctionType.COMMERCIAL_ZONE.value:
                    base += 30
            elif key == "tourist":
                # Tourist-leaning areas: hotspots and mixed behavior
                # dominated by international visitors.
                if zone.function_type == FunctionType.TOURIST_HOTSPOT.value:
                    base += 40
                if zone.behavior_type == BehaviorType.TOURIST_AREA.value:
                    base += 18
                # Downrank strongly local-only areas for this filter.
                if zone.behavior_type == BehaviorType.LOCAL_AREA.value:
                    base -= 10
            elif key == "safe_areas":
                if zone.function_type == FunctionType.SAFETY_CONCERN.value:
                    base -= 45
                else:
                    base += zone.confidence_score * 0.25

            if user_lat is not None and user_lng is not None:
                distance_km = haversine_km(
                    user_lat, user_lng, zone.centroid_lat, zone.centroid_lng
                )
                base -= min(distance_km, 20.0) * 2.0
            return base

        if limit is None:
            return sorted(zones_list, key=score, reverse=True)
        return heapq.nlargest(min(limit, len(zones_list)), zones_list, key=score)

    @classmethod
    def recommend_alternatives(
        cls,
        current_zone: MergedZone,
        zones: Iterable[MergedZone],
        *,
        limit: int = 3,
    ) -> list[MergedZone]:
        candidates: list[tuple[float, MergedZone]] = []
        for zone in zones:
            if zone.zone_id == current_zone.zone_id:
                continue
            distance_km = haversine_km(
                current_zone.centroid_lat,
                current_zone.centroid_lng,
                zone.centroid_lat,
                zone.centroid_lng,
            )
            if distance_km > 6.0:
                continue
            if zone.confidence_score < 35:
                continue

            score = float(zone.priority_score or 0)
            if zone.function_type == current_zone.function_type:
                score += 35
            elif zone.behavior_type == current_zone.behavior_type:
                score += 12
            else:
                continue

            if zone.crowd_level < current_zone.crowd_level:
                score += (current_zone.crowd_level - zone.crowd_level) * 25
            else:
                score -= (zone.crowd_level - current_zone.crowd_level) * 20
            score -= min(distance_km, 6.0) * 2.5
            candidates.append((score, zone))

        candidates.sort(key=lambda pair: pair[0], reverse=True)
        return [zone for _, zone in candidates[:limit]]
