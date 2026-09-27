# Private Milterra password derivation helper

The Python Workers runtime does not provide `hashlib.pbkdf2_hmac`. This small JavaScript service preserves the existing PBKDF2-SHA256 format (600,000 iterations, random 16-byte salt, 32-byte digest) using pinned `@noble/hashes`. It is not a rewrite of the Python backend.

Only the Python Worker's `PASSWORD_HASHER` service binding invokes this helper. `workers_dev` and preview URLs are disabled; no public route is configured. A bounded pool of 16 SQLite-backed Durable Objects supplies the CPU budget for password derivation. Credentials are neither logged nor persisted here. Authentication, rate limiting, session handling and D1 writes remain in Python.

From this directory run `npm ci --ignore-scripts`, `npm test`, then `npx wrangler deploy` before deploying the Python Worker with its service binding. The test vectors compare ASCII and Unicode derivations with Node's native PBKDF2 and reject malformed inputs. Local integration requires both Wrangler dev processes to be running.

Cloudflare supports SQLite-backed Durable Objects on the Free plan; this deployment did not activate a paid subscription. Requests, duration and Worker/D1 allowances remain subject to account limits. Measure actual traffic and CPU before claiming a capacity or monthly cost. See [pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/) and [limits](https://developers.cloudflare.com/durable-objects/platform/limits/).
