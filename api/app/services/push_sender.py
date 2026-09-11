"""Send push notifications via Firebase Cloud Messaging."""

import logging

from app.database.pool import get_pool

logger = logging.getLogger(__name__)

_app_initialized = False


def _init_firebase():
    global _app_initialized
    if not _app_initialized:
        import firebase_admin

        firebase_admin.initialize_app()
        _app_initialized = True


async def send_push_to_user(
    user_id: str,
    title: str,
    body: str,
    deep_link: str | None = None,
) -> bool:
    """Record an in-app notification and send FCM to active tokens.

    In-app inbox is always written so the Flutter notifications screen works
    even when the device has no push token yet.
    """
    import json

    from app.database.queries.notifications import create_notification

    screen = deep_link or "today_outfits"
    pool = await get_pool()
    async with pool.acquire() as conn:
        try:
            await create_notification(
                conn,
                user_id,
                title=title,
                body=body,
                notif_type="push",
                data=json.dumps({"screen": screen}),
            )
        except Exception as e:
            logger.error("In-app notification failed for user %s: %s", user_id, e)

        rows = await conn.fetch(
            "SELECT token, platform FROM push_tokens WHERE user_id = $1 AND is_active = true",
            user_id,
        )

    if not rows:
        return False

    try:
        _init_firebase()
        from firebase_admin import messaging
    except Exception as e:
        logger.error("Firebase init failed; in-app notification kept: %s", e)
        return False

    data = {"screen": screen}
    any_ok = False
    for row in rows:
        try:
            msg = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data,
                token=row["token"],
            )
            messaging.send(msg)
            logger.info("Push sent to user %s (%s)", user_id, row["platform"])
            any_ok = True
        except Exception as e:
            logger.error("Push failed for user %s: %s", user_id, e)

    return any_ok


async def send_push_to_users(
    user_ids: list[str],
    title: str,
    body: str,
    deep_link: str | None = None,
) -> int:
    """Send push to many users. Returns count of users successfully notified."""
    sent = 0
    for uid in user_ids:
        try:
            ok = await send_push_to_user(uid, title, body, deep_link)
            if ok:
                sent += 1
        except Exception as e:
            logger.error("Push failed for user %s: %s", uid, e)
    return sent


async def send_daily_outfit_push(user_id: str, message_body: str) -> bool:
    """Send a push notification to a user (legacy morning outfit helper)."""
    return await send_push_to_user(
        user_id,
        title="Sugatai",
        body=message_body,
        deep_link="today_outfits",
    )


async def send_daily_outfit_pushes_batch() -> int:
    """Send morning outfit reminder to all users with active push tokens.

    Called by ARQ cron. Returns count of users notified.
    """
    pool = await get_pool()
    async with pool.acquire() as conn:
        user_ids = await conn.fetch(
            """
            SELECT DISTINCT user_id FROM push_tokens WHERE is_active = TRUE
            """
        )

    body = "Your outfit for today is ready — open Sugatai to see it."
    return await send_push_to_users(
        [row["user_id"] for row in user_ids],
        title="Sugatai",
        body=body,
        deep_link="today_outfits",
    )
