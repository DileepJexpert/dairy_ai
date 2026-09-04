import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.delivery_address import DeliveryAddressCreate, DeliveryAddressUpdate
from app.services import delivery_address_service

router = APIRouter(prefix="/marketplace/addresses", tags=["delivery addresses"])


def _uuid(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError as exc:
        raise HTTPException(400, "Invalid delivery address UUID") from exc


@router.get("")
async def list_delivery_addresses(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    return {"success": True, "data": await delivery_address_service.list_addresses(db, current_user.id), "message": "Delivery addresses"}


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_delivery_address(data: DeliveryAddressCreate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    address = await delivery_address_service.create(db, current_user.id, data)
    return {"success": True, "data": delivery_address_service.serialize(address), "message": "Delivery address created"}


@router.put("/{address_id}")
async def update_delivery_address(address_id: str, data: DeliveryAddressUpdate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    address = await delivery_address_service.update_address(db, current_user.id, _uuid(address_id), data)
    return {"success": True, "data": delivery_address_service.serialize(address), "message": "Delivery address updated"}


@router.delete("/{address_id}")
async def delete_delivery_address(address_id: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    await delivery_address_service.delete(db, current_user.id, _uuid(address_id))
    return {"success": True, "data": {}, "message": "Delivery address deleted"}
