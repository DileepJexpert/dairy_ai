import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.withdrawal import WithdrawalRecord, AdministrationRoute

logger = logging.getLogger("dairy_ai.services.withdrawal")

# Built-in withdrawal database: active_ingredient -> {milk_hours, meat_days}
WITHDRAWAL_DATABASE: list[dict] = [
    {
        "active_ingredient": "Oxytetracycline",
        "common_names": ["Terramycin", "Oxytet", "OTC"],
        "milk_withdrawal_hours": 96,
        "meat_withdrawal_days": 28,
        "notes": "Broad-spectrum tetracycline antibiotic. Common for respiratory and reproductive infections.",
    },
    {
        "active_ingredient": "Penicillin (Procaine)",
        "common_names": ["Procaine Penicillin", "Pen-G", "Penicillin G"],
        "milk_withdrawal_hours": 72,
        "meat_withdrawal_days": 14,
        "notes": "First-line antibiotic for many bacterial infections. Commonly used for mastitis.",
    },
    {
        "active_ingredient": "Gentamicin",
        "common_names": ["Gentamicin Sulfate", "Garamycin"],
        "milk_withdrawal_hours": 72,
        "meat_withdrawal_days": 18,
        "notes": "Aminoglycoside antibiotic. Used for severe gram-negative infections.",
    },
    {
        "active_ingredient": "Enrofloxacin",
        "common_names": ["Baytril", "Enroflox"],
        "milk_withdrawal_hours": 96,
        "meat_withdrawal_days": 14,
        "notes": "Fluoroquinolone antibiotic. Restricted use in dairy cattle in some regions.",
    },
    {
        "active_ingredient": "Ceftriaxone",
        "common_names": ["Rocephin", "Ceftriaxone Sodium"],
        "milk_withdrawal_hours": 72,
        "meat_withdrawal_days": 5,
        "notes": "Third-generation cephalosporin. Used for severe bacterial infections.",
    },
    {
        "active_ingredient": "Ivermectin",
        "common_names": ["Ivomec", "Ivermectin Pour-On"],
        "milk_withdrawal_hours": 96,
        "meat_withdrawal_days": 35,
        "notes": "Antiparasitic (not antibiotic). Used for internal and external parasites.",
    },
    {
        "active_ingredient": "Amoxicillin",
        "common_names": ["Amoxicillin Trihydrate", "Vetrimoxin"],
        "milk_withdrawal_hours": 60,
        "meat_withdrawal_days": 15,
        "notes": "Broad-spectrum penicillin-type antibiotic. Common for respiratory and urinary infections.",
    },
    {
        "active_ingredient": "Trimethoprim-Sulfa",
        "common_names": ["TMP-SMX", "Tribrissen", "Sulfatrim"],
        "milk_withdrawal_hours": 96,
        "meat_withdrawal_days": 10,
        "notes": "Combination antibiotic. Used for respiratory, urinary, and gastrointestinal infections.",
    },
    {
        "active_ingredient": "Tylosin",
        "common_names": ["Tylan", "Tylosin Tartrate"],
        "milk_withdrawal_hours": 96,
        "meat_withdrawal_days": 21,
        "notes": "Macrolide antibiotic. Used for mastitis and respiratory infections.",
    },
    {
        "active_ingredient": "Ceftiofur",
        "common_names": ["Excenel", "Naxcel", "Spectramast"],
        "milk_withdrawal_hours": 72,
        "meat_withdrawal_days": 2,
        "notes": "Third-generation cephalosporin. Intramammary formulation for mastitis. Short meat withdrawal.",
    },
]

# Lookup by lowercased active ingredient for quick matching
_WITHDRAWAL_LOOKUP: dict[str, dict] = {
    entry["active_ingredient"].lower(): entry for entry in WITHDRAWAL_DATABASE
}


def _find_withdrawal_info(active_ingredient: str) -> dict | None:
    """Find withdrawal info by active ingredient name (case-insensitive, partial match)."""
    key = active_ingredient.strip().lower()

    # Exact match first
    if key in _WITHDRAWAL_LOOKUP:
        return _WITHDRAWAL_LOOKUP[key]

    # Partial match
    for ingredient_key, entry in _WITHDRAWAL_LOOKUP.items():
        if key in ingredient_key or ingredient_key in key:
            return entry
        # Check common names too
        for common_name in entry["common_names"]:
            if key in common_name.lower() or common_name.lower() in key:
                return entry

    return None


