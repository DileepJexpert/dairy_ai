from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Core
    DATABASE_URL: str = "postgresql+asyncpg://dairy:dairy123@localhost:5432/dairy_ai"
    REDIS_URL: str = ""
    JWT_SECRET: str = "test-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"

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


settings = Settings()


@lru_cache
def get_settings() -> Settings:
    return Settings()
