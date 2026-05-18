-- Extend preferences with comprehensive user profile fields for AI personalization
ALTER TABLE preferences
    ALTER COLUMN age_range DROP NOT NULL,
    ALTER COLUMN gender DROP NOT NULL,
    ALTER COLUMN style_goals DROP NOT NULL,
    ALTER COLUMN color_preferences DROP NOT NULL,
    ALTER COLUMN location_city DROP NOT NULL;

ALTER TABLE preferences
    ADD COLUMN IF NOT EXISTS name           TEXT,
    ADD COLUMN IF NOT EXISTS age            INT,
    ADD COLUMN IF NOT EXISTS body_type      TEXT,
    ADD COLUMN IF NOT EXISTS skin_undertone TEXT,
    ADD COLUMN IF NOT EXISTS height_cm      INT,
    ADD COLUMN IF NOT EXISTS budget_tier    TEXT,
    ADD COLUMN IF NOT EXISTS lifestyle      TEXT NOT NULL DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS occasions      TEXT NOT NULL DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS fit_preference TEXT,
    ADD COLUMN IF NOT EXISTS climate        TEXT,
    ADD COLUMN IF NOT EXISTS style_profile  TEXT;

-- analytics_daily already supports per-metric tracking via (date, metric, value).
-- We will write metrics like "ai_cost_openai", "ai_cost_anthropic", etc.
