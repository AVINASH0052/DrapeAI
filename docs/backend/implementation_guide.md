# DrapeAI Backend -- Implementation Guide

Step-by-step instructions: what to build, in what order, every file, with code.

---

## Phase 1 -- Project Scaffold

### What you're building
The FastAPI project skeleton with config, database connection pool, and health endpoint.

### Files to create

```
api/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── database/
│   │   ├── __init__.py
│   │   └── pool.py
│   └── routes/
│       ├── __init__.py
│       └── health.py
├── .env
├── .env.example
└── requirements.txt
```

### Step 1.1 -- `requirements.txt`

```
fastapi==0.115.0
uvicorn[standard]==0.30.0
asyncpg==0.29.0
httpx==0.27.0
pydantic[email]==2.9.0
pydantic-settings==2.5.0
python-multipart==0.0.12
python-jose[cryptography]==3.3.0
rembg==2.0.57
boto3==1.35.0
Pillow==10.4.0
openai==1.50.0
pgvector==0.3.5
firebase-admin==6.5.0
sentry-sdk[fastapi]==2.14.0
pytest==8.3.0
pytest-asyncio==0.24.0
```

### Step 1.2 -- `app/config.py`

```python
"""Central configuration from environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    environment: str = "development"
    debug: bool = False

    # Database
    database_url: str = "postgresql://drapeai:drapeai@localhost:5432/drapeai"

    # OpenAI
    openai_api_key: str = ""
    openai_model_vision: str = "gpt-4o"
    openai_model_ranker: str = "gpt-4o"
    openai_model_embedding: str = "text-embedding-3-small"
    openai_spend_cap_usd: float = 20.0

    # Cloudflare R2
    r2_account_id: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket_name: str = "drapeai-images"
    r2_public_url: str = ""

    # Firebase
    firebase_project_id: str = ""

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "INFO"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
```

### Step 1.3 -- `app/database/pool.py`

```python
"""Async connection pool for PostgreSQL."""

import asyncpg
import logging

from app.config import settings

logger = logging.getLogger(__name__)

_pool: asyncpg.Pool | None = None


async def get_pool() -> asyncpg.Pool:
    global _pool
    if _pool is None:
        raise RuntimeError("Database pool not initialized. Call init_pool() first.")
    return _pool


async def init_pool() -> None:
    global _pool
    logger.info("Initializing database connection pool")
    _pool = await asyncpg.create_pool(
        dsn=settings.database_url,
        min_size=2,
        max_size=10,
        command_timeout=30,
    )
    # Enable pgvector extension
    async with _pool.acquire() as conn:
        await conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
    logger.info("Database pool ready")


async def close_pool() -> None:
    global _pool
    if _pool:
        await _pool.close()
        _pool = None
        logger.info("Database pool closed")
```

### Step 1.4 -- `app/main.py`

```python
"""FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database.pool import init_pool, close_pool
from app.routes import health

# Logging
logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# Sentry (production only)
if settings.environment == "production":
    sentry_sdk.init(dsn=settings.sentry_dsn, traces_sample_rate=0.1)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_pool()
    logger.info("DrapeAI backend started")
    yield
    await close_pool()
    logger.info("DrapeAI backend stopped")


app = FastAPI(
    title="DrapeAI API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.environment == "development" else None,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.environment == "development" else ["https://drapeai.app"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routers
app.include_router(health.router)
```

### Step 1.5 -- `app/routes/health.py`

```python
"""Health check endpoint."""

from fastapi import APIRouter
from app.database.pool import get_pool

router = APIRouter(tags=["Health"])


@router.get("/health")
async def health_check():
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.fetchval("SELECT 1")
    return {"status": "ok", "service": "drapeai-api"}
```

### Step 1.6 -- `.env` (local development)

```
ENVIRONMENT=development
DATABASE_URL=postgresql://drapeai:drapeai@localhost:5432/drapeai
OPENAI_API_KEY=sk-your-key-here
FIREBASE_PROJECT_ID=your-project-id
LOG_LEVEL=DEBUG
```

### Step 1.7 -- Run + Verify

```bash
# Start PostgreSQL (if not running)
docker run -d --name drapeai-pg -p 5432:5432 \
  -e POSTGRES_USER=drapeai -e POSTGRES_PASSWORD=drapeai -e POSTGRES_DB=drapeai \
  pgvector/pgvector:pg16

# Install dependencies
cd api && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Run server
uvicorn app.main:app --reload --port 8000

# Test
curl http://localhost:8000/health
# Expected: {"status":"ok","service":"drapeai-api"}
```

---

## Phase 2 -- Authentication

### What you're building
Firebase JWT verification middleware that extracts `user_id` from the token and auto-provisions a user row in PostgreSQL.

### Files to create

```
app/
├── auth/
│   ├── __init__.py
│   ├── firebase.py       # JWT verification
│   └── dependencies.py   # FastAPI Depends(get_current_user)
├── models/
│   ├── __init__.py
│   └── user.py           # User pydantic models
└── database/
    └── queries/
        └── users.py       # User DB queries
```

### Step 2.1 -- `app/models/user.py`

```python
"""User models."""

from pydantic import BaseModel
from datetime import datetime


class User(BaseModel):
    id: str  # Firebase UID
    phone: str | None = None
    email: str | None = None
    display_name: str | None = None
    photo_url: str | None = None
    onboarding_done: bool = False
    created_at: datetime | None = None
```

### Step 2.2 -- `app/auth/firebase.py`

```python
"""Firebase JWT verification."""

import time
import logging

import httpx
from jose import jwt, JWTError

from app.config import settings

logger = logging.getLogger(__name__)

# Cache Firebase public keys
_cached_keys: dict = {}
_keys_fetched_at: float = 0
KEYS_TTL = 3600  # 1 hour

FIREBASE_CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"


async def _fetch_firebase_keys() -> dict:
    global _cached_keys, _keys_fetched_at
    now = time.time()
    if _cached_keys and (now - _keys_fetched_at) < KEYS_TTL:
        return _cached_keys
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(FIREBASE_CERTS_URL)
        resp.raise_for_status()
        _cached_keys = resp.json()
        _keys_fetched_at = now
    logger.info("Refreshed Firebase public keys")
    return _cached_keys


async def verify_firebase_token(token: str) -> dict:
    """Verify Firebase JWT and return decoded claims.

    Returns dict with: user_id, email, phone_number, name, picture, etc.
    """
    # Dev mode: accept test token
    if settings.environment == "development" and token == "test-token":
        return {
            "user_id": "test-user-001",
            "email": "test@drapeai.app",
            "name": "Test User",
        }

    keys = await _fetch_firebase_keys()

    # Get the key ID from the token header
    try:
        unverified_header = jwt.get_unverified_header(token)
    except JWTError:
        raise ValueError("Invalid token header")

    kid = unverified_header.get("kid")
    if kid not in keys:
        # Try refreshing keys once
        _cached_keys.clear()
        keys = await _fetch_firebase_keys()
        if kid not in keys:
            raise ValueError("Token key ID not found in Firebase keys")

    public_key = keys[kid]

    try:
        payload = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=settings.firebase_project_id,
            issuer=f"https://securetoken.google.com/{settings.firebase_project_id}",
        )
    except JWTError as e:
        raise ValueError(f"Token verification failed: {e}")

    return {
        "user_id": payload["sub"],
        "email": payload.get("email"),
        "phone_number": payload.get("phone_number"),
        "name": payload.get("name"),
        "picture": payload.get("picture"),
    }
```

### Step 2.3 -- `app/database/queries/users.py`

```python
"""User database queries."""

import asyncpg
from datetime import datetime

from app.models.user import User


async def upsert_user(conn: asyncpg.Connection, firebase_claims: dict) -> User:
    """Insert user if not exists, or update last_login. Return User."""
    row = await conn.fetchrow(
        """
        INSERT INTO users (id, email, phone, display_name, photo_url)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (id) DO UPDATE SET
            last_login_at = NOW(),
            email = COALESCE(EXCLUDED.email, users.email),
            phone = COALESCE(EXCLUDED.phone, users.phone)
        RETURNING *
        """,
        firebase_claims["user_id"],
        firebase_claims.get("email"),
        firebase_claims.get("phone_number"),
        firebase_claims.get("name"),
        firebase_claims.get("picture"),
    )
    return User(**dict(row))


async def get_user_by_id(conn: asyncpg.Connection, user_id: str) -> User | None:
    row = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)
    return User(**dict(row)) if row else None
```

### Step 2.4 -- `app/auth/dependencies.py`

```python
"""FastAPI authentication dependencies."""

from fastapi import Depends, HTTPException, Request

from app.auth.firebase import verify_firebase_token
from app.database.pool import get_pool
from app.database.queries.users import upsert_user
from app.models.user import User


async def get_current_user(request: Request) -> User:
    """Extract and verify Firebase JWT, auto-provision user, return User.

    Usage in any route:
        @router.get("/me")
        async def get_profile(user: User = Depends(get_current_user)):
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")

    token = auth_header.split(" ", 1)[1]

    try:
        claims = await verify_firebase_token(token)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))

    pool = await get_pool()
    async with pool.acquire() as conn:
        user = await upsert_user(conn, claims)

    return user
```

### Step 2.5 -- Register auth routes in `main.py`

```python
# In app/main.py, add:
from app.routes import auth

app.include_router(auth.router)
```

### Step 2.6 -- `app/routes/auth.py`

```python
"""Auth routes."""

from fastapi import APIRouter, Depends
from app.auth.dependencies import get_current_user
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/verify")
async def verify_token(user: User = Depends(get_current_user)):
    """Client calls this after Firebase login to confirm backend connectivity."""
    return {
        "user_id": user.id,
        "display_name": user.display_name,
        "onboarding_done": user.onboarding_done,
    }
```

### Step 2.7 -- Verify

```bash
# Dev mode test
curl -X POST http://localhost:8000/auth/verify \
  -H "Authorization: Bearer test-token"
# Expected: {"user_id": "test-user-001", "display_name": "Test User", "onboarding_done": false}

# No token test
curl -X POST http://localhost:8000/auth/verify
# Expected: 401 {"detail": "Missing or invalid Authorization header"}
```

