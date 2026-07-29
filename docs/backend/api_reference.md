# DrapeAI -- API Reference

All endpoints served by the FastAPI backend at `https://api.drapeai.app`.

Every request (except `/health` and `/auth/*`) requires `Authorization: Bearer <firebase_jwt>`.

---

## Base URL

| Environment | URL |
|---|---|
| Development | `http://localhost:8000` |
| Production | `https://api.drapeai.app` |

---

## Response Format

All responses return JSON. Errors use this shape:

```json
{
  "detail": "Human-readable error message"
}
```

Standard HTTP status codes:
- `200` Success
- `201` Created
- `202` Accepted for background processing
- `400` Bad request (validation error)
- `401` Unauthorized (missing or invalid token)
- `403` Forbidden (accessing another user's resource)
- `404` Not found
- `429` Rate limited
- `500` Internal server error

---

## Health

### GET /health

No auth required. Used by monitoring and load balancers.

**Response 200:**
```json
{
  "status": "ok",
  "version": "1.0.0",
  "db": "connected"
}
```

---

## Auth

### POST /auth/verify

Verifies a Firebase JWT and provisions the user if first login. Called once on app launch.

**Request:**
```json
{
  "firebase_token": "eyJ..."
}
```

**Response 200:**
```json
{
  "user_id": "firebase-uid",
  "display_name": "Avinash",
  "onboarding_done": false,
  "has_body_photo": true,
  "avatar_status": "ready"
}
```

The mobile router uses `has_body_photo` and `avatar_status` for the body-first
gate. Style preferences no longer block entry to the app.

---

## User Profile

### GET /me

Returns current user profile + preferences.

**Response 200:**
```json
{
  "id": "uuid",
  "phone": "+91...",
  "email": null,
  "display_name": "Avinash",
  "photo_url": null,
  "try_on_photo_url": "/uploads/users/uid/try_on/photo.jpg",
  "avatar_status": "ready",
  "avatar_base_url": "/uploads/users/uid/avatar/base.png",
  "avatar_profile": {
    "pose": "front_or_three_quarter",
    "visibility": "full_body",
    "aspect_ratio": 0.6667,
    "crop_bounds": {"left": 0.1, "top": 0.02, "right": 0.9, "bottom": 0.98}
  },
  "avatar_error": null,
  "onboarding_done": false
}
```

### PATCH /me

Update user profile fields.

**Request:**
```json
{
  "name": "Avinash Singh",
  "avatar_url": "https://..."
}
```

**Response 200:** Updated user object (same shape as GET /me).

---

## Body-first avatar

### POST /me/try-on-photo

Uploads the private full-body source image used by try-on rendering. The API
returns immediately after storage and schedules validation, person
segmentation, and avatar-base preparation. Orientation is normalized and EXIF,
including embedded GPS metadata, is removed before storage.

**Request:** `multipart/form-data`
- `image` (required): JPEG, PNG, or WebP.

**Response 202:**
```json
{
  "try_on_photo_url": "/uploads/users/uid/try_on/photo.jpg",
  "uploaded": true,
  "avatar_status": "queued"
}
```

### GET /me/avatar-profile

Poll until `status` is `ready` or `failed`.

```json
{
  "status": "ready",
  "avatar_base_url": "/uploads/users/uid/avatar/base.png",
  "source_photo_url": "/uploads/users/uid/try_on/photo.jpg",
  "profile": {
    "pose": "front_or_three_quarter",
    "visibility": "full_body",
    "aspect_ratio": 0.6667,
    "crop_bounds": {"left": 0.1, "top": 0.02, "right": 0.9, "bottom": 0.98}
  },
  "error": null,
  "analyzed_at": "2026-07-18T18:30:00Z"
}
```

The profile intentionally contains renderability metadata only. It does not
infer weight, exact dimensions, or body measurements.

### DELETE /me/try-on-photo

Deletes both the source body photo and the derived avatar base. The user
returns to Body Setup.

### POST /avatar/render

Creates a manual outfit from authenticated-user-owned wardrobe items and
starts the existing asynchronous try-on pipeline.

```json
{
  "slots": {
    "tops": "item-uuid",
    "bottoms": "item-uuid",
    "footwear": "item-uuid"
  }
}
```

Accepted slots are `tops`, `bottoms`, `dresses`, `outerwear`, `footwear`,
`accessories`, `caps`, and `glasses`. The API validates ownership,
`processing_status=ready`, category compatibility, duplicate items, and dress
conflicts. The response contains `outfit_id`, `job_id`, and `status`; completed
sync fallbacks may also include `preview_url`.

### GET /avatar/render/{outfit_id}/status

Polls the render using the same job payload as outfit visualization. The
completed response includes `preview_url`.

---

## Preferences (progressive personalization)

### PUT /me/preferences

Create or update the full preference profile. Called when onboarding quiz is completed.

**Request:**
```json
{
  "style_tags": ["minimalist", "streetwear"],
  "occasions": ["casual", "work", "party"],
  "color_palette": ["neutrals", "bold"],
  "preferred_fit": "regular",
  "city": "Mumbai",
  "climate": "tropical",
  "gender": "male"
}
```

**Validation rules:**
- `style_tags`: array of 1-5 strings from allowed set
- `occasions`: array of 1-6 strings from: `casual`, `work`, `party`, `gym`, `date`, `festive`, `travel`
- `color_palette`: array of 1-3 strings from: `neutrals`, `earth_tones`, `pastels`, `bold`, `monochrome`, `jewel_tones`
- `preferred_fit`: one of `slim`, `regular`, `relaxed`, `oversized`
- `city`: any string (used for weather API lookup)
- `climate`: one of `tropical`, `subtropical`, `temperate`, `arid`, `cold`
- `gender`: one of `male`, `female`, `non_binary`, `prefer_not_to_say`

**Response 200:** Updated preferences object.

### GET /me/preferences

Returns current preferences.

**Response 200:** Same shape as the request body above, plus `quiz_completed: true/false`.

---

## Items (Wardrobe)

### POST /items/upload

Accept a clothing item after background removal. AI tagging and embedding run
asynchronously (ARQ worker when Redis is available, otherwise FastAPI
`BackgroundTasks`). The cleaned item appears in the closet with
`processing_status` of `queued` / `processing` until tagging finishes.

**Request:** `multipart/form-data`
- `image` (required): JPEG, PNG, or WebP. Max 10 MB.

**Response 201:**
```json
{
  "id": "uuid",
  "image_url": "/uploads/users/uid/items/iid.png",
  "status": "processing",
  "processing_status": "queued",
  "tags": {
    "category": "top",
    "sub_category": "processing",
    "primary_color": "unknown",
    "confidence": 0.0
  },
  "confidence": 0.0
}
```

Poll `GET /items` — when analysis completes, `processing_status` becomes
`ready` (or `failed` if tagging fails).

**Errors:**
- `400` Invalid image type / too large / corrupt
- `429` Rate limit (max 20 uploads per minute)

### POST /items/upload/batch

Upload multiple items at once (max 10). Each photo is accepted immediately;
AI analysis continues in the background.

**Request:** `multipart/form-data`
- `images` (required): Array of up to 10 image files.

**Response 201:**
```json
{
  "items": [
    { "id": "uuid", "image_url": "...", "tags": {...}, "confidence": 0.89 },
    { "id": "uuid", "image_url": "...", "tags": {...}, "confidence": 0.95 }
  ],
  "failed": [
    { "filename": "blurry.jpg", "error": "Image too blurry for reliable tagging" }
  ]
}
```

### GET /items

List all wardrobe items for the current user. Supports filtering and search.

**Query parameters:**
- `category` (optional): Filter by category. Example: `?category=top`
- `color` (optional): Filter by primary_color. Example: `?color=navy`
- `season` (optional): Filter by season tag. Example: `?season=summer`
- `ethnic` (optional): Filter ethnic items. Example: `?ethnic=true`
- `search` (optional): Keyword search across sub_category, color, fabric, style_tags. Example: `?search=kurta`
- `sort` (optional): `newest` (default), `oldest`, `most_worn`, `least_worn`
- `limit` (optional): Default 50, max 200.
- `offset` (optional): Default 0.

**Response 200:**
```json
{
  "items": [
    {
      "id": "uuid",
      "image_url": "...",
      "thumbnail_url": "...",
      "category": "top",
      "sub_category": "kurta",
      "primary_color": "navy",
      "secondary_colors": ["gold"],
      "pattern": "embroidered",
      "fabric": "cotton",
      "style_tags": ["ethnic", "festive"],
      "formality": 4,
      "season_tags": ["all_season"],
      "ethnic_flag": true,
      "wear_count": 3,
      "last_worn_at": "2026-04-15T10:00:00Z",
      "created_at": "2026-03-20T14:30:00Z"
    }
  ],
  "total": 24,
  "limit": 50,
  "offset": 0
}
```

### GET /items/{id}

Single item with full details.

**Response 200:** Single item object (same shape as above, plus `brand`, `purchase_price`, `notes`, `embedding` omitted).

### PATCH /items/{id}

Update item tags or metadata. Used when user corrects AI tags.

**Request:**
```json
{
  "category": "ethnic",
  "sub_category": "kurta",
  "primary_color": "maroon",
  "fabric": "silk",
  "purchase_price": 249900,
  "notes": "Wedding kurta from FabIndia"
}
```

Note: `purchase_price` is in paise (INR x 100). 249900 = Rs 2,499.

**Response 200:** Updated item object.

If category or color changed, backend re-generates the embedding in the background.

### DELETE /items/{id}

Soft-delete (sets `is_active = false`). Item no longer appears in wardrobe or outfit generation.

**Response 200:**
```json
{ "deleted": true }
```

---

## Outfits

### POST /outfits/generate

Generate 3 AI outfit recommendations.

**Request:**
```json
{
  "occasion": "casual",
  "weather_override": null
}
```

- `occasion` (required): one of `casual`, `work`, `party`, `gym`, `date`, `festive`, `travel`
- `weather_override` (optional): `{ "temp": 28, "condition": "rain" }`. If null, auto-fetched.

**Response 200:**
```json
{
  "outfits": [
    {
      "id": "uuid",
      "items": [
        { "id": "uuid", "image_url": "...", "category": "top", "sub_category": "polo", "primary_color": "navy" },
        { "id": "uuid", "image_url": "...", "category": "bottom", "sub_category": "chinos", "primary_color": "beige" },
        { "id": "uuid", "image_url": "...", "category": "footwear", "sub_category": "loafers", "primary_color": "brown" }
      ],
      "reason": "Navy polo with beige chinos is a timeless casual combo. Brown loafers elevate it without being too formal.",
      "rule_score": 87.5,
      "occasion": "casual",
      "weather": { "temp": 28, "condition": "clear" }
    }
  ],
  "cached": false,
  "generated_at": "2026-04-20T09:00:00Z"
}
```

### POST /outfits/shuffle

Generate a single random valid outfit. Different from /generate -- uses randomness, not LLM ranking.

**Request:**
```json
{
  "occasion": "casual"
}
```

**Response 200:**
```json
{
  "outfit": {
    "id": "uuid",
    "items": [...],
    "reason": null,
    "rule_score": 72.0,
    "occasion": "casual"
  }
}
```

### POST /outfits/{id}/feedback

Submit feedback on an outfit.

**Request:**
```json
{
  "action": "like"
}
```

- `action`: one of `like`, `dislike`, `save`, `wear`, `skip`

**Response 200:**
```json
{ "recorded": true }
```

Side effects:
- `like` / `save`: sets `is_saved = true` on the outfit
- `wear`: creates wear_log entries for each item, increments `wear_count` on each item
- `dislike`: logged for future preference learning

### POST /outfits/{id}/save

Save an outfit to a lookbook.

**Request:**
```json
{
  "lookbook_id": "uuid"
}
```

If `lookbook_id` is null, saves to a default "Saved" lookbook (auto-created).

**Response 200:**
```json
{ "saved": true, "lookbook_id": "uuid" }
```

### GET /outfits/today

Shortcut to get today's cached outfits (if previously generated). Returns empty if none generated today.

**Response 200:** Same shape as POST /outfits/generate response, with `cached: true`.

---

## Lookbooks

### GET /lookbooks

List all lookbooks for the current user.

**Response 200:**
```json
{
  "lookbooks": [
    {
      "id": "uuid",
      "name": "Work",
      "outfit_count": 5,
      "cover_image_url": "...",
      "created_at": "2026-03-20T14:30:00Z"
    }
  ]
}
```

### POST /lookbooks

Create a new lookbook.

**Request:**
```json
{
  "name": "Travel"
}
```

**Response 201:**
```json
{
  "id": "uuid",
  "name": "Travel",
  "outfit_count": 0,
  "created_at": "2026-04-20T10:00:00Z"
}
```

### GET /lookbooks/{id}

Get a lookbook with all its outfits.

**Response 200:**
```json
{
  "id": "uuid",
  "name": "Work",
  "outfits": [
    {
      "id": "uuid",
      "items": [...],
      "reason": "...",
      "created_at": "2026-04-18T09:00:00Z"
    }
  ]
}
```

### PATCH /lookbooks/{id}

Rename a lookbook.

**Request:**
```json
{ "name": "Office" }
```

### DELETE /lookbooks/{id}

Delete a lookbook. Does not delete the outfits inside it.

**Response 200:**
```json
{ "deleted": true }
```

### DELETE /lookbooks/{id}/outfits/{outfit_id}

Remove an outfit from a lookbook.

---

## Calendar (v1.1)

### GET /calendar

Get planned outfits for a date range.

**Query parameters:**
- `start_date` (required): ISO date, e.g., `2026-04-20`
- `end_date` (required): ISO date, e.g., `2026-04-30`

**Response 200:**
```json
{
  "entries": [
    {
      "date": "2026-04-21",
      "outfit": { "id": "uuid", "items": [...] },
      "occasion": "work",
      "notes": "Client meeting"
    }
  ]
}
```

### PUT /calendar/{date}

Plan an outfit for a specific date.

**Request:**
```json
{
  "outfit_id": "uuid",
  "occasion": "work",
  "notes": "Client meeting"
}
```

### DELETE /calendar/{date}

Remove a planned outfit.

---

## Analytics (v1.1)

### GET /analytics/summary

Returns wardrobe analytics for the current user.

**Response 200:**
```json
{
  "total_items": 24,
  "items_worn_at_least_once": 16,
  "utilisation_pct": 66.7,
  "most_worn": [
    { "id": "uuid", "sub_category": "jeans", "color": "blue", "wear_count": 18 }
  ],
  "least_worn": [
    { "id": "uuid", "sub_category": "blazer", "color": "black", "wear_count": 0 }
  ],
  "color_breakdown": {
    "navy": 5, "white": 4, "black": 4, "beige": 3, "red": 2
  },
  "category_breakdown": {
    "top": 10, "bottom": 6, "footwear": 4, "accessory": 3, "ethnic": 1
  },
  "avg_cost_per_wear": 12350
}
```

---

## Push Notifications

### POST /push/register

Register or update FCM token for push notifications.

**Request:**
```json
{
  "token": "fcm_device_token_string",
  "platform": "android"
}
```

**Response 200:**
```json
{ "registered": true }
```

### DELETE /push/unregister

Unregister device from push notifications.

**Request:**
```json
{
  "token": "fcm_device_token_string"
}
```

---

## Rate Limits

| Endpoint | Limit |
|---|---|
| POST /items/upload | 20/minute |
| POST /items/upload/batch | 5/minute |
| POST /outfits/generate | 10/minute |
| POST /outfits/shuffle | 30/minute |
| All other endpoints | 60/minute |

Rate limit headers returned on every response:
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 58
X-RateLimit-Reset: 1713600000
```

On 429, response body:
```json
{
  "detail": "Rate limit exceeded. Try again in 45 seconds."
}
```
