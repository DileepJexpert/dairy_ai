import { Hono, type Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { verify } from 'hono/jwt';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { hmacSha256 } from '../utils/crypto.js';

export const commerceRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Helpers & Native Web Crypto
// ---------------------------------------------------------------------------

async function sha256Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hashBuf = await crypto.subtle.digest('SHA-256', data);
  const hashArr = Array.from(new Uint8Array(hashBuf));
  return hashArr.map((b) => b.toString(16).padStart(2, '0')).join('');
}

function normalizeLines(lines: Array<[string, number, number]>): Array<[string, number, number]> {
  const sorted = [...lines].sort((a, b) => a[0].localeCompare(b[0]));
  if (sorted.length === 0) {
    throw new HTTPException(422, { message: 'At least one item is required' });
  }
  const seen = new Set<string>();
  for (const [productId, quantity, priceMinor] of sorted) {
    if (seen.has(productId)) {
      throw new HTTPException(422, { message: 'Duplicate products must be combined before reservation' });
    }
    seen.add(productId);
    if (!productId || typeof quantity !== 'number' || quantity <= 0) {
      throw new HTTPException(422, { message: 'Invalid product or quantity' });
    }
    if (typeof priceMinor !== 'number' || priceMinor < 0) {
      throw new HTTPException(422, { message: 'Price must be non-negative integer minor units' });
    }
  }
  return sorted;
}

async function canonicalPayloadHash(customerId: string, lines: Array<[string, number, number]>): Promise<string> {
  const canonical = JSON.stringify({
    currency: 'INR',
    customer_id: customerId,
    lines: normalizeLines(lines),
  });
  return await sha256Hex(canonical);
}

async function checkoutFingerprint(
  customerId: string,
  idempotencyKey: string,
  addressId: string,
  paymentMethod: string = 'cod',
  couponCode?: string | null,
  expectedTotal?: number | null
): Promise<string> {
  const payload = {
    coupon_code: couponCode ? couponCode.trim().toUpperCase() : null,
    customer_id: customerId,
    delivery_address_id: addressId,
    expected_total: expectedTotal !== null && expectedTotal !== undefined ? Math.round(expectedTotal * 100) / 100 : null,
    idempotency_key: idempotencyKey,
    payment_method: paymentMethod,
    version: 1,
  };
  const sortedKeys = Object.keys(payload).sort() as (keyof typeof payload)[];
  const sortedObj: Record<string, any> = {};
  for (const k of sortedKeys) {
    sortedObj[k] = payload[k];
  }
  return await sha256Hex(JSON.stringify(sortedObj));
}

// ---------------------------------------------------------------------------
// Authentication Resolver
// ---------------------------------------------------------------------------

export async function requireAuth(
  c: Context<{ Bindings: Env }>,
  allowedRoles?: string[]
): Promise<{ id: string; role: string; phone: string; full_name: string }> {
  const allowTestAuth = c.env?.ENVIRONMENT === 'test' && c.env?.ALLOW_TEST_AUTH === 'true';
  const testUserId = c.req.header('x-test-customer-id');
  let customerId: string | null = null;

  if (allowTestAuth && testUserId) {
    customerId = testUserId;
  } else {
    const authHeader = c.req.header('authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
      throw new HTTPException(401, { message: 'Authentication required' });
    }
    const token = authHeader.substring(7).trim();
    const secret = c.env?.AUTH_SECRET || c.env?.JWT_SECRET;
    if (!secret && c.env?.ENVIRONMENT === 'production') {
      throw new HTTPException(500, { message: 'Authentication secret misconfigured on server' });
    }
    const effectiveSecret = secret || 'milterra-super-secret-auth-key-at-least-32-chars-long';

    const accessHash = await hmacSha256(effectiveSecret, token);
    const now = Math.floor(Date.now() / 1000);

    const session = await c.env?.DB?.prepare(
      `SELECT customer_id FROM customer_sessions WHERE access_hash = ? AND access_expires_at > ?`
    ).bind(accessHash, now).first<{ customer_id: string }>();

    if (session) {
      customerId = session.customer_id;
    } else {
      try {
        const verified = await verify(token, effectiveSecret, 'HS256');
        if (verified && (verified.sub || (verified as any).user_id)) {
          customerId = (verified.sub || (verified as any).user_id) as string;
        }
      } catch {
        // Token signature verification failed or token is malformed
      }
    }
  }

  if (!customerId) {
    throw new HTTPException(401, { message: 'Invalid or expired session' });
  }

  const customer = await c.env?.DB?.prepare(
    'SELECT id, phone, role, full_name, is_active FROM customers WHERE id = ?'
  ).bind(customerId).first<{ id: string; phone: string; role: string; full_name: string; is_active: number }>();

  if (!customer || !customer.is_active) {
    throw new HTTPException(401, { message: 'Customer not found or inactive' });
  }

  if (allowedRoles && !allowedRoles.includes(customer.role)) {
    throw new HTTPException(403, { message: 'Insufficient permissions' });
  }

  return {
    id: customer.id,
    role: customer.role,
    phone: customer.phone,
    full_name: customer.full_name || '',
  };
}

// ---------------------------------------------------------------------------
// Delivery & Pincode Policy
// ---------------------------------------------------------------------------

function isIndianPincode(pincode: string): boolean {
  return /^[1-8][0-9]{5}$/.test(pincode.trim());
}

async function getDeliveryPolicy(
  db: D1Database | undefined,
  pincode: string
): Promise<{
  pincode: string;
  city: string;
  state: string;
  is_serviceable: boolean;
  cod_available: boolean;
  prepaid_available: boolean;
  delivery_fee_minor: number;
  free_delivery_above_minor?: number | null;
  delivery_days_min?: number | null;
  delivery_days_max?: number | null;
}> {
  if (!isIndianPincode(pincode) || !db) {
    return {
      pincode,
      city: '',
      state: '',
      is_serviceable: false,
      cod_available: false,
      prepaid_available: false,
      delivery_fee_minor: 0,
    };
  }

  const hint = await db.prepare(
    `SELECT city, state, is_serviceable, delivery_fee_minor, delivery_days_min, delivery_days_max
     FROM serviceable_pincodes WHERE pincode = ?`
  ).bind(pincode).first<{
    city: string;
    state: string;
    is_serviceable: number;
    delivery_fee_minor: number;
    delivery_days_min: number | null;
    delivery_days_max: number | null;
  }>();

  const enabled = Boolean(hint && hint.is_serviceable);
  return {
    pincode,
    city: hint ? hint.city : '',
    state: hint ? hint.state : '',
    is_serviceable: enabled,
    cod_available: enabled,
    prepaid_available: false,
    delivery_fee_minor: hint ? hint.delivery_fee_minor : 0,
    free_delivery_above_minor: 49900,
    delivery_days_min: hint?.delivery_days_min ?? null,
    delivery_days_max: hint?.delivery_days_max ?? null,
  };
}

