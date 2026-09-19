"""Commerce admin APIs using the same products and inventory as the storefront."""
import csv
import io
import uuid
from datetime import datetime
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select, or_, func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import User, UserRole
from app.models.vendor import Vendor, VendorPayout, PayoutStatus
from app.models.order import Order, OrderItem, PaymentStatus
from app.models.product import Product, ProductFamily, ProductInventory, ProductMedia
from app.models.commerce_admin import CommerceCoupon, CommerceCertificate, CommerceAudit
from app.repositories import cart_repo
from app.schemas.commerce_admin import (
    OfferUpdate, OfferCreate, SellerUpdate, CouponInput, ActiveUpdate, CouponQuote, CertificateInput,
    ProductModerationRequest,
)
from app.schemas.vendor import VendorPayoutCreate, VendorCommissionUpdate
from app.services.commerce_admin_service import audit, serialize_coupon, validate_coupon
from app.services.product_policy import purchase_enabled
from app.services.product_service import slugify

router = APIRouter(tags=["commerce administration"])
admin_only = require_role(UserRole.admin, UserRole.super_admin)
seller_or_admin = require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)


async def unique_flush(db):
    try:
        await db.flush()
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(409, "A record with this code or batch number already exists") from error


def certificate_json(row, product):
    return {"id": str(row.id), "product_id": str(row.product_id), "product_title": product.title,
            "category": product.category.value, "batch_number": row.batch_number,
            "test_date": row.test_date.isoformat() + "Z", "laboratory": row.laboratory,
            "fssai_license": row.fssai_license,
            "purity_percent": str(row.purity_percent) if row.purity_percent is not None else None,
            "test_parameters": row.test_parameters, "status": row.status,
            "certified_by": row.certified_by, "remarks": row.remarks, "report_url": row.report_url}


async def snapshot(db, vendor_id=None):
    vendors_query = select(Vendor, User).join(User, Vendor.user_id == User.id)
    offers_query = select(Product, ProductInventory, Vendor).join(Vendor, Product.vendor_id == Vendor.id).outerjoin(ProductInventory, ProductInventory.product_id == Product.id)
    cert_query = select(CommerceCertificate, Product).join(Product, Product.id == CommerceCertificate.product_id)
    if vendor_id is not None:
        vendors_query = vendors_query.where(Vendor.id == vendor_id)
        offers_query = offers_query.where(Product.vendor_id == vendor_id)
        cert_query = cert_query.where(Product.vendor_id == vendor_id)
    sellers = [{"id": str(v.id), "business_name": v.business_name, "gstin": v.gst_number,
                "fssai_license": v.license_number, "contact_phone": u.phone,
                "contact_email": u.email, "warehouse_city": v.district, "warehouse_state": v.state,
                "bank_name": v.bank_name, "account_number": v.account_number,
                "ifsc_code": v.ifsc_code, "account_holder_name": v.account_holder_name, "upi_id": v.upi_id,
                "commission_rate": round(float(getattr(v, "commission_rate", 5.0) or 5.0), 2),
                "status": "suspended" if not v.is_active else "approved" if v.is_verified else "pendingApproval",
                "rating_score": v.rating_avg, "created_at": v.created_at.isoformat() + "Z"}
               for v, u in (await db.execute(vendors_query.order_by(Vendor.business_name))).all()]
    offers = []
    for p, stock, v in (await db.execute(offers_query.order_by(Product.title, Product.sku))).all():
        available = stock.available_quantity if stock else 0
        mrp = p.compare_at_price if p.compare_at_price is not None else p.base_price
        offers.append({"id": str(p.id), "product_id": str(p.id), "seller_id": str(v.id),
                       "seller_name": v.business_name, "seller_sku": p.sku, "selling_price": str(p.base_price),
                       "mrp": str(mrp), "discount_percent": float((mrp-p.base_price)/mrp*100) if mrp else 0,
                       "available_stock": available, "reserved_stock": stock.reserved_quantity if stock else 0,
                       "low_stock_threshold": stock.reorder_level if stock else 0,
                       "offer_status": "paused" if not p.is_active or not v.is_active or p.publication_status != "published" else "outOfStock" if available <= (stock.reserved_quantity if stock else 0) else "active",
                       "seller_rating": v.rating_avg})
    coupons = []
    logs = []
    if vendor_id is None:
        coupons = [await serialize_coupon(db, c) for c in (await db.execute(select(CommerceCoupon).order_by(CommerceCoupon.code))).scalars()]
        logs = [{"id": str(a.id), "user_role": a.user_role, "user_identifier": str(a.actor_id),
                 "action": a.action, "entity_type": a.entity_type, "entity_id": a.entity_id,
                 "details": a.details, "timestamp": a.timestamp.isoformat() + "Z"}
                for a in (await db.execute(select(CommerceAudit).order_by(CommerceAudit.timestamp.desc()).limit(500))).scalars()]
    else:
        coupons = [await serialize_coupon(db, c) for c in (await db.execute(select(CommerceCoupon).where(CommerceCoupon.vendor_id == vendor_id).order_by(CommerceCoupon.code))).scalars()]
    return {"success": True, "data": {"sellers": sellers, "offers": offers, "coupons": coupons,
            "batch_certificates": [certificate_json(c, p) for c, p in (await db.execute(cert_query.order_by(CommerceCertificate.test_date.desc()))).all()],
            "audit_logs": logs}}


