"""Multi-provider AI abstraction with automatic failover.

Roles route to a priority list of providers. Each provider exposes the same
async interface (chat / vision / embed). Failures (rate limit, network, budget
cap) automatically advance to the next provider. If all providers fail, the
caller can use a rules-based fallback.

Providers supported:
- OpenAI (gpt-4o, gpt-4o-mini, text-embedding-3-small)
- Anthropic (claude-sonnet-4-6, claude-haiku-4-5)
- NVIDIA NIM (free tier — meta/llama-3.3-70b-instruct, vision, embeddings)
- Groq (free tier — fast llama-3.3-70b inference)

The provider list per role is configured in app.config.Settings. Spend tracking
goes through cost_tracker.track_provider_spend() which writes per-provider line
items to analytics_daily.
"""

from __future__ import annotations

import asyncio
import base64
import json
import logging
from dataclasses import dataclass
from enum import Enum
from typing import Any, Awaitable, Callable, Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

# ─── Shared httpx client (connection pooling) ─────────────────────────────────
# Re-uses TCP connections and TLS sessions across all AI calls.
# Saves ~200-400ms per request (no repeated TLS handshake).
_http_client: httpx.AsyncClient | None = None


def get_http_client() -> httpx.AsyncClient:
    """Get or lazily create the shared httpx client."""
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(
            limits=httpx.Limits(
                max_connections=50,
                max_keepalive_connections=20,
            ),
            timeout=httpx.Timeout(60.0, connect=10.0),
            follow_redirects=True,
        )
    return _http_client


async def close_http_client() -> None:
    """Close the shared client. Call from lifespan shutdown."""
    global _http_client
    if _http_client and not _http_client.is_closed:
        await _http_client.aclose()
        _http_client = None
        logger.info("Shared httpx client closed")


class Role(str, Enum):
    VISION = "vision"
    RANK = "rank"
    CHAT = "chat"
    EMBED = "embed"
    REASON = "reason"


@dataclass
class ProviderCall:
    """Result of a single provider call."""
    text: str
    model: str
    provider: str
    tokens_in: int = 0
    tokens_out: int = 0
    cost_usd: float = 0.0


# ─── Price table (USD per 1K tokens) ──────────────────────────────────────────
PRICES = {
    "gpt-4o":                        (0.0025, 0.010),
    "gpt-4o-mini":                   (0.00015, 0.0006),
    "claude-sonnet-4-6":             (0.003, 0.015),
    "claude-haiku-4-5":              (0.0008, 0.004),
    "text-embedding-3-small":        (0.00002, 0),
    # Free providers
    "meta/llama-3.3-70b-instruct":   (0, 0),
    "meta/llama-3.2-90b-vision-instruct": (0, 0),
    "llama-3.3-70b-versatile":       (0, 0),
    "nvidia/nv-embedqa-e5-v5":       (0, 0),
    "moonshotai/kimi-k2.6":          (0, 0),
    "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning": (0, 0),
}


def _calc_cost(model: str, tokens_in: int, tokens_out: int) -> float:
    p_in, p_out = PRICES.get(model, (0, 0))
    return (tokens_in * p_in + tokens_out * p_out) / 1000


# ─── Base provider ────────────────────────────────────────────────────────────
class BaseProvider:
    name: str = "base"

    async def chat(self, prompt: str, *, max_tokens: int = 800, temp: float = 0.3,
                   model: Optional[str] = None) -> ProviderCall:
        raise NotImplementedError

    async def vision(self, image_bytes: bytes, prompt: str, *, mime: str = "image/png",
                     model: Optional[str] = None) -> ProviderCall:
        raise NotImplementedError

    async def embed(self, text: str, *, model: Optional[str] = None) -> list[float]:
        raise NotImplementedError