async function verifyDeliveryAddress(db: D1Database, customerId: string, addressId: string) {
  const addr = await db.prepare(
    `SELECT id, customer_id, recipient_name, phone, address_line1, address_line2, city, state, pincode, is_default
     FROM customer_addresses WHERE id = ? AND customer_id = ?`
  ).bind(addressId, customerId).first<{
    id: string;
    customer_id: string;
    recipient_name: string;
    phone: string;
    address_line1: string;
    address_line2: string | null;
    city: string;
    state: string;
    pincode: string;
    is_default: number;
  }>();

  if (!addr) {
    throw new HTTPException(404, { message: 'Delivery address not found or does not belong to customer' });
  }

  const pincode = String(addr.pincode || '').trim();
  if (!isIndianPincode(pincode)) {
    throw new HTTPException(422, { message: `Invalid delivery pincode '${pincode}'; must be exactly 6 numeric digits` });
  }
  return addr;
}

// ---------------------------------------------------------------------------
// Coupon Validation
// ---------------------------------------------------------------------------

function isCouponExpired(validUntil: string | null | undefined): boolean {
  if (!validUntil) return false;
  const expiry = new Date(validUntil.replace('Z', '+00:00'));
  return expiry.getTime() <= Date.now();
}

async function validateCoupon(
  db: D1Database,
  couponCode: string | null | undefined,
  subtotal: number
): Promise<[string | null, number]> {
  if (!couponCode || !couponCode.trim()) {
    return [null, 0.0];
  }

  const code = couponCode.trim().toUpperCase();
  const c = await db.prepare(
    `SELECT code, description, discount_type, discount_value, min_order_value, max_discount_cap, is_active, valid_until
     FROM coupons WHERE code = ?`
  ).bind(code).first<{
    code: string;
    description: string;
    discount_type: string;
    discount_value: number;
    min_order_value: number | null;
    max_discount_cap: number | null;
    is_active: number;
    valid_until: string | null;
  }>();

  if (!c) {
    throw new HTTPException(422, { message: `Invalid coupon code '${code}'` });
  }
  if (!c.is_active) {
    throw new HTTPException(422, { message: `Coupon '${code}' is no longer active` });
  }
  if (isCouponExpired(c.valid_until)) {
    throw new HTTPException(422, { message: `Coupon '${code}' has expired` });
  }

  const minOrder = Number(c.min_order_value || 0.0);
  if (subtotal < minOrder) {
    throw new HTTPException(422, { message: `Minimum order value for coupon '${code}' is ₹${minOrder.toFixed(0)}` });
  }

  const val = Number(c.discount_value || 0.0);
  let disc = 0.0;
  if (c.discount_type === 'percentage') {
    disc = (subtotal * val) / 100.0;
    if (c.max_discount_cap !== null && c.max_discount_cap !== undefined) {
      disc = Math.min(disc, Number(c.max_discount_cap));
    }
  } else {
    disc = Math.min(subtotal, val);
  }

  return [code, Math.round(disc * 100) / 100];
}

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const CartItemInputSchema = z.object({
  product_id: z.string().min(1).max(128),
  quantity: z.number().int().min(1).max(999),
});

const CartItemUpdateSchema = z.object({
  quantity: z.number().int().min(0).max(999),
});

const AddressInputSchema = z.object({
  recipient_name: z.string().min(1).max(128),
  phone: z.string().min(8).max(20),
  address_line1: z.string().min(1).max(256),
  address_line2: z.string().nullable().optional(),
  city: z.string().min(1).max(128),
  state: z.string().min(1).max(128),
  pincode: z.string().regex(/^[0-9]{6}$/),
  district: z.string().default('').optional(),
  landmark: z.string().nullable().optional(),
  is_default: z.boolean().default(false),
});

const CheckoutQuoteInputSchema = z.object({
  delivery_address_id: z.string().nullable().optional(),
  coupon_code: z.string().nullable().optional(),
  payment_method: z.string().default('cod'),
  points_to_redeem: z.number().int().min(0).default(0),
});

const CheckoutInputSchema = z.object({
  idempotency_key: z.string().min(8).max(128),
  delivery_address_id: z.string().min(1).max(128),
  payment_method: z.string().default('cod'),
  coupon_code: z.string().nullable().optional(),
  expected_total: z.number().nullable().optional(),
  points_to_redeem: z.number().int().min(0).default(0),
});

const CouponQuoteInputSchema = z.object({
  code: z.string().min(1).max(50),
});

// ---------------------------------------------------------------------------
// 1. Inventory & Products
// ---------------------------------------------------------------------------

commerceRouter.get('/inventory', async (c) => {
  const rows = await c.env.DB.prepare(
    `SELECT i.product_id, i.price_minor, i.available_units, i.is_active,
            p.mrp_minor, COALESCE(v.is_visible, 1) AS storefront_visible
     FROM inventory i
     LEFT JOIN inventory_pricing p ON p.product_id = i.product_id
     LEFT JOIN storefront_product_visibility v ON v.product_id = i.product_id`
  ).all();

  const data = (rows.results || []).map((row: any) => ({
    product_id: row.product_id,
    price: row.price_minor / 100,
    available_quantity: row.available_units,
    is_active: Boolean(row.is_active),
    storefront_visible: Boolean(row.storefront_visible),
    mrp: row.mrp_minor != null ? row.mrp_minor / 100 : null,
  }));

  return c.json({ success: true, data });
});

commerceRouter.get('/inventory/:product_id', async (c) => {
  const productId = c.req.param('product_id');
  const item = await c.env.DB.prepare(
    `SELECT i.product_id, i.title, i.available_units, i.price_minor,
            i.currency, i.is_active,
            COALESCE(v.is_visible, 1) AS storefront_visible
     FROM inventory i
     LEFT JOIN storefront_product_visibility v ON v.product_id = i.product_id
     WHERE i.product_id = ?`
  ).bind(productId).first<{
    product_id: string;
    title: string;
    available_units: number;
    price_minor: number;
    currency: string;
    is_active: number;
    storefront_visible: number;
  }>();

  if (!item) {
    throw new HTTPException(404, { message: 'Product not found in inventory' });
  }

  return c.json({
    success: true,
    data: {
      product_id: item.product_id,
      title: item.title,
      available_units: item.available_units,
      price: item.price_minor / 100.0,
      currency: item.currency,
      in_stock: item.available_units > 0,
      is_active: Boolean(item.is_active),
      storefront_visible: Boolean(item.storefront_visible),
    },
  });
});

// ---------------------------------------------------------------------------
// 2. Cart Endpoints
// ---------------------------------------------------------------------------

