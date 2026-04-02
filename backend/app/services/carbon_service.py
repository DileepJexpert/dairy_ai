import logging
import uuid
from datetime import date, datetime, timezone
from typing import Optional

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.carbon import CarbonRecord, CarbonReductionAction, CarbonActionType
from app.models.cattle import Cattle, Breed, CattleStatus
from app.models.milk import MilkRecord
from app.models.feed import FeedPlan

logger = logging.getLogger("dairy_ai.services.carbon")

# ----- IPCC Tier 1 Emission Factors (India-specific) -----

# Enteric methane: kg CH4 per head per year
ENTERIC_METHANE_FACTORS: dict[str, float] = {
    # Crossbred dairy cattle (HF, Jersey crosses)
    "hf_crossbred": 46.0,
    "jersey_crossbred": 46.0,
    # Indigenous breeds (lower body weight, lower intake)
    "gir": 33.0,
    "sahiwal": 33.0,
    # Buffalo
    "murrah": 55.0,
    # Default for unknown breeds
    "other": 40.0,
}

# Manure methane: kg CH4 per head per year (India, dry climate management)
MANURE_METHANE_PER_HEAD_YEAR = 5.0

# GWP: CH4 to CO2 equivalent multiplier (IPCC AR5, 100-year)
CH4_TO_CO2E_GWP = 28.0

# Feed production: kg CO2 per kg dry matter
FEED_CO2_PER_KG_DM = 0.5

# Transport: kg CO2 per km per trip (average milk collection vehicle)
TRANSPORT_CO2_PER_KM = 0.15

# Default collection center distance (km, one way) if not provided
DEFAULT_COLLECTION_DISTANCE_KM = 5.0

# Average milk yield per day (litres) used as fallback
DEFAULT_MILK_YIELD_PER_DAY = 8.0

# Benchmark values: kg CO2e per litre of milk
BENCHMARKS = {
    "india_average": 2.5,
    "global_average": 2.4,
    "eu_average": 1.4,
    "best_practice_india": 1.8,
}

# Carbon credit price range (INR per tonne CO2e)
CARBON_CREDIT_PRICE_MIN = 500.0
CARBON_CREDIT_PRICE_MAX = 1500.0
CARBON_CREDIT_PRICE_MID = 1000.0

# Estimated reduction per action type (kg CO2e per year)
REDUCTION_ESTIMATES: dict[str, dict] = {
    "biogas_plant": {
        "description": "Install biogas plant for manure management",
        "estimated_reduction_kg_co2_per_year": 2500.0,
        "explanation": "Captures methane from manure that would otherwise be released. Produces cooking gas and fertilizer.",
    },
    "improved_feed": {
        "description": "Switch to improved feed with lower methane potential",
        "estimated_reduction_kg_co2_per_year": 800.0,
        "explanation": "Better quality feed improves digestibility, reducing enteric methane by 10-15%.",
    },
    "manure_composting": {
        "description": "Implement systematic manure composting",
        "estimated_reduction_kg_co2_per_year": 600.0,
        "explanation": "Aerobic composting produces less methane than anaerobic decomposition.",
    },
    "solar_energy": {
        "description": "Install solar panels for farm energy needs",
        "estimated_reduction_kg_co2_per_year": 1500.0,
        "explanation": "Replaces grid electricity (coal-heavy in India) with clean solar energy.",
    },
    "tree_planting": {
        "description": "Plant trees on farm for carbon sequestration",
        "estimated_reduction_kg_co2_per_year": 500.0,
        "explanation": "Each mature tree absorbs ~20-25 kg CO2 per year. Provides shade for cattle too.",
    },
    "methane_inhibitor": {
        "description": "Use feed additive methane inhibitor (e.g., 3-NOP)",
        "estimated_reduction_kg_co2_per_year": 1200.0,
        "explanation": "Feed additives like 3-NOP can reduce enteric methane by 20-30%.",
    },
}


