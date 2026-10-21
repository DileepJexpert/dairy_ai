import { Hono, type Context } from 'hono';
import { sign, decode } from 'hono/jwt';
import { z } from 'zod';
import type { Env } from '../types/env.js';

export const deliveryRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function normalizePhone(phone: string): string {
  const cleaned = phone.replace(/\D/g, '');
  if (cleaned.startsWith('91') && cleaned.length === 12) {
    return cleaned.substring(2);
  }
  return cleaned;
}

function getUserId(c: Context<{ Bindings: Env }>): string {
  const xUserId = c.req.header('x-user-id');
  if (xUserId) {
    return xUserId;
  }
  const authHeader = c.req.header('authorization') || '';
  if (authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    try {
      const decoded = decode(token);
      if (decoded && decoded.payload) {
        const sub = (decoded.payload.sub || decoded.payload.user_id) as string;
        if (sub) return sub;
      }
    } catch {
      // ignore
    }
  }
  return 'milkman-1';
}

function getJwtSecret(env: Env): string {
  return env.JWT_SECRET || 'milterra-delivery-secret';
}

async function awardDeliveryPartnerPoints(
  db: D1Database,
  milkmanId: string,
  delivId: string,
  flatId: string,
  dateKey: string
): Promise<void> {
  if (!milkmanId || !delivId) return;
  const pointId = `dp-${crypto.randomUUID()}`;
  try {
    await db.prepare(
      `INSERT INTO delivery_partner_points (id, milkman_id, delivery_record_id, flat_id, points_earned, delivered_date, notes)
       VALUES (?, ?, ?, ?, 10, ?, 'Order delivery collection points')`
    )
      .bind(pointId, milkmanId, delivId, flatId, dateKey)
      .run();
  } catch {
    // Ignore duplicate or foreign key errors silently
  }
}

// ---------------------------------------------------------------------------
// Validation Schemas
// ---------------------------------------------------------------------------

const LoginSchema = z.object({
  phone: z.string().min(1),
  otp: z.string().min(1),
  name: z.string().default('User'),
  role: z.enum(['milkman', 'subscriber']).default('subscriber'),
});

const SocietyCreateSchema = z.object({
  name: z.string().min(1),
  address: z.string().default(''),
});

const FlatCreateSchema = z.object({
  flat_number: z.string().min(1),
  owner_name: z.string().min(1),
  owner_phone: z.string().min(1),
  has_app: z.boolean().default(false),
  default_quantity: z.number().default(1.0),
  price_per_litre: z.number().default(60.0),
});

const FlatUpdateSchema = z.object({
  flat_number: z.string().optional(),
  owner_name: z.string().optional(),
  owner_phone: z.string().optional(),
  has_app: z.boolean().optional(),
  default_quantity: z.number().optional(),
  price_per_litre: z.number().optional(),
  status: z.enum(['active', 'paused', 'stopped']).optional(),
});

const DeliveryRecordPayloadSchema = z.object({
  id: z.string().optional(),
  flat_id: z.string().min(1),
  date_key: z.string().min(1),
  planned_quantity: z.number(),
  actual_quantity: z.number().default(0.0),
  status: z.string().default('pending'),
  delivered_at: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
});

const BatchDeliveriesPayloadSchema = z.object({
  deliveries: z.array(DeliveryRecordPayloadSchema),
});

const ChangeRequestCreateSchema = z.object({
  flat_id: z.string().min(1),
  type: z.enum(['pauseToday', 'pauseTomorrow', 'pauseRange', 'changeQuantity', 'custom']),
  start_date: z.string().min(1),
  end_date: z.string().min(1),
  requested_quantity: z.number().nullable().optional(),
  reason: z.string().nullable().optional(),
});

const ChangeRequestResolveSchema = z.object({
  action: z.enum(['applied', 'rejected']),
  notes: z.string().nullable().optional(),
});

