"""In-memory rate limiter middleware.

Limits requests per-user (using Firebase UID) with configurable rates per endpoint.
Uses a sliding-window counter approach. Lightweight; no Redis needed for < 1,000 MAU.
"""

import time
import logging
from collections import defaultdict

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

# In-memory store: {user_id: {path_prefix: [(timestamp, ...)]}}
_request_log: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))

# Cleanup interval: prune stale entries every N requests
_request_count = 0
_CLEANUP_INTERVAL = 500


def _match_path_limit(path: str) -> tuple[int, int]:
    """Match request path to rate limit. Returns (max_requests, window_seconds)."""
    for prefix, limit in PATH_LIMITS.items():
        if path.startswith(prefix):
            return limit
    return DEFAULT_LIMIT


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


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Per-user rate limiting middleware.

    Extracts user ID from the request state (set by auth dependency) or
    falls back to IP-based limiting for unauthenticated endpoints.
    """

    async def dispatch(self, request: Request, call_next):
        global _request_count

        # Skip rate limiting for health checks and docs
        path = request.url.path
        if path in ("/health", "/docs", "/openapi.json"):
            return await call_next(request)

        # Get user identifier: prefer authenticated user, fallback to IP
        # The auth dependency sets request.state.user_id when it runs
        user_id = getattr(request.state, "user_id", None)
        if not user_id:
            user_id = f"ip:{request.client.host}" if request.client else "unknown"

        max_requests, window = _match_path_limit(path)
        now = time.time()
        cutoff = now - window

        # Get request timestamps for this user+path
        timestamps = _request_log[user_id][path]
        # Remove expired timestamps
        _request_log[user_id][path] = [t for t in timestamps if t > cutoff]
        timestamps = _request_log[user_id][path]

        if len(timestamps) >= max_requests:
            logger.warning(
                f"Rate limit exceeded: user={user_id}, path={path}, "
                f"requests={len(timestamps)}/{max_requests} in {window}s"
            )
            raise HTTPException(
                status_code=429,
                detail="Too many requests. Please slow down.",
                headers={"Retry-After": str(window)},
            )

        # Record this request
        timestamps.append(now)

        # Periodic cleanup
        _request_count += 1
        if _request_count % _CLEANUP_INTERVAL == 0:
            _cleanup_stale()

        return await call_next(request)
