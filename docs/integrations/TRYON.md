# Virtual try-on integrations

Cascade is Settings-driven (`TRYON_PROVIDER_*`, models, daily limits, async flags).

Providers may include Cloudflare Workers AI, NVIDIA, Gemini, OpenAI image edit, and **RunPod IDM-VTON**.

## Ops

- Worker: [../services/TRYON-WORKER.md](../services/TRYON-WORKER.md)
- Lessons: [../ops/SESSION-LESSONS.md](../ops/SESSION-LESSONS.md)
- Product plan notes: [../DrapeAI-Virtual-TryOn-Implementation-Plan.md](../DrapeAI-Virtual-TryOn-Implementation-Plan.md)

## Product constraint

IDM-VTON weights/code are **non-commercial** (CC BY-NC-SA 4.0). Keep fallbacks for production if licensing blocks IDM-VTON.