const AbsenceCreateSchema = z.object({
  type: z.enum(['singleDay', 'dateRange', 'recurringDayOfWeek']),
  date_key: z.string().nullable().optional(),
  start_date: z.string().nullable().optional(),
  end_date: z.string().nullable().optional(),
  day_of_week: z.number().nullable().optional(),
  reason: z.string().nullable().optional(),
});

const QueueItemSchema = z.object({
  op: z.enum(['upsert', 'delete']),
  collection: z.string(),
  data: z.record(z.any()),
});

const DrainPayloadSchema = z.object({
  items: z.array(QueueItemSchema),
});

// ---------------------------------------------------------------------------
// 1. Auth Endpoints
// ---------------------------------------------------------------------------

deliveryRouter.post('/auth/login', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = LoginSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const cleaned = normalizePhone(parsed.data.phone);
  if (parsed.data.otp.trim() !== '123456') {
    return c.json({ error: 'Bad Request', message: 'Invalid OTP. Use demo OTP 123456.' }, 400);
  }

  const db = c.env.DB;
  let user = await db.prepare('SELECT * FROM delivery_users WHERE phone = ?')
    .bind(cleaned)
    .first<{ id: string; phone: string; name: string; role: string }>();

  if (!user) {
    const userId = crypto.randomUUID();
    const userName = parsed.data.name.trim() || 'User';
    await db.prepare('INSERT INTO delivery_users (id, phone, name, role) VALUES (?, ?, ?, ?)')
      .bind(userId, cleaned, userName, parsed.data.role)
      .run();
    user = { id: userId, phone: cleaned, name: userName, role: parsed.data.role };
  } else {
    if (parsed.data.name && parsed.data.name !== 'User' && parsed.data.name !== user.name) {
      await db.prepare('UPDATE delivery_users SET name = ? WHERE id = ?')
        .bind(parsed.data.name, user.id)
        .run();
      user.name = parsed.data.name;
    }
  }

  const token = await sign(
    { sub: user.id, phone: user.phone, role: user.role, exp: Math.floor(Date.now() / 1000) + 30 * 86400 },
    getJwtSecret(c.env)
  );

  return c.json({
    success: true,
    token,
    user: {
      id: user.id,
      phone: user.phone,
      name: user.name,
      role: user.role,
    },
  });
});

deliveryRouter.get('/auth/me', async (c) => {
  const userId = getUserId(c);
  const user = await c.env.DB.prepare('SELECT * FROM delivery_users WHERE id = ?')
    .bind(userId)
    .first();

  if (!user) {
    return c.json({ error: 'Not Found', message: 'User not found' }, 404);
  }
  return c.json({ success: true, user });
});

// ---------------------------------------------------------------------------
// 2. Sync / State Hydration Endpoint
// ---------------------------------------------------------------------------

