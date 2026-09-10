from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Core
    APP_ENV: str = "development"
    LOG_LEVEL: str = "INFO"
    DATABASE_URL: str = "postgresql+asyncpg://dairy:dairy123@localhost:5432/dairy_ai"
    REDIS_URL: str = ""
    JWT_SECRET: str = "test-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:5000,http://localhost:8000"
    INIT_DB_ON_STARTUP: bool = True
    # Enable after an explicit local full rebuild (see scripts/rebuild_local_database.py).
    COMMERCE_TAXONOMY_ENABLED: bool = False

    # WhatsApp
    WHATSAPP_TOKEN: str = ""
    WHATSAPP_PHONE_ID: str = ""
    WHATSAPP_VERIFY_TOKEN: str = ""

    # Agora
    AGORA_APP_ID: str = ""
    AGORA_APP_CERTIFICATE: str = ""

    # Bhashini
    BHASHINI_API_KEY: str = ""
    BHASHINI_USER_ID: str = ""

    # LLM
    LLM_API_URL: str = ""
    LLM_API_KEY: str = ""
    LLM_MODEL: str = ""

    # MQTT
    MQTT_BROKER_HOST: str = ""
    MQTT_BROKER_PORT: int = 1883

    # AWS / S3
    AWS_ACCESS_KEY: str = ""
    AWS_SECRET_KEY: str = ""
    S3_BUCKET: str = ""

    # Razorpay
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""

    # Pashudhan / INAPH
    PASHUDHAN_API_URL: str = "https://inaph.gov.in/api/v1"
    PASHUDHAN_API_KEY: str = ""

    # Firebase FCM
    FCM_SERVER_KEY: str = ""
    FCM_PROJECT_ID: str = ""

    # SMS Gateway (MSG91 / Twilio)
    SMS_PROVIDER: str = "msg91"  # msg91 | twilio
    SMS_API_KEY: str = ""
    SMS_SENDER_ID: str = "DRYAI"

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "extra": "ignore",
    }

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip().rstrip("/") for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def cors_origin_regex(self) -> str | None:
        # Flutter's local web runner chooses a dynamic localhost port. Keep this
        # convenience strictly outside production, where origins are explicit.
        if self.APP_ENV.lower() == "production":
            return None
        return r"https?://(localhost|127\.0\.0\.1)(:\d+)?"

    def validate_production_settings(self) -> None:
        """Fail closed when a production process is started with demo settings."""
        if self.APP_ENV.lower() != "production":
            return
        if self.JWT_SECRET == "test-secret-key-change-in-production" or len(self.JWT_SECRET) < 32:
            raise RuntimeError("JWT_SECRET must be a unique value of at least 32 characters in production")
        if not self.cors_origins or "*" in self.cors_origins:
            raise RuntimeError("CORS_ORIGINS must list explicit HTTPS origins in production")
        if any(not origin.startswith("https://") for origin in self.cors_origins):
            raise RuntimeError("CORS_ORIGINS must use HTTPS origins in production")


settings = Settings()


@lru_cache
def get_settings() -> Settings:
    return Settings()
