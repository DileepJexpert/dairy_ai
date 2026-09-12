"""Product lifecycle policy shared by cart and checkout, independent of stock."""


def is_concept(product) -> bool:
    metadata = product.specifications or {}
    status = str(metadata.get("listing_status", "")).lower().replace("_", " ")
    return (metadata.get("concept") is True or "concept" in status
            or "development" in status or status == "coming soon")
