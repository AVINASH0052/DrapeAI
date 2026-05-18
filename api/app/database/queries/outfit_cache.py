"""Outfit cache queries. Key: (user_id, date, occasion). TTL: 24 hours."""

import json
import asyncpg


async def get_cached_outfits(
    conn: asyncpg.Connection, user_id: str, occasion: str
) -> list[dict] | None:
    row = await conn.fetchrow(
        """
        SELECT result FROM outfit_cache
        WHERE user_id = $1 AND occasion = $2 AND cache_date = CURRENT_DATE
          AND created_at > NOW() - INTERVAL '24 hours'
        """,
        user_id,
        occasion,
    )
    if row:
        return json.loads(row["result"])
    return None


async def set_cached_outfits(
    conn: asyncpg.Connection, user_id: str, occasion: str, outfits: list[dict]
) -> None:
    await conn.execute(
        """
        INSERT INTO outfit_cache (user_id, occasion, cache_date, result, created_at)
        VALUES ($1, $2, CURRENT_DATE, $3, NOW())
        ON CONFLICT (user_id, occasion, cache_date)
        DO UPDATE SET result = $3, created_at = NOW()
        """,
        user_id,
        occasion,
        json.dumps(outfits, default=str),
    )


async def invalidate_user_cache(conn: asyncpg.Connection, user_id: str) -> None:
    """Call when user adds/removes/edits items."""
    await conn.execute("DELETE FROM outfit_cache WHERE user_id = $1", user_id)
