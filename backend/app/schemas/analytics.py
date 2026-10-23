from __future__ import annotations

from datetime import date

from pydantic import BaseModel, Field


class CityPulse(BaseModel):
    city_activity: str
    crowd_level_percent: float
    local_presence_percent: float
    peak_time_window: str | None = None
    top_active_categories: list[str] = Field(default_factory=list)
    active_zone_count: int = 0


class TrendPoint(BaseModel):
    label: str
    value: float


class TrendSeries(BaseModel):
    key: str
    title: str
    points: list[TrendPoint]


class ZoneHistoryPoint(BaseModel):
    snapshot_date: date
    crowd_level: float
    local_presence_percent: float
    confidence_score: float
    report_count: int


class ZoneHistory(BaseModel):
    zone_id: str
    points: list[ZoneHistoryPoint]


class CategoryTrend(BaseModel):
    category: str
    label: str
    current_count: int
    previous_count: int
    delta: int
    growing: bool


class ZoneCategoryTrends(BaseModel):
    zone_id: str
    window_days: int
    current_total: int
    previous_total: int
    enough_data: bool
    min_sample: int
    peak_time_label: str | None = None
    categories: list[CategoryTrend] = Field(default_factory=list)
