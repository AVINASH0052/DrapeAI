"""Image upload validation."""

from fastapi import HTTPException

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB

# Magic byte signatures
MAGIC_BYTES = {
    b"\xff\xd8\xff": "image/jpeg",
    b"\x89PNG\r\n\x1a\n": "image/png",
    b"RIFF": "image/webp",
}


def validate_image(content_type: str, file_bytes: bytes) -> None:
    """Validate image type, size, and magic bytes. Raises HTTPException on failure."""
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid image type: {content_type}. Allowed: JPEG, PNG, WebP, HEIC",
        )

    if len(file_bytes) > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=400, detail="Image too large. Maximum size is 10 MB.")

    if len(file_bytes) < 100:
        raise HTTPException(status_code=400, detail="Image file is too small or corrupt.")

    # Magic bytes check (skip for HEIC -- complex container format)
    if content_type != "image/heic":
        matched = any(file_bytes.startswith(sig) for sig in MAGIC_BYTES)
        if not matched:
            raise HTTPException(
                status_code=400,
                detail="File content does not match declared type.",
            )
