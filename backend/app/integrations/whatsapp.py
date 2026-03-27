import httpx
from app.config import get_settings


class WhatsAppClient:
    BASE_URL = "https://graph.facebook.com/v18.0"

    @staticmethod
    async def send_text(phone: str, message: str) -> dict:
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
            async with httpx.AsyncClient() as client:
                response = await client.post(url, headers=headers, json=payload)
                return response.json()
        except Exception as e:
            return {"error": str(e)}

    @staticmethod
    async def send_template(phone: str, template_name: str, params: list[str]) -> dict:
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
            async with httpx.AsyncClient() as client:
                response = await client.post(url, headers=headers, json=payload)
                return response.json()
        except Exception as e:
            return {"error": str(e)}

    @staticmethod
    async def send_interactive(phone: str, body: str, buttons: list[dict]) -> dict:
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
            async with httpx.AsyncClient() as client:
                response = await client.post(url, headers=headers, json=payload)
                return response.json()
        except Exception as e:
            return {"error": str(e)}

    @staticmethod
    async def download_media(media_id: str) -> bytes:
        settings = get_settings()
        url = f"{WhatsAppClient.BASE_URL}/{media_id}"
        headers = {"Authorization": f"Bearer {settings.WHATSAPP_TOKEN}"}
        try:
            async with httpx.AsyncClient() as client:
                meta_resp = await client.get(url, headers=headers)
                media_url = meta_resp.json().get("url", "")
                if media_url:
                    resp = await client.get(media_url, headers=headers)
                    return resp.content
                return b""
        except Exception:
            return b""
