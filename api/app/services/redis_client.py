"""Async Redis client singleton.

Used by: rate limiter, ARQ task queue, caching.
"""

import logging

import redis.asyncio as aioredis

from app.config import settings

logger = logging.getLogger(__name__)

_redis: aioredis.Redis | None = None


async def init_redis() -> None:
    """Initialize the Redis connection pool. Call from lifespan startup."""
    global _redis
    logger.info("Connecting to Redis at %s", settings.redis_url)
    _redis = aioredis.from_url(
        settings.redis_url,
        encoding="utf-8",
        decode_responses=True,
        max_connections=20,
    )
    # Verify connectivity
    await _redis.ping()
    logger.info("Redis connection ready")


async def close_redis() -> None:
    """Close the Redis connection pool. Call from lifespan shutdown."""
    global _redis
    if _redis:
        await _redis.close()
        _redis = None
        logger.info("Redis connection closed")


async def get_redis() -> aioredis.Redis:
    """Get the shared Redis client. Raises if not initialized."""
    if _redis is None:
        raise RuntimeError("Redis not initialized. Call init_redis() first.")
    return _redis