deliveryRouter.get('/sync', async (c) => {
  const userId = getUserId(c);
  const db = c.env.DB;
  const dateKey = c.req.query('date_key') || new Date().toISOString().substring(0, 10);

  const user = await db.prepare('SELECT * FROM delivery_users WHERE id = ?')
    .bind(userId)
    .first<{ id: string; phone: string; name: string; role: string }>();

  if (!user || user.role === 'milkman') {
    const milkmanId = user ? user.id : userId;

    const societiesRes = await db.prepare(
      'SELECT * FROM delivery_societies WHERE milkman_id = ? ORDER BY name ASC'
    ).bind(milkmanId).all();
    const societies = societiesRes.results || [];
    const societyIds = societies.map((s: any) => s.id);

    let flats: any[] = [];
    let deliveries: any[] = [];
    let changeRequests: any[] = [];

    if (societyIds.length > 0) {
      const placeholders = societyIds.map(() => '?').join(',');
      const flatsRes = await db.prepare(
        `SELECT * FROM delivery_flats WHERE society_id IN (${placeholders}) ORDER BY flat_number ASC`
      ).bind(...societyIds).all();
      flats = flatsRes.results || [];
      const flatIds = flats.map((f: any) => f.id);

      if (flatIds.length > 0) {
        const fPlaceholders = flatIds.map(() => '?').join(',');
        const delivRes = await db.prepare(
          `SELECT * FROM delivery_records WHERE flat_id IN (${fPlaceholders}) AND date_key = ?`
        ).bind(...flatIds, dateKey).all();
        deliveries = delivRes.results || [];

        const crRes = await db.prepare(
          `SELECT * FROM delivery_change_requests WHERE flat_id IN (${fPlaceholders}) AND status = 'pending'`
        ).bind(...flatIds).all();
        changeRequests = crRes.results || [];
      }
    }

    const absencesRes = await db.prepare(
      'SELECT * FROM delivery_absences WHERE milkman_id = ?'
    ).bind(milkmanId).all();
    const absences = absencesRes.results || [];

    return c.json({
      success: true,
      role: 'milkman',
      date_key: dateKey,
      societies,
      flats,
      deliveries,
      change_requests: changeRequests,
      absences,
    });
  } else {
    // Subscriber role
    const flat = await db.prepare('SELECT * FROM delivery_flats WHERE owner_phone = ?')
      .bind(user.phone)
      .first<{ id: string; society_id: string }>();

    if (!flat) {
      return c.json({
        success: true,
        role: 'subscriber',
        flat: null,
        deliveries: [],
        change_requests: [],
        absences: [],
      });
    }

    const society = await db.prepare('SELECT * FROM delivery_societies WHERE id = ?')
      .bind(flat.society_id)
      .first<{ id: string; milkman_id: string }>();

    const delivRes = await db.prepare(
      'SELECT * FROM delivery_records WHERE flat_id = ? ORDER BY date_key DESC LIMIT 31'
    ).bind(flat.id).all();
    const deliveries = delivRes.results || [];

    const crRes = await db.prepare(
      'SELECT * FROM delivery_change_requests WHERE flat_id = ? ORDER BY created_at DESC'
    ).bind(flat.id).all();
    const changeRequests = crRes.results || [];

    let absences: any[] = [];
    if (society) {
      const absRes = await db.prepare(
        'SELECT * FROM delivery_absences WHERE milkman_id = ?'
      ).bind(society.milkman_id).all();
      absences = absRes.results || [];
    }

    return c.json({
      success: true,
      role: 'subscriber',
      flat,
      society,
      deliveries,
      change_requests: changeRequests,
      absences,
    });
  }
});

// ---------------------------------------------------------------------------
// 3. Societies Endpoints
// ---------------------------------------------------------------------------

deliveryRouter.get('/societies', async (c) => {
  const userId = getUserId(c);
  const rows = await c.env.DB.prepare(
    'SELECT * FROM delivery_societies WHERE milkman_id = ? ORDER BY name ASC'
  ).bind(userId).all();
  return c.json({ success: true, societies: rows.results || [] });
});

deliveryRouter.post('/societies', async (c) => {
  const userId = getUserId(c);
  const body = await c.req.json().catch(() => null);
  const parsed = SocietyCreateSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const societyId = crypto.randomUUID();
  await c.env.DB.prepare(
    'INSERT INTO delivery_societies (id, milkman_id, name, address) VALUES (?, ?, ?, ?)'
  ).bind(societyId, userId, parsed.data.name.trim(), parsed.data.address.trim()).run();

  const created = await c.env.DB.prepare('SELECT * FROM delivery_societies WHERE id = ?')
    .bind(societyId)
    .first();

  return c.json({ success: true, society: created });
});

deliveryRouter.delete('/societies/:society_id', async (c) => {
  const userId = getUserId(c);
  const societyId = c.req.param('society_id');
  await c.env.DB.prepare('DELETE FROM delivery_societies WHERE id = ? AND milkman_id = ?')
    .bind(societyId, userId)
    .run();
  return c.json({ success: true, message: 'Society deleted' });
});

