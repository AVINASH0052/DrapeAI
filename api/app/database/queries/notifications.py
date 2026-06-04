"""Notification query functions."""

from datetime import datetime


async def get_notifications(
    conn, user_id: str, limit: int = 30, offset: int = 0
) -> tuple[list[dict], int]:
    """Get paginated notifications for a user, newest first."""
    total = await conn.fetchval(
        "SELECT COUNT(*) FROM notifications WHERE user_id = $1",
        user_id,
    )
    rows = await conn.fetch(
        """SELECT id, title, body, type, is_read, data, created_at
           FROM notifications
           WHERE user_id = $1
           ORDER BY created_at DESC
           LIMIT $2 OFFSET $3""",
        user_id, limit, offset,
    )
    items = [dict(r) for r in rows]
    # Convert datetime to ISO string for JSON serialization
    for item in items:
        if isinstance(item.get("created_at"), datetime):
            item["created_at"] = item["created_at"].isoformat()
    return items, total


async def get_unread_count(conn, user_id: str) -> int:
    """Count unread notifications for badge display."""
    return await conn.fetchval(
        "SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE",
        user_id,
    )


async def mark_notification_read(conn, notification_id: str, user_id: str) -> bool:
    """Mark a single notification as read. Returns True if found."""
    result = await conn.execute(
        "UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2",
        notification_id, user_id,
    )
    return result != "UPDATE 0"


async def mark_all_read(conn, user_id: str) -> int:
    """Mark all notifications as read. Returns count updated."""
    result = await conn.execute(
        "UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND is_read = FALSE",
        user_id,
    )
    # result is like "UPDATE 5"
    return int(result.split()[-1])


async def create_notification(
    conn,
    user_id: str,
    title: str,
    body: str,
    notif_type: str = "info",
    data: str | None = None,
) -> dict:
    """Create an in-app notification. Returns the created notification."""
    row = await conn.fetchrow(
        """INSERT INTO notifications (user_id, title, body, type, data)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING id, title, body, type, is_read, data, created_at""",
        user_id, title, body, notif_type, data,
    )
    result = dict(row)
    if isinstance(result.get("created_at"), datetime):
        result["created_at"] = result["created_at"].isoformat()
    return result
