# DrapeAI -- Master Plan

> AI Outfit Assistant for India. Flutter (Android + iOS) + FastAPI + PostgreSQL. Solo build.

---

## Product Thesis

DrapeAI is an India-first AI stylist. Photograph your clothes (or try a demo wardrobe), answer a 5-question style quiz, and get AI-generated outfits -- including ethnic + fusion combos no global app handles. The core loop: **Upload → Tag → Get Outfit → Save / Shuffle**. Everything else stacks on top in later versions.

---

## Scope Decisions (Locked)

**Accepted from expert review:**
- Hybrid AI: rule engine builds candidates → LLM ranks + explains
- 3-upload gratification -- show first outfit after 3rd item upload
- Demo wardrobe (20 items) before any upload
- Pro pricing: Rs 99/month (not Rs 199)
- MVP trimmed: Calendar, Analytics, Cost-per-wear → V1.1

**Added:**
- Photo Guide UI overlay during upload (reduces bad photos → better tags → better outfits)

**Deferred past V1.1:**
- Shareable "AI styled me" cards

---

## Tech Stack

| Layer | Choice |
|---|---|
| Mobile | Flutter (Dart), Riverpod, Dio, GoRouter |
| Backend | FastAPI (Python 3.11), asyncpg |
| Database | PostgreSQL 16 + pgvector |
| Storage | Cloudflare R2 (S3-compatible, no egress) |
| Auth | Firebase Auth (Phone OTP + Google) |
| AI Vision | GPT-4o Vision (tagging, ~$0.03/image) |
| AI Outfit | Rule engine (Python) + GPT-4o ranker |
| BG Removal | rembg (self-hosted, u2net) |
| Embeddings | text-embedding-3-small (1536-dim) |
| Weather | OpenWeatherMap (free tier) |
| Push | Firebase Cloud Messaging |
| Hosting | Hetzner CX22 (EUR 4.50/mo), Docker Compose |
| Payments (V2) | Razorpay |

---

## Roadmap

### MVP (v1.0)

1. Onboarding quiz (5 questions)
2. Photo upload + Photo Guide overlay + AI bg removal + auto-tagging
3. 3-upload gratification loop
4. Demo wardrobe mode
5. Wardrobe grid (filter by category/color/season)
6. AI Daily Outfit Recommendation (3/day, weather + occasion aware)
7. Outfit Shuffle (swipe-based)
8. Lookbooks (save outfits: Work/Weekend/Party/Travel)
9. Ethnic wear support (saree, kurta, lehenga, sherwani, fusion logic)
10. Thumbs up/down feedback on every recommendation

### V1.1 (2-3 weeks post-launch)

- Outfit Calendar + morning push notification
- Cost-per-wear tracker
- Analytics dashboard (most/least worn, wardrobe utilisation %)

### V2.0 (retention + revenue)

- AI Chat Stylist (RAG over wardrobe)
- Personal Color Analysis
- Body Type/Fit recommendations
- Trip Packing Planner
- URL Paste import (Myntra, Ajio)
- Wardrobe Gap Analysis
- Pro tier at Rs 99/mo (free: 50 items, 1 rec/day)

### V3.0 (moat)

- Resale Marketplace
- AI Shopping Advisor (affiliate revenue)
- AR Virtual Try-On
- Indian language UI (Hindi/Tamil/Telugu/Kannada/Bengali)
- Stylist Marketplace
- Brand API integrations

---

## Build Phases

| Phase | Focus |
|---|---|
| 0 - Setup | Flutter + Xcode + Android SDK, Hetzner + R2 + Postgres, repo scaffold |
| 1 - Backend core | Auth, user, preferences, items CRUD, R2 upload, vision tagging |
| 2 - Flutter shell | Auth flow, onboarding quiz, wardrobe grid, camera + Photo Guide |
| 3 - Outfit engine | Rule engine, LLM ranker, generate + shuffle endpoints, demo wardrobe |
| 4 - Outfit UX | Today's outfits, shuffle deck, lookbooks, feedback, 3-upload trigger |
| 5 - Polish + beta | Sentry, analytics events, TestFlight + Play internal testing (20-50 users) |
| 6 - Launch | App Store + Play Store submission, then start V1.1 |

---

## Cost Model (1,000 MAU)

