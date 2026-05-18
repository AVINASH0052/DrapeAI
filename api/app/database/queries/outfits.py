"""Outfit database queries."""

import json
import uuid
import asyncpg


async def save_outfit(conn: asyncpg.Connection, user_id: str, outfit_data: dict) -> dict:
    """Save a generated outfit to the database."""
    outfit_id = str(uuid.uuid4())
    item_ids = [item["id"] for item in outfit_data["items"]]

    weather = outfit_data.get("weather") or {}
    row = await conn.fetchrow(
        """
        INSERT INTO outfits (
            id, user_id, item_ids, occasion,
            weather_temp, weather_cond,
            rule_score, llm_reason, generated_by
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
        RETURNING *
        """,
        outfit_id,
        user_id,
        json.dumps(item_ids),
        outfit_data.get("occasion", "casual"),
        weather.get("temp"),
        weather.get("condition"),
        outfit_data.get("rule_score", 0.0),
        outfit_data.get("reason"),
        "ai",
    )
    return dict(row)


async def record_feedback(
    conn: asyncpg.Connection, user_id: str, outfit_id: str, action: str
) -> None:
    """Record outfit feedback and apply side effects."""
    await conn.execute(
        """
        INSERT INTO outfit_feedback (id, outfit_id, user_id, action)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (user_id, outfit_id, action) DO NOTHING
        """,
        str(uuid.uuid4()),
        outfit_id,
        user_id,
        action,
    )

    if action in ("like", "save"):
        await conn.execute(
            "UPDATE outfits SET is_saved = true WHERE id = $1 AND user_id = $2",
            outfit_id,
            user_id,
        )
    elif action == "wear":
        await conn.execute(
            "UPDATE outfits SET is_worn = true WHERE id = $1 AND user_id = $2",
            outfit_id,
            user_id,
        )
        row = await conn.fetchrow(
            "SELECT item_ids FROM outfits WHERE id = $1 AND user_id = $2",
            outfit_id,
            user_id,
        )
        if row:
            item_ids = json.loads(row["item_ids"])
            for iid in item_ids:
                await conn.execute(
                    "UPDATE items SET wear_count = wear_count + 1, last_worn_at = NOW() WHERE id = $1",
                    iid,
                )


async def get_today_outfits(conn: asyncpg.Connection, user_id: str) -> list[dict]:
    """Get outfits generated today for this user."""
    rows = await conn.fetch(
        """
        SELECT * FROM outfits
        WHERE user_id = $1 AND DATE(created_at) = CURRENT_DATE
        ORDER BY created_at DESC
        """,
        user_id,
    )
    return [dict(r) for r in rows]
