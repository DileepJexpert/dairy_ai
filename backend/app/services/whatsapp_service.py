from datetime import datetime, timezone

from app.integrations.whatsapp import WhatsAppClient
from app.services.llm_service import LLMService


async def handle_incoming(payload: dict) -> str:
    """Process incoming WhatsApp webhook message and return response text."""
    entry = payload.get("entry", [])
    if not entry:
        return ""

    changes = entry[0].get("changes", [])
    if not changes:
        return ""

    value = changes[0].get("value", {})
    messages = value.get("messages", [])
    if not messages:
        return ""

    msg = messages[0]
    phone = msg.get("from", "")
    msg_type = msg.get("type", "text")

    if msg_type == "audio":
        response_text = "Voice messages will be supported soon! Please type your question."
    elif msg_type == "text":
        text = msg.get("text", {}).get("body", "").strip().lower()
        response_text = await _route_message(text, phone)
    elif msg_type == "interactive":
        button_reply = msg.get("interactive", {}).get("button_reply", {})
        text = button_reply.get("title", "").strip().lower()
        response_text = await _route_message(text, phone)
    else:
        response_text = "I can help with text messages. Please type your question!"

    # Send response
    if phone and response_text:
        await WhatsAppClient.send_text(phone, response_text)

    return response_text


async def _route_message(text: str, phone: str) -> str:
    """Route message to appropriate handler based on intent."""
    # Price intent
    price_keywords = ["price", "daam", "rate", "bhav", "kimat"]
    if any(kw in text for kw in price_keywords):
        return (
            "Milk prices in your area:\n"
            "- Cooperative: ₹35/litre\n"
            "- Private dairy: ₹38/litre\n"
            "- Local: ₹40/litre\n\n"
            "For exact prices, open the DairyAI app → Milk Prices"
        )

    # Health intent
    health_keywords = ["health", "bimar", "sick", "fever", "bukhar", "illness"]
    if any(kw in text for kw in health_keywords):
        return (
            "For health issues, I recommend:\n"
            "1. Open DairyAI app → Report Health Issue\n"
            "2. Our AI will assess the severity\n"
            "3. You can connect to a vet instantly\n\n"
            "Reply with symptoms for a quick check."
        )

    # Vet intent
    vet_keywords = ["vet", "doctor", "daktar"]
    if any(kw in text for kw in vet_keywords):
        return (
            "Connect with a verified vet:\n"
            "Open DairyAI app → Call Vet\n"
            "Video consultation from ₹100\n\n"
            "For emergencies, call the app's emergency button."
        )

    # Feed intent
    feed_keywords = ["feed", "chara", "khurak", "dana"]
    if any(kw in text for kw in feed_keywords):
        return (
            "For optimized feed plans:\n"
            "Open DairyAI app → Feed Plan\n"
            "Our AI creates cost-effective plans based on your cattle's needs."
        )

    # Default: send to LLM
    response = await LLMService.chat(phone, text)
    return response
