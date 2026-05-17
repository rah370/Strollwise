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
)


def catalog_by_slug(slug: str) -> CatalogPlace | None:
    for entry in CEBU_PLACE_CATALOG:
        if entry.slug == slug:
            return entry
    return None
