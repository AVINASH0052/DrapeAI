# DrapeAI — Roadmap status

**Last updated:** 2026-07-14

Framing: try-on UX (one saved full-body photo → many outfits → change anytime) is **shipped / polish**, not a new build. Default production quality today is **Gemini / cascade** (composite fallback). **IDM-VTON** is wired but cold-start gated (`workersMin=0` often falls back before finishing).

## Shipped

| Area | Notes |
|------|--------|
| Auth + onboarding | Firebase OTP, preferences |
| Wardrobe | Upload, batch≤10, AI tags, photo guide (garment) |
| Outfits | Rules + LLM, shuffle, feedback |
| Lookbooks / calendar / analytics / gaps | Present |
| Notifications + FCM | Present |
| **Persistent body photo try-on** | `POST/DELETE /me/try-on-photo`, visualize, nudge, quotas, async jobs, input checks, race guards |
| **Try-on photo guide** | Full-body tips overlay before picking (new) |
| **External / shop try-on** | `POST /try-on/external`, history, Flutter `/try-on` (new) |
| Admin API | Present |

## Not done (next market slices)

1. Bulk album / multi-item detect beyond batch 10  
2. Myntra/Ajio URL paste import  
3. Razorpay + Pro ₹99 + hard AI caps by tier  
4. Affiliate “buy the gap”  
5. Whole-wardrobe RAG chat stylist  
6. Vernacular UI  
7. Warm-worker decision for IDM-VTON quality tier  
8. Trip planner / human stylist / resale
