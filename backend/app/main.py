"""StrollWise API entry point (thesis / defence map).

Three clients talk to this FastAPI app:

- Flutter traveler app (`frontend/`) — Explore, Add Tag, Feed, Trends, Profile
- React researcher console (`admin/`) — moderation, catalog, analytics
- Optional public health/legal pages on this same process

Data never goes traveler → traveler as GPS trails. A tag is stored as a
**report**, snapped to an **H3 cell** (resolution 8), then rolled into a
**place** (named Cebu footprint) and a **zone** (map polygon + traveler mix).
Public list endpoints return those aggregates, not other people's paths.

Pipeline after a tag is approved:
  ReportService → AggregationService → PlaceService → ZoneMergeService
"""
from __future__ import annotations

import logging
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.trustedhost import TrustedHostMiddleware
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from app.api.routers import (
    analytics,
    auth,
    cells,
    geocode,
    places,
    reports,
    uploads,
    users,
    zones,
)
from app.api.admin_docs import install_admin_docs
from app.api.routers.admin import router as admin_router
from app.core.config import settings
from app.core.health import health_payload
from app.core.logging import configure_logging
from app.core.rate_limit import RateLimitMiddleware

configure_logging()
log = logging.getLogger(__name__)

_LEGAL_DIR = Path(__file__).resolve().parent / "static" / "legal"


def _init_sentry() -> None:
    dsn = (settings.sentry_dsn or "").strip()
    if not dsn:
        return
    import sentry_sdk

    sentry_sdk.init(
        dsn=dsn,
        environment=settings.env,
        traces_sample_rate=0.1,
        send_default_pii=False,
    )


def create_app() -> FastAPI:
    settings.validate_for_launch()
    _init_sentry()

    docs_url = None if settings.is_production else "/docs"
    redoc_url = None if settings.is_production else "/redoc"
    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        description=(
            "Traveler and admin API for StrollWise in Metro Cebu. "
            "Public /docs is off in production. Signed-in admins: /api/v1/admin/docs. "
            "Written guide: backend/API.md."
        ),
        docs_url=docs_url,
        redoc_url=redoc_url,
        openapi_url=None if settings.is_production else "/openapi.json",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(RateLimitMiddleware)
    if settings.is_production:
        # TLS is terminated at Fly/Render. Do not HTTPS-redirect inside the
        # container or platform health checks on http://localhost fail.
        app.add_middleware(
            TrustedHostMiddleware,
            allowed_hosts=settings.trusted_host_list,
        )
    app.add_middleware(ProxyHeadersMiddleware, trusted_hosts="*")

    prefix = settings.api_v1_prefix
    app.include_router(auth.router, prefix=prefix)
    app.include_router(users.router, prefix=prefix)
    app.include_router(reports.router, prefix=prefix)
    app.include_router(zones.router, prefix=prefix)
    app.include_router(cells.router, prefix=prefix)
    app.include_router(places.router, prefix=prefix)
    app.include_router(analytics.router, prefix=prefix)
    app.include_router(uploads.router, prefix=prefix)
    app.include_router(geocode.router, prefix=prefix)
    app.include_router(admin_router, prefix=prefix)
    install_admin_docs(app)

    local_media = Path(settings.upload_local_dir)
    local_media.mkdir(parents=True, exist_ok=True)
    app.mount("/media", StaticFiles(directory=str(local_media)), name="media")

    @app.get("/", include_in_schema=False)
    def root() -> HTMLResponse:
        admin = "https://strollwise.onrender.com"
        return HTMLResponse(
            f"""<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>StrollWise API</title></head>
  <body style="font-family:system-ui;max-width:40rem;margin:3rem auto;padding:0 1rem">
    <h1>StrollWise API</h1>
    <p>This URL is the backend, not the website.</p>
    <p><a href="{admin}">Open the admin dashboard</a></p>
    <p>This is not a public developer portal. Live <code>/docs</code> is off.
    The written reference is <code>backend/API.md</code> in the StrollWise repo.
    Signed-in admins can open <a href="/api/v1/admin/docs">API docs</a> (JWT required).</p>
    <p><a href="/health">Health</a> · <a href="/privacy">Privacy</a> · <a href="/terms">Terms</a></p>
  </body>
</html>
"""
        )

    @app.get("/health", tags=["health"])
    def health_check() -> JSONResponse:
        body, code = health_payload(settings.app_name, settings.env)
        return JSONResponse(content=body, status_code=code)

    @app.get("/privacy", include_in_schema=False)
    def privacy_policy() -> FileResponse:
        return FileResponse(_LEGAL_DIR / "privacy.html", media_type="text/html")

    @app.get("/terms", include_in_schema=False)
    def terms_of_use() -> FileResponse:
        return FileResponse(_LEGAL_DIR / "terms.html", media_type="text/html")

    log.info("%s ready (env=%s)", settings.app_name, settings.env)
    return app


app = create_app()
