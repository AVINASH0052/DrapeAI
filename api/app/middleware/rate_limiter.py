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
}

DEFAULT_LIMIT = (100, 60)  # 100/min for general endpoints


def _match_path_limit(path: str) -> tuple[int, int]:
    """Match request path to rate limit. Returns (max_requests, window_seconds)."""
    for prefix, limit in PATH_LIMITS.items():
        if path.startswith(prefix):
            return limit
    return DEFAULT_LIMIT


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
        # Skip rate limiting for health checks and docs
        path = request.url.path
        if path in ("/health", "/docs", "/openapi.json"):
            return await call_next(request)

        # Get user identifier: prefer authenticated user, fallback to IP
        user_id = getattr(request.state, "user_id", None)
        if not user_id:
            user_id = f"ip:{request.client.host}" if request.client else "unknown"

        max_requests, window = _match_path_limit(path)

        # Try Redis first, fall back to in-memory
        redis = await _get_redis()
        if redis:
            allowed = await _check_rate_limit_redis(
                redis, user_id, path, max_requests, window
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