| Item | Monthly |
|---|---|
| Hetzner CX22 | Rs 450 |
| Cloudflare R2 | Rs 150 |
| PostgreSQL (self-hosted) | Rs 0 |
| GPT-4o Vision tagging | Rs 2,400 (amortised) |
| GPT-4o outfit ranking | Rs 1,800 |
| Firebase + FCM + Weather | Rs 0 |
| **Total** | **~Rs 4,800/mo** |

One-time: Google Play $25, Apple Developer $99/yr

---

## Success Metrics

| Stage | Target |
|---|---|
| Closed beta | 30-50 WAU, 60% week-2 retention |
| Public launch | 200-400 downloads month 1 |
| Month 3 | 1,000 MAU, 25% DAU/MAU |
| V2 launch | 50-80 paying users at Rs 99 |
| Month 9 | 5,000 MAU, Pro revenue covers infra |

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Vision tagging errors | Manual edit chips on every item + Photo Guide improves input |
| Bad outfit combos | Rule engine filters before LLM sees candidates |
| GPT cost spike | 24h cache per (user, occasion); spend cap in code |
| Upload friction kills funnel | Demo wardrobe + 3-upload gratification + URL paste in V2 |
| iOS signing pain | Full TestFlight cycle in Phase 2, don't wait for launch |

---

## Documentation Index

Every aspect of this project is documented in detail:

| Document | What it covers |
|---|---|
| [docs/README.md](docs/README.md) | Documentation index and project overview |
| [docs/coding_standards.md](docs/coding_standards.md) | 15 rules: naming, security, error handling, async, Riverpod patterns, git conventions |
| [docs/architecture.md](docs/architecture.md) | System topology, service boundaries, data flows, auth, caching, scaling path |
| [docs/database_schema.md](docs/database_schema.md) | 13 tables with full DDL, indexes, migrations, useful queries |
| [docs/api_reference.md](docs/api_reference.md) | Every endpoint: request/response, rate limits, error codes |
| [docs/ui_ux_spec.md](docs/ui_ux_spec.md) | Design system, typography, spacing, component library, 12 screen specs, animations |
| [docs/ai_pipeline.md](docs/ai_pipeline.md) | Upload pipeline, outfit pipeline, rule engine, LLM ranker, cost control, prompt versioning |
| [docs/deployment.md](docs/deployment.md) | Hetzner setup, Docker Compose, Nginx + TLS, R2, Firebase, CI/CD, backups, monitoring |
| [docs/store_submission.md](docs/store_submission.md) | Play Store + App Store: signing, building, screenshots, listing copy, review guidelines |
| [docs/project_structure.md](docs/project_structure.md) | Exact folder layout for app/ + api/ + infra/, every file explained |
| [docs/environment_setup.md](docs/environment_setup.md) | Dev machine setup: Flutter, Xcode, Android SDK, Python, PostgreSQL, VS Code config |

---

## Day-1 Checklist

- [ ] `flutter doctor` passes for iOS + Android
- [ ] GitHub repo created with `/app`, `/api`, `/infra`, `/docs`
- [ ] Hetzner box + R2 bucket + Postgres provisioned
- [ ] OpenAI API key + spend cap set ($20/mo)
- [ ] Firebase project created + FlutterFire configured
- [ ] FastAPI skeleton with `/health` deployed

- [ ] Flutter app boots with placeholder routes
- [ ] Decide auth provider (Supabase vs Firebase) — recommend **Supabase** since you also get Postgres + storage in one
- [ ] Draft Vision prompt + JSON schema (commit to `/api/prompts/vision_tag.md`)
- [ ] Draft Outfit ranker prompt + JSON schema (commit to `/api/prompts/outfit_rank.md`)
- [ ] Seed 20-item demo wardrobe (your own clothes work fine)

---

## 16. One-Line Summary

**Build the trimmed MVP loop (Upload with Photo Guide → Hybrid AI Outfit → Save/Shuffle) in Flutter + FastAPI, ship to closed beta with 30–50 users, then layer calendar/analytics in v1.1 and monetisation in v2 at ₹99.**

---

## 17. Market path (Jul 2026)

Product is past prototype; public stores still blocked. Execute **[docs/MARKET_LAUNCH_PLAN.md](docs/MARKET_LAUNCH_PLAN.md)**: production hygiene → closed beta → India Play → monetize only after week-2 retention. Do not market try-on or ship Razorpay until retention proof.
