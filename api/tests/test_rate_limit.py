import pytest
from fastapi import Request

from app.middleware.rate_limiter import (
    _check_rate_limit_memory,
    _identity_for_request,
    _match_path_limit,
    _request_log,
)


def test_expensive_paths_have_tighter_limits():
    assert _match_path_limit("/items/upload") == (20, 60)
    assert _match_path_limit("/outfits/generate") == (10, 60)
    assert _match_path_limit("/waitlist") == (10, 60)
    general = _match_path_limit("/me")
    assert general[0] > 20


@pytest.mark.asyncio
async def test_memory_limiter_is_per_identity():
    _request_log.clear()
    allowed_a = []
    allowed_b = []
    for _ in range(3):
        allowed_a.append(await _check_rate_limit_memory("user:a", "/x", 2, 60))
        allowed_b.append(await _check_rate_limit_memory("user:b", "/x", 2, 60))
    assert allowed_a == [True, True, False]
    assert allowed_b == [True, True, False]


def _request(path: str, authorization: str | None, host: str) -> Request:
    headers = []
    if authorization:
        headers.append((b"authorization", authorization.encode()))
    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "GET",
        "scheme": "http",
        "path": path,
        "raw_path": path.encode(),
        "query_string": b"",
        "headers": headers,
        "client": (host, 123),
        "server": ("test", 80),
    }
    return Request(scope)


@pytest.mark.asyncio
async def test_identity_uses_test_token_in_development():
    ident = await _identity_for_request(
        _request("/me", "Bearer test-token", "1.2.3.4")
    )
    assert ident == "user:test-user-001"


@pytest.mark.asyncio
async def test_identity_falls_back_to_ip_without_token():
    ident = await _identity_for_request(_request("/waitlist", None, "9.9.9.9"))
    assert ident == "ip:9.9.9.9"
