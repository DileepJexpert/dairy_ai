# Isolated Cloudflare Python Worker compatibility proof

This Worker is a local proof for the [Cloudflare migration brief](../../milterra-cloudflare-development-brief.md), not a replacement for the current commerce API. `/health` preserves the existing FastAPI response. `/ready` checks D1 and is uncached. The guarded `/__compat/*` endpoints exercise D1 parameter binding, existing-style HS256 access tokens, Razorpay raw-body HMAC verification, a mocked authenticated payment-link request, and the current image-size/format/EXIF-stripping policy. They do not create orders or mark payments as paid.

Tooling used for the local check: Python `3.13.3`, project-local `uv 0.12.3` (pywrangler requires at least this version), Node `22.16.0`, `workers-py 1.17.4`, Wrangler `4.140.0`, Pyodide `3.14.2`, and compatibility date `2026-09-25`. `uv.lock`, `pylock.toml` and `package-lock.json` pin the tested dependency graph. The D1 ID in `wrangler.toml` is a dummy local-only ID. No production deployment can use it.

From this directory, with `uv >= 0.12.3`, Node and npm on `PATH`:

```powershell
npm ci
uv sync
npx wrangler d1 migrations apply milterra-compat-local --local
Copy-Item dev.vars.example .dev.vars
uv run pywrangler deploy --dry-run --outdir .wrangler/compat-bundle
```

For the runtime integration check, start the following in separate terminals from this directory:

```powershell
python tests/mock_provider.py
uv run pywrangler dev --port 8787
uv run python tests/verify_local_worker.py
```

The last command should print `Worker runtime verified: health, readiness, D1, JWT, HMAC, provider, image, 404`. The mock provider listens on loopback and checks Basic authentication; no external payment request or money movement occurs. Pure contract tests run with `uv run pytest -q -p no:cacheprovider tests/test_compat.py tests/test_api_contract.py`.

The successful dry run reported 523 modules, 11,881 KiB total and 3,147 KiB gzipped. That is a compatibility result, not a performance target for the eventual full API. The first D1 runtime test exposed that `result.results` may already be a Python list; the adapter now accepts either a list or a JS proxy. The full legacy API cannot be imported unchanged: its async SQLAlchemy/PostgreSQL layer, Redis fail-closed auth limiter, filesystem media storage and startup loops require separate replacements. No Cloudflare staging environment or live provider credentials were used.

Before any remote deployment, replace the dummy D1 binding with a staging resource, remove or isolate the probe endpoints, configure precise storefront CORS origins, and implement the actual authorization/ownership and commerce state transitions. Keep staging and production bindings and secrets separate.
