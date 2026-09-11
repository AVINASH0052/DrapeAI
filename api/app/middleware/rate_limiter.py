"""Rate limiter middleware — Redis-backed with in-memory fallback.

Uses Redis sorted sets for a sliding-window counter.  Consistent across
multiple uvicorn workers and Docker replicas.

Falls back to the original in-memory dict approach if Redis is unavailable
(e.g. dev mode without a Redis container).
"""

import time
import logging
from collections import defaultdict
from typing import Optional

from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)

# Rate limits: (max_requests, window_seconds)
PATH_LIMITS: dict[str, tuple[int, int]] = {
    "/items/upload":       (20, 60),     # 20/min — image upload is expensive (bg removal + vision)
    "/outfits/generate":   (10, 60),     # 10/min — LLM calls
    "/outfits/shuffle":    (30, 60),     # 30/min
    "/wardrobe/gaps":      (5, 60),      # 5/min — heavy-reasoning model
    "/try-on/":            (10, 60),
    "/avatar/":            (15, 60),
    "/waitlist":           (10, 60),
}

DEFAULT_LIMIT = (100, 60)  # 100/min for general endpoints


def _match_path_limit(path: str) -> tuple[int, int]:
    """Match request path to rate limit. Longer prefixes win."""
    if "/visualize" in path:
        return (20, 60)
    matched: tuple[int, int] | None = None
    matched_len = -1
    for prefix, limit in PATH_LIMITS.items():
        if path.startswith(prefix) and len(prefix) > matched_len:
            matched = limit
            matched_len = len(prefix)
    return matched or DEFAULT_LIMIT


_SKIP_PATHS = {"/health", "/ready", "/docs", "/openapi.json"}


async def _identity_for_request(request: Request) -> str:
    """Verified Firebase uid when a Bearer token is present, else client IP."""
    auth = request.headers.get("Authorization") or ""
    if auth.startswith("Bearer "):
        token = auth.split(" ", 1)[1]
        try:
            from app.auth.firebase import verify_firebase_token

            claims = await verify_firebase_token(token)
            uid = claims.get("user_id")
            if uid:
                return f"user:{uid}"
        except Exception:
            pass
    host = request.client.host if request.client else "unknown"
    return f"ip:{host}"


# ─── In-memory fallback (for dev / when Redis is down) ────────────────────────
_request_log: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
_request_count = 0
_CLEANUP_INTERVAL = 500


def _cleanup_stale(window: int = 120) -> None:
    """Remove entries older than the max window to prevent memory growth."""
    cutoff = time.time() - window
    stale_users = []
    for user_id, paths in _request_log.items():
        stale_paths = []
        for path, timestamps in paths.items():
            paths[path] = [t for t in timestamps if t > cutoff]
            if not paths[path]:
                stale_paths.append(path)
        for p in stale_paths:
            del paths[p]
        if not paths:
            stale_users.append(user_id)
    for u in stale_users:
        del _request_log[u]


async def _check_rate_limit_memory(user_id: str, path: str,
                                    max_requests: int, window: int) -> bool:
    """In-memory rate check. Returns True if request is allowed."""
    global _request_count
    now = time.time()
    cutoff = now - window
    timestamps = _request_log[user_id][path]
    _request_log[user_id][path] = [t for t in timestamps if t > cutoff]
    timestamps = _request_log[user_id][path]

    if len(timestamps) >= max_requests:
        return False

    timestamps.append(now)
    _request_count += 1
    if _request_count % _CLEANUP_INTERVAL == 0:
        _cleanup_stale()
    return True


# ─── Redis-backed sliding window ──────────────────────────────────────────────
async def _get_redis() -> Optional[object]:
    """Try to get the Redis client; return None if unavailable."""
    try:
        from app.services.redis_client import get_redis
        return await get_redis()
    except Exception:
        return None


async def _check_rate_limit_redis(redis, user_id: str, path: str,
                                   max_requests: int, window: int) -> bool:
    """Redis sorted-set sliding window. Returns True if request is allowed."""
    key = f"rl:{user_id}:{path}"
    now = time.time()
    cutoff = now - window

    pipe = redis.pipeline(transaction=True)
    # Remove expired entries
    pipe.zremrangebyscore(key, "-inf", cutoff)
    # Count remaining entries
    pipe.zcard(key)
    # Add current request
    pipe.zadd(key, {str(now): now})
    # Set key TTL so Redis auto-cleans
    pipe.expire(key, window + 10)
    results = await pipe.execute()

    current_count = results[1]  # zcard result
    if current_count >= max_requests:
        # Remove the entry we just added (request is denied)
        await redis.zrem(key, str(now))
        return False
    return True


# ─── Middleware ────────────────────────────────────────────────────────────────
class RateLimitMiddleware(BaseHTTPMiddleware):
    """Per-user rate limiting middleware.

    Extracts user ID from the request state (set by auth dependency) or
    falls back to IP-based limiting for unauthenticated endpoints.
    """

    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        if path in _SKIP_PATHS:
            return await call_next(request)

        user_id = await _identity_for_request(request)
        request.state.rate_limit_id = user_id
        max_requests, window = _match_path_limit(path)

        from app.config import settings

        redis = await _get_redis()
        if redis:
            try:
                allowed = await _check_rate_limit_redis(
                    redis, user_id, path, max_requests, window
                )
            except Exception:
                if settings.environment == "production":
                    raise HTTPException(
                        status_code=503,
                        detail="Service temporarily unavailable.",
                    )
                allowed = await _check_rate_limit_memory(
                    user_id, path, max_requests, window
                )
        elif settings.environment == "production":
            raise HTTPException(
                status_code=503,
                detail="Service temporarily unavailable.",
            )
        else:
            allowed = await _check_rate_limit_memory(
                user_id, path, max_requests, window
            )

        if not allowed:
            logger.warning(
                f"Rate limit exceeded: user={user_id}, path={path}, "
                f"limit={max_requests}/{window}s"
            )
            raise HTTPException(
                status_code=429,
                detail="Too many requests. Please slow down.",
                headers={"Retry-After": str(window)},
            )

        return await call_next(request)
