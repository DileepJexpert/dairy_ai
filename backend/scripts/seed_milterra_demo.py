"""Create a repeatable local Milterra catalogue, carts, visitor traffic, and clickstreams.
Run: python -m scripts.seed_milterra_demo
"""

import asyncio
import json
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy import select

from app.database import async_session_factory, init_db
from app.models.analytics import ClickstreamEvent, VisitorSession
from app.models.cart import Cart, CartItem, CartStatus
from app.models.product import Product, ProductCategory, ProductInventory
from app.models.user import User, UserRole
from app.models.vendor import Vendor, VendorType
from app.services.auth_service import hash_otp


PRODUCTS = [
    ("MIL-GHEE-250", "Milterra A2 Desi Cow Ghee (Trial Jar)", "250 ml", "Vedic A2 Bilona cultured Gir cow ghee in an accessible trial glass jar.", "425", 50),
    ("MIL-GHEE-500", "Milterra A2 Desi Cow Ghee (Family Jar)", "500 ml", "Pure A2 ghee, slowly cultured for a rich aroma.", "799", 35),
    ("MIL-GHEE-1000", "Milterra A2 Desi Cow Ghee (Kitchen Jar)", "1 litre", "Everyday traditional ghee for cooking, sweets, and wellness.", "1499", 25),
    ("MIL-GHEE-5000", "Milterra A2 Desi Cow Ghee (Heritage Tin)", "5 litre", "Bulk family pack of pure A2 Gir cow bilona ghee in food-grade tin.", "6999", 10),
    ("MIL-BUFF-500", "Milterra Traditional Cultured Buffalo Ghee", "500 ml", "Full-bodied, high-fat buffalo ghee with a naturally rich texture.", "699", 30),
    ("MIL-BUFF-1000", "Milterra Traditional Cultured Buffalo Ghee", "1 litre", "Artisanal Murrah buffalo cultured ghee for sweets and rotis.", "1299", 20),
    ("MIL-GHEE-SINGLE-FARM", "Milterra Single-Farm A2 Cultured Cow Ghee", "500 ml", "100% Single-Origin Traceable to our own Lucknow heritage pasture farm.", "899", 25),
    ("MIL-GHEE-FULL-MOON", "Milterra Full Moon (Purnima Batch) Bilona Ghee", "500 ml", "Limited batch churned and slow-cooked on the auspicious night of Purnima.", "999", 15),
    ("MIL-PANEER-200", "Milterra Fresh Paneer", "200 g", "Fresh, high-protein paneer made from quality milk.", "160", 40),
]

DEMO_CUSTOMERS = [
    ("9820112345", UserRole.farmer, "Mumbai", "Maharashtra"),
    ("9765422334", UserRole.farmer, "Pune", "Maharashtra"),
    ("9448199887", UserRole.farmer, "Bengaluru", "Karnataka"),
    ("9935144556", UserRole.farmer, "Lucknow", "Uttar Pradesh"),
    ("9829055667", UserRole.farmer, "Jaipur", "Rajasthan"),
]


