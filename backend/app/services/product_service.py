import re,uuid
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.product import Product,ProductInventory,ProductMedia
from app.repositories import product_repo
from app.schemas.product import ProductCreate,ProductUpdate,InventoryUpdate,ProductMediaCreate
def slugify(value:str)->str:return re.sub(r"[^a-z0-9]+","-",value.lower()).strip("-")
async def create(db:AsyncSession,vendor_id:uuid.UUID,data:ProductCreate):
 if await product_repo.sku_exists(db,data.sku):raise HTTPException(409,"SKU already exists")
 p=Product(vendor_id=vendor_id,slug=slugify(data.title),**data.model_dump());db.add(p);await db.flush();db.add(ProductInventory(product_id=p.id));await db.flush();return p
async def update(db:AsyncSession,p:Product,vendor_id:uuid.UUID,data:ProductUpdate):
 if p.vendor_id!=vendor_id:raise HTTPException(403,"You can manage only your products")
 for k,v in data.model_dump(exclude_unset=True).items():setattr(p,k,v)
 if data.title:p.slug=slugify(data.title)
 await db.flush();return p
async def update_inventory(db:AsyncSession,p:Product,vendor_id:uuid.UUID,data:InventoryUpdate):
 if p.vendor_id!=vendor_id:raise HTTPException(403,"You can manage only your products")
 if data.reserved_quantity>data.available_quantity:raise HTTPException(422,"Reserved quantity cannot exceed available quantity")
 inv=await product_repo.inventory(db,p.id)
 if not inv:inv=ProductInventory(product_id=p.id);db.add(inv)
 for k,v in data.model_dump().items():setattr(inv,k,v)
 await db.flush();return inv
async def add_media(db:AsyncSession,p:Product,vendor_id:uuid.UUID,data:ProductMediaCreate):
 if p.vendor_id!=vendor_id:raise HTTPException(403,"You can manage only your products")
 if data.is_primary:
  for x in await product_repo.media(db,p.id):x.is_primary=False
 x=ProductMedia(product_id=p.id,**data.model_dump());db.add(x);await db.flush();return x
def serialize(p,inv=None,media=None,vendor=None):return {"id":str(p.id),"vendor_id":str(p.vendor_id),"sku":p.sku,"title":p.title,"slug":p.slug,"category":p.category.value,"subcategory":p.subcategory,"brand":p.brand,"description":p.description,"short_description":p.short_description,"base_price":str(p.base_price),"gst_rate":str(p.gst_rate) if p.gst_rate is not None else None,"unit":p.unit,"pack_size":p.pack_size,"specifications":p.specifications or {},"is_active":p.is_active,"is_featured":p.is_featured,"is_rentable":p.is_rentable,"rental_rate_per_hour":str(p.rental_rate_per_hour) if p.rental_rate_per_hour else None,"rental_rate_per_acre":str(p.rental_rate_per_acre) if p.rental_rate_per_acre else None,"min_order_quantity":p.min_order_quantity,"in_stock":bool(inv and inv.available_quantity-inv.reserved_quantity>0),"available_quantity":max(0,inv.available_quantity-inv.reserved_quantity) if inv else 0,"media":[{"id":str(x.id),"url":x.url,"media_type":x.media_type.value,"is_primary":x.is_primary,"sort_order":x.sort_order} for x in media or []],"vendor":None if not vendor else {"id":str(vendor.id),"business_name":vendor.business_name,"rating_avg":vendor.rating_avg,"is_verified":vendor.is_verified,"district":vendor.district,"state":vendor.state}}
