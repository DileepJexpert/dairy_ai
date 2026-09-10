from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user, require_role
from app.models.user import UserRole
from app.models.product import Product
from app.models.commerce_taxonomy import ProductClassification
from app.schemas.commerce_taxonomy import ClassificationUpdate, TaxonomyCreate, TaxonomyUpdate
from app.services import commerce_taxonomy_service as service

router = APIRouter(tags=["commerce taxonomy"])
# Compatibility bridge: only existing database-backed admin roles are granted
# taxonomy management in this slice. Multi-capability membership is separate work.
commerce_admin = require_role(UserRole.admin, UserRole.super_admin)


def require_enabled():
    if not settings.COMMERCE_TAXONOMY_ENABLED:
        raise HTTPException(503, "Commerce categories are not enabled. Follow the local database rebuild guide before enabling them.")


@router.get("/marketplace/taxonomy")
async def public_taxonomy(db: AsyncSession = Depends(get_db)):
    if not settings.COMMERCE_TAXONOMY_ENABLED:
        return {"success": True, "enabled": False, "data": []}
    return {"success": True, "enabled": True, "data": await service.public_nodes(db)}


@router.get("/commerce/access")
async def access(user=Depends(get_current_user)):
    return {"success": True, "data": {"can_manage_taxonomy": user.role in (UserRole.admin, UserRole.super_admin), "taxonomy_enabled": settings.COMMERCE_TAXONOMY_ENABLED}}


@router.get("/admin/commerce/taxonomy", dependencies=[Depends(require_enabled)])
async def list_nodes(user=Depends(commerce_admin), db: AsyncSession = Depends(get_db)):
    return {"success": True, "data": [service.serialize(n) for n in await service.nodes(db)]}


@router.post("/admin/commerce/taxonomy", status_code=201, dependencies=[Depends(require_enabled)])
async def create_node(data: TaxonomyCreate, user=Depends(commerce_admin), db: AsyncSession = Depends(get_db)):
    return {"success": True, "data": await service.save_node(db, user, data)}


@router.put("/admin/commerce/taxonomy/{node_id}", dependencies=[Depends(require_enabled)])
async def update_node(node_id: UUID, data: TaxonomyUpdate, user=Depends(commerce_admin), db: AsyncSession = Depends(get_db)):
    return {"success": True, "data": await service.save_node(db, user, data, node_id)}


@router.get("/admin/commerce/catalogue", dependencies=[Depends(require_enabled)])
async def catalogue(query: str = Query("", max_length=100), page: int = Query(1, ge=1), user=Depends(commerce_admin), db: AsyncSession = Depends(get_db)):
    q = select(Product)
    if query.strip():
        q = q.where(Product.title.ilike(f"%{query.strip()}%") | Product.sku.ilike(f"%{query.strip()}%"))
    total = await db.scalar(select(func.count()).select_from(q.subquery()))
    products = list((await db.scalars(q.order_by(Product.title, Product.id).offset((page - 1) * 20).limit(20))).all())
    assignments = {a.product_id: a for a in (await db.scalars(select(ProductClassification).where(ProductClassification.product_id.in_([p.id for p in products])))).all()}
    return {"success": True, "total": total, "page": page, "per_page": 20, "data": [{"id": str(p.id), "title": p.title, "sku": p.sku, "is_active": p.is_active, "category_id": str(assignments[p.id].category_id) if p.id in assignments else None, "classification_version": assignments[p.id].version if p.id in assignments else 0} for p in products]}


@router.put("/admin/commerce/catalogue/{product_id}/category", dependencies=[Depends(require_enabled)])
async def classify(product_id: UUID, data: ClassificationUpdate, user=Depends(commerce_admin), db: AsyncSession = Depends(get_db)):
    return {"success": True, "data": await service.assign_product(db, user, product_id, data)}