---

## Phase 3 -- User Profile + Preferences

### What you're building
GET/PATCH `/me` for profile, PUT/GET `/me/preferences` for the onboarding quiz answers.

### Files to create

```
app/
├── models/
│   └── preferences.py
├── database/queries/
│   └── preferences.py
└── routes/
    └── user.py
```

### Step 3.1 -- `app/models/preferences.py`

```python
"""User preference models for onboarding quiz."""

from pydantic import BaseModel, field_validator
from typing import Literal


class PreferencesInput(BaseModel):
    gender: Literal["male", "female", "non_binary"]
    age_range: Literal["18-24", "25-34", "35-44", "45+"]
    style_goals: list[str]  # ["casual_upgrade", "work_ready", "ethnic_modern", "minimal"]
    color_preferences: list[str]  # ["earth", "pastels", "bold", "monochrome", "jewel"]
    location_city: str

    @field_validator("style_goals")
    @classmethod
    def validate_style_goals(cls, v):
        valid = {"casual_upgrade", "work_ready", "ethnic_modern", "minimal", "streetwear", "classic"}
        if not all(g in valid for g in v):
            raise ValueError(f"Invalid style goals. Valid: {valid}")
        if len(v) < 1 or len(v) > 3:
            raise ValueError("Select 1-3 style goals")
        return v

    @field_validator("color_preferences")
    @classmethod
    def validate_color_prefs(cls, v):
        valid = {"earth", "pastels", "bold", "monochrome", "jewel", "neutrals"}
        if not all(c in valid for c in v):
            raise ValueError(f"Invalid color preferences. Valid: {valid}")
        return v


class PreferencesResponse(BaseModel):
    gender: str
    age_range: str
    style_goals: list[str]
    color_preferences: list[str]
    location_city: str
```

### Step 3.2 -- `app/database/queries/preferences.py`

```python
"""Preferences database queries."""

import json
import asyncpg


async def upsert_preferences(conn: asyncpg.Connection, user_id: str, prefs: dict) -> dict:
    row = await conn.fetchrow(
        """
        INSERT INTO preferences (user_id, gender, age_range, style_goals, color_preferences, location_city)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (user_id) DO UPDATE SET
            gender = EXCLUDED.gender,
            age_range = EXCLUDED.age_range,
            style_goals = EXCLUDED.style_goals,
            color_preferences = EXCLUDED.color_preferences,
            location_city = EXCLUDED.location_city,
            updated_at = NOW()
        RETURNING *
        """,
        user_id,
        prefs["gender"],
        prefs["age_range"],
        json.dumps(prefs["style_goals"]),
        json.dumps(prefs["color_preferences"]),
        prefs["location_city"],
    )
    return dict(row)


async def get_preferences(conn: asyncpg.Connection, user_id: str) -> dict | None:
    row = await conn.fetchrow(
        "SELECT * FROM preferences WHERE user_id = $1", user_id
    )
    if row:
        result = dict(row)
        result["style_goals"] = json.loads(result["style_goals"])
        result["color_preferences"] = json.loads(result["color_preferences"])
        return result
    return None
```

### Step 3.3 -- `app/routes/user.py`

```python
"""User profile and preferences routes."""

from fastapi import APIRouter, Depends, HTTPException

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.preferences import upsert_preferences, get_preferences
from app.models.user import User
from app.models.preferences import PreferencesInput, PreferencesResponse

router = APIRouter(tags=["User"])


@router.get("/me")
async def get_profile(user: User = Depends(get_current_user)):
    return {
        "id": user.id,
        "display_name": user.display_name,
        "email": user.email,
        "phone": user.phone,
        "photo_url": user.photo_url,
        "onboarding_done": user.onboarding_done,
    }


@router.patch("/me")
async def update_profile(
    updates: dict,
    user: User = Depends(get_current_user),
):
    allowed = {"display_name", "photo_url"}
    filtered = {k: v for k, v in updates.items() if k in allowed}
    if not filtered:
        raise HTTPException(status_code=400, detail="No valid fields to update")

    pool = await get_pool()
    async with pool.acquire() as conn:
        set_clause = ", ".join(f"{k} = ${i+2}" for i, k in enumerate(filtered))
        values = [user.id] + list(filtered.values())
        await conn.execute(
            f"UPDATE users SET {set_clause} WHERE id = $1",
            *values,
        )
    return {"updated": True}


@router.put("/me/preferences")
async def save_preferences(
    prefs: PreferencesInput,
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await upsert_preferences(conn, user.id, prefs.model_dump())
        # Mark onboarding done
        await conn.execute(
            "UPDATE users SET onboarding_done = true WHERE id = $1", user.id
        )
    return PreferencesResponse(**result)


@router.get("/me/preferences")
async def get_user_preferences(user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        prefs = await get_preferences(conn, user.id)
    if not prefs:
        raise HTTPException(status_code=404, detail="Preferences not set. Complete onboarding first.")
    return PreferencesResponse(**prefs)
```

---

## Phase 4 -- Storage Layer

### What you're building
An abstraction over Cloudflare R2 (production) and local filesystem (development) for uploading and serving item images.

### Files to create

```
app/
└── services/
    ├── __init__.py
    └── storage.py
```

### Step 4.1 -- `app/services/storage.py`

```python
"""Storage abstraction: R2 in production, local filesystem in development."""

import os
import logging
from pathlib import Path

import boto3
from botocore.config import Config

from app.config import settings

logger = logging.getLogger(__name__)

LOCAL_UPLOAD_DIR = Path("uploads")


def _get_r2_client():
    return boto3.client(
        "s3",
        endpoint_url=f"https://{settings.r2_account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=settings.r2_access_key_id,
        aws_secret_access_key=settings.r2_secret_access_key,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )


async def upload_image(user_id: str, item_id: str, image_bytes: bytes, content_type: str) -> str:
    """Upload processed image. Returns the storage key (path).

    In dev: saves to local uploads/ folder.
    In prod: uploads to R2 bucket.
    """
    key = f"users/{user_id}/items/{item_id}.png"

    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(image_bytes)
        logger.debug(f"Saved locally: {path}")
        return key

    client = _get_r2_client()
    client.put_object(
        Bucket=settings.r2_bucket_name,
        Key=key,
        Body=image_bytes,
        ContentType=content_type,
    )
    logger.info(f"Uploaded to R2: {key}")
    return key


def get_image_url(key: str) -> str:
    """Convert storage key to public URL."""
    if settings.environment == "development":
        return f"http://localhost:{settings.port}/uploads/{key}"
    return f"{settings.r2_public_url}/{key}"


async def delete_image(key: str) -> None:
    """Delete image from storage."""
    if settings.environment == "development":
        path = LOCAL_UPLOAD_DIR / key
        if path.exists():
            path.unlink()
        return

    client = _get_r2_client()
    client.delete_object(Bucket=settings.r2_bucket_name, Key=key)
    logger.info(f"Deleted from R2: {key}")
```

### Step 4.2 -- Serve local uploads in dev mode

Add to `app/main.py`:

```python
from fastapi.staticfiles import StaticFiles

# After app is created:
if settings.environment == "development":
    from pathlib import Path
    Path("uploads").mkdir(exist_ok=True)
    app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
```

---

## Phase 5 -- Items CRUD

### What you're building
Upload item image (with validation), list/filter items, get single item, edit tags, soft-delete.

### Files to create

```
app/
├── models/
│   └── item.py
├── database/queries/
│   └── items.py
├── routes/
│   └── items.py
└── utils/
    └── image_validation.py
```

### Step 5.1 -- `app/utils/image_validation.py`

```python
"""Image upload validation."""

from fastapi import HTTPException

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB

# Magic byte signatures
MAGIC_BYTES = {
    b"\xff\xd8\xff": "image/jpeg",
    b"\x89PNG\r\n\x1a\n": "image/png",
    b"RIFF": "image/webp",
}


def validate_image(content_type: str, file_bytes: bytes) -> None:
    """Validate image type, size, and magic bytes. Raises HTTPException on failure."""
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid image type: {content_type}. Allowed: JPEG, PNG, WebP, HEIC",
        )

    if len(file_bytes) > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=400, detail="Image too large. Maximum size is 10 MB.")

    if len(file_bytes) < 100:
        raise HTTPException(status_code=400, detail="Image file is too small or corrupt.")

    # Magic bytes check (skip for HEIC -- complex container format)
    if content_type != "image/heic":
        matched = any(file_bytes.startswith(sig) for sig in MAGIC_BYTES)
        if not matched:
            raise HTTPException(status_code=400, detail="File content does not match declared type.")
```

### Step 5.2 -- `app/models/item.py`

```python
"""Item models."""

from pydantic import BaseModel
from datetime import datetime


class ItemTags(BaseModel):
    category: str  # top, bottom, footwear, accessory, outerwear, ethnic
    sub_category: str
    primary_color: str
    secondary_colors: list[str] = []
    pattern: str = "solid"
    fabric: str = "cotton"
    style_tags: list[str] = []
    formality: int = 3  # 1 (very casual) - 5 (formal)
    season_tags: list[str] = ["all_season"]
    ethnic_flag: bool = False
    confidence: float = 0.0


class ItemResponse(BaseModel):
    id: str
    image_url: str
    thumbnail_url: str | None = None
    category: str
    sub_category: str
    primary_color: str
    secondary_colors: list[str]
    pattern: str
    fabric: str
    style_tags: list[str]
    formality: int
    season_tags: list[str]
    ethnic_flag: bool
    wear_count: int = 0
    last_worn_at: datetime | None = None
    created_at: datetime


class ItemUpdate(BaseModel):
    category: str | None = None
    sub_category: str | None = None
    primary_color: str | None = None
    secondary_colors: list[str] | None = None
    pattern: str | None = None
    fabric: str | None = None
    style_tags: list[str] | None = None
    formality: int | None = None
    season_tags: list[str] | None = None
    ethnic_flag: bool | None = None
    notes: str | None = None
    purchase_price: int | None = None  # paise (INR x 100)
```

