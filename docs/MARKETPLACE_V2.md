# Marketplace V2 — Phase 1

Phase 1 adds cattle-only marketplace flows while reusing FastAPI, async SQLAlchemy, PostgreSQL, Dio, Riverpod, and GoRouter. Listings use UUID strings in Flutter and cattle categories are `cow`, `buffalo`, `bull`, `calf`, and `heifer`.

## API

`/api/v1/marketplace` provides listing search/detail/create/update/cancel, favorite toggling and favorites, my listings, buyer and seller inquiries, mark sold, and statistics. Listing creation may link `cattle_id`; ownership is checked and health/vaccination flags are derived from existing records. Photos remain URL strings in this phase.

## Flutter flow

`/marketplace` lists live backend listings with category, breed, and price filters; `/marketplace/listing/:listingId` shows the key cattle and verification details and sends an inquiry; `/marketplace/sell` creates a cattle listing. Marketplace is also available from More at `/more/marketplace`.

## Limitations

The existing herd API does not return enough fields to reliably prefill a selected animal, so the first sell form is standalone. Seller phone remains deliberately absent from listing responses. Distance, location coordinates, photo upload, full filter controls, and dedicated My Listings/Favorites/Inquiries screens are backend-ready follow-ups rather than separate commerce systems.

## Cart Feature

The product marketplace has one active cart per authenticated user. Feed and equipment products can be added, updated, removed, or cleared through `/api/v1/marketplace/cart`; `POST /cart/validate` reports stock, inactive/deleted product, minimum-quantity, missing-inventory, and price-change issues.

Cart quantities never reserve inventory. The server calculates the subtotal from current product prices and returns both `price_when_added` and `current_price` so the Flutter cart can show price changes. The product detail page adds items and the product-list cart badge shows the total quantity.

## Delivery addresses

Authenticated users can save, list, update, and delete delivery addresses at
`/api/v1/marketplace/addresses`. The first saved address becomes the default;
choosing a new default clears the previous default. The cart links to the
mobile saved-address screen. Order creation, delivery pricing, and payment are
still deliberately out of scope.
