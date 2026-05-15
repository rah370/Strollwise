from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration loaded from environment variables."""

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

    jwt_secret_key: str = Field(default="change-me-in-production")
    jwt_algorithm: str = Field(default="HS256")
    access_token_expire_minutes: int = Field(default=60 * 24 * 7)

    h3_resolution: int = Field(default=8)
    city_center_lat: float = Field(default=10.3157)
    city_center_lng: float = Field(default=123.8854)

    cache_ttl_zones_seconds: int = Field(default=60)
    cache_ttl_zone_feed_seconds: int = Field(default=25)
    cache_ttl_pulse_seconds: int = Field(default=120)
    pending_cache_ttl_seconds: int = Field(default=900)
    # Require more than 5 pins in the same H3 cell before approval (same-cell
    # quorum plus category agreement ratio in report_service).
    pending_min_reports_per_cell: int = Field(default=6)
    pending_agreement_ratio: float = Field(default=0.6)

    s3_bucket_name: str | None = Field(default=None)
    s3_access_key: str | None = Field(default=None)
    s3_secret_key: str | None = Field(default=None)
    s3_region: str = Field(default="us-east-1")
    upload_local_dir: str = Field(default="/tmp/strollwise-uploads")

    cors_origins: str = Field(default="*")

    @property
    def cors_origin_list(self) -> list[str]:
        raw = self.cors_origins.strip()
        if raw == "*" or not raw:
            return ["*"]
        return [origin.strip() for origin in raw.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