# ─── OpenAI provider (also handles NVIDIA NIM + Groq — they're OpenAI-compatible) ──
class OpenAICompatProvider(BaseProvider):
    def __init__(self, name: str, api_key: str, base_url: str):
        self.name = name
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")

    async def chat(self, prompt: str, *, max_tokens: int = 800, temp: float = 0.3,
                   model: Optional[str] = None) -> ProviderCall:
        if not self.api_key:
            raise RuntimeError(f"{self.name} api key not configured")
        model = model or "gpt-4o"
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": temp,
        }
        client = get_http_client()
        r = await client.post(
            f"{self.base_url}/chat/completions",
            headers={"Authorization": f"Bearer {self.api_key}",
                     "Content-Type": "application/json"},
            json=payload,
        )
        r.raise_for_status()
        data = r.json()
        text = data["choices"][0]["message"]["content"].strip()
        usage = data.get("usage", {})
        t_in = usage.get("prompt_tokens", 0)
        t_out = usage.get("completion_tokens", 0)
        return ProviderCall(text=text, model=model, provider=self.name,
                            tokens_in=t_in, tokens_out=t_out,
                            cost_usd=_calc_cost(model, t_in, t_out))

    async def vision(self, image_bytes: bytes, prompt: str, *, mime: str = "image/png",
                     model: Optional[str] = None) -> ProviderCall:
        if not self.api_key:
            raise RuntimeError(f"{self.name} api key not configured")
        model = model or "gpt-4o"
        b64 = base64.b64encode(image_bytes).decode("ascii")

        is_nemotron = "nemotron" in model

        payload: dict[str, Any] = {
            "model": model,
            "messages": [{
                "role": "user",
                "content": [
                    {"type": "image_url",
                     "image_url": {"url": f"data:{mime};base64,{b64}"}},
                    {"type": "text", "text": prompt},
                ],
            }],
            "max_tokens": 4096 if is_nemotron else 800,
            "temperature": 0.6 if is_nemotron else 0.1,
            "top_p": 0.95 if is_nemotron else 1.0,
            "stream": True,
        }
        if is_nemotron:
            # Enable thinking for better clothing analysis; budget caps reasoning tokens
            payload["chat_template_kwargs"] = {"enable_thinking": True}
            payload["reasoning_budget"] = 16384

        text_parts: list[str] = []
        t_in = t_out = 0

        # Vision uses streaming — need a separate client with longer timeout
        async with httpx.AsyncClient(timeout=httpx.Timeout(180.0, connect=10.0)) as stream_client:
            async with stream_client.stream(
                "POST",
                f"{self.base_url}/chat/completions",
                headers={"Authorization": f"Bearer {self.api_key}",
                         "Content-Type": "application/json"},
                json=payload,
            ) as response:
                response.raise_for_status()
                async for line in response.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    data_str = line[6:]
                    if data_str.strip() == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data_str)
                    except json.JSONDecodeError:
                        continue
                    # Collect usage from any chunk that carries it
                    usage = chunk.get("usage") or {}
                    if usage:
                        t_in = usage.get("prompt_tokens", t_in)
                        t_out = usage.get("completion_tokens", t_out)
                    choices = chunk.get("choices")
                    if not choices:
                        continue
                    delta = choices[0].get("delta", {})
                    # Only accumulate content — skip reasoning_content
                    content = delta.get("content")
                    if content:
                        text_parts.append(content)

        text = "".join(text_parts).strip()
        return ProviderCall(text=text, model=model, provider=self.name,
                            tokens_in=t_in, tokens_out=t_out,
                            cost_usd=_calc_cost(model, t_in, t_out))

    async def embed(self, text: str, *, model: Optional[str] = None) -> list[float]:
        if not self.api_key:
            raise RuntimeError(f"{self.name} api key not configured")
        model = model or "text-embedding-3-small"
        payload: dict[str, Any] = {"model": model, "input": text}
        # NVIDIA NIM embedding models require input_type; OpenAI ignores it
        if self.name == "nvidia":
            payload["input_type"] = "query"
            payload["encoding_format"] = "float"
        client = get_http_client()
        r = await client.post(
            f"{self.base_url}/embeddings",
            headers={"Authorization": f"Bearer {self.api_key}",
                     "Content-Type": "application/json"},
            json=payload,
        )
        r.raise_for_status()
        data = r.json()
        return data["data"][0]["embedding"]


# ─── Anthropic provider ───────────────────────────────────────────────────────
class AnthropicProvider(BaseProvider):
    name = "anthropic"

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.anthropic.com/v1"

    async def chat(self, prompt: str, *, max_tokens: int = 800, temp: float = 0.3,
                   model: Optional[str] = None) -> ProviderCall:
        if not self.api_key:
            raise RuntimeError("anthropic api key not configured")
        model = model or "claude-haiku-4-5"
        client = get_http_client()
        r = await client.post(
            f"{self.base_url}/messages",
            headers={
                "x-api-key": self.api_key,
                "anthropic-version": "2023-06-01",
                "Content-Type": "application/json",
            },
            json={
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": max_tokens,
                "temperature": temp,
            },
        )
        r.raise_for_status()
        data = r.json()
        text = "".join(b.get("text", "") for b in data.get("content", [])).strip()
        usage = data.get("usage", {})
        t_in = usage.get("input_tokens", 0)
        t_out = usage.get("output_tokens", 0)
        return ProviderCall(text=text, model=model, provider=self.name,
                            tokens_in=t_in, tokens_out=t_out,
                            cost_usd=_calc_cost(model, t_in, t_out))

    async def vision(self, image_bytes: bytes, prompt: str, *, mime: str = "image/png",
                     model: Optional[str] = None) -> ProviderCall:
        if not self.api_key:
            raise RuntimeError("anthropic api key not configured")
        model = model or "claude-sonnet-4-6"
        b64 = base64.b64encode(image_bytes).decode("ascii")
        client = get_http_client()
        r = await client.post(
            f"{self.base_url}/messages",
            headers={
                "x-api-key": self.api_key,
                "anthropic-version": "2023-06-01",
                "Content-Type": "application/json",
            },
            json={
                "model": model,
                "max_tokens": 800,
                "messages": [{
                    "role": "user",
                    "content": [
                        {"type": "image",
                         "source": {"type": "base64",
                                    "media_type": mime,
                                    "data": b64}},
                        {"type": "text", "text": prompt},
                    ],
                }],
            },
            timeout=120.0,
        )
        r.raise_for_status()
        data = r.json()
        text = "".join(b.get("text", "") for b in data.get("content", [])).strip()
        usage = data.get("usage", {})
        t_in = usage.get("input_tokens", 0)
        t_out = usage.get("output_tokens", 0)
        return ProviderCall(text=text, model=model, provider=self.name,
                            tokens_in=t_in, tokens_out=t_out,
                            cost_usd=_calc_cost(model, t_in, t_out))


