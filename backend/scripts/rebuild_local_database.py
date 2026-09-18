"""Explicitly rebuild a disposable local PostgreSQL schema from current models.

Without --execute this only prints a plan. Never imported by application startup.
"""
import argparse
import asyncio
import uuid
from decimal import Decimal

from sqlalchemy import Enum, text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import settings
from app.database import Base
import app.models  # noqa: F401 - register the COMPLETE application schema
from app.models.commerce_taxonomy import TaxonomyLock, TaxonomyNode, ProductClassification
from app.models.product import Product, ProductCategory, ProductFamily, ProductInventory, ProductReview, MerchandisingPlacement
from app.models.user import User, UserRole
from app.models.vendor import Vendor, VendorType
from scripts.seed_milterra_demo import CONCEPT_EXPLANATION, CONCEPT_FAMILIES, PRODUCTS, product_specifications


def validate_target(database_url, environment, confirmation=None, execute=False):
    url = make_url(database_url)
    if environment.lower() not in {"development", "test"}:
        raise ValueError("Rebuild is restricted to APP_ENV=development or test")
    if url.drivername != "postgresql+asyncpg" or url.host not in {"localhost", "127.0.0.1", "::1", "postgres"}:
        raise ValueError("Only a loopback PostgreSQL asyncpg connection is allowed")
    if url.query:
        raise ValueError("URL query overrides are not allowed for a destructive rebuild")
    if not url.database or url.database in {"postgres", "template0", "template1"}:
        raise ValueError("A non-system application database must be explicitly selected")
    if execute and confirmation != url.database:
        raise ValueError("--confirm-database must exactly match the configured database name")
    return url


def validate_metadata():
    """Fail before deletion if unrelated Python enums share a PostgreSQL name."""
    definitions = {}
    for table in Base.metadata.sorted_tables:
        for column in table.columns:
            if isinstance(column.type, Enum) and column.type.native_enum:
                definition = tuple(column.type.enums)
                previous = definitions.setdefault(column.type.name, definition)
                if previous != definition:
                    raise ValueError(f"Conflicting enum definitions: {column.type.name}")


def taxonomy_id(slug):
    return uuid.uuid5(uuid.NAMESPACE_URL, f"milterra:taxonomy:{slug}")


async def seed_foundation(db, demo=False):
    db.add(TaxonomyLock(id=1))
    rows = [("dairy-foods", "Dairy Foods", None),
            ("all-ghee", "All Ghee", "dairy-foods"),
            ("cow-ghee", "Cow ghee", "dairy-foods"),
            ("buffalo-ghee", "Buffalo ghee", "dairy-foods"),
            ("herbal-ghee", "Herbal Ghee", "dairy-foods"),
            ("paneer", "Paneer", "dairy-foods"),
            ("puja-hawan-samagri", "Puja & Hawan Samagri", None),
            ("hawan-yajna-ghee", "Hawan & Yajna Ghee", "puja-hawan-samagri"),
            ("cow-dung-products", "Cow Dung Sacred Products", "puja-hawan-samagri"),
            ("dhoop-agarbatti", "Natural Dhoop & Agarbatti", "puja-hawan-samagri"),
            ("kapoor-samagri", "Bhimseni Kapoor & Samagri", "puja-hawan-samagri"),
            ("farm-essentials", "Farm Essentials", None),
            ("animal-nutrition", "Animal nutrition", "farm-essentials"),
            ("equipment", "Equipment", "farm-essentials")]
    for order, (slug, name, parent) in enumerate(rows):
        db.add(TaxonomyNode(id=taxonomy_id(slug), kind="category" if parent else "department",
                            parent_id=taxonomy_id(parent) if parent else None, name=name, slug=slug,
                            description="", sort_order=order, is_active=True, version=1))
        await db.flush()
    if not demo:
        return
    from scripts.initialize_commerce_admin import seed_coupons
    await seed_coupons(db)
    vendor_user = User(id=uuid.uuid4(), phone="9999900090", role=UserRole.vendor, is_active=True)
    admin_user = User(id=uuid.uuid4(), phone="9999900000", role=UserRole.admin, is_active=True)
    # Explicit demo mode ONLY; no fixed OTP is persisted by this script.
    db.add_all([vendor_user, admin_user])
    await db.flush()
    vendor = Vendor(id=uuid.uuid4(), user_id=vendor_user.id, business_name="Milterra Dairy",
                    vendor_type=VendorType.other, district="Lucknow", state="Uttar Pradesh",
                    is_active=True, is_verified=True)
    db.add(vendor)
    await db.flush()
    for title, slug, subcategory in CONCEPT_FAMILIES:
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
    created_products = {}
    for sku, title, pack, description, price, stock in PRODUCTS:
        product = Product(id=uuid.uuid4(), vendor_id=vendor.id, sku=sku, slug=sku.lower(),
                          title=title, pack_size=pack, description=description, base_price=Decimal(price),
                          category=ProductCategory.feed_nutrition, brand="Milterra", unit="pack",
                          specifications=product_specifications(sku),
                          is_active=True, is_featured=True, min_order_quantity=1)
        db.add(product)
        await db.flush()
        created_products[sku] = product
        db.add(ProductInventory(product_id=product.id, available_quantity=stock, reorder_level=5))
        if sku.startswith("MIL-BUFF-"):
            taxonomy_slug = "buffalo-ghee"
        elif sku.startswith("MIL-PANEER-"):
            taxonomy_slug = "paneer"
        elif sku.startswith("MIL-HAWAN-GHEE-"):
            taxonomy_slug = "hawan-yajna-ghee"
        elif sku.startswith("MIL-GOBAR-") or sku.startswith("MIL-GOMAYE-"):
            taxonomy_slug = "cow-dung-products"
        elif sku.startswith("MIL-DHOOP-"):
            taxonomy_slug = "dhoop-agarbatti"
        elif sku.startswith("MIL-BHIMSENI-") or sku.startswith("MIL-HAWAN-SAMAGRI-"):
            taxonomy_slug = "kapoor-samagri"
        else:
            taxonomy_slug = "cow-ghee"

        db.add(ProductClassification(
            product_id=product.id,
            category_id=taxonomy_id(taxonomy_slug),
            version=1,
        ))
    highlighted = created_products.get("MIL-GHEE-500")
    if highlighted:
        db.add(MerchandisingPlacement(
            product_id=highlighted.id,
            placement_type="new_launch",
            headline="Discover Milterra A2 Sahiwal Cow Ghee",
            subheadline="Planned cultured-butter bilona process · 500 ml family jar",
            badge="NEW LAUNCH PREVIEW",
            priority=250,
            is_active=True,
            created_by_user_id=admin_user.id,
        ))
    seeded_feedback = [
        ("MIL-GHEE-500", "Pre-launch taster", 5, "Promising premium presentation",
         "The jar, label and pack-size idea feel suitable for a premium household ghee brand."),
        ("MIL-BUFF-500", "Catalogue preview participant", 4, "Would like more sourcing detail",
         "The product idea is interesting. I would like to see origin, batch and preparation details before launch."),
        ("MIL-PANEER-200", "Early catalogue visitor", 4, "Useful everyday pack size",
         "The proposed pack size looks convenient for a small family and I would consider trying it after launch."),
        ("MIL-HAWAN-GHEE-1L", "Temple Purohit", 5, "Remarkable pure flame & sacred aroma",
         "The hawan ghee burns with zero black soot and a natural, soothing Vedic aroma. Highly recommended for daily aarti and yajnas."),
        ("MIL-GOBAR-UPLE-12", "Agnihotra Practitioner", 5, "Authentic pure desi cow uple",
         "Sun-dried to perfection, burns evenly with neem protection. Rare to find authentic Gir cow dung cakes like this."),
        ("MIL-DHOOP-BATTI-100", "Aarti Devotee", 5, "Truly charcoal-free and divine",
         "No coughing or synthetic scent. You can feel the real guggul and cow dung purity immediately."),
    ]
    for sku, author, rating, headline, content in seeded_feedback:
        product = created_products.get(sku)
        if product:
            db.add(ProductReview(
                product_id=product.id,
                author_name=author,
                rating=rating,
                headline=headline,
                content=content,
                source_label="Illustrative pre-launch feedback",
                is_seeded=True,
                is_approved=True,
            ))
    await db.flush()


