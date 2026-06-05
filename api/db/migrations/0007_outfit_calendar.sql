-- Migration: Outfit Calendar support.
--
-- Adds a `worn_date` column to outfits so users can assign outfits to dates,
-- and an index for efficient monthly calendar queries.

-- Add worn_date to outfits (nullable — only set when user wears/plans an outfit)
ALTER TABLE outfits ADD COLUMN IF NOT EXISTS worn_date DATE;

-- Index for calendar queries: WHERE user_id = $1 AND worn_date BETWEEN $2 AND $3
CREATE INDEX IF NOT EXISTS idx_outfits_user_worn_date
    ON outfits(user_id, worn_date)
    WHERE worn_date IS NOT NULL;
