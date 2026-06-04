"""Admin dashboard database queries."""

import asyncpg


async def get_admin_stats(conn: asyncpg.Connection) -> dict:
    """Return top-level KPI stats for the admin dashboard."""
    row = await conn.fetchrow(
        """
        SELECT
            (SELECT COUNT(*) FROM users) AS total_users,
            (SELECT COUNT(*) FROM users
             WHERE last_login_at >= NOW() - INTERVAL '7 days') AS active_users_7d,
            (SELECT COUNT(*) FROM items WHERE is_active = true) AS total_items,
            (SELECT COUNT(*) FROM outfits) AS total_outfits,
            (SELECT COALESCE(SUM(value), 0) FROM analytics_daily
             WHERE date = CURRENT_DATE
               AND metric LIKE 'ai_cost_%') AS today_ai_spend,
            (SELECT COALESCE(SUM(value), 0) FROM analytics_daily
             WHERE date >= DATE_TRUNC('month', CURRENT_DATE)
               AND metric LIKE 'ai_cost_%') AS month_ai_spend
        """
    )
    return dict(row)


async def get_admin_stats_timeseries(
    conn: asyncpg.Connection, days: int = 30
) -> list[dict]:
    """Return daily stats (new_users, outfits_generated, ai_cost) for the last N days."""
    rows = await conn.fetch(
        """
        WITH date_series AS (
            SELECT generate_series(
                CURRENT_DATE - ($1 || ' days')::INTERVAL,
                CURRENT_DATE,
                '1 day'
            )::DATE AS day
        )
        SELECT
            ds.day,
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
    return [dict(r) for r in rows]


async def list_admin_users(
    conn: asyncpg.Connection,
    search: str | None = None,
    onboarding_filter: str | None = None,
    limit: int = 20,
    offset: int = 0,
) -> tuple[list[dict], int]:
    """Paginated user list with optional search and onboarding filter."""
    conditions = ["TRUE"]
    params: list = []
    idx = 1

    if search:
        conditions.append(
            f"(email ILIKE ${idx} OR phone ILIKE ${idx} OR display_name ILIKE ${idx})"
        )
        params.append(f"%{search}%")
        idx += 1

    if onboarding_filter == "done":
        conditions.append("onboarding_done = TRUE")
    elif onboarding_filter == "pending":
        conditions.append("onboarding_done = FALSE")

    where = " AND ".join(conditions)

    total = await conn.fetchval(
        f"SELECT COUNT(*) FROM users WHERE {where}", *params
    )

    params.extend([limit, offset])
    rows = await conn.fetch(
        f"""
        SELECT id, email, phone, display_name, photo_url,
               onboarding_done, is_admin, is_suspended, created_at, last_login_at
        FROM users
        WHERE {where}
        ORDER BY created_at DESC
        LIMIT ${idx} OFFSET ${idx + 1}
        """,
        *params,
    )
    return [dict(r) for r in rows], total


async def get_admin_user_detail(conn: asyncpg.Connection, user_id: str) -> dict | None:
    """Full user detail including aggregated counts and preferences."""
    row = await conn.fetchrow(
        """
        SELECT
            u.*,
            (SELECT COUNT(*) FROM items WHERE user_id = u.id AND is_active = true) AS item_count,
            (SELECT COUNT(*) FROM outfits WHERE user_id = u.id) AS outfit_count,
            (SELECT COUNT(*) FROM outfit_feedback WHERE user_id = u.id) AS feedback_count,
            (SELECT row_to_json(p) FROM preferences p WHERE p.user_id = u.id) AS preferences
        FROM users u
        WHERE u.id = $1
        """,
        user_id,
    )
    return dict(row) if row else None


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
    return dict(row) if row else None


async def delete_user(conn: asyncpg.Connection, user_id: str) -> bool:
    """Hard delete a user. CASCADE will handle related tables."""
    result = await conn.execute("DELETE FROM users WHERE id = $1", user_id)
    return result == "DELETE 1"


async def get_ai_usage(conn: asyncpg.Connection, days: int = 30) -> list[dict]:
    """AI usage breakdown by provider per day."""
    rows = await conn.fetch(
        """
        SELECT date, metric, value
        FROM analytics_daily
        WHERE metric LIKE 'ai_cost_%'
          AND date >= CURRENT_DATE - ($1 || ' days')::INTERVAL
        ORDER BY date, metric
        """,
        days,
    )
    return [dict(r) for r in rows]


async def get_system_health(conn: asyncpg.Connection) -> dict:
    """DB connectivity check and table row counts."""
    # Connectivity check
    db_ok = await conn.fetchval("SELECT 1") == 1

    # Row counts for all core tables
    tables = [
        "users", "preferences", "items", "outfits",
        "outfit_feedback", "lookbooks", "push_tokens", "analytics_daily",
    ]
    counts = {}
    for table in tables:
        counts[table] = await conn.fetchval(f"SELECT COUNT(*) FROM {table}")

    return {"db_connected": db_ok, "table_counts": counts}
