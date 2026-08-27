"""Handles image uploads. Uses S3/R2 when configured, otherwise local disk in non-prod."""
from __future__ import annotations

import logging
import mimetypes
import uuid
from pathlib import Path

from fastapi import UploadFile

from app.core.config import settings

log = logging.getLogger(__name__)

ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
}
MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB


class UploadError(Exception):
    pass


class UploadService:
    def __init__(self) -> None:
        self.local_dir = Path(settings.upload_local_dir)
        self.local_dir.mkdir(parents=True, exist_ok=True)

    async def save(self, file: UploadFile) -> dict[str, str | int]:
        mime = file.content_type or mimetypes.guess_type(file.filename or "")[0] or "application/octet-stream"
        if mime not in ALLOWED_MIME_TYPES:
            raise UploadError(f"Unsupported file type: {mime}")
        extension = mimetypes.guess_extension(mime) or ".bin"
        filename = f"{uuid.uuid4().hex}{extension}"

        data = await file.read()
        if len(data) > MAX_UPLOAD_BYTES:
            raise UploadError("File exceeds the 10MB upload limit")

        if settings.s3_configured:
            return self._save_s3(filename, data, mime)
        if settings.is_production:
            raise UploadError(
                "Object storage is not configured. Set S3_BUCKET_NAME and credentials."
            )
        return self._save_local(filename, data, mime)

    def _save_local(self, filename: str, data: bytes, mime: str) -> dict[str, str | int]:
        path = self.local_dir / filename
        with open(path, "wb") as f:
            f.write(data)
        relative = f"/media/{filename}"
        base = settings.public_base_url.rstrip("/")
        file_url = f"{base}{relative}" if base else relative
        return {
            "file_url": file_url,
            "mime_type": mime,
            "size_bytes": len(data),
        }

    def _save_s3(self, filename: str, data: bytes, mime: str) -> dict[str, str | int]:
        try:
            import boto3
        except ImportError as exc:  # pragma: no cover
            raise UploadError("boto3 not installed for S3 uploads") from exc
        client_kwargs: dict[str, str] = {
            "region_name": settings.s3_region or "auto",
            "aws_access_key_id": settings.s3_access_key or "",
            "aws_secret_access_key": settings.s3_secret_key or "",
        }
        if settings.s3_endpoint_url:
            client_kwargs["endpoint_url"] = settings.s3_endpoint_url
        client = boto3.client("s3", **client_kwargs)
        key = f"uploads/{filename}"
        extra: dict[str, str] = {"ContentType": mime}
        client.put_object(
            Bucket=settings.s3_bucket_name,
            Key=key,
            Body=data,
            **extra,
        )
        url = self._public_object_url(key)
        return {"file_url": url, "mime_type": mime, "size_bytes": len(data)}

    def _public_object_url(self, key: str) -> str:
        public = (settings.s3_public_base_url or "").rstrip("/")
        if public:
            return f"{public}/{key}"
        if settings.s3_endpoint_url:
            raise UploadError("S3_PUBLIC_BASE_URL is required when using a custom S3 endpoint")
        return f"https://{settings.s3_bucket_name}.s3.{settings.s3_region}.amazonaws.com/{key}"
