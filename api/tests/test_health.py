import pytest


@pytest.mark.asyncio
async def test_health_is_liveness(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["service"] == "drapeai-api"
    assert "database" not in body


@pytest.mark.asyncio
async def test_ready_includes_dependency_checks(client):
    resp = await client.get("/ready")
    body = resp.json()
    assert "checks" in body
    assert "database" in body["checks"]
    assert "redis" in body["checks"]
    assert body["service"] == "drapeai-api"
    if body["ready"]:
        assert resp.status_code == 200
    else:
        assert resp.status_code == 503
