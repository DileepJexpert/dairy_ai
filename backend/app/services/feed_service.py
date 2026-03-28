import logging
import uuid
from datetime import date, timedelta
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.feed import FeedPlan
from app.models.cattle import Cattle

logger = logging.getLogger("dairy_ai.services.feed")

# Predefined nutrition requirements
NUTRITION_TABLE = {
    "maintenance": {"protein_g": 350, "energy_mj": 40, "calcium_g": 20},
    "lactating_low": {"protein_g": 600, "energy_mj": 70, "calcium_g": 40},
    "lactating_high": {"protein_g": 900, "energy_mj": 100, "calcium_g": 60},
    "dry": {"protein_g": 400, "energy_mj": 45, "calcium_g": 25},
}

FEED_INGREDIENTS = [
    {"ingredient": "Green Fodder (Napier)", "cost_per_kg": 3.0, "protein_per_kg": 15, "energy_per_kg": 8, "calcium_per_kg": 4},
    {"ingredient": "Dry Fodder (Paddy Straw)", "cost_per_kg": 2.0, "protein_per_kg": 5, "energy_per_kg": 6, "calcium_per_kg": 2},
    {"ingredient": "Concentrate Feed", "cost_per_kg": 25.0, "protein_per_kg": 180, "energy_per_kg": 50, "calcium_per_kg": 10},
    {"ingredient": "Cotton Seed Cake", "cost_per_kg": 30.0, "protein_per_kg": 220, "energy_per_kg": 45, "calcium_per_kg": 5},
    {"ingredient": "Mineral Mixture", "cost_per_kg": 60.0, "protein_per_kg": 0, "energy_per_kg": 0, "calcium_per_kg": 200},
]


async def generate_feed_plan(db: AsyncSession, cattle_id: uuid.UUID) -> FeedPlan:
    logger.info(f"generate_feed_plan called | cattle_id={cattle_id}")

    logger.debug(f"Fetching cattle details from database | cattle_id={cattle_id}")
    result = await db.execute(select(Cattle).where(Cattle.id == cattle_id))
    cattle = result.scalar_one_or_none()
    if not cattle:
        logger.warning(f"Cattle not found | cattle_id={cattle_id}")
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Cattle not found")

    # Determine nutrition requirement
    weight = cattle.weight_kg or 350
    status = cattle.status.value if hasattr(cattle.status, 'value') else cattle.status
    logger.debug(f"Cattle details | cattle_id={cattle_id}, weight={weight}kg, status={status}, lactation_number={cattle.lactation_number}")

    if status == "dry":
        req = NUTRITION_TABLE["dry"]
        nutrition_category = "dry"
    elif cattle.lactation_number and cattle.lactation_number > 0:
        req = NUTRITION_TABLE["lactating_low"]
        nutrition_category = "lactating_low"
    else:
        req = NUTRITION_TABLE["maintenance"]
        nutrition_category = "maintenance"
    logger.debug(f"Nutrition category selected: {nutrition_category} | requirements={req}")

    # Simple plan: green fodder + dry fodder + concentrate + mineral
    plan = [
        {"ingredient": "Green Fodder (Napier)", "quantity_kg": round(weight * 0.05, 1), "cost_per_kg": 3.0},
        {"ingredient": "Dry Fodder (Paddy Straw)", "quantity_kg": round(weight * 0.02, 1), "cost_per_kg": 2.0},
        {"ingredient": "Concentrate Feed", "quantity_kg": round(max(2.0, weight * 0.005), 1), "cost_per_kg": 25.0},
        {"ingredient": "Mineral Mixture", "quantity_kg": 0.05, "cost_per_kg": 60.0},
    ]

    total_cost = sum(item["quantity_kg"] * item["cost_per_kg"] for item in plan)
    logger.debug(f"Feed plan calculated | cattle_id={cattle_id}, items={len(plan)}, total_cost=₹{round(total_cost, 2)}/day")
    for item in plan:
        logger.debug(f"  - {item['ingredient']}: {item['quantity_kg']}kg @ ₹{item['cost_per_kg']}/kg = ₹{round(item['quantity_kg'] * item['cost_per_kg'], 2)}")

    logger.debug(f"Saving feed plan to database | cattle_id={cattle_id}")
    feed_plan = FeedPlan(
        cattle_id=cattle_id,
        plan=plan,
        total_cost_per_day=round(total_cost, 2),
        nutrition_score=75.0,
        created_by="ai",
        valid_from=date.today(),
        valid_to=date.today() + timedelta(days=30),
    )
    db.add(feed_plan)
    await db.flush()

    logger.info(f"Feed plan created | plan_id={feed_plan.id}, cattle_id={cattle_id}, cost=₹{feed_plan.total_cost_per_day}/day, valid_from={feed_plan.valid_from}, valid_to={feed_plan.valid_to}")
    return feed_plan


async def get_current_feed_plan(db: AsyncSession, cattle_id: uuid.UUID) -> FeedPlan | None:
    logger.debug(f"get_current_feed_plan called | cattle_id={cattle_id}")
    result = await db.execute(
        select(FeedPlan)
        .where(FeedPlan.cattle_id == cattle_id)
        .order_by(FeedPlan.created_at.desc())
        .limit(1)
    )
    plan = result.scalar_one_or_none()
    if plan:
        logger.debug(f"Current feed plan found | plan_id={plan.id}, cattle_id={cattle_id}, cost=₹{plan.total_cost_per_day}/day")
    else:
        logger.debug(f"No feed plan found for cattle_id={cattle_id}")
    return plan
