"""Curated Cebu place footprints for cell → place assignment."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class CatalogPlace:
    slug: str
    display_name: str
    default_place_type: str
    polygon_geojson: dict[str, Any]
    tag_aliases: frozenset[str] = frozenset()


def _ring_from_bbox(
    min_lat: float, min_lng: float, max_lat: float, max_lng: float
) -> list[list[float]]:
    """Closed GeoJSON ring [lng, lat]."""
    return [
        [min_lng, min_lat],
        [max_lng, min_lat],
        [max_lng, max_lat],
        [min_lng, max_lat],
        [min_lng, min_lat],
    ]


def _ring_from_center(lat: float, lng: float, radius_deg: float) -> list[list[float]]:
    """Small square footprint around a district center (~street block scale)."""
    return _ring_from_bbox(
        lat - radius_deg,
        lng - radius_deg,
        lat + radius_deg,
        lng + radius_deg,
    )


def _polygon(ring: list[list[float]]) -> dict[str, Any]:
    return {"type": "Polygon", "coordinates": [ring]}


# More specific places first when testing point-in-polygon overlap.
CEBU_PLACE_CATALOG: tuple[CatalogPlace, ...] = (
    CatalogPlace(
        slug="uspf_campus",
        display_name="USPF campus",
        default_place_type="school",
        polygon_geojson=_polygon(
            _ring_from_bbox(10.3354, 123.9012, 10.3392, 123.9046)
        ),
        tag_aliases=frozenset(
            {"uspf", "uspf campus", "uspf_campus", "university of southern philippines"}
        ),
    ),
    CatalogPlace(
        slug="colon_street",
        display_name="Colon Street",
        default_place_type="commercial",
        polygon_geojson=_polygon(
            _ring_from_bbox(10.2955, 123.9005, 10.2985, 123.9035)
        ),
        tag_aliases=frozenset({"colon", "colon street"}),
    ),
    CatalogPlace(
        slug="it_park",
        display_name="IT Park",
        default_place_type="commercial",
        polygon_geojson=_polygon(
            _ring_from_bbox(10.3285, 123.9035, 10.3325, 123.9075)
        ),
        tag_aliases=frozenset({"it park", "it_park", "cebu it park"}),
    ),
    CatalogPlace(
        slug="ayala_center_cebu",
        display_name="Ayala Center Cebu",
        default_place_type="commercial",
        polygon_geojson=_polygon(
            _ring_from_bbox(10.3165, 123.9040, 10.3195, 123.9070)
        ),
        tag_aliases=frozenset({"ayala", "ayala center"}),
    ),
    CatalogPlace(
        slug="carbon_market",
        display_name="Carbon Market",
        default_place_type="food",
        polygon_geojson=_polygon(
            _ring_from_bbox(10.2930, 123.8995, 10.2960, 123.9018)
        ),
        tag_aliases=frozenset({"carbon", "carbon market"}),
    ),
    CatalogPlace(
        slug="fuente_osmena",
        display_name="Fuente Osmeña",
        default_place_type="transport",
        polygon_geojson=_polygon(
            _ring_from_bbox(10.3090, 123.8910, 10.3120, 123.8935)
        ),
        tag_aliases=frozenset({"fuente", "fuente osmena", "fuente osmeña"}),
    ),
    CatalogPlace(
        slug="lahug_residential",
        display_name="Lahug",
        default_place_type="residential",
        polygon_geojson=_polygon(_ring_from_center(10.3388, 123.8893, 0.004)),
        tag_aliases=frozenset({"lahug", "residential", "neighborhood"}),
    ),
    CatalogPlace(
        slug="usc_campus",
        display_name="USC Main Campus",
        default_place_type="school",
        polygon_geojson=_polygon(_ring_from_center(10.3139, 123.8920, 0.002)),
        tag_aliases=frozenset({"usc", "usc main", "university of san carlos"}),
    ),
    CatalogPlace(
        slug="usc_talamban",
        display_name="USC Talamban",
        default_place_type="school",
        polygon_geojson=_polygon(_ring_from_center(10.3545, 123.9139, 0.003)),
        tag_aliases=frozenset({"usc talamban", "talamban"}),
    ),
    CatalogPlace(
        slug="sm_seaside",
        display_name="SM Seaside",
        default_place_type="commercial",
        polygon_geojson=_polygon(_ring_from_center(10.2712, 123.8795, 0.003)),
        tag_aliases=frozenset({"sm seaside", "seaside", "il corso", "srp"}),
    ),
    CatalogPlace(
        slug="pier_port",
        display_name="Pier / Port Area",
        default_place_type="transport",
        polygon_geojson=_polygon(_ring_from_center(10.2925, 123.9160, 0.003)),
        tag_aliases=frozenset({"pier", "port", "terminal"}),
    ),
    CatalogPlace(
        slug="busay_tops",
        display_name="Busay / Tops",
        default_place_type="tourist",
        polygon_geojson=_polygon(_ring_from_center(10.3700, 123.8780, 0.004)),
        tag_aliases=frozenset({"busay", "tops", "temple of leah", "mountain"}),
    ),
    CatalogPlace(
        slug="taoist_temple",
        display_name="Cebu Taoist Temple",
        default_place_type="tourist",
        polygon_geojson=_polygon(_ring_from_center(10.3410, 123.8885, 0.0025)),
        tag_aliases=frozenset({"taoist", "taoist temple"}),
    ),
)


def catalog_by_slug(slug: str) -> CatalogPlace | None:
    for entry in CEBU_PLACE_CATALOG:
        if entry.slug == slug:
            return entry
    return None
