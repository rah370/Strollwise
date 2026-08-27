# Hosting StrollWise

Singapore-region layout for a public demo: FastAPI on Fly.io, Postgres+PostGIS on Supabase, optional Upstash Redis, Cloudflare R2 for photos, Cloudflare Pages for admin and Flutter web.

Suggested hostnames:

- `https://api.strollwise.app` — API
- `https://admin.strollwise.app` — operators
- `https://app.strollwise.app` — Flutter web

Keep **one** API process (`--workers 1`). Admin live-sync is in-memory SSE and will miss events across multiple workers.

## Accounts to create

1. Domain + Cloudflare DNS
2. [Supabase](https://supabase.com) project in **Singapore** (database only; keep FastAPI JWT auth)
3. [Fly.io](https://fly.io) (API)
4. [Cloudflare](https://dash.cloudflare.com) Pages + R2
5. Optional: [Upstash](https://upstash.com) Redis, [Mapbox](https://mapbox.com), [Sentry](https://sentry.io)
6. Mobile stores (phase 2): Apple Developer, Google Play Console

## 1. Database (Supabase + PostGIS)

1. Create a project in Singapore.
2. In SQL editor: `CREATE EXTENSION IF NOT EXISTS postgis;`
3. Enable **Point-in-time recovery** (Pro) or at least scheduled backups.
4. Copy the URI (Session pooler or direct `db.<ref>.supabase.co:5432`).
5. Set `DATABASE_URL` for SQLAlchemy:

```text
postgresql+psycopg2://postgres:<password>@db.<ref>.supabase.co:5432/postgres?sslmode=require
```

**Restore drill:** pick a backup in the Supabase dashboard, restore to a new project or branch, point a staging `DATABASE_URL` at it, run `alembic upgrade head` (should be a no-op), and `GET /health` until `"database": "ok"`.

Never run `backend/seed.py` here. It refuses `ENV=production` and the old bootstrap used to reset the demo admin password.

Create an operator:

```bash
cd backend
ADMIN_BOOTSTRAP_EMAIL=you@example.com ADMIN_BOOTSTRAP_PASSWORD='choose-a-long-password' \
  PYTHONPATH=. python3 scripts/create_admin.py
```

Or register in the app, then `PYTHONPATH=. python3 scripts/promote_admin.py you@example.com`.

## 2. Object storage (Cloudflare R2)

1. Create a bucket (e.g. `strollwise-uploads`).
2. Create an API token with Object Read & Write.
3. Optional: public custom domain `https://media.strollwise.app`.
4. API env:

```text
S3_BUCKET_NAME=strollwise-uploads
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
S3_REGION=auto
S3_ENDPOINT_URL=https://<accountid>.r2.cloudflarestorage.com
S3_PUBLIC_BASE_URL=https://media.strollwise.app
```

Production uploads fail closed if these are missing (no `file://` URLs).

## 3. Redis (optional)

Upstash TLS URL:

```text
REDIS_URL=rediss://default:<password>@<host>.upstash.io:6379
```

The API still serves if Redis is down; `/health` reports `"redis": "unavailable"`.

The container entrypoint runs `alembic upgrade head`, then uvicorn on `$PORT` (default `8000`) with **one worker**. Do not enable in-app HTTPS redirect — Fly and Render terminate TLS and health-check over HTTP.

## 4. API

### Render (free)

Free web services sleep after ~15 minutes of idle traffic; the first request after that can take 30–60 seconds.

1. Connect the GitHub repo in the Render dashboard.
2. Create a **Web Service**, Docker runtime, root directory `backend`, Dockerfile `./Dockerfile`.
3. Use the **free** instance type. Region `singapore` is closest to Cebu; the current Supabase project is Tokyo, so either region is fine.
4. Deploy from this hosting branch until it is merged to `main`.
5. Set:

```text
ENV=production
DEBUG=false
JWT_SECRET_KEY=<unique secret>
DATABASE_URL=postgresql+psycopg2://postgres.<ref>:<url-encoded-password>@aws-0-<region>.pooler.supabase.com:5432/postgres?sslmode=require
CORS_ORIGINS=https://<service>.onrender.com,https://<admin-host>
TRUSTED_HOSTS=localhost,127.0.0.1,.onrender.com
PUBLIC_BASE_URL=https://<service>.onrender.com
```

Use the **session** pooler (`:5432`), not transaction mode (`:6543`). Direct `db.<ref>.supabase.co` is IPv6-only and fails from some hosts.

Health: `GET https://<service>.onrender.com/health` should return `"database": "ok"`.

### Fly.io (paid / always-on)

From `backend/`:

```bash
fly auth login
fly apps create strollwise-api --org personal
fly regions set sin
fly secrets set \
  ENV=production \
  DEBUG=false \
  JWT_SECRET_KEY="$(openssl rand -hex 32)" \
  DATABASE_URL="postgresql+psycopg2://..." \
  REDIS_URL="rediss://..." \
  CORS_ORIGINS="https://admin.strollwise.app,https://app.strollwise.app" \
  TRUSTED_HOSTS="api.strollwise.app,localhost" \
  S3_BUCKET_NAME=... S3_ACCESS_KEY=... S3_SECRET_KEY=... \
  S3_REGION=auto \
  S3_ENDPOINT_URL=... \
  S3_PUBLIC_BASE_URL=... \
  MAPBOX_ACCESS_TOKEN=... \
  SENTRY_DSN=...
fly deploy
```

[`backend/fly.toml`](../backend/fly.toml) uses `force_https`, a `/health` check, and a single 512 MB machine. The image runs `alembic upgrade head` then uvicorn with **one worker** and proxy headers.

DNS: CNAME `api` → `<app>.fly.dev` (or `fly ips list` + A/AAAA).

Local container stack (not TLS): `docker compose up --build` from the repo root.

## 5. Admin and Flutter web (Cloudflare Pages)

Create two Pages projects: `strollwise-admin` and `strollwise-app`.

GitHub Actions in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) deploys on push to `main` when these secrets exist:

| Secret / variable | Purpose |
| --- | --- |
| `FLY_API_TOKEN` | API deploy |
| `CLOUDFLARE_API_TOKEN` | Pages deploy |
| `CLOUDFLARE_ACCOUNT_ID` | Pages deploy |
| `VITE_API_URL` (variable) | Admin build, default `https://api.strollwise.app` |
| `API_URL` (variable) | Flutter web build |
| `SENTRY_DSN_FLUTTER` (variable) | Optional |

Manual builds:

```bash
cd admin && VITE_API_URL=https://api.strollwise.app npm run build
# wrangler pages deploy dist --project-name=strollwise-admin

cd frontend
flutter build web --release \
  --dart-define=API_URL=https://api.strollwise.app \
  --dart-define=ENABLE_DEMO_LOGIN=false \
  --dart-define=SENTRY_DSN=https://...@sentry.io/... \
  --dart-define=SENTRY_ENVIRONMENT=production
# wrangler pages deploy build/web --project-name=strollwise-app
```

SPA fallback files: `admin/public/_redirects` and `frontend/web/_redirects`.

## 6. Legal, Sentry, backups

- Privacy: `GET https://api.strollwise.app/privacy`
- Terms: `GET https://api.strollwise.app/terms`
- Registration requires `accepted_research_consent: true`
- API Sentry: `SENTRY_DSN`
- Flutter Sentry: `--dart-define=SENTRY_DSN=...`
- OpenAPI (`/docs`) is **off** when `ENV=production`

## 7. Mobile stores (phase 2)

- Android `INTERNET` is in the main manifest. For Play, copy [`frontend/android/key.properties.example`](../frontend/android/key.properties.example) to `frontend/android/key.properties`, generate an upload keystore, and **never** commit it.
- iOS: set a development team in Xcode; localhost ATS exceptions stay for debug. Release talks HTTPS.
- Bundle ID: `com.strollwise.strollwise`
- Demo / offline login is **off** in release builds unless `ENABLE_DEMO_LOGIN=true`
- Privacy nutrition labels: location when in use; see the in-app privacy screen
- JWTs are stored with `flutter_secure_storage`

TestFlight / internal testing: build with `--dart-define=API_URL=https://api.strollwise.app` and a Mapbox token if you want geocoding.

## Launch checklist

- [ ] `ENV=production`, `DEBUG=false`, unique `JWT_SECRET_KEY`
- [ ] `CORS_ORIGINS` lists only public HTTPS admin/app origins
- [ ] R2 (or S3) configured
- [ ] Alembic applied via container start
- [ ] Real admin created; default `admin@strollwise.dev` / `admin123456` not used
- [ ] `/health` returns `"database": "ok"`
- [ ] Privacy and terms reachable
- [ ] Sentry receiving a test event
- [ ] Backup restore drill completed
- [ ] Mapbox token quota alerts