async def calculate_footprint(
    db: AsyncSession,
    farmer_id: uuid.UUID,
    period_start: date,
    period_end: date,
) -> CarbonRecord:
    """Auto-calculate carbon footprint from cattle, milk, and feed data."""
    logger.info(
        f"calculate_footprint called | farmer_id={farmer_id} "
        f"| period={period_start} to {period_end}"
    )

    period_days = (period_end - period_start).days
    if period_days <= 0:
        raise ValueError("period_end must be after period_start")
    period_fraction = period_days / 365.0

    # 1. Get active cattle for this farmer
    cattle_query = select(Cattle).where(
        and_(
            Cattle.farmer_id == farmer_id,
            Cattle.status == CattleStatus.active,
        )
    )
    result = await db.execute(cattle_query)
    cattle_list = list(result.scalars().all())
    total_cattle = len(cattle_list)

    logger.info(f"Found {total_cattle} active cattle for farmer_id={farmer_id}")

    # 2. Calculate enteric methane per breed
    total_enteric_ch4_kg = 0.0
    for c in cattle_list:
        breed_key = c.breed.value if hasattr(c.breed, "value") else str(c.breed)
        factor = ENTERIC_METHANE_FACTORS.get(breed_key, ENTERIC_METHANE_FACTORS["other"])
        total_enteric_ch4_kg += factor * period_fraction

    enteric_methane_co2e_kg = total_enteric_ch4_kg * CH4_TO_CO2E_GWP

    # 3. Manure methane
    manure_ch4_kg = total_cattle * MANURE_METHANE_PER_HEAD_YEAR * period_fraction
    manure_methane_co2e_kg = manure_ch4_kg * CH4_TO_CO2E_GWP

    # 4. Total milk production in the period
    milk_query = select(func.coalesce(func.sum(MilkRecord.quantity_litres), 0.0)).where(
        and_(
            MilkRecord.cattle_id.in_([c.id for c in cattle_list]) if cattle_list else False,
            MilkRecord.date >= period_start,
            MilkRecord.date <= period_end,
        )
    )
    if cattle_list:
        milk_result = await db.execute(milk_query)
        total_milk_litres = float(milk_result.scalar() or 0.0)
    else:
        total_milk_litres = 0.0

    # Fallback estimate if no milk records
    if total_milk_litres == 0.0 and total_cattle > 0:
        total_milk_litres = total_cattle * DEFAULT_MILK_YIELD_PER_DAY * period_days * 0.7  # 70% are milking
        logger.info(f"Using estimated milk production: {total_milk_litres:.1f} litres")

    # 5. Feed production CO2
    # Try to get feed plan data, otherwise use default
    feed_co2_kg = 0.0
    if cattle_list:
        feed_query = select(FeedPlan).where(
            FeedPlan.cattle_id.in_([c.id for c in cattle_list])
        )
        feed_result = await db.execute(feed_query)
        feed_plans = list(feed_result.scalars().all())

        if feed_plans:
            # Estimate from feed plans: average cost_per_day correlates with feed quantity
            # Rough estimate: 10 kg DM/day per animal for dairy cattle
            avg_dm_per_day = 10.0  # kg dry matter per cattle per day
            feed_co2_kg = total_cattle * avg_dm_per_day * period_days * FEED_CO2_PER_KG_DM
        else:
            # Default: 10 kg DM/day
            avg_dm_per_day = 10.0
            feed_co2_kg = total_cattle * avg_dm_per_day * period_days * FEED_CO2_PER_KG_DM

    # 6. Energy CO2 (estimate: electricity for milking machines, cooling)
    # Average small Indian dairy farm: ~5 kWh/day, emission factor ~0.82 kg CO2/kWh (India grid)
    energy_kwh_per_day = 5.0 if total_cattle > 0 else 0.0
    energy_co2_kg = energy_kwh_per_day * period_days * 0.82

    # 7. Transport CO2
    # Assume daily milk collection trip
    collection_trips = period_days
    transport_co2_kg = collection_trips * DEFAULT_COLLECTION_DISTANCE_KM * 2 * TRANSPORT_CO2_PER_KM

    # 8. Total CO2 equivalent
    total_co2e_kg = (
        enteric_methane_co2e_kg
        + manure_methane_co2e_kg
        + feed_co2_kg
        + energy_co2_kg
        + transport_co2_kg
    )

    # 9. CO2 per litre
    co2_per_litre = total_co2e_kg / total_milk_litres if total_milk_litres > 0 else 0.0

    # 10. Carbon credits potential (tonnes CO2e that could be offset through reduction actions)
    # Estimate: if farmer adopted best practices, they could reduce by ~30%
    potential_reduction_kg = total_co2e_kg * 0.30
    carbon_credits_potential = potential_reduction_kg / 1000.0  # Convert to tonnes

    # Store the record
    record = CarbonRecord(
        farmer_id=farmer_id,
        period_start=period_start,
        period_end=period_end,
        total_cattle=total_cattle,
        total_milk_litres=round(total_milk_litres, 2),
        enteric_methane_kg=round(enteric_methane_co2e_kg, 2),
        manure_methane_kg=round(manure_methane_co2e_kg, 2),
        feed_production_co2_kg=round(feed_co2_kg, 2),
        energy_co2_kg=round(energy_co2_kg, 2),
        transport_co2_kg=round(transport_co2_kg, 2),
        total_co2_equivalent_kg=round(total_co2e_kg, 2),
        co2_per_litre=round(co2_per_litre, 2),
        carbon_credits_potential=round(carbon_credits_potential, 4),
        methodology="IPCC_2019",
    )
    db.add(record)
    await db.flush()

    logger.info(
        f"Carbon footprint calculated | farmer_id={farmer_id} | cattle={total_cattle} "
        f"| total_co2e={total_co2e_kg:.1f} kg | co2_per_litre={co2_per_litre:.2f} kg "
        f"| credits_potential={carbon_credits_potential:.3f} tonnes"
    )
    return record


