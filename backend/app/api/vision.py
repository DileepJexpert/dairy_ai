"""Computer Vision API — phone camera-based cattle health assessment."""
import logging
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.ml import cattle_vision

logger = logging.getLogger("dairy_ai.api.vision")
router = APIRouter(prefix="/vision", tags=["Computer Vision"])


class BodyConditionRequest(BaseModel):
    cattle_id: str | None = None
    image_url: str | None = None
    pin_bones_visible: bool = False
    ribs_visible: bool = False
    hip_bones_prominent: bool = False
    tailhead_sunken: bool = False
    spine_visible: bool = False
    fat_deposits_visible: bool = False
    rounded_appearance: bool = False


class SkinConditionRequest(BaseModel):
    cattle_id: str | None = None
    image_url: str | None = None
    affected_area: str = "body"
    lesion_type: str = ""
    distribution: str = "localized"
    color: str = ""
    itching: bool = False
    hair_loss: bool = False
    ticks_visible: bool = False


class LamenessRequest(BaseModel):
    cattle_id: str | None = None
    gait_description: str = ""
    affected_limb: str | None = None
    swelling: bool = False
    heat: bool = False
    hoof_condition: str = ""


class UdderHealthRequest(BaseModel):
    cattle_id: str | None = None
    image_url: str | None = None
    swelling: bool = False
    heat: bool = False
    asymmetry: bool = False
    abnormal_milk: bool = False
    teat_damage: bool = False
    affected_quarter: str = ""


class FecalScoreRequest(BaseModel):
    cattle_id: str | None = None
    image_url: str | None = None
    consistency: str = "normal"


@router.post("/body-condition")
async def assess_body_condition(
    req: BodyConditionRequest,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    result = cattle_vision.analyze_body_condition(
        image_url=req.image_url,
        manual_observations=req.model_dump(exclude={"cattle_id", "image_url"}),
    )
    return {
        "success": True,
        "data": {
            "score": result.score,
            "category": result.category,
            "confidence": result.confidence,
            "recommendations": result.recommendations,
        },
        "message": f"Body condition score: {result.score} ({result.category})",
    }


@router.post("/skin-condition")
async def assess_skin_condition(
    req: SkinConditionRequest,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    result = cattle_vision.analyze_skin_condition(
        image_url=req.image_url,
        affected_area=req.affected_area,
        manual_observations=req.model_dump(exclude={"cattle_id", "image_url", "affected_area"}),
    )
    return {
        "success": True,
        "data": {
            "conditions": [
                {"name": c.name, "probability": c.probability, "description": c.description,
                 "treatment": c.treatment, "urgency": c.urgency}
                for c in result.conditions
            ],
            "severity": result.severity,
            "recommendations": result.recommendations,
        },
        "message": f"Skin analysis: {result.conditions[0].name if result.conditions else 'No conditions detected'}",
    }


@router.post("/lameness")
async def assess_lameness(
    req: LamenessRequest,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    result = cattle_vision.analyze_lameness(
        gait_description=req.gait_description,
        affected_limb=req.affected_limb,
        manual_observations=req.model_dump(exclude={"cattle_id", "gait_description", "affected_limb"}),
    )
    return {
        "success": True,
        "data": {
            "score": result.score,
            "category": result.category,
            "possible_causes": [
                {"name": c.name, "probability": c.probability, "description": c.description,
                 "treatment": c.treatment, "urgency": c.urgency}
                for c in result.possible_causes
            ],
            "recommendations": result.recommendations,
        },
        "message": f"Lameness score: {result.score}/5 ({result.category})",
    }


@router.post("/udder-health")
async def assess_udder_health(
    req: UdderHealthRequest,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    result = cattle_vision.analyze_udder_health(
        image_url=req.image_url,
        manual_observations=req.model_dump(exclude={"cattle_id", "image_url"}),
    )
    return {
        "success": True,
        "data": {
            "health_score": result.health_score,
            "quarter_assessment": result.quarter_assessment,
            "conditions": result.conditions,
            "recommendations": result.recommendations,
        },
        "message": f"Udder health score: {result.health_score}/10",
    }


@router.post("/fecal-score")
async def assess_fecal_score(
    req: FecalScoreRequest,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    result = cattle_vision.analyze_fecal_score(
        image_url=req.image_url,
        manual_observations=req.model_dump(exclude={"cattle_id", "image_url"}),
    )
    return {
        "success": True,
        "data": {
            "score": result.score,
            "interpretation": result.interpretation,
            "possible_causes": result.possible_causes,
            "action_needed": result.action_needed,
        },
        "message": f"Fecal score: {result.score}/5 — {result.interpretation}",
    }
