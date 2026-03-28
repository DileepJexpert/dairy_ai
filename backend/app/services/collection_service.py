"""
Milk Collection & Cold Chain Service — business logic for collection centers,
individual milk pourings, cold chain temperature monitoring, and dashboard
aggregation.

Logging strategy (dairy_ai.services.collection logger):
  DEBUG   — every intermediate calculation, branch taken, DB operation start/end,
             intermediate values before and after rounding
  INFO    — function entry/exit with key identifiers and final outcomes
  WARNING — anomalous conditions: milk rejection, temperature breach, capacity
             approaching full, cold chain alerts
  ERROR   — unexpected missing entities or inconsistent state
"""
import logging
import uuid
from datetime import date, datetime
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.collection import (
    CollectionCenter, MilkCollection, MilkGrade, CollectionShift,
    ColdChainReading, ColdChainAlert, AlertSeverity, AlertStatus,
)

logger = logging.getLogger("dairy_ai.services.collection")

# ---------------------------------------------------------------------------
# Grading & pricing constants
# ---------------------------------------------------------------------------
# Milk grade thresholds — both fat AND SNF must meet the bar
_GRADE_A_FAT_MIN: float = 4.0
_GRADE_A_SNF_MIN: float = 8.5
_GRADE_B_FAT_MIN: float = 3.5
_GRADE_B_SNF_MIN: float = 8.0
_GRADE_C_FAT_MIN: float = 3.0
_GRADE_C_SNF_MIN: float = 7.5

# Pricing
_BASE_RATE: float = 30.0            # ₹/litre at exactly 3.0% fat
_FAT_PREMIUM_PER_PCT: float = 5.0  # additional ₹/litre for each % point above 3.0

# Quality bonuses (₹/litre on top of rate × quantity)
_QUALITY_BONUS_A: float = 2.0
_QUALITY_BONUS_B: float = 1.0

# Temperature limits
_MILK_TEMP_REJECTION_C: float = 8.0   # reject the pour if milk arrives hotter than this
_COLD_CHAIN_WARNING_C: float = 4.5    # cold chain WARNING alert threshold
_COLD_CHAIN_CRITICAL_C: float = 8.0   # cold chain CRITICAL alert threshold

# Capacity warning level (fraction)
_CAPACITY_WARN_FRACTION: float = 0.90  # warn when stock >= 90% of capacity


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

def _determine_milk_grade(fat_pct: float | None, snf_pct: float | None) -> MilkGrade:
    """
    Determine MilkGrade from fat and SNF percentages.

    Grading ladder (highest first):
        A  — fat >= 4.0 AND snf >= 8.5
        B  — fat >= 3.5 AND snf >= 8.0
        C  — fat >= 3.0 AND snf >= 7.5
        rejected — anything below C minimums, or missing values
    """
    logger.debug(
        "_determine_milk_grade | fat_pct=%s, snf_pct=%s", fat_pct, snf_pct
    )

    if fat_pct is None or snf_pct is None:
        logger.debug(
            "_determine_milk_grade | missing fat or SNF → grade=C (default when analyzer unavailable) "
            "(fat_pct=%s, snf_pct=%s)",
            fat_pct, snf_pct,
        )
        return MilkGrade.C

    # Grade A check
    logger.debug(
        "_determine_milk_grade | checking Grade A | fat=%.2f >= %.1f? %s, snf=%.2f >= %.1f? %s",
        fat_pct, _GRADE_A_FAT_MIN, fat_pct >= _GRADE_A_FAT_MIN,
        snf_pct, _GRADE_A_SNF_MIN, snf_pct >= _GRADE_A_SNF_MIN,
    )
    if fat_pct >= _GRADE_A_FAT_MIN and snf_pct >= _GRADE_A_SNF_MIN:
        logger.debug(
            "_determine_milk_grade | Grade A awarded | fat=%.2f, snf=%.2f", fat_pct, snf_pct
        )
        return MilkGrade.A

    # Grade B check
    logger.debug(
        "_determine_milk_grade | checking Grade B | fat=%.2f >= %.1f? %s, snf=%.2f >= %.1f? %s",
        fat_pct, _GRADE_B_FAT_MIN, fat_pct >= _GRADE_B_FAT_MIN,
        snf_pct, _GRADE_B_SNF_MIN, snf_pct >= _GRADE_B_SNF_MIN,
    )
    if fat_pct >= _GRADE_B_FAT_MIN and snf_pct >= _GRADE_B_SNF_MIN:
        logger.debug(
            "_determine_milk_grade | Grade B awarded | fat=%.2f, snf=%.2f", fat_pct, snf_pct
        )
        return MilkGrade.B

    # Grade C check
    logger.debug(
        "_determine_milk_grade | checking Grade C | fat=%.2f >= %.1f? %s, snf=%.2f >= %.1f? %s",
        fat_pct, _GRADE_C_FAT_MIN, fat_pct >= _GRADE_C_FAT_MIN,
        snf_pct, _GRADE_C_SNF_MIN, snf_pct >= _GRADE_C_SNF_MIN,
    )
    if fat_pct >= _GRADE_C_FAT_MIN and snf_pct >= _GRADE_C_SNF_MIN:
        logger.debug(
            "_determine_milk_grade | Grade C awarded | fat=%.2f, snf=%.2f", fat_pct, snf_pct
        )
        return MilkGrade.C

    # Below all thresholds
    logger.debug(
        "_determine_milk_grade | grade=rejected | fat=%.2f (min=%.1f), snf=%.2f (min=%.1f)",
        fat_pct, _GRADE_C_FAT_MIN, snf_pct, _GRADE_C_SNF_MIN,
    )
    return MilkGrade.rejected


