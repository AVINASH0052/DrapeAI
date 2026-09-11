"""HD input prep defaults for try-on inference."""

import io

from PIL import Image

from app.services.try_on_prep import (
    HD_GARMENT_MAX_EDGE,
    HD_PERSON_MAX_EDGE,
    prep_item_bytes_list,
    prep_person_bytes,
    resize_max_edge,
)


def _png(w: int, h: int) -> bytes:
    img = Image.new("RGB", (w, h), (40, 80, 120))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_hd_defaults_are_2048_and_1536():
    assert HD_PERSON_MAX_EDGE == 2048
    assert HD_GARMENT_MAX_EDGE == 1536


def test_prep_person_defaults_to_hd_edge():
    out = prep_person_bytes(_png(3000, 4000))
    img = Image.open(io.BytesIO(out))
    assert max(img.size) == HD_PERSON_MAX_EDGE


def test_prep_garments_default_to_hd_edge():
    out = prep_item_bytes_list([_png(2500, 2500)])
    assert len(out) == 1
    img = Image.open(io.BytesIO(out[0]))
    assert max(img.size) == HD_GARMENT_MAX_EDGE


def test_resize_max_edge_default_is_hd_person():
    out = resize_max_edge(_png(4000, 2000))
    img = Image.open(io.BytesIO(out))
    assert max(img.size) == HD_PERSON_MAX_EDGE
