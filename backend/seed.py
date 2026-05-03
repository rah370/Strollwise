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

from datetime import UTC, datetime, timedelta

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
        "radius": 0.004,
        "traveler_bias": "mixed",
        "categories": ["food", "nightlife", "activity", "transport"],
        "tags": ["food", "cafe", "bar", "office", "shopping"],
    },
    {
        "name": "Ayala Center",
        "center": (10.3181, 123.9056),
        "radius": 0.003,
        "traveler_bias": "international",
        "categories": ["shopping", "food", "activity"],
        "tags": ["shopping", "mall", "food", "cafe"],
    },
    {
        "name": "Colon Street",
        "center": (10.2970, 123.9020),
        "radius": 0.003,
        "traveler_bias": "local",
        "categories": ["food", "transport", "shopping", "issue"],
        "tags": ["street_food", "jeepney", "market", "crowd"],
    },
    {
        "name": "USC / Student Area",
        "center": (10.3139, 123.8920),
        "radius": 0.002,
        "traveler_bias": "local",
        "categories": ["school", "food", "activity"],
        "tags": ["student", "university", "cafe", "library"],
    },
    {
        "name": "Pier / Port Area",
        "center": (10.2925, 123.9160),
        "radius": 0.003,
        "traveler_bias": "mixed",
        "categories": ["transport", "safety", "issue"],
        "tags": ["port", "terminal", "transport", "safety"],
    },
    {
        "name": "Lahug Residential",
        "center": (10.3388, 123.8893),
        "radius": 0.004,
        "traveler_bias": "local",
        "categories": ["activity", "food"],
        "tags": ["residential", "quiet", "neighborhood"],
    },
    {
        "name": "SM Seaside",
        "center": (10.2712, 123.8795),
        "radius": 0.003,
        "traveler_bias": "international",
        "categories": ["shopping", "food", "activity"],
        "tags": ["mall", "shopping", "food"],
    },
    {
        "name": "Fuente Osmeña",
        "center": (10.3105, 123.8921),
        "radius": 0.002,
        "traveler_bias": "mixed",
        "categories": ["activity", "food", "nightlife"],
        "tags": ["park", "cafe", "coffee"],
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
        email = f"demo{i}@strollwise.test"
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
    now = datetime.now(UTC)
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

        created_at = now - timedelta(
            hours=random.randint(0, 60), minutes=random.randint(0, 59)
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
            note_text=random.choice([
                None,
                "Lively during the day.",
                "Busy terminal, watch your belongings.",
                "Great coffee and study spots.",
                "Affordable street food options.",
            ]),
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

        print("Recomputing aggregates + merging zones…")
        recompute_aggregates_and_zones(db, reports)

        zone_count = db.query(MergedZone).count()
        cell_count = db.query(H3CellAggregate).count()
        print(
            f"Seeded {len(users)} users, {len(reports)} reports, "
            f"{cell_count} H3 cells, {zone_count} merged zones."
        )


if __name__ == "__main__":
    main()
