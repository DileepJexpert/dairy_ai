import uuid

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.delivery_address import DeliveryAddress
from app.repositories import delivery_address_repo
from app.schemas.delivery_address import DeliveryAddressCreate, DeliveryAddressUpdate


def serialize(address: DeliveryAddress) -> dict:
    return {
        "id": str(address.id), "recipient_name": address.recipient_name, "phone": address.phone,
        "address_line1": address.address_line1, "address_line2": address.address_line2, "landmark": address.landmark,
        "village_or_city": address.village_or_city, "district": address.district, "state": address.state,
        "postal_code": address.postal_code, "is_default": address.is_default,
    }


async def list_addresses(db: AsyncSession, user_id: uuid.UUID) -> list[dict]:
    return [serialize(address) for address in await delivery_address_repo.list_for_user(db, user_id)]


async def create(db: AsyncSession, user_id: uuid.UUID, data: DeliveryAddressCreate) -> DeliveryAddress:
    existing = await delivery_address_repo.list_for_user(db, user_id)
    make_default = data.is_default or not existing
    if make_default:
        await delivery_address_repo.clear_default(db, user_id)
    values = data.model_dump()
    values["is_default"] = make_default
    address = DeliveryAddress(user_id=user_id, **values)
    db.add(address)
    await db.flush()
    return address


async def update_address(db: AsyncSession, user_id: uuid.UUID, address_id: uuid.UUID, data: DeliveryAddressUpdate) -> DeliveryAddress:
    address = await delivery_address_repo.get_for_user(db, user_id, address_id)
    if address is None:
        raise HTTPException(404, "Delivery address not found")
    changes = data.model_dump(exclude_unset=True)
    if changes.get("is_default") is True:
        await delivery_address_repo.clear_default(db, user_id)
    for field, value in changes.items():
        setattr(address, field, value)
    await db.flush()
    return address


async def delete(db: AsyncSession, user_id: uuid.UUID, address_id: uuid.UUID) -> None:
    address = await delivery_address_repo.get_for_user(db, user_id, address_id)
    if address is None:
        raise HTTPException(404, "Delivery address not found")
    was_default = address.is_default
    await db.delete(address)
    await db.flush()
    if was_default:
        remaining = await delivery_address_repo.list_for_user(db, user_id)
        if remaining:
            remaining[0].is_default = True
            await db.flush()
