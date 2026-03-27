from fastapi import APIRouter, Request, Query, HTTPException
from app.config import get_settings
from app.services.whatsapp_service import handle_incoming

router = APIRouter(prefix="/whatsapp", tags=["whatsapp"])


@router.get("/webhook")
async def verify_webhook(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_challenge: str = Query(None, alias="hub.challenge"),
    hub_verify_token: str = Query(None, alias="hub.verify_token"),
) -> str:
    """Meta webhook verification endpoint."""
    settings = get_settings()
    if hub_mode == "subscribe" and hub_verify_token == settings.WHATSAPP_VERIFY_TOKEN:
        return hub_challenge or ""
    raise HTTPException(status_code=403, detail="Verification failed")


@router.post("/webhook")
async def receive_webhook(request: Request) -> dict:
    """Receive incoming WhatsApp messages."""
    payload = await request.json()
    await handle_incoming(payload)
    return {"success": True, "message": "Processed"}
