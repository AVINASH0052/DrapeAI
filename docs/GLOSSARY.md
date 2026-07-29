# Glossary

| Term | Meaning |
|---|---|
| Wardrobe item | A single clothing photo + AI tags + embedding owned by one user |
| Outfit | Ranked combination of items for an occasion / weather / style |
| Lookbook | Saved collection of outfits |
| Try-on | Virtual garment fit (“See me in this”) via image-gen providers or RunPod IDM-VTON |
| IDM-VTON | Open-source virtual try-on model (CC BY-NC-SA 4.0 — non-commercial) |
| RunPod Serverless | GPU endpoint hosting the IDM-VTON worker (`infra/runpod/idm-vton-worker`) |
| Rule engine | Deterministic filters before LLM ranking (`api/app/services/rule_engine.py`) |
| LLM ranker | GPT-based outfit ranking / explanation (`llm_ranker.py`) |
| Vision tagger | GPT-4o (or alternate) clothing attribute extraction |
| Embedding | `text-embedding-3-small` vector (pgvector) for similarity / pairing |
| ARQ | Async Redis task queue for uploads, try-on jobs, cron |
| R2 | Cloudflare object storage for images (local filesystem in dev) |
| Firebase Auth | Phone OTP + Google + Apple; JWT verified by FastAPI |
| Ownership check | Every user-scoped SQL query filters by `user_id` |
| Composite fallback | Side-by-side collage when all try-on providers fail |
| Admin | Vite React dashboard under `admin/` |
