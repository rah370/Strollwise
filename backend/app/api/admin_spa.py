"""Serve the researcher console from the API image when admin_dist/ is present.

The dedicated Render static site for admin has been stuck on an old build.
Shipping the Vite dist with the API (which does redeploy) gives testers a
current console at /console/ on the same origin as /api/v1.
"""
from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, RedirectResponse, Response

_ADMIN_DIST = Path(__file__).resolve().parents[2] / "admin_dist"


def admin_dist_dir() -> Path | None:
    if (_ADMIN_DIST / "index.html").is_file():
        return _ADMIN_DIST
    return None


def install_admin_spa(app: FastAPI) -> None:
    dist = admin_dist_dir()
    if dist is None:
        return
    root = dist.resolve()

    @app.get("/console", include_in_schema=False)
    def admin_console_redirect() -> RedirectResponse:
        return RedirectResponse(url="/console/", status_code=307)

    @app.get("/console/{full_path:path}", include_in_schema=False)
    def admin_console(full_path: str) -> Response:
        target = (root / full_path).resolve()
        if full_path and target.is_file() and target.is_relative_to(root):
            response = FileResponse(target)
        else:
            response = FileResponse(root / "index.html")
        if not full_path or full_path.endswith(".html") or not target.is_file():
            response.headers["Cache-Control"] = "no-store"
        return response