### Step 5.3 -- `app/database/queries/items.py`

```python
"""Item database queries."""

import json
import uuid
import asyncpg
from datetime import datetime


async def insert_item(conn: asyncpg.Connection, user_id: str, storage_key: str, tags: dict) -> dict:
    """Insert a new item after vision tagging. Returns the full item row."""
    item_id = str(uuid.uuid4())
    row = await conn.fetchrow(
        """
        INSERT INTO items (
            id, user_id, image_url, category, sub_category,
            primary_color, secondary_colors, pattern, fabric,
            style_tags, formality, season_tags, ethnic_flag, confidence
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
        RETURNING *
        """,
        item_id, user_id, storage_key,
        tags["category"], tags["sub_category"],
        tags["primary_color"], json.dumps(tags.get("secondary_colors", [])),
        tags.get("pattern", "solid"), tags.get("fabric", "cotton"),
        json.dumps(tags.get("style_tags", [])),
        tags.get("formality", 3),
        json.dumps(tags.get("season_tags", ["all_season"])),
        tags.get("ethnic_flag", False),
        tags.get("confidence", 0.0),
    )
    return dict(row)


async def get_items(
    conn: asyncpg.Connection,
    user_id: str,
    category: str | None = None,
    color: str | None = None,
    season: str | None = None,
    ethnic: bool | None = None,
    search: str | None = None,
    sort: str = "newest",
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[dict], int]:
    """List items with filters. Returns (items, total_count)."""
    conditions = ["user_id = $1", "is_active = true"]
    params: list = [user_id]
    idx = 2

    if category:
        conditions.append(f"category = ${idx}")
        params.append(category)
        idx += 1
    if color:
        conditions.append(f"primary_color = ${idx}")
        params.append(color)
        idx += 1
    if season:
        conditions.append(f"season_tags::text ILIKE ${idx}")
        params.append(f"%{season}%")
        idx += 1
    if ethnic is not None:
        conditions.append(f"ethnic_flag = ${idx}")
        params.append(ethnic)
        idx += 1
    if search:
        conditions.append(f"(sub_category ILIKE ${idx} OR primary_color ILIKE ${idx} OR fabric ILIKE ${idx})")
        params.append(f"%{search}%")
        idx += 1

    where = " AND ".join(conditions)

    sort_clause = {
        "newest": "created_at DESC",
        "oldest": "created_at ASC",
        "most_worn": "wear_count DESC",
        "least_worn": "wear_count ASC",
    }.get(sort, "created_at DESC")

    # Count
    count = await conn.fetchval(f"SELECT COUNT(*) FROM items WHERE {where}", *params)

    # Fetch
    params.extend([limit, offset])
    rows = await conn.fetch(
        f"SELECT * FROM items WHERE {where} ORDER BY {sort_clause} LIMIT ${idx} OFFSET ${idx+1}",
        *params,
    )
    return [dict(r) for r in rows], count


async def get_item(conn: asyncpg.Connection, item_id: str, user_id: str) -> dict | None:
    row = await conn.fetchrow(
        "SELECT * FROM items WHERE id = $1 AND user_id = $2 AND is_active = true",
        item_id, user_id,
    )
    return dict(row) if row else None


async def update_item(conn: asyncpg.Connection, item_id: str, user_id: str, updates: dict) -> dict | None:
    allowed = {
        "category", "sub_category", "primary_color", "secondary_colors",
        "pattern", "fabric", "style_tags", "formality", "season_tags",
        "ethnic_flag", "notes", "purchase_price",
    }
    filtered = {k: v for k, v in updates.items() if k in allowed and v is not None}
    if not filtered:
        return await get_item(conn, item_id, user_id)

    # JSON-encode list fields
    for key in ("secondary_colors", "style_tags", "season_tags"):
        if key in filtered:
            filtered[key] = json.dumps(filtered[key])

    set_parts = []
    params = [item_id, user_id]
    idx = 3
    for k, v in filtered.items():
        set_parts.append(f"{k} = ${idx}")
        params.append(v)
        idx += 1

    row = await conn.fetchrow(
        f"UPDATE items SET {', '.join(set_parts)} WHERE id = $1 AND user_id = $2 AND is_active = true RETURNING *",
        *params,
    )
    return dict(row) if row else None


async def soft_delete_item(conn: asyncpg.Connection, item_id: str, user_id: str) -> bool:
    result = await conn.execute(
        "UPDATE items SET is_active = false WHERE id = $1 AND user_id = $2",
        item_id, user_id,
    )
    return result == "UPDATE 1"


async def store_embedding(conn: asyncpg.Connection, item_id: str, embedding: list[float]) -> None:
    await conn.execute(
        "UPDATE items SET embedding = $1 WHERE id = $2",
        str(embedding), item_id,
    )
```

### Step 5.4 -- `app/routes/items.py`

```python
"""Item routes: upload, list, get, update, delete."""

import logging

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.items import (
    insert_item, get_items, get_item, update_item, soft_delete_item,
)
from app.models.user import User
from app.models.item import ItemUpdate
from app.services.storage import get_image_url
from app.utils.image_validation import validate_image

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/items", tags=["Items"])


@router.post("/upload", status_code=201)
async def upload_item(
    image: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    """Upload a clothing item. Backend processes:
    1. Validate image
    2. Remove background (rembg)
    3. Tag with GPT-4o Vision
    4. Generate embedding
    5. Store in DB + R2
    """
    file_bytes = await image.read()
    validate_image(image.content_type, file_bytes)

    # Import here to avoid circular imports at module level
    from app.services.upload_pipeline import process_upload

    result = await process_upload(user.id, file_bytes, image.content_type)
    return result


@router.get("")
async def list_items(
    category: str | None = Query(None),
    color: str | None = Query(None),
    season: str | None = Query(None),
    ethnic: bool | None = Query(None),
    search: str | None = Query(None),
    sort: str = Query("newest"),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        items, total = await get_items(
            conn, user.id, category, color, season, ethnic, search, sort, limit, offset
        )

    for item in items:
        item["image_url"] = get_image_url(item["image_url"])

    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/{item_id}")
async def get_single_item(item_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        item = await get_item(conn, item_id, user.id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    item["image_url"] = get_image_url(item["image_url"])
    return item


@router.patch("/{item_id}")
async def update_single_item(
    item_id: str,
    updates: ItemUpdate,
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        item = await update_item(conn, item_id, user.id, updates.model_dump(exclude_none=True))
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    # If category or color changed, re-generate embedding in background
    if updates.category or updates.primary_color:
        from app.services.upload_pipeline import regenerate_embedding
        import asyncio
        asyncio.create_task(regenerate_embedding(item_id))

    item["image_url"] = get_image_url(item["image_url"])
    return item


@router.delete("/{item_id}")
async def delete_single_item(item_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        deleted = await soft_delete_item(conn, item_id, user.id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"deleted": True}
```

---

## Phase 6 -- AI Upload Pipeline

### What you're building
The complete upload processing pipeline: background removal (rembg), AI tagging (GPT-4o Vision), and embedding generation.

### Files to create

```
app/
└── services/
    ├── upload_pipeline.py   # Orchestrator
    ├── bg_remover.py        # rembg wrapper
    ├── vision_tagger.py     # GPT-4o Vision call
    └── embedder.py          # text-embedding-3-small
```

### Step 6.1 -- `app/services/bg_remover.py`

```python
"""Background removal using rembg. CPU-bound, runs in thread pool."""

import asyncio
import logging
from io import BytesIO

from PIL import Image
import rembg

logger = logging.getLogger(__name__)


def _remove_bg_sync(image_bytes: bytes) -> bytes:
    """Synchronous background removal. Runs in executor."""
    result = rembg.remove(image_bytes)

    # Ensure PNG output and reasonable size
    img = Image.open(BytesIO(result))
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    # Resize if larger than 1024px on longest side
    max_side = 1024
    if max(img.size) > max_side:
        ratio = max_side / max(img.size)
        new_size = (int(img.width * ratio), int(img.height * ratio))
        img = img.resize(new_size, Image.LANCZOS)

    output = BytesIO()
    img.save(output, format="PNG", optimize=True)
    return output.getvalue()


async def remove_background(image_bytes: bytes) -> bytes:
    """Remove background from clothing image. Returns PNG bytes.

    Takes 2-4 seconds on CPU. Runs in thread pool to avoid blocking.
    """
    loop = asyncio.get_running_loop()
    result = await loop.run_in_executor(None, _remove_bg_sync, image_bytes)
    logger.info(f"Background removed: {len(image_bytes)} -> {len(result)} bytes")
    return result
```

### Step 6.2 -- `app/services/vision_tagger.py`

