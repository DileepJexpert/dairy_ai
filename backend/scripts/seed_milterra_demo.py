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
from app.models.product import Product, ProductCategory, ProductFamily, ProductInventory
from app.models.user import User, UserRole
from app.models.vendor import Vendor, VendorType
from app.services.auth_service import hash_otp, hash_password


PRODUCTS = [
    ("MIL-GHEE-250", "Milterra A2 Sahiwal Cow Ghee (Trial Jar)", "250 ml", "Planned cultured-butter bilona ghee made from Sahiwal cow milk in an accessible trial glass jar.", "425", 50),
    ("MIL-GHEE-500", "Milterra A2 Sahiwal Cow Ghee (Family Jar)", "500 ml", "Planned A2 Sahiwal cow ghee prepared from cultured curd and slowly clarified for aroma and texture.", "799", 35),
    ("MIL-GHEE-1000", "Milterra A2 Sahiwal Cow Ghee (Kitchen Jar)", "1 litre", "Planned everyday cultured-butter Sahiwal cow ghee for cooking and Indian sweets.", "1499", 25),
    ("MIL-GHEE-5000", "Milterra A2 Sahiwal Cow Ghee (Heritage Tin)", "5 litre", "Planned family pack of A2 Sahiwal cow cultured-butter ghee in a food-grade tin.", "6999", 10),
    ("MIL-BUFF-500", "Milterra Traditional Cultured Buffalo Ghee", "500 ml", "Full-bodied, high-fat buffalo ghee with a naturally rich texture.", "699", 30),
    ("MIL-BUFF-1000", "Milterra Traditional Cultured Buffalo Ghee", "1 litre", "Artisanal Murrah buffalo cultured ghee for sweets and rotis.", "1299", 20),
    ("MIL-GHEE-SINGLE-FARM", "Milterra Single-Farm A2 Sahiwal Cow Ghee", "500 ml", "Planned single-farm Sahiwal milk sourcing with batch-level traceability.", "899", 25),
    ("MIL-GHEE-FULL-MOON", "Milterra Full Moon (Purnima Batch) Sahiwal Ghee", "500 ml", "A proposed limited Purnima-themed batch using the same planned cultured-butter Sahiwal milk process.", "999", 15),
    ("MIL-MILK-COW-1L", "Milterra Pure A2 Sahiwal Cow Milk", "1 litre", "Farm-fresh, raw chilled A2 Sahiwal cow milk delivered in sterilized glass bottles. 100% pure and natural.", "85", 60),
    ("MIL-MILK-BUFF-1L", "Milterra Fresh Murrah Buffalo Milk", "1 litre", "Thick, creamy, high-fat Murrah buffalo milk in glass bottles. Ideal for pure curd, kheer, and sweets.", "90", 40),
    ("MIL-CHHACHH-1L", "Milterra Vedic Desi Cow Chhachh (Spiced Buttermilk)", "1 litre", "Authentic churned bilona chhachh spiced with roasted cumin, mint, and rock salt. Probiotic rich.", "45", 50),
    ("MIL-PANEER-200", "Milterra Fresh Sahiwal Milk Paneer", "200 g", "Planned fresh paneer made from Sahiwal cow milk and packed under refrigeration.", "160", 40),
    ("MIL-BUTTER-250", "Milterra Cultured White Butter (Makhan)", "250 g", "Traditional home-churned unsalted white butter (safed makhan). Fresh and preservative-free.", "240", 30),
    ("MIL-SARSO-OIL-1L", "Milterra Wood-Pressed Kachi Ghani Mustard (Sarso) Oil", "1 litre", "Traditional cold-pressed yellow mustard oil extracted at low temperature without heat treatment.", "260", 50),
    ("MIL-EARTH-VERMI-5KG", "Milterra Earth Pure Bio-Vermicompost", "5 kg", "Aged indigenous cow dung vermicompost enriched with living beneficial microbes and organic carbon.", "299", 60),
    ("MIL-HAWAN-GHEE-1L", "Milterra Pure Desi Cow Hawan Ghee (Yajna Special)", "1 litre", "Specially clarified pure Desi Cow Hawan Ghee formulated for holy yajnas, homams, and akhand jyot with clean, smoke-free flame.", "649", 40),
    ("MIL-GOBAR-UPLE-12", "Milterra Vedic Desi Cow Dung Cakes (Hawan Kanda)", "Pack of 12", "Traditional sun-dried Gir cow dung cakes infused with neem leaves. Specially prepared for sacred hawan fires and home purification.", "149", 100),
    ("MIL-DHOOP-BATTI-100", "Milterra Panchagavya Cow Dung Dhoop Sticks (Guggal & Loban)", "100 g", "100% organic, charcoal-free dhoop batti crafted from pure desi cow dung, natural herbs, guggul, and loban with ceramic holder.", "199", 75),
    ("MIL-BHIMSENI-KAPOOR-100", "Milterra Shuddha Bhimseni Pure Camphor (Original Flakes)", "100 g", "Pure crystalline Bhimseni Kapoor flakes for daily aarti and hawan. Burns completely without leaving any toxic residue or black smoke.", "249", 60),
    ("MIL-HAWAN-SAMAGRI-500", "Milterra Vedic Navgraha Hawan Samagri (51 Herbs & Guggul)", "500 g", "Sacred blend of 51 Ayurvedic herbs, dried flowers, navgraha samidha woods, jatamansi, nagarmotha, and pure guggul resin for havans.", "220", 50),
    ("MIL-GOMAYE-DIYA-24", "Milterra Handcrafted Cow Dung Diyas (Gomaye Deepam)", "Pack of 24", "Eco-friendly, biodegradable sacred diyas hand-moulded from indigenous cow dung and natural plant binders. Ash serves as organic soil fertilizer.", "179", 80),
]

