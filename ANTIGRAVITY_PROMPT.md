# Continue Milterra — prompt for Antigravity

Paste the following prompt into Antigravity with this repository open:

---

Continue development in C:\dileepkm\Learning\dairy_ai. Inspect the current Git state and read RUN_LOCAL.md, docs/ANTIGRAVITY_HANDOFF.md, docs/MILTERRA_UI_DESIGN.md and docs/MILTERRA_IMPLEMENTATION_PLAN.md before editing.

The immediate priority is DESIGN AND SHOPPING EXPERIENCE. Keep the existing product content, prices, authentication rules and checkout behavior. Refine the existing Flutter storefront. The desired direction is an atmospheric luxury homepage followed by practical, familiar Amazon-style catalogue and purchasing pages. Keep forest green, warm cream and restrained gold. Three columns can work on wide product pages; two columns are also acceptable. Judge hierarchy, usability and responsive behavior rather than imposing a fixed column count.

This checkpoint includes a bundled serif font, generated concept imagery, a compact shared header/search/category navigation, product cards with real pack selection, a two-column responsive detail page with grouped buying controls and expandable details, a mobile purchase bar, and a cart drawer. Catalogue-to-product navigation now pushes a route so returning can preserve search, filters, selection and scroll. Every pack keeps its existing product ID and price.

Start by running and visually checking this checkpoint in Chrome at desktop and mobile widths. Complete the design polish before starting new business features:

1. Verify homepage composition, restrained imagery, category tiles and a small featured collection. Reduce competing boxes/banners and excessive card height. Keep search, sorting and filters easy to find.
2. Inspect the shared header at narrow, tablet and wide widths. Verify search/category navigation also works from a product page, including query/category URLs. Check the gallery, enlargement, pack selection, quantity bounds and all purchase states.
3. Test a real authenticated Add to cart: the drawer must display the server cart, show errors accurately, close cleanly, preserve browsing state, and use the existing cart/checkout routes. Keep public browsing open and require login for cart actions.
4. Test return navigation after searching/filtering/sorting, opening a product and changing packs. Confirm scroll position and filters survive. Test mobile filters, sticky purchase controls, keyboard focus, Escape dismissal, touch targets and larger text. Fix any overflow or covered content.
5. Generated files under mobile/assets/store are packaging concepts; merchant photos must take priority. Preserve their concept disclosure until replaced with approved product photography. Review asset loading/performance and optimize images without changing product details. The built-in image-generation prompts and font license are documented in docs/MILTERRA_DESIGN_ASSETS.md.

Use the existing architecture:

- Flutter + Riverpod + Dio frontend; FastAPI + async SQLAlchemy backend.
- Central visual rules: mobile/lib/app/store_theme.dart. Shared shopping components: mobile/lib/features/marketplace/widgets/. Cart drawer: mobile/lib/features/cart/widgets/store_cart_drawer.dart. Avoid duplicating colors, typography, spacing rules and button styles across screens.
- Existing product IDs are referenced by inventory, carts and orders. Current pack grouping follows title/vendor/category as a presentation bridge; introduce explicit family/variant IDs in a later catalogue slice, not a hidden schema change during design work.
- Existing commerce taxonomy/admin foundation supports departments, nested categories, audited/versioned edits and classification APIs. The full product/media/price/offer admin remains unfinished.
- Local data is disposable. Schema changes use the explicit full-model rebuild script in RUN_LOCAL.md. Do not reset on ordinary startup or replay the historical ALTER chain against the rebuilt baseline. Design work does not require a database reset.

Local startup: Docker Desktop running; start postgres/redis using infra/docker-compose.yml. Run the backend from backend on port 8001 with APP_ENV=development, COMMERCE_TAXONOMY_ENABLED=true and INIT_DB_ON_STARTUP=false. Run Flutter from mobile with API_BASE_URL=http://127.0.0.1:8001. Use an available UI port such as 5052 or 5053; inspect existing listeners before starting another server. Seeded demo admin is 9999900000 and vendor is 9999900090; request OTP first, local OTP 123456.

Run flutter test --no-pub and focused flutter analyze for changed files, then verify a web build and inspect the actual browser. This checkpoint passed 23 Flutter tests, focused analysis and a JavaScript debug web build; full visual browser acceptance remains pending. The backend runner reported 38 passing focused tests but stalled after its result summary and required interruption; investigate teardown before claiming a clean backend test run. Do not equate widget fixtures with real API acceptance. Describe any failures and what was actually verified.

After the design and shopping flow are accepted, continue the next separate functional slice: explicit product family/variant/type contracts and an owner-managed product editor with category assignment, media, stock and price. Later slices cover featured/highlighted placements, Deal of the Day and festival offers using authoritative backend pricing. Do not invent product claims, discounts or details for the five named farm supplements.

Work incrementally, preserve existing changes, and deliver a tested result with clear remaining work. Do not deploy, change live payments, or push without a request.

---
