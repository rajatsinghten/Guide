"""Application configuration via pydantic-settings.

Loads all environment variables required by the GigShield platform,
with sensible defaults for local development.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central configuration for the GigShield backend."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── Database ──────────────────────────────────────────────────────────
    database_url: str = "postgresql+asyncpg://gigshield:password@localhost:5432/gigshield"

    # ── Auth / JWT ────────────────────────────────────────────────────────
    secret_key: str = "change-me-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60

    # ── External APIs ─────────────────────────────────────────────────────
    use_mock_apis: bool = True
    openweather_api_key: str = ""

    # ── Payment Gateway ───────────────────────────────────────────────────
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""

    # ── ML Inference ───────────────────────────────────────────────────────
    ml_model_path: str = ""
    ml_reference_data_path: str = ""


settings = Settings()
