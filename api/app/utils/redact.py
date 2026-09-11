"""Redact credentials and private payloads before they hit logs or clients."""

from __future__ import annotations

import re
from urllib.parse import urlsplit, urlunsplit

_BEARER_RE = re.compile(r"(?i)\b(bearer\s+)[A-Za-z0-9._\-+/=]+")
_KEY_RE = re.compile(
    r"(?i)\b(api[_-]?key|secret|password|token|authorization)\s*[:=]\s*\S+"
)
_SIGNED_QUERY_RE = re.compile(r"(?i)([?&](?:X-Amz-Signature|X-Amz-Credential|signature)=)[^&\s]+")


def redact_url(url: str) -> str:
    """Strip userinfo (password) from a URL. Safe to log."""
    if not url:
        return url
    parts = urlsplit(url)
    if not parts.username and not parts.password:
        return url
    host = parts.hostname or ""
    if parts.port:
        host = f"{host}:{parts.port}"
    netloc = f"{parts.username}:***@{host}" if parts.username else f"***@{host}"
    return urlunsplit((parts.scheme, netloc, parts.path, parts.query, parts.fragment))


def redact_text(text: str) -> str:
    """Best-effort scrub of tokens, passwords, and signed-URL query params."""
    if not text:
        return text
    out = redact_url(text)
    out = _BEARER_RE.sub(r"\1[redacted]", out)
    out = _KEY_RE.sub(r"\1=[redacted]", out)
    out = _SIGNED_QUERY_RE.sub(r"\1[redacted]", out)
    return out


CLIENT_SAFE_TRYON_ERROR = "try_on_failed"
