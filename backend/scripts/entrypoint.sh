#!/bin/sh
set -eu

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

echo "Running database migrations..."
alembic upgrade head

# Render (and most PaaS) inject $PORT. Fly typically leaves it unset.
PORT="${PORT:-8000}"
echo "Starting API on 0.0.0.0:${PORT}..."
# One worker: SSE live-sync is in-process. Do not scale workers.
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT}" --workers 1 --proxy-headers --forwarded-allow-ips='*'
