"""Feed cost optimizer — generates optimal ration from locally available Indian feed ingredients."""
import logging
import math
from dataclasses import dataclass, field

logger = logging.getLogger("dairy_ai.ml.feed_optimizer")


@dataclass
class FeedInput:
    breed: str  # gir, sahiwal, murrah, hf_crossbred, jersey_crossbred
    weight_kg: float
    milk_yield_litres: float
    fat_pct: float = 4.0
    lactation_stage: str = "mid"  # early/mid/late/dry
    is_pregnant: bool = False
    months_pregnant: int = 0
    local_prices: dict | None = None  # ingredient_name -> price_per_kg


@dataclass
class FeedIngredient:
    name: str
    category: str  # green_fodder/dry_fodder/concentrate/mineral
    quantity_kg: float
    cost_per_kg: float
    total_cost: float
    dm_pct: float  # dry matter %
    cp_pct: float  # crude protein %
    tdn_pct: float  # total digestible nutrients %
    ca_pct: float  # calcium %
    p_pct: float   # phosphorus %


@dataclass
class FeedPlanResult:
    ingredients: list[FeedIngredient]
    total_cost_per_day: float
    nutritional_breakdown: dict
    requirements: dict
    deficit_surplus: dict
    expected_milk_response: str
    recommendations: list[str]


# Ingredient nutritional database (DM basis, per kg as-fed)
INGREDIENT_DB: dict[str, dict] = {
    "Napier Grass": {"category": "green_fodder", "dm": 20, "cp": 8, "tdn": 55, "ca": 0.4, "p": 0.25, "default_price": 2.5, "max_kg": 25},
    "Maize Fodder": {"category": "green_fodder", "dm": 22, "cp": 7, "tdn": 60, "ca": 0.3, "p": 0.2, "default_price": 3.0, "max_kg": 20},
    "Berseem": {"category": "green_fodder", "dm": 18, "cp": 17, "tdn": 60, "ca": 1.5, "p": 0.3, "default_price": 4.0, "max_kg": 15},
    "Wheat Straw": {"category": "dry_fodder", "dm": 90, "cp": 3.5, "tdn": 42, "ca": 0.2, "p": 0.08, "default_price": 5.0, "max_kg": 5},
    "Paddy Straw": {"category": "dry_fodder", "dm": 90, "cp": 3.0, "tdn": 40, "ca": 0.2, "p": 0.07, "default_price": 3.5, "max_kg": 4},
    "Cotton Seed Cake": {"category": "concentrate", "dm": 92, "cp": 24, "tdn": 75, "ca": 0.2, "p": 1.0, "default_price": 32.0, "max_kg": 3},
    "Mustard Cake": {"category": "concentrate", "dm": 90, "cp": 32, "tdn": 72, "ca": 0.7, "p": 1.1, "default_price": 35.0, "max_kg": 2},
    "Soybean Meal": {"category": "concentrate", "dm": 90, "cp": 44, "tdn": 82, "ca": 0.3, "p": 0.7, "default_price": 42.0, "max_kg": 2},
    "Maize Grain": {"category": "concentrate", "dm": 88, "cp": 9, "tdn": 83, "ca": 0.03, "p": 0.3, "default_price": 22.0, "max_kg": 3},
    "Wheat Bran": {"category": "concentrate", "dm": 88, "cp": 15, "tdn": 65, "ca": 0.12, "p": 1.2, "default_price": 18.0, "max_kg": 3},
    "Rice Bran": {"category": "concentrate", "dm": 90, "cp": 13, "tdn": 60, "ca": 0.1, "p": 1.5, "default_price": 16.0, "max_kg": 2},
    "Mineral Mixture": {"category": "mineral", "dm": 95, "cp": 0, "tdn": 0, "ca": 24, "p": 12, "default_price": 80.0, "max_kg": 0.05},
    "Common Salt": {"category": "mineral", "dm": 99, "cp": 0, "tdn": 0, "ca": 0, "p": 0, "default_price": 12.0, "max_kg": 0.03},
}

