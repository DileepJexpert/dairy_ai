import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const milkRouter = new Hono<{ Bindings: Env }>();

const MilkSessionEnum = z.enum(['morning', 'evening', 'night']);

const MilkRecordCreateSchema = z.object({
  cattle_id: z.union([z.string(), z.number()]).optional(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).default(() => new Date().toISOString().slice(0, 10)),
  session: MilkSessionEnum.default('morning'),
  quantity_litres: z.number().positive(),
  fat_pct: z.number().min(0).max(15).nullable().optional(),
  snf_pct: z.number().min(0).max(15).nullable().optional(),
  buyer: z.string().optional().nullable(),
  buyer_name: z.string().max(200).nullable().optional(),
  price_per_litre: z.number().nonnegative().nullable().optional(),
});

function calculateQualityGrade(fat?: number | null, snf?: number | null): string {
  if (fat == null || snf == null) return 'B';
  if (fat >= 4.0 && snf >= 8.5) return 'A';
  if (fat >= 3.5 && snf >= 8.0) return 'B';
  if (fat >= 3.0 && snf >= 7.5) return 'C';
  return 'D';
}

async function verifyCattleOwnership(db: D1Database, userId: string, cattleId: string): Promise<{ farmerId: string }> {
  const farmer = await getFarmerByUserId(db, userId);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const cattle = (await db.prepare('SELECT id FROM cattle WHERE id = ? AND farmer_id = ?').bind(cattleId, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  return { farmerId: farmer.id };
}

// ---------------------------------------------------------------------------
// 1. Top-Level Milk Records (Used by Flutter milk_provider.dart)
// ---------------------------------------------------------------------------

milkRouter.get('/milk-records', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const cattleId = c.req.query('cattle_id');
  let query = `
    SELECT m.*, c.name as cattle_name, c.tag_id as cattle_tag_id
    FROM milk_records m
    JOIN cattle c ON c.id = m.cattle_id
    WHERE c.farmer_id = ?
  `;
  const params: any[] = [farmer.id];

  if (cattleId) {
    query += ` AND m.cattle_id = ?`;
    params.push(cattleId);
  }

  query += ` ORDER BY m.date DESC, m.session ASC, m.created_at DESC LIMIT 100`;

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      cattle_id: r.cattle_id,
      cattle_name: r.cattle_name,
      cattle_tag_id: r.cattle_tag_id,
      date: r.date,
      session: r.session,
      quantity_litres: Number(r.quantity_litres),
      fat_pct: r.fat_pct !== null ? Number(r.fat_pct) : null,
      snf_pct: r.snf_pct !== null ? Number(r.snf_pct) : null,
      buyer: r.buyer_name?.toLowerCase().includes('private') ? 'private' : 'cooperative',
      buyer_name: r.buyer_name,
      price_per_litre: r.price_per_litre ? Number(r.price_per_litre) : 42.0,
      total_amount: r.total_amount ? Number(r.total_amount) : Number(r.quantity_litres) * 42.0,
      quality_grade: r.quality_grade,
    })),
    message: 'Milk records',
  });
});

