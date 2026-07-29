-- Track async AI tagging for wardrobe uploads.
-- ready = usable; queued/processing = analysis in background; failed = needs retry.

ALTER TABLE items
    ADD COLUMN IF NOT EXISTS processing_status TEXT NOT NULL DEFAULT 'ready';

ALTER TABLE items
    DROP CONSTRAINT IF EXISTS items_processing_status_check;

ALTER TABLE items
    ADD CONSTRAINT items_processing_status_check
    CHECK (processing_status IN ('queued', 'processing', 'ready', 'failed'));

CREATE INDEX IF NOT EXISTS idx_items_user_processing
    ON items(user_id, processing_status)
    WHERE is_active = TRUE AND processing_status IN ('queued', 'processing');