# Breed-specific metabolic weight factors
BREED_FACTORS: dict[str, dict] = {
    "gir": {"avg_weight": 350, "maintenance_dm_pct": 2.5, "milk_dm_per_litre": 0.35, "max_yield": 12},
    "sahiwal": {"avg_weight": 380, "maintenance_dm_pct": 2.5, "milk_dm_per_litre": 0.35, "max_yield": 14},
    "murrah": {"avg_weight": 500, "maintenance_dm_pct": 2.8, "milk_dm_per_litre": 0.40, "max_yield": 15},
    "hf_crossbred": {"avg_weight": 450, "maintenance_dm_pct": 3.0, "milk_dm_per_litre": 0.40, "max_yield": 25},
    "jersey_crossbred": {"avg_weight": 400, "maintenance_dm_pct": 2.8, "milk_dm_per_litre": 0.38, "max_yield": 18},
    "other": {"avg_weight": 400, "maintenance_dm_pct": 2.7, "milk_dm_per_litre": 0.37, "max_yield": 15},
}


def _calculate_requirements(input: FeedInput) -> dict:
    """Calculate daily nutritional requirements based on NRC/ICAR guidelines."""
    breed_data = BREED_FACTORS.get(input.breed, BREED_FACTORS["other"])
    weight = input.weight_kg or breed_data["avg_weight"]
    metabolic_weight = weight ** 0.75

    # DM requirement: maintenance + production
    maintenance_dm = weight * breed_data["maintenance_dm_pct"] / 100
    production_dm = input.milk_yield_litres * breed_data["milk_dm_per_litre"]
    total_dm = maintenance_dm + production_dm

    # Adjust for lactation stage
    if input.lactation_stage == "early":
        total_dm *= 1.1  # higher intake needed
    elif input.lactation_stage == "dry":
        total_dm *= 0.7

    # Pregnancy adjustment
    if input.is_pregnant and input.months_pregnant >= 6:
        total_dm *= 1.05

    # CP requirement: maintenance 6% of DM + 90g per litre of 4% FCM
    fcm = 0.4 * input.milk_yield_litres + 15 * (input.fat_pct / 100) * input.milk_yield_litres
    maintenance_cp = total_dm * 0.06
    production_cp = fcm * 0.09
    total_cp = maintenance_cp + production_cp

    # TDN requirement
    maintenance_tdn = metabolic_weight * 0.033  # kg
    production_tdn = fcm * 0.3
    total_tdn = maintenance_tdn + production_tdn

    # Ca and P (g/day)
    ca_g = 16 + input.milk_yield_litres * 2.5  # maintenance + 2.5g per litre
    p_g = 12 + input.milk_yield_litres * 1.5

    return {
        "dm_kg": round(total_dm, 2),
        "cp_kg": round(total_cp, 2),
        "tdn_kg": round(total_tdn, 2),
        "ca_g": round(ca_g, 1),
        "p_g": round(p_g, 1),
        "weight_kg": weight,
        "metabolic_weight": round(metabolic_weight, 2),
        "fcm_litres": round(fcm, 2),
    }


