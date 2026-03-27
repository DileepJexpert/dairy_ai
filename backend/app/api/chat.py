import uuid
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
    farmer = await farmer_repo.get_by_user_id(db, current_user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")

    cattle_id = uuid.UUID(data.cattle_id)
    cattle = await cattle_repo.get_by_id(db, cattle_id)
    if not cattle or cattle.farmer_id != farmer.id:
        raise HTTPException(status_code=404, detail="Cattle not found")

    result = await run_triage(db, farmer.id, cattle_id, data.symptoms, data.photo_urls)
    return {"success": True, "data": result, "message": "Triage complete"}


@router.post("/chat/message")
async def chat_message(
    data: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    context = None
    if data.cattle_id:
        cattle = await cattle_repo.get_by_id(db, uuid.UUID(data.cattle_id))
        if cattle:
            breed = cattle.breed.value if hasattr(cattle.breed, 'value') else cattle.breed
            status = cattle.status.value if hasattr(cattle.status, 'value') else cattle.status
            context = f"Cattle: {cattle.name or 'Unknown'}, Breed: {breed}, Status: {status}"

    response = await LLMService.chat(str(current_user.id), data.message, context)
    return {"success": True, "data": {"response": response}, "message": "Chat response"}
