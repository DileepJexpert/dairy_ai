"""Create a repeatable local Milterra catalogue. Run: python -m scripts.seed_milterra_demo"""

import asyncio
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.database import async_session_factory
from app.models.product import Product, ProductCategory, ProductInventory
from app.models.user import User, UserRole
from app.models.vendor import Vendor, VendorType
from app.services.auth_service import hash_otp


PRODUCTS = [
    ("MIL-GHEE-500", "Milterra A2 Desi Cow Ghee", "500 ml", "Pure A2 ghee, slowly cultured for a rich aroma.", "799", 24),
    ("MIL-GHEE-1000", "Milterra A2 Desi Cow Ghee", "1 litre", "Everyday traditional ghee for cooking, sweets, and wellness.", "1499", 18),
    ("MIL-BUFF-500", "Milterra Buffalo Ghee", "500 ml", "Full-bodied buffalo ghee with a naturally rich texture.", "699", 20),
    ("MIL-PANEER-200", "Milterra Fresh Paneer", "200 g", "Fresh, high-protein paneer made from quality milk.", "160", 30),
]


async def seed() -> None:
    async with async_session_factory() as db:
        user = (await db.execute(select(User).where(User.phone == "9999900090"))).scalar_one_or_none()
        if not user:
            user = User(
                id=uuid.uuid4(),
                phone="9999900090",
                role=UserRole.vendor,
                is_active=True,
                otp_hash=hash_otp("123456"),
                otp_expires_at=(datetime.now(timezone.utc) + timedelta(days=365)).replace(tzinfo=None),
            )
            db.add(user)
            await db.flush()

        vendor = (await db.execute(select(Vendor).where(Vendor.user_id == user.id))).scalar_one_or_none()
        if not vendor:
            vendor = Vendor(
                id=uuid.uuid4(),
                user_id=user.id,
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

        created = 0
        for sku, title, pack_size, description, price, stock in PRODUCTS:
            product = (await db.execute(select(Product).where(Product.sku == sku))).scalar_one_or_none()
            if product:
                continue
            product = Product(
                id=uuid.uuid4(),
                vendor_id=vendor.id,
                sku=sku,
                title=title,
                slug=f"{sku.lower()}-{pack_size.replace(' ', '-')}",
                # The existing schema's feed category is used only as a temporary
                # catalogue bucket until the Milterra dairy categories migration.
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
            created += 1

        await db.commit()
        print(f"Milterra demo catalogue ready ({created} products created).")


if __name__ == "__main__":
    asyncio.run(seed())
