# DrapeAI Backend -- Coding Standards

Python and FastAPI rules. Read before writing any backend code.

---

## 1. Security First

### Parameterized queries -- always

```python
# CORRECT
row = await conn.fetchrow(
    "SELECT * FROM items WHERE id = $1 AND user_id = $2",
    item_id, user_id
)

# WRONG -- SQL injection
row = await conn.fetchrow(f"SELECT * FROM items WHERE id = '{item_id}'")
```

### Ownership checks on every resource

Every query that reads/writes a user's data must include `user_id` in the WHERE clause. Never trust the URL path alone.

```python
async def get_item(item_id: str, user_id: str) -> dict:
    row = await conn.fetchrow(
        "SELECT * FROM items WHERE id = $1 AND user_id = $2",
        item_id, user_id
    )
    if not row:
        raise HTTPException(status_code=404, detail="Item not found")
    return dict(row)
```

### File upload validation

```python
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB

def validate_image_upload(content_type: str, size: int, file_bytes: bytes) -> None:
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="Invalid image type")
    if size > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=400, detail="Image too large (max 10MB)")
    # Magic bytes check
    if not (file_bytes[:3] == b'\xff\xd8\xff'          # JPEG
            or file_bytes[:8] == b'\x89PNG\r\n\x1a\n'  # PNG
            or file_bytes[:4] == b'RIFF'):              # WEBP
        raise HTTPException(status_code=400, detail="File content does not match declared type")
```

### Never log secrets

API keys, tokens, passwords must never appear in log output.

### Never expose internal errors to clients

```python
try:
    result = await process_image(file_bytes)
except Exception as e:
    logger.error(f"Vision tagging failed: {e}", exc_info=True)
    raise HTTPException(status_code=500, detail="Image processing failed. Please try again.")
```

---

## 2. Async Everything

All I/O operations must be async. Never block the event loop.

```python
# CORRECT -- async HTTP
async with httpx.AsyncClient(timeout=60) as client:
    response = await client.post(url, json=body)

# CORRECT -- async DB
async with pool.acquire() as conn:
    rows = await conn.fetch("SELECT * FROM items WHERE user_id = $1", user_id)

# CORRECT -- sync library in thread pool
loop = asyncio.get_running_loop()
result = await loop.run_in_executor(None, rembg.remove, image_bytes)

# WRONG -- blocks event loop
response = requests.post(url, json=body)
time.sleep(2)
```

---

## 3. Error Handling

Every endpoint returns predictable error shapes:

```python
raise HTTPException(status_code=404, detail="Item not found")
raise HTTPException(status_code=403, detail="Access denied")
raise HTTPException(status_code=400, detail="Invalid image format")
raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in 60 seconds.")
raise HTTPException(status_code=500, detail="Processing failed. Please try again.")
```

Global exception handler catches unhandled errors:

```python
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled error: {exc}", exc_info=True)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})
```

---

## 4. Single Responsibility

- Max function length: ~50 lines
- Max file length: ~300 lines (split into modules if exceeding)
- One router per domain: `items.py`, `outfits.py`, `auth.py`, `lookbooks.py`
- One service per concern: `vision.py`, `outfit_engine.py`, `llm_ranker.py`, `storage.py`
- Queries in `database/queries/` -- never write raw SQL in routers

---

## 5. LLM Calls -- Retry + Timeout

All OpenAI calls use retry with exponential backoff:

```python
MAX_RETRIES = 3
RETRY_DELAYS = [10, 20, 40]  # seconds

async def call_with_retry(func, *args, **kwargs):
    for attempt in range(MAX_RETRIES):
        try:
            return await func(*args, **kwargs)
        except Exception as e:
            logger.warning(f"LLM call attempt {attempt + 1} failed: {e}")
            if attempt < MAX_RETRIES - 1:
                await asyncio.sleep(RETRY_DELAYS[attempt])
            else:
                raise
```

All httpx calls use explicit timeouts:

```python
async with httpx.AsyncClient(timeout=120) as client:
    response = await client.post(vision_url, json=payload)
```

---

## 6. Naming Conventions

| What | Pattern | Example |
|---|---|---|
| Files | `snake_case.py` | `rule_engine.py` |
| Functions | `snake_case` | `generate_outfit()` |
| Classes | `PascalCase` | `VisionTagger` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_IMAGE_SIZE` |
| DB tables | `snake_case` | `outfit_feedback` |
| DB columns | `snake_case` | `primary_color` |
| API routes | `snake_case` | `/items/upload` |
| Env vars | `UPPER_SNAKE_CASE` | `OPENAI_API_KEY` |

---

## 7. No Emojis

Never use emoji characters in code, log messages, or API responses.

```python
# CORRECT
logger.info("Item tagged successfully")

# WRONG
logger.info("Item tagged successfully ✅")
```

---

## 8. Configuration via Environment

All config via env vars. Never hardcode secrets. Use pydantic `BaseSettings`:

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    environment: str = "development"
    database_url: str
    openai_api_key: str
    openai_spend_cap: float = 20.0
    r2_account_id: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket_name: str = "drapeai-images"
    r2_public_url: str = "http://localhost:8000/uploads"
    firebase_project_id: str = ""
    log_level: str = "INFO"

    class Config:
        env_file = ".env"

settings = Settings()
```

Dev mode: when `environment=development`, use local filesystem for storage and accept test auth tokens.

---

## 9. Testing Standards

```python
# Every endpoint needs: happy path + auth failure + ownership check

@pytest.mark.asyncio
async def test_get_items_returns_only_owned(client, auth_headers, seed_items):
    response = await client.get("/items", headers=auth_headers)
    assert response.status_code == 200
    items = response.json()
    assert all(item["user_id"] == TEST_USER_ID for item in items)

@pytest.mark.asyncio
async def test_get_items_unauthorized(client):
    response = await client.get("/items")
    assert response.status_code == 401

@pytest.mark.asyncio
async def test_get_item_other_user_returns_404(client, auth_headers, other_user_item):
    response = await client.get(f"/items/{other_user_item.id}", headers=auth_headers)
    assert response.status_code == 404
```

Mock external services (OpenAI, R2) in tests. Never make real API calls in CI.

---

## 10. Git Conventions

```
feat: add outfit shuffle endpoint
fix: handle null color in rule engine scoring
chore: bump fastapi to 0.115
docs: add rate limit info to api reference
test: add vision tagging mock tests
```

One feature per PR. All tests pass before merge. Squash merge to main.

---

## 11. Storage Abstraction

Never construct R2 URLs directly. Always use `storage.py`:

```python
from app.services.storage import upload_image, get_image_url

url = await upload_image(user_id, item_id, image_bytes, "image/png")
public_url = get_image_url(url)
```

In development, `storage.py` writes to local filesystem. In production, it uploads to R2.

---

## 12. Cost Tracking

Track every OpenAI API call in the spend tracker:

```python
from app.utils.cost_tracker import track_spend, check_budget

# Before any OpenAI call
await check_budget()  # raises 503 if monthly cap exceeded

# After successful call
await track_spend(model="gpt-4o", tokens_in=800, tokens_out=200, cost_usd=0.03)
```
