import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth, getOrderDetailsHelper } from './commerce.js';

export const operationsRouter = new Hono<{ Bindings: Env }>();

const VALID_FULFILLMENT_TRANSITIONS: Record<string, Set<string>> = {
  pending: new Set(['confirmed', 'packed', 'shipped', 'cancelled']),
  placed: new Set(['confirmed', 'packed', 'shipped', 'cancelled']),
  created: new Set(['confirmed', 'packed', 'shipped', 'cancelled']),
  confirmed: new Set(['packed', 'shipped', 'cancelled']),
  packed: new Set(['shipped', 'out_for_delivery', 'delivered', 'cancelled']),
  shipped: new Set(['shipped', 'out_for_delivery', 'delivered']),
  dispatched: new Set(['shipped', 'out_for_delivery', 'delivered']),
  out_for_delivery: new Set(['delivered']),
  delivered: new Set(),
  cancelled: new Set(),
};

const FulfillmentUpdateSchema = z.object({
  status: z.enum(['CONFIRMED', 'PACKED', 'SHIPPED', 'DISPATCHED', 'OUT_FOR_DELIVERY', 'DELIVERED', 'confirmed', 'packed', 'shipped', 'dispatched', 'out_for_delivery', 'delivered']),
  carrier: z.string().default(''),
  tracking_number: z.string().default(''),
  location: z.string().default(''),
  remarks: z.string().default(''),
});

const CodSettlementSchema = z.object({
  remittance_reference: z.string().min(3).max(100),
});

const ReturnReasonSchema = z.object({
  reason: z.string().min(5).max(300),
  remarks: z.string().max(800).default('').optional(),
});

const ReturnResolutionSchema = z.object({
  action: z.enum(['confirm_received_refund', 'confirm_received', 'reject']),
  refund_reference: z.string().max(100).default('').optional(),
  remarks: z.string().max(800).default('').optional(),
  restock_inventory: z.boolean().default(true).optional(),
});

// ---------------------------------------------------------------------------
// 1. Order Fulfillment Transitions
// ---------------------------------------------------------------------------

operationsRouter.put('/orders/operations/:order_id', async (c) => {
  await requireAuth(c, ['admin', 'vendor', 'super_admin']);
  const orderId = c.req.param('order_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = FulfillmentUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid fulfillment details' });
  }

  const order = await db.prepare('SELECT * FROM orders WHERE id = ?').bind(orderId).first<any>();
  if (!order) {
    throw new HTTPException(404, { message: 'Order not found' });
  }

  const currentStatus = (order.status || '').toLowerCase();
  if (currentStatus === 'cancelled') {
    throw new HTTPException(409, { message: 'Cannot fulfill a cancelled order' });
  }
  if (currentStatus === 'delivered') {
    throw new HTTPException(409, { message: 'Order is already delivered and cannot be modified' });
  }

  const activeReturn = await db.prepare(
    "SELECT id FROM order_return_cases WHERE order_id = ? AND status != 'rejected'"
  ).bind(orderId).first();
  if (activeReturn) {
    throw new HTTPException(409, { message: 'Order has an active return or failed-delivery case' });
  }

  const rawTarget = parsed.data.status.toUpperCase();
  const targetLower = ['SHIPPED', 'DISPATCHED'].includes(rawTarget) ? 'shipped' : rawTarget.toLowerCase();

  const validTargets = VALID_FULFILLMENT_TRANSITIONS[currentStatus] || new Set();
  if (!validTargets.has(targetLower)) {
    throw new HTTPException(
      409,
      { message: `Cannot transition order from '${currentStatus}' to '${targetLower}'. Valid next states: ${Array.from(validTargets).join(', ') || 'none'}` }
    );
  }

  const now = new Date().toISOString();
  const carrier = parsed.data.carrier.trim() || order.carrier || '';
  const tracking = parsed.data.tracking_number.trim() || order.tracking_number || '';
  let location = parsed.data.location.trim();
  let eventRemarks = parsed.data.remarks.trim();
  let eventTitle = '';
  const stmts: D1PreparedStatement[] = [];

  if (targetLower === 'packed') {
    stmts.push(db.prepare("UPDATE orders SET status = 'packed' WHERE id = ?").bind(orderId));
    eventTitle = 'Order Packed';
    if (!eventRemarks) eventRemarks = 'Items carefully packed and sealed for transit.';
    if (!location) location = 'Milterra Facility';
  } else if (targetLower === 'shipped') {
    if (!carrier || !tracking) {
      throw new HTTPException(422, { message: 'Carrier and tracking number are required to dispatch' });
    }
    stmts.push(
      db.prepare(
        'UPDATE orders SET status = ?, carrier = ?, tracking_number = ?, dispatched_at = ? WHERE id = ?'
      ).bind('shipped', carrier, tracking, now, orderId)
    );
    eventTitle = `Dispatched with ${carrier}`;
    if (!eventRemarks) eventRemarks = `Handed over to courier. AWB / Tracking: ${tracking}`;
    if (!location) location = 'Logistics Hub';
  } else if (targetLower === 'out_for_delivery') {
    stmts.push(db.prepare("UPDATE orders SET status = 'out_for_delivery' WHERE id = ?").bind(orderId));
    eventTitle = 'Out for Delivery';
    if (!eventRemarks) eventRemarks = 'Package is out for delivery with the courier agent.';
  } else if (targetLower === 'delivered') {
    stmts.push(
      db.prepare("UPDATE orders SET status = 'delivered', delivered_at = ? WHERE id = ?").bind(now, orderId)
    );
    eventTitle = 'Delivered';
    if (!eventRemarks) eventRemarks = 'Package successfully delivered to customer.';
  }

  // Atomic order event insertion
  stmts.push(
    db.prepare(
      `INSERT INTO order_events (id, order_id, status, title, location, remarks)
       VALUES (?, ?, ?, ?, ?, ?)`
    ).bind(crypto.randomUUID(), orderId, rawTarget, eventTitle, location, eventRemarks)
  );

  await db.batch(stmts);

  const updated = await getOrderDetailsHelper(db, orderId);
  return c.json({ success: true, data: updated });
});