def _calculate_rate_per_litre(fat_pct: float | None) -> float:
    """
    Fat-based pricing:
        rate = BASE_RATE + max(0, fat_pct - 3.0) * FAT_PREMIUM_PER_PCT

    The max(0, ...) ensures the rate never drops below BASE_RATE even if
    fat_pct < 3.0 (that case is normally already rejected by grading, but
    this function remains safe regardless).

    Returns BASE_RATE when fat_pct is None.
    """
    logger.debug("_calculate_rate_per_litre | fat_pct=%s", fat_pct)

    if fat_pct is None:
        logger.debug(
            "_calculate_rate_per_litre | fat_pct is None → returning base_rate=%.2f",
            _BASE_RATE,
        )
        return _BASE_RATE

    fat_above_base = fat_pct - 3.0
    logger.debug(
        "_calculate_rate_per_litre | fat_above_base=%.4f (fat=%.2f - 3.0)",
        fat_above_base, fat_pct,
    )

    premium = max(0.0, fat_above_base) * _FAT_PREMIUM_PER_PCT
    logger.debug(
        "_calculate_rate_per_litre | premium=max(0, %.4f) × %.2f = %.4f",
        fat_above_base, _FAT_PREMIUM_PER_PCT, premium,
    )

    raw_rate = _BASE_RATE + premium
    logger.debug(
        "_calculate_rate_per_litre | raw_rate = base(%.2f) + premium(%.4f) = %.4f",
        _BASE_RATE, premium, raw_rate,
    )

    rate = round(raw_rate, 4)
    logger.debug(
        "_calculate_rate_per_litre | final rate after round(4) = ₹%.4f/L", rate
    )
    return rate


def _calculate_quality_bonus(grade: MilkGrade, quantity_litres: float) -> float:
    """
    Grade-based per-litre quality bonus:
        Grade A → ₹2/litre
        Grade B → ₹1/litre
        Otherwise → ₹0
    """
    logger.debug(
        "_calculate_quality_bonus | grade=%s, quantity=%.2fL", grade.value, quantity_litres
    )
    if grade == MilkGrade.A:
        bonus = round(_QUALITY_BONUS_A * quantity_litres, 2)
        logger.debug(
            "_calculate_quality_bonus | Grade A | %.2f × %.2fL = ₹%.2f",
            _QUALITY_BONUS_A, quantity_litres, bonus,
        )
        return bonus
    if grade == MilkGrade.B:
        bonus = round(_QUALITY_BONUS_B * quantity_litres, 2)
        logger.debug(
            "_calculate_quality_bonus | Grade B | %.2f × %.2fL = ₹%.2f",
            _QUALITY_BONUS_B, quantity_litres, bonus,
        )
        return bonus

    logger.debug(
        "_calculate_quality_bonus | grade=%s has no bonus → ₹0.00", grade.value
    )
    return 0.0


# Public aliases for the grading/pricing helpers (used by tests)
grade_milk = _determine_milk_grade
calculate_rate = _calculate_rate_per_litre


# ---------------------------------------------------------------------------
# 1. create_collection_center
# ---------------------------------------------------------------------------

