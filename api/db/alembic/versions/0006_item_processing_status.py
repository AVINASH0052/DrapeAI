"""async AI tagging status on items

Mirrors db/migrations/0012_item_processing_status.sql

Revision ID: 0006_item_processing_status
Revises: 0005_try_on_sessions
"""

from alembic import op

revision = "0006_item_processing_status"
down_revision = "0005_try_on_sessions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE items ADD COLUMN IF NOT EXISTS processing_status "
        "TEXT NOT NULL DEFAULT 'ready'"
    )
    op.execute(
        "ALTER TABLE items DROP CONSTRAINT IF EXISTS items_processing_status_check"
    )
    op.execute(
        """
        ALTER TABLE items
            ADD CONSTRAINT items_processing_status_check
            CHECK (processing_status IN ('queued', 'processing', 'ready', 'failed'))
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_items_user_processing
            ON items(user_id, processing_status)
            WHERE is_active = TRUE AND processing_status IN ('queued', 'processing')
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS idx_items_user_processing")
    op.execute(
        "ALTER TABLE items DROP CONSTRAINT IF EXISTS items_processing_status_check"
    )
    op.execute("ALTER TABLE items DROP COLUMN IF EXISTS processing_status")