milkRouter.post('/milk-records', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = MilkRecordCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid milk record details' });
  }

  let cattleId = parsed.data.cattle_id ? String(parsed.data.cattle_id) : '';

  // Validate or resolve cattle for this farmer
  if (cattleId) {
    const cattleCheck = (await db.prepare('SELECT id, name, tag_id FROM cattle WHERE id = ? AND farmer_id = ?').bind(cattleId, farmer.id).first()) as any;
    if (!cattleCheck) {
      throw new HTTPException(404, { message: 'Cattle not found for this farmer profile' });
    }
  } else {
    const firstCattle = (await db.prepare('SELECT id, name, tag_id FROM cattle WHERE farmer_id = ? AND status = "active" LIMIT 1').bind(farmer.id).first()) as any;
    if (!firstCattle) {
      throw new HTTPException(400, { message: 'No cattle registered yet. Please add a cow or buffalo before recording milk yield.' });
    }
    cattleId = firstCattle.id;
  }

  const cattleInfo = (await db.prepare('SELECT name, tag_id FROM cattle WHERE id = ?').bind(cattleId).first()) as any;
  const pricePerLitre = parsed.data.price_per_litre ?? 42.0;
  const totalAmount = Math.round(parsed.data.quantity_litres * pricePerLitre * 100) / 100;
  const qualityGrade = calculateQualityGrade(parsed.data.fat_pct, parsed.data.snf_pct);
  const recordId = `milk-${crypto.randomUUID()}`;

  await db.prepare(
    `INSERT INTO milk_records (id, cattle_id, date, session, quantity_litres, fat_pct, snf_pct, buyer_name, price_per_litre, total_amount, quality_grade)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    recordId,
    cattleId,
    parsed.data.date,
    parsed.data.session === 'night' ? 'evening' : parsed.data.session,
    parsed.data.quantity_litres,
    parsed.data.fat_pct ?? null,
    parsed.data.snf_pct ?? null,
    parsed.data.buyer_name || (parsed.data.buyer ? String(parsed.data.buyer) : 'Cooperative'),
    pricePerLitre,
    totalAmount,
    qualityGrade
  ).run();

  // Also auto-record income transaction in farm_transactions for seamless ERP integration
  try {
    await db.prepare(
      `INSERT INTO farm_transactions (id, farmer_id, type, category, amount, description, date, cattle_id)
       VALUES (?, ?, 'income', 'milk_sales', ?, ?, ?, ?)`
    ).bind(
      `tx-milk-${crypto.randomUUID().slice(0, 8)}`,
      farmer.id,
      totalAmount,
      `Milk sale (${parsed.data.quantity_litres}L @ ₹${pricePerLitre}/L) - ${parsed.data.session}`,
      parsed.data.date,
      cattleId
    ).run();
  } catch (err) {
    console.warn('Auto ERP transaction creation warning:', err);
  }

  const savedRecord = {
    id: recordId,
    cattle_id: cattleId,
    cattle_name: cattleInfo?.name || 'Cattle',
    cattle_tag_id: cattleInfo?.tag_id || '',
    date: parsed.data.date,
    session: parsed.data.session,
    quantity_litres: parsed.data.quantity_litres,
    fat_pct: parsed.data.fat_pct ?? null,
    snf_pct: parsed.data.snf_pct ?? null,
    buyer: parsed.data.buyer || 'cooperative',
    buyer_name: parsed.data.buyer_name || 'Cooperative',
    price_per_litre: pricePerLitre,
    total_amount: totalAmount,
    quality_grade: qualityGrade,
  };

  return c.json(
    {
      success: true,
      data: savedRecord,
      message: 'Milk record created',
    },
    201
  );
});

milkRouter.post('/milk-records/batch', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = (await c.req.json().catch(() => null)) as any;
  const records = Array.isArray(body?.records) ? body.records : [];
  const results: any[] = [];

  for (const item of records) {
    const cattleId = String(item.cattle_id || '');
    const price = item.price_per_litre ?? 42.0;
    const qty = Number(item.quantity_litres || 0);
    const amount = Math.round(qty * price * 100) / 100;
    const recId = `milk-${crypto.randomUUID()}`;

    if (qty > 0 && cattleId) {
      await db.prepare(
        `INSERT INTO milk_records (id, cattle_id, date, session, quantity_litres, fat_pct, snf_pct, buyer_name, price_per_litre, total_amount, quality_grade)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).bind(
        recId,
        cattleId,
        item.date || new Date().toISOString().slice(0, 10),
        item.session === 'night' ? 'evening' : (item.session || 'morning'),
        qty,
        item.fat_pct ?? null,
        item.snf_pct ?? null,
        item.buyer_name || null,
        price,
        amount,
        calculateQualityGrade(item.fat_pct, item.snf_pct)
      ).run();

      results.push({
        id: recId,
        cattle_id: cattleId,
        date: item.date,
        session: item.session,
        quantity_litres: qty,
        fat_pct: item.fat_pct,
        snf_pct: item.snf_pct,
        buyer_name: item.buyer_name,
        price_per_litre: price,
      });
    }
  }

  return c.json({
    success: true,
    data: results,
    message: `${results.length} milk records batch saved`,
  });
});

