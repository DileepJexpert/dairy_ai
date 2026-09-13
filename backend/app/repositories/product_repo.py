import uuid
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.product import Product, ProductFamily, ProductInventory, ProductMedia
from app.models.commerce_taxonomy import ProductClassification
async def get(db:AsyncSession,id:uuid.UUID): return (await db.execute(select(Product).where(Product.id==id))).scalar_one_or_none()
async def sku_exists(db:AsyncSession,sku:str,exclude:uuid.UUID|None=None):
 q=select(Product.id).where(Product.sku==sku)
 if exclude:q=q.where(Product.id!=exclude)
 return (await db.execute(q)).first() is not None
async def list_vendor(db:AsyncSession,vendor_id:uuid.UUID): return list((await db.execute(select(Product).where(Product.vendor_id==vendor_id).order_by(Product.created_at.desc()))).scalars())
async def inventory(db:AsyncSession,product_id:uuid.UUID): return (await db.execute(select(ProductInventory).where(ProductInventory.product_id==product_id))).scalar_one_or_none()
async def media(db:AsyncSession,product_id:uuid.UUID): return list((await db.execute(select(ProductMedia).where(ProductMedia.product_id==product_id).order_by(ProductMedia.is_primary.desc(),ProductMedia.sort_order))).scalars())

async def get_family(db:AsyncSession, family_id:uuid.UUID) -> ProductFamily | None:
    return (await db.execute(select(ProductFamily).where(ProductFamily.id == family_id))).scalar_one_or_none()

async def get_family_by_slug(db:AsyncSession, slug:str) -> ProductFamily | None:
    return (await db.execute(select(ProductFamily).where(ProductFamily.slug == slug))).scalar_one_or_none()

async def list_families(db:AsyncSession, vendor_id:uuid.UUID|None=None, is_published:bool|None=None, collection:str|None=None, department:str|None=None):
    q = select(ProductFamily)
    if vendor_id:
        q = q.where(ProductFamily.vendor_id == vendor_id)
    if is_published is not None:
        q = q.where(ProductFamily.is_published == is_published)
    if collection:
        q = q.where(ProductFamily.collection.ilike(f"%{collection}%"))
    if department:
        q = q.where(ProductFamily.department.ilike(f"%{department}%"))
    return list((await db.execute(q.order_by(ProductFamily.created_at.asc()))).scalars())

async def list_family_variants(db:AsyncSession, family_id:uuid.UUID, only_published:bool=True) -> list[Product]:
    q = select(Product).where(Product.family_id == family_id, Product.is_active.is_(True))
    if only_published:
        q = q.where(Product.publication_status == 'published')
    return list((await db.execute(q.order_by(Product.base_price.asc()))).scalars())

async def search(db:AsyncSession,filters:dict,page:int,per_page:int):
 q=select(Product).outerjoin(ProductFamily, Product.family_id == ProductFamily.id).where(
     Product.is_active.is_(True),
     or_(Product.family_id.is_(None), ProductFamily.is_published.is_(True)),
 )
 if not filters.get('include_drafts'):
     q=q.where(Product.publication_status != 'draft')
 if filters.get('family_id'):q=q.where(Product.family_id==filters['family_id'])
 if filters.get('category'):q=q.where(Product.category==filters['category'])
 if filters.get('brand'):q=q.where(Product.brand.ilike(f"%{filters['brand']}%"))
 if filters.get('sku'):q=q.where(Product.sku==filters['sku'])
 if filters.get('query'):q=q.where(or_(Product.title.ilike(f"%{filters['query']}%"),Product.description.ilike(f"%{filters['query']}%"),Product.sku.ilike(f"%{filters['query']}%")))
 if filters.get('min_price') is not None:q=q.where(Product.base_price>=filters['min_price'])
 if filters.get('max_price') is not None:q=q.where(Product.base_price<=filters['max_price'])
 if filters.get('vendor_id'):q=q.where(Product.vendor_id==filters['vendor_id'])
 if filters.get('taxonomy_ids') is not None:q=q.where(Product.id.in_(select(ProductClassification.product_id).where(ProductClassification.category_id.in_(filters['taxonomy_ids']))))
 if filters.get('subcategory'):q=q.where(Product.subcategory==filters['subcategory'])
 if filters.get('is_rentable') is not None:q=q.where(Product.is_rentable==filters['is_rentable'])
 if filters.get('in_stock') is not None:
  stocked=select(ProductInventory.product_id).where(ProductInventory.available_quantity-ProductInventory.reserved_quantity>0)
  q=q.where(Product.id.in_(stocked) if filters['in_stock'] else Product.id.not_in(stocked))
 total=(await db.execute(select(func.count()).select_from(q.subquery()))).scalar_one(); order=Product.created_at.desc()
 if filters.get('sort_by')=='price_asc':order=Product.base_price.asc()
 if filters.get('sort_by')=='price_desc':order=Product.base_price.desc()
 if filters.get('sort_by')=='featured':order=Product.is_featured.desc()
 return list((await db.execute(q.order_by(order,Product.id).offset((page-1)*per_page).limit(per_page))).scalars()),total
