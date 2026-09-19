import uuid
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel
from fastapi import APIRouter,Depends,HTTPException,Query,status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user,require_role
from app.models.user import User,UserRole
from app.models.product import Product,ProductCategory,ProductReview,MerchandisingPlacement,ConceptFeedback,ProductInventory
from app.repositories import product_repo,vendor_repo
from app.schemas.product import ProductCreate,ProductUpdate,InventoryUpdate,ProductMediaCreate,ProductFamilyCreate,ProductFamilyUpdate,FamilyVariantCreate,ProductReviewCreate,MerchandisingPlacementCreate,MerchandisingPlacementUpdate,ConceptFeedbackCreate,ProductModerationUpdate,BulkInventoryRequest,BulkInventoryItem
from app.services import product_service
from app.config import settings
from app.services import commerce_taxonomy_service as taxonomy
from app.services.product_policy import is_concept
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
 if p.family_id:
  family = await product_repo.get_family(db, p.family_id)
  if family and family.is_concept:
   result['specifications'] = {**result['specifications'], 'concept': True, 'listing_status': 'concept'}
   result['in_stock'] = False
 if settings.COMMERCE_TAXONOMY_ENABLED:
  tax_meta = (await taxonomy.product_metadata(db,[p.id])).get(str(p.id))
  result['taxonomy'] = tax_meta
  if tax_meta:
   result['category_id'] = tax_meta.get('category_id')
   result['category_name'] = tax_meta.get('category_name')
   result['department_name'] = tax_meta.get('department_name')
 return result


async def serialize_placement(db:AsyncSession,row:MerchandisingPlacement) -> dict:
 product=await product_repo.get(db,row.product_id)
 return {
  "id":str(row.id),
  "product_id":str(row.product_id),
  "placement_type":row.placement_type,
  "headline":row.headline,
  "subheadline":row.subheadline,
  "badge":row.badge,
  "starts_at":row.starts_at.isoformat() + "Z" if row.starts_at else None,
  "ends_at":row.ends_at.isoformat() + "Z" if row.ends_at else None,
  "priority":row.priority,
  "is_active":row.is_active,
  "product":await enrich(db,product) if product else None,
 }


@router.get("/marketplace/merchandising/placements")
async def storefront_placements(db:AsyncSession=Depends(get_db)):
 now=datetime.utcnow()
 rows=list((await db.execute(
  select(MerchandisingPlacement)
  .where(MerchandisingPlacement.is_active.is_(True))
  .order_by(MerchandisingPlacement.priority.desc(),MerchandisingPlacement.created_at.desc())
 )).scalars())
 visible=[]
 for row in rows:
  if row.starts_at and row.starts_at > now: continue
  if row.ends_at and row.ends_at <= now: continue
  product=await product_repo.get(db,row.product_id)
  if not product or not product.is_active or product.publication_status == "draft": continue
  visible.append(await serialize_placement(db,row))
 return {"success":True,"data":visible,"total":len(visible),"message":"Storefront placements"}