commerceRouter.get('/cart', async (c) => {
  const customer = await requireAuth(c);
  const rows = await c.env.DB.prepare(
    `SELECT c.id AS cart_item_id, c.product_id, c.quantity,
            i.title, i.price_minor, i.available_units, i.currency,
            i.is_active, COALESCE(v.is_visible, 1) AS storefront_visible
     FROM cart_items c
     JOIN inventory i ON c.product_id = i.product_id
     LEFT JOIN storefront_product_visibility v ON v.product_id = i.product_id
     WHERE c.customer_id = ?`
  ).bind(customer.id).all();

  const items = (rows.results || []).map((r: any) => {
    const price = r.price_minor / 100.0;
    return {
      id: r.cart_item_id,
      product_id: r.product_id,
      title: r.title,
      quantity: r.quantity,
      price,
      price_when_added: price,
      current_price: price,
      price_changed: false,
      line_total: price * r.quantity,
      in_stock: Boolean(r.is_active && r.storefront_visible && r.available_units >= r.quantity),
      storefront_visible: Boolean(r.storefront_visible),
      available_quantity: r.available_units,
    };
  });

  const totalCount = items.reduce((sum, item) => sum + item.quantity, 0);
  const subtotal = items.reduce((sum, item) => sum + item.line_total, 0);

  return c.json({
    success: true,
    data: {
      id: customer.id,
      items,
      item_count: totalCount,
      subtotal: Math.round(subtotal * 100) / 100,
    },
  });
});

commerceRouter.post('/cart/items', async (c) => {
  const customer = await requireAuth(c);
  const body = await c.req.json().catch(() => null);
  const parsed = CartItemInputSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const db = c.env.DB;
  const inv = await db.prepare(
    `SELECT i.product_id, i.is_active, COALESCE(v.is_visible, 1) AS storefront_visible
     FROM inventory i
     LEFT JOIN storefront_product_visibility v ON v.product_id = i.product_id
     WHERE i.product_id = ?`
  ).bind(parsed.data.product_id).first<{ product_id: string; is_active: number; storefront_visible: number }>();

  if (!inv) {
    throw new HTTPException(404, { message: 'Product does not exist' });
  }
  if (!inv.is_active) {
    throw new HTTPException(422, { message: 'Product is not available for purchase' });
  }
  if (!inv.storefront_visible) {
    throw new HTTPException(422, { message: 'Product is hidden from the storefront' });
  }

  const itemId = crypto.randomUUID();
  await db.prepare(
    `INSERT INTO cart_items (id, customer_id, product_id, quantity, updated_at)
     VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
     ON CONFLICT(customer_id, product_id)
     DO UPDATE SET quantity = quantity + excluded.quantity, updated_at = CURRENT_TIMESTAMP`
  ).bind(itemId, customer.id, parsed.data.product_id, parsed.data.quantity).run();

  return c.json(
    {
      success: true,
      message: 'Item added to cart',
      data: { product_id: parsed.data.product_id, quantity: parsed.data.quantity },
    },
    201
  );
});

