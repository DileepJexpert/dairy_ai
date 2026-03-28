import logging
from datetime import datetime, timezone

from app.integrations.whatsapp import WhatsAppClient
from app.services.llm_service import LLMService

logger = logging.getLogger("dairy_ai.services.whatsapp")


async def handle_incoming(payload: dict) -> str:
    """Process incoming WhatsApp webhook message and return response text."""
    logger.info("handle_incoming called — processing WhatsApp webhook payload")
    logger.debug(f"Webhook payload keys: {list(payload.keys())}")

    entry = payload.get("entry", [])
    if not entry:
        logger.debug("No 'entry' in payload, ignoring webhook")
        return ""

    changes = entry[0].get("changes", [])
    if not changes:
        logger.debug("No 'changes' in entry, ignoring webhook")
        return ""

    value = changes[0].get("value", {})
    messages = value.get("messages", [])
    if not messages:
        logger.debug("No 'messages' in value — could be a status update, ignoring")
        return ""

    msg = messages[0]
    phone = msg.get("from", "")
    msg_type = msg.get("type", "text")
    masked_phone = f"****{phone[-4:]}" if len(phone) >= 4 else "****"
    logger.info(f"Incoming WhatsApp message | phone={masked_phone}, type={msg_type}")

    if msg_type == "audio":
        response_text = "Voice messages will be supported soon! Please type your question."
        logger.debug(f"Audio message received from {masked_phone} — sending voice-not-supported response")
    elif msg_type == "text":
        text = msg.get("text", {}).get("body", "").strip().lower()
        logger.debug(f"Text message from {masked_phone}: {text[:100]}{'...' if len(text) > 100 else ''}")
        response_text = await _route_message(text, phone)
    elif msg_type == "interactive":
        button_reply = msg.get("interactive", {}).get("button_reply", {})
        text = button_reply.get("title", "").strip().lower()
        logger.debug(f"Interactive button reply from {masked_phone}: {text}")
        response_text = await _route_message(text, phone)
    else:
        response_text = "I can help with text messages. Please type your question!"
        logger.debug(f"Unsupported message type '{msg_type}' from {masked_phone}")

    # Send response
    if phone and response_text:
        logger.debug(f"Sending response to {masked_phone} | response_length={len(response_text)}")
        try:
            await WhatsAppClient.send_text(phone, response_text)
            logger.info(f"WhatsApp response sent | phone={masked_phone}, response_length={len(response_text)}")
        except Exception as e:
            logger.error(f"Failed to send WhatsApp response | phone={masked_phone}, error={e}")

    return response_text


async def _route_message(text: str, phone: str) -> str:
    """Route message to appropriate handler based on intent."""
    masked_phone = f"****{phone[-4:]}" if len(phone) >= 4 else "****"
    logger.debug(f"Routing message | phone={masked_phone}, text={text[:50]}")

    # Price intent
    price_keywords = ["price", "daam", "rate", "bhav", "kimat"]
    if any(kw in text for kw in price_keywords):
        logger.info(f"Intent detected: PRICE | phone={masked_phone}, matched_keyword={[kw for kw in price_keywords if kw in text]}")
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
        logger.info(f"Intent detected: HEALTH | phone={masked_phone}, matched_keyword={[kw for kw in health_keywords if kw in text]}")
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
        logger.info(f"Intent detected: VET | phone={masked_phone}, matched_keyword={[kw for kw in vet_keywords if kw in text]}")
        return (
            "Connect with a verified vet:\n"
            "Open DairyAI app → Call Vet\n"
            "Video consultation from ₹100\n\n"
            "For emergencies, call the app's emergency button."
        )

    # Feed intent
    feed_keywords = ["feed", "chara", "khurak", "dana"]
    if any(kw in text for kw in feed_keywords):
        logger.info(f"Intent detected: FEED | phone={masked_phone}, matched_keyword={[kw for kw in feed_keywords if kw in text]}")
        return (
            "For optimized feed plans:\n"
            "Open DairyAI app → Feed Plan\n"
            "Our AI creates cost-effective plans based on your cattle's needs."
        )

    # Default: send to LLM
    logger.info(f"No specific intent matched — routing to LLM | phone={masked_phone}")
    response = await LLMService.chat(phone, text)
    logger.debug(f"LLM response for {masked_phone}: {response[:100]}{'...' if len(response) > 100 else ''}")
    return response
