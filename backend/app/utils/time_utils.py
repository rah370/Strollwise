from __future__ import annotations

from datetime import UTC, datetime


def utcnow() -> datetime:
    return datetime.now(UTC)


def hour_of(dt: datetime) -> int:
    return dt.astimezone(UTC).hour


def label_for_peak_hours(peak_hours: list[int]) -> str | None:
    if not peak_hours:
        return None
    bucket_counts = {"morning": 0, "midday": 0, "afternoon": 0, "evening": 0, "night": 0}
    for h in peak_hours:
        if 5 <= h < 11:
            bucket_counts["morning"] += 1
        elif 11 <= h < 14:
            bucket_counts["midday"] += 1
        elif 14 <= h < 17:
            bucket_counts["afternoon"] += 1
        elif 17 <= h < 22:
            bucket_counts["evening"] += 1
        else:
            bucket_counts["night"] += 1
    dominant = max(bucket_counts.items(), key=lambda kv: kv[1])
    return {
        "morning": "Mornings (6–11am)",
        "midday": "Midday (11am–2pm)",
        "afternoon": "Afternoons (2–5pm)",
        "evening": "Evenings (5–10pm)",
        "night": "Late night (10pm–5am)",
    }[dominant[0]]
