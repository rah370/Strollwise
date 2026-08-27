from __future__ import annotations

from sqlalchemy import text

from app.core import cache as cache_mod
from app.core import database as db_mod


def ping_database() -> bool:
    try:
        with db_mod.engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


def redis_status() -> str:
    """ok, unavailable, or skipped (client already disabled)."""
    try:
        client = cache_mod.get_client()
    except Exception:
        return "unavailable"
    if client is None:
        return "unavailable"
    try:
        client.ping()
        return "ok"
    except Exception:
        return "unavailable"


def health_payload(app_name: str, env: str) -> tuple[dict[str, str], int]:
    db_ok = ping_database()
    redis = redis_status()
    status = "ok" if db_ok else "degraded"
    code = 200 if db_ok else 503
    return (
        {
            "status": status,
            "app": app_name,
            "env": env,
            "database": "ok" if db_ok else "error",
            "redis": redis,
        },
        code,
    )
