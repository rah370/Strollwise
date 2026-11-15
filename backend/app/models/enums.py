"""Controlled vocabulary used across reports, cells, places, and zones.

Defence talking points:

- `TravelerType` / `user_type` classify *who tagged* (local vs visitor).
- `BehaviorType` / `traveler_mix` classify *who uses the area*.
- `FunctionType` / `place_type` classify *what the area is for* (food, school…).
- `VisibilityStatus` is the privacy gate: pending tags stay off the public map
  until enough distinct people agree.
"""
from __future__ import annotations

from enum import Enum


class TravelerType(str, Enum):
    LOCAL = "local"
    INTERNATIONAL = "international"
    MIXED = "mixed"
    RESIDENT = "resident"
    STUDENT = "student"
    VISITOR = "visitor"


class BehaviorType(str, Enum):
    LOCAL_AREA = "local_area"
    TOURIST_AREA = "tourist_area"
    MIXED_AREA = "mixed_area"


class FunctionType(str, Enum):
    FOOD_HOTSPOT = "food_hotspot"
    STUDENT_AREA = "student_area"
    BUSY_ZONE = "busy_zone"
    TRANSPORT_ZONE = "transport_zone"
    COMMERCIAL_ZONE = "commercial_zone"
    RESIDENTIAL_ZONE = "residential_zone"
    SAFETY_CONCERN = "safety_concern"
    TOURIST_HOTSPOT = "tourist_hotspot"
    EMERGING_ZONE = "emerging_zone"
    UNKNOWN = "unknown"


class ReportCategory(str, Enum):
    FOOD = "food"
    ACTIVITY = "activity"
    CROWD = "crowd"
    SAFETY = "safety"
    TRANSPORT = "transport"
    SCHOOL = "school"
    ISSUE = "issue"
    SHOPPING = "shopping"
    NIGHTLIFE = "nightlife"
    OTHER = "other"


class LiveStatus(str, Enum):
    QUIET_NOW = "quiet_now"
    ACTIVE_NOW = "active_now"
    BUSY_NOW = "busy_now"
    PEAK_NOW = "peak_now"
    CAUTION_NOW = "caution_now"


class VisibilityStatus(str, Enum):
    PENDING = "pending"
    VISIBLE = "visible"
    HIDDEN = "hidden"
    FLAGGED = "flagged"
    REMOVED = "removed"


class SourceType(str, Enum):
    USER = "user"
    SYSTEM = "system"
    IMPORT = "import"
