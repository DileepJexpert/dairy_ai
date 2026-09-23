from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP

from fastapi import HTTPException
from sqlalchemy import select, func

from app.models.commerce_admin import CommerceAudit, CommerceCoupon, OrderCoupon


def audit(db, actor, action, entity_type, entity_id, details):
    db.add(CommerceAudit(actor_id=actor.id, user_role=actor.role.value,
                         action=action, entity_type=entity_type,
                         entity_id=str(entity_id), details=details))


def coupon_discount(coupon, subtotal, eligible_subtotal=None):
    if not coupon.is_active or (coupon.valid_until and coupon.valid_until <= datetime.utcnow()):
        raise HTTPException(422, "Coupon is inactive or expired")
    if subtotal < coupon.min_order_value:
        raise HTTPException(422, f"Minimum order value is {coupon.min_order_value}")
    base_subtotal = eligible_subtotal if eligible_subtotal is not None else subtotal
    value = base_subtotal * coupon.discount_value / 100 if coupon.discount_type == "percentage" else coupon.discount_value
    if coupon.max_discount_cap is not None:
        value = min(value, coupon.max_discount_cap)
    return max(Decimal("0"), min(base_subtotal, value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


async def validate_coupon(db, code, subtotal, lock=False, vendor_subtotal=None, has_vendor_items=True):
    query = select(CommerceCoupon).where(CommerceCoupon.code == code.strip().upper())
    if lock:
        query = query.with_for_update()
    coupon = (await db.execute(query)).scalar_one_or_none()
    if coupon is None:
        raise HTTPException(422, "Coupon not found")
    if getattr(coupon, "vendor_id", None) is not None:
        if not has_vendor_items or (vendor_subtotal is not None and vendor_subtotal <= Decimal("0")):
            raise HTTPException(422, "Coupon is only valid for products from this seller")
        return coupon, coupon_discount(coupon, subtotal, eligible_subtotal=vendor_subtotal)
    return coupon, coupon_discount(coupon, subtotal)


async def serialize_coupon(db, coupon):
    uses = (await db.execute(select(func.count()).select_from(OrderCoupon).where(OrderCoupon.coupon_id == coupon.id))).scalar_one()
    return {"id": str(coupon.id), "vendor_id": str(coupon.vendor_id) if getattr(coupon, "vendor_id", None) else None,
            "code": coupon.code, "description": coupon.description,
            "discount_type": coupon.discount_type, "discount_value": str(coupon.discount_value),
            "min_order_value": str(coupon.min_order_value),
            "max_discount_cap": str(coupon.max_discount_cap) if coupon.max_discount_cap is not None else None,
            "valid_until": coupon.valid_until.isoformat() + "Z" if coupon.valid_until else None,
            "is_active": coupon.is_active, "usage_count": uses}
