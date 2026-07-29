-- Phase 2: external outfit try-on sessions (shop / screenshot garments)
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
