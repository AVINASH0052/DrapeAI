"""Firebase JWT verification."""

import time
import logging

import httpx
from jose import jwt, JWTError

from app.config import settings

logger = logging.getLogger(__name__)

# Cache Firebase public keys
_cached_keys: dict = {}
_keys_fetched_at: float = 0
KEYS_TTL = 3600  # 1 hour

FIREBASE_CERTS_URL = (
    "https://www.googleapis.com/robot/v1/metadata/x509/"
    "securetoken@system.gserviceaccount.com"
)


async def _fetch_firebase_keys() -> dict:
    global _cached_keys, _keys_fetched_at
    now = time.time()
    if _cached_keys and (now - _keys_fetched_at) < KEYS_TTL:
        return _cached_keys
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(FIREBASE_CERTS_URL)
        resp.raise_for_status()
        _cached_keys = resp.json()
        _keys_fetched_at = now
    logger.info("Refreshed Firebase public keys")
    return _cached_keys


async def verify_firebase_token(token: str) -> dict:
    """Verify Firebase JWT and return decoded claims.

    Returns dict with: user_id, email, phone_number, name, picture.
    Raises ValueError on invalid token.
    """
    # Dev mode: accept test token (never allowed in production)
    if settings.environment == "development" and token == "test-token":
        return {
            "user_id": "test-user-001",
            "email": "test@drapeai.app",
            "name": "Test User",
            "phone_number": None,
            "picture": None,
        }

    keys = await _fetch_firebase_keys()

    try:
        unverified_header = jwt.get_unverified_header(token)
    except JWTError:
        raise ValueError("Invalid token header")

    kid = unverified_header.get("kid")
    if kid not in keys:
        # Try refreshing keys once
        _cached_keys.clear()
        keys = await _fetch_firebase_keys()
        if kid not in keys:
            raise ValueError("Token key ID not found in Firebase keys")

    public_key = keys[kid]

    try:
        payload = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=settings.firebase_project_id,
            issuer=f"https://securetoken.google.com/{settings.firebase_project_id}",
        )
    except JWTError as e:
        raise ValueError(f"Token verification failed: {e}")

    return {
        "user_id": payload["sub"],
        "email": payload.get("email"),
        "phone_number": payload.get("phone_number"),
        "name": payload.get("name"),
        "picture": payload.get("picture"),
    }
