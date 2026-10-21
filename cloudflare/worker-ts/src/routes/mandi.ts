import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';

export const mandiRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const MandiPriceRecordSchema = z.object({
  commodity: z.string().min(2).max(100),
  category: z.enum(['feed', 'fodder', 'cattle', 'milk']),
  district: z.string().min(2).max(100),
  state: z.string().min(2).max(100),
  mandi_name: z.string().max(100).optional(),
  min_price: z.number().positive(),
  max_price: z.number().positive(),
  modal_price: z.number().positive(),
  unit: z.string().default('quintal').optional(),
  price_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).default(() => new Date().toISOString().slice(0, 10)),
});

// Default feed seed data
const DEFAULT_MANDI_ITEMS = [
  { commodity: 'Mustard Oil Cake (Khal)', category: 'feed', district: 'Anand', state: 'Gujarat', min: 2650, max: 2850, modal: 2750, unit: 'quintal' },
  { commodity: 'Wheat Bran (Choker)', category: 'feed', district: 'Anand', state: 'Gujarat', min: 2100, max: 2300, modal: 2200, unit: 'quintal' },
  { commodity: 'De-oiled Rice Bran (DORB)', category: 'feed', district: 'Anand', state: 'Gujarat', min: 1450, max: 1650, modal: 1550, unit: 'quintal' },
  { commodity: 'Cotton Seed Cake', category: 'feed', district: 'Anand', state: 'Gujarat', min: 3100, max: 3400, modal: 3250, unit: 'quintal' },
  { commodity: 'Green Fodder (Hybrid Napier)', category: 'fodder', district: 'Anand', state: 'Gujarat', min: 220, max: 280, modal: 250, unit: 'quintal' },
  { commodity: 'Gir Cow (Second Lactation 12L/day)', category: 'cattle', district: 'Anand', state: 'Gujarat', min: 55000, max: 75000, modal: 65000, unit: 'animal' },
  { commodity: 'Murrah Buffalo (First Lactation 14L/day)', category: 'cattle', district: 'Anand', state: 'Gujarat', min: 80000, max: 110000, modal: 95000, unit: 'animal' },
];

async function ensureMandiSeeded(db: D1Database): Promise<void> {
  const existing = (await db.prepare('SELECT COUNT(*) as count FROM mandi_prices').first()) as any;
  if (!existing || Number(existing.count) === 0) {
    const today = new Date().toISOString().slice(0, 10);
    for (const item of DEFAULT_MANDI_ITEMS) {
      const id = crypto.randomUUID();
      await db.prepare(
        `INSERT INTO mandi_prices (id, commodity, category, district, state, mandi_name, min_price, max_price, modal_price, unit, price_date)
         VALUES (?, ?, ?, ?, ?, 'Anand APMC Mandi', ?, ?, ?, ?, ?)`
      ).bind(id, item.commodity, item.category, item.district, item.state, item.min, item.max, item.modal, item.unit, today).run();
    }
  }
}

// ---------------------------------------------------------------------------
// Endpoints
// ---------------------------------------------------------------------------

mandiRouter.get('/mandi/feed-prices', async (c) => {
  const db = c.env.DB;
  await ensureMandiSeeded(db);

  const district = c.req.query('district');
  const category = c.req.query('category') || 'feed';

  let query = 'SELECT * FROM mandi_prices WHERE category = ?';
  const params: any[] = [category];

  if (district) {
    query += ' AND district = ?';
    params.push(district);
  }

  query += ' ORDER BY price_date DESC, commodity ASC';

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: {
      prices: (rows.results || []).map((r: any) => ({
        id: r.id,
        commodity: r.commodity,
        category: r.category,
        district: r.district,
        state: r.state,
        mandi_name: r.mandi_name,
        min_price: r.min_price,
        max_price: r.max_price,
        modal_price: r.modal_price,
        unit: r.unit,
        price_date: r.price_date,
      })),
      count: (rows.results || []).length,
    },
    message: 'Mandi feed prices',
  });
});

mandiRouter.post('/mandi/feed-prices', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = MandiPriceRecordSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid mandi price data' });
  }

  const id = crypto.randomUUID();
  await db.prepare(
    `INSERT INTO mandi_prices (id, commodity, category, district, state, mandi_name, min_price, max_price, modal_price, unit, price_date)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    id,
    parsed.data.commodity.trim(),
    parsed.data.category,
    parsed.data.district.trim(),
    parsed.data.state.trim(),
    parsed.data.mandi_name || 'APMC Mandi',
    parsed.data.min_price,
    parsed.data.max_price,
    parsed.data.modal_price,
    parsed.data.unit || 'quintal',
    parsed.data.price_date
  ).run();

  return c.json({ success: true, data: { id }, message: 'Mandi price recorded' }, 201);
});

mandiRouter.get('/mandi/cattle-prices', async (c) => {
  const db = c.env.DB;
  await ensureMandiSeeded(db);

  const district = c.req.query('district');
  const rows = await db.prepare(
    `SELECT * FROM mandi_prices WHERE category = 'cattle' ORDER BY price_date DESC, modal_price DESC`
  ).all();

  return c.json({
    success: true,
    data: {
      prices: (rows.results || []).map((r: any) => ({
        id: r.id,
        commodity: r.commodity,
        district: r.district,
        state: r.state,
        modal_price: r.modal_price,
        unit: r.unit,
        price_date: r.price_date,
      })),
      count: (rows.results || []).length,
    },
    message: 'Cattle market prices',
  });
});

mandiRouter.get('/mandi/feed-prices/trend', async (c) => {
  const db = c.env.DB;
  await ensureMandiSeeded(db);

  const commodity = c.req.query('commodity') || 'Mustard Oil Cake (Khal)';
  const rows = await db.prepare(
    `SELECT price_date, modal_price, min_price, max_price
     FROM mandi_prices
     WHERE commodity LIKE ?
     ORDER BY price_date ASC LIMIT 30`
  ).bind(`%${commodity}%`).all();

  return c.json({
    success: true,
    data: {
      commodity,
      trend: (rows.results || []).map((r: any) => ({
        date: r.price_date,
        modal_price: r.modal_price,
        min: r.min_price,
        max: r.max_price,
      })),
    },
    message: 'Price trend',
  });
});
