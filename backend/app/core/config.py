from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_JWT_SECRET = "change-me-in-production"
_LOCAL_ORIGINS = (
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
)


class Settings(BaseSettings):
    """Env + `.env` configuration. Admin Settings can overlay the pending-* keys.

    Spatial: `h3_resolution` (8) and `max_h3_cells_per_place`.
    Privacy: `pending_min_reports_per_cell` (distinct people) and
    `pending_agreement_ratio` (same category).
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = Field(default="StrollWise API")
    env: str = Field(default="development")
    debug: bool = Field(default=True)
    api_v1_prefix: str = Field(default="/api/v1")

    database_url: str = Field(
        default="postgresql+psycopg2://strollwise:strollwise@localhost:5432/strollwise"
    )
    redis_url: str = Field(default="redis://localhost:6379/0")

    jwt_secret_key: str = Field(default=DEFAULT_JWT_SECRET)
    jwt_algorithm: str = Field(default="HS256")
    access_token_expire_minutes: int = Field(default=60 * 24 * 7)

    h3_resolution: int = Field(default=8)
    # Cap how many H3 cells can expand a place/zone footprint (prevents city-wide blobs).
    max_h3_cells_per_place: int = Field(default=24)
    city_center_lat: float = Field(default=10.3157)
    city_center_lng: float = Field(default=123.8854)

    mapbox_access_token: str | None = Field(default=None)
    mapbox_style: str = Field(default="mapbox/streets-v12")

    cache_ttl_zones_seconds: int = Field(default=60)
    cache_ttl_zone_feed_seconds: int = Field(default=25)
    cache_ttl_pulse_seconds: int = Field(default=120)
    pending_cache_ttl_seconds: int = Field(default=900)
    # Minimum distinct people (unique reporters) in the same H3 cell before it
    # can form / go public, plus category agreement in report_service.
    pending_min_reports_per_cell: int = Field(default=3)
    pending_agreement_ratio: float = Field(default=0.6)
    # Per-user anti-spam on POST /reports (0 disables that guard).
    report_cooldown_hours_per_cell: int = Field(default=24)
    report_max_per_user_per_hour: int = Field(default=30)

    s3_bucket_name: str | None = Field(default=None)
    s3_access_key: str | None = Field(default=None)
    s3_secret_key: str | None = Field(default=None)
    s3_region: str = Field(default="us-east-1")
    s3_endpoint_url: str | None = Field(default=None)
    s3_public_base_url: str | None = Field(default=None)
    upload_local_dir: str = Field(default="/tmp/strollwise-uploads")
    public_base_url: str = Field(default="")

    cors_origins: str = Field(default=",".join(_LOCAL_ORIGINS))
    trusted_hosts: str = Field(default="localhost,127.0.0.1,testserver")
    sentry_dsn: str | None = Field(default=None)

    rate_limit_enabled: bool = Field(default=True)
    rate_limit_auth_per_minute: int = Field(default=10)
    rate_limit_reports_per_minute: int = Field(default=20)
    rate_limit_geocode_per_minute: int = Field(default=30)

    smtp_host: str | None = Field(default=None)
    smtp_port: int = Field(default=587)
    smtp_user: str | None = Field(default=None)
    smtp_password: str | None = Field(default=None)
    smtp_from: str | None = Field(default=None)
    resend_api_key: str | None = Field(default=None)
    password_reset_minutes: int = Field(default=15)
    # When true, forgot-password JSON includes the code so local tests work
    # without a mailbox. Production with SMTP/Resend leaves this false.
    password_reset_echo_code: bool = Field(default=False)

    @property
    def is_production(self) -> bool:
        return self.env.lower() in {"production", "prod"}

    @property
    def s3_configured(self) -> bool:
        return bool(self.s3_bucket_name and self.s3_access_key and self.s3_secret_key)

    @property
    def cors_origin_list(self) -> list[str]:
        raw = self.cors_origins.strip()
        if not raw or raw == "*":
            return list(_LOCAL_ORIGINS)
        origins = [origin.strip() for origin in raw.split(",") if origin.strip()]
        return origins if origins else ["http://localhost:5173"]

    @property
    def trusted_host_list(self) -> list[str]:
        hosts = [h.strip() for h in self.trusted_hosts.split(",") if h.strip()]
        return hosts or ["localhost", "127.0.0.1", "testserver"]

    def validate_for_launch(self) -> None:
        """Refuse to boot a public API with development defaults."""
        if not self.is_production:
            return
        if self.debug:
            raise RuntimeError("DEBUG must be false when ENV=production")
        secret = (self.jwt_secret_key or "").strip()
        if not secret or secret == DEFAULT_JWT_SECRET:
            raise RuntimeError(
                "JWT_SECRET_KEY must be a strong unique secret when ENV=production"
            )
        origins = self.cors_origin_list
        public_origins = [
            origin
            for origin in origins
            if "localhost" not in origin and "127.0.0.1" not in origin
        ]
        if not public_origins:
            raise RuntimeError(
                "CORS_ORIGINS must list public admin/app HTTPS origins when ENV=production"
            )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
