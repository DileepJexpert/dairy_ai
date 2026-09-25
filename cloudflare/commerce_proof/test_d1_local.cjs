// Run with `node cloudflare/commerce_proof/test_d1_local.cjs`.
// The installed Wrangler dependency supplies Miniflare and the local D1 binding.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { Miniflare, convertV4MiniflareOptions } = require("../worker/node_modules/miniflare");

function schemaStatements() {
  const sql = fs.readFileSync(path.join(__dirname, "0001_reservation.sql"), "utf8");
  const statements = [];
  let current = [];
  let trigger = false;
  for (const line of sql.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("--")) continue;
    if (/^CREATE TRIGGER\b/i.test(trimmed)) trigger = true;
    current.push(line);
    if ((trigger && trimmed === "END;") || (!trigger && trimmed.endsWith(";"))) {
      // D1.exec treats newlines as statement separators, even inside CREATE TABLE.
      statements.push(current.join(" "));
      current = [];
      trigger = false;
    }
  }
  assert.equal(current.length, 0, "all schema SQL must be parsed");
  return statements;
}

function canonical(customerId, lines) {
  const sorted = [...lines].sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0);
  assert.ok(sorted.length > 0, "at least one line is required");
  assert.equal(new Set(sorted.map((line) => line[0])).size, sorted.length,
    "duplicate products must be combined first");
  for (const [productId, quantity, priceMinor] of sorted) {
    assert.ok(productId && Number.isInteger(quantity) && quantity > 0);
    assert.ok(Number.isInteger(priceMinor) && priceMinor >= 0);
  }
  return crypto
    .createHash("sha256")
    .update(JSON.stringify({ currency: "INR", customer_id: customerId, lines: sorted }))
    .digest("hex");
}

async function reserve(db, customerId, key, lines) {
  const hash = canonical(customerId, lines);
  const prior = async () =>
    db.prepare(
      "SELECT id, payload_sha256, status FROM proof_reservations WHERE customer_id=? AND idempotency_key=?"
    ).bind(customerId, key).first();
  const existing = await prior();
  if (existing) {
    if (existing.payload_sha256 !== hash) throw Error("idempotency conflict");
    assert.equal(existing.status, "RESERVED");
    return existing.id;
  }
  const id = crypto.randomUUID();
  const statements = [db.prepare(
    "INSERT INTO proof_reservations (id,customer_id,idempotency_key,payload_sha256,expected_lines) VALUES (?,?,?,?,?)"
  ).bind(id, customerId, key, hash, lines.length)];
  for (const [productId, quantity, priceMinor] of lines) {
    statements.push(db.prepare(
      "INSERT INTO proof_reservation_lines (reservation_id,product_id,quantity,unit_price_minor,currency) VALUES (?,?,?,?,?)"
    ).bind(id, productId, quantity, priceMinor, "INR"));
  }
  statements.push(db.prepare(
    "INSERT INTO proof_reservation_seals (reservation_id) VALUES (?)"
  ).bind(id));
  try {
    await db.batch(statements);
  } catch (error) {
    // A second request may have won this idempotency key while we prepared.
    const winner = await prior();
    if (winner) {
      if (winner.payload_sha256 !== hash) throw Error("idempotency conflict");
      assert.equal(winner.status, "RESERVED");
      return winner.id;
    }
    throw error;
  }
  return id;
}

async function inventory(db, productId) {
  return db.prepare(
    "SELECT available_units FROM proof_inventory WHERE product_id=?"
  ).bind(productId).first("available_units");
}

async function count(db) {
  return db.prepare("SELECT COUNT(*) AS n FROM proof_reservations").first("n");
}

async function seed(db, id, stock, price=500) {
  await db.prepare(
    "INSERT INTO proof_inventory (product_id,available_units,price_minor,currency) VALUES (?,?,?,'INR')"
  ).bind(id, stock, price).run();
}

async function main() {
  assert.equal(canonical("buyer", [["ghee", 1, 500]]),
    "984b219c1a7aab69d3a98af54bcf3056f33d075154d90bb1ee696e38558b4e18");
  const mf = new Miniflare(convertV4MiniflareOptions({
    modules: true,
    script: "export default { fetch() { return new Response('proof only'); } }",
    compatibilityDate: "2026-09-25",
    d1Databases: { DB: "commerce-proof" },
  }));
  try {
    const db = await mf.getD1Database("DB");
    for (const statement of schemaStatements()) await db.exec(statement);

    await seed(db, "last", 1);
    const contenders = await Promise.allSettled([
      reserve(db, "customer-a", "checkout", [["last", 1, 500]]),
      reserve(db, "customer-b", "checkout", [["last", 1, 500]]),
    ]);
    assert.equal(contenders.filter((item) => item.status === "fulfilled").length, 1);
    assert.match(String(contenders.find((item) => item.status === "rejected").reason),
      /insufficient stock/);
    assert.equal(await inventory(db, "last"), 0);
    assert.equal(await count(db), 1);

    await seed(db, "a", 2);
    await seed(db, "b", 0);
    await assert.rejects(reserve(db, "customer-c", "multi", [
      ["a", 1, 500], ["b", 1, 500],
    ]), /insufficient stock/);
    assert.equal(await inventory(db, "a"), 2);
    assert.equal(await count(db), 1);

    const first = await reserve(db, "customer-d", "stable", [["a", 1, 500]]);
    assert.equal(await reserve(db, "customer-d", "stable", [["a", 1, 500]]), first);
    await assert.rejects(
      reserve(db, "customer-d", "stable", [["a", 2, 500]]),
      /idempotency conflict/
    );
    assert.equal(await inventory(db, "a"), 1);
    assert.equal(await count(db), 2);

    await assert.rejects(
      reserve(db, "customer-e", "stale-price", [["a", 1, 400]]),
      /price changed/
    );
    assert.equal(await inventory(db, "a"), 1);
    assert.equal(await count(db), 2);
    console.log("local D1: last-unit, rollback, replay, hash conflict and stale price passed");
  } finally {
    await mf.dispose();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