milkRouter.get('/milk-records/summary', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const period = c.req.query('period') || 'weekly';
  const days = period === 'daily' ? 1 : period === 'monthly' ? 30 : 7;
  const startDate = new Date(Date.now() - days * 86400000).toISOString().slice(0, 10);

  const totalRow = (await db.prepare(
    `SELECT COALESCE(SUM(m.quantity_litres), 0) as litres,
            COALESCE(SUM(m.total_amount), 0) as rev,
            COALESCE(AVG(m.fat_pct), 0) as avg_fat,
            COALESCE(AVG(m.snf_pct), 0) as avg_snf,
            COUNT(m.id) as cnt
     FROM milk_records m
     JOIN cattle c ON c.id = m.cattle_id
     WHERE c.farmer_id = ? AND m.date >= ?`
  ).bind(farmer.id, startDate).first()) as any;

  const dailyRows = (await db.prepare(
    `SELECT m.date,
            COALESCE(SUM(m.quantity_litres), 0) as litres,
            COALESCE(SUM(m.total_amount), 0) as revenue
     FROM milk_records m
     JOIN cattle c ON c.id = m.cattle_id
     WHERE c.farmer_id = ? AND m.date >= ?
     GROUP BY m.date
     ORDER BY m.date ASC`
  ).bind(farmer.id, startDate).all()).results || [];

  const cattleRows = (await db.prepare(
    `SELECT c.id as cattle_id, c.name as cattle_name, c.tag_id as cattle_tag_id,
            COALESCE(SUM(m.quantity_litres), 0) as total_litres,
            COALESCE(SUM(m.total_amount), 0) as total_revenue,
            COALESCE(AVG(m.quantity_litres), 0) as avg_daily
     FROM cattle c
     LEFT JOIN milk_records m ON m.cattle_id = c.id AND m.date >= ?
     WHERE c.farmer_id = ?
     GROUP BY c.id, c.name, c.tag_id
     ORDER BY total_litres DESC`
  ).bind(startDate, farmer.id).all()).results || [];

  return c.json({
    success: true,
    data: {
      total_litres: Math.round(Number(totalRow?.litres || 0) * 100) / 100,
      total_revenue: Math.round(Number(totalRow?.rev || 0) * 100) / 100,
      avg_fat_pct: Math.round(Number(totalRow?.avg_fat || 0) * 10) / 10,
      avg_snf_pct: Math.round(Number(totalRow?.avg_snf || 0) * 10) / 10,
      total_records: Number(totalRow?.cnt || 0),
      daily_entries: (dailyRows as any[]).map((r) => ({
        date: r.date,
        litres: Math.round(Number(r.litres) * 100) / 100,
        revenue: Math.round(Number(r.revenue) * 100) / 100,
      })),
      cattle_breakdown: (cattleRows as any[]).map((r) => ({
        cattle_id: r.cattle_id,
        cattle_name: r.cattle_name || 'Cattle',
        cattle_tag_id: r.cattle_tag_id || '',
        total_litres: Math.round(Number(r.total_litres) * 100) / 100,
        total_revenue: Math.round(Number(r.total_revenue) * 100) / 100,
        avg_daily: Math.round(Number(r.avg_daily) * 10) / 10,
      })),
    },
    message: 'Milk summary',
  });
});

milkRouter.get('/milk-prices', async (c) => {
  const district = c.req.query('district') || 'Anand';
  const today = new Date().toISOString().slice(0, 10);

  const prices = [
    {
      id: 1,
      district: district,
      buyer_name: 'Amul Co-operative Dairy',
      price_per_litre: 44.5,
      fat_pct: 4.5,
      date: today,
    },
    {
      id: 2,
      district: district,
      buyer_name: 'Mother Dairy Bulk Center',
      price_per_litre: 43.0,
      fat_pct: 4.2,
      date: today,
    },
    {
      id: 3,
      district: district,
      buyer_name: 'Local Private Dairy & Halwai',
      price_per_litre: 48.0,
      fat_pct: 4.8,
      date: today,
    },
  ];

  return c.json({
    success: true,
    data: prices,
    message: 'Milk prices',
  });
});

// ---------------------------------------------------------------------------
// 2. Legacy Cattle Milk Production Routes
// ---------------------------------------------------------------------------

