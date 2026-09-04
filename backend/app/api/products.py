import uuid
from decimal import Decimal
from fastapi import APIRouter,Depends,HTTPException,Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user,require_role
from app.models.user import User,UserRole
from app.repositories import product_repo,vendor_repo
from app.schemas.product import ProductCreate,ProductUpdate,InventoryUpdate,ProductMediaCreate
from app.services import product_service
router=APIRouter(tags=["products"])
def uid(value:str,label:str):
 try:return uuid.UUID(value)
 except ValueError:raise HTTPException(400,f"Invalid {label} UUID")
async def vendor(db,user):
 v=await vendor_repo.get_by_user_id(db,user.id)
 if not v:raise HTTPException(404,"Vendor profile not found")
 if not v.is_active:raise HTTPException(403,"Vendor profile is inactive")
 return v
async def enrich(db,p):return product_service.serialize(p,await product_repo.inventory(db,p.id),await product_repo.media(db,p.id),await vendor_repo.get_by_id(db,p.vendor_id))
@router.get("/marketplace/products")
async def products(category:str|None=None,subcategory:str|None=None,brand:str|None=None,query:str|None=None,min_price:Decimal|None=Query(None,ge=0),max_price:Decimal|None=Query(None,ge=0),vendor_id:str|None=None,in_stock:bool|None=None,is_rentable:bool|None=None,sort_by:str="newest",page:int=Query(1,ge=1),per_page:int=Query(20,ge=1,le=100),db:AsyncSession=Depends(get_db)):
 items,total=await product_repo.search(db,{"category":category,"brand":brand,"query":query,"min_price":min_price,"max_price":max_price,"vendor_id":uid(vendor_id,"vendor") if vendor_id else None,"sort_by":sort_by},page,per_page)
 if subcategory:items=[x for x in items if x.subcategory==subcategory]
 if is_rentable is not None:items=[x for x in items if x.is_rentable==is_rentable]
 data=[await enrich(db,x) for x in items]
 if in_stock is not None:data=[x for x in data if x["in_stock"]==in_stock]
 return {"success":True,"data":data,"total":total,"page":page,"per_page":per_page,"message":"Products"}
@router.get("/marketplace/products/{product_id}")
async def product_detail(product_id:str,db:AsyncSession=Depends(get_db)):
 p=await product_repo.get(db,uid(product_id,"product"))
 if not p or not p.is_active:raise HTTPException(404,"Product not found")
 return {"success":True,"data":await enrich(db,p),"message":"Product details"}
@router.post("/vendor/products",status_code=201)
async def create_product(data:ProductCreate,current_user:User=Depends(require_role(UserRole.vendor)),db:AsyncSession=Depends(get_db)):
 p=await product_service.create(db,(await vendor(db,current_user)).id,data);return {"success":True,"data":await enrich(db,p),"message":"Product created"}
@router.get("/vendor/products")
async def vendor_products(current_user:User=Depends(require_role(UserRole.vendor)),db:AsyncSession=Depends(get_db)):
 v=await vendor(db,current_user);return {"success":True,"data":[await enrich(db,p) for p in await product_repo.list_vendor(db,v.id)],"message":"Vendor products"}
@router.get("/vendor/products/{product_id}")
async def vendor_product(product_id:str,current_user:User=Depends(require_role(UserRole.vendor)),db:AsyncSession=Depends(get_db)):
 v=await vendor(db,current_user);p=await product_repo.get(db,uid(product_id,"product"))
 if not p or p.vendor_id!=v.id:raise HTTPException(404,"Product not found")
 return {"success":True,"data":await enrich(db,p),"message":"Vendor product"}
@router.put("/vendor/products/{product_id}")
async def update_product(product_id:str,data:ProductUpdate,current_user:User=Depends(require_role(UserRole.vendor)),db:AsyncSession=Depends(get_db)):
 v=await vendor(db,current_user);p=await product_repo.get(db,uid(product_id,"product"));
 if not p:raise HTTPException(404,"Product not found")
 p=await product_service.update(db,p,v.id,data);return {"success":True,"data":await enrich(db,p),"message":"Product updated"}
@router.delete("/vendor/products/{product_id}")
async def deactivate_product(product_id:str,current_user:User=Depends(require_role(UserRole.vendor)),db:AsyncSession=Depends(get_db)):
 v=await vendor(db,current_user);p=await product_repo.get(db,uid(product_id,"product"));
 if not p:raise HTTPException(404,"Product not found")
 await product_service.update(db,p,v.id,ProductUpdate(is_active=False));return {"success":True,"data":{},"message":"Product deactivated"}
@router.put("/vendor/products/{product_id}/inventory")
async def inventory(product_id:str,data:InventoryUpdate,current_user:User=Depends(require_role(UserRole.vendor)),db:AsyncSession=Depends(get_db)):
 v=await vendor(db,current_user);p=await product_repo.get(db,uid(product_id,"product"));
 if not p:raise HTTPException(404,"Product not found")
 x=await product_service.update_inventory(db,p,v.id,data);return {"success":True,"data":{"available_quantity":x.available_quantity,"reserved_quantity":x.reserved_quantity,"available_to_sell":x.available_quantity-x.reserved_quantity},"message":"Inventory updated"}
@router.post("/vendor/products/{product_id}/media",status_code=201)
async def media(product_id:str,data:ProductMediaCreate,current_user:User=Depends(require_role(UserRole.vendor)),db:AsyncSession=Depends(get_db)):
 v=await vendor(db,current_user);p=await product_repo.get(db,uid(product_id,"product"));
 if not p:raise HTTPException(404,"Product not found")
 x=await product_service.add_media(db,p,v.id,data);return {"success":True,"data":{"id":str(x.id),"url":x.url},"message":"Media added"}
