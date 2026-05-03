#!/usr/bin/env bash
set -euo pipefail

echo "Running Alembic migrations…"
alembic upgrade head

if [[ "${SEED_ON_BOOT:-false}" == "true" ]]; then
  echo "SEED_ON_BOOT=true — seeding demo data"
  python seed.py || echo "Seed failed, continuing"
fi

echo "Starting uvicorn…"
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers "${UVICORN_WORKERS:-2}"
