"""Central configuration from environment variables."""

from __future__ import annotations

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

    # Comma-separated browser origins allowed in production.
    # Development allows any origin.
    cors_origins: str = "https://sugatai.com,https://www.sugatai.com,https://app.sugatai.com"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

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

    # Monthly spend caps, USD, per provider. Every provider that can bill must
    # have one — an uncapped provider is an uncapped invoice. Image generation
    # is the expensive path, so gemini/cloudflare/runpod/openai matter most.
    # NVIDIA and Groq are free-tier today; the caps are cheap insurance in case
    # that changes or a paid key is swapped in.
    gemini_spend_cap_usd: float = 20.0
    # Vertex AI (Gemini on Google Cloud billing / starter credits)
    vertex_spend_cap_usd: float = 25.0
    cloudflare_spend_cap_usd: float = 10.0
    runpod_spend_cap_usd: float = 15.0
    nvidia_spend_cap_usd: float = 5.0
    groq_spend_cap_usd: float = 5.0

    # Google Cloud / Vertex AI (service account JSON via ADC)
    google_cloud_project: str = ""
    google_cloud_location: str = "us-central1"
    google_application_credentials: str = ""
    # Latest image model available on Vertex for this project (verified live).
    vertex_model_image: str = "gemini-2.5-flash-image"
    vertex_model_image_hd: str = "gemini-2.5-flash-image"

    # Ceiling across all providers combined, as a backstop against a provider
    # name that has no cap of its own (e.g. one added later).
    total_spend_cap_usd: float = 60.0

    # NVIDIA NIM (free tier — build.nvidia.com).
    # Reads NVIDIA_API_KEY env var.
    nvidia_api_key: str = ""
    nvidia_nim_base_url: str = "https://integrate.api.nvidia.com/v1"

    # Groq (free tier — groq.com)
    groq_api_key: str = ""
    groq_base_url: str = "https://api.groq.com/openai/v1"

    # Google Gemini (wardrobe detect/tag + image extract / try-on)
    gemini_api_key: str = ""
    gemini_base_url: str = "https://generativelanguage.googleapis.com/v1beta"
    # Newer API keys cannot call retired 2.x flash text models (404).
    gemini_model_vision: str = "gemini-3.5-flash"
    gemini_model_image: str = "gemini-2.5-flash-image"
    # HD quality uses the same model until Vertex/Gemini expose a newer image ID.
    gemini_model_image_hd: str = "gemini-2.5-flash-image"

    # Outfit try-on image generation: Vertex (Cloud credits) first.
    tryon_provider_primary: str = "vertex"
    tryon_model_primary: str = "gemini-2.5-flash-image"
    tryon_provider_secondary: str = "gemini"
    tryon_model_secondary: str = "gemini-2.5-flash-image"
    tryon_provider_tertiary: str = "cloudflare"
    tryon_model_tertiary: str = "@cf/black-forest-labs/flux-2-klein-9b"
    tryon_provider_quaternary: str = "nvidia"
    tryon_model_quaternary: str = "qwen/qwen-image-edit"
    tryon_fallback_composite: bool = True
    tryon_image_size: str = "1024x1536"       # OpenAI: 1024x1024 | 1024x1536 | 1536x1024
    tryon_image_quality: str = "high"         # OpenAI: low | medium | high — always HD
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
    # Wardrobe vision (detect + tag) prefers Gemini; NVIDIA/OpenAI are fallbacks.
    model_vision_primary: str = "gemini-3.5-flash"
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

    # Private image URL lifetime (seconds). Clients refresh on the next list fetch.
    signed_url_ttl_sec: int = 3600


VALID_ENVIRONMENTS = {"development", "staging", "production"}
_LOCAL_HOSTS = {"localhost", "127.0.0.1", "0.0.0.0", "::1"}


