"""outfits.slot_fingerprint for avatar-studio look cache

Revision ID: 0010_avatar_slot_fingerprint
Revises: 0009_try_on_job_directives
"""

from alembic import op

revision = "0010_avatar_slot_fingerprint"
down_revision = "0009_try_on_job_directives"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE outfits
            ADD COLUMN IF NOT EXISTS slot_fingerprint TEXT
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_outfits_avatar_fingerprint
            ON outfits (user_id, slot_fingerprint)
            WHERE occasion = 'avatar studio' AND slot_fingerprint IS NOT NULL
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS idx_outfits_avatar_fingerprint")
    op.execute("ALTER TABLE outfits DROP COLUMN IF EXISTS slot_fingerprint")