commerceRouter.put('/cart/items/:item_id', async (c) => {
  const customer = await requireAuth(c);
  const itemId = c.req.param('item_id');
  const body = await c.req.json().catch(() => null);
  const parsed = CartItemUpdateSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const db = c.env.DB;
  if (parsed.data.quantity <= 0) {
    await db.prepare('DELETE FROM cart_items WHERE (id = ? OR product_id = ?) AND customer_id = ?')
      .bind(itemId, itemId, customer.id)
      .run();
    return c.json({ success: true, data: {}, message: 'Item removed' });
  }

  const item = await db.prepare(
    `SELECT c.id, c.product_id, i.available_units, i.is_active, i.title,
            COALESCE(v.is_visible, 1) AS storefront_visible
     FROM cart_items c
     JOIN inventory i ON c.product_id = i.product_id
     LEFT JOIN storefront_product_visibility v ON v.product_id = i.product_id
     WHERE (c.id = ? OR c.product_id = ?) AND c.customer_id = ?`
  ).bind(itemId, itemId, customer.id).first<{
    id: string;
    product_id: string;
    available_units: number;
    is_active: number;
    title: string;
    storefront_visible: number;
  }>();

  if (!item) {
    throw new HTTPException(404, { message: 'Item not found in cart' });
  }
  if (!item.is_active) {
    throw new HTTPException(422, { message: `Product ${item.title} is inactive` });
  }
  if (!item.storefront_visible) {
    throw new HTTPException(422, { message: `Product ${item.title} is hidden` });
  }
  if (item.available_units < parsed.data.quantity) {
    throw new HTTPException(
      422,
      { message: `Insufficient stock for ${item.title}. Available: ${item.available_units}, requested: ${parsed.data.quantity}` }
    );
  }

  await db.prepare('UPDATE cart_items SET quantity = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
    .bind(parsed.data.quantity, item.id)
    .run();

  return c.json({
    success: true,
    data: { id: item.id, quantity: parsed.data.quantity },
    message: 'Cart updated',
  });
});

commerceRouter.delete('/cart/items/:item_id', async (c) => {
  const customer = await requireAuth(c);
  const itemId = c.req.param('item_id');
  await c.env.DB.prepare('DELETE FROM cart_items WHERE (id = ? OR product_id = ?) AND customer_id = ?')
    .bind(itemId, itemId, customer.id)
    .run();
  return c.json({ success: true, data: {}, message: 'Item removed' });
});

commerceRouter.delete('/cart', async (c) => {
  const customer = await requireAuth(c);
  await c.env.DB.prepare('DELETE FROM cart_items WHERE customer_id = ?').bind(customer.id).run();
  return c.json({ success: true, data: {}, message: 'Cart cleared' });
});

// ---------------------------------------------------------------------------
// 3. Customer Delivery Addresses
// ---------------------------------------------------------------------------

commerceRouter.get('/addresses', async (c) => {
  const customer = await requireAuth(c);
  const rows = await c.env.DB.prepare(
    'SELECT * FROM customer_addresses WHERE customer_id = ? ORDER BY is_default DESC, created_at DESC'
  ).bind(customer.id).all();

  const data = (rows.results || []).map((r: any) => ({
    ...r,
    village_or_city: r.city,
    postal_code: r.pincode,
    is_default: Boolean(r.is_default),
  }));

  return c.json({ success: true, data });
});

commerceRouter.post('/addresses', async (c) => {
  const customer = await requireAuth(c);
  const body = await c.req.json().catch(() => null);
  const parsed = AddressInputSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const db = c.env.DB;
  const addressId = crypto.randomUUID();
  const stmts: D1PreparedStatement[] = [];

  if (parsed.data.is_default) {
    stmts.push(db.prepare('UPDATE customer_addresses SET is_default = 0 WHERE customer_id = ?').bind(customer.id));
  }

  stmts.push(
    db.prepare(
      `INSERT INTO customer_addresses (id, customer_id, recipient_name, phone, address_line1, address_line2, city, state, pincode, district, landmark, is_default)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      addressId,
      customer.id,
      parsed.data.recipient_name.trim(),
      parsed.data.phone.trim(),
      parsed.data.address_line1.trim(),
      parsed.data.address_line2 ? parsed.data.address_line2.trim() : null,
      parsed.data.city.trim(),
      parsed.data.state.trim(),
      parsed.data.pincode.trim(),
      parsed.data.district || '',
      parsed.data.landmark || null,
      parsed.data.is_default ? 1 : 0
    )
  );

  await db.batch(stmts);

  const created = await db.prepare('SELECT * FROM customer_addresses WHERE id = ?').bind(addressId).first();
  return c.json({ success: true, data: created }, 201);
});

commerceRouter.put('/addresses/:address_id', async (c) => {
  const customer = await requireAuth(c);
  const addressId = c.req.param('address_id');
  const db = c.env.DB;

  const existing = await db.prepare(
    'SELECT * FROM customer_addresses WHERE id = ? AND customer_id = ?'
  ).bind(addressId, customer.id).first<any>();

  if (!existing) {
    throw new HTTPException(404, { message: 'Address not found' });
  }

  const raw = await c.req.json().catch(() => ({}));
  const values: Record<string, any> = { ...raw };
  if ('postal_code' in values) values.pincode = values.postal_code;
  if ('village_or_city' in values) values.city = values.village_or_city;

  const merged = { ...existing, ...values };
  const parsed = AddressInputSchema.safeParse(merged);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid address details' });
  }

  const stmts: D1PreparedStatement[] = [];
  if (parsed.data.is_default) {
    stmts.push(db.prepare('UPDATE customer_addresses SET is_default = 0 WHERE customer_id = ?').bind(customer.id));
  }

  stmts.push(
    db.prepare(
      `UPDATE customer_addresses
       SET recipient_name = ?, phone = ?, address_line1 = ?, address_line2 = ?,
           city = ?, state = ?, pincode = ?, is_default = ?, district = ?, landmark = ?
       WHERE id = ? AND customer_id = ?`
    ).bind(
      parsed.data.recipient_name.trim(),
      parsed.data.phone.trim(),
      parsed.data.address_line1.trim(),
      parsed.data.address_line2 ? parsed.data.address_line2.trim() : null,
      parsed.data.city.trim(),
      parsed.data.state.trim(),
      parsed.data.pincode.trim(),
      parsed.data.is_default ? 1 : 0,
      parsed.data.district || '',
      parsed.data.landmark || null,
      addressId,
      customer.id
    )
  );

  await db.batch(stmts);
  const updated = await db.prepare('SELECT * FROM customer_addresses WHERE id = ?').bind(addressId).first<any>();
  return c.json({
    success: true,
    data: {
      ...updated,
      village_or_city: updated?.city,
      postal_code: updated?.pincode,
      is_default: Boolean(updated?.is_default),
    },
  });
});

commerceRouter.delete('/addresses/:address_id', async (c) => {
  const customer = await requireAuth(c);
  const addressId = c.req.param('address_id');
  const db = c.env.DB;

  await db.batch([
    db.prepare("UPDATE orders SET address_id = NULL WHERE address_id = ? AND customer_id = ? AND address_snapshot <> '{}'").bind(addressId, customer.id),
    db.prepare('DELETE FROM customer_addresses WHERE id = ? AND customer_id = ?').bind(addressId, customer.id),
  ]);

  return c.json({ success: true, data: {}, message: 'Address deleted' });
});

// ---------------------------------------------------------------------------
// 4. Delivery Policy & Pincode Lookup
// ---------------------------------------------------------------------------

commerceRouter.get('/pincode/check', async (c) => {
  const pincode = c.req.query('pincode') || '';
  const row = await getDeliveryPolicy(c.env?.DB, pincode);
  if (!row.is_serviceable) {
    return c.json({ ...row, message: 'Cash on delivery is not currently available for this pincode.' });
  }
  return c.json({
    ...row,
    delivery_fee: row.delivery_fee_minor / 100,
    expected_delivery_text: 'Delivery availability is confirmed when your order is reviewed',
    express_available: false,
  });
});

commerceRouter.get('/pincode/lookup', async (c) => {
  const pincode = c.req.query('pincode') || '';
  const row = await c.env.DB.prepare(
    'SELECT city, state FROM serviceable_pincodes WHERE pincode = ?'
  ).bind(pincode).first<{ city: string; state: string }>();

  if (!row) {
    throw new HTTPException(404, { message: 'PIN not in local coverage; enter location manually' });
  }

  const cityLower = row.city.toLowerCase();
  const district = cityLower.includes('noida')
    ? 'Gautam Buddha Nagar'
    : cityLower.includes('delhi')
    ? 'New Delhi'
    : row.city;

  return c.json({ ...row, pincode, district });
});

// ---------------------------------------------------------------------------
// 5. Checkout Quote & Orders Checkout
// ---------------------------------------------------------------------------

const handleCheckoutQuote = async (c: Context<{ Bindings: Env }>) => {
  const customer = await requireAuth(c);
  const body = await c.req.json().catch(() => null);
  const parsed = CheckoutQuoteInputSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const db = c.env.DB;
  if (parsed.data.payment_method !== 'cod') {
    throw new HTTPException(503, { message: 'Online payment is unavailable on this API' });
  }

  if (!parsed.data.delivery_address_id) {
    throw new HTTPException(422, { message: 'Delivery address is required' });
  }

  const address = await verifyDeliveryAddress(db, customer.id, parsed.data.delivery_address_id);
  const coverage = await getDeliveryPolicy(db, address.pincode);

  if (!coverage.cod_available) {
    throw new HTTPException(422, { message: `Cash on delivery is not currently available for pincode ${address.pincode}` });
  }

  const rows = await db.prepare(
    `SELECT c.product_id, c.quantity, i.title, i.price_minor,
            i.available_units, i.currency, i.is_active,
            COALESCE(v.is_visible, 1) AS storefront_visible
     FROM cart_items c
     JOIN inventory i ON c.product_id = i.product_id
     LEFT JOIN storefront_product_visibility v ON v.product_id = i.product_id
     WHERE c.customer_id = ?`
  ).bind(customer.id).all();

  const cartRecords = rows.results || [];
  if (cartRecords.length === 0) {
    throw new HTTPException(422, { message: 'Cart is empty' });
  }

  let subtotalMinor = 0;
  const itemsOut = [];

  for (const r of cartRecords as any[]) {
    if (!r.is_active) {
      throw new HTTPException(422, { message: `Product ${r.title} is inactive` });
    }
    if (!r.storefront_visible) {
      throw new HTTPException(422, { message: `Product ${r.title} is hidden` });
    }
    if (r.available_units < r.quantity) {
      throw new HTTPException(
        422,
        { message: `Insufficient stock for ${r.title}. Available: ${r.available_units}, requested: ${r.quantity}` }
      );
    }
    const lineTotalMinor = r.price_minor * r.quantity;
    subtotalMinor += lineTotalMinor;
    itemsOut.push({
      product_id: r.product_id,
      title: r.title,
      quantity: r.quantity,
      price: r.price_minor / 100.0,
      line_total: lineTotalMinor / 100.0,
    });
  }

  const freeAbove = coverage.free_delivery_above_minor ?? 49900;
  const deliveryFeeMinor = freeAbove != null && subtotalMinor > freeAbove ? 0 : coverage.delivery_fee_minor;
  const subtotal = subtotalMinor / 100.0;
  const deliveryFee = deliveryFeeMinor / 100.0;

  const [appliedCoupon, discount] = await validateCoupon(db, parsed.data.coupon_code, subtotal);
  const totalAmount = Math.round(Math.max(0.0, subtotal + deliveryFee - discount) * 100) / 100;

  return c.json({
    success: true,
    data: {
      subtotal,
      delivery_fee: deliveryFee,
      discount,
      total: totalAmount,
      total_amount: totalAmount,
      coupon_code: appliedCoupon,
      currency: 'INR',
      is_prelaunch_interest: false,
      items: itemsOut,
    },
  });
};

commerceRouter.post('/orders/checkout/quote', handleCheckoutQuote);
commerceRouter.post('/checkout/quote', handleCheckoutQuote);

export async function getOrderDetailsHelper(db: D1Database, orderId: string) {
  const row = await db.prepare('SELECT * FROM orders WHERE id = ?').bind(orderId).first<any>();
  if (!row) {
    throw new HTTPException(404, { message: 'Order not found' });
  }

  const linesRes = await db.prepare('SELECT * FROM order_lines WHERE order_id = ?').bind(orderId).all();
  const lines = linesRes.results || [];

  let timeline: any[] = [];
  try {
    const evRes = await db.prepare(
      'SELECT id, status, title, location, remarks, created_at FROM order_events WHERE order_id = ? ORDER BY created_at ASC'
    ).bind(orderId).all();
    timeline = (evRes.results || []).map((ev: any) => ({
      id: ev.id,
      time: ev.created_at,
      title: ev.title,
      location: ev.location || '',
      remarks: ev.remarks || '',
      status: String(ev.status || '').toUpperCase(),
    }));
  } catch {
    timeline = [];
  }

  let addressSnapshot: any = {};
  try {
    addressSnapshot = row.address_snapshot ? JSON.parse(row.address_snapshot) : {};
  } catch {
    addressSnapshot = {};
  }

  const state = String(row.status || '').toUpperCase();
  return {
    id: row.id,
    status: state,
    payment_status: String(row.payment_status || '').toUpperCase(),
    payment_method: row.payment_method,
    created_at: row.created_at,
    subtotal: row.subtotal_minor / 100,
    delivery_fee: row.delivery_fee_minor / 100,
    discount: row.discount_minor / 100,
    total: row.total_minor / 100,
    total_amount: row.total_minor / 100,
    currency: 'INR',
    is_prelaunch_interest: false,
    is_test_order: Boolean(row.is_test_order),
    address: addressSnapshot,
    items: lines.map((x: any) => ({
      product_id: x.product_id,
      title: x.product_title,
      quantity: x.quantity,
      unit_price: x.unit_price_minor / 100,
      line_total: x.total_minor / 100,
      fulfillment_status: state,
    })),
    carrier: row.carrier || 'Not assigned',
    tracking_number: row.tracking_number || '',
    timeline,
  };
}

const handleCheckout = async (c: Context<{ Bindings: Env }>) => {
  const customer = await requireAuth(c);
  const body = await c.req.json().catch(() => null);
  const parsed = CheckoutInputSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const db = c.env.DB;
  if (parsed.data.payment_method !== 'cod') {
    throw new HTTPException(503, { message: 'Online payment is unavailable on this API' });
  }

  const fingerprint = await checkoutFingerprint(
    customer.id,
    parsed.data.idempotency_key,
    parsed.data.delivery_address_id,
    parsed.data.payment_method,
    parsed.data.coupon_code,
    parsed.data.expected_total
  );

  const existingOrder = await db.prepare(
    'SELECT id, status, payment_status, total_minor, checkout_request_fingerprint FROM orders WHERE customer_id = ? AND idempotency_key = ?'
  ).bind(customer.id, parsed.data.idempotency_key).first<any>();

  if (existingOrder) {
    if (existingOrder.checkout_request_fingerprint !== fingerprint) {
      throw new HTTPException(409, { message: 'Idempotency key was already used for a different checkout request' });
    }
    const details = await getOrderDetailsHelper(db, existingOrder.id);
    return c.json(details, 200);
  }

  const address = await verifyDeliveryAddress(db, customer.id, parsed.data.delivery_address_id);
  const coverage = await getDeliveryPolicy(db, address.pincode);

  if (!coverage.cod_available) {
    throw new HTTPException(422, { message: `Cash on delivery is not currently available for pincode ${address.pincode}` });
  }

  const rows = await db.prepare(
    `SELECT c.product_id, c.quantity, i.title, i.price_minor,
            i.available_units, i.currency,
            COALESCE(v.is_visible, 1) AS storefront_visible
     FROM cart_items c
     JOIN inventory i ON c.product_id = i.product_id
     LEFT JOIN storefront_product_visibility v ON v.product_id = i.product_id
     WHERE c.customer_id = ?`
  ).bind(customer.id).all();

  const cartRecords = rows.results || [];
  if (cartRecords.length === 0) {
    throw new HTTPException(422, { message: 'Cart is empty' });
  }

  const lines: Array<[string, number, number]> = [];
  let subtotalMinor = 0;
  for (const r of cartRecords as any[]) {
    if (!r.storefront_visible) {
      throw new HTTPException(422, { message: `Product ${r.title} is hidden` });
    }
    lines.push([r.product_id, r.quantity, r.price_minor]);
    subtotalMinor += r.price_minor * r.quantity;
  }

  const freeAbove = coverage.free_delivery_above_minor ?? 49900;
  const deliveryFeeMinor = freeAbove != null && subtotalMinor > freeAbove ? 0 : coverage.delivery_fee_minor;
  const subtotal = subtotalMinor / 100.0;

  const [appliedCoupon, discount] = await validateCoupon(db, parsed.data.coupon_code, subtotal);
  const discountMinor = Math.round(discount * 100);
  const totalMinor = Math.max(0, subtotalMinor + deliveryFeeMinor - discountMinor);

  if (parsed.data.expected_total != null) {
    const expectedMinor = Math.round(parsed.data.expected_total * 100);
    if (Math.abs(expectedMinor - totalMinor) > 1) {
      throw new HTTPException(
        422,
        { message: `Checkout total mismatch: calculated ₹${(totalMinor / 100).toFixed(2)}, expected ₹${parsed.data.expected_total.toFixed(2)}` }
      );
    }
  }

  const reservationId = crypto.randomUUID();
  const orderId = crypto.randomUUID();
  const hashVal = await canonicalPayloadHash(customer.id, lines);

  const statements: D1PreparedStatement[] = [];

  // Step A: Insert Reservation
  statements.push(
    db.prepare(
      `INSERT INTO reservations (id, customer_id, idempotency_key, payload_sha256, expected_lines, status)
       VALUES (?, ?, ?, ?, ?, 'CREATING')`
    ).bind(reservationId, customer.id, parsed.data.idempotency_key, hashVal, lines.length)
  );

  // Step B: Insert Reservation Lines
  for (const [pId, qty, priceMinor] of normalizeLines(lines)) {
    statements.push(
      db.prepare(
        `INSERT INTO reservation_lines (reservation_id, product_id, quantity, unit_price_minor, currency)
         VALUES (?, ?, ?, ?, 'INR')`
      ).bind(reservationId, pId, qty, priceMinor)
    );
  }

  // Step C: Insert Reservation Seal
  statements.push(
    db.prepare('INSERT INTO reservation_seals (reservation_id) VALUES (?)').bind(reservationId)
  );

  // Step D: Insert Order
  const isTestOrder = c.env.ENVIRONMENT === 'test' ? 1 : 0;
  statements.push(
    db.prepare(
      `INSERT INTO orders (id, customer_id, reservation_id, idempotency_key, checkout_request_fingerprint,
                           address_id, subtotal_minor, delivery_fee_minor, discount_minor, total_minor,
                           currency, status, payment_status, payment_method, is_test_order)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'INR', 'confirmed', 'pending', ?, ?)`
    ).bind(
      orderId,
      customer.id,
      reservationId,
      parsed.data.idempotency_key,
      fingerprint,
      parsed.data.delivery_address_id,
      subtotalMinor,
      deliveryFeeMinor,
      discountMinor,
      totalMinor,
      parsed.data.payment_method,
      isTestOrder
    )
  );

  // Step E: Insert Order Lines
  for (const r of cartRecords as any[]) {
    const lineId = crypto.randomUUID();
    statements.push(
      db.prepare(
        `INSERT INTO order_lines (id, order_id, product_id, product_title, quantity, unit_price_minor, total_minor, currency)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'INR')`
      ).bind(
        lineId,
        orderId,
        r.product_id,
        r.title,
        r.quantity,
        r.price_minor,
        r.price_minor * r.quantity
      )
    );
  }

  // Step F: Clear Cart & update coupon usage
  statements.push(db.prepare('DELETE FROM cart_items WHERE customer_id = ?').bind(customer.id));
  if (appliedCoupon) {
    statements.push(db.prepare('UPDATE coupons SET usage_count = usage_count + 1 WHERE code = ?').bind(appliedCoupon));
  }

  // Step G: Event
  statements.push(
    db.prepare(
      `INSERT INTO order_events (id, order_id, status, title, location, remarks)
       VALUES (?, ?, 'CONFIRMED', 'Order Placed & Confirmed', 'Online Store', 'Your order has been received and verified for fulfillment.')`
    ).bind(crypto.randomUUID(), orderId)
  );

  try {
    await db.batch(statements);
  } catch (err: any) {
    const errMsg = String(err.message || err);
    if (errMsg.toLowerCase().includes('insufficient stock')) {
      throw new HTTPException(422, { message: 'Insufficient stock for one or more items' });
    }
    if (errMsg.toLowerCase().includes('price changed')) {
      throw new HTTPException(422, { message: 'Price changed; please refresh your cart' });
    }
    if (errMsg.toLowerCase().includes('unique')) {
      const winner = await db.prepare(
        'SELECT id, checkout_request_fingerprint FROM orders WHERE customer_id = ? AND idempotency_key = ?'
      ).bind(customer.id, parsed.data.idempotency_key).first<any>();
      if (winner) {
        if (winner.checkout_request_fingerprint !== fingerprint) {
          throw new HTTPException(409, { message: 'Idempotency conflict' });
        }
        const details = await getOrderDetailsHelper(db, winner.id);
        return c.json(details, 200);
      }
    }
    throw new HTTPException(500, { message: `Order placement failed: ${errMsg}` });
  }

  const details = await getOrderDetailsHelper(db, orderId);
  return c.json(details, 201);
};

commerceRouter.post('/orders/checkout', handleCheckout);
commerceRouter.post('/checkout', handleCheckout);

// ---------------------------------------------------------------------------
// 6. Orders Listing, Details, & Cancellation
// ---------------------------------------------------------------------------

commerceRouter.get('/orders/payment-capabilities', (c) => {
  return c.json({
    success: true,
    data: {
      is_prelaunch_interest: false,
      online_payment_available: false,
      test_mode: c.env?.ENVIRONMENT === 'test',
    },
  });
});

commerceRouter.get('/orders', async (c) => {
  const customer = await requireAuth(c);
  const rows = await c.env.DB.prepare(
    'SELECT * FROM orders WHERE customer_id = ? ORDER BY created_at DESC LIMIT 100'
  ).bind(customer.id).all();

  const data = await Promise.all((rows.results || []).map((r: any) => getOrderDetailsHelper(c.env.DB, r.id)));
  return c.json({ success: true, data });
});

commerceRouter.get('/orders/operations', async (c) => {
  await requireAuth(c, ['admin', 'vendor', 'super_admin']);
  const rows = await c.env.DB.prepare(
    "SELECT * FROM orders WHERE status != 'cancelled' ORDER BY created_at DESC LIMIT 100"
  ).all();

  const data = await Promise.all((rows.results || []).map((r: any) => getOrderDetailsHelper(c.env.DB, r.id)));
  return c.json({ success: true, data });
});

commerceRouter.get('/orders/:order_id', async (c) => {
  const customer = await requireAuth(c);
  const orderId = c.req.param('order_id');
  const db = c.env.DB;

  let row: any;
  if (['admin', 'vendor', 'super_admin'].includes(customer.role)) {
    row = await db.prepare('SELECT * FROM orders WHERE id = ?').bind(orderId).first();
  } else {
    row = await db.prepare('SELECT * FROM orders WHERE id = ? AND customer_id = ?').bind(orderId, customer.id).first();
  }

  if (!row) {
    throw new HTTPException(404, { message: 'Order not found' });
  }

  const data = await getOrderDetailsHelper(db, orderId);
  return c.json({ success: true, data });
});

commerceRouter.post('/orders/:order_id/cancel', async (c) => {
  const customer = await requireAuth(c);
  const orderId = c.req.param('order_id');
  const db = c.env.DB;

  const orderRow = await db.prepare(
    'SELECT id, customer_id, status, payment_status, reservation_id FROM orders WHERE id = ?'
  ).bind(orderId).first<{
    id: string;
    customer_id: string;
    status: string;
    payment_status: string;
    reservation_id: string | null;
  }>();

  if (!orderRow) {
    throw new HTTPException(404, { message: 'Order not found' });
  }
  if (orderRow.customer_id !== customer.id && !['admin', 'super_admin'].includes(customer.role)) {
    throw new HTTPException(403, { message: 'Access denied' });
  }
  if (orderRow.status === 'cancelled') {
    throw new HTTPException(400, { message: 'Order is already cancelled' });
  }
  if (!['placed', 'confirmed'].includes(orderRow.status)) {
    throw new HTTPException(400, { message: `Cannot cancel order in '${orderRow.status}' status` });
  }
  if (orderRow.payment_status !== 'pending') {
    throw new HTTPException(409, { message: 'Payment must be reconciled before cancellation' });
  }

  const linesRes = await db.prepare('SELECT product_id, quantity FROM order_lines WHERE order_id = ?').bind(orderId).all();
  const stmts: D1PreparedStatement[] = [
    db.prepare("UPDATE orders SET status = 'cancelled' WHERE id = ?").bind(orderId),
  ];

  if (orderRow.reservation_id) {
    stmts.push(db.prepare("UPDATE reservations SET status = 'CANCELLED' WHERE id = ?").bind(orderRow.reservation_id));
  }

  for (const l of linesRes.results || []) {
    stmts.push(
      db.prepare(
        'UPDATE inventory SET available_units = available_units + ?, updated_at = CURRENT_TIMESTAMP WHERE product_id = ?'
      ).bind(l.quantity, l.product_id)
    );
  }

  stmts.push(
    db.prepare(
      `INSERT INTO order_events (id, order_id, status, title, location, remarks)
       VALUES (?, ?, 'CANCELLED', 'Order Cancelled', '', 'Order cancelled and reserved stock restored.')`
    ).bind(crypto.randomUUID(), orderId)
  );

  await db.batch(stmts);
  return c.json({ success: true, message: 'Order cancelled' });
});

// ---------------------------------------------------------------------------
// 7. Coupons Listing & Quote
// ---------------------------------------------------------------------------

commerceRouter.get('/coupons', async (c) => {
  await requireAuth(c);
  const rows = await c.env.DB.prepare('SELECT * FROM coupons WHERE is_active = 1').all();
  const data = (rows.results || [])
    .filter((r: any) => !isCouponExpired(r.valid_until))
    .map((r: any) => ({
      ...r,
      id: r.code,
      is_active: Boolean(r.is_active),
      usage_count: r.usage_count || 0,
    }));
  return c.json({ success: true, data });
});

commerceRouter.post('/coupons/quote', async (c) => {
  const customer = await requireAuth(c);
  const body = await c.req.json().catch(() => null);
  const parsed = CouponQuoteInputSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const db = c.env.DB;
  const rows = await db.prepare(
    `SELECT c.quantity, i.price_minor, i.available_units, i.is_active,
            COALESCE(v.is_visible, 1) AS storefront_visible
     FROM cart_items c JOIN inventory i ON i.product_id = c.product_id
     LEFT JOIN storefront_product_visibility v ON v.product_id = i.product_id
     WHERE c.customer_id = ?`
  ).bind(customer.id).all();

  const items = rows.results || [];
  if (items.length === 0) {
    throw new HTTPException(422, { message: 'Cart is empty' });
  }

  const subtotal = items.reduce((sum: number, it: any) => sum + (it.quantity * it.price_minor) / 100.0, 0);
  const [code, discount] = await validateCoupon(db, parsed.data.code, subtotal);
  const coupon = await db.prepare('SELECT * FROM coupons WHERE code = ?').bind(code).first<any>();

  return c.json({
    success: true,
    data: {
      coupon: { ...coupon, id: coupon.code, is_active: Boolean(coupon.is_active) },
      subtotal,
      discount,
      total: Math.round((subtotal - discount) * 100) / 100,
    },
  });
});

// ---------------------------------------------------------------------------
// 8. Batch Certificates & Merchandising Placements
// ---------------------------------------------------------------------------

commerceRouter.get('/certificates', async (c) => {
  const rows = await c.env.DB.prepare(
    `SELECT b.*, i.title AS product_title FROM batch_certificates b
     JOIN inventory i ON i.product_id = b.product_id WHERE b.status = 'CERTIFIED'
     ORDER BY b.test_date DESC`
  ).all();

  return c.json({
    success: true,
    data: rows.results || [],
  });
});

commerceRouter.get('/merchandising/placements', async (c) => {
  const db = c.env.DB;
  const rows = (await db.prepare(
    `SELECT c.*, i.title AS product_title, i.price_minor, i.available_units,
            i.is_active AS product_active, p.mrp_minor, v.pack_size,
            COALESCE(sv.is_visible, 1) AS storefront_visible
     FROM storefront_campaigns c
     JOIN inventory i ON i.product_id = c.product_id
     LEFT JOIN inventory_pricing p ON p.product_id = c.product_id
     LEFT JOIN product_family_variants v ON v.id = c.product_id
     LEFT JOIN storefront_product_visibility sv ON sv.product_id = c.product_id
     WHERE c.is_active = 1 AND i.is_active = 1 AND COALESCE(sv.is_visible, 1) = 1
       AND (c.starts_at IS NULL OR datetime(c.starts_at) <= datetime('now'))
       AND (c.ends_at IS NULL OR datetime(c.ends_at) > datetime('now'))
     ORDER BY c.priority DESC, c.created_at DESC`
  ).all()).results || [];

  const data = [];
  for (const row of rows as any[]) {
    let coupon: any = null;
    if (row.coupon_code) {
      coupon = await db.prepare('SELECT * FROM coupons WHERE code = ? AND is_active = 1').bind(String(row.coupon_code).trim().toUpperCase()).first();
    }
    const price = (Number(row.price_minor || 0) / 100.0);
    const mrp = row.mrp_minor !== null && row.mrp_minor !== undefined ? (Number(row.mrp_minor) / 100.0) : null;
    data.push({
      id: String(row.id),
      product_id: String(row.product_id),
      placement_type: String(row.placement_type || 'highlight'),
      headline: String(row.headline || ''),
      subheadline: row.subheadline || null,
      badge: row.badge || null,
      starts_at: row.starts_at || null,
      ends_at: row.ends_at || null,
      priority: Number(row.priority ?? 100),
      is_active: Boolean(row.is_active === 1),
      product: {
        id: String(row.product_id),
        product_id: String(row.product_id),
        vendor_id: 'vendor-1',
        title: String(row.product_title || ''),
        category: 'FEED_NUTRITION',
        base_price: price,
        price: price,
        compare_at_price: mrp,
        unit: 'pack',
        pack_size: row.pack_size || '',
        description: row.product_title || '',
        available_quantity: Number(row.available_units || 0),
        available_units: Number(row.available_units || 0),
        min_order_quantity: 1,
        in_stock: Boolean((row.available_units ?? 0) > 0 && row.product_active === 1),
        is_active: Boolean(row.product_active === 1),
        storefront_visible: Boolean(row.storefront_visible === 1),
        publication_status: 'published',
        media: [],
        specifications: {},
        taxonomy: null,
        vendor: { id: 'vendor-1', business_name: 'Milterra Central Operations' },
      },
      coupon: coupon ? {
        code: coupon.code,
        description: coupon.description || '',
        discount_type: coupon.discount_type,
        discount_value: coupon.discount_value,
        min_order_value: coupon.min_order_value || 0,
        max_discount_cap: coupon.max_discount_cap,
        is_active: coupon.is_active === 1,
      } : null,
    });
  }

  return c.json({
    success: true,
    data,
  });
});

// ---------------------------------------------------------------------------
// 9. Loyalty & Referrals
// ---------------------------------------------------------------------------

commerceRouter.get('/loyalty/balance', async (c) => {
  const customer = await requireAuth(c);
  let points = 0;
  let history: any[] = [];

  try {
    const balRow = await c.env.DB.prepare(
      'SELECT points_balance FROM customer_loyalty_balance WHERE customer_id = ?'
    ).bind(customer.id).first<{ points_balance: number }>();
    points = balRow ? balRow.points_balance : 0;

    const histRows = await c.env.DB.prepare(
      'SELECT * FROM customer_loyalty_ledger WHERE customer_id = ? ORDER BY created_at DESC LIMIT 50'
    ).bind(customer.id).all();
    history = histRows.results || [];
  } catch {
    // Return empty on table missing
  }

  return c.json({
    success: true,
    data: {
      customer_id: customer.id,
      points_balance: points,
      rupee_value: points * 0.1, // ₹1 for 10 points
      history,
    },
  });
});

commerceRouter.get('/referral/me', async (c) => {
  const customer = await requireAuth(c);
  const cleaned = customer.phone.replace(/\D/g, '').slice(-4) || 'MILT';
  const h = (await sha256Hex(`${customer.id}-${customer.phone}`)).substring(0, 4).toUpperCase();
  const code = `MILT-${cleaned}-${h}`;

  let referralsCount = 0;
  let totalEarned = 0;

  try {
    const countRow = await c.env.DB.prepare(
      'SELECT COUNT(*) as cnt, COALESCE(SUM(reward_points), 0) as total_earned FROM customer_referrals WHERE referrer_customer_id = ?'
    ).bind(customer.id).first<any>();
    if (countRow) {
      referralsCount = Number(countRow.cnt || 0);
      totalEarned = Number(countRow.total_earned || 0);
    }
  } catch {
    // ignore
  }

  return c.json({
    success: true,
    data: {
      referral_code: code,
      referral_url: `https://milterrafoods.com/?ref=${code}`,
      reward_points_per_friend: 100,
      reward_rupees_per_friend: 100.0,
      total_referrals_completed: referralsCount,
      total_points_earned: totalEarned,
      share_message: `Join me on Milterra Foods for 100% pure A2 Vedic Bilona Ghee & Dairy! Use code ${code} to get ₹100 / 100 Loyalty Points off your first order: https://milterrafoods.com/?ref=${code}`,
    },
  });
});

