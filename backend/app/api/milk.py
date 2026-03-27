import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo, cattle_repo
from app.services import milk_service
from app.schemas.milk import MilkRecordCreate

router = APIRouter(tags=["milk"])


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    return farmer.id


async def _verify_cattle(db: AsyncSession, user: User, cattle_id_str: str) -> uuid.UUID:
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    cid = uuid.UUID(cattle_id_str)
    cattle = await cattle_repo.get_by_id(db, cid)
    if not cattle or cattle.farmer_id != farmer.id:
        raise HTTPException(status_code=404, detail="Cattle not found")
    return cid


@router.post("/cattle/{cattle_id}/milk-records", status_code=201)
async def create_milk_record(
    cattle_id: str, data: MilkRecordCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle(db, current_user, cattle_id)
    record = await milk_service.record_milk(db, cid, data)
    return {
        "success": True,
        "data": {
            "id": str(record.id),
            "quantity_litres": record.quantity_litres,
            "total_amount": record.total_amount,
        },
        "message": "Milk record saved",
    }


@router.get("/cattle/{cattle_id}/milk-records")
async def get_milk_records(
    cattle_id: str,
    days: int = Query(30, le=365),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cid = await _verify_cattle(db, current_user, cattle_id)
    records = await milk_service.get_milk_history(db, cid, days=days)
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
    farmer_id = await _get_farmer_id(db, current_user)
    summary = await milk_service.get_farmer_milk_summary(db, farmer_id, days=days)
    return {"success": True, "data": summary, "message": "Milk summary"}


@router.get("/milk-prices")
async def get_district_prices(
    district: str = Query(...),
    price_date: date | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    prices = await milk_service.get_district_prices(db, district, price_date)
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
    buyer = await milk_service.get_best_buyer(db, district, fat_pct)
    if not buyer:
        return {"success": True, "data": None, "message": "No buyer found"}
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
    cid = await _verify_cattle(db, current_user, cattle_id)
    prediction = await milk_service.predict_daily_yield(db, cid)
    return {"success": True, "data": prediction, "message": "Yield prediction"}