def _calculate_safe_dates(
    treatment_end_date: date,
    milk_withdrawal_hours: int,
    meat_withdrawal_days: int,
) -> tuple[date, date]:
    """Calculate milk and meat safe dates from treatment end date."""
    milk_withdrawal_days = milk_withdrawal_hours // 24
    # Round up: if hours don't divide evenly into days, add an extra day
    if milk_withdrawal_hours % 24 > 0:
        milk_withdrawal_days += 1

    milk_safe_date = treatment_end_date + timedelta(days=milk_withdrawal_days)
    meat_safe_date = treatment_end_date + timedelta(days=meat_withdrawal_days)
    return milk_safe_date, meat_safe_date


async def record_treatment(
    db: AsyncSession,
    cattle_id: uuid.UUID,
    farmer_id: uuid.UUID,
    data: dict,
) -> WithdrawalRecord:
    """Create a withdrawal record, auto-calculating safe dates from the built-in database."""
    logger.info(
        f"record_treatment called | cattle_id={cattle_id} | farmer_id={farmer_id} "
        f"| medicine={data.get('medicine_name')} | ingredient={data.get('active_ingredient')}"
    )

    active_ingredient = data["active_ingredient"]
    treatment_end_date = data["treatment_end_date"]
    if isinstance(treatment_end_date, str):
        treatment_end_date = date.fromisoformat(treatment_end_date)

    treatment_start_date = data["treatment_start_date"]
    if isinstance(treatment_start_date, str):
        treatment_start_date = date.fromisoformat(treatment_start_date)

    # Look up withdrawal periods from built-in database
    withdrawal_info = _find_withdrawal_info(active_ingredient)

    if withdrawal_info:
        milk_withdrawal_hours = withdrawal_info["milk_withdrawal_hours"]
        meat_withdrawal_days = withdrawal_info["meat_withdrawal_days"]
        milk_withdrawal_days = milk_withdrawal_hours // 24
        if milk_withdrawal_hours % 24 > 0:
            milk_withdrawal_days += 1
        logger.info(
            f"Found withdrawal info | ingredient={active_ingredient} "
            f"| milk_hours={milk_withdrawal_hours} | meat_days={meat_withdrawal_days}"
        )
    else:
        # Use manually provided values or defaults
        milk_withdrawal_days = data.get("milk_withdrawal_days", 4)
        meat_withdrawal_days = data.get("meat_withdrawal_days", 14)
        logger.warning(
            f"No withdrawal info found for '{active_ingredient}', using provided/default values "
            f"| milk_days={milk_withdrawal_days} | meat_days={meat_withdrawal_days}"
        )

    milk_safe_date, meat_safe_date = _calculate_safe_dates(
        treatment_end_date,
        milk_withdrawal_days * 24 if not withdrawal_info else milk_withdrawal_hours,
        meat_withdrawal_days,
    )

    # Parse route enum
    route_str = data.get("route", "injection")
    try:
        route = AdministrationRoute(route_str)
    except ValueError:
        route = AdministrationRoute.injection

    record = WithdrawalRecord(
        cattle_id=cattle_id,
        farmer_id=farmer_id,
        consultation_id=data.get("consultation_id"),
        medicine_name=data["medicine_name"],
        active_ingredient=active_ingredient,
        dosage=data.get("dosage"),
        route=route,
        treatment_start_date=treatment_start_date,
        treatment_end_date=treatment_end_date,
        milk_withdrawal_days=milk_withdrawal_days if not withdrawal_info else milk_withdrawal_days,
        meat_withdrawal_days=meat_withdrawal_days,
        milk_safe_date=milk_safe_date,
        meat_safe_date=meat_safe_date,
        notes=data.get("notes"),
    )
    db.add(record)
    await db.flush()

    logger.info(
        f"Withdrawal record created | record_id={record.id} | cattle_id={cattle_id} "
        f"| milk_safe={milk_safe_date} | meat_safe={meat_safe_date}"
    )
    return record


