"""Async wardrobe upload acceptance tests."""

from unittest.mock import AsyncMock, patch

import pytest

from app.services.garment_splitter import ExtractedGarment
from app.services.upload_pipeline import run_upload_pipeline_standalone


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


_TAGS = {
    "category": "top",
    "sub_category": "t-shirt",
    "primary_color": "blue",
    "secondary_colors": [],
    "pattern": "solid",
    "fabric": "cotton",
    "style_tags": ["casual"],
    "formality": 2,
    "season_tags": ["all_season"],
    "ethnic_flag": False,
    "confidence": 0.9,
}


@pytest.mark.asyncio
async def test_upload_returns_processing_without_waiting_for_gemini(
    client, auth_headers, clean_db
):
    """HTTP accept must return before Gemini extract (Cloudflare ~100s)."""
    with (
        patch(
            "app.services.upload_pipeline.enqueue_upload_job",
            new_callable=AsyncMock,
            return_value=True,
        ) as enqueue,
        patch(
            "app.services.upload_pipeline.extract_garments",
            new_callable=AsyncMock,
        ) as extract,
        patch(
            "app.services.upload_pipeline.tag_item",
            new_callable=AsyncMock,
        ) as tag,
    ):
        resp = await client.post(
            "/items/upload",
            headers=auth_headers,
            files={"image": ("shirt.png", _minimal_png(), "image/png")},
        )

    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["processing_status"] == "processing"
    assert data["status"] == "processing"
    assert data["uploaded"] == 1
    enqueue.assert_awaited_once()
    extract.assert_not_awaited()
    tag.assert_not_awaited()


@pytest.mark.asyncio
async def test_background_split_replaces_placeholder_and_adds_pieces(
    client, auth_headers, clean_db
):
    top = ExtractedGarment(
        image_bytes=_minimal_png(),
        category_hint="top",
        label="t-shirt",
        description="blue t-shirt",
    )
    bottom = ExtractedGarment(
        image_bytes=_minimal_png(),
        category_hint="bottom",
        label="pants",
        description="beige trousers",
    )
    top_tags = {**_TAGS, "category": "top", "sub_category": "t-shirt"}
    bottom_tags = {
        **_TAGS,
        "category": "bottom",
        "sub_category": "trousers",
        "primary_color": "beige",
    }

    with (
        patch(
            "app.services.upload_pipeline.enqueue_upload_job",
            new_callable=AsyncMock,
            return_value=True,
        ),
        patch(
            "app.services.upload_pipeline.extract_garments",
            new_callable=AsyncMock,
            return_value=[top, bottom],
        ),
        patch(
            "app.services.upload_pipeline.tag_item",
            new_callable=AsyncMock,
            side_effect=[top_tags, bottom_tags],
        ),
        patch(
            "app.services.upload_pipeline.generate_embedding",
            new_callable=AsyncMock,
            return_value=[0.1] * 8,
        ),
        patch(
            "app.services.upload_pipeline.store_embedding",
            new_callable=AsyncMock,
        ),
    ):
        resp = await client.post(
            "/items/upload",
            headers=auth_headers,
            files={"image": ("outfit.jpg", _minimal_png(), "image/jpeg")},
        )
        assert resp.status_code == 201, resp.text
        item_id = resp.json()["id"]
        await run_upload_pipeline_standalone(item_id, "test-user-001")

    listed = await client.get("/items", headers=auth_headers)
    assert listed.status_code == 200
    items = listed.json()["items"]
    assert len(items) == 2
    assert {item["category"] for item in items} == {"top", "bottom"}
    assert all(item["processing_status"] == "ready" for item in items)
    top_item = next(item for item in items if item["id"] == item_id)
    assert item_id not in (top_item.get("image_url") or "")
