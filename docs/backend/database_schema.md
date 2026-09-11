# Sugatai -- Database Schema (PostgreSQL)

All metadata, relationships, and state live in **PostgreSQL** via asyncpg. Images live in **Cloudflare R2**. Vector embeddings use the **pgvector** extension in the same PostgreSQL instance.

> Schema source of truth: `api/db/init.sql` + `api/db/migrations/`

---

## Extensions

```sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "vector";      -- pgvector for item embeddings
```

---

## Tables

### 1. users -- Identity

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid    TEXT UNIQUE NOT NULL,     -- matches Firebase Auth UID
    phone           TEXT,                      -- phone OTP sign-in
    email           TEXT,                      -- Google sign-in
    name            TEXT,
    avatar_url      TEXT,                      -- profile photo URL
    auth_provider   TEXT NOT NULL DEFAULT 'phone'
                        CHECK (auth_provider IN ('phone', 'google')),
    plan            TEXT NOT NULL DEFAULT 'free'
                        CHECK (plan IN ('free', 'pro')),
    status          TEXT NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'suspended', 'deleted')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ              -- soft delete
);

CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;
CREATE INDEX idx_users_phone ON users(phone) WHERE phone IS NOT NULL;
```

---

### 2. preferences -- Onboarding Quiz Results + Style Profile

```sql
CREATE TABLE preferences (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    style_tags      TEXT[] NOT NULL DEFAULT '{}',   -- ['minimalist', 'streetwear', 'ethnic']
    occasions       TEXT[] NOT NULL DEFAULT '{}',   -- ['casual', 'work', 'party', 'gym', 'date', 'festive']
    color_palette   TEXT[] NOT NULL DEFAULT '{}',   -- ['earth_tones', 'neutrals', 'bold']
    preferred_fit   TEXT DEFAULT 'regular'
                        CHECK (preferred_fit IN ('slim', 'regular', 'relaxed', 'oversized')),
    city            TEXT,                            -- for weather API
    climate         TEXT DEFAULT 'tropical'
                        CHECK (climate IN ('tropical', 'subtropical', 'temperate', 'arid', 'cold')),
    gender          TEXT
                        CHECK (gender IN ('male', 'female', 'non_binary', 'prefer_not_to_say')),
    quiz_completed  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_preferences_user_id ON preferences(user_id);
```

---

### 3. items -- Wardrobe Pieces

```sql
CREATE TABLE items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_url       TEXT NOT NULL,                    -- R2 key: users/{user_id}/items/{item_id}.png
    thumbnail_url   TEXT,                             -- R2 key: smaller version for grid

    -- AI-generated tags (editable by user)
    category        TEXT NOT NULL,                    -- 'top', 'bottom', 'footwear', 'outerwear', 'accessory', 'ethnic', 'full_body'
    sub_category    TEXT,                             -- 'tshirt', 'shirt', 'kurta', 'saree', 'jeans', 'trousers', 'sneakers', etc.
    primary_color   TEXT NOT NULL,                    -- 'navy', 'white', 'red', 'beige', etc.
    secondary_colors TEXT[] DEFAULT '{}',             -- additional colors in the item
    pattern         TEXT DEFAULT 'solid',             -- 'solid', 'striped', 'checked', 'floral', 'printed', 'embroidered'
    fabric          TEXT,                             -- 'cotton', 'denim', 'silk', 'polyester', 'linen', 'wool', 'chiffon'
    style_tags      TEXT[] DEFAULT '{}',              -- ['casual', 'formal', 'sporty', 'ethnic', 'fusion']
    formality       SMALLINT NOT NULL DEFAULT 3       -- 1 (very casual) to 5 (very formal)
                        CHECK (formality BETWEEN 1 AND 5),
    season_tags     TEXT[] DEFAULT '{}',              -- ['summer', 'winter', 'monsoon', 'all_season']
    ethnic_flag     BOOLEAN NOT NULL DEFAULT FALSE,   -- true for saree, kurta, lehenga, sherwani, etc.

    -- Embedding for similarity search
    embedding       vector(1536),                     -- OpenAI text-embedding-3-small

    -- User-entered optional data
    brand           TEXT,
    purchase_price  INTEGER,                          -- in paise (INR x 100). NULL = not entered.
    purchase_date   DATE,
    notes           TEXT,

    -- Tracking
    wear_count      INTEGER NOT NULL DEFAULT 0,
    last_worn_at    TIMESTAMPTZ,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,    -- false = archived/donated
    is_demo         BOOLEAN NOT NULL DEFAULT FALSE,   -- true = demo wardrobe item

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_items_user_id ON items(user_id);
CREATE INDEX idx_items_user_category ON items(user_id, category);
CREATE INDEX idx_items_user_active ON items(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_items_embedding ON items USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

**Category taxonomy:**

| category | sub_category values |
|---|---|
| `top` | tshirt, shirt, polo, blouse, crop_top, tank_top, sweater, hoodie, sweatshirt |
| `bottom` | jeans, trousers, chinos, shorts, skirt, palazzo, joggers |
| `outerwear` | jacket, blazer, coat, cardigan, vest, windbreaker |
| `footwear` | sneakers, formal_shoes, sandals, boots, heels, flats, loafers, kolhapuri |
| `accessory` | watch, belt, bag, sunglasses, scarf, hat, jewelry, dupatta |
| `ethnic` | kurta, saree, lehenga, sherwani, dhoti, salwar, churidar, anarkali, nehru_jacket |
| `full_body` | dress, jumpsuit, romper, suit |

---

### 4. outfits -- Generated or Saved Outfit Combinations

```sql
CREATE TABLE outfits (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Items in this outfit (ordered: top, bottom, footwear, outerwear, accessories)
    item_ids        UUID[] NOT NULL,

    -- Generation context
    occasion        TEXT,                             -- 'casual', 'work', 'party', 'gym', 'date', 'festive'
    weather_temp    REAL,                             -- temperature at generation time
    weather_cond    TEXT,                             -- 'clear', 'cloudy', 'rain', 'cold'
    generated_by    TEXT NOT NULL DEFAULT 'ai'
                        CHECK (generated_by IN ('ai', 'shuffle', 'manual')),

    -- AI metadata
    rule_score      REAL,                             -- score from rule engine (0-100)
    llm_rank        SMALLINT,                         -- 1, 2, or 3 from LLM ranker
    llm_reason      TEXT,                             -- "Navy kurta pairs well with white chinos for a smart-casual festive look"

    -- State
    is_saved        BOOLEAN NOT NULL DEFAULT FALSE,   -- user explicitly saved this
    is_worn         BOOLEAN NOT NULL DEFAULT FALSE,   -- user marked as worn

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_outfits_user_id ON outfits(user_id);
CREATE INDEX idx_outfits_user_saved ON outfits(user_id) WHERE is_saved = TRUE;
CREATE INDEX idx_outfits_user_date ON outfits(user_id, created_at);
```

---

### 5. outfit_feedback -- Thumbs Up/Down on Recommendations

```sql
CREATE TABLE outfit_feedback (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    outfit_id       UUID NOT NULL REFERENCES outfits(id) ON DELETE CASCADE,
    action          TEXT NOT NULL
                        CHECK (action IN ('like', 'dislike', 'save', 'wear', 'skip')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_feedback_user_outfit ON outfit_feedback(user_id, outfit_id, action);
CREATE INDEX idx_feedback_user_recent ON outfit_feedback(user_id, created_at DESC);
```

---

### 6. lookbooks -- Named Outfit Collections

```sql
CREATE TABLE lookbooks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,                    -- 'Work', 'Weekend', 'Party', 'Travel'
    cover_outfit_id UUID REFERENCES outfits(id),     -- first outfit = cover image
    sort_order      SMALLINT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_lookbooks_user_id ON lookbooks(user_id);
CREATE UNIQUE INDEX idx_lookbooks_user_name ON lookbooks(user_id, name);
```

---

### 7. lookbook_outfits -- Join Table

```sql
CREATE TABLE lookbook_outfits (
    lookbook_id     UUID NOT NULL REFERENCES lookbooks(id) ON DELETE CASCADE,
    outfit_id       UUID NOT NULL REFERENCES outfits(id) ON DELETE CASCADE,
    added_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (lookbook_id, outfit_id)
);
```

---

### 8. wear_log -- Daily Wear Tracking

```sql
CREATE TABLE wear_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_id         UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    outfit_id       UUID REFERENCES outfits(id),     -- NULL if standalone wear
    worn_on         DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wear_log_user_date ON wear_log(user_id, worn_on);
CREATE INDEX idx_wear_log_item ON wear_log(item_id);
CREATE UNIQUE INDEX idx_wear_log_item_date ON wear_log(item_id, worn_on);  -- max 1 wear per item per day
```

---

### 9. outfit_calendar -- Planned Outfits (v1.1)

```sql
CREATE TABLE outfit_calendar (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    outfit_id       UUID NOT NULL REFERENCES outfits(id) ON DELETE CASCADE,
    planned_date    DATE NOT NULL,
    occasion        TEXT,
    notes           TEXT,
    notified        BOOLEAN NOT NULL DEFAULT FALSE,   -- morning push sent
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_calendar_user_date ON outfit_calendar(user_id, planned_date);
CREATE INDEX idx_calendar_pending ON outfit_calendar(planned_date) WHERE notified = FALSE;
```

---

### 10. outfit_cache -- 24h Outfit Generation Cache

```sql
CREATE TABLE outfit_cache (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cache_date      DATE NOT NULL,
    occasion        TEXT NOT NULL,
    outfit_ids      UUID[] NOT NULL,                  -- the 3 outfit IDs
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_cache_lookup ON outfit_cache(user_id, cache_date, occasion);
CREATE INDEX idx_cache_expiry ON outfit_cache(expires_at);
```

---

### 11. weather_cache -- Hourly Weather Cache

```sql
CREATE TABLE weather_cache (
    city            TEXT PRIMARY KEY,
    temp_celsius    REAL NOT NULL,
    condition       TEXT NOT NULL,                    -- 'clear', 'cloudy', 'rain', 'thunderstorm', 'snow', 'mist'
    humidity        SMALLINT,
    fetched_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cleanup: DELETE FROM weather_cache WHERE fetched_at < NOW() - INTERVAL '2 hours'
```

---

### 12. push_tokens -- FCM Device Tokens

```sql
CREATE TABLE push_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token           TEXT NOT NULL,
    platform        TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_push_tokens_token ON push_tokens(token);
CREATE INDEX idx_push_tokens_user ON push_tokens(user_id) WHERE is_active = TRUE;
```

---

### 13. analytics_daily -- Pre-Aggregated Analytics (v1.1)

```sql
CREATE TABLE analytics_daily (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    report_date     DATE NOT NULL,

    total_items     INTEGER NOT NULL DEFAULT 0,
    items_worn      INTEGER NOT NULL DEFAULT 0,       -- unique items worn that day
    utilisation_pct REAL NOT NULL DEFAULT 0,           -- items_worn_ever / total_items * 100
    most_worn_id    UUID REFERENCES items(id),
    least_worn_id   UUID REFERENCES items(id),

    -- Color breakdown (JSON for flexibility)
    color_breakdown JSONB DEFAULT '{}',               -- {"navy": 12, "white": 8, "black": 6}
    category_breakdown JSONB DEFAULT '{}',            -- {"top": 15, "bottom": 8, "footwear": 5}

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_analytics_user_date ON analytics_daily(user_id, report_date);
```

---

## Migrations

Migrations are SQL files in `api/db/migrations/` numbered sequentially:

```
api/db/migrations/
  001_init.sql              -- creates all tables above (MVP set)
  002_add_calendar.sql      -- v1.1: outfit_calendar table
  003_add_analytics.sql     -- v1.1: analytics_daily table
  004_add_cost_per_wear.sql -- v1.1: purchase_price, cost_per_wear views
```

Migrations run automatically at FastAPI startup:
```python
async def run_migrations(pool):
    async with pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS _migrations (
                filename TEXT PRIMARY KEY,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
        """)
        applied = {row["filename"] for row in await conn.fetch("SELECT filename FROM _migrations")}
        migration_dir = Path(__file__).parent / "migrations"
        for sql_file in sorted(migration_dir.glob("*.sql")):
            if sql_file.name not in applied:
                logger.info(f"Applying migration: {sql_file.name}")
                await conn.execute(sql_file.read_text())
                await conn.execute(
                    "INSERT INTO _migrations (filename) VALUES ($1)", sql_file.name
                )
```

---

## Useful Queries

### Get full wardrobe for outfit generation
```sql
SELECT id, category, sub_category, primary_color, secondary_colors,
       pattern, fabric, style_tags, formality, season_tags, ethnic_flag
FROM items
WHERE user_id = $1 AND is_active = TRUE
ORDER BY category, created_at;
```

### Get recent feedback for LLM context
```sql
SELECT of.action, o.item_ids, o.occasion, o.llm_reason
FROM outfit_feedback of
JOIN outfits o ON o.id = of.outfit_id
WHERE of.user_id = $1
ORDER BY of.created_at DESC
LIMIT 20;
```

### Wardrobe utilisation percentage
```sql
SELECT
    COUNT(*) AS total_items,
    COUNT(*) FILTER (WHERE wear_count > 0) AS worn_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE wear_count > 0) / NULLIF(COUNT(*), 0), 1) AS utilisation_pct
FROM items
WHERE user_id = $1 AND is_active = TRUE;
```

### Cost per wear (for items with purchase_price)
```sql
SELECT id, sub_category, primary_color, purchase_price, wear_count,
       CASE WHEN wear_count > 0 THEN purchase_price / wear_count ELSE purchase_price END AS cost_per_wear
FROM items
WHERE user_id = $1 AND purchase_price IS NOT NULL AND is_active = TRUE
ORDER BY cost_per_wear DESC;
```

### Find similar items (pgvector)
```sql
SELECT id, category, sub_category, primary_color,
       1 - (embedding <=> $2) AS similarity
FROM items
WHERE user_id = $1 AND is_active = TRUE AND id != $3
ORDER BY embedding <=> $2
LIMIT 5;
```
