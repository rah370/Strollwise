"""Privacy-safe author labels for the public traveler feed.

Never emit emails, user ids, or raw GPS. Anonymous tags stay Local/Visitor.
Public tags may show a handle from display_name + city snapshot only.
"""
from __future__ import annotations

import re

from app.models.report import Report
from app.models.user import User

_SLUG = re.compile(r"[^a-z0-9]+")


def author_kind_for(report: Report) -> str:
    snapshot = (report.traveler_type_snapshot or "").strip().lower()
    if snapshot in {"international", "tourist", "visitor"}:
        return "visitor"
    user_type = (report.user_type_snapshot or "").strip().lower()
    if user_type == "international_visitor":
        return "visitor"
    return "local"


def feed_author_handle(report: Report, user: User | None) -> str:
    kind = author_kind_for(report)
    fallback = f"@{kind}"
    tags = {str(tag).strip().lower() for tag in (report.tags_json or [])}
    if "anonymous" in tags or "public" not in tags or user is None:
        return fallback
    raw = (user.display_name or "").strip()
    if not raw or "@" in raw:
        return fallback
    slug = _SLUG.sub("", raw.lower())[:16]
    if not slug:
        return fallback
    city = _SLUG.sub("", (report.city_of_origin_snapshot or "").lower())[:10]
    return f"@{slug}_{city}" if city else f"@{slug}"
