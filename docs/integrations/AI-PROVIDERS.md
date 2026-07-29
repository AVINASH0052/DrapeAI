# AI providers

Configured in `api/app/config.py` and used by:

- Vision tagging / embeddings
- Outfit ranking / chat helpers
- Optional alternate providers (Anthropic, Groq, NVIDIA NIM)

## Rules

- Route spend through existing services and spend-cap Settings
- Mock providers in unit tests
- Prefer changing model names via env, not hardcoding in multiple files
