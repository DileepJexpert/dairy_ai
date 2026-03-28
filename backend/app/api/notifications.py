import uuid
import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.dependencies import require_role
from app.models.user import UserRole
from app.services import notification_service
from app.services import alert_engine

logger = logging.getLogger("dairy_ai.api.notifications")

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
async def list_notifications(
    unread_only: bool = Query(False),
    limit: int = Query(50, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"GET /notifications called | user_id={current_user.id} | unread_only={unread_only} | limit={limit}")
    logger.debug(f"Calling notification_service.get_notifications | user_id={current_user.id}")
    notifs = await notification_service.get_notifications(db, current_user.id, unread_only=unread_only, limit=limit)
    logger.info(f"Notifications retrieved | user_id={current_user.id} | count={len(notifs)}")
    return {
        "success": True,
        "data": [
            {
                "id": str(n.id),
                "type": n.type.value if hasattr(n.type, 'value') else n.type,
                "title": n.title,
                "body": n.body,
                "data": n.data,
                "is_read": n.is_read,
                "created_at": str(n.created_at),
            }
            for n in notifs
        ],
        "message": "Notifications",
    }


@router.put("/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /notifications/{notification_id}/read called | user_id={current_user.id}")
    logger.debug(f"Calling notification_service.mark_read | notification_id={notification_id} | user_id={current_user.id}")
    try:
        await notification_service.mark_read(db, uuid.UUID(notification_id), current_user.id)
        logger.info(f"Notification marked as read | notification_id={notification_id} | user_id={current_user.id}")
        return {"success": True, "data": {}, "message": "Marked as read"}
    except Exception as e:
        logger.error(f"Failed to mark notification as read | notification_id={notification_id}: {e}")
        raise


@router.put("/read-all")
async def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    logger.info(f"PUT /notifications/read-all called | user_id={current_user.id}")
    logger.debug(f"Calling notification_service.mark_all_read | user_id={current_user.id}")
    try:
        count = await notification_service.mark_all_read(db, current_user.id)
        logger.info(f"All notifications marked as read | user_id={current_user.id} | count={count}")
        return {"success": True, "data": {"count": count}, "message": f"Marked {count} as read"}
    except Exception as e:
        logger.error(f"Failed to mark all notifications as read | user_id={current_user.id}: {e}")
        raise


@router.get("/unread-count")
async def unread_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Quick endpoint for badge count on mobile app."""
    logger.debug(f"GET /notifications/unread-count | user_id={current_user.id}")
    notifs = await notification_service.get_notifications(
        db, current_user.id, unread_only=True, limit=100
    )
    return {"success": True, "data": {"count": len(notifs)}, "message": "Unread count"}


@router.post("/device-token")
async def register_device_token(
    data: dict,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Register FCM device token for push notifications."""
    token = data.get("token", "")
    if not token:
        return {"success": False, "data": {}, "message": "Token required"}
    logger.info(f"POST /notifications/device-token | user_id={current_user.id}")
    await alert_engine.register_device_token(current_user.id, token)
    return {"success": True, "data": {}, "message": "Device token registered"}


@router.post("/trigger-vaccination-reminders")
async def trigger_vaccination_reminders(
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Admin trigger: send vaccination due reminders to all farmers."""
    logger.info(f"POST /notifications/trigger-vaccination-reminders | user_id={current_user.id}")
    count = await alert_engine.send_vaccination_reminders(db)
    return {
        "success": True,
        "data": {"reminders_sent": count},
        "message": f"Sent {count} vaccination reminders",
    }
