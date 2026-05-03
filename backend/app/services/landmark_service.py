"""Maps a lat/lng to the nearest known Cebu landmark name.

The MVP name fallback from the spec is `<behavior> <function> near <landmark>`.
We keep this list in code for now; later it can be promoted to a DB table
populated from OSM / city administrative polygons.
"""
from __future__ import annotations

from dataclasses import dataclass

from app.utils.geo_utils import haversine_km


@dataclass(frozen=True)
class Landmark:
    name: str
    lat: float
    lng: float
    # Soft radius (km): when the centroid is within this distance we say
    # "near <landmark>"; outside it we fall back to "near <closest>".
    radius_km: float = 1.0


# Ordered by rough importance — the first landmark within `radius_km` wins
# if multiple overlap, so put more specific names first.
CEBU_LANDMARKS: tuple[Landmark, ...] = (
    Landmark("IT Park", 10.3306, 123.9056, radius_km=0.5),
    Landmark("Ayala Center", 10.3181, 123.9056, radius_km=0.5),
    Landmark("Colon Street", 10.2970, 123.9020, radius_km=0.5),
    Landmark("USC Main", 10.3139, 123.8920, radius_km=0.5),
    Landmark("Pier / Port", 10.2925, 123.9160, radius_km=0.6),
    Landmark("Lahug", 10.3388, 123.8893, radius_km=0.8),
    Landmark("SM Seaside", 10.2712, 123.8795, radius_km=0.6),
    Landmark("Fuente Osmeña", 10.3105, 123.8921, radius_km=0.5),
    Landmark("Capitol Site", 10.3197, 123.8949, radius_km=0.5),
    Landmark("Banilad", 10.3480, 123.9095, radius_km=0.7),
    Landmark("Mabolo", 10.3215, 123.9175, radius_km=0.6),
    Landmark("Mandaue Crossing", 10.3378, 123.9410, radius_km=0.8),
    Landmark("Talamban", 10.3770, 123.9145, radius_km=1.0),
    Landmark("Downtown Cebu", 10.2950, 123.9000, radius_km=0.4),
    Landmark("Cebu Business Park", 10.3160, 123.9050, radius_km=0.4),
)


def nearest_landmark(lat: float, lng: float) -> Landmark:
    """Return the closest landmark; always returns something."""
    best = min(
        CEBU_LANDMARKS,
        key=lambda l: haversine_km(lat, lng, l.lat, l.lng),
    )
    return best


def landmark_for_centroid(lat: float, lng: float) -> tuple[str, float]:
    """Return (landmark_name, distance_km) for the nearest landmark."""
    lm = nearest_landmark(lat, lng)
    return lm.name, haversine_km(lat, lng, lm.lat, lm.lng)