async def seed() -> None:
    await init_db()
    async with async_session_factory() as db:
        # 1. Vendor & Products
        vendor_user = (await db.execute(select(User).where(User.phone == "9999900090"))).scalar_one_or_none()
        if not vendor_user:
            vendor_user = User(
                id=uuid.uuid4(),
                phone="9999900090",
                role=UserRole.vendor,
                is_active=True,
                otp_hash=hash_otp("123456"),
                otp_expires_at=(datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None),
            )
            db.add(vendor_user)
            await db.flush()

        vendor = (await db.execute(select(Vendor).where(Vendor.user_id == vendor_user.id))).scalar_one_or_none()
        if not vendor:
            vendor = Vendor(
                id=uuid.uuid4(),
                user_id=vendor_user.id,
                business_name="Milterra Dairy",
                vendor_type=VendorType.other,
                contact_person="Milterra Team",
                district="Bengaluru",
                state="Karnataka",
                description="Local development catalogue for Milterra dairy foods.",
                is_verified=True,
                is_active=True,
            )
            db.add(vendor)
            await db.flush()

        product_map: dict[str, Product] = {}
        for sku, title, pack_size, description, price, stock in PRODUCTS:
            product = (await db.execute(select(Product).where(Product.sku == sku))).scalar_one_or_none()
            if not product:
                product = Product(
                    id=uuid.uuid4(),
                    vendor_id=vendor.id,
                    sku=sku,
                    title=title,
                    slug=f"{sku.lower()}-{pack_size.replace(' ', '-')}",
                    category=ProductCategory.feed_nutrition,
                    brand="Milterra",
                    description=description,
                    base_price=price,
                    unit="pack",
                    pack_size=pack_size,
                    specifications={"storage": "Store in a cool, dry place", "origin": "India"},
                    is_active=True,
                    is_featured=True,
                    min_order_quantity=1,
                )
                db.add(product)
                await db.flush()
                db.add(ProductInventory(product_id=product.id, available_quantity=stock, reorder_level=5))
                await db.flush()
            product_map[sku] = product

        # 2. Demo Customers
        customer_users: list[User] = []
        for phone, role, city, state in DEMO_CUSTOMERS:
            c_user = (await db.execute(select(User).where(User.phone == phone))).scalar_one_or_none()
            if not c_user:
                c_user = User(
                    id=uuid.uuid4(),
                    phone=phone,
                    role=role,
                    is_active=True,
                    otp_hash=hash_otp("123456"),
                    otp_expires_at=(datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None),
                )
                db.add(c_user)
                await db.flush()
            customer_users.append(c_user)

        # 3. Seed Carts (Active & Abandoned)
        # Customer 0: Active Cart (added 15 mins ago)
        c0 = customer_users[0]
        cart0 = (await db.execute(select(Cart).where(Cart.user_id == c0.id))).scalar_one_or_none()
        if not cart0:
            cart0 = Cart(
                id=uuid.uuid4(),
                user_id=c0.id,
                status=CartStatus.active,
                created_at=datetime.utcnow() - timedelta(minutes=25),
                updated_at=datetime.utcnow() - timedelta(minutes=15),
            )
            db.add(cart0)
            await db.flush()
            p1000 = product_map.get("MIL-GHEE-1000")
            if p1000:
                db.add(CartItem(
                    id=uuid.uuid4(),
                    cart_id=cart0.id,
                    product_id=p1000.id,
                    quantity=2,
                    price_when_added=Decimal(p1000.base_price),
                    created_at=datetime.utcnow() - timedelta(minutes=25),
                    updated_at=datetime.utcnow() - timedelta(minutes=15),
                ))

        # Customer 1: Abandoned Cart (added 3 hours ago)
        c1 = customer_users[1]
        cart1 = (await db.execute(select(Cart).where(Cart.user_id == c1.id))).scalar_one_or_none()
        if not cart1:
            cart1 = Cart(
                id=uuid.uuid4(),
                user_id=c1.id,
                status=CartStatus.active,
                created_at=datetime.utcnow() - timedelta(hours=4),
                updated_at=datetime.utcnow() - timedelta(hours=3),
            )
            db.add(cart1)
            await db.flush()
            pbuff = product_map.get("MIL-BUFF-500")
            ppaneer = product_map.get("MIL-PANEER-200")
            if pbuff:
                db.add(CartItem(
                    id=uuid.uuid4(),
                    cart_id=cart1.id,
                    product_id=pbuff.id,
                    quantity=1,
                    price_when_added=Decimal(pbuff.base_price),
                    created_at=datetime.utcnow() - timedelta(hours=4),
                    updated_at=datetime.utcnow() - timedelta(hours=3),
                ))
            if ppaneer:
                db.add(CartItem(
                    id=uuid.uuid4(),
                    cart_id=cart1.id,
                    product_id=ppaneer.id,
                    quantity=2,
                    price_when_added=Decimal(ppaneer.base_price),
                    created_at=datetime.utcnow() - timedelta(hours=4),
                    updated_at=datetime.utcnow() - timedelta(hours=3),
                ))

        # Customer 3: Abandoned Cart (added 18 hours ago)
        c3 = customer_users[3]
        cart3 = (await db.execute(select(Cart).where(Cart.user_id == c3.id))).scalar_one_or_none()
        if not cart3:
            cart3 = Cart(
                id=uuid.uuid4(),
                user_id=c3.id,
                status=CartStatus.active,
                created_at=datetime.utcnow() - timedelta(hours=19),
                updated_at=datetime.utcnow() - timedelta(hours=18),
            )
            db.add(cart3)
            await db.flush()
            pghee500 = product_map.get("MIL-GHEE-500")
            if pghee500:
                db.add(CartItem(
                    id=uuid.uuid4(),
                    cart_id=cart3.id,
                    product_id=pghee500.id,
                    quantity=1,
                    price_when_added=Decimal(pghee500.base_price),
                    created_at=datetime.utcnow() - timedelta(hours=19),
                    updated_at=datetime.utcnow() - timedelta(hours=18),
                ))

        # 4. Seed Visitor Sessions across India
        sessions_seed = [
            ("sess-mum-01", c0.id, "103.21.124.5", "Mumbai", "Maharashtra", "https://wa.me/milterra-share", "whatsapp", "whatsapp", "social", "dairy_launch", "/shop", "mobile", 6),
            ("sess-pun-02", c1.id, "103.22.180.12", "Pune", "Maharashtra", "https://google.com/search?q=pure+desi+ghee", "google", None, None, None, "/shop", "mobile", 5),
            ("sess-blr-03", customer_users[2].id, "115.112.45.8", "Bengaluru", "Karnataka", "https://instagram.com/milterra", "instagram", "instagram", "feed", "monsoon_sale", "/shop/product/mil-ghee-1000", "mobile", 4),
            ("sess-lko-04", c3.id, "117.200.32.90", "Lucknow", "Uttar Pradesh", "direct", "direct", None, None, None, "/shop", "desktop", 3),
            ("sess-jpr-05", customer_users[4].id, "122.160.10.4", "Jaipur", "Rajasthan", "https://facebook.com", "facebook", "fb_ad", "banner", "ghee_promo", "/shop", "mobile", 4),
            ("sess-amd-06", None, "103.50.160.22", "Ahmedabad", "Gujarat", "direct", "direct", None, None, None, "/shop", "desktop", 2),
        ]

        for sid, uid, ip, city, state, ref, ref_type, utm_s, utm_m, utm_c, land, dev, pvs in sessions_seed:
            s_obj = (await db.execute(select(VisitorSession).where(VisitorSession.session_id == sid))).scalar_one_or_none()
            if not s_obj:
                s_obj = VisitorSession(
                    id=uuid.uuid4(),
                    session_id=sid,
                    user_id=uid,
                    ip_address=ip,
                    country="India",
                    state=state,
                    city=city,
                    referrer=ref,
                    referrer_type=ref_type,
                    utm_source=utm_s,
                    utm_medium=utm_m,
                    utm_campaign=utm_c,
                    landing_page=land,
                    device_type=dev,
                    browser="Chrome 122",
                    os="Android" if dev == "mobile" else "Windows 11",
                    page_views_count=pvs,
                    is_bounce=False,
                    started_at=datetime.utcnow() - timedelta(minutes=45),
                    last_seen_at=datetime.utcnow() - timedelta(minutes=5),
                )
                db.add(s_obj)

        # 5. Seed Clickstream Events for Customer 0 & 1
        p_ghee1000 = product_map.get("MIL-GHEE-1000")
        p_buff = product_map.get("MIL-BUFF-500")

        click_events = [
            ("sess-mum-01", c0.id, "PAGE_VIEW", "/shop", None, "Storefront Home", None, {"referrer": "WhatsApp Share"}),
            ("sess-mum-01", c0.id, "SEARCH_QUERY", "/shop", "search_box", "Search Query: Desi Cow Ghee", None, {"query": "Desi Cow Ghee", "results_found": 2}),
            ("sess-mum-01", c0.id, "PRODUCT_VIEW", f"/shop/product/{p_ghee1000.id if p_ghee1000 else 'prod-1'}", "card_product", "Milterra A2 Desi Cow Ghee 1L", str(p_ghee1000.id) if p_ghee1000 else None, {"price": "1499"}),
            ("sess-mum-01", c0.id, "CERTIFICATE_VIEW", "/purity/batch-certificate", "btn_purity_cert", "View FSSAI Quality Lab Certificate", "MIL-GH-2026-09", {"purity_percent": 99.4}),
            ("sess-mum-01", c0.id, "ADD_TO_CART", "/shop/product", "btn_add_to_cart", "Add to Cart", str(p_ghee1000.id) if p_ghee1000 else None, {"quantity": 2, "price": "1499"}),
            ("sess-mum-01", c0.id, "PAGE_VIEW", "/shop/cart", None, "Shopping Cart Review", None, {"item_count": 2, "subtotal": "2998"}),
            ("sess-pun-02", c1.id, "PAGE_VIEW", "/shop", None, "Storefront Home", None, {"utm_source": "google"}),
            ("sess-pun-02", c1.id, "PRODUCT_VIEW", f"/shop/product/{p_buff.id if p_buff else 'prod-2'}", "card_product", "Milterra Buffalo Ghee 500ml", str(p_buff.id) if p_buff else None, {"price": "699"}),
            ("sess-pun-02", c1.id, "ADD_TO_CART", "/shop/product", "btn_add_to_cart", "Add to Cart", str(p_buff.id) if p_buff else None, {"quantity": 1, "price": "699"}),
            ("sess-pun-02", c1.id, "CHECKOUT_INITIATE", "/shop/checkout", "btn_proceed_checkout", "Proceed to Checkout", None, {"cart_value": "1019", "step": "address_selection"}),
        ]

        for sid, uid, etype, url, el_id, el_text, tid, meta in click_events:
            ev_check = (await db.execute(
                select(ClickstreamEvent).where(
                    ClickstreamEvent.session_id == sid,
                    ClickstreamEvent.event_type == etype,
                    ClickstreamEvent.page_url == url,
                )
            )).scalar_one_or_none()
            if not ev_check:
                db.add(ClickstreamEvent(
                    id=uuid.uuid4(),
                    session_id=sid,
                    user_id=uid,
                    event_type=etype,
                    page_url=url,
                    element_id=el_id,
                    element_text=el_text,
                    target_id=tid,
                    metadata_json=json.dumps(meta),
                    created_at=datetime.utcnow() - timedelta(minutes=10),
                ))

        await db.commit()
        print("Milterra demo catalogue, demo carts, visitor traffic, and clickstreams seeded successfully!")


if __name__ == "__main__":
    asyncio.run(seed())
