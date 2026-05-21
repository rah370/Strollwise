"""Reference zone catalog for Cebu metro (behavioral defaults)."""
from __future__ import annotations

from dataclasses import dataclass

from app.utils.traveler_gradient import local_ratio_from_traveler_mix


@dataclass(frozen=True)
class ZoneCatalogEntry:
    zone_id: str
    zone_name: str
    city: str
    zone_type: str  # LOCAL | INTERNATIONAL | MIXED
    radius_km: float
    center_lat: float
    center_lng: float
    characteristics: tuple[str, ...]
    default_local_ratio: float


def _ratio_for_type(zone_type: str, *, mixed_default: float = 0.5) -> float:
    zt = zone_type.upper()
    if zt == "LOCAL":
        return 1.0
    if zt == "INTERNATIONAL":
        return 0.0
    return mixed_default


CEBU_ZONE_CATALOG: tuple[ZoneCatalogEntry, ...] = (
    ZoneCatalogEntry(
        "Z001", "Talamban", "Cebu City", "LOCAL", 3.0, 10.3550, 123.9180,
        ("residential", "schools", "daily_commute", "local_businesses"),
        _ratio_for_type("LOCAL"),
    ),
    ZoneCatalogEntry(
        "Z002", "Pardo", "Cebu City", "LOCAL", 4.0, 10.2815, 123.8450,
        ("community_area", "public_transport", "residential", "local_markets"),
        0.88,
    ),
    ZoneCatalogEntry(
        "Z003", "Minglanilla Proper", "Minglanilla", "LOCAL", 5.0, 10.2441, 123.7964,
        ("suburban", "residential", "local_activity", "routine_movement"),
        0.90,
    ),
    ZoneCatalogEntry(
        "Z004", "Talisay Residential Area", "Talisay", "LOCAL", 3.0, 10.2447, 123.8494,
        ("housing", "schools", "daily_life", "community_services"),
        0.87,
    ),
    ZoneCatalogEntry(
        "Z005", "Mactan Resort Zone", "Lapu-Lapu City", "INTERNATIONAL", 6.0,
        10.2995, 124.0118,
        ("resorts", "hotels", "airport_access", "foreign_visitors"),
        _ratio_for_type("INTERNATIONAL"),
    ),
    ZoneCatalogEntry(
        "Z006", "Colon Basilica Heritage Zone", "Cebu City", "INTERNATIONAL", 2.0,
        10.2943, 123.9018,
        ("heritage_sites", "tourism", "historical_landmarks", "guided_tours"),
        0.18,
    ),
    ZoneCatalogEntry(
        "Z007", "IT Park Business Zone", "Cebu City", "INTERNATIONAL", 2.0,
        10.3305, 123.9066,
        ("digital_nomads", "business_travelers", "hotels", "nightlife"),
        0.22,
    ),
    ZoneCatalogEntry(
        "Z008", "SRP Tourism Belt", "Cebu City", "INTERNATIONAL", 4.0,
        10.2867, 123.8805,
        ("tourist_destinations", "entertainment", "large_events", "visitor_activity"),
        0.15,
    ),
    ZoneCatalogEntry(
        "Z009", "Ayala Center Cebu", "Cebu City", "MIXED", 3.0, 10.3176, 123.9053,
        ("shopping", "offices", "tourists", "locals"),
        0.55,
    ),
    ZoneCatalogEntry(
        "Z010", "Fuente Osmeña", "Cebu City", "MIXED", 2.0, 10.3099, 123.8915,
        ("hotels", "hospitals", "restaurants", "transport_hub"),
        0.52,
    ),
    ZoneCatalogEntry(
        "Z011", "SM City Cebu", "Cebu City", "MIXED", 3.0, 10.3113, 123.9180,
        ("shopping", "ferry_passengers", "locals", "tourists"),
        0.48,
    ),
    ZoneCatalogEntry(
        "Z012", "Carbon Market Area", "Cebu City", "MIXED", 2.5, 10.2932, 123.8997,
        ("local_market", "heritage", "tourist_interest", "commercial_activity"),
        0.58,
    ),
)

_BY_NAME: dict[str, ZoneCatalogEntry] = {
    e.zone_name.lower(): e for e in CEBU_ZONE_CATALOG
}


def catalog_entry_for_name(display_name: str) -> ZoneCatalogEntry | None:
    key = display_name.lower().strip()
    if key in _BY_NAME:
        return _BY_NAME[key]
    for entry in CEBU_ZONE_CATALOG:
        name = entry.zone_name.lower()
        if name in key or key in name:
            return entry
    return None


def default_local_ratio_for_name(
    display_name: str,
    traveler_mix: str,
    local_presence_percent: float = 0.0,
) -> float:
    entry = catalog_entry_for_name(display_name)
    if entry is not None:
        return entry.default_local_ratio
    return local_ratio_from_traveler_mix(
        traveler_mix,
        local_presence_percent=local_presence_percent or None,
    )
