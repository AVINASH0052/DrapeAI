"""try_on_visualization columns

Revision ID: 0002_try_on
Revises: 0001_baseline
"""

from alembic import op

revision = "0002_try_on"
down_revision = "0001_baseline"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS try_on_photo_key TEXT")
    op.execute(
        "ALTER TABLE outfits ADD COLUMN IF NOT EXISTS preview_image_key TEXT"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS try_on_photo_key")
    op.execute("ALTER TABLE outfits DROP COLUMN IF EXISTS preview_image_key")
