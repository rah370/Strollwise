"""Idempotent seed script for StrollWise.

Creates:
- 20–50 demo users across traveler types
- 300–1000 realistic reports clustered around Cebu City districts
- Runs aggregation, classification, and zone merging end-to-end so the
  demo frontend has immediately useful data.

Usage:
    PYTHONPATH=backend python backend/seed.py
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

# Make `app.*` importable whether seed.py is run from repo root or backend/.
BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from datetime import datetime, timedelta, timezone

from faker import Faker
from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models import (
    AuditLog,
    H3CellAggregate,
    Media,
    MergedZone,
    Report,
    SavedZone,
    User,
    ZoneSnapshot,
)
from app.services import h3_service
from app.services.aggregation_service import AggregationService
from app.services.zone_merge_service import ZoneMergeService

fake = Faker()
random.seed(7)
Faker.seed(7)

# Clustered districts in Cebu City. Each entry drives a realistic signal mix.
CITY_DISTRICTS = [
    {
        "name": "IT Park",
        "center": (10.3306, 123.9056),
        "radius": 0.0032,
        "traveler_bias": "mixed",
        "categories": ["food", "nightlife", "activity", "shopping"],
        "tags": ["food", "cafe", "bar", "office", "study", "coworking", "nightlife"],
        "notes": [
            "Food crawl and office crowd around Sugbo Mercado.",
            "Great cafe and study spots after work.",
            "Night activity builds around restaurants and bars.",
        ],
        "peak_hours": [18, 19, 20, 21, 22],
    },
    {
        "name": "Ayala Center",
        "center": (10.3181, 123.9056),
        "radius": 0.003,
        "traveler_bias": "mixed",
        "categories": ["shopping", "food", "activity", "nightlife"],
        "tags": ["shopping", "mall", "food", "cafe", "office", "restaurant"],
        "notes": [
            "Balanced local and visitor shopping flow.",
            "Cafe, restaurant, and mall activity stays visible all day.",
            "Commercial zone with reliable food and transport access.",
        ],
        "peak_hours": [12, 16, 17, 18, 19],
    },
    {
        "name": "Colon Street",
        "center": (10.2970, 123.9020),
        "radius": 0.003,
        "traveler_bias": "local",
        "categories": ["food", "transport", "shopping", "activity"],
        "tags": ["street_food", "jeepney", "market", "heritage", "shopping", "local_food"],
        "notes": [
            "Daytime heritage walk mixes with shopping and street food.",
            "Local-heavy movement around Carbon, Basilica, and Colon.",
            "Budget food and errands are strongest during the day.",
        ],
        "peak_hours": [9, 10, 11, 14, 15],
    },
    {
        "name": "Carbon Market",
        "center": (10.2944, 123.9006),
        "radius": 0.0025,
        "traveler_bias": "local",
        "categories": ["food", "shopping", "transport"],
        "tags": ["market", "wet_market", "street_food", "budget_meal", "local_food"],
        "notes": [
            "Wet market food and practical shopping cluster.",
            "Local errands and budget meals dominate the area.",
            "Street-oriented food behavior near Carbon.",
        ],
        "peak_hours": [6, 7, 8, 9, 10],
    },
    {
        "name": "USC / Student Area",
        "center": (10.3139, 123.8920),
        "radius": 0.002,
        "traveler_bias": "local",
        "categories": ["school", "food", "activity"],
        "tags": ["student", "university", "cafe", "library", "study", "budget_meal"],
        "notes": [
            "Student budget meals and study hubs near campus.",
            "Cafe and after-class movement is visible in the afternoon.",
            "Mostly local student activity around USC.",
        ],
        "peak_hours": [12, 13, 15, 16, 17],
    },
    {
        "name": "USC Talamban",
        "center": (10.3545, 123.9139),
        "radius": 0.003,
        "traveler_bias": "local",
        "categories": ["school", "food", "transport"],
        "tags": ["student", "campus", "study", "cafe", "commute", "budget_meal"],
        "notes": [
            "Campus edge movement with study cafes and cheap meals.",
            "Student commute and budget-food pattern.",
        ],
        "peak_hours": [7, 12, 16, 17, 18],
    },
    {
        "name": "Pier / Port Area",
        "center": (10.2925, 123.9160),
        "radius": 0.003,
        "traveler_bias": "mixed",
        "categories": ["transport", "safety", "issue"],
        "tags": ["port", "terminal", "transport", "safety"],
        "notes": [
            "Transport pressure and safety awareness near the port.",
            "Terminal activity changes with departure schedules.",
        ],
        "peak_hours": [7, 8, 16, 17, 18],
    },
    {
        "name": "Lahug Residential",
        "center": (10.3388, 123.8893),
        "radius": 0.004,
        "traveler_bias": "local",
        "categories": ["activity", "food"],
        "tags": ["residential", "quiet", "neighborhood", "carinderia"],
        "notes": [
            "Mostly local neighborhood behavior with quiet side streets.",
            "Small eateries and residential movement dominate.",
        ],
        "peak_hours": [7, 12, 18, 19],
    },
    {
        "name": "SM Seaside",
        "center": (10.2712, 123.8795),
        "radius": 0.003,
        "traveler_bias": "international",
        "categories": ["shopping", "food", "activity"],
        "tags": ["mall", "shopping", "food", "family", "walking", "dining"],
        "notes": [
            "Weekend family shopping, dining, and walking flow.",
            "Large mall activity with mixed local and visitor traffic.",
        ],
        "peak_hours": [14, 15, 16, 17, 18],
    },
    {
        "name": "Fuente Osmeña",
        "center": (10.3105, 123.8921),
        "radius": 0.002,
        "traveler_bias": "local",
        "categories": ["transport", "food", "shopping", "nightlife"],
        "tags": ["commute", "jeepney", "food", "bbq", "shopping", "larsian"],
        "notes": [
            "Evening commute, Larsian food, and shopping overlap.",
            "Local-heavy transit and food behavior around Fuente.",
        ],
        "peak_hours": [17, 18, 19, 20, 21],
    },
    {
        "name": "Busay / Tops",
        "center": (10.3700, 123.8780),
        "radius": 0.004,
        "traveler_bias": "international",
        "categories": ["activity", "food", "other"],
        "tags": ["sightseeing", "coffee", "mountain_drive", "photo_spot", "sunset"],
        "notes": [
            "Sunset sightseeing, mountain cafes, and photo stops.",
            "Tourist-heavy nature escape route above the city.",
        ],
        "peak_hours": [16, 17, 18],
    },
    {
        "name": "Cebu Taoist Temple",
        "center": (10.3410, 123.8885),
        "radius": 0.0025,
        "traveler_bias": "international",
        "categories": ["activity", "other"],
        "tags": ["sightseeing", "photo_spot", "culture", "quiet", "walking"],
        "notes": [
            "Daytime cultural viewpoint with city views and quiet walking.",
            "Visitor-friendly sightseeing stop above Lahug.",
        ],
        "peak_hours": [9, 10, 11, 14, 15],
    },
    {
        "name": "Sirao Flower Garden",
        "center": (10.3940, 123.8680),
        "radius": 0.004,
        "traveler_bias": "international",
        "categories": ["activity", "other"],
        "tags": ["sightseeing", "photo_spot", "nature", "mountain_drive", "weekend"],
        "notes": [
            "Photo stops and mountain-drive behavior around the flower garden.",
            "Weekend nature escape with tourist-heavy movement.",
        ],
        "peak_hours": [10, 11, 14, 15, 16],
    },
    {
        "name": "Mactan Resort Area",
        "center": (10.2983, 124.0155),
        "radius": 0.006,
        "traveler_bias": "international",
        "categories": ["activity", "food", "nightlife"],
        "tags": ["resort", "beach", "seafood", "buffet", "diving", "nightlife"],
        "notes": [
            "Tourist resort behavior around beaches, seafood, and leisure.",
            "Afternoon resort activity turns into evening food and nightlife.",
        ],
        "peak_hours": [14, 15, 16, 17, 19],
    },
    {
        "name": "Magellan's Cross / Basilica",
        "center": (10.2939, 123.9015),
        "radius": 0.0018,
        "traveler_bias": "international",
        "categories": ["activity", "food", "shopping"],
        "tags": ["heritage", "museum", "sightseeing", "local_food", "walking"],
        "notes": [
            "Heritage walking route between Basilica, Magellan's Cross, and food stops.",
            "Visitor sightseeing mixes with downtown local movement.",
        ],
        "peak_hours": [9, 10, 11, 13, 14],
    },
    {
        "name": "Fort San Pedro",
        "center": (10.2927, 123.9058),
        "radius": 0.002,
        "traveler_bias": "international",
        "categories": ["activity", "other"],
        "tags": ["heritage", "museum", "waterfront", "sightseeing", "walking"],
        "notes": [
            "Historic fort stop connected to the downtown heritage trail.",
            "Museum and waterfront movement near the port edge.",
        ],
        "peak_hours": [9, 10, 14, 15, 16],
    },
    {
        "name": "South Bus Terminal",
        "center": (10.3001, 123.8931),
        "radius": 0.0025,
        "traveler_bias": "local",
        "categories": ["transport", "food", "issue"],
        "tags": ["bus", "terminal", "budget_meal", "commute", "budget_travel"],
        "notes": [
            "Budget traveler and local commute behavior around bus departures.",
            "Cheap food and transit pressure near the terminal.",
        ],
        "peak_hours": [5, 6, 7, 16, 17],
    },
    {
        "name": "Mango Avenue",
        "center": (10.3123, 123.8976),
        "radius": 0.0025,
        "traveler_bias": "mixed",
        "categories": ["nightlife", "food", "activity"],
        "tags": ["nightlife", "bar", "food", "late_night", "social"],
        "notes": [
            "Nightlife and food corridor with visible late-night movement.",
            "Mixed locals and visitors for social hangouts.",
        ],
        "peak_hours": [20, 21, 22, 23],
    },
    {
        "name": "IL Corso / SRP",
        "center": (10.2665, 123.8812),
        "radius": 0.004,
        "traveler_bias": "mixed",
        "categories": ["food", "activity", "shopping"],
        "tags": ["family", "walking", "dining", "seaside", "weekend"],
        "notes": [
            "Weekend family walking and seaside dining pattern.",
            "Relaxed SRP activity with food stops and group movement.",
        ],
        "peak_hours": [15, 16, 17, 18, 19],
    },
]


def clear_tables(db: Session) -> None:
    """Delete everything except users in the correct FK order."""
    db.execute(delete(ZoneSnapshot))
    db.execute(delete(SavedZone))
    db.execute(delete(AuditLog))
    db.execute(delete(Media))
    db.execute(delete(MergedZone))
    db.execute(delete(H3CellAggregate))
    db.execute(delete(Report))
    db.execute(delete(User))
    db.commit()


def seed_users(db: Session, count: int = 30) -> list[User]:
    users: list[User] = []
    traveler_types = ["local", "international", "mixed", "resident", "student", "visitor"]
    for i in range(count):
        email = f"demo{i}@example.com"
        user = User(
            email=email,
            password_hash=hash_password("supersecret123"),
            display_name=fake.name(),
            traveler_type=random.choice(traveler_types),
            nationality=random.choice(["PH", "US", "JP", "KR", "AU", "GB", "DE", None]),
            age_range=random.choice(["18-24", "25-34", "35-44", "45-54"]),
        )
        db.add(user)
        users.append(user)
    db.commit()
    for u in users:
        db.refresh(u)
    return users


def seed_reports(db: Session, users: list[User], target_count: int = 600) -> list[Report]:
    reports: list[Report] = []
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    weight = len(CITY_DISTRICTS) * 20
    for _ in range(target_count):
        district = random.choices(
            CITY_DISTRICTS,
            weights=[weight - i for i in range(len(CITY_DISTRICTS))],
            k=1,
        )[0]
        lat_center, lng_center = district["center"]
        r = district["radius"]
        lat = lat_center + random.uniform(-r, r)
        lng = lng_center + random.uniform(-r, r)
        category = random.choice(district["categories"])
        tags = random.sample(district["tags"], k=min(len(district["tags"]), random.randint(1, 3)))

        # Traveler bias: 70% chance to match district bias, 30% other.
        if random.random() < 0.7:
            traveler_type = district["traveler_bias"]
        else:
            traveler_type = random.choice(["local", "international", "mixed"])

        peak_hours = district.get("peak_hours") or list(range(24))
        day_offset = random.randint(0, 5)
        hour = random.choice(peak_hours if random.random() < 0.75 else list(range(24)))
        created_at = (now - timedelta(days=day_offset)).replace(
            hour=hour,
            minute=random.randint(0, 59),
            second=0,
            microsecond=0,
        )
        h3_index = h3_service.latlng_to_cell(lat, lng, 8)

        user = random.choice(users)
        report = Report(
            user_id=user.id,
            h3_index=h3_index,
            resolution=8,
            latitude_raw=lat,
            longitude_raw=lng,
            category=category,
            tags_json=tags,
            note_text=random.choice(district.get("notes", [None])),
            source_type="user",
            traveler_type_snapshot=traveler_type,
            visibility_status="visible",
            created_at=created_at,
            updated_at=created_at,
        )
        db.add(report)
        reports.append(report)
    db.commit()
    return reports


def recompute_aggregates_and_zones(db: Session, reports: list[Report]) -> None:
    unique_indexes = {r.h3_index for r in reports}
    AggregationService(db).recompute_cells(unique_indexes)
    db.commit()
    ZoneMergeService(db).rebuild_all()


def main() -> None:
    with SessionLocal() as db:
        print("Clearing existing seed data…")
        clear_tables(db)

        print("Seeding users…")
        users = seed_users(db, count=30)

        print("Seeding reports…")
        reports = seed_reports(db, users, target_count=600)

        print("Recomputing aggregates + publishing per-cell zones…")
        recompute_aggregates_and_zones(db, reports)

        zone_count = db.query(MergedZone).count()
        cell_count = db.query(H3CellAggregate).count()
        print(
            f"Seeded {len(users)} users, {len(reports)} reports, "
            f"{cell_count} H3 cells, {zone_count} map zones."
        )


if __name__ == "__main__":
    main()