```python
"""GPT-4o Vision tagging for clothing items."""

import asyncio
import base64
import json
import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

VISION_PROMPT = """You are a fashion item tagger for an Indian wardrobe app.

Analyze this clothing/accessory image and return a JSON object with these exact fields:

{
  "category": "top|bottom|footwear|accessory|outerwear|ethnic",
  "sub_category": "<specific type, e.g. kurta, polo, chinos, sneakers, dupatta>",
  "primary_color": "<dominant color, lowercase, e.g. navy, maroon, beige>",
  "secondary_colors": ["<other visible colors>"],
  "pattern": "solid|striped|checked|printed|floral|geometric|embroidered|abstract",
  "fabric": "<best guess: cotton, silk, polyester, denim, linen, wool, chiffon, georgette, etc>",
  "style_tags": ["<relevant style tags: casual, formal, ethnic, festive, sporty, streetwear, classic, bohemian, minimal>"],
  "formality": <1-5 integer: 1=very casual, 2=casual, 3=smart casual, 4=semi-formal, 5=formal>,
  "season_tags": ["<summer, winter, monsoon, all_season>"],
  "ethnic_flag": <true if this is Indian ethnic wear (kurta, saree, lehenga, sherwani, etc), false otherwise>,
  "confidence": <0.0-1.0 your confidence in the overall tagging>
}

Rules:
- For Indian ethnic wear: use specific sub_categories (kurta, churidar, saree, lehenga, sherwani, nehru_jacket, dupatta, mojari, kolhapuri, juttis)
- If the item is clearly a full outfit (like saree with blouse), tag the primary garment
- If unsure between two categories, pick the more specific one
- Color names should be simple (navy, not "dark navy blue")
- Return ONLY the JSON object, no markdown, no explanation
"""


async def tag_item(image_bytes: bytes) -> dict:
    """Send image to GPT-4o Vision for tagging. Returns parsed tag dict.

    Cost: ~$0.03 per image (low detail mode).
    """
    from app.utils.cost_tracker import check_budget, track_spend

    await check_budget()

    b64_image = base64.b64encode(image_bytes).decode("utf-8")

    payload = {
        "model": settings.openai_model_vision,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": VISION_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/png;base64,{b64_image}",
                            "detail": "low",
                        },
                    },
                ],
            }
        ],
        "max_tokens": 500,
        "temperature": 0.1,
    }

    headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }

    # Retry with backoff
    delays = [10, 20, 40]
    last_error = None

    for attempt in range(3):
        try:
            async with httpx.AsyncClient(timeout=60) as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers=headers,
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()

            content = data["choices"][0]["message"]["content"].strip()

            # Clean markdown code block if present
            if content.startswith("```"):
                content = content.split("\n", 1)[1].rsplit("```", 1)[0].strip()

            tags = json.loads(content)

            # Track cost
            usage = data.get("usage", {})
            cost = (usage.get("prompt_tokens", 0) * 0.0025 + usage.get("completion_tokens", 0) * 0.01) / 1000
            await track_spend(model="gpt-4o-vision", tokens_in=usage.get("prompt_tokens", 0),
                             tokens_out=usage.get("completion_tokens", 0), cost_usd=cost)

            logger.info(f"Vision tagging: {tags.get('category')}/{tags.get('sub_category')} "
                       f"(confidence: {tags.get('confidence', 0)})")
            return tags

        except Exception as e:
            last_error = e
            logger.warning(f"Vision tagging attempt {attempt + 1} failed: {e}")
            if attempt < 2:
                await asyncio.sleep(delays[attempt])

    raise RuntimeError(f"Vision tagging failed after 3 attempts: {last_error}")
```

### Step 6.3 -- `app/services/embedder.py`

```python
"""Generate text embeddings for wardrobe items using OpenAI text-embedding-3-small."""

import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


def _build_embedding_text(tags: dict) -> str:
    """Build a descriptive text string from item tags for embedding.

    Example: "ethnic kurta maroon embroidered silk festive formal winter"
    """
    parts = [
        tags.get("category", ""),
        tags.get("sub_category", ""),
        tags.get("primary_color", ""),
        tags.get("pattern", ""),
        tags.get("fabric", ""),
    ]
    parts.extend(tags.get("style_tags", []))
    parts.extend(tags.get("season_tags", []))
    if tags.get("ethnic_flag"):
        parts.append("indian ethnic")
    parts.extend(tags.get("secondary_colors", []))
    return " ".join(p for p in parts if p)


async def generate_embedding(tags: dict) -> list[float]:
    """Generate 1536-dimensional embedding from item tags.

    Cost: ~$0.0001 per item (negligible).
    """
    text = _build_embedding_text(tags)
    logger.debug(f"Embedding text: {text}")

    headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": settings.openai_model_embedding,
        "input": text,
    }

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            "https://api.openai.com/v1/embeddings",
            headers=headers,
            json=payload,
        )
        response.raise_for_status()
        data = response.json()

    embedding = data["data"][0]["embedding"]
    logger.info(f"Generated embedding: {len(embedding)} dimensions")
    return embedding
```

### Step 6.4 -- `app/services/upload_pipeline.py`

```python
"""Orchestrates the full item upload pipeline."""

import logging

from app.database.pool import get_pool
from app.database.queries.items import insert_item, store_embedding
from app.services.bg_remover import remove_background
from app.services.vision_tagger import tag_item
from app.services.embedder import generate_embedding
from app.services.storage import upload_image, get_image_url

logger = logging.getLogger(__name__)


async def process_upload(user_id: str, file_bytes: bytes, content_type: str) -> dict:
    """Full upload pipeline:
    1. Remove background (rembg, 2-4s)
    2. Upload processed image to storage
    3. Tag with GPT-4o Vision (~3s)
    4. Generate embedding (~0.5s)
    5. Insert item row in DB
    6. Store embedding
    """
    # 1. Background removal
    processed_bytes = await remove_background(file_bytes)

    # 2. Upload to storage (need temp ID, will update with real ID)
    import uuid
    item_id = str(uuid.uuid4())
    storage_key = await upload_image(user_id, item_id, processed_bytes, "image/png")

    # 3. Vision tagging
    tags = await tag_item(processed_bytes)

    # 4. Insert item in DB
    pool = await get_pool()
    async with pool.acquire() as conn:
        item = await insert_item(conn, user_id, storage_key, tags)

    # 5. Generate and store embedding (non-blocking for response, but we await it)
    try:
        embedding = await generate_embedding(tags)
        async with pool.acquire() as conn:
            await store_embedding(conn, item["id"], embedding)
    except Exception as e:
        logger.error(f"Embedding generation failed for item {item['id']}: {e}")
        # Item is still usable without embedding

    # 6. Return response
    item["image_url"] = get_image_url(item["image_url"])
    return {
        "id": item["id"],
        "image_url": item["image_url"],
        "tags": tags,
        "confidence": tags.get("confidence", 0.0),
    }


async def regenerate_embedding(item_id: str) -> None:
    """Re-generate embedding when user edits tags. Called as background task."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM items WHERE id = $1", item_id)
    if not row:
        return

    tags = {
        "category": row["category"],
        "sub_category": row["sub_category"],
        "primary_color": row["primary_color"],
        "pattern": row["pattern"],
        "fabric": row["fabric"],
        "style_tags": row["style_tags"],
        "season_tags": row["season_tags"],
        "ethnic_flag": row["ethnic_flag"],
    }

    try:
        embedding = await generate_embedding(tags)
        async with pool.acquire() as conn:
            await store_embedding(conn, item_id, embedding)
        logger.info(f"Re-generated embedding for item {item_id}")
    except Exception as e:
        logger.error(f"Embedding regeneration failed for {item_id}: {e}")
```

### Step 6.5 -- `app/utils/cost_tracker.py`

```python
"""OpenAI spend tracking and budget enforcement."""

import logging
from datetime import datetime

from app.config import settings
from app.database.pool import get_pool

logger = logging.getLogger(__name__)


async def track_spend(model: str, tokens_in: int, tokens_out: int, cost_usd: float) -> None:
    """Record an API call cost."""
    pool = await get_pool()
    month = datetime.utcnow().strftime("%Y-%m")
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO analytics_daily (date, metric, value)
            VALUES (CURRENT_DATE, $1, $2)
            ON CONFLICT (date, metric)
            DO UPDATE SET value = analytics_daily.value + EXCLUDED.value
            """,
            f"openai_cost_{month}", cost_usd,
        )


async def check_budget() -> None:
    """Raise error if monthly OpenAI spend exceeds cap."""
    pool = await get_pool()
    month = datetime.utcnow().strftime("%Y-%m")
    async with pool.acquire() as conn:
        total = await conn.fetchval(
            "SELECT COALESCE(SUM(value), 0) FROM analytics_daily WHERE metric = $1",
            f"openai_cost_{month}",
        )
    if total and total >= settings.openai_spend_cap_usd:
        logger.error(f"OpenAI budget exceeded: ${total:.2f} >= ${settings.openai_spend_cap_usd}")
        from fastapi import HTTPException
        raise HTTPException(status_code=503, detail="AI service temporarily unavailable. Please try later.")
```

---

## Phase 7 -- Rule Engine

### What you're building
Deterministic Python outfit candidate generator. Takes user's wardrobe + occasion + weather, outputs ~20 scored outfit combos.

### Files to create

```
app/
└── services/
    └── rule_engine.py
```

### Step 7.1 -- `app/services/rule_engine.py`

```python
"""Deterministic outfit generation engine.

Pipeline: filter wardrobe -> build combos -> score each -> return top 20 candidates.
No LLM calls. Pure Python logic. Fast (<100ms for 50 items).
"""

import random
import logging
from itertools import product as cartesian_product

logger = logging.getLogger(__name__)

# --- Constants ---

OCCASION_FORMALITY = {
    "casual": (1, 3),
    "work": (3, 5),
    "party": (3, 5),
    "gym": (1, 2),
    "date": (3, 4),
    "festive": (4, 5),
    "travel": (1, 3),
}

WEATHER_SEASON_MAP = {
    "hot": ["summer", "all_season"],        # > 30C
    "warm": ["summer", "all_season"],       # 20-30C
    "cool": ["winter", "all_season"],       # 10-20C
    "cold": ["winter"],                     # < 10C
    "rain": ["monsoon", "all_season"],
}

GOOD_COLOR_PAIRS = {
    ("navy", "white"), ("navy", "beige"), ("navy", "cream"),
    ("black", "white"), ("black", "grey"), ("black", "red"),
    ("maroon", "cream"), ("maroon", "gold"), ("maroon", "beige"),
    ("olive", "cream"), ("olive", "brown"), ("olive", "white"),
    ("grey", "white"), ("grey", "black"), ("grey", "navy"),
    ("brown", "cream"), ("brown", "beige"), ("brown", "white"),
    ("white", "navy"), ("white", "black"), ("white", "blue"),
    ("beige", "brown"), ("beige", "navy"), ("beige", "olive"),
    ("blue", "white"), ("blue", "grey"), ("blue", "beige"),
    ("cream", "maroon"), ("cream", "navy"), ("cream", "brown"),
}

CLASHING_PAIRS = {
    ("red", "orange"), ("red", "pink"), ("red", "green"),
    ("brown", "black"), ("navy", "black"),
    ("orange", "pink"), ("purple", "orange"),
}

# Good ethnic fusion combos
ETHNIC_GOOD_COMBOS = [
    ("nehru_jacket", "shirt"), ("nehru_jacket", "t_shirt"),
    ("kurta", "jeans"), ("kurta", "chinos"),
    ("dupatta", "kurta"),
]

