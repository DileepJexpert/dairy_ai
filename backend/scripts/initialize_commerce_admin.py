"""Create only the additive commerce-admin tables; never drop or alter local data.

Run: python -m scripts.initialize_commerce_admin [--seed-demo]
The existing application schema must already exist.
"""
import argparse
import asyncio
from decimal import Decimal

from sqlalchemy import select

import app.models  # noqa: F401
from app.database import engine, async_session_factory
from app.models.commerce_admin import CommerceCoupon, OrderCoupon, CommerceCertificate, CommerceAudit


async def seed_coupons(db):
    """Opt-in demo records live in the database, and never overwrite admin edits."""
    for code, kind, value, minimum, cap in [
        ("MILTERRA10", "percentage", "10", "499", "250"),
        ("FARMER50", "flat", "50", "299", "50"),
    ]:
        if (await db.execute(select(CommerceCoupon.id).where(CommerceCoupon.code == code))).first():
            continue
        db.add(CommerceCoupon(code=code, description=f"Pre-launch demo offer: {code}",
            discount_type=kind, discount_value=Decimal(value), min_order_value=Decimal(minimum),
            max_discount_cap=Decimal(cap), is_active=True))
    await db.flush()


async def initialize(demo=False):
    async with engine.begin() as connection:
        for model in (CommerceCoupon, OrderCoupon, CommerceCertificate, CommerceAudit):
            await connection.run_sync(lambda conn, table=model.__table__: table.create(conn, checkfirst=True))
    if demo:
        async with async_session_factory() as db:
            await seed_coupons(db)
            await db.commit()
    print("Commerce-admin tables are ready. Existing products, users and orders were preserved.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed-demo", action="store_true")
    asyncio.run(initialize(parser.parse_args().seed_demo))
