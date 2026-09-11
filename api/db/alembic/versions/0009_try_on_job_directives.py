"""try_on_jobs.directives for post-result preview refine

Revision ID: 0009_try_on_job_directives
Revises: 0008_avatar_profile
"""

from alembic import op

revision = "0009_try_on_job_directives"
down_revision = "0008_avatar_profile"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE try_on_jobs
            ADD COLUMN IF NOT EXISTS directives TEXT
        """
    )


def downgrade() -> None:
    op.execute(
        """
        ALTER TABLE try_on_jobs
            DROP COLUMN IF EXISTS directives
        """
    )