// ---------------------------------------------------------------------------
// 10. Customer Subscriptions
// ---------------------------------------------------------------------------

const SubscriptionCreateSchema = z.object({
  product_id: z.string().min(1),
  delivery_address_id: z.string().min(1),
  frequency: z.enum(['daily', 'alternateDays', 'weekly', 'custom']),
  custom_days: z.string().nullable().optional(),
  quantity: z.number().int().min(1),
  start_date: z.string().min(1),
  payment_mode: z.enum(['cod', 'prepaid']).default('cod'),
});

const SubscriptionPauseSchema = z.object({
  pause_start_date: z.string().min(1),
  pause_end_date: z.string().min(1),
});

commerceRouter.get('/subscriptions', async (c) => {
  const customer = await requireAuth(c);
  const rows = await c.env.DB.prepare(
    `SELECT s.*, i.title as product_title, i.price_minor
     FROM customer_subscriptions s
     LEFT JOIN inventory i ON i.product_id = s.product_id
     WHERE s.customer_id = ?
     ORDER BY s.created_at DESC`
  ).bind(customer.id).all();

  return c.json({ success: true, data: rows.results || [] });
});

commerceRouter.post('/subscriptions', async (c) => {
  const customer = await requireAuth(c);
  const body = await c.req.json().catch(() => null);
  const parsed = SubscriptionCreateSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const prod = await c.env.DB.prepare('SELECT product_id, title FROM inventory WHERE product_id = ?')
    .bind(parsed.data.product_id)
    .first<{ product_id: string; title: string }>();

  if (!prod) {
    throw new HTTPException(404, { message: 'Product not found in catalogue' });
  }

  const subId = `sub-${crypto.randomUUID()}`;
  await c.env.DB.prepare(
    `INSERT INTO customer_subscriptions (id, customer_id, product_id, delivery_address_id, frequency, custom_days, quantity, status, start_date, payment_mode)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)`
  ).bind(
    subId,
    customer.id,
    parsed.data.product_id,
    parsed.data.delivery_address_id,
    parsed.data.frequency,
    parsed.data.custom_days || null,
    parsed.data.quantity,
    parsed.data.start_date,
    parsed.data.payment_mode
  ).run();

  return c.json({
    success: true,
    message: `Subscription for ${prod.title} created successfully!`,
    data: {
      id: subId,
      product_title: prod.title,
      frequency: parsed.data.frequency,
      status: 'active',
      start_date: parsed.data.start_date,
    },
  });
});

