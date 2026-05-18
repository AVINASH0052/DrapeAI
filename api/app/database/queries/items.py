"""Item database queries."""

import json
import uuid
import asyncpg


async def insert_item(conn: asyncpg.Connection, user_id: str, storage_key: str, tags: dict) -> dict:
    """Insert a new item after vision tagging. Returns the full item row."""
    item_id = str(uuid.uuid4())
    row = await conn.fetchrow(
        """
        INSERT INTO items (
            id, user_id, image_url, category, sub_category,
            primary_color, secondary_colors, pattern, fabric,
            style_tags, formality, season_tags, ethnic_flag, confidence
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
        RETURNING *
        """,
        item_id, user_id, storage_key,
        tags["category"], tags["sub_category"],
        tags["primary_color"], json.dumps(tags.get("secondary_colors", [])),
        tags.get("pattern", "solid"), tags.get("fabric", "cotton"),
        json.dumps(tags.get("style_tags", [])),
        tags.get("formality", 3),
        json.dumps(tags.get("season_tags", ["all_season"])),
        tags.get("ethnic_flag", False),
        tags.get("confidence", 0.0),
    )
    return dict(row)


async def get_items(
    conn: asyncpg.Connection,
    user_id: str,
    category: str | None = None,
    color: str | None = None,
    season: str | None = None,
    ethnic: bool | None = None,
    search: str | None = None,
    sort: str = "newest",
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[dict], int]:
    """List items with filters. Returns (items, total_count)."""
    conditions = ["user_id = $1", "is_active = true"]
    params: list = [user_id]
    idx = 2

    if category:
        conditions.append(f"category = ${idx}")
        params.append(category)
        idx += 1
    if color:
        conditions.append(f"primary_color = ${idx}")
        params.append(color)
        idx += 1
    if season:
        conditions.append(f"season_tags::text ILIKE ${idx}")
        params.append(f"%{season}%")
        idx += 1
    if ethnic is not None:
        conditions.append(f"ethnic_flag = ${idx}")
        params.append(ethnic)
        idx += 1
    if search:
        conditions.append(
            f"(sub_category ILIKE ${idx} OR primary_color ILIKE ${idx} OR fabric ILIKE ${idx})"
        )
        params.append(f"%{search}%")
        idx += 1

    where = " AND ".join(conditions)
    sort_clause = {
        "newest": "created_at DESC",
        "oldest": "created_at ASC",
        "most_worn": "wear_count DESC",
        "least_worn": "wear_count ASC",
    }.get(sort, "created_at DESC")

    count = await conn.fetchval(f"SELECT COUNT(*) FROM items WHERE {where}", *params)

    params.extend([limit, offset])
    rows = await conn.fetch(
        f"SELECT * FROM items WHERE {where} ORDER BY {sort_clause} LIMIT ${idx} OFFSET ${idx + 1}",
        *params,
    )
    return [dict(r) for r in rows], count


async def get_item(conn: asyncpg.Connection, item_id: str, user_id: str) -> dict | None:
    row = await conn.fetchrow(
        "SELECT * FROM items WHERE id = $1 AND user_id = $2 AND is_active = true",
        item_id, user_id,
    )
    return dict(row) if row else None


async def update_item(
    conn: asyncpg.Connection, item_id: str, user_id: str, updates: dict
) -> dict | None:
    allowed = {
        "category", "sub_category", "primary_color", "secondary_colors",
        "pattern", "fabric", "style_tags", "formality", "season_tags",
        "ethnic_flag", "notes", "purchase_price",
    }
    filtered = {k: v for k, v in updates.items() if k in allowed and v is not None}
    if not filtered:
        return await get_item(conn, item_id, user_id)

    for key in ("secondary_colors", "style_tags", "season_tags"):
        if key in filtered:
            filtered[key] = json.dumps(filtered[key])

    set_parts = []
    params: list = [item_id, user_id]
    idx = 3
    for k, v in filtered.items():
        set_parts.append(f"{k} = ${idx}")
        params.append(v)
        idx += 1

    row = await conn.fetchrow(
        f"UPDATE items SET {', '.join(set_parts)} WHERE id = $1 AND user_id = $2 AND is_active = true RETURNING *",
        *params,
    )
    return dict(row) if row else None


async def soft_delete_item(conn: asyncpg.Connection, item_id: str, user_id: str) -> bool:
    result = await conn.execute(
        "UPDATE items SET is_active = false WHERE id = $1 AND user_id = $2",
        item_id, user_id,
    )
    return result == "UPDATE 1"


async def store_embedding(conn: asyncpg.Connection, item_id: str, embedding: list[float]) -> None:
    await conn.execute(
        "UPDATE items SET embedding = $1::vector WHERE id = $2",
        str(embedding), item_id,
    )
