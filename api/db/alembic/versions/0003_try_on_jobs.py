"""try_on_jobs table

Revision ID: 0003_try_on_jobs
Revises: 0002_try_on
"""

from alembic import op

revision = "0003_try_on_jobs"
down_revision = "0002_try_on"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS try_on_jobs (
            id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            outfit_id       UUID REFERENCES outfits(id) ON DELETE CASCADE,
            session_id      UUID,
            status          TEXT NOT NULL DEFAULT 'queued',
            provider        TEXT,
            model           TEXT,
            method          TEXT,
            result_key      TEXT,
            error_message   TEXT,
            created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            started_at      TIMESTAMPTZ,
            completed_at    TIMESTAMPTZ
        )
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS idx_try_on_jobs_user_created "
        "ON try_on_jobs(user_id, created_at DESC)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS idx_try_on_jobs_outfit "
        "ON try_on_jobs(outfit_id) WHERE outfit_id IS NOT NULL"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS try_on_jobs")
