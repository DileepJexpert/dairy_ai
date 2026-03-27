import uuid


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
    return f"mock_agora_token_{channel_name}_{uid}_{role}"
