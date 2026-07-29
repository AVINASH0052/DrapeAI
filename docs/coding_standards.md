# DrapeAI -- Coding Standards

Rules that apply to all code written for DrapeAI. Read this before writing any code.

> **Preferred entry for agents:** [rules/CODING-STANDARDS.md](rules/CODING-STANDARDS.md) · [rules/AGENTS.md](rules/AGENTS.md) · [rules/CODING-RULES-HANDBOOK.md](rules/CODING-RULES-HANDBOOK.md)

---

## Critical Rules

### 1. No Emojis in Code

Never use emoji characters in code, UI strings, comments, or log messages.

- Flutter icons: Material Icons exclusively (`Icons.favorite`, `Icons.checkCircle`)
- Status indicators: use `Icons.check_circle_outline`, `Icons.error_outline`, `Icons.warning_amber`
- Navigation: use `Icons.menu`, `Icons.arrow_back`, `Icons.close`

```dart
// CORRECT
Icon(Icons.check_circle_outline, color: AppColors.success)

// WRONG
Text("Success! ✅")
```

```python
# CORRECT
logger.info("Item tagged successfully")

# WRONG
logger.info("Item tagged successfully ✅")
```

---

### 2. Light Theme Only

One consistent light theme. No dark mode toggle. Clean, modern, minimal -- like a YC-backed product.

**Color Palette (Flutter + Backend references):**

```dart
class AppColors {
  // Primary
  static const primary       = Color(0xFF111827); // Gray-900 -- primary actions, buttons
  static const primaryLight  = Color(0xFFF9FAFB); // Gray-50 -- selected backgrounds
  static const accent        = Color(0xFF6366F1); // Indigo-500 -- accents, highlights, AI elements

  // Backgrounds
  static const bgPrimary     = Color(0xFFFFFFFF); // White -- main background
  static const bgSecondary   = Color(0xFFF9FAFB); // Gray-50 -- cards, secondary panels
  static const bgTertiary    = Color(0xFFF3F4F6); // Gray-100 -- input fields, chips

  // Text
  static const textPrimary   = Color(0xFF111827); // Gray-900 -- headings
  static const textSecondary = Color(0xFF6B7280); // Gray-500 -- body, labels
  static const textMuted     = Color(0xFF9CA3AF); // Gray-400 -- placeholders, hints

  // Borders
  static const border        = Color(0xFFE5E7EB); // Gray-200
  static const borderLight   = Color(0xFFF3F4F6); // Gray-100

  // Semantic
  static const success       = Color(0xFF059669); // Emerald-600
  static const error         = Color(0xFFDC2626); // Red-600
  static const warning       = Color(0xFFD97706); // Amber-600
  static const info          = Color(0xFF2563EB); // Blue-600
}
```

Rules:
- No gradient backgrounds on screens (only subtle on accent elements like AI cards)
- No heavy drop shadows (use `elevation: 0` with border, or max `elevation: 1`)
- No neon or saturated colors outside the accent
- No dark mode

---

### 3. Security First

Every piece of code must consider security. No exceptions.

**Backend -- parameterized queries always:**
```python
# CORRECT
row = await conn.fetchrow(
    "SELECT * FROM items WHERE id = $1 AND user_id = $2",
    item_id, user_id
)

# WRONG -- SQL injection
row = await conn.fetchrow(f"SELECT * FROM items WHERE id = '{item_id}'")
```

**Ownership checks on every resource access:**
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

**File upload validation:**
```python
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB

def validate_image_upload(content_type: str, size: int, file_bytes: bytes) -> None:
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="Invalid image type")
    if size > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=400, detail="Image too large (max 10MB)")
    # Magic bytes check
    if not (file_bytes[:3] == b'\xff\xd8\xff'      # JPEG
            or file_bytes[:8] == b'\x89PNG\r\n\x1a\n'  # PNG
            or file_bytes[:4] == b'RIFF'):           # WEBP
        raise HTTPException(status_code=400, detail="File content does not match declared type")
```

**Never log secrets:** API keys, tokens, passwords must never appear in log output.

**Never expose internal errors to clients:**
```python
try:
    result = await process_image(file_bytes)
except Exception as e:
    logger.error(f"Vision tagging failed: {e}", exc_info=True)
    raise HTTPException(status_code=500, detail="Image processing failed. Please try again.")
```

---

### 4. Error Handling -- Loading + Error + Empty States

Every async operation in the app needs all three states handled.

**Flutter (Riverpod):**
```dart
// In provider
final wardrobeProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final repo = ref.read(itemRepositoryProvider);
  return repo.getItems();
});

// In widget
ref.watch(wardrobeProvider).when(
  loading: () => const ShimmerGrid(),  // skeleton, never a bare spinner
  error: (e, _) => ErrorCard(
    message: "Could not load your wardrobe",
    onRetry: () => ref.invalidate(wardrobeProvider),
  ),
  data: (items) => items.isEmpty
      ? const EmptyState(
          icon: Icons.checkroom_outlined,
          title: "Your wardrobe is empty",
          subtitle: "Add your first item to get started",
          actionLabel: "Add item",
        )
      : WardrobeGrid(items: items),
);
```

**Backend (FastAPI):**
```python
raise HTTPException(status_code=404, detail="Item not found")
raise HTTPException(status_code=403, detail="Access denied")
raise HTTPException(status_code=400, detail="Invalid image format")
raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in 60 seconds.")
raise HTTPException(status_code=500, detail="Processing failed. Please try again.")
```

---

### 5. Single Responsibility

