"""Async connection pool for PostgreSQL.

Tuned for 2 uvicorn workers × 20 max connections = 40 total,
well within Postgres's default max_connections=100.
"""

import asyncpg
import logging

from app.config import settings

logger = logging.getLogger(__name__)

_pool: asyncpg.Pool | None = None


async def _setup_connection(conn: asyncpg.Connection) -> None:
    """Per-connection setup callback.

    Sets statement_timeout to prevent runaway queries from holding
    connections indefinitely (e.g. complex gap analysis on huge wardrobes).
    """
    await conn.execute("SET statement_timeout = '30s'")


async def get_pool() -> asyncpg.Pool:
    global _pool
    if _pool is None:
        raise RuntimeError("Database pool not initialized. Call init_pool() first.")
    return _pool


async def init_pool() -> None:
    global _pool
    logger.info("Initializing database connection pool")
    _pool = await asyncpg.create_pool(
        dsn=settings.database_url,
        min_size=5,                         # Pre-warm 5 connections for fast cold starts
        max_size=20,                        # 20 per worker (2 workers = 40 total)
        command_timeout=30,                 # Per-query timeout
        max_inactive_connection_lifetime=300,  # Recycle idle connections after 5 min
        setup=_setup_connection,            # Per-connection setup
    )
    # Enable pgvector extension
    async with _pool.acquire() as conn:
        await conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
    logger.info("Database pool ready (min=5, max=20)")


async def close_pool() -> None:
    global _pool
    if _pool:
        await _pool.close()
        _pool = None
        logger.info("Database pool closed")
