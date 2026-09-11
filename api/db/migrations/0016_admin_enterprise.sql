-- Enterprise admin: support notes, content flagging, audit log

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS admin_notes TEXT;

ALTER TABLE items
    ADD COLUMN IF NOT EXISTS is_flagged BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS flagged_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS flagged_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_items_flagged
    ON items (flagged_at DESC) WHERE is_flagged = TRUE;

CREATE TABLE IF NOT EXISTS admin_audit_log (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id    TEXT REFERENCES users(id) ON DELETE SET NULL,
    action      TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id   TEXT,
    meta        JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created
    ON admin_audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin
    ON admin_audit_log (admin_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_target
    ON admin_audit_log (target_type, target_id);
