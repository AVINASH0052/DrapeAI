# DrapeAI — Market Launch Plan

> Goal: closed beta → Play Store (India) → retention proof → monetize.  
> Constraint: solo founder. Prefer shipping the core loop over new features.  
> Source: product readiness review (Jul 2026). Master product roadmap remains [PLAN.md](../PLAN.md).

---

## Verdict we are executing against

- **Public market:** not ready
- **Closed beta:** ready once Phase 0–1 blockers below are cleared
- **Do not build yet:** Razorpay, AR try-on marketing, resale, multilingual UI, stylist marketplace

Success is not “more screens.” Success is:

1. A stranger can get a good outfit without you in the room  
2. They come back in week 2  
3. Stores will accept the build

---

## North-star metrics

| Stage | Metric | Target | Kill criterion |
|---|---|---|---|
| Closed beta | Invited WAU | 30–50 | — |
| Funnel | % who generate ≥1 outfit (demo or own) | ≥70% of installs | <40% after 2 weeks of fixes → rethink onboarding |
| Habit | Week-2 retention | ≥40% | <20% → do not launch public / do not add Pro |
| Quality | Thumbs-up rate on outfits | ≥45% | <25% → fix rule engine + prompts before growth |
| Public M1 | Play downloads (India) | 200–400 | — |
| M3 | MAU | ~1,000 | — |

Instrument these before inviting beta users (Firebase Analytics or equivalent events listed in Phase 1).

---

## Scope rules

**In scope for launch path**

- Production hygiene (API URL, strip dev bypass, Android Firebase)
- Demo wardrobe that works offline of your laptop
- Hosted privacy / terms / support
- Core loop QA (upload → tag → outfit → shuffle → save)
- Outfit quality tests + ethnic combo spot-checks
- Play internal testing → India public Play
- Morning habit + retention (already partly built; keep it working)

**Explicitly out of scope until week-2 retention ≥40%**

- Virtual try-on as a marketed feature (keep code, hide or soft-gate)
- New AI features (color analysis, packing planner polish as launch hero)
- Payments / Pro paywall
- iOS App Store (after Play proof, unless you already have TestFlight cohort)
- Hindi/Tamil UI
- Share cards, marketplace, brand APIs

---

## Phase 0 — Production foundation (unblocks everything)

**Outcome:** Beta APK/IPA points at a stable API; auth is real; demo clothes load.

| # | Task | Where | Done when |
|---|---|---|---|
| 0.1 | Confirm Hetzner + Docker Compose prod + TLS for `api.drapeai.app` | `infra/`, `docs/deployment.md` | `GET https://api.drapeai.app/health` returns 200 |
| 0.2 | R2 bucket has all `demo/*.png` keys used in seed | `api/app/services/demo_wardrobe.py` (`DEMO_ITEMS`) | Activate demo → every item thumbnail loads |
| 0.3 | Script or checklist to upload/regenerate missing demo assets | `api/scripts/` or `docs/` | Repeatable without manual SSH guesswork |
| 0.4 | Production `.env` complete (OpenAI/fallback keys, Firebase, R2, Sentry, Redis, DB) | server secrets | Outfit generate works on prod for a test user |
| 0.5 | OpenAI (or primary LLM) spend cap | provider dashboard | Hard monthly ceiling set |

**Risk:** Demo items reference R2 keys with no binaries in repo — first-run looks broken if Phase 0.2 is skipped.

---

## Phase 1 — Client release hygiene (store + beta safe)

**Outcome:** No ngrok default, no “skip for now (dev)” in release, Android can auth.

| # | Task | Where | Done when |
|---|---|---|---|
| 1.1 | Remove hardcoded ngrok fallback; fail loudly if `API_BASE_URL` missing in release | `app/lib/core/constants/environment.dart` | Release build uses `API_PROD_URL` / dart-define only |
| 1.2 | Gate `devBypass` + “skip for now (dev)” behind `kDebugMode` / flavor | `auth_screen.dart`, `auth_provider.dart` | Invisible in profile/release |
| 1.3 | Add real Android Firebase config | `google-services.json` + `firebase_options.dart` Android `appId` | Phone/Google sign-in works on a physical Android device |
| 1.4 | Release build flags documented | `app/README.md` | One copy-paste command for beta APK with prod API |
| 1.5 | Analytics events | Flutter | Fire: `signup`, `onboarding_complete`, `demo_activate`, `item_upload`, `outfit_generate`, `outfit_feedback`, `lookbook_save`, `day2_open` |
| 1.6 | Crash reporting | Sentry (already wired backend; confirm Flutter) | Force a test crash appears in dashboard |
| 1.7 | Strip or soft-hide try-on / experimental entry points from primary CTA | outfit visualize sheet / nav | Beta testers land on Today → Shuffle, not broken VTO |

---

## Phase 2 — Legal + trust surfaces (Play/App Store hard requirement)

**Outcome:** Live URLs Apple/Google can open; in-app links match.

| # | Task | Where | Done when |
|---|---|---|---|
| 2.1 | Minimal static site: landing, privacy, terms, support | Cloudflare Pages / GitHub Pages on `drapeai.app` | All four URLs return 200 |
| 2.2 | Privacy must disclose OpenAI image processing | copy from `docs/store_submission.md` §6 | Accurate third-party list |
| 2.3 | Point in-app Terms/Privacy to hosted URLs (keep local screens or WebView) | `legal_screens.dart` / profile links | Match store listing URLs |
| 2.4 | Support email monitored | e.g. `support@drapeai.app` | Reply within 48h during beta |

