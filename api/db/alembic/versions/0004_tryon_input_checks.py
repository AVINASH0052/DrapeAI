"""cached try-on reference pre-flight checks on items

Mirrors db/migrations/0010_tryon_input_checks.sql

Revision ID: 0004_tryon_input_checks
Revises: 0003_try_on_jobs
"""

from alembic import op

revision = "0004_tryon_input_checks"
down_revision = "0003_try_on_jobs"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE items ADD COLUMN IF NOT EXISTS tryon_ref_checked_key TEXT"
    )
    op.execute("ALTER TABLE items ADD COLUMN IF NOT EXISTS tryon_ref_ok BOOLEAN")
    op.execute("ALTER TABLE items ADD COLUMN IF NOT EXISTS tryon_ref_issue TEXT")
    op.execute("ALTER TABLE items ADD COLUMN IF NOT EXISTS tryon_ref_reason TEXT")


def downgrade() -> None:
    op.execute("ALTER TABLE items DROP COLUMN IF EXISTS tryon_ref_reason")
    op.execute("ALTER TABLE items DROP COLUMN IF EXISTS tryon_ref_issue")
    op.execute("ALTER TABLE items DROP COLUMN IF EXISTS tryon_ref_ok")
    op.execute("ALTER TABLE items DROP COLUMN IF EXISTS tryon_ref_checked_key")
