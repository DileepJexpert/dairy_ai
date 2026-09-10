# Production deployment: Milterra preview API

This repository can deploy the FastAPI service to Railway using the root `Dockerfile` and `railway.toml`. It remains a shared DairyAI backend; do not point the consumer-facing `milterra.in` domain at the current Flutter super-app, because that app exposes farmer, veterinary, and cattle-marketplace features rather than a Milterra food storefront.

## Railway

1. Create a Railway project and add a PostgreSQL service.
2. Create a service from this GitHub repository. Railway will use `railway.toml`.
3. Add every value from `.env.production.example` as an encrypted Railway variable. Use Railway's PostgreSQL connection value for `DATABASE_URL`, converted to the `postgresql+asyncpg://` driver form when necessary.
4. Generate a unique JWT secret of at least 32 characters. Production startup deliberately refuses the development default.
5. Deploy. The start command runs `alembic upgrade head` before Uvicorn starts. Confirm the generated Railway URL returns `200` from `/health`.

## Domain mapping

In Railway, map `api.milterra.in` to the API service. In the DNS provider for `milterra.in`, add the CNAME Railway supplies. Set `CORS_ORIGINS` to the exact public storefront origins, for example `https://milterra.in,https://www.milterra.in`.

Do not map the API service directly to `milterra.in`: the apex domain should serve the future Milterra customer storefront. The backend should use `api.milterra.in`.

## Launch gates

This deployment is suitable for a protected preview/staging environment, not customer checkout yet:

- The Milterra web storefront has not been built in this repository.
- Buyer OTP generation is stored but not delivered through an SMS provider implementation.
- Checkout records `PENDING_PAYMENT`; Razorpay order creation, signature-verified webhook handling, and payment-state updates are still required.
- Product media currently uses supplied image URLs; an object-storage upload flow is still required.

Vendor fulfillment is deliberately hidden until an order's payment status is `PAID`, so unpaid customer addresses cannot be exposed to sellers.
