from app.config import Settings, production_settings_errors, validate_boot_settings


def _prod(**overrides) -> Settings:
    base = dict(
        environment="production",
        firebase_project_id="sugatai-test",
        database_url="postgresql://u:p@db:5432/drapeai",
        redis_url="redis://redis:6379/0",
        r2_account_id="acct",
        r2_access_key_id="key",
        r2_secret_access_key="secret",
        r2_bucket_name="drapeai-images",
        cors_origins="https://www.sugatai.com",
        gemini_api_key="test-gemini",
    )
    base.update(overrides)
    return Settings(_env_file=None, **base)


def test_production_config_ok():
    assert production_settings_errors(_prod()) == []


def test_production_requires_firebase_and_r2():
    errors = production_settings_errors(_prod(firebase_project_id="", r2_account_id=""))
    assert any("FIREBASE" in e for e in errors)
    assert any("R2_" in e for e in errors)


def test_production_rejects_wildcard_and_localhost_cors():
    errors = production_settings_errors(_prod(cors_origins="*,https://localhost:5173"))
    assert any("*" in e for e in errors)
    assert any("local" in e.lower() for e in errors)


def test_production_rejects_zero_spend_cap():
    errors = production_settings_errors(_prod(total_spend_cap_usd=0))
    assert any("TOTAL_SPEND_CAP" in e for e in errors)


def test_production_requires_an_ai_path():
    errors = production_settings_errors(
        _prod(
            gemini_api_key="",
            openai_api_key="",
            google_cloud_project="",
            google_application_credentials="",
            cloudflare_account_id="",
            cloudflare_api_token="",
            runpod_api_key="",
            runpod_endpoint_id="",
        )
    )
    assert any("AI path" in e for e in errors)


def test_validate_boot_rejects_unknown_environment():
    try:
        validate_boot_settings(
            Settings(_env_file=None, environment="prod"),
            require_production=False,
        )
    except RuntimeError as e:
        assert "ENVIRONMENT" in str(e)
    else:
        raise AssertionError("expected RuntimeError")


def test_development_still_boots_without_r2():
    validate_boot_settings(
        Settings(_env_file=None, environment="development"),
        require_production=False,
    )
