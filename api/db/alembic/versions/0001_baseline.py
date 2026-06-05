"""baseline: init.sql + migrations 0002-0007

Revision ID: 0001_baseline
Revises:
Create Date: 2025-06-05

This is a baseline migration that represents the full schema
as of init.sql + migrations 0002 through 0007.

For new databases: run init.sql directly (it's already synced).
For existing databases: stamp this revision without running it:
    alembic stamp 0001_baseline
"""

revision = "0001_baseline"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    """No-op for baseline.

    The schema is already in place via init.sql (new databases)
    or via manual migrations 0002-0007 (existing databases).

    Included DDL (for documentation):
    - users: id, phone, email, display_name, photo_url, onboarding_done,
             is_admin, is_suspended, is_active, last_login_at, created_at
    - preferences: + body_type, skin_tone, budget_range, preferred_brands, avoid_colors
    - items: secondary_colors/style_tags/season_tags as JSONB with GIN indexes,
             embedding vector(1024)
    - outfits: + worn_date DATE with composite index
    - notifications: id, user_id, title, body, type, data, is_read, created_at
    - push_tokens, outfit_cache, weather_cache, analytics_daily, lookbooks, etc.
    """
    pass


def downgrade():
    """Cannot downgrade from baseline."""
    raise RuntimeError("Cannot downgrade past the baseline migration.")
