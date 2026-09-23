from functools import lru_cache
from typing import Literal

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
    # Demand-validation mode: checkout records intent without charging a
    # customer or consuming sellable inventory.
    PRELAUNCH_MODE: bool = True
    # Shipping remains manual until an approved courier account is configured.
    SHIPPING_ORIGIN_PINCODE: str = "201305"
    SHIPPING_AUTO_BOOK_ENABLED: bool = False
    SHIPPING_PACKAGING_TARE_GRAMS: int = 0
    SHIPPING_PACKAGE_LENGTH_CM: int = 0
    SHIPPING_PACKAGE_WIDTH_CM: int = 0
    SHIPPING_PACKAGE_HEIGHT_CM: int = 0
    SHIPPING_MAX_COURIER_COST: float = 0.0  # 0 disables the cost ceiling.
    SHIPPING_MAX_DELIVERY_DAYS: int = 0  # 0 accepts unknown ETA.
    SHIPPING_SELECTION_STRATEGY: Literal["lowest_cost", "fastest"] = "lowest_cost"
    DELHIVERY_ENV: Literal["staging", "production"] = "staging"
    DELHIVERY_TOKEN: str = ""
    DELHIVERY_CLIENT_NAME: str = ""
    DELHIVERY_PICKUP_LOCATION: str = ""
    DELHIVERY_PICKUP_TIME: str = "15:00:00"
    # Keep this directory on persistent disk and back it up with the database.
    PRODUCT_MEDIA_DIR: str = "storage/product-media"
    # Enable after an explicit local full rebuild (see scripts/rebuild_local_database.py).
    COMMERCE_TAXONOMY_ENABLED: bool = True

    # Optional zero-software-cost email delivery. Gmail SMTP can be used with
    # an account-specific App Password; leave blank for local reset-link testing.
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = ""
    SMTP_USE_TLS: bool = True
    STOREFRONT_BASE_URL: str = "http://127.0.0.1:5051"

    # WhatsApp
    WHATSAPP_TOKEN: str = ""
    WHATSAPP_PHONE_ID: str = ""
    WHATSAPP_VERIFY_TOKEN: str = ""
    WHATSAPP_APP_SECRET: str = ""
    ALLOW_DEMO_LOGIN: bool = True

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