// ---------------------------------------------------------------------------
// 4. Flats Endpoints
// ---------------------------------------------------------------------------

deliveryRouter.get('/societies/:society_id/flats', async (c) => {
  const societyId = c.req.param('society_id');
  const rows = await c.env.DB.prepare(
    'SELECT * FROM delivery_flats WHERE society_id = ? ORDER BY flat_number ASC'
  ).bind(societyId).all();
  return c.json({ success: true, flats: rows.results || [] });
});

deliveryRouter.post('/societies/:society_id/flats', async (c) => {
  const societyId = c.req.param('society_id');
  const body = await c.req.json().catch(() => null);
  const parsed = FlatCreateSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const flatId = crypto.randomUUID();
  const cleanedPhone = normalizePhone(parsed.data.owner_phone);

  await c.env.DB.prepare(
    `INSERT INTO delivery_flats (id, society_id, flat_number, owner_name, owner_phone, has_app, default_quantity, price_per_litre, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active')`
  ).bind(
    flatId,
    societyId,
    parsed.data.flat_number.trim(),
    parsed.data.owner_name.trim(),
    cleanedPhone,
    parsed.data.has_app ? 1 : 0,
    parsed.data.default_quantity,
    parsed.data.price_per_litre
  ).run();

  const created = await c.env.DB.prepare('SELECT * FROM delivery_flats WHERE id = ?')
    .bind(flatId)
    .first();

  return c.json({ success: true, flat: created });
});

deliveryRouter.put('/flats/:flat_id', async (c) => {
  const flatId = c.req.param('flat_id');
  const body = await c.req.json().catch(() => null);
  const parsed = FlatUpdateSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const flat = await c.env.DB.prepare('SELECT * FROM delivery_flats WHERE id = ?')
    .bind(flatId)
    .first();

  if (!flat) {
    return c.json({ error: 'Not Found', message: 'Flat not found' }, 404);
  }

  const updates: string[] = [];
  const values: any[] = [];

  if (parsed.data.flat_number !== undefined) {
    updates.push('flat_number = ?');
    values.push(parsed.data.flat_number.trim());
  }
  if (parsed.data.owner_name !== undefined) {
    updates.push('owner_name = ?');
    values.push(parsed.data.owner_name.trim());
  }
  if (parsed.data.owner_phone !== undefined) {
    updates.push('owner_phone = ?');
    values.push(normalizePhone(parsed.data.owner_phone));
  }
  if (parsed.data.has_app !== undefined) {
    updates.push('has_app = ?');
    values.push(parsed.data.has_app ? 1 : 0);
  }
  if (parsed.data.default_quantity !== undefined) {
    updates.push('default_quantity = ?');
    values.push(parsed.data.default_quantity);
  }
  if (parsed.data.price_per_litre !== undefined) {
    updates.push('price_per_litre = ?');
    values.push(parsed.data.price_per_litre);
  }
  if (parsed.data.status !== undefined) {
    updates.push('status = ?');
    values.push(parsed.data.status);
  }

  if (updates.length > 0) {
    values.push(flatId);
    const sql = `UPDATE delivery_flats SET ${updates.join(', ')} WHERE id = ?`;
    await c.env.DB.prepare(sql).bind(...values).run();
  }

  const updated = await c.env.DB.prepare('SELECT * FROM delivery_flats WHERE id = ?')
    .bind(flatId)
    .first();

  return c.json({ success: true, flat: updated });
});

// ---------------------------------------------------------------------------
// 5. Delivery Records Endpoints
// ---------------------------------------------------------------------------

