# Static storefront catalogue export

`export_static_catalogue.py` reads the existing PostgreSQL `Product`, `ProductFamily`, `ProductMedia`, active `Vendor`, and active taxonomy records. It emits one compact JSON file with stable ordering and a `content_sha256` that changes only when exported content changes. The script uses a read-only, repeatable-read transaction on PostgreSQL and replaces the output file atomically.

From `backend`, after applying migrations and reviewing the public product content:

```powershell
python -m scripts.export_static_catalogue `
  --output ../mobile/assets/catalogue/products.json `
  --public-media-base-url https://media.example.com/product-media/
```

The output path is an example; the storefront build must publish the exact generated file it reads. Do not commit a file generated from a stale development database as the live catalogue. Export from the authoritative commerce database after each approved catalogue change, then publish the JSON and matching media in one release.

An empty product result fails before touching the current output. Use `--allow-empty` only when intentionally publishing an empty shop.

The snapshot includes only active, published products from active sellers and published families. Prices remain decimal strings. It includes public descriptions, simple display specifications, family content, product IDs/SKUs, and media references. It excludes stock quantities, vendor contact/banking fields, unrestricted supporting documents, drafts, and all review/rating data. Review provenance in the current database is insufficient to distinguish genuine purchase feedback from seeded examples. Checkout must re-read price, publication status, and stock from the live backend. A browser cannot treat this file as proof of availability.

Uploaded media currently uses `/api/v1/marketplace/media/<uuid>`. The export fails if it encounters such a reference without `--public-media-base-url`. When supplied, it writes `<base-url>/<uuid>.jpg`; the matching JPEG bytes must first be copied to that public R2/CDN path. Bundled `assets/...` paths and stable HTTPS media URLs remain as stored. HTTP URLs, signed/query URLs, and traversal paths are rejected so a published snapshot does not depend on expiring or private image links. The export does not perform the R2 upload; that publishing step remains to be implemented.

The JSON is built from the current database. Without access to that database and its media files, the script can be tested against synthetic fixture records, but a real catalogue snapshot and image completeness cannot be verified. Before release, check the item count, sample product IDs and prices, image fetches from the public media domain, and a live checkout quote against the same products.

For a Pages deployment that ships the uploaded images with Flutter, run:

```powershell
python -m scripts.publish_static_catalogue --output-dir ../mobile/web/catalogue
```

This writes `/catalogue/media/<uuid>.jpg`, a versioned `/catalogue/products-<sha>.json`, and `/catalogue/current.json` last. The pointer contains `schema_version`, `snapshot`, and `content_sha256`. Existing snapshots/images remain for older clients. Missing, oversized, invalid or metadata-bearing local JPEGs abort before the pointer changes. Deploy the resulting `mobile/build/web` only after reviewing the new snapshot and checking every image URL. The script does not mark admin publication status or deploy Pages; those are separate unfinished steps. The same-origin `/catalogue/media` prefix avoids an R2 bill for this small initial catalogue; R2 remains appropriate when admin uploads must be published without a full frontend release.
