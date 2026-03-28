import logging
import httpx
from app.config import get_settings

logger = logging.getLogger("dairy_ai.integrations.whatsapp")


class WhatsAppClient:
    BASE_URL = "https://graph.facebook.com/v18.0"

    @staticmethod
    async def send_text(phone: str, message: str) -> dict:
        logger.info("Sending text message to phone=%s, message_length=%d", phone, len(message))
        settings = get_settings()
        url = f"{WhatsAppClient.BASE_URL}/{settings.WHATSAPP_PHONE_ID}/messages"
        headers = {
            "Authorization": f"Bearer {settings.WHATSAPP_TOKEN}",
            "Content-Type": "application/json",
        }
        payload = {
            "messaging_product": "whatsapp",
            "to": phone,
            "type": "text",
            "text": {"body": message},
        }
        try:
            logger.debug("POST %s for phone=%s", url, phone)
            async with httpx.AsyncClient() as client:
                response = await client.post(url, headers=headers, json=payload)
                result = response.json()
                logger.info("WhatsApp text send response: status=%d, phone=%s, result_keys=%s",
                            response.status_code, phone, list(result.keys()))
                if response.status_code >= 400:
                    logger.error("WhatsApp API error sending text to %s: status=%d, body=%s",
                                 phone, response.status_code, result)
                return result
        except Exception as e:
            logger.exception("Exception sending WhatsApp text to %s: %s", phone, e)
            return {"error": str(e)}

    @staticmethod
    async def send_template(phone: str, template_name: str, params: list[str]) -> dict:
        logger.info("Sending template '%s' to phone=%s with %d params", template_name, phone, len(params))
        settings = get_settings()
        url = f"{WhatsAppClient.BASE_URL}/{settings.WHATSAPP_PHONE_ID}/messages"
        headers = {
            "Authorization": f"Bearer {settings.WHATSAPP_TOKEN}",
            "Content-Type": "application/json",
        }
        components = []
        if params:
            components = [{"type": "body", "parameters": [{"type": "text", "text": p} for p in params]}]
        payload = {
            "messaging_product": "whatsapp",
            "to": phone,
            "type": "template",
            "template": {"name": template_name, "language": {"code": "en"}, "components": components},
        }
        try:
            logger.debug("POST %s for template=%s, phone=%s", url, template_name, phone)
            async with httpx.AsyncClient() as client:
                response = await client.post(url, headers=headers, json=payload)
                result = response.json()
                logger.info("WhatsApp template send response: status=%d, template=%s, phone=%s",
                            response.status_code, template_name, phone)
                if response.status_code >= 400:
                    logger.error("WhatsApp API error sending template '%s' to %s: status=%d, body=%s",
                                 template_name, phone, response.status_code, result)
                return result
        except Exception as e:
            logger.exception("Exception sending WhatsApp template '%s' to %s: %s", template_name, phone, e)
            return {"error": str(e)}

    @staticmethod
    async def send_interactive(phone: str, body: str, buttons: list[dict]) -> dict:
        logger.info("Sending interactive message to phone=%s, buttons=%d, body_length=%d",
                     phone, len(buttons), len(body))
        settings = get_settings()
        url = f"{WhatsAppClient.BASE_URL}/{settings.WHATSAPP_PHONE_ID}/messages"
        headers = {
            "Authorization": f"Bearer {settings.WHATSAPP_TOKEN}",
            "Content-Type": "application/json",
        }
        payload = {
            "messaging_product": "whatsapp",
            "to": phone,
            "type": "interactive",
            "interactive": {
                "type": "button",
                "body": {"text": body},
                "action": {
                    "buttons": [
                        {"type": "reply", "reply": {"id": b.get("id", str(i)), "title": b["title"]}}
                        for i, b in enumerate(buttons)
                    ]
                },
            },
        }
        try:
            logger.debug("POST %s for interactive message, phone=%s", url, phone)
            async with httpx.AsyncClient() as client:
                response = await client.post(url, headers=headers, json=payload)
                result = response.json()
                logger.info("WhatsApp interactive send response: status=%d, phone=%s",
                            response.status_code, phone)
                if response.status_code >= 400:
                    logger.error("WhatsApp API error sending interactive to %s: status=%d, body=%s",
                                 phone, response.status_code, result)
                return result
        except Exception as e:
            logger.exception("Exception sending WhatsApp interactive to %s: %s", phone, e)
            return {"error": str(e)}

    @staticmethod
    async def download_media(media_id: str) -> bytes:
        logger.info("Downloading media: media_id=%s", media_id)
        settings = get_settings()
        url = f"{WhatsAppClient.BASE_URL}/{media_id}"
        headers = {"Authorization": f"Bearer {settings.WHATSAPP_TOKEN}"}
        try:
            async with httpx.AsyncClient() as client:
                logger.debug("GET media metadata: %s", url)
                meta_resp = await client.get(url, headers=headers)
                meta_json = meta_resp.json()
                media_url = meta_json.get("url", "")
                logger.debug("Media metadata response: status=%d, has_url=%s", meta_resp.status_code, bool(media_url))
                if media_url:
                    logger.debug("GET media content from: %s", media_url)
                    resp = await client.get(media_url, headers=headers)
                    logger.info("Media downloaded: media_id=%s, size=%d bytes, status=%d",
                                media_id, len(resp.content), resp.status_code)
                    return resp.content
                logger.warning("No media URL returned for media_id=%s, metadata=%s", media_id, meta_json)
                return b""
        except Exception as e:
            logger.exception("Exception downloading media media_id=%s: %s", media_id, e)
            return b""