async def create_collection_center(db: AsyncSession, data: dict) -> CollectionCenter:
    """
    Persist a new CollectionCenter row and return the refreshed ORM object.

    Expected keys in `data`:
        name            str           (required)
        code            str           (required, unique)
        cooperative_id  uuid | None
        address         str | None
        village         str | None
        district        str | None
        state           str | None
        pincode         str | None
        lat             float | None
        lng             float | None
        capacity_litres float         (default: 500.0)
        chilling_temp_celsius float   (default: 4.0)
        has_fat_analyzer  bool        (default: False)
        has_snf_analyzer  bool        (default: False)
        manager_name    str | None
        manager_phone   str | None
        status          CenterStatus  (default: active)
    """
    logger.info(
        "create_collection_center called | name=%r, code=%r, district=%r",
        data.get("name"), data.get("code"), data.get("district"),
    )
    logger.debug("create_collection_center | full payload: %s", data)

    # Resolve defaults before constructing the ORM object so the log
    # shows exactly what will be written to the DB.
    capacity = data.get("capacity_litres", 500.0)
    chilling_temp = data.get("chilling_temp_celsius", 4.0)
    has_fat = data.get("has_fat_analyzer", False)
    has_snf = data.get("has_snf_analyzer", False)

    logger.debug(
        "create_collection_center | resolved values: capacity=%.1fL, "
        "chilling_temp=%.1f°C, has_fat_analyzer=%s, has_snf_analyzer=%s",
        capacity, chilling_temp, has_fat, has_snf,
    )

    center = CollectionCenter(
        name=data["name"],
        code=data["code"],
        cooperative_id=data.get("cooperative_id"),
        address=data.get("address"),
        village=data.get("village"),
        district=data.get("district"),
        state=data.get("state"),
        pincode=data.get("pincode"),
        lat=data.get("lat"),
        lng=data.get("lng"),
        capacity_litres=capacity,
        current_stock_litres=0.0,
        chilling_temp_celsius=chilling_temp,
        has_fat_analyzer=has_fat,
        has_snf_analyzer=has_snf,
        manager_name=data.get("manager_name"),
        manager_phone=data.get("manager_phone"),
    )
    logger.debug(
        "create_collection_center | CollectionCenter ORM object constructed, adding to session"
    )

    db.add(center)
    logger.debug("create_collection_center | session.add() done, calling db.flush()")

    await db.flush()
    logger.debug(
        "create_collection_center | db.flush() completed | center.id=%s", center.id
    )

    await db.refresh(center)
    logger.debug(
        "create_collection_center | db.refresh() completed | "
        "id=%s, created_at=%s, status=%s",
        center.id, center.created_at, center.status,
    )

    logger.info(
        "create_collection_center SUCCESS | id=%s, code=%s, name=%r, "
        "capacity=%.1fL, chilling=%.1f°C",
        center.id, center.code, center.name, center.capacity_litres,
        center.chilling_temp_celsius,
    )
    return center


# ---------------------------------------------------------------------------
# 2. record_milk_collection
# ---------------------------------------------------------------------------