ETHNIC_BAD_COMBOS = [
    ("kurta", "shorts"), ("sherwani", "jeans"),
    ("saree", "sneakers"), ("lehenga", "sneakers"),
]


def _temp_to_weather(temp: int) -> str:
    if temp > 30:
        return "hot"
    elif temp > 20:
        return "warm"
    elif temp > 10:
        return "cool"
    return "cold"


def filter_wardrobe(items: list[dict], occasion: str, weather: dict | None) -> dict[str, list[dict]]:
    """Filter items by occasion formality, season, and weather. Group by category."""
    min_f, max_f = OCCASION_FORMALITY.get(occasion, (1, 5))

    # Determine allowed seasons from weather
    allowed_seasons = {"all_season"}
    if weather:
        temp = weather.get("temp", 25)
        condition = weather.get("condition", "clear")
        w_key = _temp_to_weather(temp)
        allowed_seasons.update(WEATHER_SEASON_MAP.get(w_key, ["all_season"]))
        if "rain" in condition.lower():
            allowed_seasons.update(WEATHER_SEASON_MAP["rain"])

    groups: dict[str, list[dict]] = {}
    for item in items:
        # Formality filter
        if not (min_f <= item.get("formality", 3) <= max_f):
            continue
        # Season filter
        item_seasons = set(item.get("season_tags", ["all_season"]))
        if not item_seasons.intersection(allowed_seasons):
            continue

        cat = item["category"]
        groups.setdefault(cat, []).append(item)

    return groups


def build_candidates(groups: dict[str, list[dict]], occasion: str) -> list[list[dict]]:
    """Generate outfit combos from filtered groups.

    Standard combo: top + bottom + footwear (+ optional accessory/outerwear)
    Ethnic combo: ethnic standalone or ethnic + complementary piece
    """
    candidates = []

    tops = groups.get("top", [])
    bottoms = groups.get("bottom", [])
    footwear = groups.get("footwear", [])
    outerwear = groups.get("outerwear", [])
    accessories = groups.get("accessory", [])
    ethnic = groups.get("ethnic", [])

    # Standard combos: top + bottom + footwear
    if tops and bottoms:
        for t, b in cartesian_product(tops, bottoms):
            combo = [t, b]
            if footwear:
                combo.append(random.choice(footwear))
            candidates.append(combo)

    # Ethnic standalone (saree, lehenga, sherwani)
    standalone_types = {"saree", "lehenga", "sherwani", "anarkali"}
    for e in ethnic:
        if e.get("sub_category") in standalone_types:
            combo = [e]
            if footwear:
                combo.append(random.choice(footwear))
            candidates.append(combo)

    # Ethnic fusion: ethnic top + western bottom
    ethnic_tops = [e for e in ethnic if e.get("sub_category") in {"kurta", "nehru_jacket"}]
    for et in ethnic_tops:
        for b in bottoms:
            combo = [et, b]
            if footwear:
                combo.append(random.choice(footwear))
            candidates.append(combo)

    # Augment with outerwear for cool/cold weather
    if outerwear:
        augmented = []
        for combo in candidates[:10]:  # Only augment top 10
            aug = combo + [random.choice(outerwear)]
            augmented.append(aug)
        candidates.extend(augmented)

    # Augment with accessories
    if accessories and occasion in ("party", "date", "festive", "work"):
        for combo in candidates[:5]:
            combo.append(random.choice(accessories))

    return candidates


def score_combo(combo: list[dict]) -> float:
    """Score an outfit combo 0-100. Higher is better.

    Scoring:
    - Color harmony: 40 points
    - Formality consistency: 30 points
    - Ethnic fusion quality: 20 points
    - Pattern clash avoidance: 10 points
    """
    score = 0.0

    colors = [item.get("primary_color", "unknown") for item in combo]
    formalities = [item.get("formality", 3) for item in combo]
    sub_cats = [item.get("sub_category", "") for item in combo]
    patterns = [item.get("pattern", "solid") for item in combo]
    ethnic_flags = [item.get("ethnic_flag", False) for item in combo]

    # --- Color harmony (40 pts) ---
    color_score = 20.0  # base
    for i in range(len(colors)):
        for j in range(i + 1, len(colors)):
            pair = (colors[i], colors[j])
            pair_rev = (colors[j], colors[i])
            if pair in GOOD_COLOR_PAIRS or pair_rev in GOOD_COLOR_PAIRS:
                color_score += 10
            elif pair in CLASHING_PAIRS or pair_rev in CLASHING_PAIRS:
                color_score -= 15
            elif colors[i] == colors[j] and colors[i] not in ("black", "white", "grey"):
                color_score -= 5  # Same-color different items (boring)
    score += min(max(color_score, 0), 40)

    # --- Formality consistency (30 pts) ---
    if formalities:
        f_range = max(formalities) - min(formalities)
        if f_range <= 1:
            score += 30
        elif f_range == 2:
            score += 20
        else:
            score += 5

    # --- Ethnic fusion (20 pts) ---
    has_ethnic = any(ethnic_flags)
    has_western = any(not f for f in ethnic_flags)
    if has_ethnic and has_western:
        # Fusion outfit -- check if it's a good combo
        sub_pairs = [(sub_cats[i], sub_cats[j]) for i in range(len(sub_cats)) for j in range(i+1, len(sub_cats))]
        good_fusion = any(p in ETHNIC_GOOD_COMBOS or (p[1], p[0]) in ETHNIC_GOOD_COMBOS for p in sub_pairs)
        bad_fusion = any(p in ETHNIC_BAD_COMBOS or (p[1], p[0]) in ETHNIC_BAD_COMBOS for p in sub_pairs)
        if good_fusion:
            score += 20
        elif bad_fusion:
            score += 0
        else:
            score += 10
    elif has_ethnic and not has_western:
        score += 18  # Full ethnic -- usually good
    else:
        score += 15  # Full western -- neutral

    # --- Pattern clash (10 pts) ---
    non_solid = [p for p in patterns if p != "solid"]
    if len(non_solid) == 0:
        score += 8  # All solid -- safe
    elif len(non_solid) == 1:
        score += 10  # One pattern piece -- great
    elif len(non_solid) == 2 and len(set(non_solid)) == 2:
        score += 3  # Two different patterns -- risky
    else:
        score += 0  # Multiple patterns -- bad

    return round(score, 1)


def generate_candidates(
    items: list[dict],
    occasion: str,
    weather: dict | None = None,
    max_candidates: int = 20,
) -> list[dict]:
    """Main entry point. Returns up to max_candidates scored combos, sorted by score.

    Each returned dict: {"items": [...], "score": float}
    """
    groups = filter_wardrobe(items, occasion, weather)

    if not groups:
        logger.warning(f"No items match filters for occasion={occasion}")
        return []

    combos = build_candidates(groups, occasion)

    if not combos:
        logger.warning("No valid combos generated")
        return []

    scored = []
    for combo in combos:
        s = score_combo(combo)
        scored.append({"items": combo, "score": s})

    # Sort by score descending, take top N
    scored.sort(key=lambda x: x["score"], reverse=True)
    result = scored[:max_candidates]

    logger.info(f"Rule engine: {len(combos)} combos -> top {len(result)} "
                f"(scores: {result[0]['score']}-{result[-1]['score']})")
    return result
```

---

## Phase 8 -- LLM Ranker

### What you're building
Takes the top ~20 rule engine candidates, sends them to GPT-4o, gets back the top 3 with styling reasons.

### Files to create

```
app/
└── services/
    └── llm_ranker.py
```

### Step 8.1 -- `app/services/llm_ranker.py`

```python
"""LLM-based outfit ranking using GPT-4o."""

import asyncio
import json
import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

RANKER_PROMPT_TEMPLATE = """You are a personal stylist for an Indian user.

User profile:
- Gender: {gender}
- Style goals: {style_goals}
- Color preferences: {color_preferences}

Occasion: {occasion}
Weather: {weather_desc}

Here are {n} outfit candidates (scored by a rule engine). Pick the best 3 and explain why.

Candidates:
{candidates_text}

Return a JSON array of exactly 3 objects:
[
  {{
    "index": <0-based index of the candidate>,
    "reason": "<1-2 sentence styling explanation, no emojis>"
  }}
]

Rules:
- Pick outfits that look cohesive and appropriate for the occasion
- Prefer variety (don't pick 3 similar outfits)
- Consider Indian fashion context (ethnic fusion is good when done right)
- Keep reasons concise, practical, and emoji-free
- Return ONLY the JSON array, no markdown
"""


def _format_candidates(candidates: list[dict]) -> str:
    lines = []
    for i, c in enumerate(candidates):
        items_desc = ", ".join(
            f"{it.get('sub_category', it.get('category', '?'))} ({it.get('primary_color', '?')})"
            for it in c["items"]
        )
        lines.append(f"[{i}] Score: {c['score']} | {items_desc}")
    return "\n".join(lines)


