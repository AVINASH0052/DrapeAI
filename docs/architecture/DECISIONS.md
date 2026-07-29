# Architecture decisions

> Why the current stack. Update when a decision is reversed.

| Decision | Choice | Why |
|---|---|---|
| Backend shape | FastAPI monolith | Early-stage product; one deployable; simpler ops than 3–4 services |
| SQL access | asyncpg + raw SQL | Explicit queries, fast, fits ownership filters; migrations via SQL/Alembic |
| Auth | Firebase Auth | Phone OTP + Google + Apple without running an IdP |
| Mobile | Flutter | One codebase for Android + iOS; Riverpod + GoRouter already standardized |
| Vectors | pgvector | Keep embeddings next to relational data; avoid early need for a separate vector DB |
| Images | Cloudflare R2 | S3-compatible, egress-friendly; local FS in development |
| Queue | Redis + ARQ | Same Redis as rate limiting; Python-native async workers |
| Outfit quality | Rules then LLM | Cheap deterministic filters before spent LLM ranking |
| Try-on | Provider cascade + optional RunPod IDM-VTON | Accuracy vs cost; NC license on IDM-VTON must be respected commercially |
| Admin | Separate Vite app | Keep ops UI out of the consumer Flutter binary |
| Deploy | Docker Compose → Swarm | Fits current hosting docs; rolling updates without Kubernetes yet |

## Rejected (for now)

- Microservices split (platform / AI / business) — premature
- Keycloak / Kong — Firebase + Nginx enough at current scale
- Always-on GPU pod for try-on — Serverless scale-to-zero preferred for cost

See also [../architecture.md](../architecture.md) and Multi-tenant-style ops notes in [../ops/SESSION-LESSONS.md](../ops/SESSION-LESSONS.md).
