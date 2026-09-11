"""ARQ worker configuration.

Run with:  arq app.workers.worker.WorkerSettings
Or via Docker Compose 'worker' service.
"""

import logging

from arq import cron
from arq.connections import RedisSettings

from app.config import settings

logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


async def startup(ctx: dict) -> None:
    """Worker startup — initialize DB pool."""
    from app.database.pool import init_pool
    await init_pool()
    logger.info("ARQ worker started — DB pool initialized")


async def shutdown(ctx: dict) -> None:
    """Worker shutdown — close DB pool."""
    from app.database.pool import close_pool
    await close_pool()
    logger.info("ARQ worker stopped — DB pool closed")


def _parse_redis_url(*, fast_fail: bool = False) -> RedisSettings:
    """Parse redis_url into ARQ RedisSettings."""
    from urllib.parse import urlparse
    parsed = urlparse(settings.redis_url)
    return RedisSettings(
        host=parsed.hostname or "localhost",
        port=parsed.port or 6379,
        database=int(parsed.path.lstrip("/") or 0),
        password=parsed.password,
        conn_timeout=0.25 if fast_fail else 1,
        conn_retries=0 if fast_fail else 5,
    )


class WorkerSettings:
    """ARQ worker settings — functions, cron jobs, concurrency."""

    # Task functions the worker can execute
    functions = [
        "app.workers.tasks.process_avatar",
        "app.workers.tasks.process_upload",
        "app.workers.tasks.regenerate_embedding",
        "app.workers.tasks.process_try_on",
        "app.workers.tasks.process_try_on_refine",
        "app.workers.tasks.process_external_try_on",
    ]

    # Scheduled cron jobs
    cron_jobs = [
        # Daily outfit push at 7:30 AM IST (2:00 AM UTC)
        cron("app.workers.tasks.send_daily_push", hour=2, minute=0),
    ]

    # Worker config
    on_startup = startup
    on_shutdown = shutdown
    redis_settings = _parse_redis_url()
    max_jobs = 5        # Concurrent task limit
    # process_try_on can block on a cold RunPod worker for up to
    # RUNPOD_TRYON_TIMEOUT_SEC (~900s) plus fallback-provider time; this
    # ceiling must exceed that or ARQ kills the task before it can complete
    # or fail over. Other tasks (upload/embedding) finish in seconds, so a
    # higher ceiling doesn't change their behavior.
    job_timeout = 960   # 16 min max per task
    keep_result = 3600  # Keep results for 1 hour
    health_check_interval = 30
