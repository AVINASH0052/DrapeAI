-- Public landing-page early-access waitlist (no auth).

CREATE TABLE IF NOT EXISTS waitlist_emails (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'landing',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT waitlist_emails_email_unique UNIQUE (email)
);

CREATE INDEX IF NOT EXISTS idx_waitlist_emails_created_at
    ON waitlist_emails (created_at DESC);
