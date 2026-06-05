-- Migration: Convert TEXT JSON columns to native JSONB.
--
-- The items table stores secondary_colors, style_tags, and season_tags as
-- TEXT with json.dumps(). This prevents SQL-level querying and indexing.
--
-- JSONB benefits:
--   1. GIN indexes for containment queries: WHERE style_tags @> '["casual"]'
--   2. No json.dumps/loads needed — asyncpg handles JSONB natively
--   3. Validation: Postgres rejects malformed JSON on write
--
-- This is a zero-downtime migration — USING col::jsonb does the cast inline.

-- Convert columns
ALTER TABLE items ALTER COLUMN secondary_colors TYPE JSONB USING secondary_colors::jsonb;
ALTER TABLE items ALTER COLUMN style_tags TYPE JSONB USING style_tags::jsonb;
ALTER TABLE items ALTER COLUMN season_tags TYPE JSONB USING season_tags::jsonb;

-- Set proper defaults (JSONB '[]' instead of TEXT '[]')
ALTER TABLE items ALTER COLUMN secondary_colors SET DEFAULT '[]'::jsonb;
ALTER TABLE items ALTER COLUMN style_tags SET DEFAULT '[]'::jsonb;
ALTER TABLE items ALTER COLUMN season_tags SET DEFAULT '["all_season"]'::jsonb;

-- GIN indexes for containment queries (@>)
CREATE INDEX IF NOT EXISTS idx_items_style_tags ON items USING gin(style_tags);
CREATE INDEX IF NOT EXISTS idx_items_season_tags ON items USING gin(season_tags);
CREATE INDEX IF NOT EXISTS idx_items_secondary_colors ON items USING gin(secondary_colors);
