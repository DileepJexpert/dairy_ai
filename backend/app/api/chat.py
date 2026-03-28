import uuid
import logging
from pydantic import BaseModel
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo
from app.services.triage_service import run_triage
from app.services.llm_service import LLMService

logger = logging.getLogger("dairy_ai.api.chat")

router = APIRouter(tags=["chat"])


class TriageRequest(BaseModel):
    cattle_id: str
    symptoms: str
    photo_urls: Optional[list[str]] = None


class ChatRequest(BaseModel):
    message: str
    cattle_id: Optional[str] = None


@router.post("/triage")
async def triage(
    data: TriageRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /triage called | user_id={current_user.id} | cattle_id={data.cattle_id} | symptoms_length={len(data.symptoms)}")
    logger.debug(f"Triage symptoms: {data.symptoms[:200]}...")  # Log first 200 chars of symptoms
    logger.debug(f"Photo URLs provided: {len(data.photo_urls) if data.photo_urls else 0}")

    logger.debug(f"Looking up farmer profile for user_id={current_user.id}")
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found for triage | user_id={current_user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")

    cattle_id = uuid.UUID(data.cattle_id)
    logger.debug(f"Verifying cattle ownership | cattle_id={cattle_id} | farmer_id={farmer.id}")
    cattle = await cattle_repo.get_by_id(db, cattle_id)
    if not cattle or cattle.farmer_id != farmer.id:
        logger.warning(f"Cattle not found or ownership mismatch for triage | cattle_id={data.cattle_id} | farmer_id={farmer.id}")
        raise HTTPException(status_code=404, detail="Cattle not found")

    logger.info(f"Running triage | farmer_id={farmer.id} | cattle_id={cattle_id}")
    try:
        result = await run_triage(db, farmer.id, cattle_id, data.symptoms, data.photo_urls)
        logger.info(f"Triage complete | cattle_id={cattle_id} | severity={result.get('severity', 'unknown') if isinstance(result, dict) else 'unknown'}")
        return {"success": True, "data": result, "message": "Triage complete"}
    except Exception as e:
        logger.error(f"Triage failed for cattle_id={cattle_id}: {e}")
        raise


@router.post("/chat/message")
async def chat_message(
    data: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /chat/message called | user_id={current_user.id} | message_length={len(data.message)} | has_cattle_id={bool(data.cattle_id)}")
    logger.debug(f"Chat message preview: {data.message[:100]}...")  # Log first 100 chars

    context = None
    if data.cattle_id:
        logger.debug(f"Looking up cattle context | cattle_id={data.cattle_id}")
        cattle = await cattle_repo.get_by_id(db, uuid.UUID(data.cattle_id))
        if cattle:
            breed = cattle.breed.value if hasattr(cattle.breed, 'value') else cattle.breed
            status = cattle.status.value if hasattr(cattle.status, 'value') else cattle.status
            context = f"Cattle: {cattle.name or 'Unknown'}, Breed: {breed}, Status: {status}"
            logger.debug(f"Cattle context built | cattle_id={data.cattle_id} | context={context}")
        else:
            logger.warning(f"Cattle not found for chat context | cattle_id={data.cattle_id}")

    logger.debug(f"Calling LLMService.chat | user_id={current_user.id} | has_context={bool(context)}")
    try:
        response = await LLMService.chat(str(current_user.id), data.message, context)
        logger.info(f"Chat response generated | user_id={current_user.id} | response_length={len(response) if response else 0}")
        return {"success": True, "data": {"response": response}, "message": "Chat response"}
    except Exception as e:
        logger.error(f"Chat failed for user_id={current_user.id}: {e}")
        raise