def _has_ai_path(s: Settings) -> bool:
    if s.gemini_api_key or s.openai_api_key:
        return True
    if s.google_cloud_project and (
        s.google_application_credentials or s.gemini_api_key
    ):
        return True
    if s.cloudflare_account_id and s.cloudflare_api_token:
        return True
    if s.runpod_api_key and s.runpod_endpoint_id:
        return True
    return False


def production_settings_errors(s: Settings) -> list[str]:
    """Return why this config must not serve production traffic. Empty = ok."""
    errors: list[str] = []
    if not s.firebase_project_id:
        errors.append("FIREBASE_PROJECT_ID is required in production.")
    if not s.database_url:
        errors.append("DATABASE_URL is required in production.")
    if not s.redis_url:
        errors.append("REDIS_URL is required in production.")
    if not (s.r2_account_id and s.r2_access_key_id and s.r2_secret_access_key):
        errors.append("R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, and R2_SECRET_ACCESS_KEY are required.")
    if not s.r2_bucket_name:
        errors.append("R2_BUCKET_NAME is required in production.")
    if "*" in s.cors_origin_list:
        errors.append("CORS_ORIGINS must not contain '*' in production.")
    for origin in s.cors_origin_list:
        host = origin.split("://", 1)[-1].split("/", 1)[0].split(":")[0].lower()
        if host in _LOCAL_HOSTS:
            errors.append(f"CORS_ORIGINS must not include a local origin ({origin}).")
    if not _has_ai_path(s):
        errors.append(
            "Production needs at least one AI path: GEMINI_API_KEY, Vertex "
            "(GOOGLE_CLOUD_PROJECT + credentials), CLOUDFLARE_*, or RUNPOD_*."
        )
    for name, cap in (
        ("OPENAI_SPEND_CAP_USD", s.openai_spend_cap_usd),
        ("ANTHROPIC_SPEND_CAP_USD", s.anthropic_spend_cap_usd),
        ("GEMINI_SPEND_CAP_USD", s.gemini_spend_cap_usd),
        ("VERTEX_SPEND_CAP_USD", s.vertex_spend_cap_usd),
        ("CLOUDFLARE_SPEND_CAP_USD", s.cloudflare_spend_cap_usd),
        ("RUNPOD_SPEND_CAP_USD", s.runpod_spend_cap_usd),
        ("NVIDIA_SPEND_CAP_USD", s.nvidia_spend_cap_usd),
        ("GROQ_SPEND_CAP_USD", s.groq_spend_cap_usd),
        ("TOTAL_SPEND_CAP_USD", s.total_spend_cap_usd),
    ):
        if cap <= 0:
            errors.append(f"{name} must be > 0 (uncapped providers are refused).")
    if s.tryon_daily_limit_free < 0:
        errors.append("TRYON_DAILY_LIMIT_FREE must be >= 0.")
    if s.tryon_job_timeout_sec <= 0:
        errors.append("TRYON_JOB_TIMEOUT_SEC must be > 0.")
    if s.signed_url_ttl_sec <= 0:
        errors.append("SIGNED_URL_TTL_SEC must be > 0.")
    return errors


def validate_boot_settings(s: Settings, *, require_production: bool) -> None:
    """Refuse to boot on a misconfigured ENVIRONMENT or production secrets gap."""
    env = s.environment
    if env not in VALID_ENVIRONMENTS:
        raise RuntimeError(
            f"ENVIRONMENT={env!r} is not one of {sorted(VALID_ENVIRONMENTS)}. "
            "Refusing to start rather than guess."
        )
    if require_production and env != "production":
        raise RuntimeError(
            f"REQUIRE_PRODUCTION is set but ENVIRONMENT={env!r}. This host would "
            "accept the 'test-token' auth bypass and serve permissive CORS. "
            "Refusing to start."
        )
    if env == "production":
        errors = production_settings_errors(s)
        if errors:
            raise RuntimeError("Invalid production configuration:\n- " + "\n- ".join(errors))


settings = Settings()
