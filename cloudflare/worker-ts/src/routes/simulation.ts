import { Hono, type Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';

export const simulationRouter = new Hono<{ Bindings: Env }>();

const SIMULATED_CARRIER = 'Milterra Test Courier (SIMULATED)';

function requireSimulation(c: Context<{ Bindings: Env }>): void {
  const isTest = c.env?.ENVIRONMENT === 'test';
  if (!isTest) {
    throw new HTTPException(404, { message: 'Not found' });
  }
}

async function adminTestOrder(orderId: string, c: Context<{ Bindings: Env }>) {
  requireSimulation(c);
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;
  const order = await db.prepare('SELECT * FROM orders WHERE id = ? AND is_test_order = 1')
    .bind(orderId)
    .first<any>();

  if (!order) {
    throw new HTTPException(404, { message: 'Test order not found' });
  }
  return { db, order };
}

async function activeReturn(db: D1Database, orderId: string): Promise<boolean> {
  const row = await db.prepare("SELECT id FROM order_return_cases WHERE order_id = ? AND status != 'rejected'")
    .bind(orderId)
    .first();
  return Boolean(row);
}

const CourierEventSchema = z.object({
  event: z.enum(['OUT_FOR_DELIVERY', 'DELIVERED', 'DELIVERY_FAILED']),
  reason: z.string().max(300).default(''),
});

const SimulatedRefundSchema = z.object({
  restock_inventory: z.boolean().default(true),
  remarks: z.string().max(800).default(''),
});

// POST /api/v1/marketplace/orders/admin/simulator/:order_id/dispatch
simulationRouter.post('/:order_id/dispatch', async (c) => {
  const orderId = c.req.param('order_id');
  const { db, order } = await adminTestOrder(orderId, c);

  if (order.status !== 'packed' || (await activeReturn(db, orderId))) {
    throw new HTTPException(409, { message: 'Only a packed test order without a return case can be dispatched' });
  }

  const tracking = 'SIM-AWB-' + crypto.randomUUID().replace(/-/g, '').substring(0, 16).toUpperCase();
  const now = new Date().toISOString();

  await db.batch([
    db.prepare(
      `UPDATE orders SET status = 'shipped', carrier = ?, tracking_number = ?, dispatched_at = ?
       WHERE id = ? AND is_test_order = 1`
    ).bind(SIMULATED_CARRIER, tracking, now, orderId),
    db.prepare(
      `INSERT INTO order_events (id, order_id, status, title, remarks)
       VALUES (?, ?, 'SHIPPED', '[SIMULATED] Courier dispatch', ?)`
    ).bind(crypto.randomUUID(), orderId, `No parcel booked. Test tracking number: ${tracking}`),
  ]);

  const updated = await db.prepare('SELECT * FROM orders WHERE id = ?').bind(orderId).first();
  return c.json({ success: true, simulated: true, data: updated });
});

// POST /api/v1/marketplace/orders/admin/simulator/:order_id/event
simulationRouter.post('/:order_id/event', async (c) => {
  const orderId = c.req.param('order_id');
  const body = await c.req.json().catch(() => null);
  const parsed = CourierEventSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const { db, order } = await adminTestOrder(orderId, c);
  if (order.carrier !== SIMULATED_CARRIER || (await activeReturn(db, orderId))) {
    throw new HTTPException(409, { message: 'An active simulated shipment without a return case is required' });
  }

  const current = order.status;
  const statements: D1PreparedStatement[] = [];
  let title = '';

  if (parsed.data.event === 'OUT_FOR_DELIVERY') {
    if (current !== 'shipped') {
      throw new HTTPException(409, { message: 'Shipment must be dispatched first' });
    }
    statements.push(db.prepare("UPDATE orders SET status = 'out_for_delivery' WHERE id = ?").bind(orderId));
    title = '[SIMULATED] Out for delivery';
  } else if (parsed.data.event === 'DELIVERED') {
    if (!['shipped', 'out_for_delivery'].includes(current)) {
      throw new HTTPException(409, { message: 'Shipment is not in transit' });
    }
    statements.push(
      db.prepare("UPDATE orders SET status = 'delivered', delivered_at = ? WHERE id = ?").bind(
        new Date().toISOString(),
        orderId
      )
    );
    title = '[SIMULATED] Delivered';
  } else {
    if (!['shipped', 'out_for_delivery'].includes(current)) {
      throw new HTTPException(409, { message: 'Only an in-transit shipment can fail delivery' });
    }
    if (parsed.data.reason.trim().length < 5) {
      throw new HTTPException(422, { message: 'Give a delivery failure reason' });
    }
    statements.push(
      db.prepare(
        `INSERT INTO order_return_cases (id, order_id, kind, reason, remarks)
         VALUES (?, ?, 'rto', ?, 'Simulated courier failure')`
      ).bind(crypto.randomUUID(), orderId, parsed.data.reason.trim())
    );
    title = '[SIMULATED] Delivery failed; return to sender';
  }

  statements.push(
    db.prepare(
      `INSERT INTO order_events (id, order_id, status, title, remarks)
       VALUES (?, ?, ?, ?, ?)`
    ).bind(crypto.randomUUID(), orderId, parsed.data.event, title, 'No courier was contacted. ' + parsed.data.reason.trim())
  );

  await db.batch(statements);
  const updated = await db.prepare('SELECT * FROM orders WHERE id = ?').bind(orderId).first();
  return c.json({ success: true, simulated: true, data: updated });
});

// POST /api/v1/marketplace/orders/admin/simulator/:order_id/collect
simulationRouter.post('/:order_id/collect', async (c) => {
  const orderId = c.req.param('order_id');
  const { db, order } = await adminTestOrder(orderId, c);

  if (order.payment_method !== 'cod' || order.status !== 'delivered' || (await activeReturn(db, orderId))) {
    throw new HTTPException(409, { message: 'Only a delivered COD test order without a return case can be collected' });
  }
  if (order.carrier !== SIMULATED_CARRIER) {
    throw new HTTPException(409, { message: 'A simulated courier delivery is required' });
  }
  if (order.payment_status !== 'pending') {
    throw new HTTPException(409, { message: 'Test COD is no longer pending' });
  }

  const reference = 'SIM-COD-' + crypto.randomUUID().replace(/-/g, '').toUpperCase();
  await db.batch([
    db.prepare("UPDATE orders SET payment_status = 'paid', remittance_reference = ? WHERE id = ?").bind(reference, orderId),
    db.prepare(
      `INSERT INTO simulated_money_movements (id, order_id, kind, amount_minor, reference)
       VALUES (?, ?, 'cod_collection', ?, ?)`
    ).bind(crypto.randomUUID(), orderId, order.total_minor, reference),
    db.prepare(
      `INSERT INTO order_events (id, order_id, status, title, remarks)
       VALUES (?, ?, 'PAID', '[SIMULATED] COD collection', ?)`
    ).bind(crypto.randomUUID(), orderId, 'No cash collected. Test reference: ' + reference),
  ]);

  const updated = await db.prepare('SELECT * FROM orders WHERE id = ?').bind(orderId).first();
  return c.json({ success: true, simulated: true, reference, data: updated });
});

// POST /api/v1/marketplace/orders/admin/simulator/:order_id/refund
simulationRouter.post('/:order_id/refund', async (c) => {
  const orderId = c.req.param('order_id');
  const body = await c.req.json().catch(() => null);
  const parsed = SimulatedRefundSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const { db, order } = await adminTestOrder(orderId, c);
  const caseRow = await db.prepare('SELECT * FROM order_return_cases WHERE order_id = ?').bind(orderId).first<any>();
  const capture = await db.prepare(
    "SELECT id FROM simulated_money_movements WHERE order_id = ? AND kind = 'cod_collection'"
  ).bind(orderId).first();

  if (
    order.payment_method !== 'cod' ||
    order.status !== 'delivered' ||
    order.payment_status !== 'paid' ||
    !capture ||
    !caseRow ||
    caseRow.kind !== 'customer_return' ||
    caseRow.status !== 'requested'
  ) {
    throw new HTTPException(409, { message: 'A paid simulated COD order with a requested customer return is required' });
  }

  const reference = 'SIM-REFUND-' + crypto.randomUUID().replace(/-/g, '').toUpperCase();
  const statements: D1PreparedStatement[] = [
    db.prepare(
      `UPDATE order_return_cases SET status = 'received', remarks = ?, refund_reference = ?,
       restocked = ?, resolved_at = CURRENT_TIMESTAMP WHERE id = ?`
    ).bind(parsed.data.remarks.trim(), reference, parsed.data.restock_inventory ? 1 : 0, caseRow.id),
    db.prepare("UPDATE orders SET payment_status = 'refunded' WHERE id = ?").bind(orderId),
  ];

  if (parsed.data.restock_inventory) {
    const linesRes = await db.prepare('SELECT product_id, quantity FROM order_lines WHERE order_id = ?').bind(orderId).all();
    for (const line of linesRes.results || []) {
      statements.push(
        db.prepare(
          'UPDATE inventory SET available_units = available_units + ?, updated_at = CURRENT_TIMESTAMP WHERE product_id = ?'
        ).bind(line.quantity, line.product_id)
      );
    }
    if (order.reservation_id) {
      statements.push(db.prepare("UPDATE reservations SET status = 'CANCELLED' WHERE id = ?").bind(order.reservation_id));
    }
  }

  statements.push(
    db.prepare(
      `INSERT INTO simulated_money_movements (id, order_id, kind, amount_minor, reference)
       VALUES (?, ?, 'cod_refund', ?, ?)`
    ).bind(crypto.randomUUID(), orderId, order.total_minor, reference),
    db.prepare(
      `INSERT INTO order_events (id, order_id, status, title, remarks)
       VALUES (?, ?, 'REFUNDED', '[SIMULATED] COD refund', ?)`
    ).bind(crypto.randomUUID(), orderId, 'No money transferred. Test reference: ' + reference)
  );

  await db.batch(statements);
  const updated = await db.prepare('SELECT * FROM orders WHERE id = ?').bind(orderId).first();
  return c.json({ success: true, simulated: true, reference, data: updated });
});

// GET /api/v1/marketplace/orders/admin/simulator/:order_id/ledger
simulationRouter.get('/:order_id/ledger', async (c) => {
  const orderId = c.req.param('order_id');
  const { db } = await adminTestOrder(orderId, c);
  const rows = await db.prepare(
    'SELECT kind, amount_minor, reference, created_at FROM simulated_money_movements WHERE order_id = ? ORDER BY created_at'
  ).bind(orderId).all();

  const data = (rows.results || []).map((row: any) => ({
    ...row,
    amount: row.amount_minor / 100,
    currency: 'INR',
  }));

  return c.json({ success: true, simulated: true, data });
});
