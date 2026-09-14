"""Product lifecycle policy shared by cart and checkout, independent of stock."""


def is_concept(product) -> bool:
    metadata = product.specifications or {}
    status = str(metadata.get("listing_status", "")).lower().replace("_", " ")
    return (metadata.get("concept") is True or "concept" in status
            or "development" in status or status == "coming soon")


async def purchase_enabled(db, product) -> bool:
    from app.models.product import ProductFamily
    from app.models.vendor import Vendor
    if not product or not product.is_active or product.publication_status != "published" or is_concept(product):
        return False
    vendor = await db.get(Vendor, product.vendor_id)
    if not vendor or not vendor.is_active:
        return False
    if product.family_id:
        family = await db.get(ProductFamily, product.family_id)
        if not family or not family.is_published or family.is_concept:
            return False
    return True
