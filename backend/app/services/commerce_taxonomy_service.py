"""Tree validation, serialized edits and audit events in the caller's transaction."""
from fastapi import HTTPException
from sqlalchemy import select
from app.models.commerce_taxonomy import CommerceAudit, ProductClassification, TaxonomyLock, TaxonomyNode
from app.models.product import Product


def serialize(node):
    return {"id": str(node.id), "kind": node.kind, "parent_id": str(node.parent_id) if node.parent_id else None,
            "name": node.name, "slug": node.slug, "description": node.description,
            "sort_order": node.sort_order, "is_active": node.is_active, "version": node.version}


async def nodes(db):
    return list((await db.scalars(select(TaxonomyNode).order_by(TaxonomyNode.sort_order, TaxonomyNode.name, TaxonomyNode.id))).all())


def effective_active(node, index):
    seen = set()
    while node is not None:
        if node.id in seen or not node.is_active:
            return False
        seen.add(node.id)
        if node.parent_id is None:
            return node.kind == "department"
        node = index.get(node.parent_id)
    return False


async def public_nodes(db):
    items = await nodes(db)
    index = {n.id: n for n in items}
    return [serialize(n) for n in items if effective_active(n, index)]


async def lock_tree(db):
    # A seeded singleton serializes all hierarchy/classification mutations.
    # Prevents concurrent moves creating a cycle or assignment racing archive.
    lock = await db.scalar(select(TaxonomyLock).where(TaxonomyLock.id == 1).with_for_update())
    if lock is None:
        raise HTTPException(503, "Commerce taxonomy is not initialized. Follow the local database rebuild guide.")


async def save_node(db, actor, data, node_id=None):
    await lock_tree(db)
    items = await nodes(db)
    index = {n.id: n for n in items}
    node = index.get(node_id) if node_id else None
    if node_id and node is None:
        raise HTTPException(404, "Category not found")
    if node and node.version != data.expected_version:
        raise HTTPException(409, "This category changed. Reload before saving.")
    kind = node.kind if node else data.kind
    if any(n.slug == data.slug and n.id != node_id for n in items):
        raise HTTPException(409, "This slug is already in use")
    if kind == "department" and data.parent_id is not None:
        raise HTTPException(422, "Departments cannot have a parent")
    if kind == "category":
        parent = index.get(data.parent_id)
        if not parent:
            raise HTTPException(422, "Choose an existing parent department or category")
        seen = {node_id} if node_id else set()
        cursor = parent
        while cursor:
            if cursor.id in seen:
                raise HTTPException(422, "A category cannot be its own ancestor")
            seen.add(cursor.id)
            cursor = index.get(cursor.parent_id)
        if data.is_active and not effective_active(parent, index):
            raise HTTPException(422, "Activate the parent before publishing this category")
    if node and not data.is_active:
        if any(n.parent_id == node.id and n.is_active for n in items):
            raise HTTPException(409, "Archive or move active child categories first")
        # Protect direct references; archived descendants cannot contain active
        # products through this service, and public reads recheck ancestors.
        in_use = await db.scalar(select(ProductClassification.product_id).join(Product, Product.id == ProductClassification.product_id).where(ProductClassification.category_id == node.id, Product.is_active.is_(True)).limit(1))
        if in_use:
            raise HTTPException(409, "Move active products to another category before archiving")
    before = serialize(node) if node else None
    if node is None:
        node = TaxonomyNode(kind=kind)
        db.add(node)
    for key, value in data.model_dump(exclude={"kind", "expected_version"}).items():
        setattr(node, key, value)
    node.version = (node.version or 0) + 1
    await db.flush()
    db.add(CommerceAudit(actor_id=actor.id, action="taxonomy.update" if before else "taxonomy.create", target_id=node.id, before=before, after=serialize(node)))
    await db.flush()
    return serialize(node)


async def assign_product(db, actor, product_id, data):
    await lock_tree(db)
    product = await db.get(Product, product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    index = {n.id: n for n in await nodes(db)}
    category = index.get(data.category_id)
    if not category or category.kind != "category" or not effective_active(category, index):
        raise HTTPException(422, "Choose an active product category")
    assignment = await db.get(ProductClassification, product_id)
    if data.expected_version != (assignment.version if assignment else 0):
        raise HTTPException(409, "Product classification changed. Reload before saving.")
    before = {"category_id": str(assignment.category_id), "version": assignment.version} if assignment else None
    if assignment is None:
        assignment = ProductClassification(product_id=product_id, category_id=category.id, version=0)
        db.add(assignment)
    assignment.category_id = category.id
    assignment.version += 1
    after = {"product_id": str(product_id), "category_id": str(category.id), "version": assignment.version}
    db.add(CommerceAudit(actor_id=actor.id, action="product.classify", target_id=product_id, before=before, after=after))
    await db.flush()
    return after


async def product_metadata(db, product_ids):
    if not product_ids:
        return {}
    index = {n.id: n for n in await nodes(db)}
    assignments = (await db.scalars(select(ProductClassification).where(ProductClassification.product_id.in_(product_ids)))).all()
    result = {}
    for assignment in assignments:
        node = index.get(assignment.category_id)
        if not node or not effective_active(node, index):
            continue
        department = node
        while department.parent_id:
            department = index[department.parent_id]
        result[str(assignment.product_id)] = {"category_id": str(node.id), "category_name": node.name,
            "department_id": str(department.id), "department_name": department.name,
            "classification_version": assignment.version}
    return result
