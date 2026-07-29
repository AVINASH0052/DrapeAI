"""Central configuration from environment variables."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        protected_namespaces=("settings_",),
        extra="ignore",
    )

    environment: str = "development"
    debug: bool = False

    # Database
    database_url: str = "postgresql://drapeai:drapeai@localhost:5432/drapeai"

    # OpenAI
    openai_api_key: str = ""
    openai_model_vision: str = "gpt-4o"
    openai_model_ranker: str = "gpt-4o"
    openai_model_embedding: str = "text-embedding-3-small"
    openai_spend_cap_usd: float = 15.0

    # Anthropic (Claude)
    anthropic_api_key: str = ""
    anthropic_spend_cap_usd: float = 10.0

    # NVIDIA NIM (free tier — build.nvidia.com).
    # Reads NVIDIA_API_KEY env var.
    nvidia_api_key: str = ""
    nvidia_nim_base_url: str = "https://integrate.api.nvidia.com/v1"

    # Groq (free tier — groq.com)
    groq_api_key: str = ""
    groq_base_url: str = "https://api.groq.com/openai/v1"

    # Google Gemini (primary image generation / editing for outfit try-on)
    gemini_api_key: str = ""
    gemini_base_url: str = "https://generativelanguage.googleapis.com/v1beta"

    # Outfit try-on image generation, with Gemini first.
    tryon_provider_primary: str = "gemini"
    tryon_model_primary: str = "gemini-2.5-flash-image"
    tryon_provider_secondary: str = "cloudflare"
    tryon_model_secondary: str = "@cf/black-forest-labs/flux-2-klein-9b"
    tryon_provider_tertiary: str = "nvidia"
    tryon_model_tertiary: str = "qwen/qwen-image-edit"
    tryon_provider_quaternary: str = "openai"
    tryon_model_quaternary: str = "gpt-image-1"
    tryon_fallback_composite: bool = True
    tryon_image_size: str = "1024x1536"       # OpenAI: 1024x1024 | 1024x1536 | 1536x1024
    tryon_image_quality: str = "medium"       # OpenAI: low | medium | high
    tryon_prompt_version: str = "wardrobe_v1"
    tryon_daily_limit_free: int = 5
    tryon_job_timeout_sec: int = 120
    tryon_async: bool = True
    tryon_enabled: bool = True
    tryon_input_check_enabled: bool = True
    tryon_cloudflare_width: int = 1024
    tryon_cloudflare_height: int = 1536

    # RunPod Serverless (IDM-VTON or custom try-on worker)
    runpod_api_key: str = ""
    runpod_endpoint_id: str = ""
    runpod_tryon_timeout_sec: int = 300

    # Cloudflare Workers AI (try-on primary). Account ID often matches R2.
    cloudflare_account_id: str = ""
    cloudflare_api_token: str = ""

    # Optional self-hosted NVIDIA Visual GenAI NIM URL (else uses integrate API)
    nvidia_visual_genai_url: str = ""

    # Per-role model selection (override via env).
    # Default: NVIDIA Kimi K2.6 — free, multimodal (image+text), good quality.
    # Nemotron Nano Omni: NVIDIA NIM's multimodal model for clothing tagging.
    # Kimi K2.6 stays as fallback. (qwen/qwen-image is for image GENERATION,
    # not understanding — would be the right pick for a future "generate
    # outfit visualization" feature, not for tagging uploaded photos.)
    model_vision_primary: str = "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning"
    model_vision_secondary: str = "moonshotai/kimi-k2.6"
    model_vision_tertiary: str = "gpt-4o"
    model_rank_primary: str = "moonshotai/kimi-k2.6"
    model_rank_secondary: str = "claude-haiku-4-5"
    model_rank_tertiary: str = "gpt-4o-mini"
    model_chat_primary: str = "moonshotai/kimi-k2.6"
    model_chat_secondary: str = "llama-3.3-70b-versatile"   # Groq
    model_chat_tertiary: str = "claude-haiku-4-5"
    model_embed_primary: str = "nvidia/nv-embedqa-e5-v5"
    model_embed_secondary: str = "text-embedding-3-small"
    model_reason_primary: str = "moonshotai/kimi-k2.6"
    model_reason_secondary: str = "claude-sonnet-4-6"
    model_reason_tertiary: str = "gpt-4o"

    # Cloudflare R2
    r2_account_id: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket_name: str = "drapeai-images"
    r2_public_url: str = ""

    # Firebase
    firebase_project_id: str = ""

    # Sentry
    sentry_dsn: str = ""

    # Redis (rate limiter, task queue, caching)
    redis_url: str = "redis://localhost:6379/0"

    # Weather: uses Open-Meteo (free, no API key required)

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "INFO"


settings = Settings()
