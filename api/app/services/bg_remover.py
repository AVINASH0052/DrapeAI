"""Background removal using rembg. CPU-bound, runs in thread pool."""

import asyncio
import logging
from io import BytesIO

from PIL import Image
import rembg

logger = logging.getLogger(__name__)


def _remove_bg_sync(image_bytes: bytes) -> bytes:
    """Synchronous background removal. Runs in executor."""
    result = rembg.remove(image_bytes)

    # Ensure PNG output and reasonable size
    img = Image.open(BytesIO(result))
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    # Resize if larger than 1024px on longest side
    max_side = 1024
    if max(img.size) > max_side:
        ratio = max_side / max(img.size)
        new_size = (int(img.width * ratio), int(img.height * ratio))
        img = img.resize(new_size, Image.LANCZOS)

    output = BytesIO()
    img.save(output, format="PNG", optimize=True)
    return output.getvalue()


async def remove_background(image_bytes: bytes) -> bytes:
    """Remove background from clothing image. Returns PNG bytes.

    Takes 2-4 seconds on CPU. Runs in thread pool to avoid blocking.
    """
    loop = asyncio.get_running_loop()
    result = await loop.run_in_executor(None, _remove_bg_sync, image_bytes)
    logger.info(f"Background removed: {len(image_bytes)} -> {len(result)} bytes")
    return result
