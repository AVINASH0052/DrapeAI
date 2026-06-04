-- Migration: Notification system
-- Stores in-app notifications for users (distinct from push tokens).

CREATE TABLE IF NOT EXISTS notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    type        TEXT NOT NULL DEFAULT 'info'
                    CHECK (type IN ('info', 'outfit', 'wardrobe', 'system', 'promo')),
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    data        TEXT,           -- optional JSON payload (e.g. outfit_id, item_id)
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user
    ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON notifications(user_id) WHERE is_read = FALSE;
