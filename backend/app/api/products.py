import uuid
from decimal import Decimal
from fastapi import APIRouter,Depends,HTTPException,Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user,require_role
from app.models.user import User,UserRole
from app.models.product import ProductCategory
from app.repositories import product_repo,vendor_repo
from app.schemas.product import ProductCreate,ProductUpdate,InventoryUpdate,ProductMediaCreate,ProductFamilyCreate,ProductFamilyUpdate,FamilyVariantCreate
from app.services import product_service
from app.config import settings
from app.services import commerce_taxonomy_service as taxonomy
router=APIRouter(tags=["products"])
def uid(value:str,label:str):
 try:return uuid.UUID(value)
 except ValueError:raise HTTPException(400,f"Invalid {label} UUID")
async def vendor(db,user):
 v=await vendor_repo.get_by_user_id(db,user.id)
 if not v:raise HTTPException(404,"Vendor profile not found")
 if not v.is_active:raise HTTPException(403,"Vendor profile is inactive")
 return v
async def enrich(db,p):
 result = product_service.serialize(p,await product_repo.inventory(db,p.id),await product_repo.media(db,p.id),await vendor_repo.get_by_id(db,p.vendor_id))
 if settings.COMMERCE_TAXONOMY_ENABLED:
  result['taxonomy'] = (await taxonomy.product_metadata(db,[p.id])).get(str(p.id))
 return result
@router.get("/marketplace/products")
async def products(category:str|None=None,subcategory:str|None=None,brand:str|None=None,sku:str|None=None,query:str|None=None,family_id:str|None=None,min_price:Decimal|None=Query(None,ge=0),max_price:Decimal|None=Query(None,ge=0),vendor_id:str|None=None,in_stock:bool|None=None,is_rentable:bool|None=None,sort_by:str="newest",page:int=Query(1,ge=1),per_page:int=Query(20,ge=1,le=100),taxonomy_id:uuid.UUID|None=None,db:AsyncSession=Depends(get_db)):
 product_category = None
 if category:
  try:
   product_category = ProductCategory(category)
  except ValueError as exc:
   raise HTTPException(422, "Invalid product category") from exc
 if taxonomy_id and not settings.COMMERCE_TAXONOMY_ENABLED:
  raise HTTPException(503,"Commerce categories are not enabled")
 category_ids = None
 if taxonomy_id:
  public = await taxonomy.public_nodes(db)
  if not any(n['id'] == str(taxonomy_id) for n in public):
   raise HTTPException(404,"Category not found")
  category_ids = {str(taxonomy_id)}
  for _ in public:
   category_ids.update(n['id'] for n in public if n['parent_id'] in category_ids)
  category_ids = [uuid.UUID(x) for x in category_ids]
 items,total=await product_repo.search(db,{"category":product_category,"brand":brand,"sku":sku,"query":query,"family_id":uid(family_id,"family") if family_id else None,"min_price":min_price,"max_price":max_price,"vendor_id":uid(vendor_id,"vendor") if vendor_id else None,"sort_by":sort_by,"taxonomy_ids":category_ids,"subcategory":subcategory,"in_stock":in_stock,"is_rentable":is_rentable},page,per_page)
 data=[await enrich(db,x) for x in items]
 return {"success":True,"data":data,"total":total,"page":page,"per_page":per_page,"message":"Products"}
@router.get("/marketplace/families")
async def marketplace_families(collection:str|None=None, department:str|None=None, db:AsyncSession=Depends(get_db)):
 families = await product_repo.list_families(db, is_published=True, collection=collection, department=department)
 res = []
 for fam in families:
  variants = [] if fam.is_concept else await product_repo.list_family_variants(db, fam.id, only_published=True)
  var_data = [await enrich(db, v) for v in variants]
  res.append(product_service.serialize_family(fam, var_data))
 return {"success":True,"data":res,"message":"Product families"}