// ---------------------------------------------------------------------------
// 2. COD Remittance & Collection
// ---------------------------------------------------------------------------

operationsRouter.post('/orders/admin/cod/:order_id/collect', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const orderId = c.req.param('order_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = CodSettlementSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Valid remittance reference is required' });
  }
  const ref = parsed.data.remittance_reference.trim();

  const order = await db.prepare('SELECT * FROM orders WHERE id = ?').bind(orderId).first<any>();
  if (!order) {
    throw new HTTPException(404, { message: 'Order not found' });
  }
  if (order.payment_method !== 'cod') {
    throw new HTTPException(409, { message: 'A COD order is required for cash collection' });
  }
  if (order.status !== 'delivered') {
    throw new HTTPException(409, { message: 'Record courier delivery before COD remittance' });
  }

  const activeReturn = await db.prepare(
    "SELECT id FROM order_return_cases WHERE order_id = ? AND status != 'rejected'"
  ).bind(orderId).first();
  if (activeReturn) {
    throw new HTTPException(409, { message: 'Resolve the return case before recording COD remittance' });
  }

  // Idempotent replay check
  if (order.payment_status === 'paid') {
    if (order.remittance_reference === ref) {
      const data = await getOrderDetailsHelper(db, orderId);
      return c.json({ success: true, data });
    }
    throw new HTTPException(409, { message: 'COD has already been settled with another reference' });
  }

  const stmts = [
    db.prepare("UPDATE orders SET payment_status = 'paid', remittance_reference = ? WHERE id = ?").bind(ref, orderId),
    db.prepare(
      `INSERT INTO order_events (id, order_id, status, title, location, remarks)
       VALUES (?, ?, 'PAID', 'COD Remittance Recorded', '', ?)`
    ).bind(crypto.randomUUID(), orderId, `Remittance reference: ${ref}`),
  ];

  await db.batch(stmts);

  const updated = await getOrderDetailsHelper(db, orderId);
  return c.json({ success: true, data: updated });
});

// ---------------------------------------------------------------------------
// 3. Customer Returns & Admin RTO Cases
// ---------------------------------------------------------------------------

