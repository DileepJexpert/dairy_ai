import re,uuid
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.product import Product, ProductFamily, ProductInventory, ProductMedia, ProductCategory
from app.repositories import product_repo
from app.schemas.product import ProductCreate, ProductUpdate, InventoryUpdate, ProductMediaCreate, ProductFamilyCreate, ProductFamilyUpdate, FamilyVariantCreate
def slugify(value:str)->str:return re.sub(r"[^a-z0-9]+","-",value.lower()).strip("-")

async def create_family(db:AsyncSession, vendor_id:uuid.UUID, data:ProductFamilyCreate) -> ProductFamily:
    slug = data.slug or slugify(data.title)
    existing = await product_repo.get_family_by_slug(db, slug)
    if existing:
        slug = f"{slug}-{uuid.uuid4().hex[:6]}"
    fam = ProductFamily(
        vendor_id=vendor_id,
        slug=slug,
        title=data.title,
        brand=data.brand,
        department=data.department,
        collection=data.collection,
        milk_source=data.milk_source,
        production_method=data.production_method,
        ingredients=data.ingredients,
        description=data.description,
        is_published=data.is_published,
        is_concept=data.is_concept,
        supporting_documents=data.supporting_documents or {},
    )
    db.add(fam)
    await db.flush()
    return fam

async def update_family(db:AsyncSession, fam:ProductFamily, vendor_id:uuid.UUID, is_admin:bool, data:ProductFamilyUpdate) -> ProductFamily:
    if not is_admin and fam.vendor_id != vendor_id:
        raise HTTPException(403, "You can manage only your product families")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(fam, k, v)
    if data.title and not data.model_dump().get("slug"):
        fam.slug = slugify(data.title)
    await db.flush()
    return fam

async def create_family_variant(db:AsyncSession, fam:ProductFamily, vendor_id:uuid.UUID, is_admin:bool, data:FamilyVariantCreate) -> Product:
    if not is_admin and fam.vendor_id != vendor_id:
        raise HTTPException(403, "You can manage only your product families")
    if fam.is_concept:
        raise HTTPException(422, "Concept families cannot have purchasable variants")
    if await product_repo.sku_exists(db, data.sku):
        raise HTTPException(409, f"SKU '{data.sku}' already exists")
    cat = ProductCategory.equipment if "equipment" in fam.department.lower() or "machinery" in fam.department.lower() else ProductCategory.feed_nutrition
    p = Product(
        vendor_id=fam.vendor_id,
        family_id=fam.id,
        sku=data.sku,
        title=f"{fam.title} ({data.pack_size})",
        slug=slugify(f"{data.sku}-{data.pack_size}"),
        category=cat,
        brand=fam.brand,
        description=fam.description,
        base_price=data.base_price,
        compare_at_price=data.compare_at_price,
        unit=data.unit,
        pack_size=data.pack_size,
        weight_grams=data.weight_grams,
        publication_status=data.publication_status,
        specifications={
            "family_id": str(fam.id),
            "publication_status": data.publication_status,
            "milk_source": fam.milk_source,
            "production_method": fam.production_method,
        },
        is_active=True,
    )
    db.add(p)
    await db.flush()
    inv = ProductInventory(product_id=p.id, available_quantity=data.initial_stock, reorder_level=5)
    db.add(inv)
    await db.flush()
    return p

async def create(db:AsyncSession,vendor_id:uuid.UUID,data:ProductCreate,is_admin:bool=True):
    if await product_repo.sku_exists(db,data.sku):raise HTTPException(409,"SKU already exists")
    if data.family_id:
        family = await product_repo.get_family(db, data.family_id)
        if not family or family.vendor_id != vendor_id: raise HTTPException(422,"Product family is unavailable for this vendor")
    values = data.model_dump(exclude={"vendor_id", "category_id", "initial_stock"})
    cat_val = values.get("category")
    if isinstance(cat_val, str):
        try:
            values["category"] = ProductCategory(cat_val)
        except ValueError:
            values["category"] = ProductCategory.equipment if "equipment" in cat_val.lower() else ProductCategory.feed_nutrition
    if not is_admin:
        values["publication_status"] = "pending_approval"
    p=Product(vendor_id=vendor_id,slug=slugify(data.title),**values);db.add(p);await db.flush()
    db.add(ProductInventory(product_id=p.id, available_quantity=data.initial_stock));await db.flush()
    if data.category_id:
        from app.models.commerce_taxonomy import ProductClassification, TaxonomyNode
        node = await db.get(TaxonomyNode, data.category_id)
        if node and node.is_active:
            classification = ProductClassification(product_id=p.id, category_id=node.id, version=1)
            db.add(classification)
            await db.flush()
    return p