commerceRouter.put('/subscriptions/:sub_id/pause', async (c) => {
  const customer = await requireAuth(c);
  const subId = c.req.param('sub_id');
  const body = await c.req.json().catch(() => null);
  const parsed = SubscriptionPauseSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const sub = await c.env.DB.prepare('SELECT id FROM customer_subscriptions WHERE id = ? AND customer_id = ?')
    .bind(subId, customer.id)
    .first();

  if (!sub) {
    throw new HTTPException(404, { message: 'Subscription not found' });
  }

  await c.env.DB.prepare(
    "UPDATE customer_subscriptions SET status = 'paused', pause_start_date = ?, pause_end_date = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
  ).bind(parsed.data.pause_start_date, parsed.data.pause_end_date, subId).run();

  return c.json({ success: true, message: 'Subscription paused successfully' });
});

commerceRouter.put('/subscriptions/:sub_id/resume', async (c) => {
  const customer = await requireAuth(c);
  const subId = c.req.param('sub_id');

  const sub = await c.env.DB.prepare('SELECT id FROM customer_subscriptions WHERE id = ? AND customer_id = ?')
    .bind(subId, customer.id)
    .first();

  if (!sub) {
    throw new HTTPException(404, { message: 'Subscription not found' });
  }

  await c.env.DB.prepare(
    "UPDATE customer_subscriptions SET status = 'active', pause_start_date = NULL, pause_end_date = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
  ).bind(subId).run();

  return c.json({ success: true, message: 'Subscription resumed successfully' });
});

