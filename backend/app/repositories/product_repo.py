import uuid
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.product import Product, ProductInventory, ProductMedia
async def get(db:AsyncSession,id:uuid.UUID): return (await db.execute(select(Product).where(Product.id==id))).scalar_one_or_none()
async def sku_exists(db:AsyncSession,sku:str,exclude:uuid.UUID|None=None):
 q=select(Product.id).where(Product.sku==sku)
 if exclude:q=q.where(Product.id!=exclude)
 return (await db.execute(q)).first() is not None
async def list_vendor(db:AsyncSession,vendor_id:uuid.UUID): return list((await db.execute(select(Product).where(Product.vendor_id==vendor_id).order_by(Product.created_at.desc()))).scalars())
async def inventory(db:AsyncSession,product_id:uuid.UUID): return (await db.execute(select(ProductInventory).where(ProductInventory.product_id==product_id))).scalar_one_or_none()
async def media(db:AsyncSession,product_id:uuid.UUID): return list((await db.execute(select(ProductMedia).where(ProductMedia.product_id==product_id).order_by(ProductMedia.is_primary.desc(),ProductMedia.sort_order))).scalars())
async def search(db:AsyncSession,filters:dict,page:int,per_page:int):
 q=select(Product).where(Product.is_active.is_(True))
 if filters.get('category'):q=q.where(Product.category==filters['category'])
 if filters.get('brand'):q=q.where(Product.brand.ilike(f"%{filters['brand']}%"))
 if filters.get('query'):q=q.where(or_(Product.title.ilike(f"%{filters['query']}%"),Product.description.ilike(f"%{filters['query']}%")))
 if filters.get('min_price') is not None:q=q.where(Product.base_price>=filters['min_price'])
 if filters.get('max_price') is not None:q=q.where(Product.base_price<=filters['max_price'])
 if filters.get('vendor_id'):q=q.where(Product.vendor_id==filters['vendor_id'])
 total=(await db.execute(select(func.count()).select_from(q.subquery()))).scalar_one(); order=Product.created_at.desc()
 if filters.get('sort_by')=='price_asc':order=Product.base_price.asc()
 if filters.get('sort_by')=='price_desc':order=Product.base_price.desc()
 if filters.get('sort_by')=='featured':order=Product.is_featured.desc()
 return list((await db.execute(q.order_by(order).offset((page-1)*per_page).limit(per_page))).scalars()),total
