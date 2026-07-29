# Troubleshooting

## API won’t start

- Check `DATABASE_URL` / Redis reachable
- Confirm `.env` loaded from `api/`
- Look for missing Firebase credentials when auth routes are hit

## Flutter can’t reach API

- Simulator: `localhost` OK; physical device needs machine LAN IP
- CORS / cleartext HTTP settings for Android
- Auth interceptor: expired Firebase token → re-login

## Vision tagging fails

- OpenAI (or configured) key + spend cap
- Image validation rejecting HEIC / oversized files
- ARQ worker not running → jobs stuck queued

## Try-on fails / slow

See [SESSION-LESSONS.md](SESSION-LESSONS.md) and [../services/TRYON-WORKER.md](../services/TRYON-WORKER.md).

Quick checks:

1. `TRYON_PROVIDER_*` and keys set  
2. RunPod health: workers initializing vs ready vs throttled  
3. Cold start timeout vs `RUNPOD_TRYON_TIMEOUT_SEC`  
4. `CUDA error: no kernel image` → torch / GPU arch mismatch (need Ada-capable torch on 4090)

## Admin 401

- Not using admin credentials / custom claims as implemented in `api/app/auth`
