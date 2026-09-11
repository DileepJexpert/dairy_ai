import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User, UserRole
from app.models.marketplace_models import (
    SellerAccount, SellerOffer, DealPromotion, PlatformCoupon, MarketplaceAuditLog,
    SellerStatus, OfferStatus, AuditActionType
)
from app.schemas.marketplace_schemas import (
    SellerAccountCreate, SellerAccountResponse,
    SellerOfferCreate, SellerOfferUpdate, SellerOfferResponse,
    DealPromotionCreate, DealPromotionResponse,
    PlatformCouponCreate, PlatformCouponResponse,
    AuditLogResponse
)
from app.services.marketplace_service import MarketplaceService

router = APIRouter(prefix="/marketplace", tags=["marketplace"])

@router.get("/products/{product_id}/offers", response_model=List[SellerOfferResponse])
async def get_product_offers(product_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    service = MarketplaceService(db)
    offers = await service.get_offers_for_product(product_id)
    return offers

@router.get("/deals/active", response_model=List[DealPromotionResponse])
async def get_active_deals(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(DealPromotion).where(DealPromotion.is_active == True))
    return list(result.scalars().all())

@router.get("/coupons/validate/{code}", response_model=PlatformCouponResponse)
async def validate_coupon(code: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(PlatformCoupon).where(PlatformCoupon.code == code.upper(), PlatformCoupon.is_active == True))
    coupon = result.scalars().first()
    if not coupon:
        raise HTTPException(status_code=404, detail="Coupon code invalid or expired.")
    return coupon

@router.post("/seller/onboard", response_model=SellerAccountResponse)
async def onboard_seller(
    payload: SellerAccountCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    seller = SellerAccount(
        user_id=current_user.id,
        business_name=payload.business_name,
        trade_name=payload.trade_name,
        gstin=payload.gstin,
        fssai_license=payload.fssai_license,
        contact_email=payload.contact_email,
        contact_phone=payload.contact_phone or current_user.phone,
        warehouse_city=payload.warehouse_city,
        warehouse_state=payload.warehouse_state,
        bank_account_number=payload.bank_account_number,
        ifsc_code=payload.ifsc_code,
        upi_id=payload.upi_id,
        status=SellerStatus.PENDING_APPROVAL,
    )
    db.add(seller)
    await db.commit()
    await db.refresh(seller)

    service = MarketplaceService(db)
    await service.log_audit(
        action_type=AuditActionType.SELLER_APPROVAL,
        entity_type="seller_account",
        entity_id=str(seller.id),
        details=f"Seller application submitted by {seller.business_name}",
        user_id=current_user.id,
        user_role=current_user.role.value,
        user_email=current_user.phone
    )
    return seller

@router.get("/admin/audit-logs", response_model=List[AuditLogResponse])
async def get_audit_logs(limit: int = 50, db: AsyncSession = Depends(get_db)):
    service = MarketplaceService(db)
    return await service.get_audit_logs(limit=limit)
