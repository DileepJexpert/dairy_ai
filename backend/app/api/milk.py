import uuid
import logging
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo
from app.services import milk_service
from app.schemas.milk import MilkRecordCreate

logger = logging.getLogger("dairy_ai.api.milk")

router = APIRouter(tags=["milk"])


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    logger.debug(f"Looking up farmer profile for user_id={user.id}")
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found | user_id={user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    logger.debug(f"Farmer profile found | farmer_id={farmer.id}")
    return farmer.id


async def _verify_cattle(db: AsyncSession, user: User, cattle_id_str: str) -> uuid.UUID:
    logger.debug(f"Verifying cattle ownership | user_id={user.id} | cattle_id={cattle_id_str}")
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found during cattle verification | user_id={user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    cid = uuid.UUID(cattle_id_str)
    cattle = await cattle_repo.get_by_id(db, cid)
    if not cattle or cattle.farmer_id != farmer.id:
        logger.warning(f"Cattle not found or ownership mismatch | cattle_id={cattle_id_str} | farmer_id={farmer.id}")
        raise HTTPException(status_code=404, detail="Cattle not found")
    logger.debug(f"Cattle ownership verified | cattle_id={cid}")
    return cid


@router.post("/cattle/{cattle_id}/milk-records", status_code=201)
async def create_milk_record(
    cattle_id: str, data: MilkRecordCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /cattle/{cattle_id}/milk-records called | user_id={current_user.id} | quantity={data.quantity_litres}L")
    cid = await _verify_cattle(db, current_user, cattle_id)
    logger.debug(f"Calling milk_service.record_milk | cattle_id={cid} | session={data.session}")
    try:
        record = await milk_service.record_milk(db, cid, data)
        logger.info(f"Milk record saved | record_id={record.id} | cattle_id={cid} | quantity={record.quantity_litres}L | amount={record.total_amount}")
        return {
            "success": True,
            "data": {
                "id": str(record.id),
                "quantity_litres": record.quantity_litres,
                "total_amount": record.total_amount,
            },
            "message": "Milk record saved",
        }
    except Exception as e:
        logger.error(f"Failed to record milk for cattle_id={cid}: {e}")
        raise


@router.get("/cattle/{cattle_id}/milk-records")
async def get_milk_records(
    cattle_id: str,
    days: int = Query(30, le=365),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/{cattle_id}/milk-records called | user_id={current_user.id} | days={days}")
    cid = await _verify_cattle(db, current_user, cattle_id)
    logger.debug(f"Calling milk_service.get_milk_history | cattle_id={cid} | days={days}")
    records = await milk_service.get_milk_history(db, cid, days=days)
    logger.info(f"Milk records retrieved | cattle_id={cid} | count={len(records)}")
    return {
        "success": True,
        "data": [
            {
                "id": str(r.id),
                "date": str(r.date),
                "session": r.session.value if hasattr(r.session, 'value') else r.session,
                "quantity_litres": r.quantity_litres,
                "total_amount": r.total_amount,
            }
            for r in records
        ],
        "message": "Milk records",
    }


@router.get("/farmers/me/milk-summary")
async def get_milk_summary(
    days: int = Query(30, le=365),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /farmers/me/milk-summary called | user_id={current_user.id} | days={days}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling milk_service.get_farmer_milk_summary | farmer_id={farmer_id} | days={days}")
    summary = await milk_service.get_farmer_milk_summary(db, farmer_id, days=days)
    logger.info(f"Milk summary retrieved | farmer_id={farmer_id}")
    return {"success": True, "data": summary, "message": "Milk summary"}


@router.get("/milk-prices")
async def get_district_prices(
    district: str = Query(...),
    price_date: date | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /milk-prices called | user_id={current_user.id} | district={district} | price_date={price_date}")
    logger.debug(f"Calling milk_service.get_district_prices | district={district}")
    prices = await milk_service.get_district_prices(db, district, price_date)
    logger.info(f"Milk prices retrieved | district={district} | count={len(prices)}")
    return {
        "success": True,
        "data": [
            {
                "buyer_name": p.buyer_name,
                "buyer_type": p.buyer_type.value if hasattr(p.buyer_type, 'value') else p.buyer_type,
                "price_per_litre": p.price_per_litre,
                "fat_pct_basis": p.fat_pct_basis,
                "date": str(p.date),
            }
            for p in prices
        ],
        "message": "District milk prices",
    }


@router.get("/milk-prices/best-buyer")
async def get_best_buyer(
    district: str = Query(...),
    fat_pct: float | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /milk-prices/best-buyer called | user_id={current_user.id} | district={district} | fat_pct={fat_pct}")
    logger.debug(f"Calling milk_service.get_best_buyer | district={district} | fat_pct={fat_pct}")
    buyer = await milk_service.get_best_buyer(db, district, fat_pct)
    if not buyer:
        logger.info(f"No best buyer found | district={district} | fat_pct={fat_pct}")
        return {"success": True, "data": None, "message": "No buyer found"}
    logger.info(f"Best buyer found | district={district} | buyer={buyer.buyer_name} | price={buyer.price_per_litre}")
    return {
        "success": True,
        "data": {
            "buyer_name": buyer.buyer_name,
            "price_per_litre": buyer.price_per_litre,
            "buyer_type": buyer.buyer_type.value if hasattr(buyer.buyer_type, 'value') else buyer.buyer_type,
        },
        "message": "Best buyer",
    }


@router.get("/cattle/{cattle_id}/yield-prediction")
async def get_yield_prediction(
    cattle_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /cattle/{cattle_id}/yield-prediction called | user_id={current_user.id}")
    cid = await _verify_cattle(db, current_user, cattle_id)
    logger.debug(f"Calling milk_service.predict_daily_yield | cattle_id={cid}")
    try:
        prediction = await milk_service.predict_daily_yield(db, cid)
        logger.info(f"Yield prediction retrieved | cattle_id={cid} | prediction={prediction}")
        return {"success": True, "data": prediction, "message": "Yield prediction"}
    except Exception as e:
        logger.error(f"Failed to predict yield for cattle_id={cid}: {e}")
        raise
