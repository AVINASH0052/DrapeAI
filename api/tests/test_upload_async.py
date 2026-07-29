"""Async wardrobe upload acceptance tests."""

from unittest.mock import AsyncMock, patch

import pytest


def _minimal_png(min_size: int = 120) -> bytes:
    # 1x1 PNG, padded past the 100-byte validation floor.
    png = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01"
        b"\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00"
        b"\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18"
        b"\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    if len(png) >= min_size:
        return png
    return png + (b"\x00" * (min_size - len(png)))


@pytest.mark.asyncio
async def test_upload_returns_immediately_while_processing(
    client, auth_headers, clean_db
):
    """Upload should persist the item and return before AI tagging finishes."""
    with (
        patch(
            "app.services.upload_pipeline.enqueue_upload_job",
            new_callable=AsyncMock,
            return_value=True,
        ) as enqueue,
        patch(
            "app.services.upload_pipeline.run_upload_pipeline_standalone",
            new_callable=AsyncMock,
        ) as inline,
        patch(
            "app.services.upload_pipeline.remove_background",
            new_callable=AsyncMock,
            return_value=_minimal_png(),
        ) as remove_background,
    ):
        resp = await client.post(
            "/items/upload",
            headers=auth_headers,
            files={"image": ("shirt.png", _minimal_png(), "image/png")},
        )

    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["status"] == "processing"
    assert data["processing_status"] == "queued"
    assert data["id"]
    assert data["image_url"]
    enqueue.assert_awaited_once()
    inline.assert_not_awaited()
    remove_background.assert_awaited_once()

    listed = await client.get("/items", headers=auth_headers)
    assert listed.status_code == 200
    items = listed.json()["items"]
    uploaded = next(item for item in items if item["id"] == data["id"])
    assert uploaded["processing_status"] == "queued"