async def record_milk_collection(db: AsyncSession, data: dict) -> MilkCollection:
    """
    Record an individual farmer's milk pour at a collection center.

    Business rules applied in order:
        1. Determine milk grade from fat + SNF percentages.
        2. Calculate rate per litre from fat percentage.
        3. Calculate total_amount = quantity × rate.
        4. Calculate quality_bonus based on grade.
        5. Check temperature — if > 8.0°C, mark is_rejected=True with reason.
        6. Calculate net_amount = total_amount + quality_bonus − deductions.
        7. Persist MilkCollection.
        8. If not rejected, increment CollectionCenter.current_stock_litres.

    Expected keys in `data`:
        center_id         uuid  (required)
        farmer_id         uuid  (required)
        date              date  (default: today)
        shift             CollectionShift  (default: morning)
        quantity_litres   float (required)
        fat_pct           float | None
        snf_pct           float | None
        temperature_celsius float | None
        deductions        float (default: 0.0)
        collected_by      str | None
    """
    # ---- Extract and validate inputs -----------------------------------
    _cid = data["center_id"]
    center_id: uuid.UUID = uuid.UUID(_cid) if isinstance(_cid, str) else _cid
    _fid = data["farmer_id"]
    farmer_id: uuid.UUID = uuid.UUID(_fid) if isinstance(_fid, str) else _fid
    quantity: float = float(data["quantity_litres"])
    fat_pct: float | None = data.get("fat_pct")
    snf_pct: float | None = data.get("snf_pct")
    temperature: float | None = data.get("temperature_celsius")
    deductions: float = float(data.get("deductions", 0.0))
    collection_date: date = data.get("date", date.today())
    shift = data.get("shift", CollectionShift.morning)
    collected_by: str | None = data.get("collected_by")

    logger.info(
        "record_milk_collection called | center_id=%s, farmer_id=%s, "
        "date=%s, shift=%s, quantity=%.2fL",
        center_id, farmer_id, collection_date, shift, quantity,
    )
    logger.debug(
        "record_milk_collection | quality inputs: fat_pct=%s, snf_pct=%s, "
        "temperature_celsius=%s, deductions=%.2f, collected_by=%r",
        fat_pct, snf_pct, temperature, deductions, collected_by,
    )

    # ---- Step 1: Milk grading ------------------------------------------
    logger.debug(
        "record_milk_collection | STEP 1 — grading milk | fat_pct=%s, snf_pct=%s",
        fat_pct, snf_pct,
    )
    milk_grade: MilkGrade = _determine_milk_grade(fat_pct, snf_pct)
    logger.debug(
        "record_milk_collection | STEP 1 result | milk_grade=%s", milk_grade.value
    )

    # ---- Step 2: Rate per litre ----------------------------------------
    logger.debug(
        "record_milk_collection | STEP 2 — calculating rate per litre | fat_pct=%s", fat_pct
    )
    rate_per_litre: float = _calculate_rate_per_litre(fat_pct)
    logger.debug(
        "record_milk_collection | STEP 2 result | rate_per_litre=₹%.4f", rate_per_litre
    )

    # ---- Step 3: Total amount ------------------------------------------
    logger.debug(
        "record_milk_collection | STEP 3 — calculating total amount | "
        "quantity=%.2fL × rate=₹%.4f",
        quantity, rate_per_litre,
    )
    total_amount: float = round(quantity * rate_per_litre, 2)
    logger.debug(
        "record_milk_collection | STEP 3 result | total_amount=₹%.2f", total_amount
    )

    # ---- Step 4: Quality bonus -----------------------------------------
    logger.debug(
        "record_milk_collection | STEP 4 — calculating quality bonus | "
        "grade=%s, quantity=%.2fL",
        milk_grade.value, quantity,
    )
    quality_bonus: float = _calculate_quality_bonus(milk_grade, quantity)
    logger.debug(
        "record_milk_collection | STEP 4 result | quality_bonus=₹%.2f", quality_bonus
    )

    # ---- Step 5: Temperature rejection check ---------------------------
    logger.debug(
        "record_milk_collection | STEP 5 — temperature check | "
        "temperature=%s°C, threshold=%.1f°C",
        temperature, _MILK_TEMP_REJECTION_C,
    )
    is_rejected: bool = False
    rejection_reason: str | None = None

    if milk_grade == MilkGrade.rejected:
        is_rejected = True
        rejection_reason = "Milk quality below minimum standards"
        logger.warning(
            "record_milk_collection | STEP 5 — milk rejected due to low quality | "
            "farmer_id=%s, center_id=%s, fat_pct=%s, snf_pct=%s",
            farmer_id, center_id, fat_pct, snf_pct,
        )
    else:
        logger.debug(
            "record_milk_collection | STEP 5 — quality grade (%s) is acceptable, "
            "no quality rejection",
            milk_grade.value,
        )

    if temperature is not None and temperature > _MILK_TEMP_REJECTION_C:
        # Temperature rejection overrides any quality-based decision
        is_rejected = True
        rejection_reason = "Milk temperature too high"
        logger.warning(
            "record_milk_collection | STEP 5 — milk rejected due to high temperature | "
            "farmer_id=%s, center_id=%s, temperature=%.2f°C > threshold=%.1f°C",
            farmer_id, center_id, temperature, _MILK_TEMP_REJECTION_C,
        )
    elif temperature is not None:
        logger.debug(
            "record_milk_collection | STEP 5 — temperature within limit | "
            "%.2f°C <= %.1f°C",
            temperature, _MILK_TEMP_REJECTION_C,
        )
    else:
        logger.debug(
            "record_milk_collection | STEP 5 — temperature not provided, skipping check"
        )

    logger.debug(
        "record_milk_collection | STEP 5 result | is_rejected=%s, rejection_reason=%r",
        is_rejected, rejection_reason,
    )

    # ---- Step 6: Net amount --------------------------------------------
    if is_rejected:
        net_amount = 0.0
        logger.debug(
            "record_milk_collection | STEP 6 — milk rejected, net_amount forced to ₹0.00"
        )
    else:
        logger.debug(
            "record_milk_collection | STEP 6 — calculating net amount | "
            "total=₹%.2f + bonus=₹%.2f - deductions=₹%.2f",
            total_amount, quality_bonus, deductions,
        )
        net_amount = round(total_amount + quality_bonus - deductions, 2)
        logger.debug(
            "record_milk_collection | STEP 6 result | net_amount=₹%.2f", net_amount
        )

    # ---- Step 7: Persist MilkCollection record -------------------------
    logger.debug(
        "record_milk_collection | STEP 7 — constructing MilkCollection ORM object | "
        "grade=%s, rate=₹%.4f, total=₹%.2f, bonus=₹%.2f, net=₹%.2f, rejected=%s",
        milk_grade.value, rate_per_litre, total_amount, quality_bonus, net_amount, is_rejected,
    )
    collection = MilkCollection(
        center_id=center_id,
        farmer_id=farmer_id,
        date=collection_date,
        shift=shift,
        quantity_litres=quantity,
        fat_pct=fat_pct,
        snf_pct=snf_pct,
        temperature_celsius=temperature,
        milk_grade=milk_grade,
        rate_per_litre=rate_per_litre,
        total_amount=total_amount,
        quality_bonus=quality_bonus,
        deductions=deductions,
        net_amount=net_amount,
        is_rejected=is_rejected,
        rejection_reason=rejection_reason,
        collected_by=collected_by,
    )

    db.add(collection)
    logger.debug(
        "record_milk_collection | STEP 7 — MilkCollection added to session, calling db.flush()"
    )
    await db.flush()
    logger.debug(
        "record_milk_collection | STEP 7 — db.flush() done | collection.id=%s", collection.id
    )

    await db.refresh(collection)
    logger.debug(
        "record_milk_collection | STEP 7 — db.refresh() done | "
        "collection.id=%s, created_at=%s",
        collection.id, collection.created_at,
    )

    # ---- Step 8: Update center stock -----------------------------------
    logger.debug(
        "record_milk_collection | STEP 8 — deciding whether to update center stock | "
        "is_rejected=%s, center_id=%s",
        is_rejected, center_id,
    )
    if not is_rejected:
        logger.debug(
            "record_milk_collection | STEP 8 — fetching CollectionCenter from DB | "
            "center_id=%s",
            center_id,
        )
        result = await db.execute(
            select(CollectionCenter).where(CollectionCenter.id == center_id)
        )
        center = result.scalar_one_or_none()

        if center is None:
            logger.error(
                "record_milk_collection | STEP 8 — CollectionCenter not found, "
                "cannot update stock | center_id=%s",
                center_id,
            )
        else:
            old_stock = center.current_stock_litres
            new_stock = round(old_stock + quantity, 3)
            logger.debug(
                "record_milk_collection | STEP 8 — updating stock | "
                "old_stock=%.3fL + quantity=%.2fL = new_stock=%.3fL",
                old_stock, quantity, new_stock,
            )
            center.current_stock_litres = new_stock

            # Capacity warning
            if center.capacity_litres and center.capacity_litres > 0:
                fill_pct = new_stock / center.capacity_litres
                logger.debug(
                    "record_milk_collection | STEP 8 — capacity check | "
                    "stock=%.3fL / capacity=%.1fL = %.1f%% full",
                    new_stock, center.capacity_litres, fill_pct * 100,
                )
                if fill_pct >= _CAPACITY_WARN_FRACTION:
                    logger.warning(
                        "record_milk_collection | STEP 8 — center nearing capacity | "
                        "center_id=%s, name=%r, stock=%.1fL, capacity=%.1fL (%.1f%% full)",
                        center.id, center.name, new_stock,
                        center.capacity_litres, fill_pct * 100,
                    )

            logger.debug(
                "record_milk_collection | STEP 8 — calling db.flush() to persist stock update"
            )
            await db.flush()
            logger.debug(
                "record_milk_collection | STEP 8 — db.flush() done | "
                "center_id=%s, current_stock_litres=%.3fL",
                center_id, center.current_stock_litres,
            )
    else:
        logger.debug(
            "record_milk_collection | STEP 8 — skipping stock update because milk was rejected | "
            "center_id=%s, farmer_id=%s, rejection_reason=%r",
            center_id, farmer_id, rejection_reason,
        )

    logger.info(
        "record_milk_collection SUCCESS | collection_id=%s, center_id=%s, farmer_id=%s, "
        "grade=%s, quantity=%.2fL, rate=₹%.4f, total=₹%.2f, bonus=₹%.2f, "
        "deductions=₹%.2f, net=₹%.2f, is_rejected=%s",
        collection.id, center_id, farmer_id,
        milk_grade.value, quantity, rate_per_litre,
        total_amount, quality_bonus, deductions, net_amount, is_rejected,
    )
    return collection


