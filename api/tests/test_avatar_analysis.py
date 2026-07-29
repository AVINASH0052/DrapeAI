"""Avatar preparation status-transition tests."""

from io import BytesIO
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest
from PIL import Image

from app.services.avatar_analysis import run_avatar_analysis, sanitize_avatar_source


class FakeConnection:
    def __init__(self, source_key="users/u/body.jpg"):
        self.source_key = source_key
        self.executed = []

    async def fetchval(self, query, *_args):
        self.executed.append(query)
        return self.source_key

    async def execute(self, query, *_args):
        self.executed.append(query)


class Acquire:
    def __init__(self, conn):
        self.conn = conn

    async def __aenter__(self):
        return self.conn

    async def __aexit__(self, *_args):
        return False


class FakePool:
    def __init__(self, conn):
        self.conn = conn

    def acquire(self):
        return Acquire(self.conn)


def transparent_person_png():
    image = Image.new("RGBA", (100, 200), (0, 0, 0, 0))
    for x in range(25, 75):
        for y in range(10, 190):
            image.putpixel((x, y), (120, 80, 60, 255))
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


@pytest.mark.asyncio
async def test_avatar_source_metadata_is_removed():
    image = Image.new("RGB", (20, 30), "white")
    exif = Image.Exif()
    exif[305] = "camera software"
    source = BytesIO()
    image.save(source, format="JPEG", exif=exif)

    sanitized = await sanitize_avatar_source(source.getvalue())

    result = Image.open(BytesIO(sanitized))
    assert result.mode == "RGB"
    assert len(result.getexif()) == 0


@pytest.mark.asyncio
async def test_avatar_analysis_moves_processing_to_ready():
    conn = FakeConnection()
    avatar_png = transparent_person_png()
    with (
        patch(
            "app.services.avatar_analysis.get_pool",
            new=AsyncMock(return_value=FakePool(conn)),
        ),
        patch(
            "app.services.avatar_analysis.read_image_bytes",
            new=AsyncMock(return_value=b"source"),
        ),
        patch(
            "app.services.avatar_analysis.check_person_photo",
            new=AsyncMock(return_value=SimpleNamespace(ok=True, reason=None)),
        ),
        patch(
            "app.services.avatar_analysis.remove_background",
            new=AsyncMock(return_value=avatar_png),
        ),
        patch(
            "app.services.avatar_analysis.upload_avatar_base",
            new=AsyncMock(return_value="users/u/avatar/base.png"),
        ),
    ):
        profile = await run_avatar_analysis("u")

    sql = "\n".join(conn.executed)
    assert "avatar_status = 'processing'" in sql
    assert "avatar_status = 'ready'" in sql
    assert profile["visibility"] == "full_body"
    assert "weight" not in profile
    assert "measurements" not in profile


@pytest.mark.asyncio
async def test_avatar_analysis_records_failure():
    conn = FakeConnection()
    with (
        patch(
            "app.services.avatar_analysis.get_pool",
            new=AsyncMock(return_value=FakePool(conn)),
        ),
        patch(
            "app.services.avatar_analysis.read_image_bytes",
            new=AsyncMock(side_effect=OSError("missing source")),
        ),
    ):
        with pytest.raises(OSError, match="missing source"):
            await run_avatar_analysis("u")

    assert "avatar_status = 'failed'" in "\n".join(conn.executed)