No god functions. One concern per function.

- Max function length: ~50 lines (Dart and Python)
- Max file length: ~300 lines (split into modules if exceeding)
- One router per domain: `items.py`, `outfits.py`, `auth.py`, `lookbooks.py`
- One service per concern: `vision_tagger.py`, `rule_engine.py`, `llm_ranker.py`
- Flutter: one widget per file, max 200 lines per widget file (extract sub-widgets)

---

### 6. Async Everything (Backend)

All I/O operations must be async. Never block the event loop.

```python
# CORRECT
async with httpx.AsyncClient(timeout=60) as client:
    response = await client.post(url, json=body)

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

### 7. LLM Calls -- Retry + Timeout

All LLM and Vision API calls use retry with exponential back-off:

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

# All httpx calls use explicit timeouts
async with httpx.AsyncClient(timeout=120) as client:
    response = await client.post(vision_url, json=payload)
```

---

### 8. Naming Conventions

| Context | Pattern | Example |
|---|---|---|
| Dart files | `snake_case.dart` | `wardrobe_grid.dart` |
| Dart classes | `PascalCase` | `OutfitCard` |
| Dart functions | `camelCase` | `generateOutfit()` |
| Dart constants | `camelCase` | `defaultOccasion` |
| Dart providers | `camelCase + Provider` | `wardrobeProvider` |
| Python files | `snake_case.py` | `rule_engine.py` |
| Python functions | `snake_case` | `generate_outfit()` |
| Python classes | `PascalCase` | `VisionTagger` |
| DB tables | `snake_case` | `outfit_feedback` |
| DB columns | `snake_case` | `primary_color`, `created_at` |
| API routes | `snake_case` | `/items/upload`, `/outfits/generate` |
| Env vars | `UPPER_SNAKE_CASE` | `OPENAI_API_KEY` |

---

### 9. Flutter State Management (Riverpod)

All state flows through Riverpod. No `setState()` outside of trivial local UI state (e.g., a text field controller).

```dart
// Repository provider
final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  final dio = ref.read(dioProvider);
  return ItemRepository(dio);
});

// Async data provider
final wardrobeProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final repo = ref.read(itemRepositoryProvider);
  return repo.getItems();
});

// Mutation via StateNotifier
class OutfitNotifier extends StateNotifier<AsyncValue<List<Outfit>>> {
  OutfitNotifier(this._repo) : super(const AsyncValue.loading());
  final OutfitRepository _repo;

  Future<void> generate(String occasion) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.generate(occasion));
  }

  Future<void> submitFeedback(String outfitId, bool liked) async {
    await _repo.feedback(outfitId, liked);
  }
}
```

---

### 10. Network Layer (Flutter)

All HTTP calls go through a single Dio instance configured with interceptors:

```dart
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Environment.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));
  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  return dio;
});

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.ref);
  final Ref ref;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ref.read(authTokenProvider);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

---

### 11. R2 Storage (Production) vs Local Filesystem (Dev)

Backend:
```python
from app.utils.storage import upload_image, get_image_url

# Upload -- switches between local and R2 based on R2_ACCOUNT_ID env var
image_url = await upload_image(
    user_id=user_id,
    item_id=item_id,
    image_bytes=processed_bytes,
    content_type="image/png",
)

# Download URL -- returns signed URL in prod, local path in dev
url = await get_image_url(image_url)
```

Never construct R2 URLs directly. Always use the `storage.py` utility.

---

### 12. Testing Standards

**Backend (pytest + httpx):**
```python
# Every endpoint needs at least one happy-path and one auth-failure test
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
```

**Flutter (widget tests):**
```dart
testWidgets('WardrobeGrid shows empty state when no items', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [wardrobeProvider.overrideWithValue(const AsyncData([]))],
      child: const MaterialApp(home: WardrobeScreen()),
    ),
  );
  expect(find.text('Your wardrobe is empty'), findsOneWidget);
});
```

---

### 13. Git Conventions

**Branch naming:**
- `feat/onboarding-quiz`
- `fix/vision-tagging-timeout`
- `chore/update-dependencies`

**Commit messages (conventional commits):**
```
feat: add outfit shuffle swipe deck
fix: handle null color in rule engine
chore: bump flutter to 3.24
docs: add API reference for /outfits/generate
```

**PR rules:**
- One feature per PR
- All tests pass before merge
- No `--force` push to `main`
- Squash merge to keep history clean

---

### 14. Environment Variables

All config via env vars. Never hardcode secrets.

```env
# Server
ENVIRONMENT=development       # development | production
LOG_LEVEL=INFO
API_PORT=8000

# Database
DATABASE_URL=postgresql://drapeai:password@localhost:5432/drapeai

# Auth
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_JWT_SECRET=super-secret

# AI
OPENAI_API_KEY=sk-...
OPENAI_SPEND_CAP=20          # USD per month hard limit

# Storage
R2_ACCOUNT_ID=               # empty = local filesystem mode
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=drapeai-images
R2_PUBLIC_URL=https://images.drapeai.app

# Weather
OPENWEATHER_API_KEY=

# Push
FIREBASE_PROJECT_ID=
```

Dev mode: when `ENVIRONMENT=development`, the backend uses local filesystem for storage, SQLite or local Postgres, and mock auth tokens.

---

### 15. Read Existing Code Before Writing Code

Before implementing any function, search for it first:
```bash
# Backend
grep -r "function_name" api/app/

# Flutter
grep -r "ClassName" app/lib/
```

Many utilities already exist. Avoid re-implementing.