# ---------------------------------------------------------------------------
# 3. get_center_dashboard
# ---------------------------------------------------------------------------

async def get_center_dashboard(db: AsyncSession, center_id: uuid.UUID) -> dict:
    """
    Return a dashboard dict for the given collection center with today's
    aggregated stats, current stock levels, and active alert counts.

    Returned dict keys:
        center_id, center_name, center_code, status,
        today_collection_litres, today_farmer_count,
        current_stock_litres, capacity_litres, stock_pct,
        chilling_temp_celsius,
        active_alerts_count,
        manager_name, manager_phone, district
    """
    logger.info("get_center_dashboard called | center_id=%s", center_id)

    # ---- Fetch CollectionCenter ----------------------------------------
    logger.debug(
        "get_center_dashboard | querying CollectionCenter | center_id=%s", center_id
    )
    center_result = await db.execute(
        select(CollectionCenter).where(CollectionCenter.id == center_id)
    )
    center = center_result.scalar_one_or_none()
    logger.debug(
        "get_center_dashboard | CollectionCenter query completed | found=%s", center is not None
    )

    if center is None:
        logger.warning(
            "get_center_dashboard | CollectionCenter not found | center_id=%s", center_id
        )
        return {"center_id": str(center_id), "error": "Collection center not found"}

    logger.debug(
        "get_center_dashboard | CollectionCenter loaded | id=%s, name=%r, code=%s, "
        "status=%s, stock=%.2fL, capacity=%.2fL, chilling=%.1f°C",
        center.id, center.name, center.code, center.status,
        center.current_stock_litres, center.capacity_litres,
        center.chilling_temp_celsius,
    )

    # ---- Today's accepted collection totals ----------------------------
    today = date.today()
    logger.debug(
        "get_center_dashboard | querying today's accepted collections | "
        "center_id=%s, date=%s",
        center_id, today,
    )

    litres_result = await db.execute(
        select(func.coalesce(func.sum(MilkCollection.quantity_litres), 0.0))
        .where(
            MilkCollection.center_id == center_id,
            MilkCollection.date == today,
            MilkCollection.is_rejected.is_(False),
        )
    )
    today_collection_litres: float = float(litres_result.scalar_one())
    logger.debug(
        "get_center_dashboard | today's total accepted litres | "
        "center_id=%s, date=%s, litres=%.2f",
        center_id, today, today_collection_litres,
    )

    # ---- Today's distinct farmer count ---------------------------------
    logger.debug(
        "get_center_dashboard | querying today's distinct farmer count | "
        "center_id=%s, date=%s",
        center_id, today,
    )
    farmers_result = await db.execute(
        select(func.count(func.distinct(MilkCollection.farmer_id)))
        .where(
            MilkCollection.center_id == center_id,
            MilkCollection.date == today,
            MilkCollection.is_rejected.is_(False),
        )
    )
    today_farmer_count: int = int(farmers_result.scalar_one())
    logger.debug(
        "get_center_dashboard | today's distinct farmer count | "
        "center_id=%s, date=%s, farmers=%d",
        center_id, today, today_farmer_count,
    )

    # ---- Active cold chain alerts --------------------------------------
    logger.debug(
        "get_center_dashboard | querying active cold chain alerts | center_id=%s", center_id
    )
    alerts_result = await db.execute(
        select(func.count(ColdChainAlert.id))
        .where(
            ColdChainAlert.center_id == center_id,
            ColdChainAlert.status == AlertStatus.active,
        )
    )
    active_alerts_count: int = int(alerts_result.scalar_one())
    logger.debug(
        "get_center_dashboard | active cold chain alerts | "
        "center_id=%s, count=%d",
        center_id, active_alerts_count,
    )

    if active_alerts_count > 0:
        logger.warning(
            "get_center_dashboard | center has %d active cold chain alert(s) | "
            "center_id=%s, name=%r",
            active_alerts_count, center_id, center.name,
        )

    # ---- Stock percentage ----------------------------------------------
    logger.debug(
        "get_center_dashboard | calculating stock_pct | "
        "stock=%.2fL, capacity=%.2fL",
        center.current_stock_litres, center.capacity_litres,
    )
    stock_pct: float = 0.0
    if center.capacity_litres and center.capacity_litres > 0:
        stock_pct = round(
            (center.current_stock_litres / center.capacity_litres) * 100, 1
        )
    logger.debug(
        "get_center_dashboard | stock_pct=%.1f%%", stock_pct
    )

    # ---- Assemble and return dashboard dict ----------------------------
    dashboard = {
        "center": {
            "id": str(center.id),
            "name": center.name,
            "code": center.code,
            "status": center.status.value if hasattr(center.status, "value") else str(center.status),
            "current_stock_litres": center.current_stock_litres,
            "capacity_litres": center.capacity_litres,
            "stock_pct": stock_pct,
            "chilling_temp_celsius": center.chilling_temp_celsius,
            "manager_name": center.manager_name,
            "manager_phone": center.manager_phone,
            "district": center.district,
        },
        "today": {
            "collection_litres": today_collection_litres,
            "farmer_count": today_farmer_count,
        },
        "alerts": {
            "active_count": active_alerts_count,
        },
    }

    logger.info(
        "get_center_dashboard SUCCESS | center_id=%s, name=%r, "
        "today_litres=%.2f, today_farmers=%d, stock=%.2fL (%.1f%%), "
        "active_alerts=%d",
        center_id, center.name,
        today_collection_litres, today_farmer_count,
        center.current_stock_litres, stock_pct,
        active_alerts_count,
    )
    return dashboard


