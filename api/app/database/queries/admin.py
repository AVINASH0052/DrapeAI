"""Admin dashboard database queries."""

from __future__ import annotations

import json
from datetime import date, datetime
from typing import Any
from uuid import UUID

import asyncpg

from app.services.storage import get_image_url


def _jsonable(value: Any) -> Any:
    if isinstance(value, dict):
        return {k: _jsonable(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_jsonable(v) for v in value]
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def _row(row: asyncpg.Record | None) -> dict | None:
    if row is None:
        return None
    return _jsonable(dict(row))


def _rows(rows: list[asyncpg.Record]) -> list[dict]:
    return [_row(r) for r in rows]  # type: ignore[misc]


async def write_audit(
    conn: asyncpg.Connection,
    admin_id: str,
    action: str,
    target_type: str,
    target_id: str | None = None,
    meta: dict | None = None,
) -> None:
    await conn.execute(
        """
        INSERT INTO admin_audit_log (admin_id, action, target_type, target_id, meta)
        VALUES ($1, $2, $3, $4, $5::jsonb)
        """,
        admin_id,
        action,
        target_type,
        target_id,
        json.dumps(meta or {}),
    )


async def get_admin_stats(conn: asyncpg.Connection) -> dict:
    """Return top-level KPI stats for the admin dashboard."""
    row = await conn.fetchrow(
        """
        SELECT
            (SELECT COUNT(*) FROM users) AS total_users,
            (SELECT COUNT(*) FROM users
             WHERE last_login_at >= NOW() - INTERVAL '7 days') AS active_users_7d,
            (SELECT COUNT(*) FROM users
             WHERE created_at >= NOW() - INTERVAL '7 days') AS new_users_7d,
            (SELECT COUNT(*) FROM items WHERE is_active = true) AS total_items,
            (SELECT COUNT(*) FROM outfits) AS total_outfits,
            (SELECT COUNT(*) FROM items WHERE is_flagged = true) AS flagged_items,
            (SELECT COUNT(*) FROM waitlist_emails) AS waitlist_count,
            (SELECT COALESCE(SUM(value), 0) FROM analytics_daily
             WHERE date = CURRENT_DATE
               AND metric LIKE 'ai_cost_%') AS today_ai_spend,
            (SELECT COALESCE(SUM(value), 0) FROM analytics_daily
             WHERE date >= DATE_TRUNC('month', CURRENT_DATE)
               AND metric LIKE 'ai_cost_%') AS month_ai_spend
        """
    )
    data = _row(row) or {}
    # Aliases expected by the admin UI
    data["ai_spend_today"] = data.get("today_ai_spend", 0)
    data["ai_spend_month"] = data.get("month_ai_spend", 0)
    return data


async def get_admin_stats_timeseries(
    conn: asyncpg.Connection, days: int = 30
) -> list[dict]:
    """Return daily stats (new_users, outfits_generated, ai_cost) for the last N days."""
    rows = await conn.fetch(
        """
        WITH date_series AS (
            SELECT generate_series(
                CURRENT_DATE - ($1 * INTERVAL '1 day'),
                CURRENT_DATE,
                '1 day'
            )::DATE AS day
        )
        SELECT
            ds.day AS date,
            COALESCE(u.new_users, 0) AS new_users,
            COALESCE(o.outfits_generated, 0) AS outfits_generated,
            COALESCE(a.ai_cost, 0) AS ai_cost
        FROM date_series ds
        LEFT JOIN (
            SELECT DATE(created_at) AS day, COUNT(*) AS new_users
            FROM users GROUP BY DATE(created_at)
        ) u ON u.day = ds.day
        LEFT JOIN (
            SELECT DATE(created_at) AS day, COUNT(*) AS outfits_generated
            FROM outfits GROUP BY DATE(created_at)
        ) o ON o.day = ds.day
        LEFT JOIN (
            SELECT date AS day, SUM(value) AS ai_cost
            FROM analytics_daily
            WHERE metric LIKE 'ai_cost_%'
            GROUP BY date
        ) a ON a.day = ds.day
        ORDER BY ds.day
        """,
        days,
    )
    return _rows(rows)


async def list_admin_users(
    conn: asyncpg.Connection,
    search: str | None = None,
    onboarding_filter: str | None = None,
    suspended: str | None = None,
    is_admin: str | None = None,
    avatar_status: str | None = None,
    inactive_days: int | None = None,
    limit: int = 20,
    offset: int = 0,
) -> tuple[list[dict], int]:
    """Paginated user list with search, filters, and content counts."""
    conditions = ["TRUE"]
    params: list = []
    idx = 1

    if search:
        conditions.append(
            f"(u.email ILIKE ${idx} OR u.phone ILIKE ${idx} OR u.display_name ILIKE ${idx})"
        )
        params.append(f"%{search}%")
        idx += 1

    if onboarding_filter == "done":
        conditions.append("u.onboarding_done = TRUE")
    elif onboarding_filter == "pending":
        conditions.append("u.onboarding_done = FALSE")

    if suspended == "true":
        conditions.append("u.is_suspended = TRUE")
    elif suspended == "false":
        conditions.append("u.is_suspended = FALSE")

    if is_admin == "true":
        conditions.append("u.is_admin = TRUE")
    elif is_admin == "false":
        conditions.append("u.is_admin = FALSE")

    if avatar_status:
        conditions.append(f"u.avatar_status = ${idx}")
        params.append(avatar_status)
        idx += 1

    if inactive_days is not None and inactive_days > 0:
        conditions.append(
            f"(u.last_login_at IS NULL OR u.last_login_at < NOW() - (${idx} || ' days')::INTERVAL)"
        )
        params.append(str(inactive_days))
        idx += 1

    where = " AND ".join(conditions)

    total = await conn.fetchval(
        f"SELECT COUNT(*) FROM users u WHERE {where}", *params
    )

    params.extend([limit, offset])
    rows = await conn.fetch(
        f"""
        SELECT
            u.id, u.email, u.phone, u.display_name, u.photo_url,
            u.onboarding_done, u.is_admin, u.is_suspended, u.suspended_at,
            u.avatar_status, u.created_at, u.last_login_at,
            (SELECT COUNT(*) FROM items i
             WHERE i.user_id = u.id AND i.is_active = true) AS item_count,
            (SELECT COUNT(*) FROM outfits o WHERE o.user_id = u.id) AS outfit_count
        FROM users u
        WHERE {where}
        ORDER BY u.created_at DESC
        LIMIT ${idx} OFFSET ${idx + 1}
        """,
        *params,
    )
    return _rows(rows), int(total or 0)


async def get_admin_user_detail(conn: asyncpg.Connection, user_id: str) -> dict | None:
    """Full user detail including aggregated counts and preferences."""
    row = await conn.fetchrow(
        """
        SELECT
            u.*,
            (SELECT COUNT(*) FROM items WHERE user_id = u.id AND is_active = true) AS item_count,
            (SELECT COUNT(*) FROM outfits WHERE user_id = u.id) AS outfit_count,
            (SELECT COUNT(*) FROM outfit_feedback WHERE user_id = u.id) AS feedback_count,
            (SELECT COUNT(*) FROM lookbooks WHERE user_id = u.id) AS lookbook_count,
            (SELECT COUNT(*) FROM try_on_jobs WHERE user_id = u.id) AS try_on_job_count,
            (SELECT COUNT(*) FROM try_on_sessions WHERE user_id = u.id) AS try_on_session_count,
            (SELECT COUNT(*) FROM push_tokens
             WHERE user_id = u.id AND is_active = true) AS push_token_count,
            (SELECT row_to_json(p) FROM preferences p WHERE p.user_id = u.id) AS preferences
        FROM users u
        WHERE u.id = $1
        """,
        user_id,
    )
    return _row(row)


async def update_admin_user(
    conn: asyncpg.Connection,
    user_id: str,
    admin_notes: str | None = None,
    set_admin_notes: bool = False,
    is_admin: bool | None = None,
) -> dict | None:
    """Patch admin-editable user fields."""
    sets: list[str] = []
    params: list = [user_id]
    idx = 2

    if set_admin_notes:
        sets.append(f"admin_notes = ${idx}")
        params.append(admin_notes)
        idx += 1

    if is_admin is not None:
        sets.append(f"is_admin = ${idx}")
        params.append(is_admin)
        idx += 1

    if not sets:
        return await get_admin_user_detail(conn, user_id)

    row = await conn.fetchrow(
        f"""
        UPDATE users SET {', '.join(sets)}
        WHERE id = $1
        RETURNING id
        """,
        *params,
    )
    if not row:
        return None
    return await get_admin_user_detail(conn, user_id)


async def reset_onboarding(conn: asyncpg.Connection, user_id: str) -> dict | None:
    row = await conn.fetchrow(
        """
        UPDATE users SET onboarding_done = FALSE
        WHERE id = $1
        RETURNING id
        """,
        user_id,
    )
    if not row:
        return None
    return await get_admin_user_detail(conn, user_id)


async def suspend_user(
    conn: asyncpg.Connection, user_id: str, is_suspended: bool
) -> dict | None:
    """Set is_suspended flag on a user."""
    row = await conn.fetchrow(
        """
        UPDATE users
        SET is_suspended = $2,
            suspended_at = CASE WHEN $2 THEN NOW() ELSE NULL END
        WHERE id = $1
        RETURNING *
        """,
        user_id,
        is_suspended,
    )
    return _row(row)


async def delete_user(conn: asyncpg.Connection, user_id: str) -> bool:
    """Hard delete a user. CASCADE will handle related tables."""
    result = await conn.execute("DELETE FROM users WHERE id = $1", user_id)
    return result == "DELETE 1"


def _enrich_item(row: dict) -> dict:
    key = row.get("image_url") or ""
    thumb = row.get("thumbnail_url") or key
    if key and not str(key).startswith("http") and not str(key).startswith("/"):
        row["image_url_resolved"] = get_image_url(key)
    else:
        row["image_url_resolved"] = key
    if thumb and not str(thumb).startswith("http") and not str(thumb).startswith("/"):
        row["thumbnail_url_resolved"] = get_image_url(thumb)
    else:
        row["thumbnail_url_resolved"] = thumb
    return row


async def list_user_items(
    conn: asyncpg.Connection,
    user_id: str,
    limit: int = 40,
    offset: int = 0,
) -> tuple[list[dict], int]:
    total = await conn.fetchval(
        "SELECT COUNT(*) FROM items WHERE user_id = $1",
        user_id,
    )
    rows = await conn.fetch(
        """
        SELECT id, user_id, image_url, thumbnail_url, category, sub_category,
               display_name, primary_color, pattern, fabric, formality,
               brand, wear_count, is_active, is_flagged, flagged_reason,
               processing_status, created_at
        FROM items
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
        """,
        user_id,
        limit,
        offset,
    )
    items = [_enrich_item(r) for r in _rows(rows)]
    return items, int(total or 0)


async def list_user_outfits(
    conn: asyncpg.Connection,
    user_id: str,
    limit: int = 20,
    offset: int = 0,
) -> tuple[list[dict], int]:
    total = await conn.fetchval(
        "SELECT COUNT(*) FROM outfits WHERE user_id = $1",
        user_id,
    )
    rows = await conn.fetch(
        """
        SELECT id, user_id, item_ids, occasion, weather_temp, weather_cond,
               generated_by, rule_score, llm_rank, llm_reason,
               is_saved, is_worn, preview_image_key, created_at
        FROM outfits
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
        """,
        user_id,
        limit,
        offset,
    )
    outfits = _rows(rows)
    # Resolve item thumbnails for each outfit
    for outfit in outfits:
        raw_ids = outfit.get("item_ids")
        ids: list[str] = []
        if isinstance(raw_ids, str):
            try:
                ids = json.loads(raw_ids)
            except json.JSONDecodeError:
                ids = []
        elif isinstance(raw_ids, list):
            ids = [str(x) for x in raw_ids]
        outfit["item_ids"] = ids
        items = []
        if ids:
            item_rows = await conn.fetch(
                """
                SELECT id, image_url, thumbnail_url, category, display_name, primary_color
                FROM items WHERE id = ANY($1::uuid[])
                """,
                ids,
            )
            items = [_enrich_item(r) for r in _rows(item_rows)]
        outfit["items"] = items
        preview = outfit.get("preview_image_key")
        if preview and not str(preview).startswith("http"):
            outfit["preview_url"] = get_image_url(preview)
        else:
            outfit["preview_url"] = preview
    return outfits, int(total or 0)


async def list_user_lookbooks(
    conn: asyncpg.Connection, user_id: str
) -> list[dict]:
    rows = await conn.fetch(
        """
        SELECT
            l.id, l.user_id, l.name, l.sort_order, l.created_at, l.updated_at,
            (SELECT COUNT(*) FROM lookbook_outfits lo WHERE lo.lookbook_id = l.id) AS outfit_count
        FROM lookbooks l
        WHERE l.user_id = $1
        ORDER BY l.sort_order ASC, l.created_at DESC
        """,
        user_id,
    )
    return _rows(rows)


async def list_user_activity(
    conn: asyncpg.Connection,
    user_id: str,
    limit: int = 50,
) -> list[dict]:
    rows = await conn.fetch(
        """
        (
            SELECT 'item_upload' AS event_type, i.id::text AS ref_id,
                   COALESCE(i.display_name, i.category) AS label,
                   i.created_at AS at
            FROM items i WHERE i.user_id = $1
        )
        UNION ALL
        (
            SELECT 'outfit_feedback', f.id::text,
                   f.action, f.created_at
            FROM outfit_feedback f WHERE f.user_id = $1
        )
        UNION ALL
        (
            SELECT 'try_on_job', j.id::text,
                   j.status, j.created_at
            FROM try_on_jobs j WHERE j.user_id = $1
        )
        UNION ALL
        (
            SELECT 'try_on_session', s.id::text,
                   s.status, s.created_at
            FROM try_on_sessions s WHERE s.user_id = $1
        )
        ORDER BY at DESC
        LIMIT $2
        """,
        user_id,
        limit,
    )
    return _rows(rows)


async def list_user_try_ons(
    conn: asyncpg.Connection,
    user_id: str,
    limit: int = 30,
    offset: int = 0,
) -> dict:
    jobs = await conn.fetch(
        """
        SELECT id, outfit_id, session_id, status, provider, model, method,
               result_key, error_message, created_at, started_at, completed_at
        FROM try_on_jobs
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
        """,
        user_id,
        limit,
        offset,
    )
    sessions = await conn.fetch(
        """
        SELECT id, status, reference_image_key, result_image_key, provider,
               model, method, error_message, created_at, completed_at
        FROM try_on_sessions
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
        """,
        user_id,
        limit,
        offset,
    )
    job_list = _rows(jobs)
    for j in job_list:
        key = j.get("result_key")
        j["result_url"] = get_image_url(key) if key and not str(key).startswith("http") else key
    session_list = _rows(sessions)
    for s in session_list:
        key = s.get("result_image_key")
        s["result_url"] = get_image_url(key) if key and not str(key).startswith("http") else key
        s["result_key"] = key
    return {"jobs": job_list, "sessions": session_list}


async def list_admin_items(
    conn: asyncpg.Connection,
    search: str | None = None,
    category: str | None = None,
    flagged: str | None = None,
    user_id: str | None = None,
    limit: int = 40,
    offset: int = 0,
) -> tuple[list[dict], int]:
    conditions = ["TRUE"]
    params: list = []
    idx = 1

    if search:
        conditions.append(
            f"(i.display_name ILIKE ${idx} OR i.category ILIKE ${idx} OR i.brand ILIKE ${idx})"
        )
        params.append(f"%{search}%")
        idx += 1
    if category:
        conditions.append(f"i.category = ${idx}")
        params.append(category)
        idx += 1
    if flagged == "true":
        conditions.append("i.is_flagged = TRUE")
    elif flagged == "false":
        conditions.append("i.is_flagged = FALSE")
    if user_id:
        conditions.append(f"i.user_id = ${idx}")
        params.append(user_id)
        idx += 1

    where = " AND ".join(conditions)
    total = await conn.fetchval(
        f"SELECT COUNT(*) FROM items i WHERE {where}", *params
    )
    params.extend([limit, offset])
    rows = await conn.fetch(
        f"""
        SELECT
            i.id, i.user_id, i.image_url, i.thumbnail_url, i.category,
            i.sub_category, i.display_name, i.primary_color, i.formality,
            i.brand, i.wear_count, i.is_active, i.is_flagged, i.flagged_at,
            i.flagged_reason, i.created_at,
            u.email AS user_email, u.display_name AS user_display_name
        FROM items i
        LEFT JOIN users u ON u.id = i.user_id
        WHERE {where}
        ORDER BY i.created_at DESC
        LIMIT ${idx} OFFSET ${idx + 1}
        """,
        *params,
    )
    return [_enrich_item(r) for r in _rows(rows)], int(total or 0)


async def flag_item(
    conn: asyncpg.Connection,
    item_id: str,
    flagged: bool,
    reason: str | None = None,
) -> dict | None:
    if flagged:
        row = await conn.fetchrow(
            """
            UPDATE items
            SET is_flagged = TRUE,
                flagged_at = NOW(),
                flagged_reason = $2
            WHERE id = $1::uuid
            RETURNING id, user_id, is_flagged, flagged_at, flagged_reason
            """,
            item_id,
            reason,
        )
    else:
        row = await conn.fetchrow(
            """
            UPDATE items
            SET is_flagged = FALSE,
                flagged_at = NULL,
                flagged_reason = NULL
            WHERE id = $1::uuid
            RETURNING id, user_id, is_flagged, flagged_at, flagged_reason
            """,
            item_id,
        )
    return _row(row)


async def soft_delete_item(conn: asyncpg.Connection, item_id: str) -> dict | None:
    row = await conn.fetchrow(
        """
        UPDATE items SET is_active = FALSE
        WHERE id = $1::uuid
        RETURNING id, user_id, is_active
        """,
        item_id,
    )
    return _row(row)


async def get_ai_usage(conn: asyncpg.Connection, days: int = 30) -> list[dict]:
    """AI usage breakdown by provider (aggregated for pie chart + raw daily)."""
    rows = await conn.fetch(
        """
        SELECT date, metric, value
        FROM analytics_daily
        WHERE metric LIKE 'ai_cost_%'
          AND date >= CURRENT_DATE - ($1 * INTERVAL '1 day')
        ORDER BY date, metric
        """,
        days,
    )
    raw = _rows(rows)
    # Aggregate by provider for UI pie chart
    by_provider: dict[str, float] = {}
    for r in raw:
        metric = str(r.get("metric") or "")
        # ai_cost_{provider}_{YYYY-MM} or similar
        parts = metric.split("_")
        provider = parts[2] if len(parts) >= 3 else metric
        by_provider[provider] = by_provider.get(provider, 0.0) + float(r.get("value") or 0)
    providers = [
        {"provider": p, "model": "all", "total_cost": v}
        for p, v in sorted(by_provider.items(), key=lambda x: -x[1])
    ]
    return providers


async def get_analytics_overview(conn: asyncpg.Connection, days: int = 30) -> dict:
    row = await conn.fetchrow(
        """
        SELECT
            (SELECT COUNT(*) FROM users) AS total_users,
            (SELECT COUNT(*) FROM users
             WHERE last_login_at >= NOW() - INTERVAL '1 day') AS dau,
            (SELECT COUNT(*) FROM users
             WHERE last_login_at >= NOW() - INTERVAL '30 days') AS mau,
            (SELECT COUNT(*) FROM users
             WHERE created_at >= NOW() - ($1 * INTERVAL '1 day')) AS new_users,
            (SELECT COUNT(*) FROM items WHERE is_active = true) AS total_items,
            (SELECT COUNT(*) FROM outfits) AS total_outfits,
            (SELECT COALESCE(SUM(value), 0) FROM analytics_daily
             WHERE date >= CURRENT_DATE - ($1 * INTERVAL '1 day')
               AND metric LIKE 'ai_cost_%') AS total_cost_usd,
            (SELECT COALESCE(AVG(c.cnt), 0) FROM (
                SELECT COUNT(*) AS cnt FROM items
                WHERE is_active = true GROUP BY user_id
             ) c) AS avg_items_per_user
        """,
        days,
    )
    return _row(row) or {}


async def get_analytics_costs(conn: asyncpg.Connection, days: int = 30) -> list[dict]:
    rows = await conn.fetch(
        """
        SELECT date, metric, value
        FROM analytics_daily
        WHERE metric LIKE 'ai_cost_%'
          AND date >= CURRENT_DATE - ($1 * INTERVAL '1 day')
        ORDER BY date
        """,
        days,
    )
    # Pivot to date -> provider costs
    by_date: dict[str, dict] = {}
    for r in rows:
        d = r["date"].isoformat() if hasattr(r["date"], "isoformat") else str(r["date"])
        metric = str(r["metric"])
        parts = metric.split("_")
        provider = parts[2] if len(parts) >= 3 else "other"
        bucket = by_date.setdefault(d, {"date": d})
        bucket[provider] = bucket.get(provider, 0.0) + float(r["value"] or 0)
    return [by_date[k] for k in sorted(by_date.keys())]


async def get_analytics_usage(conn: asyncpg.Connection, days: int = 30) -> list[dict]:
    rows = await conn.fetch(
        """
        WITH date_series AS (
            SELECT generate_series(
                CURRENT_DATE - ($1 * INTERVAL '1 day'),
                CURRENT_DATE,
                '1 day'
            )::DATE AS day
        )
        SELECT
            ds.day AS date,
            COALESCE(i.uploads, 0) AS uploads,
            COALESCE(o.outfits_generated, 0) AS outfits_generated,
            COALESCE(f.chat_refinements, 0) AS chat_refinements
        FROM date_series ds
        LEFT JOIN (
            SELECT DATE(created_at) AS day, COUNT(*) AS uploads
            FROM items GROUP BY DATE(created_at)
        ) i ON i.day = ds.day
        LEFT JOIN (
            SELECT DATE(created_at) AS day, COUNT(*) AS outfits_generated
            FROM outfits GROUP BY DATE(created_at)
        ) o ON o.day = ds.day
        LEFT JOIN (
            SELECT DATE(created_at) AS day, COUNT(*) AS chat_refinements
            FROM outfit_feedback GROUP BY DATE(created_at)
        ) f ON f.day = ds.day
        ORDER BY ds.day
        """,
        days,
    )
    return _rows(rows)


async def get_top_users(
    conn: asyncpg.Connection,
    metric: str = "items",
    days: int = 30,
    limit: int = 20,
) -> list[dict]:
    if metric == "outfits":
        rows = await conn.fetch(
            """
            SELECT u.id, u.email, u.display_name, COUNT(o.id) AS value
            FROM users u
            JOIN outfits o ON o.user_id = u.id
            WHERE o.created_at >= NOW() - ($1 * INTERVAL '1 day')
            GROUP BY u.id
            ORDER BY value DESC
            LIMIT $2
            """,
            days,
            limit,
        )
    else:
        rows = await conn.fetch(
            """
            SELECT u.id, u.email, u.display_name, COUNT(i.id) AS value
            FROM users u
            JOIN items i ON i.user_id = u.id
            WHERE i.created_at >= NOW() - ($1 * INTERVAL '1 day')
            GROUP BY u.id
            ORDER BY value DESC
            LIMIT $2
            """,
            days,
            limit,
        )
    return _rows(rows)


async def list_waitlist(
    conn: asyncpg.Connection,
    search: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[dict], int]:
    conditions = ["TRUE"]
    params: list = []
    idx = 1
    if search:
        conditions.append(f"email ILIKE ${idx}")
        params.append(f"%{search}%")
        idx += 1
    where = " AND ".join(conditions)
    total = await conn.fetchval(
        f"SELECT COUNT(*) FROM waitlist_emails WHERE {where}", *params
    )
    params.extend([limit, offset])
    rows = await conn.fetch(
        f"""
        SELECT id, email, source, created_at
        FROM waitlist_emails
        WHERE {where}
        ORDER BY created_at DESC
        LIMIT ${idx} OFFSET ${idx + 1}
        """,
        *params,
    )
    return _rows(rows), int(total or 0)


async def get_push_segments(conn: asyncpg.Connection) -> list[dict]:
    all_tokens = await conn.fetchval(
        "SELECT COUNT(DISTINCT user_id) FROM push_tokens WHERE is_active = TRUE"
    )
    inactive_7d = await conn.fetchval(
        """
        SELECT COUNT(DISTINCT pt.user_id)
        FROM push_tokens pt
        JOIN users u ON u.id = pt.user_id
        WHERE pt.is_active = TRUE
          AND (u.last_login_at IS NULL OR u.last_login_at < NOW() - INTERVAL '7 days')
        """
    )
    inactive_30d = await conn.fetchval(
        """
        SELECT COUNT(DISTINCT pt.user_id)
        FROM push_tokens pt
        JOIN users u ON u.id = pt.user_id
        WHERE pt.is_active = TRUE
          AND (u.last_login_at IS NULL OR u.last_login_at < NOW() - INTERVAL '30 days')
        """
    )
    onboarding_pending = await conn.fetchval(
        """
        SELECT COUNT(DISTINCT pt.user_id)
        FROM push_tokens pt
        JOIN users u ON u.id = pt.user_id
        WHERE pt.is_active = TRUE AND u.onboarding_done = FALSE
        """
    )
    return [
        {
            "id": "all_with_tokens",
            "label": "All users with push tokens",
            "count": int(all_tokens or 0),
        },
        {
            "id": "inactive_7d",
            "label": "Inactive 7+ days",
            "count": int(inactive_7d or 0),
        },
        {
            "id": "inactive_30d",
            "label": "Inactive 30+ days",
            "count": int(inactive_30d or 0),
        },
        {
            "id": "onboarding_pending",
            "label": "Onboarding incomplete",
            "count": int(onboarding_pending or 0),
        },
    ]


async def resolve_push_segment_user_ids(
    conn: asyncpg.Connection, segment_id: str
) -> list[str]:
    if segment_id == "all_with_tokens":
        rows = await conn.fetch(
            "SELECT DISTINCT user_id FROM push_tokens WHERE is_active = TRUE"
        )
    elif segment_id == "inactive_7d":
        rows = await conn.fetch(
            """
            SELECT DISTINCT pt.user_id
            FROM push_tokens pt
            JOIN users u ON u.id = pt.user_id
            WHERE pt.is_active = TRUE
              AND (u.last_login_at IS NULL OR u.last_login_at < NOW() - INTERVAL '7 days')
            """
        )
    elif segment_id == "inactive_30d":
        rows = await conn.fetch(
            """
            SELECT DISTINCT pt.user_id
            FROM push_tokens pt
            JOIN users u ON u.id = pt.user_id
            WHERE pt.is_active = TRUE
              AND (u.last_login_at IS NULL OR u.last_login_at < NOW() - INTERVAL '30 days')
            """
        )
    elif segment_id == "onboarding_pending":
        rows = await conn.fetch(
            """
            SELECT DISTINCT pt.user_id
            FROM push_tokens pt
            JOIN users u ON u.id = pt.user_id
            WHERE pt.is_active = TRUE AND u.onboarding_done = FALSE
            """
        )
    else:
        return []
    return [r["user_id"] for r in rows]


async def get_system_health(conn: asyncpg.Connection) -> dict:
    """DB connectivity check and table row counts."""
    from app.config import settings

    db_ok = await conn.fetchval("SELECT 1") == 1
    db_version = await conn.fetchval("SHOW server_version")
    uptime = await conn.fetchval(
        "SELECT EXTRACT(EPOCH FROM (NOW() - pg_postmaster_start_time()))"
    )

    tables = [
        "users",
        "preferences",
        "items",
        "outfits",
        "outfit_feedback",
        "lookbooks",
        "push_tokens",
        "analytics_daily",
        "notifications",
        "try_on_jobs",
        "try_on_sessions",
        "waitlist_emails",
        "admin_audit_log",
    ]
    table_counts: dict[str, int] = {}
    table_list = []
    for table in tables:
        try:
            count = await conn.fetchval(f"SELECT COUNT(*) FROM {table}")
        except Exception:
            count = None
        if count is not None:
            table_counts[table] = int(count)
            table_list.append({"name": table, "row_count": int(count)})

    providers = [
        {"name": "openai", "configured": bool(settings.openai_api_key)},
        {"name": "anthropic", "configured": bool(settings.anthropic_api_key)},
        {"name": "gemini", "configured": bool(settings.gemini_api_key)},
        {
            "name": "vertex",
            "configured": bool(
                settings.google_cloud_project
                and settings.google_application_credentials
            ),
        },
        {"name": "nvidia", "configured": bool(settings.nvidia_api_key)},
        {"name": "groq", "configured": bool(settings.groq_api_key)},
        {
            "name": "cloudflare",
            "configured": bool(
                settings.cloudflare_account_id and settings.cloudflare_api_token
            ),
        },
        {
            "name": "runpod",
            "configured": bool(settings.runpod_api_key and settings.runpod_endpoint_id),
        },
    ]

    return {
        "db_connected": db_ok,
        "db_version": db_version,
        "uptime_seconds": float(uptime or 0),
        "table_counts": table_counts,
        "tables": table_list,
        "providers": providers,
    }
