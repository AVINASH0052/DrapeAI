-- Migration: Virtual try-on / outfit visualization support.
--
-- users.try_on_photo_key  — full-body photo for "see me in this outfit"
-- outfits.preview_image_key — generated composite preview for an outfit

ALTER TABLE users ADD COLUMN IF NOT EXISTS try_on_photo_key TEXT;

ALTER TABLE outfits ADD COLUMN IF NOT EXISTS preview_image_key TEXT;
