import logging
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.rfq import RFQInquiry, RFQStatus
from app.models.user import User, UserRole
from app.schemas.rfq import RFQCreate, RFQResponse

logger = logging.getLogger("dairy_ai.api.rfq")

router = APIRouter(prefix="/rfq", tags=["RFQ & Bulk Quotes"])


def _to_rfq_response(row: RFQInquiry) -> dict:
    # Generate human readable reference code like RFQ-78291
    ref_suffix = str(row.id).replace("-", "")[:6].upper()
    return {
        "id": str(row.id),
        "reference_no": f"RFQ-{ref_suffix}",
        "product_id": str(row.product_id) if row.product_id else None,
        "product_title": row.product_title,
        "quantity": row.quantity,
        "unit": row.unit,
        "buyer_name": row.buyer_name,
        "buyer_phone": row.buyer_phone,
        "buyer_email": row.buyer_email,
        "pincode": row.pincode,
        "city": row.city,
        "state": row.state,
        "requirement_details": row.requirement_details,
        "preferred_contact": row.preferred_contact,
        "status": row.status,
        "created_at": row.created_at.isoformat() + "Z" if row.created_at else None,
    }


@router.post("", status_code=201)
@router.post("/", status_code=201)
async def submit_rfq_inquiry(
    data: RFQCreate,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Submit a Request for Quotation (RFQ) / IndiaMART-style requirement."""
    logger.info(f"POST /rfq called | buyer={data.buyer_name} | phone={data.buyer_phone} | item={data.product_title}")
    
    prod_uuid = None
    if data.product_id:
        try:
            prod_uuid = uuid.UUID(data.product_id)
        except ValueError:
            pass

    row = RFQInquiry(
        product_id=prod_uuid,
        product_title=data.product_title,
        quantity=data.quantity,
        unit=data.unit,
        buyer_name=data.buyer_name,
        buyer_phone=data.buyer_phone,
        buyer_email=data.buyer_email,
        pincode=data.pincode,
        city=data.city,
        state=data.state,
        requirement_details=data.requirement_details,
        preferred_contact=data.preferred_contact,
        status=RFQStatus.pending.value,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    
    logger.info(f"RFQ inquiry created successfully | id={row.id}")
    return {
        "success": True,
        "data": _to_rfq_response(row),
        "message": "Your requirement has been submitted. Verified manufacturers and distributors will contact you shortly.",
    }


@router.get("/recent")
async def get_recent_rfqs(
    db: AsyncSession = Depends(get_db),
) -> dict:
    """List recent public RFQ requirements for live market activity feed."""
    stmt = select(RFQInquiry).order_by(RFQInquiry.created_at.desc()).limit(10)
    res = await db.execute(stmt)
    rows = res.scalars().all()
    
    # Redact phone numbers for privacy in public feed
    def _public_summary(r: RFQInquiry):
        masked_phone = r.buyer_phone[:3] + "XXXX" + r.buyer_phone[-3:] if len(r.buyer_phone) >= 7 else "XXXXX"
        ref_suffix = str(r.id).replace("-", "")[:6].upper()
        return {
            "reference_no": f"RFQ-{ref_suffix}",
            "product_title": r.product_title,
            "quantity": r.quantity,
            "unit": r.unit,
            "city": r.city or "India",
            "state": r.state or "",
            "buyer_name": r.buyer_name.split()[0] + " " + (r.buyer_name.split()[1][0] + "." if len(r.buyer_name.split()) > 1 else ""),
            "buyer_phone_masked": masked_phone,
            "status": "Matching Suppliers",
            "created_at": r.created_at.isoformat() + "Z" if r.created_at else None,
        }

    return {
        "success": True,
        "data": [_public_summary(r) for r in rows],
        "message": "Recent RFQ inquiries",
    }