@router.get("/admin/commerce")
async def admin_snapshot(user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    return await snapshot(db)


@router.get("/vendor/commerce")
async def vendor_snapshot(user: User = Depends(seller_or_admin), db: AsyncSession = Depends(get_db)):
    vendor = (await db.execute(select(Vendor).where(Vendor.user_id == user.id))).scalar_one_or_none()
    if not vendor:
        raise HTTPException(404, "Vendor profile not found")
    return await snapshot(db, vendor.id)


@router.patch("/admin/commerce/sellers/{vendor_id}")
async def update_seller(vendor_id: uuid.UUID, data: SellerUpdate, user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    vendor = await db.get(Vendor, vendor_id)
    if not vendor:
        raise HTTPException(404, "Seller not found")
    vendor.is_active = data.status == "approved"
    if vendor.is_active:
        vendor.is_verified = True
    audit(db, user, "sellerApproval" if vendor.is_active else "sellerSuspension", "SellerAccount", vendor.id, f"Status: {data.status}. {data.reason}")
    await db.flush()
    return {"success": True}


@router.patch("/admin/commerce/products/{product_id}/moderation")
async def moderate_product(
    product_id: uuid.UUID,
    data: ProductModerationRequest,
    user: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    product = (await db.execute(select(Product).where(Product.id == product_id).with_for_update())).scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Product not found")
    product.publication_status = data.status
    specs = dict(product.specifications or {})
    if data.status == "rejected":
        specs["rejection_reason"] = data.reason
    elif data.status == "published":
        specs.pop("rejection_reason", None)
    product.specifications = specs
    audit(db, user, "productModeration", "Product", product.id, f"Set publication status to {data.status}. Reason: {data.reason}")
    await db.flush()
    return {"success": True, "data": {"id": str(product.id), "publication_status": product.publication_status}}


@router.patch("/admin/commerce/offers/{product_id}")
async def admin_update_offer(product_id: uuid.UUID, data: OfferUpdate, user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    return await save_offer(db, user, product_id, data)


@router.patch("/vendor/commerce/offers/{product_id}")
async def vendor_update_offer(product_id: uuid.UUID, data: OfferUpdate, user: User = Depends(seller_or_admin), db: AsyncSession = Depends(get_db)):
    return await save_offer(db, user, product_id, data, own_only=True)


@router.post("/vendor/commerce/offers", status_code=201)
async def create_seller_offer(data: OfferCreate, user: User = Depends(seller_or_admin), db: AsyncSession = Depends(get_db)):
    vendor = (await db.execute(select(Vendor).where(Vendor.user_id == user.id))).scalar_one_or_none()
    if not vendor or not vendor.is_active or not vendor.is_verified:
        raise HTTPException(403, "An approved active seller profile is required")
    source = await db.get(Product, data.source_product_id)
    if not await purchase_enabled(db, source):
        raise HTTPException(422, "Select a published, non-concept product")
    # A separate seller listing keeps cart/order/vendor references isolated.
    spec = {k: v for k, v in (source.specifications or {}).items() if k != "family_id"}
    spec["canonical_product_id"] = str(source.id)
    product = Product(vendor_id=vendor.id, sku=data.seller_sku, title=source.title,
        slug=slugify(data.seller_sku), category=source.category, brand=source.brand,
        description=source.description, unit=source.unit, pack_size=source.pack_size,
        base_price=data.selling_price, compare_at_price=data.mrp, specifications=spec)
    db.add(product)
    await unique_flush(db)
    db.add(ProductInventory(product_id=product.id, available_quantity=data.available_stock, reserved_quantity=0))
    for media in (await db.execute(select(ProductMedia).where(ProductMedia.product_id == source.id))).scalars():
        db.add(ProductMedia(product_id=product.id, media_type=media.media_type, url=media.url,
                            sort_order=media.sort_order, is_primary=media.is_primary))
    audit(db, user, "catalogCreate", "SellerOffer", product.id, f"Created seller SKU {product.sku}")
    await db.flush()
    return {"success": True, "data": {"id": str(product.id)}}


async def save_offer(db, user, product_id, data, own_only=False):
    product = (await db.execute(select(Product).where(Product.id == product_id).with_for_update())).scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Offer not found")
    vendor = await db.get(Vendor, product.vendor_id)
    if own_only and (vendor.user_id != user.id or not vendor.is_active):
        raise HTTPException(403, "Cannot edit this seller's offer")
    price = data.selling_price if data.selling_price is not None else product.base_price
    mrp = data.mrp if data.mrp is not None else product.compare_at_price
    if mrp is not None and mrp < price:
        raise HTTPException(422, "MRP must be at least the selling price")
    stock = (await db.execute(select(ProductInventory).where(ProductInventory.product_id == product_id).with_for_update())).scalar_one_or_none()
    if data.available_stock is not None:
        if stock and data.available_stock < stock.reserved_quantity:
            raise HTTPException(422, "Stock cannot be less than reserved units")
        if not stock:
            stock = ProductInventory(product_id=product_id, reserved_quantity=0)
            db.add(stock)
        stock.available_quantity = data.available_stock
    product.base_price, product.compare_at_price = price, mrp
    audit(db, user, "stockAdjust" if data.available_stock is not None else "priceChange", "SellerOffer", product.id, data.model_dump_json(exclude_unset=True))
    await db.flush()
    return {"success": True}


@router.post("/admin/commerce/coupons", status_code=201)
async def create_coupon(data: CouponInput, user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    row = CommerceCoupon(**data.model_dump())
    db.add(row)
    await unique_flush(db)
    audit(db, user, "statusChange", "PlatformCoupon", row.id, f"Created coupon {row.code}")
    await db.flush()
    return {"success": True, "data": await serialize_coupon(db, row)}


@router.put("/admin/commerce/coupons/{coupon_id}")
async def edit_coupon(coupon_id: uuid.UUID, data: CouponInput, user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    row = (await db.execute(select(CommerceCoupon).where(CommerceCoupon.id == coupon_id).with_for_update())).scalar_one_or_none()
    if not row:
        raise HTTPException(404, "Coupon not found")
    for key, value in data.model_dump().items():
        setattr(row, key, value)
    await unique_flush(db)
    audit(db, user, "statusChange", "PlatformCoupon", row.id, f"Updated coupon {row.code}")
    await db.flush()
    return {"success": True, "data": await serialize_coupon(db, row)}


@router.patch("/admin/commerce/coupons/{coupon_id}")
async def toggle_coupon(coupon_id: uuid.UUID, data: ActiveUpdate, user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    row = (await db.execute(select(CommerceCoupon).where(CommerceCoupon.id == coupon_id).with_for_update())).scalar_one_or_none()
    if not row:
        raise HTTPException(404, "Coupon not found")
    row.is_active = data.is_active
    audit(db, user, "statusChange", "PlatformCoupon", row.id, f"Active: {row.is_active}")
    await db.flush()
    return {"success": True}


@router.get("/vendor/commerce/coupons")
async def get_vendor_coupons(user: User = Depends(seller_or_admin), db: AsyncSession = Depends(get_db)):
    vendor = (await db.execute(select(Vendor).where(Vendor.user_id == user.id))).scalar_one_or_none()
    if not vendor:
        raise HTTPException(404, "Vendor profile not found")
    rows = (await db.execute(select(CommerceCoupon).where(CommerceCoupon.vendor_id == vendor.id).order_by(CommerceCoupon.code))).scalars().all()
    return {"success": True, "data": [await serialize_coupon(db, row) for row in rows]}


@router.post("/vendor/commerce/coupons", status_code=201)
async def create_vendor_coupon(data: CouponInput, user: User = Depends(seller_or_admin), db: AsyncSession = Depends(get_db)):
    vendor = (await db.execute(select(Vendor).where(Vendor.user_id == user.id))).scalar_one_or_none()
    if not vendor or not vendor.is_active:
        raise HTTPException(403, "An active vendor account is required")
    coupon_data = data.model_dump()
    coupon_data["vendor_id"] = vendor.id
    row = CommerceCoupon(**coupon_data)
    db.add(row)
    await unique_flush(db)
    audit(db, user, "couponCreate", "VendorCoupon", row.id, f"Created seller coupon {row.code}")
    await db.flush()
    return {"success": True, "data": await serialize_coupon(db, row), "message": f"Coupon {row.code} created successfully"}


@router.patch("/vendor/commerce/coupons/{coupon_id}")
async def toggle_vendor_coupon(coupon_id: uuid.UUID, data: ActiveUpdate, user: User = Depends(seller_or_admin), db: AsyncSession = Depends(get_db)):
    vendor = (await db.execute(select(Vendor).where(Vendor.user_id == user.id))).scalar_one_or_none()
    if not vendor:
        raise HTTPException(404, "Vendor profile not found")
    row = (await db.execute(select(CommerceCoupon).where(CommerceCoupon.id == coupon_id, CommerceCoupon.vendor_id == vendor.id).with_for_update())).scalar_one_or_none()
    if not row:
        raise HTTPException(404, "Coupon not found or not owned by your store")
    row.is_active = data.is_active
    audit(db, user, "statusChange", "VendorCoupon", row.id, f"Active: {row.is_active}")
    await db.flush()
    return {"success": True, "message": f"Coupon is now {'active' if row.is_active else 'inactive'}"}


@router.delete("/vendor/commerce/coupons/{coupon_id}")
async def delete_vendor_coupon(coupon_id: uuid.UUID, user: User = Depends(seller_or_admin), db: AsyncSession = Depends(get_db)):
    vendor = (await db.execute(select(Vendor).where(Vendor.user_id == user.id))).scalar_one_or_none()
    if not vendor:
        raise HTTPException(404, "Vendor profile not found")
    row = (await db.execute(select(CommerceCoupon).where(CommerceCoupon.id == coupon_id, CommerceCoupon.vendor_id == vendor.id).with_for_update())).scalar_one_or_none()
    if not row:
        raise HTTPException(404, "Coupon not found or not owned by your store")
    await db.delete(row)
    audit(db, user, "delete", "VendorCoupon", coupon_id, f"Deleted seller coupon {row.code}")
    await db.flush()
    return {"success": True, "message": "Coupon deleted successfully"}


@router.get("/marketplace/coupons")
async def public_coupons(vendor_id: uuid.UUID | None = None, db: AsyncSession = Depends(get_db)):
    query = select(CommerceCoupon).where(CommerceCoupon.is_active.is_(True), or_(CommerceCoupon.valid_until.is_(None), CommerceCoupon.valid_until > datetime.utcnow()))
    if vendor_id:
        query = query.where(or_(CommerceCoupon.vendor_id == vendor_id, CommerceCoupon.vendor_id.is_(None)))
    else:
        query = query.where(CommerceCoupon.vendor_id.is_(None))
    rows = (await db.execute(query.order_by(CommerceCoupon.code))).scalars()
    return {"success": True, "data": [await serialize_coupon(db, row) for row in rows]}


@router.post("/marketplace/coupons/quote")
async def quote_coupon(data: CouponQuote, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    cart = await cart_repo.get_or_create_active_cart(db, user.id)
    items = await cart_repo.items(db, cart.id)
    if not items:
        raise HTTPException(422, "Cart is empty")
    subtotal = Decimal("0")
    for item in items:
        product = await db.get(Product, item.product_id)
        if not await purchase_enabled(db, product):
            raise HTTPException(422, "Review your cart before applying a coupon")
        subtotal += product.base_price * item.quantity
    coupon, discount = await validate_coupon(db, data.code, subtotal)
    return {"success": True, "data": {"coupon": await serialize_coupon(db, coupon), "subtotal": str(subtotal), "discount": str(discount), "total": str(subtotal-discount)}}


@router.post("/admin/commerce/certificates", status_code=201)
async def create_certificate(data: CertificateInput, user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    product = await db.get(Product, data.product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    row = CommerceCertificate(**data.model_dump())
    db.add(row)
    await unique_flush(db)
    audit(db, user, "statusChange", "BatchCertificate", row.id, f"Created {row.batch_number}: {row.status}")
    await db.flush()
    return {"success": True, "data": certificate_json(row, product)}


@router.put("/admin/commerce/certificates/{certificate_id}")
async def edit_certificate(certificate_id: uuid.UUID, data: CertificateInput, user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    row = await db.get(CommerceCertificate, certificate_id)
    product = await db.get(Product, data.product_id)
    if not row or not product:
        raise HTTPException(404, "Certificate or product not found")
    for key, value in data.model_dump().items():
        setattr(row, key, value)
    await unique_flush(db)
    audit(db, user, "statusChange", "BatchCertificate", row.id, f"Updated {row.batch_number}: {row.status}")
    await db.flush()
    return {"success": True, "data": certificate_json(row, product)}


@router.get("/marketplace/certificates")
async def public_certificates(product_id: uuid.UUID | None = None, db: AsyncSession = Depends(get_db)):
    query = select(CommerceCertificate, Product).join(Product, Product.id == CommerceCertificate.product_id).join(Vendor, Vendor.id == Product.vendor_id).outerjoin(ProductFamily, ProductFamily.id == Product.family_id).where(
        CommerceCertificate.status == "CERTIFIED", CommerceCertificate.report_url.is_not(None),
        Product.is_active.is_(True), Product.publication_status == "published", Vendor.is_active.is_(True),
        or_(Product.family_id.is_(None), ProductFamily.is_published.is_(True)))
    if product_id:
        query = query.where(Product.id == product_id)
    return {"success": True, "data": [certificate_json(c, p) for c, p in (await db.execute(query.order_by(CommerceCertificate.test_date.desc()))).all()]}


@router.get("/admin/commerce/vendors/settlements")
async def get_vendor_settlements(user: User = Depends(admin_only), db: AsyncSession = Depends(get_db)):
    vendors = (await db.execute(select(Vendor).order_by(Vendor.business_name))).scalars().all()
    settlements = []

    for v in vendors:
        order_items_q = (
            select(OrderItem)
            .join(Order, OrderItem.order_id == Order.id)
            .where(OrderItem.vendor_id == v.id, Order.payment_status == PaymentStatus.paid)
        )
        items = (await db.execute(order_items_q)).scalars().all()
        gross_sales = round(sum(float(it.line_total) for it in items), 2)

        comm_rate = round(float(getattr(v, "commission_rate", 5.0) or 5.0), 2)
        comm_amt = round(gross_sales * (comm_rate / 100.0), 2)
        net_payable = max(0.0, round(gross_sales - comm_amt, 2))

        payouts_q = select(VendorPayout).where(VendorPayout.vendor_id == v.id)
        payouts = (await db.execute(payouts_q)).scalars().all()
        total_settled = round(sum(float(p.amount) for p in payouts if p.status == PayoutStatus.paid), 2)
        pending_balance = max(0.0, round(net_payable - total_settled, 2))

        settlements.append({
            "vendor_id": str(v.id),
            "business_name": v.business_name,
            "is_active": v.is_active,
            "commission_rate": comm_rate,
            "bank_name": v.bank_name,
            "account_number": v.account_number,
            "ifsc_code": v.ifsc_code,
            "account_holder_name": v.account_holder_name,
            "upi_id": v.upi_id,
            "gross_sales": gross_sales,
            "commission_amount": comm_amt,
            "net_payable": net_payable,
            "total_settled": total_settled,
            "pending_balance": pending_balance,
            "payouts_count": len(payouts),
            "recent_payouts": [
                {
                    "id": str(p.id),
                    "amount": float(p.amount),
                    "status": p.status.value if hasattr(p.status, "value") else str(p.status),
                    "payment_reference": p.payment_reference,
                    "bank_name": p.bank_name,
                    "remarks": p.remarks,
                    "processed_at": p.processed_at.isoformat() if p.processed_at else None,
                    "created_at": p.created_at.isoformat() if p.created_at else "",
                }
                for p in sorted(payouts, key=lambda x: x.created_at, reverse=True)[:5]
            ],
        })

    return {"success": True, "data": settlements}


@router.post("/admin/commerce/vendors/{vendor_id}/payouts", status_code=201)
async def create_vendor_payout(
    vendor_id: uuid.UUID,
    data: VendorPayoutCreate,
    user: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    vendor = await db.get(Vendor, vendor_id)
    if not vendor:
        raise HTTPException(404, "Vendor not found")

    payout = VendorPayout(
        vendor_id=vendor.id,
        amount=data.amount,
        gross_amount=data.gross_amount or data.amount,
        commission_amount=data.commission_amount or 0.0,
        status=PayoutStatus.paid,
        payment_reference=data.payment_reference,
        bank_name=data.bank_name or vendor.bank_name,
        account_number=data.account_number or vendor.account_number,
        remarks=data.remarks,
        processed_at=datetime.utcnow(),
    )
    db.add(payout)
    await db.flush()
    audit(db, user, "vendorPayoutDisbursed", "VendorPayout", payout.id, f"Disbursed ₹{payout.amount} to {vendor.business_name}. Ref: {payout.payment_reference}")
    await db.flush()

    return {
        "success": True,
        "data": {
            "id": str(payout.id),
            "vendor_id": str(payout.vendor_id),
            "amount": float(payout.amount),
            "status": payout.status.value if hasattr(payout.status, "value") else str(payout.status),
            "payment_reference": payout.payment_reference,
            "processed_at": payout.processed_at.isoformat() if payout.processed_at else None,
        },
        "message": f"Payout of ₹{payout.amount} recorded successfully",
    }


@router.patch("/admin/commerce/vendors/{vendor_id}/commission")
async def update_vendor_commission(
    vendor_id: uuid.UUID,
    data: VendorCommissionUpdate,
    user: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    vendor = await db.get(Vendor, vendor_id)
    if not vendor:
        raise HTTPException(404, "Vendor not found")

    old_rate = vendor.commission_rate
    vendor.commission_rate = data.commission_rate
    audit(db, user, "vendorCommissionUpdate", "Vendor", vendor.id, f"Updated commission from {old_rate}% to {data.commission_rate}%")
    await db.flush()

    return {
        "success": True,
        "data": {
            "vendor_id": str(vendor.id),
            "commission_rate": float(vendor.commission_rate),
        },
        "message": f"Commission rate updated to {data.commission_rate}%",
    }


@router.get("/admin/commerce/reports/gstr1")
async def gstr1_tax_report(
    format: str = "json",
    user: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    orders_q = select(Order).where(Order.payment_status != PaymentStatus.failed).order_by(Order.created_at.desc())
    orders = (await db.execute(orders_q)).scalars().all()

    rows = []
    for o in orders:
        inv_no = f"INV-{o.created_at.strftime('%Y%m')}-{str(o.id)[:6].upper()}"
        tot = float(o.total_amount)
        taxable = round(tot / 1.05, 2)
        tax = round(tot - taxable, 2)
        shipping_st = (getattr(o, "shipping_state", None) or "").strip().lower()
        is_interstate = shipping_st not in ("delhi", "haryana", "uttar pradesh", "")
        cgst = 0.0 if is_interstate else round(tax / 2, 2)
        sgst = 0.0 if is_interstate else round(tax / 2, 2)
        igst = tax if is_interstate else 0.0

        rows.append({
            "invoice_number": inv_no,
            "order_id": str(o.id),
            "order_date": o.created_at.strftime("%Y-%m-%d %H:%M"),
            "shipping_state": getattr(o, "shipping_state", None) or "Standard",
            "tax_rate_percent": 5.0,
            "taxable_amount": taxable,
            "cgst": cgst,
            "sgst": sgst,
            "igst": igst,
            "total_tax": tax,
            "total_invoice_amount": tot,
            "payment_status": o.payment_status.value if hasattr(o.payment_status, "value") else str(o.payment_status),
            "order_status": o.order_status.value if hasattr(o.order_status, "value") else str(o.order_status),
        })

    if format.lower() == "csv":
        output = io.StringIO()
        fieldnames = [
            "invoice_number", "order_id", "order_date", "shipping_state",
            "tax_rate_percent", "taxable_amount", "cgst", "sgst", "igst",
            "total_tax", "total_invoice_amount", "payment_status", "order_status"
        ]
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        for r in rows:
            writer.writerow(r)
        return Response(
            content=output.getvalue(),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=gstr1_sales_register.csv"},
        )

    return {"success": True, "data": rows, "total": len(rows)}


@router.get("/admin/commerce/reports/settlements")
async def settlements_financial_report(
    format: str = "json",
    user: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    settlements_data = await get_vendor_settlements(user=user, db=db)
    items = settlements_data.get("data", [])

    rows = []
    for item in items:
        rows.append({
            "vendor_id": item["vendor_id"],
            "business_name": item["business_name"],
            "commission_rate_percent": item["commission_rate"],
            "gross_sales": item["gross_sales"],
            "platform_commission": item["commission_amount"],
            "net_payable": item["net_payable"],
            "total_settled": item["total_settled"],
            "pending_balance": item["pending_balance"],
            "bank_name": item.get("bank_name") or "",
            "account_number": item.get("account_number") or "",
            "ifsc_code": item.get("ifsc_code") or "",
            "upi_id": item.get("upi_id") or "",
            "payouts_count": item["payouts_count"],
        })

    if format.lower() == "csv":
        output = io.StringIO()
        fieldnames = [
            "vendor_id", "business_name", "commission_rate_percent",
            "gross_sales", "platform_commission", "net_payable",
            "total_settled", "pending_balance", "bank_name",
            "account_number", "ifsc_code", "upi_id", "payouts_count"
        ]
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        for r in rows:
            writer.writerow(r)
        return Response(
            content=output.getvalue(),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=vendor_settlements_register.csv"},
        )

    return {"success": True, "data": rows, "total": len(rows)}


