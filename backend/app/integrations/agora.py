import logging
import uuid

logger = logging.getLogger("dairy_ai.integrations.agora")


def generate_rtc_token(
    channel_name: str,
    uid: int = 0,
    role: str = "publisher",
    expire_seconds: int = 3600,
) -> str:
    """Generate a mock Agora RTC token.

    In production this would use the Agora SDK to build a real token.
    For now it returns a deterministic stub so tests are predictable.
    """
    logger.info("Generating RTC token: channel=%s, uid=%d, role=%s, expire=%ds",
                channel_name, uid, role, expire_seconds)
    logger.debug("Token generation parameters: channel_name=%s, uid=%d, role=%s, expire_seconds=%d",
                 channel_name, uid, role, expire_seconds)
    token = f"mock_agora_token_{channel_name}_{uid}_{role}"
    logger.info("RTC token generated for channel=%s, uid=%d (token_length=%d)", channel_name, uid, len(token))
    return token
