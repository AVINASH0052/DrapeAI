"""Lookbook database queries."""

import uuid
import asyncpg


async def create_lookbook(
    conn: asyncpg.Connection, user_id: str, name: str
) -> dict:
    row = await conn.fetchrow(
        "INSERT INTO lookbooks (id, user_id, name) VALUES ($1, $2, $3) RETURNING *",
        str(uuid.uuid4()),
        user_id,
        name,
    )
    return dict(row)


async def get_lookbooks(conn: asyncpg.Connection, user_id: str) -> list[dict]:
    rows = await conn.fetch(
        """
        SELECT l.*, COUNT(lo.outfit_id) as outfit_count
        FROM lookbooks l
        LEFT JOIN lookbook_outfits lo ON lo.lookbook_id = l.id
        WHERE l.user_id = $1
        GROUP BY l.id
        ORDER BY l.created_at DESC
        """,
        user_id,
    )
    return [dict(r) for r in rows]


async def get_lookbook_with_outfits(
    conn: asyncpg.Connection, lookbook_id: str, user_id: str
) -> dict | None:
    lb = await conn.fetchrow(
        "SELECT * FROM lookbooks WHERE id = $1 AND user_id = $2", lookbook_id, user_id
    )
    if not lb:
        return None

    outfits = await conn.fetch(
        """
        SELECT o.* FROM outfits o
        JOIN lookbook_outfits lo ON lo.outfit_id = o.id
        WHERE lo.lookbook_id = $1
        ORDER BY lo.added_at DESC
        """,
        lookbook_id,
    )
    result = dict(lb)
    result["outfits"] = [dict(o) for o in outfits]
    return result


async def add_outfit_to_lookbook(
    conn: asyncpg.Connection,
    lookbook_id: str,
    outfit_id: str,
    user_id: str,
) -> bool:
    lb = await conn.fetchrow(
        "SELECT id FROM lookbooks WHERE id = $1 AND user_id = $2", lookbook_id, user_id
    )
    outfit = await conn.fetchrow(
        "SELECT id FROM outfits WHERE id = $1 AND user_id = $2", outfit_id, user_id
    )
    if not lb or not outfit:
        return False

    await conn.execute(
        "INSERT INTO lookbook_outfits (lookbook_id, outfit_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        lookbook_id,
        outfit_id,
    )
    return True


async def remove_outfit_from_lookbook(
    conn: asyncpg.Connection,
    lookbook_id: str,
    outfit_id: str,
    user_id: str,
) -> bool:
    lb = await conn.fetchrow(
        "SELECT id FROM lookbooks WHERE id = $1 AND user_id = $2", lookbook_id, user_id
    )
    if not lb:
        return False
    await conn.execute(
        "DELETE FROM lookbook_outfits WHERE lookbook_id = $1 AND outfit_id = $2",
        lookbook_id,
        outfit_id,
    )
    return True


async def rename_lookbook(
    conn: asyncpg.Connection, lookbook_id: str, user_id: str, name: str
) -> dict | None:
    row = await conn.fetchrow(
        "UPDATE lookbooks SET name = $1 WHERE id = $2 AND user_id = $3 RETURNING *",
        name,
        lookbook_id,
        user_id,
    )
    return dict(row) if row else None


async def delete_lookbook(
    conn: asyncpg.Connection, lookbook_id: str, user_id: str
) -> bool:
    result = await conn.execute(
        "DELETE FROM lookbooks WHERE id = $1 AND user_id = $2", lookbook_id, user_id
    )
    return result == "DELETE 1"
