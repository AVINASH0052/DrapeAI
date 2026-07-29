-- DrapeAI database schema
-- Run via: psql -U drapeai -d drapeai -f init.sql

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================================
-- users
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id              TEXT PRIMARY KEY,           -- Firebase UID
    phone           TEXT,
    email           TEXT,
    display_name    TEXT,
    photo_url       TEXT,
    try_on_photo_key TEXT,                    -- full-body photo for outfit visualization
    avatar_status   TEXT NOT NULL DEFAULT 'missing'
        CHECK (avatar_status IN ('missing', 'queued', 'processing', 'ready', 'failed')),
    avatar_base_key TEXT,                     -- segmented 2.5D avatar base
    avatar_profile  JSONB NOT NULL DEFAULT '{}'::jsonb,
    avatar_error    TEXT,
    avatar_analyzed_at TIMESTAMPTZ,
    onboarding_done BOOLEAN NOT NULL DEFAULT FALSE,
    is_admin        BOOLEAN NOT NULL DEFAULT FALSE,
    is_suspended    BOOLEAN NOT NULL DEFAULT FALSE,
    suspended_at    TIMESTAMPTZ,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone) WHERE phone IS NOT NULL;

-- ============================================================
-- preferences
-- ============================================================
CREATE TABLE IF NOT EXISTS preferences (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Identity
    name                TEXT,
    age                 INTEGER,
    gender              TEXT,
    age_range           TEXT,                        -- legacy

    -- Style profile (JSON arrays stored as TEXT)
    style_goals         TEXT NOT NULL DEFAULT '[]',
    occasions           TEXT NOT NULL DEFAULT '[]',
    color_preferences   TEXT NOT NULL DEFAULT '[]',
    fit_preference      TEXT,

    -- Location / climate
    location_city       TEXT,
    climate             TEXT,

    -- Body / budget / lifestyle
    body_type           TEXT,
    skin_undertone      TEXT,                        -- warm | cool | neutral
    height_cm           INTEGER,
    budget_tier         TEXT,                        -- budget | mid | luxury
    lifestyle           TEXT NOT NULL DEFAULT '[]',

    -- Derived
    style_profile       TEXT,

    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_preferences_user_id ON preferences(user_id);

-- ============================================================
-- items
-- ============================================================
CREATE TABLE IF NOT EXISTS items (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_url        TEXT NOT NULL,             -- storage key: users/{uid}/items/{id}.png
    thumbnail_url    TEXT,

    -- AI-generated tags (editable)
    category         TEXT NOT NULL,
    sub_category     TEXT NOT NULL DEFAULT '',
    display_name     TEXT,
    primary_color    TEXT NOT NULL,
    secondary_colors JSONB NOT NULL DEFAULT '[]'::jsonb,
    pattern          TEXT NOT NULL DEFAULT 'solid',
    fabric           TEXT NOT NULL DEFAULT 'cotton',
    style_tags       JSONB NOT NULL DEFAULT '[]'::jsonb,
    formality        SMALLINT NOT NULL DEFAULT 3 CHECK (formality BETWEEN 1 AND 5),
    season_tags      JSONB NOT NULL DEFAULT '["all_season"]'::jsonb,
    ethnic_flag      BOOLEAN NOT NULL DEFAULT FALSE,
    confidence       REAL NOT NULL DEFAULT 0.0,
    processing_status TEXT NOT NULL DEFAULT 'ready'
        CHECK (processing_status IN ('queued', 'processing', 'ready', 'failed')),

    -- Vector embedding (1024-dim: NVIDIA NIM / text-embedding-3-small)
    embedding        vector(1024),

    -- User metadata
    brand            TEXT,
    purchase_price   INTEGER,   -- paise (INR x 100)
    purchase_date    DATE,
    notes            TEXT,

    -- Tracking
    wear_count       INTEGER NOT NULL DEFAULT 0,
    last_worn_at     TIMESTAMPTZ,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    is_demo          BOOLEAN NOT NULL DEFAULT FALSE,

    -- Try-on garment reference pre-flight check (cached by image_url)
    tryon_ref_checked_key TEXT,
    tryon_ref_ok           BOOLEAN,
    tryon_ref_issue        TEXT,
    tryon_ref_reason       TEXT,

    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_items_user_id ON items(user_id);
CREATE INDEX IF NOT EXISTS idx_items_user_category ON items(user_id, category);
CREATE INDEX IF NOT EXISTS idx_items_user_active ON items(user_id) WHERE is_active = TRUE;
-- IVFFlat index for approximate nearest neighbour search
-- (Only useful once you have >1000 items; safe to create early)
CREATE INDEX IF NOT EXISTS idx_items_embedding
    ON items USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- GIN indexes for JSONB containment queries (@>)
CREATE INDEX IF NOT EXISTS idx_items_style_tags ON items USING gin(style_tags);
CREATE INDEX IF NOT EXISTS idx_items_season_tags ON items USING gin(season_tags);
CREATE INDEX IF NOT EXISTS idx_items_secondary_colors ON items USING gin(secondary_colors);

-- ============================================================
-- outfits
-- ============================================================
CREATE TABLE IF NOT EXISTS outfits (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_ids        TEXT NOT NULL,              -- JSON array of item UUIDs
    occasion        TEXT,
    weather_temp    REAL,
    weather_cond    TEXT,
    generated_by    TEXT NOT NULL DEFAULT 'ai'
                        CHECK (generated_by IN ('ai', 'shuffle', 'manual')),
    rule_score      REAL,
    llm_rank        SMALLINT,
    llm_reason      TEXT,
    is_saved        BOOLEAN NOT NULL DEFAULT FALSE,
    is_worn         BOOLEAN NOT NULL DEFAULT FALSE,
    worn_date       DATE,                       -- Calendar: date the outfit was worn/planned
    preview_image_key TEXT,                   -- generated "see me in this outfit" image
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_outfits_user_id ON outfits(user_id);
CREATE INDEX IF NOT EXISTS idx_outfits_user_saved ON outfits(user_id) WHERE is_saved = TRUE;
CREATE INDEX IF NOT EXISTS idx_outfits_user_date ON outfits(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_outfits_user_worn_date ON outfits(user_id, worn_date) WHERE worn_date IS NOT NULL;

-- ============================================================
-- outfit_feedback
-- ============================================================
CREATE TABLE IF NOT EXISTS outfit_feedback (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    outfit_id   UUID NOT NULL REFERENCES outfits(id) ON DELETE CASCADE,
    action      TEXT NOT NULL
                    CHECK (action IN ('like', 'dislike', 'save', 'wear', 'skip')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_feedback_user_outfit
    ON outfit_feedback(user_id, outfit_id, action);
CREATE INDEX IF NOT EXISTS idx_feedback_user_recent
    ON outfit_feedback(user_id, created_at DESC);

-- ============================================================
-- lookbooks
-- ============================================================
CREATE TABLE IF NOT EXISTS lookbooks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    sort_order      SMALLINT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lookbooks_user_id ON lookbooks(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_lookbooks_user_name ON lookbooks(user_id, name);

-- ============================================================
-- lookbook_outfits (join table)
-- ============================================================
CREATE TABLE IF NOT EXISTS lookbook_outfits (
    lookbook_id UUID NOT NULL REFERENCES lookbooks(id) ON DELETE CASCADE,
    outfit_id   UUID NOT NULL REFERENCES outfits(id) ON DELETE CASCADE,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (lookbook_id, outfit_id)
);

-- ============================================================
-- outfit_cache (24h cache keyed by user+date+occasion)
-- ============================================================
CREATE TABLE IF NOT EXISTS outfit_cache (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    occasion    TEXT NOT NULL,
    cache_date  DATE NOT NULL,
    result      TEXT NOT NULL,  -- JSON array of outfit objects
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_cache_lookup
    ON outfit_cache(user_id, occasion, cache_date);

-- ============================================================
-- weather_cache (hourly)
-- ============================================================
CREATE TABLE IF NOT EXISTS weather_cache (
    city        TEXT PRIMARY KEY,
    temp        REAL NOT NULL,
    condition   TEXT NOT NULL,
    fetched_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- push_tokens
-- ============================================================
CREATE TABLE IF NOT EXISTS push_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       TEXT NOT NULL,
    platform    TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_push_tokens_user_platform
    ON push_tokens(user_id, platform);
CREATE INDEX IF NOT EXISTS idx_push_tokens_user
    ON push_tokens(user_id) WHERE is_active = TRUE;

-- ============================================================
-- analytics_daily (cost tracking + usage metrics)
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics_daily (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date        DATE NOT NULL DEFAULT CURRENT_DATE,
    metric      TEXT NOT NULL,
    value       REAL NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_analytics_date_metric
    ON analytics_daily(date, metric);

-- ============================================================
-- notifications
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    type        TEXT NOT NULL DEFAULT 'info',
    data        TEXT,
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id
    ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- ============================================================
-- try_on_sessions (external outfit / screenshot try-on)
-- ============================================================
CREATE TABLE IF NOT EXISTS try_on_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reference_image_key TEXT NOT NULL,
    result_image_key    TEXT,
    prompt_version      TEXT NOT NULL DEFAULT 'external_tryon_v1',
    provider            TEXT,
    model               TEXT,
    method              TEXT,
    status              TEXT NOT NULL DEFAULT 'queued',
    error_message       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_try_on_sessions_user
    ON try_on_sessions(user_id, created_at DESC);

-- ============================================================
-- try_on_jobs (async outfit visualization)
-- ============================================================
CREATE TABLE IF NOT EXISTS try_on_jobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    outfit_id       UUID REFERENCES outfits(id) ON DELETE CASCADE,
    session_id      UUID,
    status          TEXT NOT NULL DEFAULT 'queued',
    provider        TEXT,
    model           TEXT,
    method          TEXT,
    result_key      TEXT,
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_try_on_jobs_user_created
    ON try_on_jobs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_try_on_jobs_outfit
    ON try_on_jobs(outfit_id) WHERE outfit_id IS NOT NULL;
