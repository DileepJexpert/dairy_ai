import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.repositories import farmer_repo
from app.services import finance_service
from app.schemas.finance import TransactionCreate

logger = logging.getLogger("dairy_ai.api.finance")

router = APIRouter(tags=["finance"])


async def _get_farmer_id(db: AsyncSession, user: User) -> uuid.UUID:
    logger.debug(f"Looking up farmer profile for user_id={user.id}")
    farmer = await farmer_repo.get_by_user_id(db, user.id)
    if not farmer:
        logger.warning(f"Farmer profile not found | user_id={user.id}")
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    logger.debug(f"Farmer profile found | farmer_id={farmer.id}")
    return farmer.id


@router.post("/transactions", status_code=201)
async def create_transaction(
    data: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"POST /transactions called | user_id={current_user.id} | type={data.type} | category={data.category} | amount={data.amount}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling finance_service.add_transaction | farmer_id={farmer_id} | amount={data.amount}")
    try:
        txn = await finance_service.add_transaction(db, farmer_id, data)
        logger.info(f"Transaction recorded | txn_id={txn.id} | farmer_id={farmer_id} | amount={txn.amount}")
        return {
            "success": True,
            "data": {"id": str(txn.id), "amount": txn.amount},
            "message": "Transaction recorded",
        }
    except Exception as e:
        logger.error(f"Failed to create transaction for farmer_id={farmer_id}: {e}")
        raise


@router.get("/transactions")
async def list_transactions(
    type: str | None = Query(None),
    category: str | None = Query(None),
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /transactions called | user_id={current_user.id} | type={type} | category={category} | limit={limit} | offset={offset}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling finance_service.get_transactions | farmer_id={farmer_id}")
    txns = await finance_service.get_transactions(db, farmer_id, type_filter=type, category=category, limit=limit, offset=offset)
    logger.info(f"Transactions retrieved | farmer_id={farmer_id} | count={len(txns)}")
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
    logger.info(f"GET /farmers/me/profit-loss called | user_id={current_user.id} | months={months}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling finance_service.get_profit_loss | farmer_id={farmer_id} | months={months}")
    try:
        pl = await finance_service.get_profit_loss(db, farmer_id, months=months)
        logger.info(f"Profit/Loss data retrieved | farmer_id={farmer_id} | months={months}")
        return {"success": True, "data": pl, "message": "Profit & Loss"}
    except Exception as e:
        logger.error(f"Failed to get profit/loss for farmer_id={farmer_id}: {e}")
        raise


@router.get("/farmers/me/cattle-economics")
async def cattle_economics(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /farmers/me/cattle-economics called | user_id={current_user.id}")
    farmer_id = await _get_farmer_id(db, current_user)
    logger.debug(f"Calling finance_service.get_profit_loss for cattle economics | farmer_id={farmer_id}")
    try:
        # Simplified: just return P&L for now
        pl = await finance_service.get_profit_loss(db, farmer_id, months=6)
        logger.info(f"Cattle economics retrieved | farmer_id={farmer_id}")
        return {"success": True, "data": pl, "message": "Cattle economics"}
    except Exception as e:
        logger.error(f"Failed to get cattle economics for farmer_id={farmer_id}: {e}")
        raise