# ─── Provider registry ────────────────────────────────────────────────────────
_openai = OpenAICompatProvider("openai", settings.openai_api_key,
                               "https://api.openai.com/v1")
_nvidia = OpenAICompatProvider("nvidia", settings.nvidia_api_key,
                               settings.nvidia_nim_base_url)
_groq = OpenAICompatProvider("groq", settings.groq_api_key,
                             settings.groq_base_url)
_anthropic = AnthropicProvider(settings.anthropic_api_key)


def _route(role: Role) -> list[tuple[BaseProvider, str]]:
    """Return ordered (provider, model) tuples to try for a role.

    VISION: nemotron-3-nano-omni (multimodal, reasoning) primary;
            kimi-k2.6 on NVIDIA as fallback.
    RANK/CHAT/REASON: kimi-k2.6 on NVIDIA (free, fast).
    EMBED: NVIDIA nv-embedqa-e5-v5; OpenAI text-embedding-3-small fallback.
    Paid OpenAI/Anthropic serve as last-resort fallbacks.
    """
    s = settings
    if role == Role.VISION:
        return [(_nvidia, s.model_vision_primary),
                (_nvidia, s.model_vision_secondary),
                (_openai, s.model_vision_tertiary)]
    if role == Role.RANK:
        return [(_nvidia, s.model_rank_primary),
                (_anthropic, s.model_rank_secondary),
                (_openai, s.model_rank_tertiary)]
    if role == Role.CHAT:
        return [(_nvidia, s.model_chat_primary),
                (_groq, s.model_chat_secondary),
                (_anthropic, s.model_chat_tertiary)]
    if role == Role.EMBED:
        return [(_nvidia, s.model_embed_primary),
                (_openai, s.model_embed_secondary)]
    if role == Role.REASON:
        return [(_nvidia, s.model_reason_primary),
                (_anthropic, s.model_reason_secondary),
                (_openai, s.model_reason_tertiary)]
    return []


def _provider_configured(p: BaseProvider) -> bool:
    if isinstance(p, AnthropicProvider):
        return bool(p.api_key)
    if isinstance(p, OpenAICompatProvider):
        return bool(p.api_key)
    return False


async def call_role(role: Role, action: str, *args, **kwargs) -> Any:
    """Try each configured provider for the given role until one succeeds.

    action: "chat" | "vision" | "embed"
    """
    from app.utils.cost_tracker import track_provider_spend

    candidates = _route(role)
    last_error: Optional[Exception] = None

    for provider, model in candidates:
        if not _provider_configured(provider):
            logger.debug(f"skip {provider.name}: no api key")
            continue
        try:
            method = getattr(provider, action)
            result = await method(*args, model=model, **kwargs)
            if isinstance(result, ProviderCall):
                await track_provider_spend(
                    provider=result.provider, model=result.model,
                    tokens_in=result.tokens_in, tokens_out=result.tokens_out,
                    cost_usd=result.cost_usd,
                )
                logger.info(
                    f"ai[{role.value}] -> {result.provider}/{result.model} "
                    f"in={result.tokens_in} out={result.tokens_out} "
                    f"cost=${result.cost_usd:.4f}"
                )
            return result
        except Exception as e:
            last_error = e
            logger.warning(
                f"ai[{role.value}] {provider.name}/{model} failed: {e!r}"
            )
            continue

    raise RuntimeError(
        f"All providers failed for role={role.value}; last_error={last_error!r}"
    )


# Convenience helpers
async def chat(role: Role, prompt: str, *, max_tokens: int = 800,
               temp: float = 0.3) -> ProviderCall:
    return await call_role(role, "chat", prompt, max_tokens=max_tokens, temp=temp)


async def vision(role: Role, image_bytes: bytes, prompt: str, *,
                 mime: str = "image/png") -> ProviderCall:
    return await call_role(role, "vision", image_bytes, prompt, mime=mime)


async def embed(text: str) -> list[float]:
    return await call_role(Role.EMBED, "embed", text)
