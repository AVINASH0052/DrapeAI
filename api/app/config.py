"""Central configuration from environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
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

    # OpenWeather (for weather-based outfit suggestions)
    openweather_api_key: str = ""

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "INFO"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        protected_namespaces = ("settings_",)


settings = Settings()
