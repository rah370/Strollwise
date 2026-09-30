"""In-memory per-IP rate limiter for a single API worker."""
from __future__ import annotations

import time
from collections import defaultdict, deque

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.core.config import settings

_WINDOW_SECONDS = 60


class InMemoryRateLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def reset(self) -> None:
        self._hits.clear()

    def allow(self, key: str, limit: int) -> bool:
        now = time.monotonic()
        bucket = self._hits[key]
        cutoff = now - _WINDOW_SECONDS
        while bucket and bucket[0] < cutoff:
            bucket.popleft()
        if len(bucket) >= limit:
            return False
        bucket.append(now)
        return True


limiter = InMemoryRateLimiter()


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client is not None:
        return request.client.host
    return "unknown"


def _limit_for_request(method: str, path: str) -> int | None:
    if method == "POST" and path in {"/api/v1/auth/register", "/api/v1/auth/login"}:
        return settings.rate_limit_auth_per_minute
    if method == "POST" and path.rstrip("/") == "/api/v1/reports":
        return settings.rate_limit_reports_per_minute
    if method == "GET" and path.startswith("/api/v1/geocode/forward"):
        return settings.rate_limit_geocode_per_minute
    if method == "POST" and path.startswith("/api/v1/admin/pipeline"):
        return 6
    return None


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        if not settings.rate_limit_enabled:
            return await call_next(request)
        limit = _limit_for_request(request.method, request.url.path)
        if limit is None:
            return await call_next(request)
        key = f"{request.method}:{request.url.path}:{_client_ip(request)}"
        if not limiter.allow(key, limit):
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. Try again in a minute."},
                headers={"Retry-After": "60"},
            )
        return await call_next(request)
