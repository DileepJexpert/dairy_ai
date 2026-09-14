import asyncio
import logging
import smtplib
from email.message import EmailMessage

from app.config import get_settings


logger = logging.getLogger("dairy_ai.services.email")


def email_is_configured() -> bool:
    settings = get_settings()
    return bool(
        settings.SMTP_HOST
        and settings.SMTP_USERNAME
        and settings.SMTP_PASSWORD
        and settings.SMTP_FROM_EMAIL
    )


def _send(message: EmailMessage) -> None:
    settings = get_settings()
    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=20) as smtp:
        if settings.SMTP_USE_TLS:
            smtp.starttls()
        smtp.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
        smtp.send_message(message)


async def send_password_reset_email(email: str, reset_url: str) -> bool:
    """Send a reset link when SMTP is configured; never expose credentials."""
    if not email_is_configured():
        logger.info("Password reset email skipped because SMTP is not configured")
        return False
    settings = get_settings()
    message = EmailMessage()
    message["Subject"] = "Reset your Milterra password"
    message["From"] = settings.SMTP_FROM_EMAIL
    message["To"] = email
    message.set_content(
        "A password reset was requested for your Milterra account.\n\n"
        f"Open this link within 30 minutes:\n{reset_url}\n\n"
        "If you did not request this, ignore this email."
    )
    await asyncio.to_thread(_send, message)
    return True