async def get_active_withdrawals(
    db: AsyncSession,
    farmer_id: uuid.UUID,
) -> list[dict]:
    """Get all cattle currently in withdrawal period for a farmer."""
    logger.info(f"get_active_withdrawals called | farmer_id={farmer_id}")
    today = date.today()

    query = select(WithdrawalRecord).where(
        and_(
            WithdrawalRecord.farmer_id == farmer_id,
            WithdrawalRecord.is_milk_cleared == False,  # noqa: E712
            WithdrawalRecord.milk_safe_date >= today,
        )
    ).order_by(WithdrawalRecord.milk_safe_date.asc())

    result = await db.execute(query)
    records = list(result.scalars().all())

    active = []
    for r in records:
        days_remaining_milk = (r.milk_safe_date - today).days
        days_remaining_meat = (r.meat_safe_date - today).days

        active.append({
            "id": str(r.id),
            "cattle_id": str(r.cattle_id),
            "medicine_name": r.medicine_name,
            "active_ingredient": r.active_ingredient,
            "route": r.route.value,
            "treatment_start_date": str(r.treatment_start_date),
            "treatment_end_date": str(r.treatment_end_date),
            "milk_safe_date": str(r.milk_safe_date),
            "meat_safe_date": str(r.meat_safe_date),
            "days_remaining_milk": max(days_remaining_milk, 0),
            "days_remaining_meat": max(days_remaining_meat, 0),
            "is_milk_cleared": r.is_milk_cleared,
            "is_meat_cleared": r.is_meat_cleared,
            "milk_status": "safe" if days_remaining_milk <= 0 else "withdrawal",
            "meat_status": "safe" if days_remaining_meat <= 0 else "withdrawal",
        })

    logger.info(f"Active withdrawals found | farmer_id={farmer_id} | count={len(active)}")
    return active


async def get_cattle_withdrawal_status(
    db: AsyncSession,
    cattle_id: uuid.UUID,
) -> dict:
    """Check if a specific cattle's milk is safe to sell."""
    logger.info(f"get_cattle_withdrawal_status called | cattle_id={cattle_id}")
    today = date.today()

    query = select(WithdrawalRecord).where(
        and_(
            WithdrawalRecord.cattle_id == cattle_id,
            WithdrawalRecord.is_milk_cleared == False,  # noqa: E712
        )
    ).order_by(WithdrawalRecord.milk_safe_date.desc())

    result = await db.execute(query)
    records = list(result.scalars().all())

    if not records:
        logger.info(f"No withdrawal records | cattle_id={cattle_id} | milk_safe=True")
        return {
            "cattle_id": str(cattle_id),
            "is_milk_safe": True,
            "is_meat_safe": True,
            "active_withdrawals": 0,
            "message": "No active withdrawal periods. Milk and meat are safe.",
            "records": [],
        }

    is_milk_safe = all(r.milk_safe_date <= today for r in records)
    is_meat_safe = all(r.meat_safe_date <= today for r in records)

    # Find the latest safe dates across all active records
    latest_milk_safe = max(r.milk_safe_date for r in records)
    latest_meat_safe = max(r.meat_safe_date for r in records)

    active_count = sum(1 for r in records if r.milk_safe_date > today)

    if is_milk_safe:
        message = "All withdrawal periods complete. Milk is safe to sell."
    else:
        days_left = (latest_milk_safe - today).days
        message = f"Milk NOT safe. {active_count} active withdrawal(s). Milk safe after {latest_milk_safe} ({days_left} days remaining)."

    logger.info(
        f"Cattle withdrawal status | cattle_id={cattle_id} | milk_safe={is_milk_safe} "
        f"| meat_safe={is_meat_safe} | active={active_count}"
    )

    return {
        "cattle_id": str(cattle_id),
        "is_milk_safe": is_milk_safe,
        "is_meat_safe": is_meat_safe,
        "active_withdrawals": active_count,
        "latest_milk_safe_date": str(latest_milk_safe),
        "latest_meat_safe_date": str(latest_meat_safe),
        "message": message,
        "records": [
            {
                "id": str(r.id),
                "medicine_name": r.medicine_name,
                "active_ingredient": r.active_ingredient,
                "treatment_end_date": str(r.treatment_end_date),
                "milk_safe_date": str(r.milk_safe_date),
                "meat_safe_date": str(r.meat_safe_date),
                "days_remaining_milk": max((r.milk_safe_date - today).days, 0),
                "days_remaining_meat": max((r.meat_safe_date - today).days, 0),
            }
            for r in records
        ],
    }


