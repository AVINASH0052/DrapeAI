# DrapeAI documentation handbook

Everything you need to **build, run, integrate, deploy, and operate** DrapeAI.  
Deep dives also live under `docs/backend/`, `docs/frontend/`, and each package README.

**Last updated:** 2026-07-14

---

## I am new — start here

1. [GLOSSARY.md](GLOSSARY.md) — terms  
2. [architecture/OVERVIEW.md](architecture/OVERVIEW.md) — system map  
   - [architecture/DECISIONS.md](architecture/DECISIONS.md) — *why* the stack  
   - [architecture.md](architecture.md) — full topology / data flows  
3. [local-development/README.md](local-development/README.md) — run locally  
4. [services/README.md](services/README.md) — what each package does  
5. [rules/AGENTS.md](rules/AGENTS.md) — invariants (read before coding)  
6. [contributing/README.md](contributing/README.md) — PR / review norms  

## By job

| Job | Go to |
|---|---|
| Local setup | [local-development/](local-development/) · [environment_setup.md](environment_setup.md) |
| Deploy / CI | [DEPLOYMENT.md](DEPLOYMENT.md) · [deployment.md](deployment.md) |
| Session lessons / past fixes | [ops/SESSION-LESSONS.md](ops/SESSION-LESSONS.md) |
| Fix production issue | [ops/TROUBLESHOOTING.md](ops/TROUBLESHOOTING.md) |
| Add API / UI / migration / test | [instructions/](instructions/) · [rules/CODING-STANDARDS.md](rules/CODING-STANDARDS.md) |
| Coding rules (must follow) | [rules/CODING-STANDARDS.md](rules/CODING-STANDARDS.md) · [rules/AGENTS.md](rules/AGENTS.md) · [instructions/FOLLOW-THESE.md](instructions/FOLLOW-THESE.md) |
| Firebase / R2 / RunPod / LLM providers | [integrations/](integrations/) |
| Backend deep dive | [backend/](backend/) |
| Flutter deep dive | [frontend/](frontend/) |
| Try-on / IDM-VTON worker | [services/TRYON-WORKER.md](services/TRYON-WORKER.md) · [infra/runpod/idm-vton-worker/README.md](../infra/runpod/idm-vton-worker/README.md) |
| Store submission | [store_submission.md](store_submission.md) |
| Folder layout | [project_structure.md](project_structure.md) |

---

## Folder map

```
docs/
├── README.md                    ← this handbook index
├── GLOSSARY.md
├── DEPLOYMENT.md                ← short CI/CD cheat sheet
├── architecture/                ← overview + decisions
├── architecture.md              ← detailed topology (legacy deep dive)
├── local-development/           ← run apps, env
├── services/                    ← api, app, admin, try-on worker
├── integrations/                ← Firebase, R2, RunPod, AI providers
├── ops/                         ← troubleshooting, session lessons
├── contributing/                ← git + PR norms
├── rules/                       ← AGENTS, coding standards
├── instructions/                ← AI task profiles
├── backend/                     ← FastAPI implementation guides
├── frontend/                    ← Flutter implementation guides
├── project_structure.md
├── environment_setup.md
├── deployment.md                ← long-form deploy guide
└── store_submission.md
```

---

## Packages (source of truth for code)

| Package | Docs |
|---|---|
| `api/` | [backend/](backend/) · [services/BACKEND.md](services/BACKEND.md) |
| `app/` | [frontend/](frontend/) · [services/FRONTEND.md](services/FRONTEND.md) · `app/README.md` |
| `admin/` | [services/ADMIN.md](services/ADMIN.md) |
| `infra/` | [deployment.md](deployment.md) · Compose / Nginx / Redis |
| `infra/runpod/idm-vton-worker/` | package README · [services/TRYON-WORKER.md](services/TRYON-WORKER.md) |

---

## Non-negotiables (short)

1. **User ownership** — every user-scoped query filters by authenticated `user_id`  
2. **No live secrets in git** — `.env` stays local; use `.env.example`  
3. **Parameterized SQL only** — never string-concat SQL  
4. **Async I/O on the API** — no blocking calls on the event loop  
5. **Light theme / no emoji in product UI or logs**  
6. **IDM-VTON is non-commercial** (CC BY-NC-SA 4.0) until licensing changes  

Full list: [rules/AGENTS.md](rules/AGENTS.md).
