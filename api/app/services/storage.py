"""Storage abstraction: R2 in production, local filesystem in development."""

import logging
import uuid
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


SIGNED_URL_TTL_SEC = 3600


def user_owns_key(user_id: str, key: str) -> bool:
    """True when the object key is under this user's private prefix."""
    if not user_id or not key:
        return False
    return key.startswith(f"users/{user_id}/")


def get_image_url(key: str) -> str:
    """Convert a storage key to a client-fetchable URL.

    Development: path-only `/uploads/...` so the app can resolve against
    whatever API host it is using.

    Production: short-lived signed R2 URL. The bucket stays private —
    `R2_PUBLIC_URL` is never used for wardrobe, avatar, or try-on objects.
    """
    if not key:
        return ""
    if settings.environment == "development":
        return f"/uploads/{key}"
    ttl = getattr(settings, "signed_url_ttl_sec", SIGNED_URL_TTL_SEC) or SIGNED_URL_TTL_SEC
    client = _get_r2_client()
    return client.generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.r2_bucket_name, "Key": key},
        ExpiresIn=int(ttl),
    )


async def read_image_bytes(key: str) -> bytes:
    """Read image bytes from local storage or R2."""
    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        if not path.exists():
            raise FileNotFoundError(f"Image not found: {key}")
        return path.read_bytes()

    client = _get_r2_client()
    resp = client.get_object(Bucket=settings.r2_bucket_name, Key=key)
    return resp["Body"].read()


async def upload_try_on_photo(
    user_id: str, image_bytes: bytes, content_type: str = "image/jpeg"
) -> str:
    """Upload user's full-body try-on reference photo."""
    ext = "jpg" if "jpeg" in content_type else "png"
    key = f"users/{user_id}/try_on/photo.{ext}"

    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(image_bytes)
        return key

    client = _get_r2_client()
    client.put_object(
        Bucket=settings.r2_bucket_name,
        Key=key,
        Body=image_bytes,
        ContentType=content_type,
    )
    return key


async def upload_avatar_base(user_id: str, image_bytes: bytes) -> str:
    """Upload the transparent, segmented image used as the 2.5D avatar base."""
    key = f"users/{user_id}/avatar/base.png"

    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(image_bytes)
        return key

    client = _get_r2_client()
    client.put_object(
        Bucket=settings.r2_bucket_name,
        Key=key,
        Body=image_bytes,
        ContentType="image/png",
    )
    return key


async def upload_outfit_preview(
    user_id: str, outfit_id: str, image_bytes: bytes
) -> str:
    """Upload generated outfit visualization preview."""
    # New file each write so clients/CDN do not keep showing the previous look.
    key = f"users/{user_id}/outfits/{outfit_id}/preview-{uuid.uuid4().hex[:12]}.png"

    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(image_bytes)
        return key

    client = _get_r2_client()
    client.put_object(
        Bucket=settings.r2_bucket_name,
        Key=key,
        Body=image_bytes,
        ContentType="image/png",
    )
    return key


async def upload_try_on_session_ref(
    user_id: str, session_id: str, image_bytes: bytes, content_type: str = "image/jpeg"
) -> str:
    """Upload external outfit/garment reference for a try-on session."""
    ext = "jpg" if "jpeg" in content_type else "png"
    key = f"users/{user_id}/try_on/sessions/{session_id}/ref.{ext}"

    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(image_bytes)
        return key

    client = _get_r2_client()
    client.put_object(
        Bucket=settings.r2_bucket_name,
        Key=key,
        Body=image_bytes,
        ContentType=content_type,
    )
    return key


async def upload_try_on_session_result(
    user_id: str, session_id: str, image_bytes: bytes
) -> str:
    """Upload generated external try-on result."""
    key = f"users/{user_id}/try_on/sessions/{session_id}/result.png"

    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(image_bytes)
        return key

    client = _get_r2_client()
    client.put_object(
        Bucket=settings.r2_bucket_name,
        Key=key,
        Body=image_bytes,
        ContentType="image/png",
    )
    return key


async def delete_image(key: str) -> None:
    """Delete one object. Missing keys are a no-op so retries stay safe."""
    if not key:
        return
    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        if path.exists():
            path.unlink()
        return

    client = _get_r2_client()
    try:
        client.delete_object(Bucket=settings.r2_bucket_name, Key=key)
    except Exception:
        logger.warning("R2 delete skipped or failed for an object")
        return
    logger.info("Deleted from R2: %s", key)


async def delete_user_prefix(user_id: str) -> None:
    """Remove leftover objects under users/{user_id}/ after row cleanup."""
    if not user_id:
        return
    prefix = f"users/{user_id}/"
    if settings.environment == "development":
        root = LOCAL_UPLOAD_DIR / prefix
        if root.exists():
            for path in root.rglob("*"):
                if path.is_file():
                    path.unlink()
        return

    client = _get_r2_client()
    token = None
    while True:
        kwargs = {"Bucket": settings.r2_bucket_name, "Prefix": prefix}
        if token:
            kwargs["ContinuationToken"] = token
        resp = client.list_objects_v2(**kwargs)
        keys = [{"Key": obj["Key"]} for obj in resp.get("Contents") or []]
        if keys:
            client.delete_objects(
                Bucket=settings.r2_bucket_name,
                Delete={"Objects": keys, "Quiet": True},
            )
        if not resp.get("IsTruncated"):
            break
        token = resp.get("NextContinuationToken")
