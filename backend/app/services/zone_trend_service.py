from __future__ import annotations

from collections import Counter
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from app.repositories.report_repository import ReportRepository
from app.repositories.zone_repository import ZoneRepository
from app.schemas.analytics import CategoryTrend, ZoneCategoryTrends

_CATEGORY_LABELS = {
    "food": "Food",
    "transport": "Transport",
    "safety": "Safety",
    "school": "School",
    "crowd": "Busy",
    "commercial": "Commercial",
    "residential": "Residential",
    "tourist": "Tourist",
    "other": "Place",
}

MIN_SAMPLE_BY_WINDOW = {7: 4, 30: 8}


def _category_label(raw: str) -> str:
    key = (raw or "").strip().lower()
    return _CATEGORY_LABELS.get(key, key.replace("_", " ").title() or "Place")


def _peak_time_label(created_at: list[datetime]) -> str | None:
    if len(created_at) < 3:
        return None
    hours = []
    for stamp in created_at:
        local = stamp.astimezone(timezone.utc) if stamp.tzinfo else stamp.replace(tzinfo=timezone.utc)
        hours.append(local.hour)
    counts = Counter(hours)
    if not counts:
        return None
    top_hour = max(counts, key=lambda hour: (counts[hour], -hour))
    span = [hour for hour, count in counts.items() if count >= max(1, counts[top_hour] // 2)]
    start = min(span)
    end = max(span)
    end_exclusive = (end + 1) % 24

    def _fmt(hour: int) -> str:
        suffix = "AM" if hour < 12 else "PM"
        display = hour % 12
        if display == 0:
            display = 12
        return f"{display} {suffix}"

    if start == end:
        return _fmt(start)
    return f"{_fmt(start).replace(' AM', '').replace(' PM', '')}–{_fmt(end_exclusive)}"


def compute_zone_category_trends(
    db: Session,
    zone_id: UUID,
    *,
    window_days: int = 30,
) -> ZoneCategoryTrends | None:
    zone = ZoneRepository(db).get(zone_id)
    if zone is None:
        return None
    days = 7 if window_days <= 7 else 30
    min_sample = MIN_SAMPLE_BY_WINDOW[days]
    now = datetime.now(timezone.utc)
    current_start = now - timedelta(days=days)
    previous_start = now - timedelta(days=days * 2)
    h3_indexes = list(zone.source_h3_indexes_json or [])
    repo = ReportRepository(db)
    current = repo.count_visible_by_category_in_window(h3_indexes, current_start, now)
    previous = repo.count_visible_by_category_in_window(
        h3_indexes, previous_start, current_start
    )
    created = repo.list_visible_created_at_in_window(h3_indexes, current_start, now)
    keys = sorted(set(current) | set(previous))
    categories: list[CategoryTrend] = []
    for key in keys:
        curr = int(current.get(key, 0))
        prev = int(previous.get(key, 0))
        categories.append(
            CategoryTrend(
                category=key,
                label=_category_label(key),
                current_count=curr,
                previous_count=prev,
                delta=curr - prev,
                growing=curr > prev,
            )
        )
    categories.sort(key=lambda item: (item.growing, item.delta, item.current_count), reverse=True)
    current_total = sum(item.current_count for item in categories)
    previous_total = sum(item.previous_count for item in categories)
    peak = _peak_time_label(created) or zone.peak_time_label
    return ZoneCategoryTrends(
        zone_id=str(zone.zone_id),
        window_days=days,
        current_total=current_total,
        previous_total=previous_total,
        enough_data=current_total >= min_sample,
        min_sample=min_sample,
        peak_time_label=peak,
        categories=categories,
    )
