"""Authenticated, server-owned wishlist and atomic save-for-later operations."""
import uuid
from typing import Literal
from pydantic import BaseModel, Field, ConfigDict
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.models.customer_commerce import WishlistEntry, SavedCartItem, StoreHelp, SupportTicket, CustomerPreferences
from app.models.notification import Notification, NotificationType
from app.services.commerce_admin_service import audit
from app.repositories import product_repo, cart_repo
from app.services import cart_service

router = APIRouter(prefix="/marketplace", tags=["customer commerce"])


def result(data):
    return {"success": True, "data": data}


@router.get('/wallet')
async def wallet_status(user: User = Depends(get_current_user)):
    # No real wallet ledger or payment gateway is configured. Never invent funds.
    return result({'enabled': False, 'total_balance': '0', 'milk_payout_balance': '0', 'store_credit_balance': '0', 'transactions': [],
                   'message': 'Wallet funding, bank withdrawals and milk settlement are not enabled. Use the available payment methods shown at checkout.'})


class ProfileInput(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    name: str = Field(min_length=1, max_length=120)
    village: str = Field(default='', max_length=150)
    district: str = Field(default='', max_length=150)
    state: str = Field(default='', max_length=100)
    language: str = Field(default='en', min_length=2, max_length=10)
    notify_health: bool = True
    notify_vaccination: bool = True
    notify_consultation: bool = True
    notify_payment: bool = True


@router.get('/profile')
async def customer_profile(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    row = await db.get(CustomerPreferences, user.id)
    return result((row.content if row else {}) | {'name': user.display_name or ''})


@router.put('/profile')
async def update_customer_profile(data: ProfileInput, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    user.display_name = data.name.strip()
    row = await db.get(CustomerPreferences, user.id)
    if not row:
        row = CustomerPreferences(user_id=user.id, content=data.model_dump())
        db.add(row)
    else:
        row.content = data.model_dump()
    await db.flush()
    return result(row.content)


@router.get("/wishlist")
async def wishlist(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(WishlistEntry).where(WishlistEntry.user_id == user.id).order_by(WishlistEntry.created_at.desc()))).scalars()
    return result([r.product_key for r in rows])


@router.put("/wishlist/{key}")
async def save_wish(key: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        target_id = uuid.UUID(key.removeprefix("family-"))
    except ValueError:
        raise HTTPException(422, "Invalid product reference")
    key = ('family-' if key.startswith('family-') else '') + str(target_id)
    if key.startswith("family-"):
        families = await product_repo.list_families(db, is_published=True)
        valid = any(f.id == target_id for f in families)
    else:
        product = await product_repo.get(db, target_id)
        from app.repositories import vendor_repo
        vendor = await vendor_repo.get_by_id(db, product.vendor_id) if product else None
        valid = product and product.is_active and product.publication_status != "draft" and vendor and vendor.is_active
    if not valid:
        raise HTTPException(404, "Product unavailable")
    # Serialize concurrent changes for one account; PUT is idempotent.
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    if not await db.get(WishlistEntry, (user.id, key)):
        db.add(WishlistEntry(user_id=user.id, product_key=key))
        await db.flush()
    return result({"product_key": key})


@router.delete("/wishlist/{key}")
async def remove_wish(key: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        key = ('family-' if key.startswith('family-') else '') + str(uuid.UUID(key.removeprefix('family-')))
    except ValueError:
        raise HTTPException(422, 'Invalid product reference')
    row = await db.get(WishlistEntry, (user.id, key))
    if row:
        await db.delete(row)
    return result({})


@router.get("/saved-items")
async def saved_items(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(SavedCartItem).where(SavedCartItem.user_id == user.id))).scalars()
    return result([await cart_service.item_data(db, row) for row in rows])


@router.post("/cart/items/{item_id}/save")
async def save_cart_item(item_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    cart = await cart_repo.get_or_create_active_cart(db, user.id)
    item = await cart_repo.item_for_cart(db, cart.id, item_id)
    if not item:
        raise HTTPException(404, "Cart item not found")
    saved = await db.get(SavedCartItem, (user.id, item.product_id))
    if saved:
        saved.quantity += item.quantity
    else:
        db.add(SavedCartItem(user_id=user.id, product_id=item.product_id, quantity=item.quantity, price_when_added=item.price_when_added))
    await db.delete(item)
    await db.flush()
    return result({})


@router.post("/saved-items/{product_id}/restore")
async def restore_saved(product_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    row = await db.get(SavedCartItem, (user.id, product_id))
    if not row:
        raise HTTPException(404, "Saved item not found")
    await cart_service.add_item(db, user.id, product_id, row.quantity)
    await db.delete(row)
    await db.flush()
    return result({})


@router.delete("/saved-items/{product_id}")
async def delete_saved(product_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    row = await db.get(SavedCartItem, (user.id, product_id))
    if row:
        await db.delete(row)
    return result({})


class FaqInput(BaseModel):
    category: str = Field(min_length=1, max_length=100)
    question: str = Field(min_length=1, max_length=300)
    answer: str = Field(min_length=1, max_length=4000)


class HelpInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    faqs: list[FaqInput] = Field(default_factory=list, max_length=100)
    contact_message: str = Field(default='', max_length=2000)


@router.get('/help')
async def help_content(db: AsyncSession = Depends(get_db)):
    row = await db.get(StoreHelp, 'help')
    return result(row.content if row else {'faqs': [], 'contact_message': 'Pre-launch enquiries can be submitted below. No deliveries or payments are currently processed.'})


@router.put('/admin/help')
async def save_help(data: HelpInput, user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
    row = await db.get(StoreHelp, 'help')
    if not row:
        row = StoreHelp(key='help', content=data.model_dump())
        db.add(row)
    else:
        row.content = data.model_dump()
    audit(db, user, 'help.publish', 'content', 'help', 'Updated help content')
    await db.flush()
    return result(row.content)


class TicketInput(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    subject: str = Field(min_length=3, max_length=200)
    message: str = Field(min_length=10, max_length=4000)


def ticket_data(row):
    return {'id': str(row.id), 'subject': row.subject, 'message': row.message,
            'status': row.status, 'reply': row.reply, 'created_at': row.created_at.isoformat() + 'Z'}


@router.post('/support', status_code=201)
async def create_ticket(data: TicketInput, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    row = SupportTicket(user_id=user.id, **data.model_dump())
    db.add(row)
    await db.flush()
    return result(ticket_data(row))


@router.get('/support')
async def my_tickets(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(SupportTicket).where(SupportTicket.user_id == user.id).order_by(SupportTicket.created_at.desc()))).scalars()
    return result([ticket_data(r) for r in rows])


@router.get('/admin/support')
async def all_tickets(user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(SupportTicket, User.phone).join(User, User.id == SupportTicket.user_id).order_by(SupportTicket.created_at.desc()).limit(500))).all()
    return result([ticket_data(r) | {'customer_phone': phone} for r, phone in rows])


class TicketUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    status: Literal['OPEN', 'IN_PROGRESS', 'CLOSED']
    reply: str = Field(min_length=1, max_length=4000)


@router.patch('/admin/support/{ticket_id}')
async def reply_ticket(ticket_id: uuid.UUID, data: TicketUpdate, user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
    row = (await db.execute(select(SupportTicket).where(SupportTicket.id == ticket_id).with_for_update())).scalar_one_or_none()
    if not row:
        raise HTTPException(404, 'Enquiry not found')
    if row.reply != data.reply or row.status != data.status:
        row.reply, row.status = data.reply, data.status
        db.add(Notification(user_id=row.user_id, type=NotificationType.general, title='Support reply received', body=data.reply, data={'ticket_id': str(row.id)}))
        audit(db, user, 'support.reply', 'ticket', row.id, data.status)
    await db.flush()
    return result(ticket_data(row))
