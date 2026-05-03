# StrollWise

StrollWise is a crowd-sourced travel intelligence app that uses H3 hexagonal zoning to map how people move and interact in a city. Instead of relying on static POIs, it aggregates reports, traveler behavior, and activity patterns into privacy-aware hex zones.

## Repo Structure

- `frontend/` Flutter app (MapLibre + Riverpod + Dio)
- `backend/` FastAPI app (PostgreSQL + H3 aggregation + classification)
- `docker-compose.yml` local development stack (PostGIS, Redis, API)

## MVP Features Implemented

- Auth APIs (`/auth/register`, `/auth/login`, `/auth/me`)
- Explore map with H3 zone payloads (`/zones`, `/zones/{h3_index}`, neighbors)
- Report submission and feed (`/reports`, `/reports/feed`, `/reports/by-zone/{h3_index}`)
- User profile and saved zones (`/users/me`, saved zone routes)
- Analytics summary and trends
- H3 aggregation and zone classification service
- Synthetic seed data generation (`backend/seed.py`)
- Flutter tabs: Explore, Feed, Add Tag, Trends/Layers, Profile

## Local Setup

### 1) Start infrastructure + backend

```bash
docker compose up --build
```

API runs at [http://localhost:8000](http://localhost:8000)
Swagger docs at [http://localhost:8000/docs](http://localhost:8000/docs)

### 2) Seed development data

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python seed.py
```

### 3) Run Flutter app

```bash
cd frontend
flutter pub get
flutter run
```

For emulator/device connectivity, override API URL:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

## API Notes

- Public map/feed payloads are zone-level and do not expose individual trajectories.
- Reports store raw coordinates privately in backend storage and link public results to `h3_index`.
- Traveler classification:
  - Local if `local_count / total_count >= 0.70`
  - International if `international_count / total_count >= 0.70`
  - Else Mixed

## Seed Data

`backend/seed.py` creates:

- 40 synthetic users
- ~350 synthetic reports
- Multiple categories/tags and report time patterns
- Recomputed hex aggregates and zone snapshots

## Next Recommended Steps

- Add Alembic migration workflow and full PostGIS geometry columns
- Move auth token handling to secure storage in Flutter
- Add dedicated onboarding + auth screens connected to backend
- Implement precise map hit-testing for selected hex instead of first-result fallback
- Add media upload flow to S3 and moderation hooks