async def rebuild(database_url, environment, confirmation, demo=False):
    url = validate_target(database_url, environment, confirmation, execute=True)
    validate_metadata()
    engine = create_async_engine(url)
    try:
        async with engine.begin() as connection:
            actual = await connection.scalar(text("SELECT current_database()"))
            if actual != confirmation:
                raise ValueError("Connected database differs from confirmed target")
            await connection.execute(text("SET LOCAL lock_timeout = '5s'"))
            await connection.execute(text("SELECT pg_advisory_xact_lock(71911001)"))
            other_schemas = (await connection.execute(text(
                "SELECT n.nspname FROM pg_namespace n "
                "WHERE n.nspname NOT IN ('public', 'information_schema') AND n.nspname NOT LIKE 'pg_%' "
                "AND NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_extension e ON e.oid = d.refobjid "
                "WHERE d.classid = 'pg_namespace'::regclass AND d.objid = n.oid "
                "AND d.refclassid = 'pg_extension'::regclass AND d.deptype = 'e' AND e.extname = 'timescaledb')"
            ))).scalars().all()
            if other_schemas:
                raise ValueError("Refusing a database containing additional user schemas")
            timescale = await connection.scalar(text("SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname='timescaledb')"))
            # Fixed, explicit scope: public schema of the validated local database.
            # PostgreSQL transactional DDL restores the old schema if any step fails.
            await connection.execute(text("DROP SCHEMA IF EXISTS public CASCADE"))
            await connection.execute(text("CREATE SCHEMA public"))
            if timescale:
                await connection.execute(text("CREATE EXTENSION IF NOT EXISTS timescaledb"))
            await connection.run_sync(Base.metadata.create_all)
            async with AsyncSession(bind=connection, expire_on_commit=False) as db:
                await seed_foundation(db, demo)
                await db.flush()
            # Deliberately no Alembic stamp: this is the current model baseline,
            # not a claim that the historical ALTER migration chain was executed.
    finally:
        await engine.dispose()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="DELETE all public-schema data and recreate")
    parser.add_argument("--confirm-database", help="Exact application database name; required with --execute")
    parser.add_argument("--seed-demo", action="store_true", help="Add local demo admin, vendor and four products")
    args = parser.parse_args()
    try:
        url = validate_target(settings.DATABASE_URL, settings.APP_ENV, args.confirm_database, args.execute)
        validate_metadata()
        print(f"Target: {url.host}:{url.port or 5432}/{url.database}; schema=public; tables={len(Base.metadata.tables)}")
        if not args.execute:
            print("DRY RUN: no database connection or changes. Rebuild deletes ALL data in this schema.")
            return
        asyncio.run(rebuild(settings.DATABASE_URL, settings.APP_ENV, args.confirm_database, args.seed_demo))
        print("Rebuild complete. Current full schema and taxonomy created; historical migrations not replayed.")
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