milkRouter.post('/cattle/:cattle_id/milk-records', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  await verifyCattleOwnership(db, user.id, cattleId);

  const body = await c.req.json().catch(() => null);
  const parsed = MilkRecordCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid milk record details' });
  }

  const pricePerLitre = parsed.data.price_per_litre ?? 42.0;
  const totalAmount = Math.round(parsed.data.quantity_litres * pricePerLitre * 100) / 100;
  const qualityGrade = calculateQualityGrade(parsed.data.fat_pct, parsed.data.snf_pct);
  const recordId = `milk-${crypto.randomUUID()}`;

  await db.prepare(
    `INSERT INTO milk_records (id, cattle_id, date, session, quantity_litres, fat_pct, snf_pct, buyer_name, price_per_litre, total_amount, quality_grade)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    recordId,
    cattleId,
    parsed.data.date,
    parsed.data.session === 'night' ? 'evening' : parsed.data.session,
    parsed.data.quantity_litres,
    parsed.data.fat_pct ?? null,
    parsed.data.snf_pct ?? null,
    parsed.data.buyer_name || null,
    pricePerLitre,
    totalAmount,
    qualityGrade
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id: recordId,
        quantity_litres: parsed.data.quantity_litres,
        total_amount: totalAmount,
        quality_grade: qualityGrade,
      },
      message: 'Milk record saved',
    },
    201
  );
});

milkRouter.get('/cattle/:cattle_id/milk-records', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const days = Math.min(Math.max(Number(c.req.query('days') || 30), 1), 365);
  const db = c.env.DB;

  await verifyCattleOwnership(db, user.id, cattleId);

  const startDate = new Date(Date.now() - days * 86400000).toISOString().slice(0, 10);
  const rows = await db.prepare(
    `SELECT * FROM milk_records
     WHERE cattle_id = ? AND date >= ?
     ORDER BY date DESC, session ASC`
  ).bind(cattleId, startDate).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      date: r.date,
      session: r.session,
      quantity_litres: Number(r.quantity_litres),
      fat_pct: r.fat_pct,
      snf_pct: r.snf_pct,
      total_amount: r.total_amount,
      quality_grade: r.quality_grade,
    })),
    message: 'Milk records',
  });
});

milkRouter.get('/farmers/me/milk-summary', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const todayStr = new Date().toISOString().slice(0, 10);
  const weekStartStr = new Date(Date.now() - 7 * 86400000).toISOString().slice(0, 10);

  const todayRow = (await db.prepare(
    `SELECT COALESCE(SUM(m.quantity_litres), 0) as litres,
            COALESCE(SUM(m.total_amount), 0) as amount
     FROM milk_records m
     JOIN cattle c ON c.id = m.cattle_id
     WHERE c.farmer_id = ? AND m.date = ?`
  ).bind(farmer.id, todayStr).first()) as any;

  const weekRow = (await db.prepare(
    `SELECT COALESCE(SUM(m.quantity_litres), 0) as litres,
            COALESCE(SUM(m.total_amount), 0) as amount,
            COALESCE(AVG(m.fat_pct), 0) as avg_fat,
            COALESCE(AVG(m.snf_pct), 0) as avg_snf
     FROM milk_records m
     JOIN cattle c ON c.id = m.cattle_id
     WHERE c.farmer_id = ? AND m.date >= ?`
  ).bind(farmer.id, weekStartStr).first()) as any;

  return c.json({
    success: true,
    data: {
      today: {
        total_litres: Math.round(Number(todayRow?.litres || 0) * 100) / 100,
        revenue: Math.round(Number(todayRow?.amount || 0) * 100) / 100,
      },
      last_7_days: {
        total_litres: Math.round(Number(weekRow?.litres || 0) * 100) / 100,
        revenue: Math.round(Number(weekRow?.amount || 0) * 100) / 100,
        average_fat_pct: Math.round(Number(weekRow?.avg_fat || 0) * 10) / 10,
        average_snf_pct: Math.round(Number(weekRow?.avg_snf || 0) * 10) / 10,
      },
    },
    message: 'Milk summary',
  });
});

milkRouter.get('/farmers/me/production-forecast', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const weekStartStr = new Date(Date.now() - 14 * 86400000).toISOString().slice(0, 10);
  const row = (await db.prepare(
    `SELECT COALESCE(SUM(m.quantity_litres), 0) / 14.0 as daily_avg
     FROM milk_records m
     JOIN cattle c ON c.id = m.cattle_id
     WHERE c.farmer_id = ? AND m.date >= ?`
  ).bind(farmer.id, weekStartStr).first()) as any;

  const dailyAvg = Math.max(0, Math.round(Number(row?.daily_avg || 15.0) * 10) / 10);
  const forecast: Array<{ date: string; forecasted_litres: number }> = [];

  for (let i = 1; i <= 7; i++) {
    const d = new Date(Date.now() + i * 86400000).toISOString().slice(0, 10);
    forecast.push({
      date: d,
      forecasted_litres: dailyAvg,
    });
  }

  return c.json({
    success: true,
    data: {
      daily_baseline_litres: dailyAvg,
      seven_day_forecast_total: Math.round(dailyAvg * 7 * 10) / 10,
      forecast,
    },
    message: 'Production forecast',
  });
});
