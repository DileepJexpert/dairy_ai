import logging

from fastapi import APIRouter, Request, Query, HTTPException
from app.config import get_settings
from app.services.whatsapp_service import handle_incoming

logger = logging.getLogger("dairy_ai.api.whatsapp")

router = APIRouter(prefix="/whatsapp", tags=["whatsapp"])


@router.get("/webhook")
async def verify_webhook(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_challenge: str = Query(None, alias="hub.challenge"),
    hub_verify_token: str = Query(None, alias="hub.verify_token"),
) -> str:
    """Meta webhook verification endpoint."""
    logger.info(f"GET /whatsapp/webhook called | hub_mode={hub_mode}")
    logger.debug(f"Webhook verification attempt | hub_mode={hub_mode} | has_challenge={bool(hub_challenge)} | has_verify_token={bool(hub_verify_token)}")
    settings = get_settings()
    if hub_mode == "subscribe" and hub_verify_token == settings.WHATSAPP_VERIFY_TOKEN:
        logger.info("WhatsApp webhook verification successful")
        return hub_challenge or ""
    logger.warning(f"WhatsApp webhook verification failed | hub_mode={hub_mode} | token_match={hub_verify_token == settings.WHATSAPP_VERIFY_TOKEN if hub_verify_token else False}")
    raise HTTPException(status_code=403, detail="Verification failed")


@router.post("/webhook")
async def receive_webhook(request: Request) -> dict:
    """Receive incoming WhatsApp messages."""
    logger.info("POST /whatsapp/webhook called | receiving incoming WhatsApp message")
    try:
        payload = await request.json()
        logger.debug(f"WhatsApp webhook payload received | keys={list(payload.keys()) if isinstance(payload, dict) else 'non-dict'}")
        await handle_incoming(payload)
        logger.info("WhatsApp webhook processed successfully")
        return {"success": True, "message": "Processed"}
    except Exception as e:
        logger.error(f"Failed to process WhatsApp webhook: {e}")
        raise
