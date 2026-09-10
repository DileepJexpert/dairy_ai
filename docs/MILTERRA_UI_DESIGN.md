# Milterra Flutter storefront

This page describes the implemented storefront and its design system. Future multi-department commerce, owner administration, featured products, daily deals and festival campaigns are specified in [MILTERRA_ECOMMERCE_REQUIREMENTS.md](MILTERRA_ECOMMERCE_REQUIREMENTS.md), with delivery gates in [MILTERRA_IMPLEMENTATION_PLAN.md](MILTERRA_IMPLEMENTATION_PLAN.md).

## Current design direction — luxury refinement

The latest user direction takes precedence over fixed layout prescriptions: an atmospheric homepage, followed by practical Amazon-style catalogue and shopping pages. Preserve existing content, prices and checkout. Two or three product columns are acceptable when each has a clear purpose and collapses well on smaller screens.

Current changes use bundled Cormorant Garamond headings, cream/forest-green surfaces and restrained gold, matching product image proportions, compact cards with real pack selection, shared search/category navigation, a cart drawer and a mobile purchase bar that reserves layout space. Generated assets are disclosed packaging concepts and yield to merchant media. See [MILTERRA_DESIGN_ASSETS.md](MILTERRA_DESIGN_ASSETS.md) for generation prompts and the font license.

This checkpoint still needs desktop/mobile browser acceptance, real cart responses and accessibility testing. See [ANTIGRAVITY_PROMPT.md](../ANTIGRAVITY_PROMPT.md) for the continuation task and [ANTIGRAVITY_HANDOFF.md](ANTIGRAVITY_HANDOFF.md) for the latest validation record.

The public storefront is `/shop` (also available at the existing `/marketplace/feed` URL). Product details are `/marketplace/product/<id>`. Browsing does not require login; purchase actions send guests to login with the product return path.

## Change the design in one place

`mobile/lib/app/store_theme.dart` owns the storefront design system:

- Brand and semantic colours, including category palettes.
- `StoreType`: typography roles and responsive heading variants.
- `StoreLayout`: spacing scale, breakpoints, maximum content width, corners and panel treatment.
- `StoreTheme.light`: application-wide Material 3 button, field, card, divider and text themes.
- `StoreTheme.purchaseButton`: shared purchase action treatment.

`main.dart` installs the theme globally. `app/theme.dart` retains compatibility aliases for older DairyAI screens, so their brand constants reference the same source. Existing unrelated farm/vet screens with explicit local style overrides have not been redesigned in this storefront change.

`features/marketplace/widgets/store_design.dart` owns reusable header, footer, panel, product artwork and currency formatting. `store_product_card.dart` owns selectable-pack cards and their presentation grouping; `features/cart/widgets/store_cart_drawer.dart` owns the shopping drawer. Screens compose these widgets and use shared tokens; do not add page-specific copies of colours, fonts or control themes. Web manifest and SVG favicon are static browser metadata and must be kept in sync when rebranding.

## Implemented

- Responsive search/navigation, category cards, category/price/stock filters, sorting and product grid.
- Catalogue API pagination is traversed before local filtering, avoiding first-page-only results. For a large catalogue, move filtering/sorting to a paginated server-backed query instead of loading the whole collection.
- Detail gallery with thumbnails and enlargement when media exists; price, pack variants, description, product specifications, seller information and related products.
- Stock-bounded quantity, cart action and checkout navigation using the existing cart API.
- Loading, API-error/retry, empty collection and unavailable-product states.

## Data boundaries

All product names, prices, stock and seller data come from the existing API. Generated packaging concepts are visibly labelled and used only when product photography is unavailable. No fabricated ratings, discounts, delivery dates, return guarantees or payment-success states are shown. Reviews are not implemented; missing nutrition and policies are stated explicitly.

With `COMMERCE_TAXONOMY_ENABLED=true`, browsing uses authoritative department/category metadata; unclassified products are not assigned a category from their names. Legacy title-derived dairy browsing groups remain only for old API data without enabled taxonomy. Pack choices match products with the same seller, title and category as a presentation bridge; a future explicit product-family/variant model is preferable for a larger catalogue.

## Run in your own Chrome profile

Keep the existing FastAPI backend running on port 8001 (see the root `RUN_LOCAL.md`), then in PowerShell:

```powershell
Set-Location C:\dileepkm\Learning\dairy_ai\mobile
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5051 --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

Open `http://127.0.0.1:5051/#/shop` manually in your preferred Chrome profile. If port 5051 is occupied by a preview, use another port such as 5052. The development backend CORS configuration accepts loopback origins. Do not use this development CORS policy in production.

To use Flutter's managed Chrome debugger instead: `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8001`. For an already running Flutter process, press capital `R` in its terminal to hot restart the app after source changes.

## Checks

```powershell
flutter test --no-pub
flutter analyze --no-pub lib/app/store_theme.dart lib/app/theme.dart lib/features/marketplace/screens/product_list_screen.dart lib/features/marketplace/screens/product_detail_screen.dart lib/features/marketplace/widgets/store_design.dart lib/features/marketplace/providers/product_provider.dart test/storefront_test.dart
flutter build web --debug --no-wasm-dry-run --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

Responsive tests cover 360, 390, 768, 1024 and 1440 logical pixels, search/filter/sort, unavailable inventory, pack navigation, quantity bounds, API failures and guest login return paths. These are UI and mocked-provider tests, not acceptance of live payments or a production deployment.

Earlier storefront validation (before luxury refinement): the 14-test Flutter suite passed, as did focused analysis and the JavaScript web build. Browser inspection exercised the live four-item catalogue and pack switching; the loopback API preflight returned HTTP 200 with the correct allowed origin. No order or payment was submitted, and the preview API was started with schema creation disabled. Those browser checks do not accept the latest design. The existing secure-storage dependency emits WebAssembly compatibility warnings; this build targets JavaScript, not Wasm.
