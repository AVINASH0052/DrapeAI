-- Persistent 2.5D avatar derived from the user's full-body try-on photo.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS avatar_status TEXT NOT NULL DEFAULT 'missing',
    ADD COLUMN IF NOT EXISTS avatar_base_key TEXT,
    ADD COLUMN IF NOT EXISTS avatar_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS avatar_error TEXT,
    ADD COLUMN IF NOT EXISTS avatar_analyzed_at TIMESTAMPTZ;

ALTER TABLE users
    DROP CONSTRAINT IF EXISTS users_avatar_status_check;

ALTER TABLE users
    ADD CONSTRAINT users_avatar_status_check
    CHECK (avatar_status IN ('missing', 'queued', 'processing', 'ready', 'failed'));

UPDATE users
SET avatar_status = 'ready',
    avatar_analyzed_at = NOW()
WHERE try_on_photo_key IS NOT NULL
  AND avatar_status = 'missing';
