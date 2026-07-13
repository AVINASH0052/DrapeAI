-- Cache vision-based pre-flight checks on wardrobe items used as try-on
-- garment references, so repeated visualize calls don't re-pay for a vision
-- LLM call per item. Keyed by image_url so a re-uploaded photo re-checks.

ALTER TABLE items ADD COLUMN IF NOT EXISTS tryon_ref_checked_key TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS tryon_ref_ok BOOLEAN;
ALTER TABLE items ADD COLUMN IF NOT EXISTS tryon_ref_issue TEXT;
ALTER TABLE items ADD COLUMN IF NOT EXISTS tryon_ref_reason TEXT;
