# Milterra same-site order test mode

Updated 29 September 2026. The owner is testing on [milterrafoods.com](https://milterrafoods.com/#/shop) using the **existing** `milterra-staging` Pages project, `milterra-api-staging` Worker, and `milterra-staging` D1. No extra Cloudflare Pages project, Worker, or database is required. The separate flow preview was deleted.

## Why this mode exists

The owner is currently the only intended tester and will reset the test data before inviting real customers. This mode runs checkout and tracking through the same website and accounts that will later serve customers, while allowing the owner to exercise courier, COD collection, return, and refund states **without contacting a courier or moving money**. It tests Milterra's internal state transitions and UI, not external delivery or payment settlement.

This is a **whole-site test phase**: every new COD checkout order on this Worker is tagged `is_test_order=1`. Existing rows keep their prior tag. Do not treat a new test order as a real accepted shipment. The visible `MILTERRA TEST MODE` banner and `SIM-` references identify simulated events. Test orders still use the same D1 inventory and reserve stock; the later fresh-data launch must account for them.

## Configuration and controls

The ignored local Wrangler configuration for the existing Worker sets `ENVIRONMENT=staging`, `CUSTOMER_AUTH_ENABLED=true`, `TEST_COMMERCE_ENABLED=true`, `LIVE_COD_ENABLED=false`, and `SIMULATION_ENABLED=true`. The Flutter build uses `FLOW_SIMULATION=true` and points `API_BASE_URL` and `AUTH_API_BASE_URL` to that **same** Worker. The Pages project remains `milterra-staging`; its custom domains remain `milterrafoods.com` and `www.milterrafoods.com`.

Migration `0012_simulated_fulfillment.sql` adds an append-only simulated money ledger to the existing D1. Simulator routes also require a signed-in admin and an `is_test_order=1` order. They reject a real-tagged order even while whole-site test mode is on. Courier references begin `SIM-AWB-`, simulated COD references `SIM-COD-`, simulated refund references `SIM-REFUND-`, and timeline titles say `[SIMULATED]`. There is no courier API request, physical cash collection, bank transfer, prepaid payment, or refund.

Only PIN `201305` is currently enabled with free delivery for this test. A valid six-digit PIN alone does not create delivery coverage.

## Test it in the browser

Use a normal customer account for checkout and your existing admin login for seller actions. Two browser profiles or signing out between roles avoids mixing their sessions. Save each order ID.

1. Open [the real-domain test site](https://milterrafoods.com/#/shop) and confirm the `MILTERRA TEST MODE` banner. As a customer, add an available product and an address with PIN `201305`. Choose **Cash on Delivery**, review the server-calculated total, and place an order.
2. For the **cancellation case**, open **Your Orders** and cancel that order before it is packed. Expect `CANCELLED`, payment still `PENDING`, stock returned, and no refund entry. Unpaid COD requires no refund.
3. Place a **second** COD order. As admin, open [Orders](https://milterrafoods.com/#/admin/commerce/orders). If it is `PENDING`, use **Update** to confirm it; then use **Update** to mark it `PACKED`. Do not use the ordinary dispatch action on a test order.
4. On that order, choose **Simulate dispatch**, **Simulate out for delivery**, **Simulate delivery**, and **Simulate COD collection** in sequence. Expect `SHIPPED`, `OUT_FOR_DELIVERY`, `DELIVERED`, then payment `PAID`, with `SIM-` references. No parcel is booked and no cash is collected.
5. As the customer, open the delivered order and choose **Request return**. As admin, open [the control panel](https://milterrafoods.com/#/admin/ecommerce), select **Shipments & Logistics**, refresh the return queue, then choose **Simulate received item and COD refund**. Expect a `SIM-REFUND-` reference, payment `REFUNDED`, and an updated customer timeline. Choose inventory restock only when appropriate for the test.
6. Optionally place a third order and choose **Simulate failed delivery** after fake dispatch. Expect an RTO case and no COD collection or refund. Process its receipt in **Shipments & Logistics**.

If the simulation buttons are missing, check that the new order is tagged test, the admin is signed in, and the order is at the required state. Refresh the list after each action. A `409` means the requested transition does not fit the current state. Send the order ID and error message for debugging; never send login credentials.

## Verification and current limits

Local verification: all 61 Worker tests passed, the Python Worker dry-run bundle succeeded, and focused Flutter analysis found no issues. Remote migration `0012` applied; `/health` and `/ready` returned 200; payment capabilities reported `test_mode=true`, `online_payment_available=false`; the simulator required sign-in. Pages deployment `8c910fe4.milterra-staging.pages.dev` served JavaScript matching the local release build on both custom domains, and browser inspection showed the test-mode banner.

The same-site API acceptance script created synthetic customer `2705adda-079c-41d8-b198-ab49a25704aa` and test order `ac9a93e6-db58-4a7b-a1c3-d0570eda9db3`. It verified account, address, cart, authoritative quote, test-tagged COD checkout, idempotent replay, order history, cancellation, restored stock, and logout. That order remains cancelled in D1. The full **signed-in customer/admin browser walkthrough** of dispatch, COD collection, return, and refund is still for the owner to perform; local tests cover these transitions, but no same-site remote admin completion is claimed.

The mode does not establish all-India courier serviceability, real pickup, cash remittance, or prepaid refund behavior. These need real provider accounts and separate acceptance.

## Exit test mode for a real launch

Do not merely remove the banner. First decide which test customers, addresses, orders, coupons, inventory changes, and simulated ledger rows to reset or replace; back up anything to retain. Then deploy a reviewed live configuration with `TEST_COMMERCE_ENABLED=false`, `SIMULATION_ENABLED=false`, `LIVE_COD_ENABLED=true`, and a Flutter build without `FLOW_SIMULATION`. Verify new orders receive `is_test_order=0`, simulator routes return 404, live COD PIN/fee policy is correct, and the admin/customer journeys work. A fresh D1 deployment needs all migrations and authoritative catalogue/inventory plus a new admin/customer setup before switching traffic. **No reset or real-launch cutover was performed in this test-mode deployment.**
