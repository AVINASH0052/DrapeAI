"""Tests for RunPod try-on provider wiring."""

from __future__ import annotations

import base64
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.image_gen_provider import (
    _idm_category_from_items,
    _runpod_tryon,
    generate_tryon_image,
)


def test_idm_category_from_items():
    assert _idm_category_from_items([{"category": "top"}]) == "upper_body"
    assert _idm_category_from_items([{"category": "bottom"}]) == "lower_body"
    assert _idm_category_from_items([{"category": "dress"}]) == "dresses"


@pytest.mark.asyncio
async def test_runpod_tryon_success():
    fake_png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32
    b64 = base64.b64encode(fake_png).decode("ascii")
    mock_resp = MagicMock()
    mock_resp.raise_for_status = MagicMock()
    mock_resp.json.return_value = {
        "status": "COMPLETED",
        "output": {"image": b64, "stub": False},
    }
    mock_client = MagicMock()
    mock_client.post = AsyncMock(return_value=mock_resp)

    with patch("app.services.image_gen_provider.settings") as mock_settings, \
         patch("app.services.image_gen_provider.get_http_client", return_value=mock_client), \
         patch("app.services.image_gen_provider.prep_person_bytes", side_effect=lambda b: b), \
         patch("app.services.image_gen_provider.prep_item_bytes_list", side_effect=lambda items, **kw: items):
        mock_settings.runpod_api_key = "rp_test"
        mock_settings.runpod_endpoint_id = "ep_test"
        mock_settings.runpod_tryon_timeout_sec = 120
        out = await _runpod_tryon(fake_png, [fake_png], "prompt", "idm-vton")

    assert out[:8] == b"\x89PNG\r\n\x1a\n"
    mock_client.post.assert_awaited_once()
    call_kw = mock_client.post.await_args
    assert "ep_test/runsync" in call_kw.args[0]


@pytest.mark.asyncio
async def test_runpod_tryon_polls_when_runsync_returns_in_queue():
    """/runsync has its own ~90s internal wait cap; on a cold worker it can
    return IN_QUEUE/IN_PROGRESS with no output well before our timeout.
    The client must then poll GET /status/{id} until it settles."""
    fake_png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32
    b64 = base64.b64encode(fake_png).decode("ascii")

    post_resp = MagicMock()
    post_resp.raise_for_status = MagicMock()
    post_resp.json.return_value = {"id": "job-123", "status": "IN_QUEUE"}

    status_in_progress = MagicMock()
    status_in_progress.raise_for_status = MagicMock()
    status_in_progress.json.return_value = {"id": "job-123", "status": "IN_PROGRESS"}

    status_completed = MagicMock()
    status_completed.raise_for_status = MagicMock()
    status_completed.json.return_value = {
        "id": "job-123",
        "status": "COMPLETED",
        "output": {"image": b64},
    }

    mock_client = MagicMock()
    mock_client.post = AsyncMock(return_value=post_resp)
    mock_client.get = AsyncMock(side_effect=[status_in_progress, status_completed])

    with patch("app.services.image_gen_provider.settings") as mock_settings, \
         patch("app.services.image_gen_provider.get_http_client", return_value=mock_client), \
         patch("app.services.image_gen_provider.prep_person_bytes", side_effect=lambda b: b), \
         patch("app.services.image_gen_provider.prep_item_bytes_list", side_effect=lambda items, **kw: items), \
         patch("app.services.image_gen_provider.asyncio.sleep", new_callable=AsyncMock):
        mock_settings.runpod_api_key = "rp_test"
        mock_settings.runpod_endpoint_id = "ep_test"
        mock_settings.runpod_tryon_timeout_sec = 120
        out = await _runpod_tryon(fake_png, [fake_png], "prompt", "idm-vton")

    assert out[:8] == b"\x89PNG\r\n\x1a\n"
    assert mock_client.get.await_count == 2
    for call in mock_client.get.await_args_list:
        assert "ep_test/status/job-123" in call.args[0]


@pytest.mark.asyncio
async def test_runpod_tryon_raises_on_timeout_while_in_queue():
    """If the job never settles within runpod_tryon_timeout_sec, raise
    instead of looping forever or silently returning no image."""
    post_resp = MagicMock()
    post_resp.raise_for_status = MagicMock()
    post_resp.json.return_value = {"id": "job-999", "status": "IN_QUEUE"}

    still_queued = MagicMock()
    still_queued.raise_for_status = MagicMock()
    still_queued.json.return_value = {"id": "job-999", "status": "IN_QUEUE"}

    mock_client = MagicMock()
    mock_client.post = AsyncMock(return_value=post_resp)
    mock_client.get = AsyncMock(return_value=still_queued)

    fake_png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32

    # Fake a clock that jumps straight past the deadline after the first poll.
    times = iter([0.0, 0.0, 999.0])

    with patch("app.services.image_gen_provider.settings") as mock_settings, \
         patch("app.services.image_gen_provider.get_http_client", return_value=mock_client), \
         patch("app.services.image_gen_provider.prep_person_bytes", side_effect=lambda b: b), \
         patch("app.services.image_gen_provider.prep_item_bytes_list", side_effect=lambda items, **kw: items), \
         patch("app.services.image_gen_provider.asyncio.sleep", new_callable=AsyncMock), \
         patch("app.services.image_gen_provider.asyncio.get_event_loop") as mock_loop:
        mock_loop.return_value.time.side_effect = lambda: next(times)
        mock_settings.runpod_api_key = "rp_test"
        mock_settings.runpod_endpoint_id = "ep_test"
        mock_settings.runpod_tryon_timeout_sec = 10

        with pytest.raises(RuntimeError, match="timed out"):
            await _runpod_tryon(fake_png, [fake_png], "prompt", "idm-vton")


@pytest.mark.asyncio
async def test_generate_tryon_runpod_primary():
    fake_png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32
    person = fake_png
    items = [{"category": "top", "image_url": "x"}]

    with patch("app.services.image_gen_provider._route_tryon", return_value=[("runpod", "idm-vton")]), \
         patch("app.services.image_gen_provider._provider_configured", return_value=True), \
         patch("app.services.image_gen_provider._load_item_bytes", new_callable=AsyncMock) as mock_load, \
         patch("app.services.image_gen_provider._runpod_tryon", new_callable=AsyncMock) as mock_rp, \
         patch("app.services.image_gen_provider._track_tryon_cost", new_callable=AsyncMock), \
         patch("app.services.image_gen_provider.settings") as mock_settings:
        mock_settings.tryon_prompt_version = "wardrobe_v1"
        mock_load.return_value = [fake_png]
        mock_rp.return_value = fake_png
        result = await generate_tryon_image(person, items)

    assert result is not None
    assert result.provider == "runpod"
    mock_rp.assert_awaited_once()
