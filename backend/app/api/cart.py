import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.cart import CartItemCreate, CartItemUpdate
from app.services import cart_service

router = APIRouter(prefix="/marketplace/cart", tags=["cart"])


def _uuid(value: str, label: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError as exc:
        raise HTTPException(400, f"Invalid {label} UUID") from exc


@router.get("")
async def get_cart(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    return {"success": True, "data": await cart_service.cart_data(db, current_user.id), "message": "Cart"}


@router.post("/items", status_code=201)
async def add_cart_item(data: CartItemCreate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    item = await cart_service.add_item(db, current_user.id, data.product_id, data.quantity)
    return {"success": True, "data": {"id": str(item.id), "quantity": item.quantity}, "message": "Item added to cart"}


@router.put("/items/{item_id}")
async def update_cart_item(item_id: str, data: CartItemUpdate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    item = await cart_service.update_item(db, current_user.id, _uuid(item_id, "cart item"), data.quantity)
    return {"success": True, "data": {"id": str(item.id), "quantity": item.quantity}, "message": "Cart updated"}


@router.delete("/items/{item_id}")
async def delete_cart_item(item_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    await cart_service.remove_item(db, current_user.id, _uuid(item_id, "cart item"))
    return {"success": True, "data": {}, "message": "Item removed"}


@router.delete("")
async def clear_cart(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    await cart_service.clear(db, current_user.id)
    return {"success": True, "data": {}, "message": "Cart cleared"}


@router.post("/validate")
async def validate_cart(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    return {"success": True, "data": await cart_service.validate(db, current_user.id), "message": "Cart validation complete"}