# ---------------------------------------------------------------------------
# 4. record_cold_chain_reading
# ---------------------------------------------------------------------------

async def record_cold_chain_reading(db: AsyncSession, data: dict) -> ColdChainReading:
    """
    Persist a ColdChainReading and, if the temperature breaches a threshold,
    automatically create a ColdChainAlert.

    Alert creation rules:
        temperature > 4.5°C → AlertSeverity.warning  (threshold stored = 4.5)
        temperature > 8.0°C → AlertSeverity.critical (threshold stored = 8.0)
        Both cases set AlertStatus.active.

    Expected keys in `data`:
        center_id           uuid | None
        route_id            uuid | None
        temperature_celsius float  (required)
        humidity_pct        float | None
        recorded_at         datetime | None  (defaults to utcnow)
        device_id           str | None
    """
    _cid = data.get("center_id")
    center_id: uuid.UUID | None = uuid.UUID(_cid) if isinstance(_cid, str) else _cid
    _rid = data.get("route_id")
    route_id: uuid.UUID | None = uuid.UUID(_rid) if isinstance(_rid, str) else _rid
    temperature: float = float(data["temperature_celsius"])
    humidity: float | None = data.get("humidity_pct")
    recorded_at: datetime = data.get("recorded_at") or datetime.utcnow()
    device_id: str | None = data.get("device_id")

    logger.info(
        "record_cold_chain_reading called | center_id=%s, route_id=%s, "
        "temperature=%.2f°C, device_id=%s, recorded_at=%s",
        center_id, route_id, temperature, device_id, recorded_at.isoformat(),
    )
    logger.debug(
        "record_cold_chain_reading | humidity=%s%%, "
        "warning_threshold=%.1f°C, critical_threshold=%.1f°C",
        humidity, _COLD_CHAIN_WARNING_C, _COLD_CHAIN_CRITICAL_C,
    )

    # ---- Decide is_alert flag ------------------------------------------
    logger.debug(
        "record_cold_chain_reading | evaluating is_alert | "
        "temperature=%.2f°C > warning_threshold=%.1f°C? %s",
        temperature, _COLD_CHAIN_WARNING_C, temperature > _COLD_CHAIN_WARNING_C,
    )
    is_alert: bool = temperature > _COLD_CHAIN_WARNING_C
    logger.debug(
        "record_cold_chain_reading | is_alert=%s for this reading", is_alert
    )

    # ---- Persist ColdChainReading -------------------------------------
    logger.debug(
        "record_cold_chain_reading | constructing ColdChainReading ORM object"
    )
    reading = ColdChainReading(
        center_id=center_id,
        route_id=route_id,
        temperature_celsius=temperature,
        humidity_pct=humidity,
        recorded_at=recorded_at,
        device_id=device_id,
        is_alert=is_alert,
    )

    db.add(reading)
    logger.debug(
        "record_cold_chain_reading | ColdChainReading added to session, calling db.flush()"
    )
    await db.flush()
    logger.debug(
        "record_cold_chain_reading | db.flush() completed | reading.id=%s", reading.id
    )

    await db.refresh(reading)
    logger.debug(
        "record_cold_chain_reading | db.refresh() completed | "
        "reading.id=%s, recorded_at=%s, is_alert=%s",
        reading.id, reading.recorded_at, reading.is_alert,
    )

    # ---- Auto-create ColdChainAlert if threshold exceeded -------------
    logger.debug(
        "record_cold_chain_reading | checking whether to auto-create ColdChainAlert | "
        "temperature=%.2f°C, warning_threshold=%.1f°C",
        temperature, _COLD_CHAIN_WARNING_C,
    )

    if temperature > _COLD_CHAIN_WARNING_C:
        # Determine severity and which threshold value to record
        logger.debug(
            "record_cold_chain_reading | temperature %.2f°C exceeds warning threshold %.1f°C — "
            "determining severity | critical_threshold=%.1f°C",
            temperature, _COLD_CHAIN_WARNING_C, _COLD_CHAIN_CRITICAL_C,
        )

        if temperature > _COLD_CHAIN_CRITICAL_C:
            severity = AlertSeverity.critical
            threshold_recorded = _COLD_CHAIN_CRITICAL_C
            logger.warning(
                "record_cold_chain_reading | CRITICAL cold chain breach | "
                "center_id=%s, route_id=%s, temperature=%.2f°C > critical_threshold=%.1f°C, "
                "device_id=%s",
                center_id, route_id, temperature, _COLD_CHAIN_CRITICAL_C, device_id,
            )
        else:
            severity = AlertSeverity.warning
            threshold_recorded = _COLD_CHAIN_WARNING_C
            logger.warning(
                "record_cold_chain_reading | WARNING cold chain breach | "
                "center_id=%s, route_id=%s, temperature=%.2f°C > warning_threshold=%.1f°C, "
                "device_id=%s",
                center_id, route_id, temperature, _COLD_CHAIN_WARNING_C, device_id,
            )

        logger.debug(
            "record_cold_chain_reading | alert severity determined | severity=%s, "
            "threshold_recorded=%.1f°C",
            severity.value, threshold_recorded,
        )

        # Build human-readable alert message
        source_label = (
            f"center {center_id}" if center_id else
            f"route {route_id}" if route_id else
            "unknown source"
        )
        alert_message = (
            f"Temperature {temperature:.1f}\u00b0C detected at {source_label} "
            f"(threshold: {threshold_recorded:.1f}\u00b0C). "
            f"Device: {device_id or 'unknown'}. "
            f"Severity: {severity.value.upper()}."
        )
        logger.debug(
            "record_cold_chain_reading | alert message composed | %r", alert_message
        )

        logger.debug(
            "record_cold_chain_reading | constructing ColdChainAlert ORM object | "
            "severity=%s, status=active",
            severity.value,
        )
        alert = ColdChainAlert(
            center_id=center_id,
            route_id=route_id,
            temperature_celsius=temperature,
            threshold_celsius=threshold_recorded,
            severity=severity,
            status=AlertStatus.active,
            message=alert_message,
        )

        db.add(alert)
        logger.debug(
            "record_cold_chain_reading | ColdChainAlert added to session, calling db.flush()"
        )
        await db.flush()
        logger.debug(
            "record_cold_chain_reading | db.flush() completed | alert.id=%s", alert.id
        )

        await db.refresh(alert)
        logger.debug(
            "record_cold_chain_reading | db.refresh() completed | "
            "alert.id=%s, severity=%s, status=%s, created_at=%s",
            alert.id, alert.severity.value, alert.status.value, alert.created_at,
        )

        logger.info(
            "record_cold_chain_reading | ColdChainAlert created | "
            "alert_id=%s, reading_id=%s, severity=%s, temperature=%.2f°C, source=%s",
            alert.id, reading.id, severity.value, temperature, source_label,
        )

        # Notify cooperative/admin about cold chain breach
        if center_id:
            try:
                from app.services.alert_engine import notify_cold_chain_alert
                await notify_cold_chain_alert(
                    db, center_id, temperature, severity.value
                )
            except Exception as e:
                logger.error(
                    "Failed to send cold chain notification: %s", e
                )
    else:
        logger.debug(
            "record_cold_chain_reading | temperature within safe range — no alert created | "
            "temperature=%.2f°C <= warning_threshold=%.1f°C",
            temperature, _COLD_CHAIN_WARNING_C,
        )

    logger.info(
        "record_cold_chain_reading SUCCESS | reading_id=%s, center_id=%s, route_id=%s, "
        "temperature=%.2f°C, humidity=%s%%, is_alert=%s",
        reading.id, center_id, route_id, temperature, humidity, is_alert,
    )
    return reading
