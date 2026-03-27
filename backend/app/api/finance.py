import uuid
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo
from app.services import finance_service
from app.schemas.finance import TransactionCreate

router = APIRouter(tags=["finance"])


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    return farmer.id


@router.post("/transactions", status_code=201)
async def create_transaction(
    data: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer_id = await _get_farmer_id(db, current_user)
    txn = await finance_service.add_transaction(db, farmer_id, data)
    return {
        "success": True,
        "data": {"id": str(txn.id), "amount": txn.amount},
        "message": "Transaction recorded",
    }


@router.get("/transactions")
async def list_transactions(
    type: str | None = Query(None),
    category: str | None = Query(None),
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer_id = await _get_farmer_id(db, current_user)
    txns = await finance_service.get_transactions(db, farmer_id, type_filter=type, category=category, limit=limit, offset=offset)
    return {
        "success": True,
        "data": [
            {
                "id": str(t.id),
                "type": t.type.value if hasattr(t.type, 'value') else t.type,
                "category": t.category.value if hasattr(t.category, 'value') else t.category,
                "amount": t.amount,
                "description": t.description,
                "date": str(t.date),
            }
            for t in txns
        ],
        "message": "Transactions",
    }


@router.get("/farmers/me/profit-loss")
async def profit_loss(
    months: int = Query(6, le=24),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer_id = await _get_farmer_id(db, current_user)
    pl = await finance_service.get_profit_loss(db, farmer_id, months=months)
    return {"success": True, "data": pl, "message": "Profit & Loss"}


@router.get("/farmers/me/cattle-economics")
async def cattle_economics(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    farmer_id = await _get_farmer_id(db, current_user)
    # Simplified: just return P&L for now
    pl = await finance_service.get_profit_loss(db, farmer_id, months=6)
    return {"success": True, "data": pl, "message": "Cattle economics"}