async def update(db:AsyncSession,p:Product,vendor_id:uuid.UUID,is_admin:bool,data:ProductUpdate):
    if not is_admin and p.vendor_id!=vendor_id:raise HTTPException(403,"You can manage only your products")
    if data.family_id:
        family = await product_repo.get_family(db, data.family_id)
        if not family or family.vendor_id != p.vendor_id: raise HTTPException(422,"Product family is unavailable for this vendor")
    update_data = data.model_dump(exclude_unset=True, exclude={"category_id"})
    if "category" in update_data and isinstance(update_data["category"], str):
        try:
            update_data["category"] = ProductCategory(update_data["category"])
        except ValueError:
            update_data["category"] = ProductCategory.equipment if "equipment" in update_data["category"].lower() else ProductCategory.feed_nutrition
    for k,v in update_data.items():setattr(p,k,v)
    if data.title:p.slug=slugify(data.title)
    if p.family_id:
        specs = dict(p.specifications or {})
        specs["family_id"] = str(p.family_id)
        if p.publication_status:
            specs["publication_status"] = p.publication_status
        p.specifications = specs
    if data.category_id:
        from app.models.commerce_taxonomy import ProductClassification, TaxonomyNode
        node = await db.get(TaxonomyNode, data.category_id)
        if node and node.is_active:
            classification = (await db.execute(select(ProductClassification).where(ProductClassification.product_id == p.id))).scalar_one_or_none()
            if not classification:
                db.add(ProductClassification(product_id=p.id, category_id=node.id, version=1))
            else:
                classification.category_id = node.id
                classification.version += 1
    await db.flush();return p

async def update_inventory(db:AsyncSession,p:Product,vendor_id:uuid.UUID,is_admin:bool,data:InventoryUpdate):
    if not is_admin and p.vendor_id!=vendor_id:raise HTTPException(403,"You can manage only your products")
    if data.reserved_quantity>data.available_quantity:raise HTTPException(422,"Reserved quantity cannot exceed available quantity")
    inv=await product_repo.inventory(db,p.id)
    if not inv:inv=ProductInventory(product_id=p.id);db.add(inv)
    for k,v in data.model_dump(exclude_unset=True).items():setattr(inv,k,v)
    await db.flush();return inv

async def add_media(db:AsyncSession,p:Product,vendor_id:uuid.UUID,is_admin:bool,data:ProductMediaCreate):
    if not is_admin and p.vendor_id!=vendor_id:raise HTTPException(403,"You can manage only your products")
    await db.execute(select(Product.id).where(Product.id==p.id).with_for_update())
    if len(await product_repo.media(db,p.id)) >= 12:raise HTTPException(422,"A product can have at most 12 images; remove one first")
    if data.is_primary:
        for x in await product_repo.media(db,p.id):x.is_primary=False
    x=ProductMedia(product_id=p.id,**data.model_dump());db.add(x);await db.flush();return x

def serialize_family(fam: ProductFamily, variants: list | None = None) -> dict:
    return {
        "id": str(fam.id),
        "vendor_id": str(fam.vendor_id),
        "slug": fam.slug,
        "title": fam.title,
        "brand": fam.brand,
        "department": fam.department,
        "collection": fam.collection,
        "milk_source": fam.milk_source,
        "production_method": fam.production_method,
        "ingredients": fam.ingredients,
        "description": fam.description,
        "is_published": fam.is_published,
        "is_concept": fam.is_concept,
        "supporting_documents": fam.supporting_documents or {},
        "primary_image": (fam.supporting_documents or {}).get("primary_image"),
        "media": (fam.supporting_documents or {}).get("media", []),
        "created_at": fam.created_at.isoformat() if fam.created_at else None,
        "updated_at": fam.updated_at.isoformat() if fam.updated_at else None,
        "variants": variants or [],
    }

def serialize(p,inv=None,media=None,vendor=None):return {"id":str(p.id),"vendor_id":str(p.vendor_id),"family_id":str(p.family_id) if p.family_id else None,"sku":p.sku,"title":p.title,"slug":p.slug,"category":p.category.value,"subcategory":p.subcategory,"brand":p.brand,"description":p.description,"short_description":p.short_description,"base_price":str(p.base_price),"compare_at_price":str(p.compare_at_price) if p.compare_at_price is not None else None,"gst_rate":str(p.gst_rate) if p.gst_rate is not None else None,"unit":p.unit,"pack_size":p.pack_size,"weight_grams":p.weight_grams,"publication_status":p.publication_status,"specifications":p.specifications or {},"is_active":p.is_active,"is_featured":p.is_featured,"is_rentable":p.is_rentable,"rental_rate_per_hour":str(p.rental_rate_per_hour) if p.rental_rate_per_hour else None,"rental_rate_per_acre":str(p.rental_rate_per_acre) if p.rental_rate_per_acre else None,"min_order_quantity":p.min_order_quantity,"in_stock":bool(inv and inv.available_quantity-inv.reserved_quantity>0),"available_quantity":max(0,inv.available_quantity-inv.reserved_quantity) if inv else 0,"batch_number":inv.batch_number if inv else None,"manufacture_date":inv.manufacture_date.isoformat() if inv and inv.manufacture_date else None,"expiry_date":inv.expiry_date.isoformat() if inv and inv.expiry_date else None,"media":[{"id":str(x.id),"url":x.url,"media_type":x.media_type.value,"is_primary":x.is_primary,"sort_order":x.sort_order} for x in media or []],"vendor":None if not vendor else {"id":str(vendor.id),"business_name":vendor.business_name,"rating_avg":vendor.rating_avg,"is_verified":vendor.is_verified,"district":vendor.district,"state":vendor.state}}
