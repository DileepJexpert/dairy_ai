# Catalogue consistency — implementation decisions

## Feedback assessed

Keep the intentional Amazon-style marketplace shell and existing green/cream/gold theme. Retain the three-column product detail layout on wide desktops; stack on smaller screens. Improve shared components, not separate visual copies of the catalogue.

The local API was inspected before making data changes. It contained four sellable SKUs: MIL-PANEER-200, MIL-BUFF-500, MIL-GHEE-500 and MIL-GHEE-1000, all from Milterra Dairy. There were no duplicate buffalo-ghee or paneer database records. The differing names/prices came from hardcoded carousel, deals and wishlist data. Two cow-ghee rows are legitimate pack SKUs. Do not delete/rebuild or merge these records.

## Shared sources and identity

- `productsProvider` is authoritative for sellable products. Carousel, wishlist recommendations, cart recommendations, detail and offers now use those records. Fetch failures do not inject demo commercial stock.
- `Product.familyKey` and `storeProductGroups` present same-seller/same-family packs together without changing IDs. Explicit `specifications.family_id` can identify a family; otherwise the same seller, title, category and lifecycle are required. Different seller offers remain separate.
- Legacy dairy carousel URLs still resolve through the existing SKU aliases. Cart, order and wishlist IDs are unchanged. No database migration or data reset was performed.
- `concept_catalogue.dart` is an explicitly editorial preview source, separate from sellable inventory. It preserves preview IDs, trade names, media and category placement, including the full JANAM·42 name. Unsupported nutrition percentages and outcome claims are removed from other concept-title descriptors. JANAM·42 and white butter are not present in the current live stock catalogue. White butter is therefore shown as a preview, not an invented available SKU.
- `Product.isConcept` governs all shared cards/details. Future persisted concepts must set `specifications.listing_status` to `concept`, `in_development` or `coming soon`, or `specifications.concept` to true. Backend cart validation and checkout enforce the same specification policy even when price/stock exist. Publishing a preview as a sellable product requires replacing its editorial entry and maintaining its legacy route alias; do not simply add a second listing.

## Presentation

Shared `StoreLayout.productImageAspectRatio` is 1.31 (was 1.05): roughly 20% less image-panel height, with contained, undistorted imagery. Shared cards keep pack IDs, image/name navigation and wishlist controls. Product information uses canonical API names and pack sizes. No invented rating/question counts, seller ratings, scarcity timers or discounts are substituted.

Concepts show neutral development wording, no monetary price, stock promise, checkout, bundles or purchased-product reviews. Farmer feedback is explicitly distinguished from a review. “Share Farmer Feedback” opens an honest draft-copy dialog; “Register for Updates” explains that registration is not open. Neither claims to save or submit anything.

The sidebar retains every department, expands relevant groups first, scopes pack sizes, and hides price/stock controls and price sorts for concept-only collections. Price filters exclude concepts in mixed results. Empty/error collections retain recovery controls. Dynamic server taxonomy remains available.

Quality links share `product_information.dart`. Without verified product-specific records they read “Quality & Research” and explain the missing evidence. A product's `specifications.lab_reports` may contain records with `verified: true` and an HTTPS `url`; those are presented as “Lab Test Reports”, with selectable/copyable destinations. Only populate this field after actual evidence review. Illustrated farm stories are labelled as illustrations, not evidence of completed testing or real facility operations.

## White-butter asset

Path: `mobile/assets/store/white-butter-concept.png`.

Generated with the built-in image-generation capability; no suitable existing white-butter asset was found. Listings and detail/gallery reuse it through `ProductArtwork`, which identifies bundled packaging visuals as concept imagery. This is not production photography or approved final packaging.

Prompt used:

> Use case: product-mockup. Generate a square 1024x1024 premium ecommerce packaging concept for MILTERRA WHITE BUTTER (Indian makhan). One low round clear glass tub filled with soft ivory-white cultured butter with delicate spoon swirls, dark forest-green lid resting upright just behind, minimal forest-green label reading exactly 'milterra' and smaller 'WHITE BUTTER'. Warm cream seamless background #F7F5EF, consistent soft side daylight, natural soft shadow, realistic butter texture and glass, complete tub and lid visible centered with generous 20 percent margins. Green #173F35 and muted gold accent. No croissants, bread, paneer cubes, yellow ghee, health claims, certifications, quantities, prices, watermark or interface. This is concept packaging, not actual production photography.

## Verification and remaining data requirements

Focused automated checks cover catalogue/detail widths 360, 390, 768, 1024 and 1440; concept prices/actions, images, search, category/price sorting, filter recovery, variant IDs, wishlist state, navigation/scroll restoration and authenticated cart drawer behaviour. Backend tests cover existing cart/checkout behaviour plus refusing concepts, including an item changed to concept after it entered a cart.

Results: 33 focused Flutter tests and 11 backend tests passed. Scoped Flutter analysis found no errors or warnings, with 13 informational lint findings remaining (not a clean repository-wide analysis). Live browser checks confirmed the desktop catalogue uses canonical live product names, one grouped cow-ghee card, the new butter visual, JANAM desktop/mobile layouts, tablet butter imagery and a concept-only Stage-Based Nutrition collection without price/stock filters. A transient catalogue request failure during local server reload recovered; the public error state did not substitute fake stock. The generated white-butter asset is approximately 1.7 MB; production image optimization/CDN variants remain a deployment consideration.

Still needed before commercial publication: approved production photographs/packaging, verified lab-report files and claims, confirmed trial information if trials are to be offered, a consent/privacy policy and persisted feedback/update-registration service. No such data or service was invented. The admin's existing in-memory promotional editor is not a published promotion backend; customer deals therefore show current prices and an accurate no-published-offers message. Wishlist remains the existing session-only implementation, now without seeded entries.
