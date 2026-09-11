"""external outfit try-on sessions

Mirrors db/migrations/0011_try_on_sessions.sql

Revision ID: 0005_try_on_sessions
Revises: 0004_tryon_input_checks
"""

from alembic import op

revision = "0005_try_on_sessions"
down_revision = "0004_tryon_input_checks"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS try_on_sessions (
            id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            reference_image_key TEXT NOT NULL,
            result_image_key    TEXT,
            prompt_version      TEXT NOT NULL DEFAULT 'external_tryon_v1',
            provider            TEXT,
            model               TEXT,
            method              TEXT,
            status              TEXT NOT NULL DEFAULT 'queued',
            error_message       TEXT,
            created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            completed_at        TIMESTAMPTZ
        )
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS idx_try_on_sessions_user "
        "ON try_on_sessions(user_id, created_at DESC)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS idx_try_on_sessions_user")
    op.execute("DROP TABLE IF EXISTS try_on_sessions")
