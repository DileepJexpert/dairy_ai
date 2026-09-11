import uuid
from datetime import datetime
from decimal import Decimal
from typing import List, Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, desc
from app.models.marketplace_models import (
    SellerAccount, SellerDocument, SellerOffer, DealPromotion, PlatformCoupon,
    MarketplaceAuditLog, SellerStatus, OfferStatus, AuditActionType
)
from app.models.product import Product

class MarketplaceService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def log_audit(
        self,
        action_type: AuditActionType,
        entity_type: str,
        entity_id: str,
        details: str,
        diff_payload: Optional[Dict[str, Any]] = None,
        user_id: Optional[uuid.UUID] = None,
        user_role: str = " SUPER_ADMIN\,
 user_email: str = \admin@milterra.com\,
 ) -> MarketplaceAuditLog:
 log = MarketplaceAuditLog(
 user_id=user_id,
 user_email_or_phone=user_email,
 user_role=user_role,
 action_type=action_type,
 entity_type=entity_type,
 entity_id=entity_id,
 details=details,
 diff_payload=diff_payload or {},
 )
 self.db.add(log)
 await self.db.commit()
 await self.db.refresh(log)
 return log

 async def get_offers_for_product(self, product_id: uuid.UUID) -> List[SellerOffer]:
 result = await self.db.execute(
 select(SellerOffer)
 .where(SellerOffer.product_id == product_id, SellerOffer.offer_status == OfferStatus.ACTIVE)
 .order_by(SellerOffer.selling_price.asc())
 )
 return list(result.scalars().all())

 async def get_seller_offers(self, seller_id: uuid.UUID) -> List[SellerOffer]:
 result = await self.db.execute(
 select(SellerOffer)
 .where(SellerOffer.seller_id == seller_id)
 .order_by(SellerOffer.created_at.desc())
 )
 return list(result.scalars().all())

 async def get_audit_logs(self, limit: int = 50) -> List[MarketplaceAuditLog]:
 result = await self.db.execute(
 select(MarketplaceAuditLog)
 .order_by(desc(MarketplaceAuditLog.created_at))
 .limit(limit)
 )
 return list(result.scalars().all())
