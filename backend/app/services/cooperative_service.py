import logging
import uuid
from datetime import date

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cooperative import Cooperative
from app.models.farmer import Farmer
from app.models.milk import MilkRecord
from app.repositories import cooperative_repo
from app.schemas.cooperative import CooperativeCreate, CooperativeUpdate

logger = logging.getLogger("dairy_ai.services.cooperative")


async def register_cooperative(db: AsyncSession, user_id: uuid.UUID, data: CooperativeCreate) -> Cooperative:
    logger.info(f"register_cooperative called | user_id={user_id} | name={data.name} | reg_no={data.registration_number}")

    logger.debug(f"Checking if cooperative profile already exists for user_id={user_id}")
    existing = await cooperative_repo.get_by_user_id(db, user_id)
    if existing:
        logger.warning(f"Cooperative profile already exists | user_id={user_id} | cooperative_id={existing.id}")
        raise ValueError("Cooperative profile already exists")

    logger.debug(f"Creating cooperative profile | user_id={user_id}")
    coop = await cooperative_repo.create(db, user_id, **data.model_dump(exclude_none=True))
    logger.info(f"Cooperative registered | cooperative_id={coop.id} | name={coop.name}")
    return coop


async def update_cooperative(db: AsyncSession, coop: Cooperative, data: CooperativeUpdate) -> Cooperative:
    logger.info(f"update_cooperative called | cooperative_id={coop.id}")
    fields = data.model_dump(exclude_unset=True)
    logger.debug(f"Update fields: {list(fields.keys())}")
    updated = await cooperative_repo.update(db, coop, **fields)
    logger.info(f"Cooperative updated | cooperative_id={updated.id}")
    return updated


async def get_cooperative_dashboard(db: AsyncSession, cooperative_id: uuid.UUID, user_id: uuid.UUID) -> dict:
    logger.info(f"get_cooperative_dashboard called | cooperative_id={cooperative_id} | user_id={user_id}")

    logger.debug(f"Fetching cooperative profile | cooperative_id={cooperative_id}")
    coop = await cooperative_repo.get_by_id(db, cooperative_id)
    if not coop:
        logger.warning(f"Cooperative not found | cooperative_id={cooperative_id}")
        return {}

    today = date.today()

    # Count registered farmers in the district
    logger.debug(f"Counting farmers in district={coop.district}")
    farmer_count_query = select(func.count(Farmer.id))
    if coop.district:
        farmer_count_query = farmer_count_query.where(Farmer.district == coop.district)
    farmers_in_district = (await db.execute(farmer_count_query)).scalar() or 0

    # Today's milk collection
    logger.debug(f"Fetching today's milk collection stats")
    milk_today = (await db.execute(
        select(func.sum(MilkRecord.quantity_litres)).where(MilkRecord.date == today)
    )).scalar() or 0

    logger.debug(f"Building cooperative dashboard | cooperative_id={cooperative_id}")
    dashboard = {
        "profile": {
            "id": str(coop.id),
            "name": coop.name,
            "registration_number": coop.registration_number,
            "cooperative_type": coop.cooperative_type.value if hasattr(coop.cooperative_type, "value") else coop.cooperative_type,
            "is_verified": coop.is_verified,
            "is_active": coop.is_active,
            "district": coop.district,
            "state": coop.state,
        },
        "stats": {
            "total_members": coop.total_members,
            "total_milk_collected_litres": round(float(coop.total_milk_collected_litres), 2),
            "total_revenue": round(float(coop.total_revenue), 2),
            "total_payouts": round(float(coop.total_payouts), 2),
            "milk_price_per_litre": round(float(coop.milk_price_per_litre), 2),
            "farmers_in_district": farmers_in_district,
            "milk_today_litres": round(float(milk_today), 2),
        },
        "collection_centers": coop.collection_centers or [],
        "services_offered": coop.services_offered or [],
    }

    logger.info(
        f"Cooperative dashboard built | cooperative_id={cooperative_id} | "
        f"members={coop.total_members} | revenue={coop.total_revenue} | "
        f"milk_today={round(float(milk_today), 2)}L"
    )
    return dashboard