async def clear_withdrawal(
    db: AsyncSession,
    record_id: uuid.UUID,
    cleared_by: str,
) -> WithdrawalRecord:
    """Vet manually clears a withdrawal record (e.g., after lab test confirms safe)."""
    logger.info(f"clear_withdrawal called | record_id={record_id} | cleared_by={cleared_by}")

    query = select(WithdrawalRecord).where(WithdrawalRecord.id == record_id)
    result = await db.execute(query)
    record = result.scalar_one_or_none()

    if not record:
        logger.warning(f"Withdrawal record not found | record_id={record_id}")
        raise ValueError(f"Withdrawal record {record_id} not found")

    record.is_milk_cleared = True
    record.is_meat_cleared = True
    record.cleared_by = cleared_by
    record.cleared_at = datetime.now(timezone.utc)
    await db.flush()

    logger.info(f"Withdrawal cleared | record_id={record_id} | cleared_by={cleared_by}")
    return record


def get_withdrawal_database() -> list[dict]:
    """Return the built-in antibiotic withdrawal period database."""
    logger.info("get_withdrawal_database called")
    return [
        {
            "active_ingredient": entry["active_ingredient"],
            "common_names": entry["common_names"],
            "milk_withdrawal_hours": entry["milk_withdrawal_hours"],
            "milk_withdrawal_days": entry["milk_withdrawal_hours"] // 24 + (1 if entry["milk_withdrawal_hours"] % 24 > 0 else 0),
            "meat_withdrawal_days": entry["meat_withdrawal_days"],
            "notes": entry["notes"],
        }
        for entry in WITHDRAWAL_DATABASE
    ]


async def check_milk_collection_safety(
    db: AsyncSession,
    farmer_id: uuid.UUID,
) -> dict:
    """Check if ANY cattle belonging to the farmer has an active withdrawal period.

    This is critical for milk collection: if even one cow has active withdrawal,
    the farmer must segregate that cow's milk.
    """
    logger.info(f"check_milk_collection_safety called | farmer_id={farmer_id}")
    today = date.today()

    query = select(WithdrawalRecord).where(
        and_(
            WithdrawalRecord.farmer_id == farmer_id,
            WithdrawalRecord.is_milk_cleared == False,  # noqa: E712
            WithdrawalRecord.milk_safe_date > today,
        )
    ).order_by(WithdrawalRecord.milk_safe_date.asc())

    result = await db.execute(query)
    records = list(result.scalars().all())

    if not records:
        logger.info(f"Milk collection safe | farmer_id={farmer_id}")
        return {
            "farmer_id": str(farmer_id),
            "is_collection_safe": True,
            "warning": False,
            "message": "All milk is safe for collection. No active withdrawal periods.",
            "cattle_in_withdrawal": [],
        }

    # Group by cattle_id
    cattle_warnings: dict[str, dict] = {}
    for r in records:
        cattle_key = str(r.cattle_id)
        days_left = (r.milk_safe_date - today).days
        if cattle_key not in cattle_warnings:
            cattle_warnings[cattle_key] = {
                "cattle_id": cattle_key,
                "medicines": [],
                "latest_milk_safe_date": str(r.milk_safe_date),
                "max_days_remaining": days_left,
            }
        cattle_warnings[cattle_key]["medicines"].append({
            "medicine_name": r.medicine_name,
            "milk_safe_date": str(r.milk_safe_date),
            "days_remaining": days_left,
        })
        if days_left > cattle_warnings[cattle_key]["max_days_remaining"]:
            cattle_warnings[cattle_key]["max_days_remaining"] = days_left
            cattle_warnings[cattle_key]["latest_milk_safe_date"] = str(r.milk_safe_date)

    cattle_list = list(cattle_warnings.values())

    logger.warning(
        f"Milk collection WARNING | farmer_id={farmer_id} | cattle_in_withdrawal={len(cattle_list)}"
    )

    return {
        "farmer_id": str(farmer_id),
        "is_collection_safe": False,
        "warning": True,
        "message": (
            f"WARNING: {len(cattle_list)} cattle have active antibiotic withdrawal periods. "
            f"Their milk must NOT be mixed with collection milk. "
            f"Segregate milk from these cattle until withdrawal period ends."
        ),
        "cattle_in_withdrawal": cattle_list,
    }