async def get_farmer_footprint_history(
    db: AsyncSession,
    farmer_id: uuid.UUID,
) -> list[dict]:
    """Get trend of farmer's carbon footprint over time."""
    logger.info(f"get_farmer_footprint_history called | farmer_id={farmer_id}")

    query = select(CarbonRecord).where(
        CarbonRecord.farmer_id == farmer_id
    ).order_by(CarbonRecord.period_start.asc())

    result = await db.execute(query)
    records = list(result.scalars().all())

    history = [
        {
            "id": str(r.id),
            "period_start": str(r.period_start),
            "period_end": str(r.period_end),
            "total_cattle": r.total_cattle,
            "total_milk_litres": r.total_milk_litres,
            "enteric_methane_kg": r.enteric_methane_kg,
            "manure_methane_kg": r.manure_methane_kg,
            "feed_production_co2_kg": r.feed_production_co2_kg,
            "energy_co2_kg": r.energy_co2_kg,
            "transport_co2_kg": r.transport_co2_kg,
            "total_co2_equivalent_kg": r.total_co2_equivalent_kg,
            "co2_per_litre": r.co2_per_litre,
            "carbon_credits_potential": r.carbon_credits_potential,
            "methodology": r.methodology,
            "created_at": str(r.created_at),
        }
        for r in records
    ]

    logger.info(f"Footprint history retrieved | farmer_id={farmer_id} | records={len(history)}")
    return history


async def get_benchmark(
    db: AsyncSession,
    district: Optional[str] = None,
) -> dict:
    """Get CO2/litre benchmarks: district average vs national vs global."""
    logger.info(f"get_benchmark called | district={district}")

    result_data = {
        "benchmarks": {
            "india_average_kg_co2_per_litre": BENCHMARKS["india_average"],
            "global_average_kg_co2_per_litre": BENCHMARKS["global_average"],
            "eu_average_kg_co2_per_litre": BENCHMARKS["eu_average"],
            "best_practice_india_kg_co2_per_litre": BENCHMARKS["best_practice_india"],
        },
        "district_average": None,
        "district": district,
    }

    if district:
        # Calculate district average from existing records
        # Join farmer to get district, then average co2_per_litre
        from app.models.farmer import Farmer

        query = (
            select(func.avg(CarbonRecord.co2_per_litre))
            .join(Farmer, Farmer.id == CarbonRecord.farmer_id)
            .where(
                and_(
                    Farmer.district == district,
                    CarbonRecord.co2_per_litre > 0,
                )
            )
        )
        avg_result = await db.execute(query)
        district_avg = avg_result.scalar()

        if district_avg is not None:
            result_data["district_average"] = round(float(district_avg), 2)
            logger.info(f"District average for {district}: {district_avg:.2f} kg CO2e/litre")
        else:
            logger.info(f"No data available for district: {district}")

    logger.info(f"Benchmark data retrieved | district={district}")
    return result_data


