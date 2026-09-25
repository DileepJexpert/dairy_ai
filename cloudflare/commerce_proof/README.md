# D1 commerce correctness proof

This isolated proof exercises the reservation invariant planned for Milterra's
Cloudflare migration. It is **not** a replacement checkout endpoint or a
deployable production order schema. The current PostgreSQL checkout continues
to own real orders until the full D1 commerce flow is implemented and accepted.

The SQL in `0001_reservation.sql` requires one D1 `batch()` containing, in
order: an idempotent reservation parent insert, one line insert per product,
and a final seal insert. Every statement binds parameters. The line trigger
decrements stock with `WHERE available_units >= quantity`, then raises an SQL
error if the update changed no row. D1 rolls back the entire batch on that
error. The seal trigger rejects an incomplete set of lines and marks the
reservation `RESERVED` only after all lines exist. A unique
`(customer_id, idempotency_key)` constraint prevents duplicate reservations.
On a duplicate key, fetch the existing row and compare its canonical request
hash; identical requests return the original ID, while changed payloads fail.

The proof stores money as integer minor units with `INR` currency and rejects a
line when its accepted unit price differs from the current inventory price.
The real checkout must still authenticate the customer, validate the address,
coupon, delivery charge and tax, and calculate totals from trusted D1 records.
It must never trust customer-supplied prices, totals or payment status. Stock
release, expiry, provider reconciliation, durable jobs and migration of
existing PostgreSQL rows are outside this proof.

Run the SQLite concurrency harness:

```powershell
python -m unittest discover -s cloudflare\commerce_proof -p 'test_*.py' -v
```

Run the same schema and batch behavior with the local D1 binding shipped by
the pinned Wrangler installation in `cloudflare/worker`:

```powershell
node cloudflare\commerce_proof\test_d1_local.cjs
```

The D1 test starts a local Miniflare/workerd process in memory. It tests two
buyers contending for the final unit, rollback when a later line lacks stock,
same-key replay, different-payload conflict and stale-price rejection. No
Cloudflare account or remote database is touched. A staging D1 test remains
necessary before this design is used for real checkout.

Cloudflare's [D1 database API](https://developers.cloudflare.com/d1/worker-api/d1-database/)
documents transactional `batch()` rollback on statement errors. This proof
uses SQL `RAISE(ABORT)` because a conditional update affecting zero rows is
otherwise a successful SQL statement.