def optimize_feed(input: FeedInput) -> FeedPlanResult:
    """Generate cost-optimized feed plan meeting nutritional requirements."""
    logger.info("Feed optimization: breed=%s, weight=%.0f, milk=%.1f, stage=%s",
                input.breed, input.weight_kg, input.milk_yield_litres, input.lactation_stage)

    requirements = _calculate_requirements(input)
    prices = input.local_prices or {}

    # Greedy allocation: fill roughage first (60%), then concentrate (35%), then minerals (5%)
    target_dm = requirements["dm_kg"]
    roughage_dm = target_dm * 0.60
    concentrate_dm = target_dm * 0.35
    mineral_dm = target_dm * 0.05

    ingredients: list[FeedIngredient] = []
    total_dm = 0.0
    total_cp = 0.0
    total_tdn = 0.0
    total_ca = 0.0
    total_p = 0.0
    total_cost = 0.0

    def _add(name: str, quantity_kg: float) -> None:
        nonlocal total_dm, total_cp, total_tdn, total_ca, total_p, total_cost
        info = INGREDIENT_DB[name]
        price = prices.get(name.lower().replace(" ", "_"), info["default_price"])
        cost = round(quantity_kg * price, 2)
        dm = quantity_kg * info["dm"] / 100
        cp = dm * info["cp"] / 100
        tdn = dm * info["tdn"] / 100
        ca = dm * info["ca"] / 100
        p = dm * info["p"] / 100

        ingredients.append(FeedIngredient(
            name=name, category=info["category"],
            quantity_kg=round(quantity_kg, 2), cost_per_kg=price,
            total_cost=cost, dm_pct=info["dm"], cp_pct=info["cp"],
            tdn_pct=info["tdn"], ca_pct=info["ca"], p_pct=info["p"],
        ))
        total_dm += dm
        total_cp += cp
        total_tdn += tdn
        total_ca += ca
        total_p += p
        total_cost += cost

    # Green fodder (high moisture, moderate CP)
    green_quantity = roughage_dm / 0.20 * 0.7  # 70% of roughage from green
    _add("Napier Grass", min(green_quantity * 0.6, 20))
    if input.milk_yield_litres > 5:
        _add("Berseem", min(green_quantity * 0.4, 10))

    # Dry fodder
    dry_quantity = roughage_dm / 0.90 * 0.3
    _add("Wheat Straw", min(dry_quantity, 4))

    # Concentrates — select based on yield level and price
    if input.milk_yield_litres > 0:
        conc_kg = concentrate_dm / 0.90  # approximate
        # Energy source
        _add("Maize Grain", min(conc_kg * 0.35, 3))
        # Protein sources
        _add("Mustard Cake", min(conc_kg * 0.25, 2))
        if input.milk_yield_litres > 8:
            _add("Cotton Seed Cake", min(conc_kg * 0.2, 2.5))
        # Bran for bulk + fiber
        _add("Wheat Bran", min(conc_kg * 0.2, 2.5))

    # Minerals
    _add("Mineral Mixture", 0.05)
    _add("Common Salt", 0.03)

    # Calculate deficit/surplus
    deficit_surplus = {
        "dm_kg": round(total_dm - requirements["dm_kg"], 2),
        "cp_kg": round(total_cp - requirements["cp_kg"], 2),
        "tdn_kg": round(total_tdn - requirements["tdn_kg"], 2),
        "ca_g": round(total_ca * 1000 - requirements["ca_g"], 1),
        "p_g": round(total_p * 1000 - requirements["p_g"], 1),
    }

    # Recommendations
    recommendations = []
    if deficit_surplus["cp_kg"] < -0.1:
        recommendations.append(f"Protein deficit of {abs(deficit_surplus['cp_kg']):.1f} kg — add more oil cake or soybean meal")
    if deficit_surplus["tdn_kg"] < -0.2:
        recommendations.append(f"Energy deficit of {abs(deficit_surplus['tdn_kg']):.1f} kg — add more maize grain or molasses")
    if deficit_surplus["ca_g"] < -5:
        recommendations.append("Calcium deficit — ensure mineral mixture is given daily")
    if input.lactation_stage == "early":
        recommendations.append("Early lactation: ensure ad-lib water and gradual concentrate increase")
    if input.milk_yield_litres > 15:
        recommendations.append("High yielder: consider bypass fat supplement (100-150g/day)")

    # Expected milk response
    current = input.milk_yield_litres
    breed_max = BREED_FACTORS.get(input.breed, BREED_FACTORS["other"])["max_yield"]
    if deficit_surplus["cp_kg"] >= 0 and deficit_surplus["tdn_kg"] >= 0:
        potential = min(current * 1.1, breed_max)
        milk_response = f"With this balanced ration, expect yield maintenance at {current:.0f}L or slight increase to {potential:.0f}L/day"
    else:
        milk_response = f"Current ration has nutritional gaps. Fixing these could improve yield by 1-2L/day"

    result = FeedPlanResult(
        ingredients=ingredients,
        total_cost_per_day=round(total_cost, 2),
        nutritional_breakdown={
            "total_dm_kg": round(total_dm, 2),
            "total_cp_kg": round(total_cp, 2),
            "total_tdn_kg": round(total_tdn, 2),
            "total_ca_g": round(total_ca * 1000, 1),
            "total_p_g": round(total_p * 1000, 1),
            "roughage_concentrate_ratio": f"{int(total_dm * 0.6 / total_dm * 100)}:{int(total_dm * 0.4 / total_dm * 100)}" if total_dm > 0 else "60:40",
        },
        requirements=requirements,
        deficit_surplus=deficit_surplus,
        expected_milk_response=milk_response,
        recommendations=recommendations,
    )

    logger.info("Feed plan: cost=₹%.0f/day, DM=%.1fkg, CP=%.2fkg, ingredients=%d",
                result.total_cost_per_day, total_dm, total_cp, len(ingredients))
    return result
