import uuid
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
async def list_notifications(
    unread_only: bool = Query(False),
    limit: int = Query(50, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    notifs = await notification_service.get_notifications(db, current_user.id, unread_only=unread_only, limit=limit)
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
    await notification_service.mark_read(db, uuid.UUID(notification_id), current_user.id)
    return {"success": True, "data": {}, "message": "Marked as read"}


@router.put("/read-all")
async def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    count = await notification_service.mark_all_read(db, current_user.id)
    return {"success": True, "data": {"count": count}, "message": f"Marked {count} as read"}