---

## Phase 3 — Core loop quality gate (product truth)

**Outcome:** You would recommend the app to a friend for “what do I wear today?”

| # | Task | Where | Done when |
|---|---|---|---|
| 3.1 | Integration test: seed wardrobe → `POST /outfits/generate` → 3 outfits, valid item_ids | `api/tests/` | CI-green test, not only `/today` auth |
| 3.2 | Integration test: shuffle + feedback updates preferences path | `api/tests/` | Feedback recorded |
| 3.3 | Ethnic fixture cases (kurta+jeans allowed; sherwani+jeans blocked/scored low) | rule engine tests | Assertions match `ETHNIC_*` tables |
| 3.4 | Manual script: 10 Indian occasions (office, college, festive, monsoon outing…) | Notion/sheet | ≥7/10 “I’d wear this” from you or 2 friends |
| 3.5 | Photo Guide still shown; tag review editable | Flutter wardrobe flow | Bad tags correctable in <10s |
| 3.6 | Empty / error states never silent | lookbooks + today | User sees retry, not blank |
| 3.7 | Re-enable lightweight CI | `.github/workflows/` | `pytest` + `flutter test` on PR |

**Do not expand features in this phase.** If quality fails, fix prompts/`rule_engine.py`/caching only.

---

## Phase 4 — Closed beta (India)

**Outcome:** Evidence, not opinions.

| # | Task | Done when |
|---|---|---|
| 4.1 | Play Console internal testing track + 20–50 emails | Testers install without store listing |
| 4.2 | Optional TestFlight (if iOS cohort already exists) | Same prompt script |
| 4.3 | Beta brief: “Use Demo Wardrobe first, then upload 5 own items, rate outfits 7 days” | Shared once |
| 4.4 | Mix: college + young working; men + women; ethnic wear owners | Not only friends who won’t criticize |
| 4.5 | Weekly review of thumbs + open feedback | Decisions logged |
| 4.6 | Fix only P0 crashes and “outfits are nonsense” | Resists feature requests |

**Exit criteria for Phase 5:** week-2 retention ≥40% **or** clear plan fixing why not, plus thumbs-up ≥45%.

---

## Phase 5 — Public Play Store (India only first)

Use [store_submission.md](store_submission.md). Short checklist:

| # | Task | Done when |
|---|---|---|
| 5.1 | Icon, 6 screenshots, feature graphic from real builds | Assets ready |
| 5.2 | Listing: ethnic/fusion + owned wardrobe (no VTO hero claims) | Copy honest |
| 5.3 | Data safety / privacy URLs | Form complete |
| 5.4 | Staged rollout 20% → 50% → 100% | Crash-free 24h each step |
| 5.5 | Monitor: crash-free sessions, Outfit generate success rate, upload failures | Dashboards live |

Defer App Store until Play shows non-zero week-2 retention from cold users (not just your invite list).

---

## Phase 6 — Retention → revenue (only after proof)

Aligns with PLAN.md V2, but gated:

| Gate | Then build |
|---|---|
| Week-2 retention ≥40% | Push morning “Today’s outfits” reliability polish |
| Upload drop-off >50% before 5 items | Prioritize **URL paste / Myntra-Ajio import** over new AI toys |
| Thumbs-up ≥45% and MAU ≥500 | Razorpay Pro ₹99: free = demo + limited recs; Pro = unlimited + gaps |
| Clear “what should I buy” demand | Affiliate on gap recommendations |
| Brands ask | B2B styling widget (Stylz Sense–style) — later |

---

## Workstream map (what to implement in repo)

### A. Code changes (implement next)

1. `environment.dart` — no ngrok in mobile defaults  
2. Auth — debug-only bypass  
3. Firebase Android real config (requires your Firebase console export — cannot invent `google-services.json`)  
4. Demo asset bootstrap script + verify endpoint or admin check  
5. Outfit generate/shuffle/ethnic pytest coverage  
6. CI workflow restoring tests  
7. Soft-gate try-on in UI for release flavor  
8. Analytics event constants + fires at key actions  

### B. Outside-repo (you / ops)

1. Domain DNS + Pages for privacy/terms  
2. Play Console + signing keystore  
3. R2 upload of demo PNGs  
4. Beta recruiter list (college WhatsApp, friends of friends)  
5. Apple Developer only when starting iOS public  

### C. Explicit non-goals this cycle

- IDM-VTON production hardening as launch dependency  
- Expanding onboarding past what you have  
- Admin dashboard polish  
- Multi-language  

---

## Suggested execution order for the next agent / coding session

Do these in one vertical slice before anything else:

1. Phase 1.1 + 1.2 (release hygiene in Flutter)  
2. Phase 3.1–3.3 (backend outfit quality tests)  
3. Phase 1.7 (CI)  
4. Phase 0.2–0.3 (demo asset script; document R2 upload)  
5. Phase 2.1 skeleton (static privacy/terms markdown → Pages)  
6. Stop and run a personal dogfood week on prod  

Firebase `google-services.json` and live DNS need your accounts — agent can stub docs and wiring, not create Google/Apple accounts for you.

---

## One-line strategy

**Prove ethnic-aware daily outfits from a demo + small personal wardrobe with India beta users; then Play Store; monetize only after retention.** Everything else is noise until those metrics move.
