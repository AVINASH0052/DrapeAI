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


async def send_daily_outfit_push(user_id: str, message_body: str) -> bool:
    """Send a push notification to a user."""
    _init_firebase()

    import firebase_admin
    from firebase_admin import messaging

    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT token, platform FROM push_tokens WHERE user_id = $1 AND is_active = true",
            user_id,
        )

    if not rows:
        return False

    for row in rows:
        try:
            msg = messaging.Message(
                notification=messaging.Notification(
                    title="DrapeAI",
                    body=message_body,
                ),
                data={"screen": "today_outfits"},
                token=row["token"],
            )
            messaging.send(msg)
            logger.info(f"Push sent to user {user_id} ({row['platform']})")
        except Exception as e:
            logger.error(f"Push failed for user {user_id}: {e}")

    return True
