# Custom IDM-VTON on RunPod Serverless — detailed steps

This guide deploys **IDM-VTON** as a **RunPod Serverless** endpoint (scale to 0 = $0 idle), then wires it to DrapeAI later.

Scaffold path: `infra/runpod/idm-vton-worker/`

Official model: [yisol/IDM-VTON](https://github.com/yisol/IDM-VTON)  
RunPod docs: [Serverless quickstart](https://docs.runpod.io/serverless/quickstart) · [Custom workers](https://docs.runpod.io/serverless/workers/overview) · [Handlers](https://docs.runpod.io/serverless/workers/handler-functions)

---

## 0. What you will end up with

```
DrapeAI FastAPI
    → POST RunPod /run  { person_image, garment_image }
    → IDM-VTON worker (RTX 4090 Serverless)
    → PNG base64 / URL
    → save to R2, show in app
```

| Setting | Value |
|---------|--------|
| Product | **Serverless** (not Pods) |
| GPU | **24GB+** (RTX 4090 / A5000) |
| Min workers | **0** |
| Idle cost | **$0** |

Do **not** use the Hub `engui_idm-vton` **Pod** template for production — that bills while the Pod is on.

---

## 1. Prerequisites

1. RunPod account with credits (you have balance).
2. Docker Desktop installed + logged in to Docker Hub:
   ```bash
   docker login
   ```
3. Hugging Face account (IDM-VTON checkpoints are on HF).
4. Local machine with enough disk (~30–40 GB for build + models).
5. (Optional) `huggingface-cli login` if models are gated.

---

## 2. Understand the worker layout

```
infra/runpod/idm-vton-worker/
  src/handler.py          # RunPod entrypoint
  src/infer.py            # IDM-VTON inference wrapper
  Dockerfile
  requirements.txt
  README.md               # this file (also at docs path below)
```

**Request contract** (what DrapeAI will send):

```json
{
  "input": {
    "person_image": "<base64 jpeg/png>",
    "garment_image": "<base64 jpeg/png>",
    "category": "upper_body",
    "garment_description": "blue cotton kurta"
  }
}
```

`category`: `upper_body` | `lower_body` | `dresses`

**Response:**

```json
{
  "image": "<base64 png>",
  "model": "idm-vton",
  "width": 768,
  "height": 1024
}
```

---

## 3. Fill in inference (one-time)

1. Open `src/infer.py` and follow the `TODO` comments.
2. Clone upstream once while building the image (already in Dockerfile):
   - Repo: `https://github.com/yisol/IDM-VTON`
3. Download checkpoints into the image **or** onto a RunPod **Network Volume** (recommended so the Docker image stays smaller):

From [IDM-VTON HF Space / ckpt](https://huggingface.co/spaces/yisol/IDM-VTON/tree/main/ckpt):

```
ckpt/
  densepose/model_final_162be9.pkl
  humanparsing/parsing_atr.onnx
  humanparsing/parsing_lip.onnx
  openpose/ckpts/body_pose_model.pth
```

Plus diffusion weights from the project README / HF.

**Recommended for cost:** attach a **Network Volume** (~40–80 GB) with `ckpt/` so you don’t rebuild a 20GB+ image every code change.

---

## 4. Build & push the Docker image

Image is based on `fonixteam/idm-vton:pod-v1` (prebuilt IDM-VTON + deps) plus our RunPod handler.

```bash
cd /Users/avinash/Desktop/DrapeAI/infra/runpod/idm-vton-worker

# Local tag (already built in this session as drapeai/idm-vton-worker:v1)
docker build --platform linux/amd64 -t YOURUSER/idm-vton-worker:v1 .
```

### Push to Docker Hub (required for RunPod pull)

```bash
docker login
docker tag drapeai/idm-vton-worker:v1 YOURUSER/idm-vton-worker:v1
docker push YOURUSER/idm-vton-worker:v1
# RunPod image field: docker.io/YOURUSER/idm-vton-worker:v1
```

Do **not** use AWS ECR for this worker.

---

## 4b. Deploy via RunPod GitHub (no local push)

If local Docker Hub is awkward:

1. Push this folder to GitHub (already in DrapeAI: `infra/runpod/idm-vton-worker/`)
2. RunPod → Serverless → **Deploy from a GitHub repository**
3. Dockerfile path: `infra/runpod/idm-vton-worker/Dockerfile`
4. Same GPU / min workers settings as below

Note: RunPod GitHub builds must finish within their time limits; baking huge weights may fail — prefer Network Volume for `ckpt/` + HF cache.

---

## 5. Deploy on RunPod (console steps)

### 5.1 Open Serverless

1. [console.runpod.io](https://console.runpod.io) → left **Serverless**
2. Click **Get started** / **New Endpoint**
3. Choose **Deploy from a Docker image**  
   (Not “Deploy LLM from Hugging Face”, not Hub Pod templates)

### 5.2 Container

1. Container image:
   ```text
   docker.io/YOURNAME/idm-vton-worker:v1
   ```
2. Click **Next**

### 5.3 Configure (critical)

| Field | Set to |
|-------|--------|
| Endpoint type | **Queue** |
| GPU | Enable **24 GB** (and/or 48 GB) — pick **4090** class when selecting |
| **Active workers / Min workers** | **0** |
| Max workers | `1` or `2` for start |
| Idle timeout | 5–10 seconds (default OK) |
| Container disk | ≥ 40 GB if models are baked in |
| Network volume | Attach volume with `ckpt/` if you used that approach |
| Env vars (optional) | `MODEL_DIR=/runpod-volume/ckpt` |

### 5.4 Deploy

1. Click **Deploy Endpoint**
2. Wait until status is ready
3. Copy:
   - **Endpoint ID** (e.g. `xxxxxxxx-xxxx-...`)
   - Create **API key**: Account → **Settings** → API Keys

---

## 6. Test the endpoint

```bash
export RUNPOD_API_KEY="rp_..."
export RUNPOD_ENDPOINT_ID="your-endpoint-id"

# Encode sample images
PERSON_B64=$(base64 -i /Users/avinash/Desktop/DrapeAI/tmp_tryon_test/female_person.jpg | tr -d '\n')
GARMENT_B64=$(base64 -i /Users/avinash/Desktop/DrapeAI/tmp_tryon_test/female_top.jpg | tr -d '\n')

curl -sS "https://api.runpod.ai/v2/${RUNPOD_ENDPOINT_ID}/runsync" \
  -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"input\": {
      \"person_image\": \"${PERSON_B64}\",
      \"garment_image\": \"${GARMENT_B64}\",
      \"category\": \"upper_body\",
      \"garment_description\": \"top from wardrobe\"
    }
  }" | tee /tmp/runpod_vton_out.json
```

- First call may take **several minutes** (cold start + model load).
- Later calls with a warm worker: ~**8–20s**.
- For async (better for DrapeAI jobs): use `/run` then poll `/status/{id}` — see [Send requests](https://docs.runpod.io/serverless/endpoints/send-requests).

Decode result image:

```bash
python3 -c "
import json,base64
d=json.load(open('/tmp/runpod_vton_out.json'))
img=d.get('output',{}).get('image') or d.get('image')
open('/tmp/vton_out.png','wb').write(base64.b64decode(img))
print('wrote /tmp/vton_out.png')
"
```

---

## 7. Cost controls (do these)

1. **Min workers = 0** always for MVP.  
2. Never leave a **Pod** or **Notebook** running “just in case”.  
3. Cache try-on results in DrapeAI (`preview_image_key`) — second view = $0.  
4. Cap daily gens: `TRYON_DAILY_LIMIT_FREE=3`.  
5. Send **one garment** (e.g. top) first; multi-garment = multiple RunPod calls or a later pipeline.

Rough: warm 4090 ~10s ≈ **fractions of a cent** per image; cold starts cost more (worker spin-up time).

---

## 8. Wire into DrapeAI

Already supported in code (`_runpod_tryon`). In `api/.env`:

```bash
TRYON_PROVIDER_PRIMARY=runpod
TRYON_MODEL_PRIMARY=idm-vton
RUNPOD_API_KEY=rp_...
RUNPOD_ENDPOINT_ID=...
RUNPOD_TRYON_TIMEOUT_SEC=300
TRYON_FALLBACK_COMPOSITE=true
TRYON_DAILY_LIMIT_FREE=3

# Optional fallbacks
TRYON_PROVIDER_SECONDARY=gemini
GEMINI_API_KEY=...   # use drapeai Tier 1 project key
```

Restart the API. IDM-VTON uses the **first** garment (category-ordered); multi-piece outfits may need multiple passes later.

---

## 9. Troubleshooting

| Problem | Fix |
|---------|-----|
| OOM / CUDA error | Use 24GB+ GPU; reduce output resolution |
| Cold start timeout | Increase endpoint timeout; use `/run` + poll; optional min workers=1 only during demos |
| 401 from API | Check `Authorization: Bearer` API key |
| Hub Pod template temptation | Ignore for prod; Serverless only |
| Huge image size | Put `ckpt/` on Network Volume |

---

## 10. Checklist

- [ ] Docker image builds for `linux/amd64`
- [ ] Image pushed to Docker Hub
- [ ] Serverless endpoint created from **Docker image**
- [ ] Min workers = **0**
- [ ] GPU 24GB+ selected
- [ ] `runsync` test returns a PNG
- [ ] Test Pods/Notebooks **stopped**
- [ ] Endpoint ID + API key saved for DrapeAI `.env`

---

## Docs index

| Topic | URL |
|-------|-----|
| Serverless overview | https://docs.runpod.io/serverless/overview |
| Quickstart | https://docs.runpod.io/serverless/quickstart |
| Handler functions | https://docs.runpod.io/serverless/workers/handler-functions |
| Dockerfile | https://docs.runpod.io/serverless/workers/create-dockerfile |
| Send requests | https://docs.runpod.io/serverless/endpoints/send-requests |
| IDM-VTON upstream | https://github.com/yisol/IDM-VTON |
