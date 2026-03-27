import uuid
from datetime import date, timedelta
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.feed import FeedPlan
from app.models.cattle import Cattle

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
    result = await db.execute(select(Cattle).where(Cattle.id == cattle_id))
    cattle = result.scalar_one_or_none()
    if not cattle:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Cattle not found")

    # Determine nutrition requirement
    weight = cattle.weight_kg or 350
    status = cattle.status.value if hasattr(cattle.status, 'value') else cattle.status

    if status == "dry":
        req = NUTRITION_TABLE["dry"]
    elif cattle.lactation_number and cattle.lactation_number > 0:
        req = NUTRITION_TABLE["lactating_low"]
    else:
        req = NUTRITION_TABLE["maintenance"]

    # Simple plan: green fodder + dry fodder + concentrate + mineral
    plan = [
        {"ingredient": "Green Fodder (Napier)", "quantity_kg": round(weight * 0.05, 1), "cost_per_kg": 3.0},
        {"ingredient": "Dry Fodder (Paddy Straw)", "quantity_kg": round(weight * 0.02, 1), "cost_per_kg": 2.0},
        {"ingredient": "Concentrate Feed", "quantity_kg": round(max(2.0, weight * 0.005), 1), "cost_per_kg": 25.0},
        {"ingredient": "Mineral Mixture", "quantity_kg": 0.05, "cost_per_kg": 60.0},
    ]

    total_cost = sum(item["quantity_kg"] * item["cost_per_kg"] for item in plan)

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
    return feed_plan


async def get_current_feed_plan(db: AsyncSession, cattle_id: uuid.UUID) -> FeedPlan | None:
    result = await db.execute(
        select(FeedPlan)
        .where(FeedPlan.cattle_id == cattle_id)
        .order_by(FeedPlan.created_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()
