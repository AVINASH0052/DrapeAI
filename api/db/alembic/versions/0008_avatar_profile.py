"""persistent 2.5D avatar derived from the try-on photo

Mirrors db/migrations/0014_avatar_profile.sql

Revision ID: 0008_avatar_profile
Revises: 0007_item_display_name
"""

from alembic import op

revision = "0008_avatar_profile"
down_revision = "0007_item_display_name"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE users
            ADD COLUMN IF NOT EXISTS avatar_status TEXT NOT NULL DEFAULT 'missing',
            ADD COLUMN IF NOT EXISTS avatar_base_key TEXT,
            ADD COLUMN IF NOT EXISTS avatar_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
            ADD COLUMN IF NOT EXISTS avatar_error TEXT,
            ADD COLUMN IF NOT EXISTS avatar_analyzed_at TIMESTAMPTZ
        """
    )
    op.execute(
        "ALTER TABLE users DROP CONSTRAINT IF EXISTS users_avatar_status_check"
    )
    op.execute(
        """
        ALTER TABLE users
            ADD CONSTRAINT users_avatar_status_check
            CHECK (avatar_status IN
                   ('missing', 'queued', 'processing', 'ready', 'failed'))
        """
    )
    # Backfill: anyone who already saved a full-body photo has a usable avatar.
    op.execute(
        """
        UPDATE users
        SET avatar_status = 'ready',
            avatar_analyzed_at = NOW()
        WHERE try_on_photo_key IS NOT NULL
          AND avatar_status = 'missing'
        """
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE users DROP CONSTRAINT IF EXISTS users_avatar_status_check"
    )
    op.execute(
        """
        ALTER TABLE users
            DROP COLUMN IF EXISTS avatar_analyzed_at,
            DROP COLUMN IF EXISTS avatar_error,
            DROP COLUMN IF EXISTS avatar_profile,
            DROP COLUMN IF EXISTS avatar_base_key,
            DROP COLUMN IF EXISTS avatar_status
        """
    )
