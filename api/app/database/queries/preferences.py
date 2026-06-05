"""Preferences database queries."""

import json
import asyncpg


async def upsert_preferences(conn: asyncpg.Connection, user_id: str, prefs: dict) -> dict:
    row = await conn.fetchrow(
        """
        INSERT INTO preferences (
            user_id, name, age, gender, age_range,
            style_goals, occasions, color_preferences, fit_preference,
            location_city, climate,
            body_type, skin_undertone, height_cm, budget_tier, lifestyle
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
        ON CONFLICT (user_id) DO UPDATE SET
            name              = EXCLUDED.name,
            age               = EXCLUDED.age,
            gender            = EXCLUDED.gender,
            age_range         = EXCLUDED.age_range,
            style_goals       = EXCLUDED.style_goals,
            occasions         = EXCLUDED.occasions,
            color_preferences = EXCLUDED.color_preferences,
            fit_preference    = EXCLUDED.fit_preference,
            location_city     = EXCLUDED.location_city,
            climate           = EXCLUDED.climate,
            body_type         = EXCLUDED.body_type,
            skin_undertone    = EXCLUDED.skin_undertone,
            height_cm         = EXCLUDED.height_cm,
            budget_tier       = EXCLUDED.budget_tier,
            lifestyle         = EXCLUDED.lifestyle,
            updated_at        = NOW()
        RETURNING *
        """,
        user_id,
        prefs.get("name"),
        prefs.get("age"),
        prefs.get("gender"),
        prefs.get("age_range"),
        json.dumps(prefs.get("style_goals", [])),
        json.dumps(prefs.get("occasions", [])),
        json.dumps(prefs.get("color_preferences", [])),
        prefs.get("fit_preference"),
        prefs.get("location_city"),
        prefs.get("climate"),
        prefs.get("body_type"),
        prefs.get("skin_undertone"),
        prefs.get("height_cm"),
        prefs.get("budget_tier"),
        json.dumps(prefs.get("lifestyle", [])),
    )
    return _row_to_dict(row)


async def get_preferences(conn: asyncpg.Connection, user_id: str) -> dict | None:
    row = await conn.fetchrow(
        "SELECT * FROM preferences WHERE user_id = $1", user_id
    )
    if not row:
        return None
    return _row_to_dict(row)


def _row_to_dict(row) -> dict:
    result = dict(row)
    for json_field in ("style_goals", "occasions", "color_preferences", "lifestyle"):
        if result.get(json_field):
            try:
                result[json_field] = json.loads(result[json_field])
            except (TypeError, json.JSONDecodeError):
                result[json_field] = []
        else:
            result[json_field] = []
    return result
