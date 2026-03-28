import logging
import uuid
from sqlalchemy import select, update, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification, NotificationType

logger = logging.getLogger("dairy_ai.services.notification")


async def create_notification(
    db: AsyncSession, user_id: uuid.UUID,
    type: str, title: str, body: str, data: dict | None = None,
) -> Notification:
    logger.info(f"create_notification called | user_id={user_id}, type={type}, title={title}")
    logger.debug(f"Notification body: {body}")
    if data:
        logger.debug(f"Notification data payload: {data}")

    logger.debug(f"Creating notification record in database | user_id={user_id}")
    notif = Notification(user_id=user_id, type=type, title=title, body=body, data=data)
    db.add(notif)
    await db.flush()

    logger.info(f"Notification created | notification_id={notif.id}, user_id={user_id}, type={type}")
    return notif


async def send_push(user_id: uuid.UUID, title: str, body: str, data: dict | None = None) -> None:
    """Stub for Firebase FCM push notification."""
    logger.info(f"send_push called | user_id={user_id}, title={title}")
    logger.debug(f"Push notification body: {body}")
    if data:
        logger.debug(f"Push data payload: {data}")
    # FCM integration stub
    logger.debug(f"[FCM STUB] Push to {user_id}: {title} - {body}")
    logger.info(f"Push notification sent (stub) | user_id={user_id}")


async def send_sms(phone: str, message: str) -> None:
    """Stub for SMS gateway."""
    masked_phone = f"****{phone[-4:]}" if len(phone) >= 4 else "****"
    logger.info(f"send_sms called | phone={masked_phone}, message_length={len(message)}")
    logger.debug(f"SMS message: {message[:100]}{'...' if len(message) > 100 else ''}")
    # SMS gateway stub
    logger.debug(f"[SMS STUB] SMS to {masked_phone}: {message}")
    logger.info(f"SMS sent (stub) | phone={masked_phone}")


async def notify_farmer(
    db: AsyncSession, farmer_user_id: uuid.UUID,
    type: str, title: str, body: str, data: dict | None = None,
) -> Notification:
    logger.info(f"notify_farmer called | farmer_user_id={farmer_user_id}, type={type}, title={title}")

    logger.debug(f"Creating notification for farmer | user_id={farmer_user_id}")
    notif = await create_notification(db, farmer_user_id, type, title, body, data)

    logger.debug(f"Sending push notification to farmer | user_id={farmer_user_id}")
    await send_push(farmer_user_id, title, body, data)

    logger.info(f"Farmer notified | user_id={farmer_user_id}, notification_id={notif.id}, type={type}")
    return notif


async def mark_read(db: AsyncSession, notification_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    logger.info(f"mark_read called | notification_id={notification_id}, user_id={user_id}")

    result = await db.execute(
        update(Notification)
        .where(and_(Notification.id == notification_id, Notification.user_id == user_id))
        .values(is_read=True)
    )
    await db.flush()

    success = result.rowcount > 0
    if success:
        logger.info(f"Notification marked as read | notification_id={notification_id}, user_id={user_id}")
    else:
        logger.warning(f"Notification not found or doesn't belong to user | notification_id={notification_id}, user_id={user_id}")
    return success


async def mark_all_read(db: AsyncSession, user_id: uuid.UUID) -> int:
    logger.info(f"mark_all_read called | user_id={user_id}")

    result = await db.execute(
        update(Notification)
        .where(and_(Notification.user_id == user_id, Notification.is_read == False))
        .values(is_read=True)
    )
    await db.flush()

    count = result.rowcount
    logger.info(f"Notifications marked as read | user_id={user_id}, count={count}")
    return count


async def get_notifications(
    db: AsyncSession, user_id: uuid.UUID, unread_only: bool = False, limit: int = 50,
) -> list[Notification]:
    logger.debug(f"get_notifications called | user_id={user_id}, unread_only={unread_only}, limit={limit}")

    query = select(Notification).where(Notification.user_id == user_id)
    if unread_only:
        query = query.where(Notification.is_read == False)
        logger.debug(f"Filtering for unread notifications only | user_id={user_id}")
    query = query.order_by(Notification.created_at.desc()).limit(limit)

    result = await db.execute(query)
    notifications = list(result.scalars().all())
    logger.debug(f"Notifications fetched | user_id={user_id}, count={len(notifications)}, unread_only={unread_only}")
    return notifications