const handleReturnRequest = async (c: any) => {
  const customer = await requireAuth(c);
  const orderId = c.req.param('order_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = ReturnReasonSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Return reason must be at least 5 characters' });
  }

  const order = (await db.prepare(
    'SELECT status FROM orders WHERE id = ? AND customer_id = ?'
  ).bind(orderId, customer.id).first()) as any;

  if (!order) {
    throw new HTTPException(404, { message: 'Order not found' });
  }
  if (order.status !== 'delivered') {
    throw new HTTPException(409, { message: 'Return requests are available after delivery' });
  }

  try {
    await db.prepare(
      'INSERT INTO order_return_cases (id, order_id, kind, reason, remarks) VALUES (?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), orderId, 'customer_return', parsed.data.reason.trim(), parsed.data.remarks?.trim() || '').run();
  } catch (err: any) {
    if (String(err).toUpperCase().includes('UNIQUE')) {
      throw new HTTPException(409, { message: 'This order already has a return case' });
    }
    throw err;
  }

  return c.json(
    {
      success: true,
      message: 'Return request received for review',
      data: { order_id: orderId, return_status: 'RETURN_REQUESTED' },
    },
    201
  );
};

operationsRouter.post('/orders/:order_id/return-request', handleReturnRequest);
operationsRouter.post('/orders/:order_id/return', handleReturnRequest);

operationsRouter.post('/orders/admin/returns/:order_id/rto', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const orderId = c.req.param('order_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = ReturnReasonSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'RTO reason is required' });
  }

  const order = await db.prepare('SELECT status FROM orders WHERE id = ?').bind(orderId).first<any>();
  if (!order) {
    throw new HTTPException(404, { message: 'Order not found' });
  }
  if (!['shipped', 'out_for_delivery'].includes(order.status)) {
    throw new HTTPException(409, { message: 'RTO can only be opened for an in-transit order' });
  }

  try {
    await db.batch([
      db.prepare(
        'INSERT INTO order_return_cases (id, order_id, kind, reason, remarks) VALUES (?, ?, ?, ?, ?)'
      ).bind(crypto.randomUUID(), orderId, 'rto', parsed.data.reason.trim(), parsed.data.remarks?.trim() || ''),
      db.prepare(
        `INSERT INTO order_events (id, order_id, status, title, remarks)
         VALUES (?, ?, 'RTO_REQUESTED', 'Delivery failed; return to sender opened', ?)`
      ).bind(crypto.randomUUID(), orderId, parsed.data.reason.trim()),
    ]);
  } catch (err: any) {
    if (String(err).toUpperCase().includes('UNIQUE')) {
      throw new HTTPException(409, { message: 'This order already has a return case' });
    }
    throw err;
  }

  return c.json({ success: true, data: { order_id: orderId, return_status: 'RTO_REQUESTED' } }, 201);
});

