#!/bin/sh
set -eu

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

# Fail fast on a paused Supabase instead of hanging Render's port bind.
export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-10}"

echo "Running database migrations..."
# Do not block forever if Postgres is paused — otherwise Render never
# binds $PORT and testers only see "Application loading".
if command -v timeout >/dev/null 2>&1; then
  if ! timeout 45 alembic upgrade head; then
    echo "WARNING: alembic timed out or failed. Starting API so /health can report database status." >&2
  fi
else
  alembic upgrade head || echo "WARNING: alembic failed. Starting API so /health can report database status." >&2
fi

# Render (and most PaaS) inject $PORT. Fly typically leaves it unset.
PORT="${PORT:-8000}"
echo "Starting API on 0.0.0.0:${PORT}..."
# One worker: SSE live-sync is in-process. Do not scale workers.
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT}" --workers 1 --proxy-headers --forwarded-allow-ips='*'
