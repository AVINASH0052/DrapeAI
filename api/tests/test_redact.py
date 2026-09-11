from app.utils.redact import CLIENT_SAFE_TRYON_ERROR, redact_text, redact_url


def test_redact_url_strips_password():
    assert (
        redact_url("redis://user:hunter2@localhost:6379/0")
        == "redis://user:***@localhost:6379/0"
    )


def test_redact_bearer_and_signed_query():
    text = redact_text(
        "Authorization: Bearer abc.def.ghi "
        "https://r2.example/obj?X-Amz-Signature=deadbeef"
    )
    assert "abc.def.ghi" not in text
    assert "deadbeef" not in text
    assert "[redacted]" in text


def test_client_safe_tryon_error_is_generic():
    assert CLIENT_SAFE_TRYON_ERROR == "try_on_failed"
    assert "exception" not in CLIENT_SAFE_TRYON_ERROR
