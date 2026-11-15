"""Building-scale sensitive sites: block the facility, not the street.

Ethics rule: hospitals, city hall, and police are tagged as *buildings*
(~40 m), not neighborhoods. Adjacent cafes and roads stay taggable.
Public overlays send kind + footprint only — never operational names.
`public_place_name` also strips facility identity from zone titles.
"""
from __future__ import annotations

from dataclasses import dataclass

from app.utils.geo_utils import haversine_km

PIN_ON_BUILDING_COPY = (
    "Tag the street or a public place next to this, not the {facility} itself."
)

# Place *identity* — not category "safety", and not "police nearby".
_IDENTITY_PHRASES = (
    "police station",
    "pnp",
    "camp sergio",
    "city hall",
    "city medical center",
    "cebu city medical",
    "hospital",
    "military camp",
    "jail",
    "precinct",
)


@dataclass(frozen=True)
class SensitiveSite:
    kind: str
    lat: float
    lng: float
    radius_m: float = 40.0
    facility_label: str = "building"

    def contains(self, lat: float, lng: float) -> bool:
        return haversine_km(lat, lng, self.lat, self.lng) * 1000.0 <= self.radius_m


# Verified building centroids (not neighborhood boxes).
SENSITIVE_SITES: tuple[SensitiveSite, ...] = (
    SensitiveSite(
        kind="hospital",
        lat=10.2970,
        lng=123.8915,
        facility_label="hospital",
    ),
    SensitiveSite(
        kind="government",
        lat=10.2930,
        lng=123.9018,
        facility_label="city hall",
    ),
    SensitiveSite(
        kind="police",
        lat=10.3118,
        lng=123.8918,
        facility_label="station",
    ),
)


def site_at(lat: float, lng: float) -> SensitiveSite | None:
    for site in SENSITIVE_SITES:
        if site.contains(lat, lng):
            return site
    return None


def pin_on_building_message(site: SensitiveSite) -> str:
    return PIN_ON_BUILDING_COPY.format(facility=site.facility_label)


def public_sites() -> list[dict[str, float | str]]:
    """Authenticated map overlay: kind + footprint, no operational names."""
    return [
        {
            "kind": site.kind,
            "lat": site.lat,
            "lng": site.lng,
            "radius_m": site.radius_m,
        }
        for site in SENSITIVE_SITES
    ]


def text_names_facility(text: str | None) -> bool:
    if not text:
        return False
    blob = " ".join(text.lower().replace("_", " ").split())
    return any(phrase in blob for phrase in _IDENTITY_PHRASES)


def tags_name_facility(tags: list[str] | None, note: str | None = None) -> bool:
    parts = list(tags or [])
    if note:
        parts.append(note)
    return any(text_names_facility(part) for part in parts)


def public_place_name(name: str | None, lat: float, lng: float) -> str:
    """Keep streets/cafes; never title a public place as the facility."""
    raw = (name or "").strip()
    if raw and not text_names_facility(raw):
        return raw
    from app.services.landmark_service import landmark_for_centroid

    landmark, _ = landmark_for_centroid(lat, lng)
    return landmark
