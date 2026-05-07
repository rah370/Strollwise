# StrollWise

StrollWise is a crowd-sourced travel intelligence app. It uses **H3** hex cells to aggregate reports and movement signals into **merged, map-ready zones** (local vs tourist mix, function types like food hotspots, and similar) without exposing individual trajectories in public APIs.

## Repository layout

| Path | Stack | Role |
| --- | --- | --- |
| `frontend/` | Flutter 3 (Dart ^3.11), **Riverpod**, **go_router**, **Dio**, **MapLibre** (+ `flutter_map`, `h3_flutter`, **geolocator**) | Mobile app: auth, hex map explore, feed, tag submission, layers/analytics, profile |
| `backend/` | **FastAPI**, SQLAlchemy 2, **Alembic**, PostgreSQL **PostGIS**, **Redis**, **h3-py**, JWT | REST API under `/api/v1`, aggregation, classification, zone merge pipeline |
| `docker-compose.yml` | PostGIS 16, Redis 7, API container | Local stack: DB, cache, API on port **8000** |

Detailed backend notes (env vars, full route table, caching): [`backend/README.md`](backend/README.md).

## What is implemented

**Backend (`/api/v1/…`)**

- **Auth:** register, login, current user (`/auth/…`, `/auth/me`).
- **Users:** profile, saved zones (`/users/me`, saved-zone CRUD).
- **Reports:** create report, global feed, reports by merged zone (`/reports`, `/reports/feed`, `/reports/by-zone/{zone_id}`).
- **Zones:** viewport listing, zone detail, nearby zones, **current zone** overview for the user location (`/zones`, `/zones/{zone_id}`, `/zones/{zone_id}/nearby`, `/zones/current`).
- **Analytics:** city pulse, trends, per-zone history (`/analytics/…`).
- **Uploads:** image upload when S3 is configured (`/uploads/image`).

**Flutter app**

- **Routing:** `go_router` starts at **`/auth`** (login/register against the API), then a bottom shell with **Explore**, **Add tag**, **Feed**, **Layers/Trends**, **Profile** (`/explore`, `/add-tag`, `/feed`, `/layers`, `/profile`).
- **API base:** `ApiConstants.baseUrl` from `--dart-define=API_URL=…` (default `http://localhost:8000`) + path prefix **`/api/v1`** (see `frontend/lib/core/constants/api_constants.dart`).

**Data & ops**

- **Alembic** migrations run automatically when the API container starts (`backend/docker/entrypoint.sh`).
- Optional **`SEED_ON_BOOT=true`** for compose to run `seed.py` on startup; otherwise seed manually (below).
- Idempotent **`backend/seed.py`**: demo users (roughly 20–50) and hundreds of synthetic reports around **Cebu City** districts, then full aggregation → classification → merge.

## Prerequisites

- Docker with Compose v2 (`docker compose`)
- For local Flutter only: Flutter SDK matching `frontend/pubspec.yaml` (Dart ^3.11), Xcode/Android toolchain as needed

## Local setup

### 1) API + PostGIS + Redis

From the repo root:

```bash
docker compose up --build
```

- API: [http://localhost:8000](http://localhost:8000)
- OpenAPI: [http://localhost:8000/docs](http://localhost:8000/docs)
- Health: `GET http://localhost:8000/health`

Compose wires **`DATABASE_URL`** / **`REDIS_URL`** inside the API service; it loads **`backend/.env.example`** by default. Copy to `backend/.env` if you want to override secrets or tuning (see [`backend/.env.example`](backend/.env.example)).

**Optional auto-seed on container start:**

```bash
SEED_ON_BOOT=true docker compose up --build
```

**Or seed after the stack is up:**

```bash
docker compose exec api python seed.py
```

### 2) Flutter app

```bash
cd frontend
flutter pub get
flutter run
```

**Pointing the app at the API**

- **Simulator/emulator on the same machine as Docker:** often `http://localhost:8000` works on iOS simulator; Android emulator typically needs the host loopback alias:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

- **Physical device:** use your machine’s LAN IP, e.g. `--dart-define=API_URL=http://192.168.1.x:8000`, and ensure the host firewall allows port 8000.

### 3) Backend without Docker (optional)

If you run Postgres+PostGIS and Redis yourself, follow [`backend/README.md`](backend/README.md) (`alembic upgrade head`, `uvicorn app.main:app --reload`, etc.).

## Tests

```bash
cd backend && pytest -q
```

## Privacy & API behavior

- Public map and feed payloads are **zone-level**; they do not expose raw trajectories.
- Reports store coordinates server-side for aggregation; public responses tie to **merged zone** / H3-derived identifiers as implemented in the services layer.

## Traveler mix (classification)

Heuristic used in classification (see backend services):

- **Local** if `local_count / total_count >= 0.70`
- **International** if `international_count / total_count >= 0.70`
- Otherwise **Mixed**

## Pipeline (short)

1. **`POST /api/v1/reports`** validates a submission and converts `latitude` / `longitude` to an H3 zone.
2. The report is stored as **pending**, then a batch validator checks duplicates, agreement, and approval thresholds.
3. If approved, pending reports are promoted to visible and the system recomputes zone counts and assigns classification.
4. Connected similar zones are merged into frontend-ready polygons and approved zone records are refreshed.
5. Explore renders only approved overlays; Redis keys for viewport/pulse are refreshed when publication changes zone outputs.

## Roadmap ideas

- Harden token storage on mobile (e.g. platform secure storage) and refresh-token flow if you add it server-side.
- Production object storage and moderation for `/uploads/image`.
- Map interaction polish (selection, hit-testing) and any first-run UX you add beyond the current auth gate.

For migration commands, S3 env vars, and the full route list, use **`backend/README.md`**.
