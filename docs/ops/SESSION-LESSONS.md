# Session lessons

Captured from real deploy work so we do not repeat failures.

**Last updated:** 2026-07-14

## Try-on / RunPod / IDM-VTON

1. **Ada GPUs need newer torch**  
   RTX 4090 is compute 8.9. `torch 2.0.1+cu117` has sm_80/sm_86 only → `CUDA error: no kernel image is available for execution on the device`. **Fix:** `torch 2.1.2+cu118` (or newer with Ada) in the worker image (`v9`).

2. **OpenPose / DensePose CUDA extensions are fragile on serverless**  
   Force OpenPose weights + inputs on CPU; DensePose `MODEL.DEVICE=cpu`. Keep diffusion UNet on CUDA.

3. **Base image path assumptions**  
   Upstream images hardcode `/runpod-volume/IDM-VTON/ckpt`. Bake checkpoints to `/opt/idm-ckpt` and patch/symlink so empty network volumes do not hide weights.

4. **`runpod` install can break `cryptography`**  
   Pin compatible cryptography and set `ENTRYPOINT ["python","-u","/app/handler.py"]`.

5. **Cold starts are long**  
   Multi-GB image + HF `yisol/IDM-VTON` download. First job may take 10–15+ minutes. Use `diag: true` handler mode to validate GPU before full try-on.

6. **Workers stuck initializing**  
   Purge queue (`POST …/purge-queue`), set `workersMax: 0` to drain, enlarge container disk if needed, then re-enable. Cancel abandoned jobs.

7. **License**  
   IDM-VTON is **CC BY-NC-SA 4.0**. Do not sell or market as commercial try-on without a different model or license.

8. **API cascade**  
   Keep Gemini / Cloudflare / composite fallbacks so the app still works when RunPod is cold or failing.

## General

- Prefer documenting env vars and runbooks in `docs/` over tribal Slack knowledge.
- When debugging GPU workers, log `device_name` + `capability` + torch version in the worker error path.
