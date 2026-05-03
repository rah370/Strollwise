"""Background task stubs.

In the MVP these are invoked synchronously from the request path, but they
are factored here so they can be moved to Celery/RQ with minimal churn.
"""
from __future__ import annotations

import logging
from collections.abc import Iterable
from datetime import date

from app.core.cache import cache_delete_pattern
from app.core.database import SessionLocal
from app.services.aggregation_service import AggregationService
from app.services.city_pulse_service import CityPulseService
from app.services.snapshot_service import SnapshotService
from app.services.zone_merge_service import ZoneMergeService

log = logging.getLogger(__name__)


def recompute_cell_task(h3_index: str) -> None:
    with SessionLocal() as db:
        AggregationService(db).recompute_cell(h3_index)
        db.commit()


def merge_zones_task(seed_indexes: Iterable[str]) -> None:
    seeds = list(seed_indexes)
    with SessionLocal() as db:
        ZoneMergeService(db).recompute_near(seeds)


def rebuild_all_zones_task() -> None:
    with SessionLocal() as db:
        ZoneMergeService(db).rebuild_all()


def update_city_pulse_task() -> None:
    with SessionLocal() as db:
        CityPulseService(db).compute()


def refresh_rankings_task() -> None:
    """Bust cached viewport + city-pulse responses so the next request
    recomputes rankings against the freshest aggregates.

    Ranking itself is computed on read (see `RankingService`), so we only
    need to drop the relevant cache keys here.
    """
    cleared_zones = cache_delete_pattern("zones:vp:*")
    cleared_pulse = cache_delete_pattern("city:pulse:*")
    log.info(
        "refresh_rankings_task: cleared %d zone viewports and %d pulse entries",
        cleared_zones,
        cleared_pulse,
    )


def generate_daily_snapshots_task(snapshot_date: date | None = None) -> int:
    """Capture a per-zone snapshot row for long-term analytics.

    Idempotent: repeated runs on the same date update in place.
    Returns the number of snapshots written.
    """
    with SessionLocal() as db:
        count = SnapshotService(db).snapshot_all_active(snapshot_date)
    log.info("generate_daily_snapshots_task wrote/updated %d snapshots", count)
    return count