async def rank_outfits(
    candidates: list[dict],
    preferences: dict,
    occasion: str,
    weather: dict | None = None,
) -> list[dict]:
    """Send candidates to GPT-4o for ranking. Returns top 3 with reasons.

    Cost: ~$0.01 per generation.
    """
    from app.utils.cost_tracker import check_budget, track_spend

    await check_budget()

    weather_desc = "Unknown"
    if weather:
        weather_desc = f"{weather.get('temp', '?')}C, {weather.get('condition', 'clear')}"

    prompt = RANKER_PROMPT_TEMPLATE.format(
        gender=preferences.get("gender", "unknown"),
        style_goals=", ".join(preferences.get("style_goals", [])),
        color_preferences=", ".join(preferences.get("color_preferences", [])),
        occasion=occasion,
        weather_desc=weather_desc,
        n=len(candidates),
        candidates_text=_format_candidates(candidates),
    )

    headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": settings.openai_model_ranker,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 500,
        "temperature": 0.3,
    }

    delays = [10, 20, 40]
    last_error = None

    for attempt in range(3):
        try:
            async with httpx.AsyncClient(timeout=60) as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers=headers,
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()

            content = data["choices"][0]["message"]["content"].strip()
            if content.startswith("```"):
                content = content.split("\n", 1)[1].rsplit("```", 1)[0].strip()

            picks = json.loads(content)

            # Track cost
            usage = data.get("usage", {})
            cost = (usage.get("prompt_tokens", 0) * 0.0025 + usage.get("completion_tokens", 0) * 0.01) / 1000
            await track_spend(model="gpt-4o-ranker", tokens_in=usage.get("prompt_tokens", 0),
                             tokens_out=usage.get("completion_tokens", 0), cost_usd=cost)

            # Build result
            result = []
            for pick in picks[:3]:
                idx = pick["index"]
                if 0 <= idx < len(candidates):
                    candidate = candidates[idx]
                    result.append({
                        "items": candidate["items"],
                        "reason": pick["reason"],
                        "rule_score": candidate["score"],
                    })

            if not result:
                raise ValueError("LLM returned no valid picks")

            logger.info(f"LLM ranker: selected indices {[p['index'] for p in picks[:3]]}")
            return result

        except Exception as e:
            last_error = e
            logger.warning(f"LLM ranker attempt {attempt + 1} failed: {e}")
            if attempt < 2:
                await asyncio.sleep(delays[attempt])

    # Fallback: return top 3 from rule engine
    logger.error(f"LLM ranker failed after 3 attempts: {last_error}. Using rule engine fallback.")
    return [
        {"items": c["items"], "reason": None, "rule_score": c["score"]}
        for c in candidates[:3]
    ]
```

---

## Phase 9 -- Outfit Endpoints

### What you're building
The outfit generation flow: `/outfits/generate`, `/outfits/shuffle`, `/outfits/{id}/feedback`, caching.

### Files to create

```
app/
├── services/
│   ├── outfit_service.py   # Orchestrates rule engine + LLM
│   └── weather.py          # Weather fetching
├── database/queries/
│   ├── outfits.py
│   └── outfit_cache.py
└── routes/
    └── outfits.py
```

### Step 9.1 -- `app/services/weather.py`

```python
"""Weather data fetching with caching."""

import logging
from datetime import datetime, timedelta

import httpx

from app.database.pool import get_pool

logger = logging.getLogger(__name__)

# Using Open-Meteo (free, no API key needed)
WEATHER_API = "https://api.open-meteo.com/v1/forecast"

# Rough city -> coordinates for major Indian cities
CITY_COORDS = {
    "mumbai": (19.07, 72.87),
    "delhi": (28.61, 77.23),
    "bangalore": (12.97, 77.59),
    "hyderabad": (17.38, 78.49),
    "chennai": (13.08, 80.27),
    "kolkata": (22.57, 88.36),
    "pune": (18.52, 73.85),
    "ahmedabad": (23.02, 72.57),
    "jaipur": (26.92, 75.78),
}


async def get_weather(city: str) -> dict:
    """Get current weather for a city. Uses 1-hour cache in DB."""
    city_lower = city.lower().strip()

    # Check cache
    pool = await get_pool()
    async with pool.acquire() as conn:
        cached = await conn.fetchrow(
            "SELECT temp, condition, fetched_at FROM weather_cache WHERE city = $1 AND fetched_at > $2",
            city_lower, datetime.utcnow() - timedelta(hours=1),
        )
        if cached:
            return {"temp": cached["temp"], "condition": cached["condition"]}

    # Fetch from API
    coords = CITY_COORDS.get(city_lower)
    if not coords:
        # Default to Delhi if unknown city
        coords = CITY_COORDS["delhi"]
        logger.warning(f"Unknown city '{city}', defaulting to Delhi coordinates")

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(WEATHER_API, params={
                "latitude": coords[0],
                "longitude": coords[1],
                "current_weather": True,
            })
            resp.raise_for_status()
            data = resp.json()

        current = data["current_weather"]
        temp = round(current["temperature"])
        code = current.get("weathercode", 0)

        # WMO weather codes to simple conditions
        if code in (0, 1):
            condition = "clear"
        elif code in (2, 3):
            condition = "cloudy"
        elif code in (51, 53, 55, 61, 63, 65, 80, 81, 82):
            condition = "rain"
        elif code in (71, 73, 75, 77):
            condition = "snow"
        else:
            condition = "cloudy"

        # Cache it
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO weather_cache (city, temp, condition, fetched_at)
                VALUES ($1, $2, $3, NOW())
                ON CONFLICT (city) DO UPDATE SET temp = $2, condition = $3, fetched_at = NOW()
                """,
                city_lower, temp, condition,
            )

        return {"temp": temp, "condition": condition}

    except Exception as e:
        logger.error(f"Weather fetch failed for {city}: {e}")
        return {"temp": 25, "condition": "clear"}  # Safe default
```

### Step 9.2 -- `app/database/queries/outfits.py`

```python
"""Outfit database queries."""

import json
import uuid
import asyncpg


async def save_outfit(conn: asyncpg.Connection, user_id: str, outfit_data: dict) -> dict:
    """Save a generated outfit to the database."""
    outfit_id = str(uuid.uuid4())
    item_ids = [item["id"] for item in outfit_data["items"]]

    row = await conn.fetchrow(
        """
        INSERT INTO outfits (id, user_id, item_ids, reason, rule_score, occasion, weather_snapshot)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING *
        """,
        outfit_id, user_id,
        json.dumps(item_ids),
        outfit_data.get("reason"),
        outfit_data.get("rule_score", 0),
        outfit_data.get("occasion", "casual"),
        json.dumps(outfit_data.get("weather")),
    )
    return dict(row)


async def record_feedback(conn: asyncpg.Connection, user_id: str, outfit_id: str, action: str) -> None:
    """Record outfit feedback and apply side effects."""
    # Insert feedback
    await conn.execute(
        """
        INSERT INTO outfit_feedback (id, outfit_id, user_id, action)
        VALUES ($1, $2, $3, $4)
        """,
        str(uuid.uuid4()), outfit_id, user_id, action,
    )

    if action in ("like", "save"):
        await conn.execute(
            "UPDATE outfits SET is_saved = true WHERE id = $1 AND user_id = $2",
            outfit_id, user_id,
        )
    elif action == "wear":
        # Get item_ids for this outfit
        row = await conn.fetchrow(
            "SELECT item_ids FROM outfits WHERE id = $1 AND user_id = $2",
            outfit_id, user_id,
        )
        if row:
            item_ids = json.loads(row["item_ids"])
            for iid in item_ids:
                await conn.execute(
                    "UPDATE items SET wear_count = wear_count + 1, last_worn_at = NOW() WHERE id = $1",
                    iid,
                )


async def get_today_outfits(conn: asyncpg.Connection, user_id: str) -> list[dict]:
    """Get outfits generated today for this user."""
    rows = await conn.fetch(
        "SELECT * FROM outfits WHERE user_id = $1 AND DATE(created_at) = CURRENT_DATE ORDER BY created_at DESC",
        user_id,
    )
    return [dict(r) for r in rows]
```

### Step 9.3 -- `app/database/queries/outfit_cache.py`

```python
"""Outfit cache queries. Key: (user_id, date, occasion). TTL: 24 hours."""

import json
import asyncpg
from datetime import date


async def get_cached_outfits(conn: asyncpg.Connection, user_id: str, occasion: str) -> list[dict] | None:
    row = await conn.fetchrow(
        """
        SELECT result FROM outfit_cache
        WHERE user_id = $1 AND occasion = $2 AND cache_date = CURRENT_DATE
          AND created_at > NOW() - INTERVAL '24 hours'
        """,
        user_id, occasion,
    )
    if row:
        return json.loads(row["result"])
    return None


async def set_cached_outfits(conn: asyncpg.Connection, user_id: str, occasion: str, outfits: list[dict]) -> None:
    await conn.execute(
        """
        INSERT INTO outfit_cache (user_id, occasion, cache_date, result, created_at)
        VALUES ($1, $2, CURRENT_DATE, $3, NOW())
        ON CONFLICT (user_id, occasion, cache_date)
        DO UPDATE SET result = $3, created_at = NOW()
        """,
        user_id, occasion, json.dumps(outfits, default=str),
    )


async def invalidate_user_cache(conn: asyncpg.Connection, user_id: str) -> None:
    """Call when user adds/removes/edits items."""
    await conn.execute("DELETE FROM outfit_cache WHERE user_id = $1", user_id)
```

### Step 9.4 -- `app/services/outfit_service.py`

```python
"""Outfit generation orchestrator: cache -> weather -> rule engine -> LLM ranker."""

import logging

from app.database.pool import get_pool
from app.database.queries.items import get_items
from app.database.queries.preferences import get_preferences
from app.database.queries.outfits import save_outfit
from app.database.queries.outfit_cache import get_cached_outfits, set_cached_outfits
from app.services.rule_engine import generate_candidates
from app.services.llm_ranker import rank_outfits
from app.services.weather import get_weather
from app.services.storage import get_image_url

logger = logging.getLogger(__name__)


async def generate_outfits(user_id: str, occasion: str, weather_override: dict | None = None) -> dict:
    """Full outfit generation pipeline.

    1. Check cache
    2. Fetch weather (if no override)
    3. Run rule engine (deterministic, <100ms)
    4. Run LLM ranker (~3s)
    5. Save outfits to DB
    6. Cache result
    """
    pool = await get_pool()

    # 1. Check cache
    async with pool.acquire() as conn:
        cached = await get_cached_outfits(conn, user_id, occasion)
    if cached:
        logger.info(f"Cache hit for user={user_id}, occasion={occasion}")
        return {"outfits": cached, "cached": True}

    # 2. Fetch preferences + items
    async with pool.acquire() as conn:
        prefs = await get_preferences(conn, user_id)
        items, _ = await get_items(conn, user_id, limit=200)

    if not prefs:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Complete onboarding first")

    if len(items) < 3:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Add at least 3 items to generate outfits")

    # 3. Get weather
    weather = weather_override
    if not weather:
        weather = await get_weather(prefs.get("location_city", "delhi"))

    # 4. Rule engine
    candidates = generate_candidates(items, occasion, weather)
    if not candidates:
        return {"outfits": [], "cached": False}

    # 5. LLM ranker
    ranked = await rank_outfits(candidates, prefs, occasion, weather)

    # 6. Save to DB and format response
    outfits = []
    async with pool.acquire() as conn:
        for outfit_data in ranked:
            outfit_data["occasion"] = occasion
            outfit_data["weather"] = weather
            saved = await save_outfit(conn, user_id, outfit_data)

            # Format items with image URLs
            formatted_items = []
            for item in outfit_data["items"]:
                item_copy = dict(item)
                item_copy["image_url"] = get_image_url(item_copy.get("image_url", ""))
                formatted_items.append(item_copy)

            outfits.append({
                "id": saved["id"],
                "items": formatted_items,
                "reason": outfit_data.get("reason"),
                "rule_score": outfit_data.get("rule_score"),
                "occasion": occasion,
                "weather": weather,
            })

        # Cache
        await set_cached_outfits(conn, user_id, occasion, outfits)

    return {"outfits": outfits, "cached": False}


async def shuffle_outfit(user_id: str, occasion: str) -> dict:
    """Generate a single random outfit. Uses rule engine + randomness, no LLM."""
    import random

    pool = await get_pool()
    async with pool.acquire() as conn:
        prefs = await get_preferences(conn, user_id)
        items, _ = await get_items(conn, user_id, limit=200)

    if not prefs or len(items) < 3:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Need preferences and at least 3 items")

    weather = await get_weather(prefs.get("location_city", "delhi"))
    candidates = generate_candidates(items, occasion, weather, max_candidates=10)

    if not candidates:
        return {"outfit": None}

    # Pick a random one from top 10 (weighted by score)
    weights = [c["score"] for c in candidates]
    chosen = random.choices(candidates, weights=weights, k=1)[0]

    # Save to DB
    async with pool.acquire() as conn:
        chosen["occasion"] = occasion
        chosen["weather"] = weather
        saved = await save_outfit(conn, user_id, chosen)

    formatted_items = []
    for item in chosen["items"]:
        item_copy = dict(item)
        item_copy["image_url"] = get_image_url(item_copy.get("image_url", ""))
        formatted_items.append(item_copy)

    return {
        "outfit": {
            "id": saved["id"],
            "items": formatted_items,
            "reason": None,
            "rule_score": chosen["score"],
            "occasion": occasion,
        }
    }
```

### Step 9.5 -- `app/routes/outfits.py`

```python
"""Outfit generation and feedback routes."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Literal

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.outfits import record_feedback, get_today_outfits
from app.models.user import User
from app.services.outfit_service import generate_outfits, shuffle_outfit

