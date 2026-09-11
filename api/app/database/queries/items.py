"""Item database queries."""

import json
import uuid
import asyncpg


def normalize_item_row(row: dict) -> dict:
    """Ensure JSONB list fields are real lists (asyncpg may return strings)."""
    item = dict(row)
    for key in ("secondary_colors", "style_tags", "season_tags"):
        val = item.get(key)
        if isinstance(val, str):
            try:
                parsed = json.loads(val)
                item[key] = parsed if isinstance(parsed, list) else []
            except json.JSONDecodeError:
                item[key] = []
        elif val is None:
            item[key] = []
        elif not isinstance(val, list):
            item[key] = list(val) if val else []
    return item


async def insert_item(
    conn: asyncpg.Connection,
    user_id: str,
    storage_key: str,
    tags: dict,
    *,
    item_id: str | None = None,
    processing_status: str = "ready",
) -> dict:
    """Insert a new item. Returns the full item row."""
    item_id = item_id or str(uuid.uuid4())
    row = await conn.fetchrow(
        """
        INSERT INTO items (
            id, user_id, image_url, category, sub_category,
            primary_color, secondary_colors, pattern, fabric,
            style_tags, formality, season_tags, ethnic_flag, confidence,
            processing_status
        ) VALUES ($1,$2,$3,$4,$5,$6,$7::jsonb,$8,$9,$10::jsonb,$11,$12::jsonb,$13,$14,$15)
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
        processing_status,
    )
    return normalize_item_row(dict(row))


async def set_processing_status(
    conn: asyncpg.Connection,
    item_id: str,
    user_id: str,
    status: str,
    *,
    notes: str | None = None,
) -> None:
    await conn.execute(
        """
        UPDATE items
        SET processing_status = $3,
            notes = COALESCE($4, notes),
            updated_at = NOW()
        WHERE id = $1::uuid AND user_id = $2 AND is_active = true
        """,
        item_id,
        user_id,
        status,
        notes,
    )


async def apply_tags_and_image(
    conn: asyncpg.Connection,
    item_id: str,
    user_id: str,
    storage_key: str,
    tags: dict,
) -> dict | None:
    """Replace placeholder tags/image after background AI analysis."""
    row = await conn.fetchrow(
        """
        UPDATE items SET
            image_url = $3,
            category = $4,
            sub_category = $5,
            primary_color = $6,
            secondary_colors = $7::jsonb,
            pattern = $8,
            fabric = $9,
            style_tags = $10::jsonb,
            formality = $11,
            season_tags = $12::jsonb,
            ethnic_flag = $13,
            confidence = $14,
            processing_status = 'ready',
            notes = NULL,
            updated_at = NOW()
        WHERE id = $1::uuid AND user_id = $2 AND is_active = true
        RETURNING *
        """,
        item_id,
        user_id,
        storage_key,
        tags["category"],
        tags.get("sub_category", ""),
        tags["primary_color"],
        json.dumps(tags.get("secondary_colors", [])),
        tags.get("pattern", "solid"),
        tags.get("fabric", "cotton"),
        json.dumps(tags.get("style_tags", [])),
        tags.get("formality", 3),
        json.dumps(tags.get("season_tags", ["all_season"])),
        tags.get("ethnic_flag", False),
        tags.get("confidence", 0.0),
    )
    return normalize_item_row(dict(row)) if row else None


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
    return [normalize_item_row(dict(r)) for r in rows], count


async def get_item(conn: asyncpg.Connection, item_id: str, user_id: str) -> dict | None:
    row = await conn.fetchrow(
        "SELECT * FROM items WHERE id = $1 AND user_id = $2 AND is_active = true",
        item_id, user_id,
    )
    return normalize_item_row(dict(row)) if row else None


async def update_item(
    conn: asyncpg.Connection, item_id: str, user_id: str, updates: dict
) -> dict | None:
    allowed = {
        "display_name", "category", "sub_category", "primary_color", "secondary_colors",
        "pattern", "fabric", "style_tags", "formality", "season_tags",
        "ethnic_flag", "notes", "purchase_price",
        "garment_size", "garment_fit",
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
        if k in ("secondary_colors", "style_tags", "season_tags"):
            set_parts.append(f"{k} = ${idx}::jsonb")
        else:
            set_parts.append(f"{k} = ${idx}")
        params.append(v)
        idx += 1

    row = await conn.fetchrow(
        f"UPDATE items SET {', '.join(set_parts)}, updated_at = NOW() "
        "WHERE id = $1 AND user_id = $2 AND is_active = true RETURNING *",
        *params,
    )
    return normalize_item_row(dict(row)) if row else None


async def soft_delete_item(conn: asyncpg.Connection, item_id: str, user_id: str) -> bool:
    result = await conn.execute(
        """
        UPDATE items
        SET is_active = false, updated_at = NOW()
        WHERE id = $1::uuid AND user_id = $2 AND is_active = true
        """,
        item_id,
        user_id,
    )
    return result == "UPDATE 1"


async def store_embedding(conn: asyncpg.Connection, item_id: str, embedding: list[float]) -> None:
    await conn.execute(
        "UPDATE items SET embedding = $1::vector WHERE id = $2",
        str(embedding), item_id,
    )
