"""Admin-only OpenAPI / Swagger. Public /docs stays off in production."""
from __future__ import annotations

from urllib.parse import quote

from fastapi import Depends, FastAPI, Query
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.responses import HTMLResponse, JSONResponse
from sqlalchemy.orm import Session

from app.api.deps import oauth2_scheme, verify_admin_token
from app.core.config import settings
from app.core.database import get_db


def install_admin_docs(app: FastAPI) -> None:
    prefix = settings.api_v1_prefix

    def _require_admin(
        db: Session = Depends(get_db),
        bearer: str | None = Depends(oauth2_scheme),
        token: str | None = Query(default=None),
    ):
        return verify_admin_token(bearer or token or "", db)

    @app.get(f"{prefix}/admin/openapi.json", include_in_schema=False)
    def admin_openapi_json(_: object = Depends(_require_admin)) -> JSONResponse:
        return JSONResponse(app.openapi())

    @app.get(f"{prefix}/admin/docs", include_in_schema=False)
    def admin_swagger_ui(
        bearer: str | None = Depends(oauth2_scheme),
        token: str | None = Query(default=None),
        _: object = Depends(_require_admin),
    ) -> HTMLResponse:
        schema_url = f"{prefix}/admin/openapi.json"
        passed = token or bearer
        if passed:
            schema_url = f"{schema_url}?token={quote(passed, safe='')}"
        return get_swagger_ui_html(
            openapi_url=schema_url,
            title=f"{settings.app_name} (admin)",
            swagger_ui_parameters={"persistAuthorization": True},
        )