const handleListReturns = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT r.*, o.total_minor, o.payment_status, o.is_test_order, c.phone AS customer_phone
     FROM order_return_cases r
     JOIN orders o ON o.id = r.order_id
     JOIN customers c ON c.id = o.customer_id
     ORDER BY r.created_at DESC LIMIT 100`
  ).all();

  const data = (rows.results || []).map((row: any) => {
    let returnStatus = 'RETURN_REQUESTED';
    if (row.status === 'received') {
      returnStatus = row.kind === 'rto' ? 'RTO_DELIVERED' : 'RETURN_COMPLETED';
    } else if (row.status === 'rejected') {
      returnStatus = 'RETURN_REJECTED';
    } else if (row.kind === 'rto') {
      returnStatus = 'RTO_REQUESTED';
    }

    return {
      id: row.order_id,
      case_id: row.id,
      return_reason: row.reason,
      return_remarks: row.remarks,
      return_status: returnStatus,
      payment_status: String(row.payment_status || '').toUpperCase(),
      is_test_order: Boolean(row.is_test_order),
      customer_phone: row.customer_phone,
      total: (row.total_minor || 0) / 100,
    };
  });

  return c.json({ success: true, data });
};

operationsRouter.get('/orders/admin/returns', handleListReturns);
operationsRouter.get('/marketplace/orders/admin/returns', handleListReturns);

const handleProcessReturn = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const orderId = c.req.param('order_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = ReturnResolutionSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid return processing input' });
  }

  const row = (await db.prepare(
    `SELECT r.*, o.payment_status, o.payment_method, o.reservation_id
     FROM order_return_cases r
     JOIN orders o ON o.id = r.order_id
     WHERE r.order_id = ?`
  ).bind(orderId).first()) as any;

  if (!row) {
    throw new HTTPException(404, { message: 'Return case not found' });
  }
  if (row.status !== 'requested') {
    throw new HTTPException(409, { message: 'Return case has already been resolved' });
  }
  if (parsed.data.action === 'reject' && !parsed.data.remarks?.trim()) {
    throw new HTTPException(422, { message: 'A rejection explanation is required' });
  }

  const receiving = parsed.data.action !== 'reject';
  const refundRef = parsed.data.refund_reference?.trim() || '';
  if (receiving && row.payment_status === 'paid') {
    if (row.payment_method !== 'cod') {
      throw new HTTPException(409, { message: 'Online refunds require payment-provider verification' });
    }
    if (refundRef.length < 3) {
      throw new HTTPException(422, { message: 'Enter the completed COD refund reference' });
    }
  }

  const stmts: D1PreparedStatement[] = [
    db.prepare(
      `UPDATE order_return_cases
       SET status = ?, remarks = ?, refund_reference = ?, restocked = ?, resolved_at = CURRENT_TIMESTAMP
       WHERE id = ?`
    ).bind(
      receiving ? 'received' : 'rejected',
      parsed.data.remarks?.trim() || '',
      refundRef || null,
      receiving && (parsed.data.restock_inventory ?? true) ? 1 : 0,
      row.id
    ),
  ];

  if (receiving && (parsed.data.restock_inventory ?? true)) {
    const linesRes = await db.prepare('SELECT product_id, quantity FROM order_lines WHERE order_id = ?').bind(orderId).all();
    for (const line of (linesRes.results || []) as any[]) {
      stmts.push(
        db.prepare(
          'UPDATE inventory SET available_units = available_units + ?, updated_at = CURRENT_TIMESTAMP WHERE product_id = ?'
        ).bind(line.quantity, line.product_id)
      );
    }
    if (row.reservation_id) {
      stmts.push(
        db.prepare("UPDATE reservations SET status = 'CANCELLED' WHERE id = ?").bind(row.reservation_id)
      );
    }
  }

  if (receiving && row.payment_status === 'paid') {
    stmts.push(db.prepare("UPDATE orders SET payment_status = 'refunded' WHERE id = ?").bind(orderId));
  }

  stmts.push(
    db.prepare(
      `INSERT INTO order_events (id, order_id, status, title, remarks)
       VALUES (?, ?, ?, ?, ?)`
    ).bind(
      crypto.randomUUID(),
      orderId,
      receiving ? 'RETURN_RECEIVED' : 'RETURN_REJECTED',
      receiving ? 'Return received and closed' : 'Return request rejected',
      parsed.data.remarks?.trim() || ''
    )
  );

  await db.batch(stmts);

  return c.json({
    success: true,
    data: {
      order_id: orderId,
      return_status: receiving ? 'RETURN_COMPLETED' : 'RETURN_REJECTED',
    },
  });
};

operationsRouter.post('/orders/admin/returns/:order_id/process', handleProcessReturn);
operationsRouter.post('/marketplace/orders/admin/returns/:order_id/process', handleProcessReturn);

// ---------------------------------------------------------------------------
// 4. Cancellations & Purchase Interests
// ---------------------------------------------------------------------------

const handleListCancellations = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT o.*, c.phone AS customer_phone
     FROM orders o
     JOIN customers c ON c.id = o.customer_id
     WHERE o.status = 'cancelled'
     ORDER BY o.created_at DESC LIMIT 100`
  ).all();

  const data = (rows.results || []).map((row: any) => ({
    id: row.id,
    status: 'CANCELLED',
    payment_status: String(row.payment_status || '').toUpperCase(),
    customer_phone: row.customer_phone,
    total: (row.total_minor || 0) / 100,
    created_at: row.created_at,
    refund_status: row.payment_method === 'cod' ? 'NOT_REQUIRED' : 'REVIEW_REQUIRED',
  }));

  return c.json({ success: true, data });
};

operationsRouter.get('/orders/admin/cancellations', handleListCancellations);
operationsRouter.get('/marketplace/orders/admin/cancellations', handleListCancellations);

const handleInterests = async (c: any) => {
  await requireAuth(c, ['admin', 'super_admin']);
  return c.json({ success: true, data: [] });
};

operationsRouter.get('/orders/admin/interests', handleInterests);
operationsRouter.get('/marketplace/orders/admin/interests', handleInterests);
operationsRouter.patch('/orders/admin/interests/:interest_id', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  throw new HTTPException(501, { message: 'Pre-launch interest follow-up is not active in the live COD store' });
});

// ---------------------------------------------------------------------------
// 5. Printable A4 Packing Slip & 4x6 Thermal Shipping Label
// ---------------------------------------------------------------------------

