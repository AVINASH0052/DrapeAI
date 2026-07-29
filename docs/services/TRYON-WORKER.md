# Try-on worker (RunPod IDM-VTON)

Package: `infra/runpod/idm-vton-worker/`  
Detailed ops: package [README](../../infra/runpod/idm-vton-worker/README.md) · [../ops/SESSION-LESSONS.md](../ops/SESSION-LESSONS.md)

## Role

Optional GPU Serverless worker for higher-fidelity virtual try-on (`avivamp00/idm-vton-worker` images). DrapeAI API calls RunPod `/run` or `/runsync` when `TRYON_PROVIDER_PRIMARY=runpod`.

## Current working baseline (2026-07)

| Item | Value |
|---|---|
| Image tag | `avivamp00/idm-vton-worker:v9` (torch 2.1.2+cu118 — Ada + Ampere) |
| Endpoint | configured via `RUNPOD_ENDPOINT_ID` |
| GPU pools | `ADA_24,AMPERE_24,AMPERE_48` |
| Handler | `src/handler.py` (`diag` mode + try-on) |
| Inference | `src/infer.py` — OpenPose/DensePose CPU; diffusion CUDA |

## Hard constraints

1. **License:** IDM-VTON is **CC BY-NC-SA 4.0** (non-commercial).
2. **Arch mismatch:** torch 2.0.1+cu117 lacks Ada (sm_89 / 8.9) → `no kernel image`. Keep torch ≥ 2.1.2+cu118 if using Ada (4090, etc.).
3. Cold start can exceed 10–15 minutes (image pull + HF weights). Size timeouts accordingly.
4. Prefer `ALLOW_STUB=0` in production templates.

## API wiring

- `api/app/services/image_gen_provider.py` — `_runpod_tryon`
- Settings: `runpod_api_key`, `runpod_endpoint_id`, `runpod_tryon_timeout_sec`
- Cascade still allows Gemini / Cloudflare / composite fallbacks

## Local image build (amd64)

```bash
cd infra/runpod/idm-vton-worker
docker build --platform linux/amd64 -t YOURUSER/idm-vton-worker:vN .
docker push YOURUSER/idm-vton-worker:vN
```

Update RunPod template `imageName`, drain workers, then smoke with `diag: true` before full try-on.