@router.get("/marketplace/families/{family_id_or_slug}")
async def marketplace_family_detail(family_id_or_slug:str, db:AsyncSession=Depends(get_db)):
 fam = None
 try:
  fam = await product_repo.get_family(db, uuid.UUID(family_id_or_slug))
 except ValueError:
  fam = await product_repo.get_family_by_slug(db, family_id_or_slug)
 if not fam or not fam.is_published:
  raise HTTPException(404, "Product family not found")
 variants = [] if fam.is_concept else await product_repo.list_family_variants(db, fam.id, only_published=True)
 var_data = [await enrich(db, v) for v in variants]
 return {"success":True,"data":product_service.serialize_family(fam, var_data),"message":"Product family details"}
@router.get("/marketplace/products/{product_id}")
async def product_detail(product_id:str,db:AsyncSession=Depends(get_db)):
 p=await product_repo.get(db,uid(product_id,"product"))
 if not p or not p.is_active or p.publication_status == "draft":raise HTTPException(404,"Product not found")
 if p.family_id:
  family = await product_repo.get_family(db, p.family_id)
  if not family or not family.is_published: raise HTTPException(404,"Product not found")
 return {"success":True,"data":await enrich(db,p),"message":"Product details"}
@router.get("/admin/marketplace/vendors")
async def marketplace_vendors(current_user:User=Depends(require_role(UserRole.admin, UserRole.super_admin)), db:AsyncSession=Depends(get_db)):
 vendors, total = await vendor_repo.list_all(db, limit=100)
 return {"success": True, "data": [{"id": str(v.id), "business_name": v.business_name, "is_active": v.is_active} for v in vendors if v.is_active], "total": total, "message": "Active marketplace vendors"}
@router.get("/vendor/families")
async def vendor_families(current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)), db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 v_id = None if is_admin else (await vendor(db, current_user)).id
 families = await product_repo.list_families(db, vendor_id=v_id)
 res = []
 for fam in families:
  variants = await product_repo.list_family_variants(db, fam.id, only_published=False)
  var_data = [await enrich(db, v) for v in variants]
  res.append(product_service.serialize_family(fam, var_data))
 return {"success":True,"data":res,"message":"Vendor product families"}
@router.post("/vendor/families", status_code=201)
async def create_family(data:ProductFamilyCreate, current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)), db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 v = (await vendor(db, current_user)) if not is_admin else await vendor_repo.get_by_id(db, data.vendor_id) if data.vendor_id else None
 if not v or not v.is_active: raise HTTPException(422, "Select an active vendor before creating a family")
 fam = await product_service.create_family(db, v.id, data)
 return {"success":True,"data":product_service.serialize_family(fam, []),"message":"Product family created"}
@router.get("/vendor/families/{family_id}")
async def vendor_family_detail(family_id:str, current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)), db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 fam = await product_repo.get_family(db, uid(family_id, "family"))
 if not fam: raise HTTPException(404, "Product family not found")
 if not is_admin:
  v = await vendor(db, current_user)
  if fam.vendor_id != v.id: raise HTTPException(403, "Forbidden")
 variants = await product_repo.list_family_variants(db, fam.id, only_published=False)
 var_data = [await enrich(db, v) for v in variants]
 return {"success":True,"data":product_service.serialize_family(fam, var_data),"message":"Family details"}
@router.put("/vendor/families/{family_id}")
async def update_family(family_id:str, data:ProductFamilyUpdate, current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)), db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 fam = await product_repo.get_family(db, uid(family_id, "family"))
 if not fam: raise HTTPException(404, "Product family not found")
 v_id = fam.vendor_id if is_admin else (await vendor(db, current_user)).id
 fam = await product_service.update_family(db, fam, v_id, is_admin, data)
 variants = await product_repo.list_family_variants(db, fam.id, only_published=False)
 var_data = [await enrich(db, v) for v in variants]
 return {"success":True,"data":product_service.serialize_family(fam, var_data),"message":"Product family updated"}