router = APIRouter(prefix="/outfits", tags=["Outfits"])


class GenerateRequest(BaseModel):
    occasion: Literal["casual", "work", "party", "gym", "date", "festive", "travel"]
    weather_override: dict | None = None


class FeedbackRequest(BaseModel):
    action: Literal["like", "dislike", "save", "wear", "skip"]


@router.post("/generate")
async def generate(req: GenerateRequest, user: User = Depends(get_current_user)):
    result = await generate_outfits(user.id, req.occasion, req.weather_override)
    return result


@router.post("/shuffle")
async def shuffle(req: GenerateRequest, user: User = Depends(get_current_user)):
    result = await shuffle_outfit(user.id, req.occasion)
    return result


@router.post("/{outfit_id}/feedback")
async def submit_feedback(
    outfit_id: str,
    req: FeedbackRequest,
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        # Verify outfit belongs to user
        row = await conn.fetchrow(
            "SELECT id FROM outfits WHERE id = $1 AND user_id = $2", outfit_id, user.id
        )
        if not row:
            raise HTTPException(status_code=404, detail="Outfit not found")
        await record_feedback(conn, user.id, outfit_id, req.action)
    return {"recorded": True}


@router.get("/today")
async def today(user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        outfits = await get_today_outfits(conn, user.id)
    if not outfits:
        return {"outfits": [], "cached": False}
    return {"outfits": outfits, "cached": True}
```

---

## Phase 10 -- Lookbooks

### What you're building
CRUD for lookbooks (collections of saved outfits).

### Step 10.1 -- `app/database/queries/lookbooks.py`

```python
"""Lookbook database queries."""

import json
import uuid
import asyncpg


async def create_lookbook(conn: asyncpg.Connection, user_id: str, name: str) -> dict:
    row = await conn.fetchrow(
        "INSERT INTO lookbooks (id, user_id, name) VALUES ($1, $2, $3) RETURNING *",
        str(uuid.uuid4()), user_id, name,
    )
    return dict(row)


async def get_lookbooks(conn: asyncpg.Connection, user_id: str) -> list[dict]:
    rows = await conn.fetch(
        """
        SELECT l.*, COUNT(lo.outfit_id) as outfit_count
        FROM lookbooks l
        LEFT JOIN lookbook_outfits lo ON lo.lookbook_id = l.id
        WHERE l.user_id = $1
        GROUP BY l.id
        ORDER BY l.created_at DESC
        """,
        user_id,
    )
    return [dict(r) for r in rows]


async def get_lookbook_with_outfits(conn: asyncpg.Connection, lookbook_id: str, user_id: str) -> dict | None:
    lb = await conn.fetchrow(
        "SELECT * FROM lookbooks WHERE id = $1 AND user_id = $2", lookbook_id, user_id
    )
    if not lb:
        return None

    outfits = await conn.fetch(
        """
        SELECT o.* FROM outfits o
        JOIN lookbook_outfits lo ON lo.outfit_id = o.id
        WHERE lo.lookbook_id = $1
        ORDER BY lo.added_at DESC
        """,
        lookbook_id,
    )
    result = dict(lb)
    result["outfits"] = [dict(o) for o in outfits]
    return result


async def add_outfit_to_lookbook(conn: asyncpg.Connection, lookbook_id: str, outfit_id: str, user_id: str) -> bool:
    # Verify both belong to user
    lb = await conn.fetchrow("SELECT id FROM lookbooks WHERE id = $1 AND user_id = $2", lookbook_id, user_id)
    outfit = await conn.fetchrow("SELECT id FROM outfits WHERE id = $1 AND user_id = $2", outfit_id, user_id)
    if not lb or not outfit:
        return False

    await conn.execute(
        "INSERT INTO lookbook_outfits (lookbook_id, outfit_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        lookbook_id, outfit_id,
    )
    return True


async def remove_outfit_from_lookbook(conn: asyncpg.Connection, lookbook_id: str, outfit_id: str, user_id: str) -> bool:
    lb = await conn.fetchrow("SELECT id FROM lookbooks WHERE id = $1 AND user_id = $2", lookbook_id, user_id)
    if not lb:
        return False
    await conn.execute(
        "DELETE FROM lookbook_outfits WHERE lookbook_id = $1 AND outfit_id = $2", lookbook_id, outfit_id
    )
    return True


async def rename_lookbook(conn: asyncpg.Connection, lookbook_id: str, user_id: str, name: str) -> dict | None:
    row = await conn.fetchrow(
        "UPDATE lookbooks SET name = $1 WHERE id = $2 AND user_id = $3 RETURNING *",
        name, lookbook_id, user_id,
    )
    return dict(row) if row else None


async def delete_lookbook(conn: asyncpg.Connection, lookbook_id: str, user_id: str) -> bool:
    result = await conn.execute("DELETE FROM lookbooks WHERE id = $1 AND user_id = $2", lookbook_id, user_id)
    return result == "DELETE 1"
```

### Step 10.2 -- `app/routes/lookbooks.py`

```python
"""Lookbook CRUD routes."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.lookbooks import (
    create_lookbook, get_lookbooks, get_lookbook_with_outfits,
    rename_lookbook, delete_lookbook, add_outfit_to_lookbook,
    remove_outfit_from_lookbook,
)
from app.models.user import User

router = APIRouter(prefix="/lookbooks", tags=["Lookbooks"])


class CreateLookbookRequest(BaseModel):
    name: str


class RenameLookbookRequest(BaseModel):
    name: str


@router.post("", status_code=201)
async def create(req: CreateLookbookRequest, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        lb = await create_lookbook(conn, user.id, req.name)
    return lb


@router.get("")
async def list_all(user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        lbs = await get_lookbooks(conn, user.id)
    return {"lookbooks": lbs}


@router.get("/{lookbook_id}")
async def get_one(lookbook_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        lb = await get_lookbook_with_outfits(conn, lookbook_id, user.id)
    if not lb:
        raise HTTPException(status_code=404, detail="Lookbook not found")
    return lb


@router.patch("/{lookbook_id}")
async def rename(lookbook_id: str, req: RenameLookbookRequest, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        lb = await rename_lookbook(conn, lookbook_id, user.id, req.name)
    if not lb:
        raise HTTPException(status_code=404, detail="Lookbook not found")
    return lb


@router.delete("/{lookbook_id}")
async def delete(lookbook_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        deleted = await delete_lookbook(conn, lookbook_id, user.id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Lookbook not found")
    return {"deleted": True}


@router.post("/{lookbook_id}/outfits/{outfit_id}")
async def add_outfit(lookbook_id: str, outfit_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        added = await add_outfit_to_lookbook(conn, lookbook_id, outfit_id, user.id)
    if not added:
        raise HTTPException(status_code=404, detail="Lookbook or outfit not found")
    return {"saved": True, "lookbook_id": lookbook_id}


@router.delete("/{lookbook_id}/outfits/{outfit_id}")
async def remove_outfit(lookbook_id: str, outfit_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        removed = await remove_outfit_from_lookbook(conn, lookbook_id, outfit_id, user.id)
    if not removed:
        raise HTTPException(status_code=404, detail="Lookbook not found")
    return {"removed": True}
```

---

## Phase 11 -- Demo Wardrobe

### What you're building
A seeder script that creates 15-20 demo items for new users to try the app before uploading their own clothes.

### Step 11.1 -- `app/services/demo_wardrobe.py`

```python
"""Demo wardrobe seeder. Pre-tagged items for new users to explore the app."""

import logging

from app.database.pool import get_pool
from app.database.queries.items import insert_item

logger = logging.getLogger(__name__)

# Pre-built demo items (no AI processing needed, tags are hardcoded)
DEMO_ITEMS = [
    {"image_key": "demo/navy_polo.png", "category": "top", "sub_category": "polo", "primary_color": "navy", "pattern": "solid", "fabric": "cotton", "formality": 3, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/white_shirt.png", "category": "top", "sub_category": "shirt", "primary_color": "white", "pattern": "solid", "fabric": "cotton", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/black_tshirt.png", "category": "top", "sub_category": "t_shirt", "primary_color": "black", "pattern": "solid", "fabric": "cotton", "formality": 1, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/maroon_kurta.png", "category": "ethnic", "sub_category": "kurta", "primary_color": "maroon", "pattern": "embroidered", "fabric": "silk", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": True},
    {"image_key": "demo/olive_jacket.png", "category": "outerwear", "sub_category": "jacket", "primary_color": "olive", "pattern": "solid", "fabric": "cotton", "formality": 3, "season_tags": ["winter"], "ethnic_flag": False},
    {"image_key": "demo/beige_chinos.png", "category": "bottom", "sub_category": "chinos", "primary_color": "beige", "pattern": "solid", "fabric": "cotton", "formality": 3, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/blue_jeans.png", "category": "bottom", "sub_category": "jeans", "primary_color": "blue", "pattern": "solid", "fabric": "denim", "formality": 2, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/grey_trousers.png", "category": "bottom", "sub_category": "trousers", "primary_color": "grey", "pattern": "solid", "fabric": "polyester", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/black_shorts.png", "category": "bottom", "sub_category": "shorts", "primary_color": "black", "pattern": "solid", "fabric": "cotton", "formality": 1, "season_tags": ["summer"], "ethnic_flag": False},
    {"image_key": "demo/white_sneakers.png", "category": "footwear", "sub_category": "sneakers", "primary_color": "white", "pattern": "solid", "fabric": "synthetic", "formality": 2, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/brown_loafers.png", "category": "footwear", "sub_category": "loafers", "primary_color": "brown", "pattern": "solid", "fabric": "leather", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/kolhapuri.png", "category": "footwear", "sub_category": "kolhapuri", "primary_color": "brown", "pattern": "solid", "fabric": "leather", "formality": 3, "season_tags": ["summer"], "ethnic_flag": True},
    {"image_key": "demo/nehru_jacket.png", "category": "ethnic", "sub_category": "nehru_jacket", "primary_color": "cream", "pattern": "solid", "fabric": "linen", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": True},
    {"image_key": "demo/watch.png", "category": "accessory", "sub_category": "watch", "primary_color": "silver", "pattern": "solid", "fabric": "metal", "formality": 3, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/sunglasses.png", "category": "accessory", "sub_category": "sunglasses", "primary_color": "black", "pattern": "solid", "fabric": "plastic", "formality": 2, "season_tags": ["summer"], "ethnic_flag": False},
]

DEMO_USER_ID = "demo-user"


async def seed_demo_wardrobe() -> int:
    """Seed demo wardrobe items. Returns count of items created."""
    pool = await get_pool()
    count = 0
    async with pool.acquire() as conn:
        # Check if already seeded
        existing = await conn.fetchval(
            "SELECT COUNT(*) FROM items WHERE user_id = $1", DEMO_USER_ID
        )
        if existing > 0:
            logger.info(f"Demo wardrobe already seeded ({existing} items)")
            return existing

        for demo in DEMO_ITEMS:
            tags = {k: v for k, v in demo.items() if k != "image_key"}
            tags["confidence"] = 1.0
            tags["style_tags"] = []
            tags["secondary_colors"] = []
            await insert_item(conn, DEMO_USER_ID, demo["image_key"], tags)
            count += 1

    logger.info(f"Seeded {count} demo wardrobe items")
    return count
```

### Step 11.2 -- `app/routes/demo.py`

```python
"""Demo wardrobe endpoint for new users."""

from fastapi import APIRouter, Depends
from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.items import get_items
from app.models.user import User
from app.services.storage import get_image_url

router = APIRouter(tags=["Demo"])

DEMO_USER_ID = "demo-user"


@router.get("/demo/wardrobe")
async def get_demo_wardrobe(user: User = Depends(get_current_user)):
    """Return the demo wardrobe. Any authenticated user can access this."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        items, total = await get_items(conn, DEMO_USER_ID, limit=50)

    for item in items:
        item["image_url"] = get_image_url(item["image_url"])

    return {"items": items, "total": total, "is_demo": True}
```

---

## Phase 12 -- Push Notifications

### What you're building
FCM token registration and daily outfit push notifications.

### Step 12.1 -- `app/routes/push.py`

```python
"""Push notification token registration."""

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Literal

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.models.user import User

router = APIRouter(prefix="/push", tags=["Push"])


class RegisterTokenRequest(BaseModel):
    token: str
    platform: Literal["android", "ios"]


@router.post("/register")
async def register_token(req: RegisterTokenRequest, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO push_tokens (user_id, token, platform)
            VALUES ($1, $2, $3)
            ON CONFLICT (user_id, platform) DO UPDATE SET token = $2, updated_at = NOW()
            """,
            user.id, req.token, req.platform,
        )
    return {"registered": True}
```

### Step 12.2 -- `app/services/push_sender.py`

```python
"""Send push notifications via Firebase Cloud Messaging."""

import logging

import firebase_admin
from firebase_admin import credentials, messaging

from app.config import settings
from app.database.pool import get_pool

logger = logging.getLogger(__name__)

_app_initialized = False


def _init_firebase():
    global _app_initialized
    if not _app_initialized:
        # In production, use service account JSON
        # firebase_admin.initialize_app(credentials.Certificate("service-account.json"))
        firebase_admin.initialize_app()
        _app_initialized = True


async def send_daily_outfit_push(user_id: str, message_body: str) -> bool:
    """Send a push notification to a user."""
    _init_firebase()

    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT token, platform FROM push_tokens WHERE user_id = $1", user_id
        )

    if not rows:
        return False

    for row in rows:
        try:
            msg = messaging.Message(
                notification=messaging.Notification(
                    title="DrapeAI",
                    body=message_body,
                ),
                data={"screen": "today_outfits"},
                token=row["token"],
            )
            messaging.send(msg)
            logger.info(f"Push sent to user {user_id} ({row['platform']})")
        except Exception as e:
            logger.error(f"Push failed for user {user_id}: {e}")

    return True
```

---

## Phase 13 -- Testing

### What you're building
pytest + httpx async test suite with fixtures for auth, DB, and mocked external services.

### Step 13.1 -- `tests/conftest.py`

```python
"""Shared test fixtures."""

import asyncio
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.database.pool import init_pool, close_pool, get_pool


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def setup_db():
    await init_pool()
    yield
    await close_pool()


@pytest_asyncio.fixture
async def client(setup_db):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}


@pytest_asyncio.fixture
async def clean_db(setup_db):
    """Clean test data after each test."""
    yield
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute("DELETE FROM outfit_feedback WHERE user_id = 'test-user-001'")
        await conn.execute("DELETE FROM lookbook_outfits WHERE lookbook_id IN (SELECT id FROM lookbooks WHERE user_id = 'test-user-001')")
        await conn.execute("DELETE FROM outfits WHERE user_id = 'test-user-001'")
        await conn.execute("DELETE FROM lookbooks WHERE user_id = 'test-user-001'")
        await conn.execute("DELETE FROM items WHERE user_id = 'test-user-001'")
        await conn.execute("DELETE FROM preferences WHERE user_id = 'test-user-001'")
```

### Step 13.2 -- `tests/test_health.py`

```python
import pytest


@pytest.mark.asyncio
async def test_health(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
```

### Step 13.3 -- `tests/test_auth.py`

```python
import pytest


@pytest.mark.asyncio
async def test_verify_with_token(client, auth_headers):
    resp = await client.post("/auth/verify", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["user_id"] == "test-user-001"


@pytest.mark.asyncio
async def test_verify_without_token(client):
    resp = await client.post("/auth/verify")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_verify_bad_token(client):
    resp = await client.post("/auth/verify", headers={"Authorization": "Bearer invalid"})
    assert resp.status_code == 401
```

### Step 13.4 -- `tests/test_items.py`

```python
import pytest
from unittest.mock import patch, AsyncMock


@pytest.mark.asyncio
async def test_list_items_empty(client, auth_headers, clean_db):
    resp = await client.get("/items", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["items"] == []
    assert resp.json()["total"] == 0


@pytest.mark.asyncio
async def test_list_items_unauthorized(client):
    resp = await client.get("/items")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_upload_invalid_type(client, auth_headers):
    resp = await client.post(
        "/items/upload",
        headers=auth_headers,
        files={"image": ("test.txt", b"not an image", "text/plain")},
    )
    assert resp.status_code == 400
```

### Step 13.5 -- Register all routers in `main.py`

```python
# Final main.py router registration:
from app.routes import health, auth, user, items, outfits, lookbooks, demo, push

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(items.router)
app.include_router(outfits.router)
app.include_router(lookbooks.router)
app.include_router(demo.router)
app.include_router(push.router)
```

---

## Checklist

Before moving to frontend development, verify:

- [ ] `GET /health` returns 200
- [ ] `POST /auth/verify` works with Firebase JWT (and test token in dev)
- [ ] `PUT /me/preferences` saves onboarding answers
- [ ] `POST /items/upload` removes background, tags with GPT-4o, returns tags
- [ ] `GET /items` lists and filters items
- [ ] `PATCH /items/{id}` updates tags and re-generates embedding
- [ ] `POST /outfits/generate` returns 3 ranked outfits with reasons
- [ ] `POST /outfits/shuffle` returns 1 random outfit
- [ ] `POST /outfits/{id}/feedback` records like/dislike/wear
- [ ] Lookbook CRUD works (create, list, add outfit, remove outfit, delete)
- [ ] `GET /demo/wardrobe` returns demo items
- [ ] `POST /push/register` saves FCM token
- [ ] All tests pass: `pytest -v`
- [ ] Swagger docs work: `http://localhost:8000/docs`
