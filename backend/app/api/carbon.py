import uuid
import logging
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo
from app.services import carbon_service

logger = logging.getLogger("dairy_ai.api.carbon")

router = APIRouter(prefix="/carbon", tags=["Carbon Footprint"])


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found. Create profile first.")
    return farmer.id


async def _get_farmer(db: AsyncSession, user: User):
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found. Create profile first.")
    return farmer


@router.post("/calculate", status_code=201)
async def calculate_footprint(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Calculate carbon footprint for a given period."""
    logger.info(f"POST /carbon/calculate called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)

    required_fields = ["period_start", "period_end"]
    for field in required_fields:
        if field not in data:
            raise HTTPException(status_code=422, detail=f"Missing required field: {field}")

    try:
        period_start = data["period_start"]
        period_end = data["period_end"]
        if isinstance(period_start, str):
            period_start = date.fromisoformat(period_start)
        if isinstance(period_end, str):
            period_end = date.fromisoformat(period_end)
    except (ValueError, TypeError) as e:
        raise HTTPException(status_code=422, detail=f"Invalid date format: {e}")

    try:
        record = await carbon_service.calculate_footprint(db, farmer_id, period_start, period_end)
        logger.info(f"Footprint calculated | record_id={record.id} | co2_per_litre={record.co2_per_litre}")
        return {
            "success": True,
            "data": {
                "id": str(record.id),
                "period_start": str(record.period_start),
                "period_end": str(record.period_end),
                "total_cattle": record.total_cattle,
                "total_milk_litres": record.total_milk_litres,
                "breakdown": {
                    "enteric_methane_kg": record.enteric_methane_kg,
                    "manure_methane_kg": record.manure_methane_kg,
                    "feed_production_co2_kg": record.feed_production_co2_kg,
                    "energy_co2_kg": record.energy_co2_kg,
                    "transport_co2_kg": record.transport_co2_kg,
                },
                "total_co2_equivalent_kg": record.total_co2_equivalent_kg,
                "co2_per_litre": record.co2_per_litre,
                "carbon_credits_potential_tonnes": record.carbon_credits_potential,
                "methodology": record.methodology,
            },
            "message": (
                f"Carbon footprint calculated: {record.total_co2_equivalent_kg:.1f} kg CO2e total, "
                f"{record.co2_per_litre:.2f} kg CO2e per litre of milk"
            ),
        }
    except ValueError as e:
        logger.warning(f"Invalid input: {e}")
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        logger.error(f"Failed to calculate footprint: {e}")
        raise HTTPException(status_code=500, detail="Failed to calculate carbon footprint")


@router.get("/history")
async def get_footprint_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get farmer's carbon footprint history over time."""
    logger.info(f"GET /carbon/history called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)

    try:
        history = await carbon_service.get_farmer_footprint_history(db, farmer_id)
        logger.info(f"Footprint history retrieved | farmer_id={farmer_id} | records={len(history)}")
        return {
            "success": True,
            "data": history,
            "message": f"Carbon footprint history with {len(history)} records",
        }
    except Exception as e:
        logger.error(f"Failed to get footprint history: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve footprint history")


@router.get("/benchmark")
async def get_benchmark(
    district: str | None = Query(None, description="District for local comparison"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Compare farmer's footprint against benchmarks (district, national, global)."""
    logger.info(f"GET /carbon/benchmark called | user_id={current_user.id} | district={district}")
    farmer_id = await _get_farmer_id(db, current_user)

    try:
        # Get farmer's latest footprint for comparison
        history = await carbon_service.get_farmer_footprint_history(db, farmer_id)
        farmer_co2_per_litre = None
        if history:
            farmer_co2_per_litre = history[-1].get("co2_per_litre")

        benchmark = await carbon_service.get_benchmark(db, district=district)
        benchmark["farmer_co2_per_litre"] = farmer_co2_per_litre

        # Add comparison text
        if farmer_co2_per_litre is not None:
            india_avg = benchmark["benchmarks"]["india_average_kg_co2_per_litre"]
            if farmer_co2_per_litre < india_avg:
                benchmark["comparison"] = (
                    f"Your footprint ({farmer_co2_per_litre:.2f} kg CO2e/L) is BELOW "
                    f"the India average ({india_avg} kg CO2e/L). Great work!"
                )
            else:
                benchmark["comparison"] = (
                    f"Your footprint ({farmer_co2_per_litre:.2f} kg CO2e/L) is ABOVE "
                    f"the India average ({india_avg} kg CO2e/L). See suggestions for improvement."
                )
        else:
            benchmark["comparison"] = "Calculate your footprint first to compare against benchmarks."

        logger.info(f"Benchmark retrieved | farmer_co2={farmer_co2_per_litre}")
        return {
            "success": True,
            "data": benchmark,
            "message": "Carbon footprint benchmarks",
        }
    except Exception as e:
        logger.error(f"Failed to get benchmark: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve benchmarks")


@router.get("/suggestions")
async def get_suggestions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get personalized carbon reduction suggestions."""
    logger.info(f"GET /carbon/suggestions called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)

    try:
        suggestions = await carbon_service.suggest_reductions(db, farmer_id)
        logger.info(f"Suggestions generated | farmer_id={farmer_id} | count={len(suggestions)}")
        return {
            "success": True,
            "data": suggestions,
            "message": f"{len(suggestions)} carbon reduction suggestions",
        }
    except Exception as e:
        logger.error(f"Failed to get suggestions: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate reduction suggestions")


@router.post("/actions", status_code=201)
async def record_reduction_action(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a carbon reduction action taken by the farmer."""
    logger.info(f"POST /carbon/actions called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)

    required_fields = ["action_type", "start_date"]
    for field in required_fields:
        if field not in data:
            raise HTTPException(status_code=422, detail=f"Missing required field: {field}")

    try:
        action = await carbon_service.record_reduction_action(db, farmer_id, data)
        logger.info(f"Reduction action recorded | action_id={action.id}")
        return {
            "success": True,
            "data": {
                "id": str(action.id),
                "action_type": action.action_type.value,
                "description": action.description,
                "estimated_reduction_kg_co2": action.estimated_reduction_kg_co2,
                "start_date": str(action.start_date),
                "is_verified": action.is_verified,
            },
            "message": (
                f"Reduction action '{action.action_type.value}' recorded. "
                f"Estimated reduction: {action.estimated_reduction_kg_co2:.1f} kg CO2e/year."
            ),
        }
    except ValueError as e:
        logger.warning(f"Invalid input: {e}")
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        logger.error(f"Failed to record reduction action: {e}")
        raise HTTPException(status_code=500, detail="Failed to record reduction action")


@router.get("/credits")
async def get_carbon_credits(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Estimate potential carbon credit value for the farmer."""
    logger.info(f"GET /carbon/credits called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)

    try:
        credits = await carbon_service.estimate_carbon_credits(db, farmer_id)
        logger.info(
            f"Carbon credits estimated | farmer_id={farmer_id} "
            f"| tonnes={credits['total_reduction_tonnes_co2']}"
        )
        return {
            "success": True,
            "data": credits,
            "message": (
                f"Potential carbon credits: {credits['total_reduction_tonnes_co2']:.3f} tonnes CO2e "
                f"(value: INR {credits['potential_credit_value_inr']['min']:.0f} - "
                f"{credits['potential_credit_value_inr']['max']:.0f})"
            ),
        }
    except Exception as e:
        logger.error(f"Failed to estimate carbon credits: {e}")
        raise HTTPException(status_code=500, detail="Failed to estimate carbon credits")