@router.post("/vendor/families/{family_id}/variants", status_code=201)
async def create_family_variant(family_id:str, data:FamilyVariantCreate, current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)), db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 fam = await product_repo.get_family(db, uid(family_id, "family"))
 if not fam: raise HTTPException(404, "Product family not found")
 v_id = fam.vendor_id if is_admin else (await vendor(db, current_user)).id
 p = await product_service.create_family_variant(db, fam, v_id, is_admin, data)
 return {"success":True,"data":await enrich(db, p),"message":"Variant created"}
@router.post("/vendor/products",status_code=201)
async def create_product(data:ProductCreate,current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 v = (await vendor(db, current_user)) if not is_admin else await vendor_repo.get_by_id(db, data.vendor_id) if data.vendor_id else None
 if not v or not v.is_active: raise HTTPException(422, "Select an active vendor before creating a product")
 p=await product_service.create(db,v.id,data);return {"success":True,"data":await enrich(db,p),"message":"Product created"}
@router.get("/vendor/products")
async def vendor_products(current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 if is_admin:
  items, _ = await product_repo.search(db, {"include_drafts": True}, 1, 100)
  return {"success":True,"data":[await enrich(db,p) for p in items],"message":"Vendor products"}
 v=await vendor(db,current_user);return {"success":True,"data":[await enrich(db,p) for p in await product_repo.list_vendor(db,v.id)],"message":"Vendor products"}
@router.get("/vendor/products/{product_id}")
async def vendor_product(product_id:str,current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 p=await product_repo.get(db,uid(product_id,"product"))
 if not p: raise HTTPException(404,"Product not found")
 if not is_admin:
  v=await vendor(db,current_user)
  if p.vendor_id!=v.id:raise HTTPException(403,"Forbidden")
 return {"success":True,"data":await enrich(db,p),"message":"Vendor product"}
@router.put("/vendor/products/{product_id}")
async def update_product(product_id:str,data:ProductUpdate,current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 p=await product_repo.get(db,uid(product_id,"product"));
 if not p:raise HTTPException(404,"Product not found")
 v_id = p.vendor_id if is_admin else (await vendor(db,current_user)).id
 p=await product_service.update(db,p,v_id,is_admin,data);return {"success":True,"data":await enrich(db,p),"message":"Product updated"}
@router.delete("/vendor/products/{product_id}")
async def deactivate_product(product_id:str,current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 p=await product_repo.get(db,uid(product_id,"product"));
 if not p:raise HTTPException(404,"Product not found")
 v_id = p.vendor_id if is_admin else (await vendor(db,current_user)).id
 await product_service.update(db,p,v_id,is_admin,ProductUpdate(is_active=False));return {"success":True,"data":{},"message":"Product deactivated"}
@router.put("/vendor/products/{product_id}/inventory")
async def inventory(product_id:str,data:InventoryUpdate,current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 p=await product_repo.get(db,uid(product_id,"product"));
 if not p:raise HTTPException(404,"Product not found")
 v_id = p.vendor_id if is_admin else (await vendor(db,current_user)).id
 x=await product_service.update_inventory(db,p,v_id,is_admin,data);return {"success":True,"data":{"available_quantity":x.available_quantity,"reserved_quantity":x.reserved_quantity,"available_to_sell":x.available_quantity-x.reserved_quantity},"message":"Inventory updated"}
@router.post("/vendor/products/{product_id}/media",status_code=201)
async def media(product_id:str,data:ProductMediaCreate,current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 p=await product_repo.get(db,uid(product_id,"product"));
 if not p:raise HTTPException(404,"Product not found")
 v_id = p.vendor_id if is_admin else (await vendor(db,current_user)).id
 x=await product_service.add_media(db,p,v_id,is_admin,data);return {"success":True,"data":{"id":str(x.id),"url":x.url},"message":"Media added"}
