"""items.garment_size and items.garment_fit

Revision ID: 0011_item_size_fit
Revises: 0010_avatar_slot_fingerprint
"""

from alembic import op

revision = "0011_item_size_fit"
down_revision = "0010_avatar_slot_fingerprint"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE items ADD COLUMN IF NOT EXISTS garment_size TEXT")
    op.execute("ALTER TABLE items ADD COLUMN IF NOT EXISTS garment_fit TEXT")


def downgrade() -> None:
    op.execute("ALTER TABLE items DROP COLUMN IF EXISTS garment_fit")
    op.execute("ALTER TABLE items DROP COLUMN IF EXISTS garment_size")