deliveryRouter.post('/deliveries/batch', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = BatchDeliveriesPayloadSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const db = c.env.DB;
  const stmts: D1PreparedStatement[] = [];
  const milkmanId = getUserId(c);

  for (const d of parsed.data.deliveries) {
    const delivId = d.id || crypto.randomUUID();
    const deliveredAt = d.delivered_at || (d.status === 'delivered' ? new Date().toISOString() : null);

    stmts.push(
      db.prepare(
        `INSERT INTO delivery_records (id, flat_id, date_key, planned_quantity, actual_quantity, status, delivered_at, notes)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(flat_id, date_key) DO UPDATE SET
         actual_quantity = excluded.actual_quantity,
         status = excluded.status,
         delivered_at = excluded.delivered_at,
         notes = excluded.notes`
      ).bind(
        delivId,
        d.flat_id,
        d.date_key,
        d.planned_quantity,
        d.actual_quantity,
        d.status,
        deliveredAt,
        d.notes || ''
      )
    );

    if (d.status === 'delivered') {
      await awardDeliveryPartnerPoints(db, milkmanId, delivId, d.flat_id, d.date_key);
    }
  }

  if (stmts.length > 0) {
    await db.batch(stmts);
  }

  return c.json({ success: true, count: stmts.length });
});

deliveryRouter.put('/deliveries/:delivery_id', async (c) => {
  const deliveryId = c.req.param('delivery_id');
  const body = await c.req.json().catch(() => null);
  const parsed = DeliveryRecordPayloadSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const db = c.env.DB;
  const deliveredAt = parsed.data.delivered_at || (parsed.data.status === 'delivered' ? new Date().toISOString() : null);

  await db.prepare(
    `INSERT INTO delivery_records (id, flat_id, date_key, planned_quantity, actual_quantity, status, delivered_at, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(flat_id, date_key) DO UPDATE SET
     actual_quantity = excluded.actual_quantity,
     status = excluded.status,
     delivered_at = excluded.delivered_at,
     notes = excluded.notes`
  ).bind(
    deliveryId,
    parsed.data.flat_id,
    parsed.data.date_key,
    parsed.data.planned_quantity,
    parsed.data.actual_quantity,
    parsed.data.status,
    deliveredAt,
    parsed.data.notes || ''
  ).run();

  if (parsed.data.status === 'delivered') {
    const milkmanId = getUserId(c);
    await awardDeliveryPartnerPoints(db, milkmanId, deliveryId, parsed.data.flat_id, parsed.data.date_key);
  }

  const updated = await db.prepare('SELECT * FROM delivery_records WHERE id = ?')
    .bind(deliveryId)
    .first();

  return c.json({ success: true, delivery: updated });
});

// ---------------------------------------------------------------------------
// 6. Change Requests Endpoints
// ---------------------------------------------------------------------------

deliveryRouter.get('/change-requests', async (c) => {
  const flatId = c.req.query('flat_id');
  let rows: any;
  if (flatId) {
    rows = await c.env.DB.prepare(
      'SELECT * FROM delivery_change_requests WHERE flat_id = ? ORDER BY created_at DESC'
    ).bind(flatId).all();
  } else {
    rows = await c.env.DB.prepare(
      "SELECT * FROM delivery_change_requests WHERE status = 'pending' ORDER BY created_at DESC"
    ).all();
  }
  return c.json({ success: true, requests: rows.results || [] });
});

deliveryRouter.post('/change-requests', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = ChangeRequestCreateSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const reqId = crypto.randomUUID();
  await c.env.DB.prepare(
    `INSERT INTO delivery_change_requests (id, flat_id, type, start_date, end_date, requested_quantity, reason, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')`
  ).bind(
    reqId,
    parsed.data.flat_id,
    parsed.data.type,
    parsed.data.start_date,
    parsed.data.end_date,
    parsed.data.requested_quantity ?? null,
    parsed.data.reason || ''
  ).run();

  const created = await c.env.DB.prepare('SELECT * FROM delivery_change_requests WHERE id = ?')
    .bind(reqId)
    .first();

  return c.json({ success: true, request: created });
});

