"""Deliver Milterra's server-generated login code using an approved MSG91 SMS template."""

import logging

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)
MSG91_FLOW_URL = "https://control.msg91.com/api/v5/flow"


class OtpSmsClient:
    @staticmethod
    async def send(phone: str, code: str) -> bool:
        settings = get_settings()
        if (settings.SMS_PROVIDER != "msg91" or not settings.SMS_API_KEY
                or not settings.SMS_TEMPLATE_ID):
            return False
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    MSG91_FLOW_URL,
                    headers={"authkey": settings.SMS_API_KEY, "accept": "application/json"},
                    json={
                        "template_id": settings.SMS_TEMPLATE_ID,
                        "recipients": [{"mobiles": f"91{phone}", "VAR1": code}],
                    },
                )
                response.raise_for_status()
                result = response.json()
                return isinstance(result, dict) and result.get("type") == "success"
        except (httpx.HTTPError, ValueError):
            logger.exception("OTP SMS submission failed for phone ending %s", phone[-4:])
            return False
