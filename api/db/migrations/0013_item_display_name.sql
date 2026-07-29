-- Optional user-facing name, separate from AI-generated sub_category.

ALTER TABLE items
    ADD COLUMN IF NOT EXISTS display_name TEXT;