@router.get("/admin/marketplace/merchandising/placements")
async def admin_storefront_placements(current_user:User=Depends(require_role(UserRole.admin,UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 rows=list((await db.execute(
  select(MerchandisingPlacement)
  .order_by(MerchandisingPlacement.created_at.desc())
 )).scalars())
 return {"success":True,"data":[await serialize_placement(db,row) for row in rows],"total":len(rows),"message":"Admin storefront placements"}


@router.post("/admin/marketplace/merchandising/placements",status_code=status.HTTP_201_CREATED)
async def create_storefront_placement(data:MerchandisingPlacementCreate,current_user:User=Depends(require_role(UserRole.admin,UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 product=await product_repo.get(db,data.product_id)
 if not product: raise HTTPException(404,"Product not found")
 row=MerchandisingPlacement(**data.model_dump(),created_by_user_id=current_user.id)
 db.add(row)
 await db.flush()
 return {"success":True,"data":await serialize_placement(db,row),"message":"Storefront placement created"}


@router.put("/admin/marketplace/merchandising/placements/{placement_id}")
async def update_storefront_placement(placement_id:str,data:MerchandisingPlacementUpdate,current_user:User=Depends(require_role(UserRole.admin,UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 row=(await db.execute(select(MerchandisingPlacement).where(MerchandisingPlacement.id==uid(placement_id,"placement")))).scalar_one_or_none()
 if not row: raise HTTPException(404,"Storefront placement not found")
 changes=data.model_dump(exclude_unset=True)
 starts_at=changes.get("starts_at",row.starts_at)
 ends_at=changes.get("ends_at",row.ends_at)
 if starts_at and ends_at and ends_at <= starts_at: raise HTTPException(422,"ends_at must be after starts_at")
 for key,value in changes.items(): setattr(row,key,value)
 await db.flush()
 return {"success":True,"data":await serialize_placement(db,row),"message":"Storefront placement updated"}


@router.post("/marketplace/concepts/{concept_key}/feedback",status_code=status.HTTP_201_CREATED)
async def create_concept_feedback(concept_key:str,data:ConceptFeedbackCreate,db:AsyncSession=Depends(get_db)):
 key=concept_key.strip().lower()
 if len(key)<3 or len(key)>120 or any(char not in "abcdefghijklmnopqrstuvwxyz0123456789-_" for char in key):
  raise HTTPException(422,"Invalid concept key")
 row=ConceptFeedback(
  concept_key=key,
  concept_title=data.concept_title.strip(),
  visitor_name=data.visitor_name.strip(),
  email=data.email.strip().lower() if data.email else None,
  phone=data.phone.strip() if data.phone else None,
  message=data.message.strip() if data.message else None,
  wants_updates=data.wants_updates,
 )
 db.add(row)
 await db.flush()
 return {"success":True,"data":{"id":str(row.id)},"message":"Concept feedback saved"}


@router.get("/admin/marketplace/concept-feedback")
async def admin_concept_feedback(current_user:User=Depends(require_role(UserRole.admin,UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 rows=list((await db.execute(
  select(ConceptFeedback).order_by(ConceptFeedback.created_at.desc()).limit(500)
 )).scalars())
 return {"success":True,"data":[{
  "id":str(row.id),"concept_key":row.concept_key,"concept_title":row.concept_title,
  "visitor_name":row.visitor_name,"email":row.email,"phone":row.phone,
  "message":row.message,"wants_updates":row.wants_updates,
  "created_at":row.created_at.isoformat(),
 } for row in rows],"total":len(rows),"message":"Concept feedback"}
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
 seller = await vendor_repo.get_by_id(db, p.vendor_id)
 if not seller or not seller.is_active: raise HTTPException(404,"Product not found")
 if p.family_id:
  family = await product_repo.get_family(db, p.family_id)
  if not family or not family.is_published: raise HTTPException(404,"Product not found")
 return {"success":True,"data":await enrich(db,p),"message":"Product details"}


class ReviewModerationUpdate(BaseModel):
    is_approved: bool
    rejection_reason: str | None = None

class VendorReviewReply(BaseModel):
    reply: str

def serialize_review(review: ProductReview, product_title: str | None = None) -> dict:
 return {
  "id": str(review.id),
  "product_id": str(review.product_id),
  "product_title": product_title,
  "author_name": review.author_name,
  "rating": review.rating,
  "headline": review.headline,
  "content": review.content,
  "source_label": review.source_label,
  "is_seeded": review.is_seeded,
  "is_approved": review.is_approved,
  "rejection_reason": getattr(review, "rejection_reason", None),
  "vendor_reply": getattr(review, "vendor_reply", None),
  "vendor_replied_at": review.vendor_replied_at.isoformat() if getattr(review, "vendor_replied_at", None) else None,
  "created_at": review.created_at.isoformat() if review.created_at else None,
 }


@router.get("/marketplace/products/{product_id}/reviews")
async def product_reviews(product_id:str,db:AsyncSession=Depends(get_db)):
 product_uuid=uid(product_id,"product")
 product=await product_repo.get(db,product_uuid)
 if not product or not product.is_active or product.publication_status == "draft":
  raise HTTPException(404,"Product not found")
 rows=list((await db.execute(
  select(ProductReview)
  .where(ProductReview.product_id == product_uuid, ProductReview.is_approved.is_(True))
  .order_by(ProductReview.created_at.desc())
  .limit(100)
 )).scalars())
 return {"success":True,"data":[serialize_review(row) for row in rows],"total":len(rows),"message":"Product feedback"}


@router.post("/marketplace/products/{product_id}/reviews",status_code=status.HTTP_201_CREATED)
async def create_product_review(product_id:str,data:ProductReviewCreate,db:AsyncSession=Depends(get_db)):
 product_uuid=uid(product_id,"product")
 product=(await db.execute(select(Product).where(Product.id == product_uuid,Product.is_active.is_(True)))).scalar_one_or_none()
 if not product or product.publication_status == "draft":
  raise HTTPException(404,"Product not found")
 if is_concept(product):
  raise HTTPException(422,"Use concept feedback instead of a product review")
 review=ProductReview(
  product_id=product_uuid,
  author_name=data.author_name.strip(),
  rating=data.rating,
  headline=data.headline.strip(),
  content=data.content.strip(),
  source_label="Visitor feedback",
  is_seeded=False,
  is_approved=True,
 )
 db.add(review)
 await db.flush()
 return {"success":True,"data":serialize_review(review),"message":"Feedback saved"}


@router.get("/admin/marketplace/reviews")
async def admin_marketplace_reviews(status_filter: str | None = None, current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
 query = select(ProductReview, Product.title).outerjoin(Product, Product.id == ProductReview.product_id)
 if status_filter == "approved":
  query = query.where(ProductReview.is_approved.is_(True))
 elif status_filter == "rejected":
  query = query.where(ProductReview.is_approved.is_(False))
 rows = (await db.execute(query.order_by(ProductReview.created_at.desc()).limit(200))).all()
 return {
  "success": True,
  "data": [serialize_review(r, title) for r, title in rows],
  "total": len(rows),
  "message": "All product reviews",
 }


@router.patch("/admin/marketplace/reviews/{review_id}/moderation")
async def moderate_review(review_id: str, data: ReviewModerationUpdate, current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
 r_uuid = uid(review_id, "review")
 review = await db.get(ProductReview, r_uuid)
 if not review:
  raise HTTPException(404, "Review not found")
 review.is_approved = data.is_approved
 review.rejection_reason = data.rejection_reason if not data.is_approved else None
 await db.flush()
 return {"success": True, "data": serialize_review(review), "message": f"Review {'approved' if data.is_approved else 'rejected'}"}


@router.post("/vendor/products/reviews/{review_id}/reply")
async def vendor_reply_review(review_id: str, data: VendorReviewReply, current_user: User = Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
 r_uuid = uid(review_id, "review")
 review = await db.get(ProductReview, r_uuid)
 if not review:
  raise HTTPException(404, "Review not found")
 review.vendor_reply = data.reply.strip()
 review.vendor_replied_at = datetime.utcnow()
 await db.flush()
 return {"success": True, "data": serialize_review(review), "message": "Vendor reply posted"}


@router.get("/vendor/products/reviews")
async def vendor_products_reviews(status_filter: str | None = None, current_user: User = Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)), db: AsyncSession = Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 v_id = None if is_admin else (await vendor(db, current_user)).id
 query = select(ProductReview, Product.title).join(Product, Product.id == ProductReview.product_id)
 if v_id:
  query = query.where(Product.vendor_id == v_id)
 if status_filter == "unreplied":
  query = query.where(ProductReview.vendor_reply.is_(None))
 elif status_filter == "replied":
  query = query.where(ProductReview.vendor_reply.is_not(None))
 rows = (await db.execute(query.order_by(ProductReview.created_at.desc()).limit(200))).all()
 return {
  "success": True,
  "data": [serialize_review(r, title) for r, title in rows],
  "total": len(rows),
  "message": "Vendor product reviews",
 }
@router.get("/admin/marketplace/vendors")
async def marketplace_vendors(current_user:User=Depends(require_role(UserRole.admin, UserRole.super_admin)), db:AsyncSession=Depends(get_db)):
 vendors, total = await vendor_repo.list_all(db, limit=100)
 return {"success": True, "data": [{"id": str(v.id), "business_name": v.business_name, "is_active": v.is_active} for v in vendors if v.is_active], "total": total, "message": "Active marketplace vendors"}
@router.get("/marketplace/vendors/{vendor_id}")
async def public_vendor_storefront(vendor_id: str, db: AsyncSession = Depends(get_db)):
 v_uid = uid(vendor_id, "vendor")
 v = await vendor_repo.get_by_id(db, v_uid)
 if not v or not v.is_active:
  raise HTTPException(404, "Vendor storefront not found")
 prod_count = (await db.execute(
  select(func.count(Product.id)).where(
   Product.vendor_id == v.id,
   Product.is_active.is_(True),
   Product.publication_status == "published"
  )
 )).scalar() or 0
 return {
  "success": True,
  "data": {
   "id": str(v.id),
   "business_name": v.business_name,
   "vendor_type": v.vendor_type.value if hasattr(v.vendor_type, "value") else str(v.vendor_type),
   "description": v.description or "Trusted agricultural & dairy producer on Milterra.",
   "logo_url": getattr(v, "logo_url", None),
   "banner_url": getattr(v, "banner_url", None),
   "support_phone": getattr(v, "support_phone", None),
   "support_email": getattr(v, "support_email", None),
   "return_policy": getattr(v, "return_policy", None),
   "district": v.district or "Regional Hub",
   "state": v.state or "India",
   "rating_avg": float(v.rating_avg or 4.8),
   "total_orders": int(v.total_orders or 0),
   "is_verified": bool(v.is_verified),
   "fssai_license_number": v.license_number,
   "gst_number": v.gst_number,
   "service_areas": v.service_areas or [],
   "products_services": v.products_services or [],
   "total_products": prod_count,
  },
  "message": "Vendor storefront details",
 }
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
 p=await product_service.create(db,v.id,data,is_admin);return {"success":True,"data":await enrich(db,p),"message":"Product created"}
@router.get("/vendor/products")
async def vendor_products(current_user:User=Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)),db:AsyncSession=Depends(get_db)):
 is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
 if is_admin:
  items = (await db.execute(select(Product).order_by(Product.title, Product.id))).scalars().all()
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


@router.put("/admin/products/{product_id}/moderation")
async def admin_moderate_product(
    product_id: str,
    data: ProductModerationUpdate,
    current_user: User = Depends(require_role(UserRole.admin, UserRole.super_admin)),
    db: AsyncSession = Depends(get_db)
):
    p = await product_repo.get(db, uid(product_id, "product"))
    if not p:
        raise HTTPException(404, "Product not found")

    p.publication_status = data.publication_status
    if data.is_active is not None:
        p.is_active = data.is_active
    if data.is_featured is not None:
        p.is_featured = data.is_featured

    specs = dict(p.specifications or {})
    if data.rejection_reason:
        specs["rejection_reason"] = data.rejection_reason
    specs["moderated_at"] = datetime.utcnow().isoformat()
    specs["moderated_by"] = str(current_user.id)
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

    await db.flush()
    return {"success": True, "data": await enrich(db, p), "message": f"Product status updated to {data.publication_status}"}


@router.post("/vendor/products/bulk-inventory")
async def bulk_inventory_update(
    data: BulkInventoryRequest,
    current_user: User = Depends(require_role(UserRole.vendor, UserRole.admin, UserRole.super_admin)),
    db: AsyncSession = Depends(get_db)
):
    is_admin = current_user.role in (UserRole.admin, UserRole.super_admin)
    v = None if is_admin else await vendor(db, current_user)
    updated_count = 0
    results = []

    for item in data.items:
        p = (await db.execute(select(Product).where(Product.id == item.product_id).with_for_update())).scalar_one_or_none()
        if not p:
            continue
        if not is_admin and p.vendor_id != v.id:
            continue

        if item.base_price is not None:
            p.base_price = item.base_price
        if item.compare_at_price is not None:
            p.compare_at_price = item.compare_at_price
        if item.is_active is not None:
            p.is_active = item.is_active

        inv = (await db.execute(select(ProductInventory).where(ProductInventory.product_id == p.id).with_for_update())).scalar_one_or_none()
        if not inv:
            inv = ProductInventory(product_id=p.id, available_quantity=0, reserved_quantity=0)
            db.add(inv)

        if item.available_quantity is not None:
            inv.available_quantity = max(inv.reserved_quantity, item.available_quantity)
        elif item.stock_delta is not None:
            inv.available_quantity = max(inv.reserved_quantity, inv.available_quantity + item.stock_delta)

        results.append({
            "product_id": str(p.id),
            "title": p.title,
            "base_price": str(p.base_price),
            "compare_at_price": str(p.compare_at_price) if p.compare_at_price else None,
            "available_quantity": inv.available_quantity,
            "reserved_quantity": inv.reserved_quantity,
            "is_active": p.is_active,
        })
        updated_count += 1

    await db.flush()
    return {
        "success": True,
        "data": results,
        "updated_count": updated_count,
        "message": f"Successfully updated {updated_count} products",
    }

