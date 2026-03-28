import logging
import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, update, delete, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import require_role
from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.cattle import Cattle
from app.models.vet import VetProfile, Consultation
from app.models.milk import MilkRecord
from app.models.finance import Transaction
from app.models.health import HealthRecord, Vaccination, SensorReading
from app.models.notification import Notification
from app.models.breeding import BreedingRecord
from app.models.feed import FeedPlan
from app.models.conversation import Conversation

logger = logging.getLogger("dairy_ai.api.super_admin")

router = APIRouter(prefix="/super-admin", tags=["super-admin"])


# ---------------------------------------------------------------------------
# System Overview — full platform stats
# ---------------------------------------------------------------------------

@router.get("/dashboard")
async def super_admin_dashboard(
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Complete platform overview with all key metrics."""
    logger.info(f"Super admin dashboard requested by user_id={current_user.id}")

    # User counts by role
    logger.debug("Fetching user counts by role...")
    role_counts = {}
    for role in UserRole:
        count = (await db.execute(
            select(func.count(User.id)).where(User.role == role)
        )).scalar() or 0
        role_counts[role.value] = count
    logger.info(f"User counts by role: {role_counts}")

    # Total counts
    total_farmers = (await db.execute(select(func.count(Farmer.id)))).scalar() or 0
    total_cattle = (await db.execute(select(func.count(Cattle.id)))).scalar() or 0
    total_vets = (await db.execute(select(func.count(VetProfile.id)))).scalar() or 0
    verified_vets = (await db.execute(
        select(func.count(VetProfile.id)).where(VetProfile.is_verified == True)
    )).scalar() or 0
    logger.info(f"Platform stats: farmers={total_farmers}, cattle={total_cattle}, vets={total_vets}, verified_vets={verified_vets}")

    # Consultation stats
    total_consultations = (await db.execute(select(func.count(Consultation.id)))).scalar() or 0
    active_consultations = (await db.execute(
        select(func.count(Consultation.id))
        .where(Consultation.status.in_(["requested", "assigned", "in_progress"]))
    )).scalar() or 0
    completed_consultations = (await db.execute(
        select(func.count(Consultation.id))
        .where(Consultation.status == "completed")
    )).scalar() or 0
    logger.info(f"Consultations: total={total_consultations}, active={active_consultations}, completed={completed_consultations}")

    # Financial summary (platform revenue from consultation fees)
    total_platform_fees = (await db.execute(
        select(func.sum(Consultation.platform_fee))
    )).scalar() or 0
    logger.info(f"Total platform fees collected: ₹{total_platform_fees}")

    # Milk production today
    today = date.today()
    milk_today = (await db.execute(
        select(func.sum(MilkRecord.quantity_litres))
        .where(MilkRecord.date == today)
    )).scalar() or 0
    logger.info(f"Milk production today: {milk_today} litres")

    # Health alerts (unresolved health records)
    active_health_issues = (await db.execute(
        select(func.count(HealthRecord.id))
        .where(HealthRecord.resolved == False)
    )).scalar() or 0

    # Sensor readings count (last 24h)
    yesterday = today - timedelta(days=1)
    sensor_count_24h = (await db.execute(
        select(func.count(SensorReading.id))
    )).scalar() or 0

    # Notification stats
    total_notifications = (await db.execute(select(func.count(Notification.id)))).scalar() or 0
    unread_notifications = (await db.execute(
        select(func.count(Notification.id)).where(Notification.is_read == False)
    )).scalar() or 0

    # New registrations last 7 days
    week_ago = today - timedelta(days=7)
    new_users_week = (await db.execute(
        select(func.count(User.id)).where(User.created_at >= str(week_ago))
    )).scalar() or 0
    logger.info(f"New users in last 7 days: {new_users_week}")

    logger.info("Super admin dashboard data compiled successfully")
    return {
        "success": True,
        "data": {
            "users": {
                "total": sum(role_counts.values()),
                "by_role": role_counts,
                "new_last_7_days": new_users_week,
            },
            "platform": {
                "total_farmers": total_farmers,
                "total_cattle": total_cattle,
                "total_vets": total_vets,
                "verified_vets": verified_vets,
                "unverified_vets": total_vets - verified_vets,
            },
            "consultations": {
                "total": total_consultations,
                "active": active_consultations,
                "completed": completed_consultations,
                "platform_revenue": round(float(total_platform_fees), 2),
            },
            "milk": {
                "today_litres": round(float(milk_today), 2),
            },
            "health": {
                "active_issues": active_health_issues,
                "sensor_readings_total": sensor_count_24h,
            },
            "notifications": {
                "total": total_notifications,
                "unread": unread_notifications,
            },
        },
        "message": "Super admin dashboard",
    }


# ---------------------------------------------------------------------------
# User Management
# ---------------------------------------------------------------------------

@router.get("/users")
async def list_all_users(
    role: str | None = Query(None),
    is_active: bool | None = Query(None),
    search: str | None = Query(None),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """List all users with filtering."""
    logger.info(f"List users | role={role}, is_active={is_active}, search={search}, limit={limit}, offset={offset}")

    query = select(User)
    count_query = select(func.count(User.id))

    if role:
        query = query.where(User.role == role)
        count_query = count_query.where(User.role == role)
    if is_active is not None:
        query = query.where(User.is_active == is_active)
        count_query = count_query.where(User.is_active == is_active)
    if search:
        query = query.where(User.phone.ilike(f"%{search}%"))
        count_query = count_query.where(User.phone.ilike(f"%{search}%"))

    query = query.order_by(User.created_at.desc()).offset(offset).limit(limit)
    result = await db.execute(query)
    users = list(result.scalars().all())
    total = (await db.execute(count_query)).scalar() or 0

    logger.info(f"Found {len(users)} users (total matching: {total})")

    return {
        "success": True,
        "data": [
            {
                "id": str(u.id),
                "phone": u.phone,
                "role": u.role.value,
                "is_active": u.is_active,
                "created_at": str(u.created_at),
            }
            for u in users
        ],
        "total": total,
        "message": "Users list",
    }


@router.put("/users/{user_id}/role")
async def change_user_role(
    user_id: str,
    new_role: str = Query(...),
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Change a user's role (promote/demote)."""
    logger.info(f"Change role for user_id={user_id} to new_role={new_role} | by super_admin={current_user.id}")

    try:
        target_role = UserRole(new_role)
    except ValueError:
        logger.warning(f"Invalid role: {new_role}")
        raise HTTPException(status_code=400, detail=f"Invalid role: {new_role}. Valid: {[r.value for r in UserRole]}")

    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user:
        logger.warning(f"User not found: {user_id}")
        raise HTTPException(status_code=404, detail="User not found")

    old_role = user.role.value
    user.role = target_role
    await db.flush()

    logger.info(f"User {user_id} role changed: {old_role} -> {new_role}")
    return {
        "success": True,
        "data": {"id": str(user.id), "phone": user.phone, "old_role": old_role, "new_role": new_role},
        "message": f"User role changed from {old_role} to {new_role}",
    }


@router.put("/users/{user_id}/toggle-active")
async def toggle_user_active(
    user_id: str,
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Activate or deactivate a user account."""
    logger.info(f"Toggle active status for user_id={user_id} | by super_admin={current_user.id}")

    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user:
        logger.warning(f"User not found: {user_id}")
        raise HTTPException(status_code=404, detail="User not found")

    user.is_active = not user.is_active
    await db.flush()

    status_text = "activated" if user.is_active else "deactivated"
    logger.info(f"User {user_id} {status_text}")
    return {
        "success": True,
        "data": {"id": str(user.id), "is_active": user.is_active},
        "message": f"User {status_text}",
    }


# ---------------------------------------------------------------------------
# Vet Verification Management
# ---------------------------------------------------------------------------

@router.get("/vets/pending-verification")
async def pending_vet_verifications(
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """List all unverified vets awaiting approval."""
    logger.info("Fetching unverified vets for super admin review")

    result = await db.execute(
        select(VetProfile).where(VetProfile.is_verified == False)
    )
    vets = list(result.scalars().all())
    logger.info(f"Found {len(vets)} vets pending verification")

    return {
        "success": True,
        "data": [
            {
                "id": str(v.id),
                "user_id": str(v.user_id),
                "license_number": v.license_number,
                "qualification": v.qualification.value if hasattr(v.qualification, 'value') else v.qualification,
                "specializations": v.specializations or [],
                "experience_years": v.experience_years,
                "bio": v.bio,
                "is_verified": v.is_verified,
            }
            for v in vets
        ],
        "message": f"{len(vets)} vets pending verification",
    }


@router.put("/vets/{vet_id}/verify")
async def verify_vet(
    vet_id: str,
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Verify a vet profile."""
    logger.info(f"Verifying vet_id={vet_id} | by super_admin={current_user.id}")

    result = await db.execute(select(VetProfile).where(VetProfile.id == uuid.UUID(vet_id)))
    vet = result.scalar_one_or_none()
    if not vet:
        logger.warning(f"Vet not found: {vet_id}")
        raise HTTPException(status_code=404, detail="Vet not found")

    vet.is_verified = True
    await db.flush()
    logger.info(f"Vet {vet_id} verified successfully")

    return {
        "success": True,
        "data": {"id": str(vet.id), "is_verified": True},
        "message": "Vet verified successfully",
    }


@router.put("/vets/{vet_id}/reject")
async def reject_vet(
    vet_id: str,
    reason: str = Query("Does not meet verification criteria"),
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Reject a vet verification (keeps profile but unverified)."""
    logger.info(f"Rejecting vet_id={vet_id} | reason={reason} | by super_admin={current_user.id}")

    result = await db.execute(select(VetProfile).where(VetProfile.id == uuid.UUID(vet_id)))
    vet = result.scalar_one_or_none()
    if not vet:
        raise HTTPException(status_code=404, detail="Vet not found")

    vet.is_verified = False
    await db.flush()
    logger.info(f"Vet {vet_id} rejected: {reason}")

    return {
        "success": True,
        "data": {"id": str(vet.id), "is_verified": False, "rejection_reason": reason},
        "message": f"Vet rejected: {reason}",
    }


# ---------------------------------------------------------------------------
# Platform Analytics
# ---------------------------------------------------------------------------

@router.get("/analytics/overview")
async def platform_analytics(
    days: int = Query(30, le=365),
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Comprehensive platform analytics."""
    logger.info(f"Platform analytics requested | days={days}")
    cutoff = date.today() - timedelta(days=days)

    # Daily user registrations
    logger.debug("Fetching daily registration trends...")
    reg_result = await db.execute(
        select(func.date(User.created_at).label("day"), func.count(User.id).label("count"))
        .where(User.created_at >= str(cutoff))
        .group_by(func.date(User.created_at))
        .order_by(func.date(User.created_at))
    )
    registrations = [{"date": str(row.day), "count": row.count} for row in reg_result.all()]

    # Consultations per day
    logger.debug("Fetching consultation trends...")
    consult_result = await db.execute(
        select(func.date(Consultation.created_at).label("day"), func.count(Consultation.id).label("count"))
        .where(Consultation.created_at >= str(cutoff))
        .group_by(func.date(Consultation.created_at))
        .order_by(func.date(Consultation.created_at))
    )
    consultations_trend = [{"date": str(row.day), "count": row.count} for row in consult_result.all()]

    # Revenue per day (platform fees)
    logger.debug("Fetching revenue trends...")
    revenue_result = await db.execute(
        select(func.date(Consultation.ended_at).label("day"), func.sum(Consultation.platform_fee).label("revenue"))
        .where(and_(Consultation.ended_at != None, Consultation.ended_at >= str(cutoff)))
        .group_by(func.date(Consultation.ended_at))
        .order_by(func.date(Consultation.ended_at))
    )
    revenue_trend = [{"date": str(row.day), "revenue": round(float(row.revenue or 0), 2)} for row in revenue_result.all()]

    # Total milk production per day
    logger.debug("Fetching milk production trends...")
    milk_result = await db.execute(
        select(MilkRecord.date, func.sum(MilkRecord.quantity_litres).label("total"))
        .where(MilkRecord.date >= cutoff)
        .group_by(MilkRecord.date)
        .order_by(MilkRecord.date)
    )
    milk_trend = [{"date": str(row.date), "litres": round(float(row.total or 0), 2)} for row in milk_result.all()]

    logger.info(f"Analytics compiled: {len(registrations)} registration days, {len(consultations_trend)} consultation days")

    return {
        "success": True,
        "data": {
            "period_days": days,
            "registrations": registrations,
            "consultations": consultations_trend,
            "revenue": revenue_trend,
            "milk_production": milk_trend,
        },
        "message": "Platform analytics",
    }


# ---------------------------------------------------------------------------
# System Health & Config
# ---------------------------------------------------------------------------

@router.get("/system/health")
async def system_health(
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Check system health — database connectivity, table counts."""
    logger.info("System health check by super admin")

    table_counts = {}
    tables = {
        "users": User, "farmers": Farmer, "cattle": Cattle,
        "vets": VetProfile, "consultations": Consultation,
        "health_records": HealthRecord, "vaccinations": Vaccination,
        "milk_records": MilkRecord, "transactions": Transaction,
        "breeding_records": BreedingRecord, "feed_plans": FeedPlan,
        "notifications": Notification, "conversations": Conversation,
    }

    for name, model in tables.items():
        count = (await db.execute(select(func.count(model.id)))).scalar() or 0
        table_counts[name] = count
        logger.debug(f"Table '{name}': {count} rows")

    logger.info(f"System health: all tables accessible, total rows across tables = {sum(table_counts.values())}")

    return {
        "success": True,
        "data": {
            "database": "connected",
            "table_counts": table_counts,
            "total_records": sum(table_counts.values()),
        },
        "message": "System healthy",
    }


@router.post("/users/create-admin")
async def create_admin_user(
    phone: str = Query(...),
    role: str = Query("admin"),
    current_user: User = Depends(require_role(UserRole.super_admin)),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Create a new admin or super_admin user directly (no OTP needed)."""
    logger.info(f"Creating admin user | phone=****{phone[-4:]}, role={role} | by super_admin={current_user.id}")

    try:
        target_role = UserRole(role)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid role: {role}")

    if target_role not in (UserRole.admin, UserRole.super_admin):
        raise HTTPException(status_code=400, detail="Can only create admin or super_admin users via this endpoint")

    # Check if phone already exists
    existing = (await db.execute(select(User).where(User.phone == phone))).scalar_one_or_none()
    if existing:
        logger.warning(f"Phone already registered: ****{phone[-4:]}")
        raise HTTPException(status_code=409, detail="Phone number already registered")

    new_user = User(phone=phone, role=target_role, is_active=True)
    db.add(new_user)
    await db.flush()

    logger.info(f"Admin user created: id={new_user.id}, role={role}")
    return {
        "success": True,
        "data": {"id": str(new_user.id), "phone": phone, "role": role},
        "message": f"{role} user created successfully",
    }
