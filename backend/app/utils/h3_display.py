"""H3 cell indexes → map-ready polygon rings for zones and places."""
from __future__ import annotations

from collections.abc import Iterable

from app.core.config import settings
from app.services import h3_service


def close_ring(ring: list[list[float]]) -> list[list[float]]:
    if not ring:
        return []
    if ring[0] == ring[-1]:
        return ring
    return [*ring, ring[0]]


def display_h3_rings(source_indexes: Iterable[str] | None) -> list[list[list[float]]]:
    """Expand stored cells to finer display hexes and return closed [lng, lat] rings."""
    source = [idx for idx in (source_indexes or []) if idx]
    if not source:
        return []

    target_resolution = min(settings.h3_resolution + 1, 10)
    try:
        display_indexes = h3_service.expand_cells(source, target_resolution)
    except Exception:
        display_indexes = source

    unique = list(dict.fromkeys(display_indexes))
    if len(unique) > 600:
        unique = unique[:600]

    return [close_ring(h3_service.cell_to_lnglat_ring(idx)) for idx in unique]
