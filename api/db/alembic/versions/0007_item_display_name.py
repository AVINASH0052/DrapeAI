"""optional user-facing item name

Mirrors db/migrations/0013_item_display_name.sql

Revision ID: 0007_item_display_name
Revises: 0006_item_processing_status
"""

from alembic import op

revision = "0007_item_display_name"
down_revision = "0006_item_processing_status"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE items ADD COLUMN IF NOT EXISTS display_name TEXT")


def downgrade() -> None:
    op.execute("ALTER TABLE items DROP COLUMN IF EXISTS display_name")
