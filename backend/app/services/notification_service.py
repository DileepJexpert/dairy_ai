import uuid
from sqlalchemy import select, update, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification, NotificationType


async def create_notification(
    db: AsyncSession, user_id: uuid.UUID,
    type: str, title: str, body: str, data: dict | None = None,
) -> Notification:
    notif = Notification(user_id=user_id, type=type, title=title, body=body, data=data)
    db.add(notif)
    await db.flush()
    return notif


async def send_push(user_id: uuid.UUID, title: str, body: str, data: dict | None = None) -> None:
    """Stub for Firebase FCM push notification."""
    print(f"[FCM STUB] Push to {user_id}: {title} - {body}")


async def send_sms(phone: str, message: str) -> None:
    """Stub for SMS gateway."""
    print(f"[SMS STUB] SMS to {phone}: {message}")


async def notify_farmer(
    db: AsyncSession, farmer_user_id: uuid.UUID,
    type: str, title: str, body: str, data: dict | None = None,
) -> Notification:
    notif = await create_notification(db, farmer_user_id, type, title, body, data)
    await send_push(farmer_user_id, title, body, data)
    return notif


async def mark_read(db: AsyncSession, notification_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    result = await db.execute(
        update(Notification)
        .where(and_(Notification.id == notification_id, Notification.user_id == user_id))
        .values(is_read=True)
    )
    await db.flush()
    return result.rowcount > 0


async def mark_all_read(db: AsyncSession, user_id: uuid.UUID) -> int:
    result = await db.execute(
        update(Notification)
        .where(and_(Notification.user_id == user_id, Notification.is_read == False))
        .values(is_read=True)
    )
    await db.flush()
    return result.rowcount


async def get_notifications(
    db: AsyncSession, user_id: uuid.UUID, unread_only: bool = False, limit: int = 50,
) -> list[Notification]:
    query = select(Notification).where(Notification.user_id == user_id)
    if unread_only:
        query = query.where(Notification.is_read == False)
    query = query.order_by(Notification.created_at.desc()).limit(limit)
    result = await db.execute(query)
    return list(result.scalars().all())