deliveryRouter.post('/change-requests/:request_id/resolve', async (c) => {
  const requestId = c.req.param('request_id');
  const body = await c.req.json().catch(() => null);
  const parsed = ChangeRequestResolveSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const resolvedAt = new Date().toISOString();
  await c.env.DB.prepare(
    'UPDATE delivery_change_requests SET status = ?, resolved_at = ? WHERE id = ?'
  ).bind(parsed.data.action, resolvedAt, requestId).run();

  const updated = await c.env.DB.prepare('SELECT * FROM delivery_change_requests WHERE id = ?')
    .bind(requestId)
    .first();

  return c.json({ success: true, request: updated });
});

// ---------------------------------------------------------------------------
// 7. Absences Endpoints
// ---------------------------------------------------------------------------

deliveryRouter.get('/absences', async (c) => {
  const userId = getUserId(c);
  const rows = await c.env.DB.prepare(
    'SELECT * FROM delivery_absences WHERE milkman_id = ? ORDER BY created_at DESC'
  ).bind(userId).all();
  return c.json({ success: true, absences: rows.results || [] });
});

deliveryRouter.post('/absences', async (c) => {
  const userId = getUserId(c);
  const body = await c.req.json().catch(() => null);
  const parsed = AbsenceCreateSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const absId = crypto.randomUUID();
  await c.env.DB.prepare(
    `INSERT INTO delivery_absences (id, milkman_id, type, date_key, start_date, end_date, day_of_week, reason)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    absId,
    userId,
    parsed.data.type,
    parsed.data.date_key ?? null,
    parsed.data.start_date ?? null,
    parsed.data.end_date ?? null,
    parsed.data.day_of_week ?? null,
    parsed.data.reason || ''
  ).run();

  const created = await c.env.DB.prepare('SELECT * FROM delivery_absences WHERE id = ?')
    .bind(absId)
    .first();

  return c.json({ success: true, absence: created });
});

deliveryRouter.delete('/absences/:absence_id', async (c) => {
  const userId = getUserId(c);
  const absenceId = c.req.param('absence_id');
  await c.env.DB.prepare('DELETE FROM delivery_absences WHERE id = ? AND milkman_id = ?')
    .bind(absenceId, userId)
    .run();
  return c.json({ success: true, message: 'Absence deleted' });
});

// ---------------------------------------------------------------------------
// 8. Offline Queue Drain Endpoint (SyncQueue Drain)
// ---------------------------------------------------------------------------

deliveryRouter.post('/sync/drain', async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = DrainPayloadSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: 'Validation Error', details: parsed.error.format() }, 400);
  }

  const db = c.env.DB;
  const stmts: D1PreparedStatement[] = [];

  for (const item of parsed.data.items) {
    const op = item.op;
    const coll = item.collection;
    const d = item.data;

    if (coll === 'societies') {
      if (op === 'upsert') {
        stmts.push(
          db.prepare(
            `INSERT INTO delivery_societies (id, milkman_id, name, address) VALUES (?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET name=excluded.name, address=excluded.address`
          ).bind(d.id, d.milkmanId || d.milkman_id, d.name, d.address || '')
        );
      } else if (op === 'delete') {
        stmts.push(db.prepare('DELETE FROM delivery_societies WHERE id = ?').bind(d.id));
      }
    } else if (coll === 'flats') {
      if (op === 'upsert') {
        stmts.push(
          db.prepare(
            `INSERT INTO delivery_flats (id, society_id, flat_number, owner_name, owner_phone, has_app, default_quantity, price_per_litre, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET
             flat_number=excluded.flat_number, owner_name=excluded.owner_name,
             owner_phone=excluded.owner_phone, has_app=excluded.has_app,
             default_quantity=excluded.default_quantity, price_per_litre=excluded.price_per_litre,
             status=excluded.status`
          ).bind(
            d.id,
            d.societyId || d.society_id,
            d.flatNumber || d.flat_number,
            d.ownerName || d.owner_name,
            normalizePhone(d.ownerPhone || d.owner_phone || ''),
            d.hasApp || d.has_app ? 1 : 0,
            Number(d.defaultQuantity || d.default_quantity || 1.0),
            Number(d.pricePerLitre || d.price_per_litre || 60.0),
            d.status || 'active'
          )
        );
      } else if (op === 'delete') {
        stmts.push(db.prepare('DELETE FROM delivery_flats WHERE id = ?').bind(d.id));
      }
    } else if (coll === 'deliveries') {
      if (op === 'upsert') {
        const delivId = d.id || crypto.randomUUID();
        stmts.push(
          db.prepare(
            `INSERT INTO delivery_records (id, flat_id, date_key, planned_quantity, actual_quantity, status, delivered_at, notes)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(flat_id, date_key) DO UPDATE SET
             actual_quantity=excluded.actual_quantity,
             status=excluded.status,
             delivered_at=excluded.delivered_at,
             notes=excluded.notes`
          ).bind(
            delivId,
            d.flatId || d.flat_id,
            d.dateKey || d.date_key,
            Number(d.plannedQuantity || d.planned_quantity || 1.0),
            Number(d.actualQuantity || d.actual_quantity || 0.0),
            d.status || 'pending',
            d.deliveredAt || d.delivered_at || null,
            d.notes || ''
          )
        );
      }
    } else if (coll === 'change_requests') {
      if (op === 'upsert') {
        stmts.push(
          db.prepare(
            `INSERT INTO delivery_change_requests (id, flat_id, type, start_date, end_date, requested_quantity, reason, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET status=excluded.status`
          ).bind(
            d.id,
            d.flatId || d.flat_id,
            d.type,
            d.startDate || d.start_date,
            d.endDate || d.end_date,
            d.requestedQuantity || d.requested_quantity ? Number(d.requestedQuantity || d.requested_quantity) : null,
            d.reason || '',
            d.status || 'pending'
          )
        );
      }
    } else if (coll === 'absences') {
      if (op === 'upsert') {
        stmts.push(
          db.prepare(
            `INSERT INTO delivery_absences (id, milkman_id, type, date_key, start_date, end_date, day_of_week, reason)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO NOTHING`
          ).bind(
            d.id,
            d.milkmanId || d.milkman_id,
            d.type,
            d.dateKey || d.date_key || null,
            d.startDate || d.start_date || null,
            d.endDate || d.end_date || null,
            d.dayOfWeek || d.day_of_week || null,
            d.reason || ''
          )
        );
      } else if (op === 'delete') {
        stmts.push(db.prepare('DELETE FROM delivery_absences WHERE id = ?').bind(d.id));
      }
    }
  }

  if (stmts.length > 0) {
    await db.batch(stmts);
  }

  return c.json({ success: true, applied: stmts.length });
});

// ---------------------------------------------------------------------------
// 9. Delivery Partner Points Collection Endpoints
// ---------------------------------------------------------------------------

const getDeliveryPartnerPointsHandler = async (c: Context<{ Bindings: Env }>) => {
  const userId = getUserId(c);
  let records: any[] = [];
  try {
    const rows = await c.env.DB.prepare(
      'SELECT * FROM delivery_partner_points WHERE milkman_id = ? ORDER BY created_at DESC'
    ).bind(userId).all();
    records = rows.results || [];
  } catch {
    // Return empty on table missing or error
  }

  const totalPoints = records.reduce((sum, r) => sum + (r.points_earned || 10), 0);
  const totalDeliveries = records.length;

  return c.json({
    success: true,
    data: {
      milkman_id: userId,
      total_points: totalPoints,
      total_deliveries: totalDeliveries,
      points_per_delivery: 10,
      history: records,
    },
  });
};

deliveryRouter.get('/partner/points', getDeliveryPartnerPointsHandler);
deliveryRouter.get('/deliveries/points-summary', getDeliveryPartnerPointsHandler);