commerceRouter.delete('/subscriptions/:sub_id', async (c) => {
  const customer = await requireAuth(c);
  const subId = c.req.param('sub_id');

  const sub = await c.env.DB.prepare('SELECT id FROM customer_subscriptions WHERE id = ? AND customer_id = ?')
    .bind(subId, customer.id)
    .first();

  if (!sub) {
    throw new HTTPException(404, { message: 'Subscription not found' });
  }

  await c.env.DB.prepare(
    "UPDATE customer_subscriptions SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP WHERE id = ?"
  ).bind(subId).run();

  return c.json({ success: true, message: 'Subscription cancelled successfully' });
});

// ---------------------------------------------------------------------------
// 11. Purity Batch Verification
// ---------------------------------------------------------------------------

commerceRouter.get('/purity/verify/:batch_number', async (c) => {
  const batchNumber = c.req.param('batch_number').trim();
  const row = await c.env.DB.prepare(
    `SELECT b.*, i.title as product_title
     FROM product_batch_reports b
     LEFT JOIN inventory i ON i.product_id = b.product_id
     WHERE UPPER(b.batch_number) = UPPER(?)`
  ).bind(batchNumber).first<any>();

  if (!row) {
    throw new HTTPException(404, { message: 'Batch report not found. Please check the batch number printed on your Milterra packaging.' });
  }

  return c.json({ success: true, data: row });
});