CONCEPT_FAMILIES = [
    (
        "MILTERRA MINERA-360 Mineral Supplement Concept",
        "milterra-minera-360-concept",
        "Mineral supplements",
    ),
    (
        "JANAM·42 Calving & Transition Nutrition Concept",
        "janam-42-transition-nutrition-concept",
        "Stage-based nutrition",
    ),
    (
        "MILTERRA RUMEN-PRO Rumen Support Concept",
        "milterra-rumen-pro-concept",
        "Rumen support",
    ),
]

CONCEPT_EXPLANATION = (
    "This product concept is in development. Share your feedback and register "
    "for future updates."
)


def product_specifications(sku: str) -> dict[str, str]:
    """Truthful pre-launch specifications shared by both local seed workflows."""
    common = {
        "Product Status": "Pre-launch specification; final production and lab validation pending",
        "Country of Origin": "India",
    }
    if sku.startswith("MIL-HAWAN-GHEE-"):
        return {
            **common,
            "Source": "100% Pure Desi Cow Milk Fat",
            "Intended Rituals": "Yajna, Havan, Homam, Agnihotra, Akhand Jyot, and Aarti",
            "Characteristics": "Clean golden flame, minimal soot, natural auspicious satvik aroma",
            "Storage": "Store sealed in a cool, dry place away from direct sunlight",
            "Shelf Life": "12 months from packing date",
        }
    if sku.startswith("MIL-GOBAR-UPLE-"):
        return {
            **common,
            "Raw Material": "100% Indigenous Desi Cow Dung & Organic Neem Leaves",
            "Processing": "Naturally sun-dried and sanitized, zero chemical additives or coal",
            "Intended Rituals": "Vedic Yajna, Homa, Agnihotra, Dhoop base, Environment purification",
            "Packaging": "12 pieces cushioned box packing to prevent breakage",
        }
    if sku.startswith("MIL-DHOOP-BATTI-"):
        return {
            **common,
            "Composition": "Gir Cow Dung, Pure Guggul, Natural Loban, Bhimseni Camphor, Ayurvedic Herbs",
            "Features": "100% Charcoal-Free, Bamboo-Less, Chemical-Free, Low Smoke",
            "Burning Time": "Approx 45 minutes per stick",
            "Package Contents": "30 Dhoop Sticks with 1 handmade ceramic holder",
        }
    if sku.startswith("MIL-BHIMSENI-KAPOOR-"):
        return {
            **common,
            "Purity": "100% Pure Bhimseni Camphor (Cinnamomum camphora extract flakes)",
            "Residue Standard": "Leaves zero soot, ash, or toxic chemical residue upon combustion",
            "Usage": "Daily Aarti, Hawan Ahuti, Diffusers, and Natural Aromatherapy",
            "Storage": "Keep tightly closed in an airtight jar to prevent evaporation",
        }
    if sku.startswith("MIL-HAWAN-SAMAGRI-"):
        return {
            **common,
            "Herbal Composition": "51 Sacred Herbs: Jatamansi, Nagarmotha, Chandan, Guggul, Loban, Navgraha Woods",
            "Purity Standard": "100% Natural botanicals, no added artificial colour or synthetic perfume",
            "Usage": "Sacred Ahuti in Navchandi, Griha Pravesh, Gayatri Hawan, and Daily Homa",
            "Net Quantity": "500 grams",
        }
    if sku.startswith("MIL-GOMAYE-DIYA-"):
        return {
            **common,
            "Raw Material": "Pure Indigenous Cow Dung, Organic Clay, and Natural Plant Binders",
            "Eco Property": "100% Biodegradable; burns completely with ghee leaving sacred holy ash",
            "Use": "Diwali, Navratri, Daily Mandir Puja, and Floating Deepdan",
            "Package Contents": "24 pieces per pack",
        }
    if sku.startswith("MIL-GHEE-"):
        return {
            **common,
            "Milk Source": "Planned: A2 milk from Sahiwal cows",
            "Ingredients": "Planned: cultured butter prepared from Sahiwal cow milk",
            "How It Is Made": (
                "Milk is filtered and cultured into curd; the curd is churned to separate butter; "
                "the butter is slowly clarified, filtered, cooled, and packed. Exact time and "
                "temperature controls will be finalized before commercial launch."
            ),
            "Proposed Additives": "No added colour, flavour, or preservative",
            "Storage": "Store sealed in a cool, dry place; use a clean, dry spoon",
            "Shelf Life": "To be confirmed by production stability testing",
        }
    if sku.startswith("MIL-BUFF-"):
        return {
            **common,
            "Milk Source": "Planned: Murrah buffalo milk",
            "Ingredients": "Planned: cultured butter prepared from buffalo milk",
            "How It Is Made": (
                "Buffalo milk is filtered and cultured into curd; the curd is churned for butter; "
                "the butter is slowly clarified, filtered, cooled, and packed."
            ),
            "Proposed Texture": "Rich and naturally granular",
            "Storage": "Store sealed in a cool, dry place; use a clean, dry spoon",
            "Shelf Life": "To be confirmed by production stability testing",
        }
    return {
        **common,
        "Milk Source": "Planned: fresh Sahiwal cow milk",
        "Ingredients": "Sahiwal cow milk and a food-grade acidulant; exact formulation pending",
        "How It Is Made": (
            "Milk is filtered and heat-treated, gently coagulated, drained, pressed into blocks, "
            "rapidly chilled, and packed for refrigerated distribution."
        ),
        "Storage": "Keep refrigerated at 0–4°C",
        "Shelf Life": "To be confirmed by refrigerated shelf-life testing",
    }

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
        # 1. Admin & Vendor Users
        admin_user = (await db.execute(select(User).where(User.phone == "9999900000"))).scalar_one_or_none()
        if not admin_user:
            admin_user = User(
                id=uuid.uuid4(),
                phone="9999900000",
                role=UserRole.admin,
                is_active=True,
                password_hash=hash_password("Password@123"),
                otp_hash=hash_otp("123456"),
                otp_expires_at=(datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None),
            )
            db.add(admin_user)
            await db.flush()
        else:
            admin_user.password_hash = hash_password("Password@123")
            admin_user.otp_hash = hash_otp("123456")
            admin_user.otp_expires_at = (datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None)
            await db.flush()

        vendor_user = (await db.execute(select(User).where(User.phone == "9999900090"))).scalar_one_or_none()
        if not vendor_user:
            vendor_user = User(
                id=uuid.uuid4(),
                phone="9999900090",
                role=UserRole.vendor,
                is_active=True,
                password_hash=hash_password("Password@123"),
                otp_hash=hash_otp("123456"),
                otp_expires_at=(datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None),
            )
            db.add(vendor_user)
            await db.flush()
        else:
            vendor_user.password_hash = hash_password("Password@123")
            vendor_user.otp_hash = hash_otp("123456")
            vendor_user.otp_expires_at = (datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None)
            await db.flush()

        farmer_user = (await db.execute(select(User).where(User.phone == "9876500001"))).scalar_one_or_none()
        if not farmer_user:
            farmer_user = User(
                id=uuid.uuid4(),
                phone="9876500001",
                role=UserRole.farmer,
                is_active=True,
                password_hash=hash_password("Password@123"),
                otp_hash=hash_otp("123456"),
                otp_expires_at=(datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None),
            )
            db.add(farmer_user)
            await db.flush()
        else:
            farmer_user.password_hash = hash_password("Password@123")
            farmer_user.otp_hash = hash_otp("123456")
            farmer_user.otp_expires_at = (datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None)
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

        for title, slug, subcategory in CONCEPT_FAMILIES:
            concept = (
                await db.execute(select(ProductFamily).where(ProductFamily.slug == slug))
            ).scalar_one_or_none()
            if not concept:
                db.add(ProductFamily(
                    id=uuid.uuid4(),
                    vendor_id=vendor.id,
                    slug=slug,
                    title=title,
                    brand="MILTERRA",
                    department="Farm Essentials",
                    collection="Animal Nutrition",
                    description=CONCEPT_EXPLANATION,
                    production_method=(
                        "Proposed formulation; composition and claims require validation before launch."
                    ),
                    is_published=True,
                    is_concept=True,
                    supporting_documents={
                        "subcategory": subcategory,
                        "status": "concept_preview",
                    },
                ))
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
                    specifications=product_specifications(sku),
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
                    password_hash=hash_password("Password@123"),
                    otp_hash=hash_otp("123456"),
                    otp_expires_at=(datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None),
                )
                db.add(c_user)
                await db.flush()
            else:
                c_user.password_hash = hash_password("Password@123")
                c_user.otp_hash = hash_otp("123456")
                c_user.otp_expires_at = (datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None)
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

        from scripts.initialize_commerce_admin import seed_coupons
        await seed_coupons(db)
        await db.commit()
        print("Milterra demo catalogue, coupons, demo carts, visitor traffic, and clickstreams seeded successfully!")


if __name__ == "__main__":
    asyncio.run(seed())
