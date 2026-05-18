"""Storage abstraction: R2 in production, local filesystem in development."""

import logging
from pathlib import Path

import boto3
from botocore.config import Config

from app.config import settings

logger = logging.getLogger(__name__)

LOCAL_UPLOAD_DIR = Path("uploads")


def _get_r2_client():
    return boto3.client(
        "s3",
        endpoint_url=f"https://{settings.r2_account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=settings.r2_access_key_id,
        aws_secret_access_key=settings.r2_secret_access_key,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )


async def upload_image(user_id: str, item_id: str, image_bytes: bytes, content_type: str = "image/png") -> str:
    """Upload processed image. Returns the storage key (path).

    Dev: saves to local uploads/ folder.
    Prod: uploads to R2 bucket.
    """
    key = f"users/{user_id}/items/{item_id}.png"

    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(image_bytes)
        logger.debug(f"Saved locally: {path}")
        return key

    client = _get_r2_client()
    client.put_object(
        Bucket=settings.r2_bucket_name,
        Key=key,
        Body=image_bytes,
        ContentType=content_type,
    )
    logger.info(f"Uploaded to R2: {key}")
    return key


def get_image_url(key: str) -> str:
    """Convert storage key to a relative URL.

    Returning a path-only URL lets the mobile client resolve it against
    whatever base URL it is using — localhost on macOS, the ngrok tunnel
    on a real device, the prod domain in production. This avoids baking
    `localhost:8000` into image URLs that a phone over cellular can't reach.
    """
    if settings.environment == "development":
        return f"/uploads/{key}"
    if settings.r2_public_url:
        return f"{settings.r2_public_url}/{key}"
    return f"/uploads/{key}"


async def delete_image(key: str) -> None:
    """Delete image from storage."""
    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        if path.exists():
            path.unlink()
        return

    client = _get_r2_client()
    client.delete_object(Bucket=settings.r2_bucket_name, Key=key)
    logger.info(f"Deleted from R2: {key}")
