-- Migration: Fix embedding dimension mismatch.
--
-- The items table currently defines `embedding vector(1536)` (OpenAI text-embedding-3-small).
-- The primary embedding model is now NVIDIA nv-embedqa-e5-v5 which produces 1024-dim vectors.
-- This migration changes the column to 1024 dimensions.
--
-- NOTE: Existing embeddings (if any were stored at 1536) will need to be re-generated.
-- The system handles missing/null embeddings gracefully — pairing falls back to rule-based scoring.

-- Drop the old IVFFlat index (dimension-specific)
DROP INDEX IF EXISTS idx_items_embedding;

-- Alter the column dimension
ALTER TABLE items ALTER COLUMN embedding TYPE vector(1024);

-- Recreate the index for 1024-dim vectors
CREATE INDEX IF NOT EXISTS idx_items_embedding
    ON items USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
