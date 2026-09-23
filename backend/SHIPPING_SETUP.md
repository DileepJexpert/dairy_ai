# Shipping setup

The store currently has one pickup origin (`201305`) and one parcel per order. Manual dispatch can use any real courier and AWB. The automatic adapter supports Delhivery only; Blue Dart, Ekart, and other partners require their own approved accounts and adapters before they can participate in automatic rate or coverage selection.

The adapter registry filters carriers by pincode serviceability and rate, then applies an optional maximum cost and delivery-days limit. `SHIPPING_SELECTION_STRATEGY` chooses the cheapest eligible rate or the fastest known ETA. Delhivery's current estimate adapter does not provide an ETA, so a nonzero delivery-days limit will exclude it until ETA data is available.

The default configuration is safe for development: `PRELAUNCH_MODE=true` and `SHIPPING_AUTO_BOOK_ENABLED=false`. A purchase interest cannot be shipped. Checkout payments are not yet connected to the commerce order's `PAID` state, so production booking must stay disabled until verified payment confirmation is integrated. COD settlement is also not connected, and COD orders are never booked automatically.

After obtaining Delhivery staging credentials, set these server-side variables in a private environment, never in Flutter or the repository:

```text
SHIPPING_ORIGIN_PINCODE=201305
DELHIVERY_ENV=staging
DELHIVERY_TOKEN=<account token>
DELHIVERY_CLIENT_NAME=<account client name>
DELHIVERY_PICKUP_LOCATION=<registered pickup location name>
SHIPPING_PACKAGE_LENGTH_CM=<measured default length>
SHIPPING_PACKAGE_WIDTH_CM=<measured default width>
SHIPPING_PACKAGE_HEIGHT_CM=<measured default height>
SHIPPING_PACKAGING_TARE_GRAMS=<measured packaging weight>
SHIPPING_MAX_COURIER_COST=<optional rupee ceiling>
SHIPPING_MAX_DELIVERY_DAYS=0
SHIPPING_SELECTION_STRATEGY=lowest_cost
```

Apply Alembic migration `commerce_shipping_v15` before enabling the worker. Product `weight_grams` must represent actual product weight; an operator can supply the measured parcel weight and dimensions from the operations screen after packing. A paid, packed single-seller order becomes `READY` when all measurements are present. With `SHIPPING_AUTO_BOOK_ENABLED=true` and a commercial order, the background loop requests a courier quote, books with Delhivery, records the real AWB, and requests pickup. Carrier scans update the recorded customer timeline. If booking outcome is uncertain, the shipment enters `NEEDS_ATTENTION`; use the reconcile action and courier portal to check for an existing AWB. If the portal has an AWB, record it through Resolve; if the portal confirms no booking, Resolve moves the order to manual dispatch. The worker never blindly creates a second booking.

Checkout still supports the configured manual pincode fee. When automatic shipping is enabled and a prepaid cart has known weights, checkout asks Delhivery for a live quote and uses that rate when available. Staging quote responses may not contain contract rates. The booked courier amount may differ from the checkout estimate, so monitor the quoted cost and use a configured ceiling.

The operations screen can record an actual manual courier and AWB, including when automatic booking is disabled. The customer tracking endpoint returns only recorded shipment data and scans; it never invents a courier, AWB, or delivery milestone. The admin label endpoint serves a courier-issued PDF when Delhivery returns one. Pickup requests and label generation have not been accepted against a real account in this workspace.