async def suggest_reductions(
    db: AsyncSession,
    farmer_id: uuid.UUID,
) -> list[dict]:
    """Analyze current footprint and suggest specific reduction actions."""
    logger.info(f"suggest_reductions called | farmer_id={farmer_id}")

    # Get latest carbon record
    query = select(CarbonRecord).where(
        CarbonRecord.farmer_id == farmer_id
    ).order_by(CarbonRecord.created_at.desc()).limit(1)

    result = await db.execute(query)
    latest_record = result.scalar_one_or_none()

    # Get already adopted actions
    actions_query = select(CarbonReductionAction).where(
        CarbonReductionAction.farmer_id == farmer_id
    )
    actions_result = await db.execute(actions_query)
    existing_actions = {a.action_type.value for a in actions_result.scalars().all()}

    suggestions = []
    for action_key, action_info in REDUCTION_ESTIMATES.items():
        if action_key in existing_actions:
            continue  # Skip already adopted actions

        priority = "medium"
        estimated_reduction = action_info["estimated_reduction_kg_co2_per_year"]

        # Prioritize based on current footprint breakdown
        if latest_record:
            if action_key in ("biogas_plant", "manure_composting") and latest_record.manure_methane_kg > 500:
                priority = "high"
            elif action_key == "improved_feed" and latest_record.enteric_methane_kg > 2000:
                priority = "high"
            elif action_key == "methane_inhibitor" and latest_record.enteric_methane_kg > 3000:
                priority = "high"
            elif action_key == "solar_energy" and latest_record.energy_co2_kg > 500:
                priority = "high"

        # Estimate financial benefit from carbon credits
        credit_value_min = (estimated_reduction / 1000.0) * CARBON_CREDIT_PRICE_MIN
        credit_value_max = (estimated_reduction / 1000.0) * CARBON_CREDIT_PRICE_MAX

        suggestions.append({
            "action_type": action_key,
            "description": action_info["description"],
            "explanation": action_info["explanation"],
            "estimated_reduction_kg_co2_per_year": estimated_reduction,
            "estimated_reduction_tonnes_per_year": round(estimated_reduction / 1000.0, 3),
            "priority": priority,
            "potential_carbon_credit_value_inr": {
                "min": round(credit_value_min, 2),
                "max": round(credit_value_max, 2),
            },
            "already_adopted": False,
        })

    # Sort by priority (high first), then by reduction potential
    priority_order = {"high": 0, "medium": 1, "low": 2}
    suggestions.sort(key=lambda x: (priority_order.get(x["priority"], 1), -x["estimated_reduction_kg_co2_per_year"]))

    logger.info(f"Suggestions generated | farmer_id={farmer_id} | count={len(suggestions)}")
    return suggestions


async def record_reduction_action(
    db: AsyncSession,
    farmer_id: uuid.UUID,
    data: dict,
) -> CarbonReductionAction:
    """Log a carbon reduction action taken by the farmer."""
    logger.info(f"record_reduction_action called | farmer_id={farmer_id} | action={data.get('action_type')}")

    action_type_str = data["action_type"]
    try:
        action_type = CarbonActionType(action_type_str)
    except ValueError:
        valid = [a.value for a in CarbonActionType]
        raise ValueError(f"Invalid action_type: {action_type_str}. Must be one of: {valid}")

    # Look up estimated reduction from our database
    reduction_info = REDUCTION_ESTIMATES.get(action_type_str, {})
    estimated_reduction = data.get(
        "estimated_reduction_kg_co2",
        reduction_info.get("estimated_reduction_kg_co2_per_year", 0.0),
    )

    start_date = data["start_date"]
    if isinstance(start_date, str):
        start_date = date.fromisoformat(start_date)

    action = CarbonReductionAction(
        farmer_id=farmer_id,
        action_type=action_type,
        description=data.get("description", reduction_info.get("description", "")),
        estimated_reduction_kg_co2=estimated_reduction,
        start_date=start_date,
    )
    db.add(action)
    await db.flush()

    logger.info(
        f"Reduction action recorded | action_id={action.id} | type={action_type.value} "
        f"| estimated_reduction={estimated_reduction} kg CO2e"
    )
    return action