const handlePrintablePackingSlip = async (c: any) => {
  const orderId = c.req.param('order_id');
  const mode = (c.req.query('mode') || 'a4').toLowerCase();
  const autoprint = c.req.query('autoprint') === '1';
  const db = c.env.DB;

  const details = await getOrderDetailsHelper(db, orderId);
  if (!details) {
    return c.html('<h2>Order not found</h2>', 404);
  }

  const shortId = orderId.length >= 8 ? orderId.slice(0, 8).toUpperCase() : orderId;
  const createdAt = String(details.created_at || '').slice(0, 10);
  const status = String(details.status || 'CONFIRMED').toUpperCase();
  const paymentMethod = String(details.payment_method || 'cod').toUpperCase();
  const paymentStatus = String(details.payment_status || 'PENDING').toUpperCase();
  const total = Number(details.total || 0).toFixed(2);
  const subtotal = Number(details.subtotal || details.total || 0).toFixed(2);
  const deliveryFee = Number(details.delivery_fee || 0).toFixed(2);
  const carrier = String(details.carrier || 'Self-Fulfill / Courier');
  const awb = String(details.tracking_number || 'PENDING');

  const addr: any = details.address || {};
  const recipient = String(addr.recipient_name || 'Customer');
  const phone = String(addr.phone || addr.phone_number || '');
  const fullAddr = [
    addr.address_line1 || addr.street_address,
    addr.address_line2,
    addr.village_or_city || addr.city,
    addr.district,
    addr.state,
    addr.postal_code || addr.pincode ? `PIN: ${addr.postal_code || addr.pincode}` : '',
  ].filter(Boolean).join(', ');

  const items: any[] = Array.isArray(details.items) ? details.items : [];
  const rowsHtml = items.map((it, idx) => {
    const qty = Number(it.quantity || 1);
    const price = Number(it.unit_price || 0).toFixed(2);
    const lineTotal = Number(it.line_total || qty * Number(it.unit_price || 0)).toFixed(2);
    return `
      <tr>
        <td>${idx + 1}</td>
        <td><strong>${String(it.title || it.product_id)}</strong><br/><span style="color:#64748b;font-size:11px;">SKU: ${String(it.product_id || '')}</span></td>
        <td style="text-align:center;font-weight:700;">${qty}</td>
        <td style="text-align:right;">&#8377;${price}</td>
        <td style="text-align:right;font-weight:700;">&#8377;${lineTotal}</td>
      </tr>
    `;
  }).join('');

  const isCod = paymentMethod === 'COD' && paymentStatus !== 'PAID';

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Milterra Packing Slip #${shortId}</title>
  <style>
    * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    body { margin: 0; padding: 24px; background: #f1f5f9; color: #0f172a; }
    .toolbar {
      max-width: 820px; margin: 0 auto 16px auto; background: #0d1b15; color: #fff;
      padding: 12px 20px; border-radius: 10px; display: flex; justify-content: space-between; align-items: center;
    }
    .toolbar button, .toolbar a {
      background: #15803d; color: #fff; border: none; padding: 8px 16px; border-radius: 6px;
      font-weight: 700; cursor: pointer; text-decoration: none; font-size: 13px; margin-left: 8px;
    }
    .toolbar a.secondary { background: #334155; }
    .sheet {
      max-width: ${mode === 'thermal' ? '420px' : '820px'}; margin: 0 auto; background: #fff;
      padding: ${mode === 'thermal' ? '20px' : '32px'}; border-radius: 12px; border: 2px solid #0f172a;
    }
    .header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #0f172a; padding-bottom: 16px; }
    .brand { font-size: 24px; font-weight: 900; color: #0d1b15; letter-spacing: 0.5px; }
    .sub { font-size: 12px; color: #475569; margin-top: 4px; }
    .cod-banner {
      margin: 16px 0; padding: 12px 16px; border-radius: 8px; font-weight: 900; font-size: 16px;
      text-align: center; border: 2px solid #0f172a;
      background: ${isCod ? '#fef3c7' : '#dcfce7'}; color: ${isCod ? '#92400e' : '#166534'};
    }
    .grid { display: grid; grid-template-columns: ${mode === 'thermal' ? '1fr' : '1fr 1fr'}; gap: 16px; margin: 16px 0; }
    .box { border: 1px solid #cbd5e1; border-radius: 8px; padding: 14px; background: #f8fafc; }
    .box-title { font-size: 10px; font-weight: 800; color: #64748b; text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 6px; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 13px; }
    th { background: #0d1b15; color: #fff; text-align: left; padding: 10px; font-size: 11px; text-transform: uppercase; }
    td { padding: 10px; border-bottom: 1px solid #e2e8f0; }
    .totals { margin-top: 16px; width: 280px; margin-left: auto; font-size: 13px; }
    .totals div { display: flex; justify-content: space-between; padding: 4px 0; }
    .totals .grand { font-size: 16px; font-weight: 900; border-top: 2px solid #0f172a; padding-top: 8px; margin-top: 4px; }
    .barcode {
      font-family: monospace; font-size: 16px; font-weight: 900; letter-spacing: 3px;
      border: 2px dashed #0f172a; padding: 8px 14px; display: inline-block; margin-top: 8px;
    }
    @media print {
      body { background: #fff; padding: 0; }
      .toolbar { display: none !important; }
      .sheet { border: 1px solid #000; box-shadow: none; max-width: 100%; }
    }
  </style>
</head>
<body>
  <div class="toolbar">
    <div><strong>Milterra Print Center</strong> &middot; Order #${shortId}</div>
    <div>
      <a class="secondary" href="?mode=${mode === 'thermal' ? 'a4' : 'thermal'}">${mode === 'thermal' ? 'Switch to A4 Invoice View' : 'Switch to 4x6 Thermal Label'}</a>
      <button onclick="window.print()">&#128424; Print Now</button>
    </div>
  </div>

  <div class="sheet">
    <div class="header">
      <div>
        <div class="brand">MILTERRA</div>
        <div class="sub">Pure Farm-to-Kitchen Dairy &amp; Naturals &middot; milterrafoods.com</div>
        <div class="sub">Order ID: <strong>${orderId}</strong> &middot; Date: <strong>${createdAt}</strong></div>
      </div>
      <div style="text-align:right;">
        <div style="font-size:12px;font-weight:800;">STATUS: ${status}</div>
        <div class="barcode">||| ${shortId} |||</div>
      </div>
    </div>

    <div class="cod-banner">
      ${isCod ? `CASH ON DELIVERY &mdash; COLLECT &#8377;${total} ON DELIVERY` : `PREPAID ORDER &mdash; DO NOT COLLECT CASH (&#8377;${total} PAID)`}
    </div>

    <div class="grid">
      <div class="box">
        <div class="box-title">Ship To / Customer Delivery Address</div>
        <div style="font-size:16px;font-weight:900;">${recipient}</div>
        <div style="font-size:13px;font-weight:700;color:#15803d;margin:4px 0;">Phone: ${phone}</div>
        <div style="font-size:13px;line-height:1.4;">${fullAddr}</div>
      </div>
      <div class="box">
        <div class="box-title">Courier &amp; Dispatch Details</div>
        <div style="font-size:14px;font-weight:800;">Courier Partner: ${carrier.toUpperCase()}</div>
        <div style="font-size:13px;font-weight:700;margin:4px 0;">AWB / Tracking #: ${awb}</div>
        <div style="font-size:12px;color:#475569;margin-top:8px;">
          <strong>Sold &amp; Dispatched By:</strong><br/>
          Milterra Central Fulfillment Hub, Lucknow / Delhi NCR
        </div>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th style="width:36px;">#</th>
          <th>Item Description</th>
          <th style="width:60px;text-align:center;">Qty</th>
          <th style="width:90px;text-align:right;">Unit Price</th>
          <th style="width:100px;text-align:right;">Total</th>
        </tr>
      </thead>
      <tbody>
        ${rowsHtml}
      </tbody>
    </table>

    <div class="totals">
      <div><span>Subtotal:</span><span>&#8377;${subtotal}</span></div>
      <div><span>Shipping &amp; Handling:</span><span>&#8377;${deliveryFee}</span></div>
      <div class="grand"><span>Order Total:</span><span>&#8377;${total}</span></div>
    </div>
  </div>
  ${autoprint ? '<script>window.onload = function() { setTimeout(function() { window.print(); }, 300); };</script>' : ''}
</body>
</html>`;

  return c.html(html);
};

operationsRouter.get('/orders/:order_id/packing-slip', handlePrintablePackingSlip);
operationsRouter.get('/marketplace/orders/:order_id/packing-slip', handlePrintablePackingSlip);

