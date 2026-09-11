# Virtual try-on integrations

Cascade is Settings-driven (`TRYON_PROVIDER_*`, models, daily limits, async flags).

Default cascade (Cloud credits first):

1. **Vertex AI** `gemini-2.5-flash-image` — service account / ADC (`GOOGLE_APPLICATION_CREDENTIALS`, `GOOGLE_CLOUD_PROJECT`)
2. **Gemini Developer API** — `GEMINI_API_KEY` fallback
3. Cloudflare Workers AI / NVIDIA / optional RunPod IDM-VTON

On Vertex `us-central1` for project `sugatai`, newer IDs (`gemini-3-pro-image-preview`, Imagen 4) currently 404; bump `VERTEX_MODEL_IMAGE*` when Google publishes them on Vertex.

Providers may also include OpenAI image edit and **RunPod IDM-VTON**.

## Avatar Studio look cache

`POST /avatar/render` **reuses** a prior studio outfit when the same slots +
pose/style/quality + body photo fingerprint already has a saved preview
(`outfits.slot_fingerprint`). Pass `force=true` only to regenerate.

`GET /avatar/history` returns recent studio looks with previews so the client
can switch back to a white tee (etc.) without another AI render, then refine
or change one slot from that base look.

## HD quality (always on inference)

All try-on / refine / external paths send **HD** inputs to image models:

- Person long edge **2048**, garments **1536** (JPEG q≈92), via `try_on_prep.HD_*`
- HD Vertex/Gemini model ids preferred (`VERTEX_MODEL_IMAGE_HD` / `GEMINI_MODEL_IMAGE_HD`)
- OpenAI edits use `TRYON_IMAGE_QUALITY=high` (default)
- Cloudflare FLUX Klein still caps inputs at **512×512** (platform limit)

Avatar Studio’s quality toggle still affects prompt wording (`quality=hd` adds ultra-sharp directives); resolution into the model is always HD.

## Post-result text refine

After a try-on preview exists, clients can steer pose / background / lighting with freeform text:

- `POST /outfits/{outfit_id}/visualize/refine` — body `{ "message": "…" }` (max 500 chars)
- Uses the **latest preview** as IMAGE 0 (efficient edit; does not re-load wardrobe garments)
- Same daily try-on quota and async job / status poll as visualize (`GET …/visualize/status`)
- Returns **409** if another try-on job is already in progress for that outfit (so a new “change look” message is never silently dropped)
- Distinct from `POST /outfits/{id}/refine`, which only swaps wardrobe items

## Ops

- Worker: [../services/TRYON-WORKER.md](../services/TRYON-WORKER.md)
- Env: [../local-development/ENV-VARS.md](../local-development/ENV-VARS.md)
- Lessons: [../ops/SESSION-LESSONS.md](../ops/SESSION-LESSONS.md)
- Product plan notes: [../DrapeAI-Virtual-TryOn-Implementation-Plan.md](../DrapeAI-Virtual-TryOn-Implementation-Plan.md)

## Product constraint

IDM-VTON weights/code are **non-commercial** (CC BY-NC-SA 4.0). Keep fallbacks for production if licensing blocks IDM-VTON.
