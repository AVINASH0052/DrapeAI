from app.services.storage import get_image_url, user_owns_key


def test_user_owns_key_prefix():
    assert user_owns_key("u1", "users/u1/items/a.png")
    assert not user_owns_key("u1", "users/u2/items/a.png")
    assert not user_owns_key("u1", "")
    assert not user_owns_key("", "users/u1/items/a.png")


def test_dev_image_url_is_local_path():
    url = get_image_url("users/u1/items/a.png")
    assert url == "/uploads/users/u1/items/a.png"
    assert "r2.cloudflarestorage.com" not in url
