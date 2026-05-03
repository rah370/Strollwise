# StrollWise Backend

FastAPI + PostgreSQL (PostGIS) + Redis backend for StrollWise, a
crowd-sourced travel intelligence platform. H3 is used internally as the
spatial framework for aggregating user activity into merged, frontend-ready
zones (Local Area, Tourist Area, Food Hotspot, Student Area, etc.).

## Tech stack

- Python 3.11+
- FastAPI 0.115
- SQLAlchemy 2.x + Alembic
- PostgreSQL 16 with PostGIS
- Redis 7
- h3-py 4.x
- Passlib (bcrypt) + python-jose (JWT)
- Pytest, Ruff, Faker

## Layout

```
backend/
  app/
    core/            config, database, security, cache, logging
    api/
      deps.py        FastAPI dependencies (auth, db session)
      routers/       auth / users / reports / zones / analytics / uploads
    models/          SQLAlchemy models + enums
    schemas/         Pydantic request/response models
    repositories/    thin query layer
    services/        business logic: H3, aggregation, classification, merging…
    workers/         task stubs ready to move to Celery/RQ
    utils/           time/geo/enum helpers
    main.py          FastAPI app factory
  alembic/           migrations
  tests/             pytest suite
  seed.py            idempotent demo seeder for Cebu City districts
  docker/            container entrypoint
  Dockerfile
```

## Quick start (Docker)

```bash
cp backend/.env.example backend/.env        # optional: edit values
docker compose up --build
# Run migrations + seed demo data in a second terminal:
docker compose exec api alembic upgrade head
docker compose exec api python seed.py
```

The API is available at `http://localhost:8000` (`/docs` for the OpenAPI
Swagger UI). Health check is `GET /health`.

## Local development (without Docker)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export $(grep -v '^#' .env.example | xargs)
alembic upgrade head
python seed.py
uvicorn app.main:app --reload
```

You will need PostgreSQL with PostGIS + Redis running locally. The
easiest way is `docker compose up db redis` and leaving the API process on
your machine.

## Environment variables

See `.env.example`. Highlights:

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | SQLAlchemy URL for Postgres/PostGIS |
| `REDIS_URL` | Redis URL for zone and pulse caching |
| `JWT_SECRET_KEY` | HMAC secret for access tokens |
| `H3_RESOLUTION` | Base H3 resolution (8 for MVP) |
| `CACHE_TTL_ZONES_SECONDS` | `/zones` response TTL |
| `S3_*` | Optional S3 credentials for `/uploads/image` |

## Migrations

```bash
alembic revision -m "add column foo" --autogenerate
alembic upgrade head
alembic downgrade -1
```

## Seed data

```bash
python seed.py
```

Seeds ~30 users and ~600 reports clustered around Cebu City districts
(IT Park, Ayala, Colon, USC, Port, Lahug, SM Seaside, Fuente Osmeña)
and runs the full aggregation + classification + merge pipeline.

## Tests

```bash
cd backend
pytest -q
```

Tests boot the app against in-memory SQLite and stub out PostGIS-only
column types so no Postgres instance is required.

## API overview (`/api/v1/...`)

| Method | Path | Description |
| --- | --- | --- |
| POST | `/auth/register` | Create account, returns JWT |
| POST | `/auth/login` | Exchange email+password for JWT |
| GET  | `/auth/me` | Current user |
| GET  | `/users/me` | Current user |
| PATCH | `/users/me` | Update profile |
| GET  | `/users/me/saved-zones` | List saved zones |
| POST | `/users/me/saved-zones/{zone_id}` | Save a zone |
| DELETE | `/users/me/saved-zones/{zone_id}` | Remove a saved zone |
| POST | `/reports` | Submit a geo-tagged report |
| GET  | `/reports/feed` | Recent global feed |
| GET  | `/reports/by-zone/{zone_id}` | Reports belonging to a zone |
| GET  | `/zones` | **Main map endpoint** — viewport-filtered zones, with optional `filter`, `user_lat`, `user_lng` |
| GET  | `/zones/{zone_id}` | Detailed zone view |
| GET  | `/zones/{zone_id}/nearby` | Nearby zones |
| GET  | `/analytics/city-pulse` | City-level activity summary |
| GET  | `/analytics/trends` | Function-type distribution |
| GET  | `/analytics/zone/{zone_id}/history` | Zone snapshot series |
| POST | `/uploads/image` | Upload an image (JWT required) |

## How the pipeline works

1. `POST /reports` receives the payload, validates it, and converts
   `latitude/longitude` into an H3 index at `H3_RESOLUTION`.
2. The raw report is persisted to `reports`.
3. `AggregationService.recompute_cells` rebuilds aggregates for the cell
   and its 1-ring neighbors, running `ClassificationService` to assign
   `behavior_type` and `function_type`.
4. `ZoneMergeService.recompute_near` performs a BFS over similar adjacent
   cells and writes merged polygons to `merged_zones`.
5. Zones and the city pulse are cached in Redis; `POST /reports` busts
   `zones:vp:*` and `city:pulse:*` to keep the map in sync.

## Caching

- `/zones` is cached by quantized viewport bbox + zoom + filter for
  `CACHE_TTL_ZONES_SECONDS` seconds.
- `/analytics/city-pulse` is cached for `CACHE_TTL_PULSE_SECONDS` seconds.
- Cache is invalidated synchronously on report submission and whenever
  `ZoneMergeService` rebuilds zones.