async def estimate_carbon_credits(
    db: AsyncSession,
    farmer_id: uuid.UUID,
) -> dict:
    """Estimate potential carbon credit value based on reduction actions."""
    logger.info(f"estimate_carbon_credits called | farmer_id={farmer_id}")

    # Get all reduction actions
    query = select(CarbonReductionAction).where(
        CarbonReductionAction.farmer_id == farmer_id
    )
    result = await db.execute(query)
    actions = list(result.scalars().all())

    total_reduction_kg = sum(a.estimated_reduction_kg_co2 for a in actions)
    total_reduction_tonnes = total_reduction_kg / 1000.0

    verified_reduction_kg = sum(a.estimated_reduction_kg_co2 for a in actions if a.is_verified)
    verified_reduction_tonnes = verified_reduction_kg / 1000.0

    # Calculate credit values
    credit_value_min = total_reduction_tonnes * CARBON_CREDIT_PRICE_MIN
    credit_value_max = total_reduction_tonnes * CARBON_CREDIT_PRICE_MAX
    credit_value_mid = total_reduction_tonnes * CARBON_CREDIT_PRICE_MID

    verified_value_min = verified_reduction_tonnes * CARBON_CREDIT_PRICE_MIN
    verified_value_max = verified_reduction_tonnes * CARBON_CREDIT_PRICE_MAX

    # Get latest footprint for context
    footprint_query = select(CarbonRecord).where(
        CarbonRecord.farmer_id == farmer_id
    ).order_by(CarbonRecord.created_at.desc()).limit(1)

    fp_result = await db.execute(footprint_query)
    latest_footprint = fp_result.scalar_one_or_none()

    reduction_percentage = 0.0
    if latest_footprint and latest_footprint.total_co2_equivalent_kg > 0:
        # Annualize the footprint
        period_days = (latest_footprint.period_end - latest_footprint.period_start).days
        annual_co2e = latest_footprint.total_co2_equivalent_kg * (365.0 / max(period_days, 1))
        reduction_percentage = (total_reduction_kg / annual_co2e * 100.0) if annual_co2e > 0 else 0.0

    logger.info(
        f"Carbon credits estimated | farmer_id={farmer_id} | total_reduction={total_reduction_tonnes:.3f} tonnes "
        f"| value_range=INR {credit_value_min:.0f}-{credit_value_max:.0f}"
    )

    return {
        "farmer_id": str(farmer_id),
        "total_actions": len(actions),
        "verified_actions": sum(1 for a in actions if a.is_verified),
        "total_reduction_kg_co2": round(total_reduction_kg, 2),
        "total_reduction_tonnes_co2": round(total_reduction_tonnes, 3),
        "verified_reduction_tonnes_co2": round(verified_reduction_tonnes, 3),
        "reduction_percentage_of_footprint": round(reduction_percentage, 1),
        "potential_credit_value_inr": {
            "min": round(credit_value_min, 2),
            "max": round(credit_value_max, 2),
            "mid": round(credit_value_mid, 2),
        },
        "verified_credit_value_inr": {
            "min": round(verified_value_min, 2),
            "max": round(verified_value_max, 2),
        },
        "carbon_credit_price_per_tonne_inr": {
            "min": CARBON_CREDIT_PRICE_MIN,
            "max": CARBON_CREDIT_PRICE_MAX,
        },
        "actions": [
            {
                "id": str(a.id),
                "action_type": a.action_type.value,
                "description": a.description,
                "estimated_reduction_kg_co2": a.estimated_reduction_kg_co2,
                "start_date": str(a.start_date),
                "is_verified": a.is_verified,
                "verified_by": a.verified_by,
            }
            for a in actions
        ],
    }
