import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const outbreakRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const OutbreakReportSchema = z.object({
  disease_name: z.string().min(2).max(100),
  severity: z.enum(['low', 'medium', 'high', 'critical']),
  affected_count: z.number().int().positive().default(1).optional(),
  lat: z.number(),
  lng: z.number(),
  village: z.string().max(100).optional(),
  district: z.string().max(100).optional(),
  state: z.string().max(100).optional(),
  notes: z.string().max(1000).optional(),
});

const WithdrawalRecordSchema = z.object({
  cattle_id: z.string().min(1),
  medicine_name: z.string().min(2).max(100),
  active_ingredient: z.string().min(2).max(100),
  treatment_start_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  treatment_end_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  milk_withdrawal_days: z.number().int().min(0),
  meat_withdrawal_days: z.number().int().min(0).default(28).optional(),
});

function addDaysToDate(dateStr: string, days: number): string {
  const d = new Date(dateStr);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------------
// 1. Disease Outbreak Endpoints
// ---------------------------------------------------------------------------

outbreakRouter.post('/outbreak/report', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = OutbreakReportSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid disease report details' });
  }

  const reportId = crypto.randomUUID();
  await db.prepare(
    `INSERT INTO outbreak_reports (
      id, farmer_id, disease_name, severity, affected_count, lat, lng,
      village, district, state, status, notes
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'reported', ?)`
  ).bind(
    reportId,
    farmer.id,
    parsed.data.disease_name.trim(),
    parsed.data.severity,
    parsed.data.affected_count ?? 1,
    parsed.data.lat,
    parsed.data.lng,
    parsed.data.village || farmer.village || null,
    parsed.data.district || farmer.district || null,
    parsed.data.state || farmer.state || null,
    parsed.data.notes || null
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id: reportId,
        disease_name: parsed.data.disease_name,
        severity: parsed.data.severity,
        status: 'reported',
      },
      message: 'Disease report submitted successfully',
    },
    201
  );
});

outbreakRouter.get('/outbreak/map', async (c) => {
  const db = c.env.DB;
  const district = c.req.query('district');
  const state = c.req.query('state');

  let query = 'SELECT * FROM outbreak_reports WHERE 1=1';
  const params: any[] = [];

  if (district) {
    query += ' AND district = ?';
    params.push(district);
  }
  if (state) {
    query += ' AND state = ?';
    params.push(state);
  }

  query += ' ORDER BY created_at DESC LIMIT 100';

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      disease_name: r.disease_name,
      severity: r.severity,
      affected_count: r.affected_count,
      lat: r.lat,
      lng: r.lng,
      village: r.village,
      district: r.district,
      state: r.state,
      status: r.status,
      reported_at: r.created_at,
    })),
    message: 'Outbreak map records',
  });
});

outbreakRouter.get('/outbreak/alerts', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  const district = farmer?.district || c.req.query('district') || 'Anand';

  const rows = await db.prepare(
    `SELECT * FROM outbreak_reports
     WHERE district = ? AND severity IN ('high', 'critical')
     ORDER BY created_at DESC LIMIT 10`
  ).bind(district).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      disease: r.disease_name,
      severity: r.severity,
      village: r.village,
      district: r.district,
      reported_at: r.created_at,
    })),
    message: `Active high-severity outbreak alerts in ${district}`,
  });
});

// ---------------------------------------------------------------------------
// 2. Antibiotic Withdrawal Endpoints
// ---------------------------------------------------------------------------

outbreakRouter.post('/withdrawal/record', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = WithdrawalRecordSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid treatment details' });
  }

  // Verify cattle exists
  const cattle = (await db.prepare('SELECT id FROM cattle WHERE id = ? AND farmer_id = ?').bind(parsed.data.cattle_id, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  const milkSafeDate = addDaysToDate(parsed.data.treatment_end_date, parsed.data.milk_withdrawal_days);
  const meatSafeDate = addDaysToDate(parsed.data.treatment_end_date, parsed.data.meat_withdrawal_days ?? 28);

  const recordId = crypto.randomUUID();
  await db.prepare(
    `INSERT INTO withdrawal_records (
      id, cattle_id, farmer_id, medicine_name, active_ingredient, treatment_start_date,
      treatment_end_date, milk_withdrawal_days, milk_safe_date, meat_withdrawal_days,
      meat_safe_date, is_active
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`
  ).bind(
    recordId,
    parsed.data.cattle_id,
    farmer.id,
    parsed.data.medicine_name.trim(),
    parsed.data.active_ingredient.trim(),
    parsed.data.treatment_start_date,
    parsed.data.treatment_end_date,
    parsed.data.milk_withdrawal_days,
    milkSafeDate,
    parsed.data.meat_withdrawal_days ?? 28,
    meatSafeDate
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id: recordId,
        cattle_id: parsed.data.cattle_id,
        medicine_name: parsed.data.medicine_name,
        milk_withdrawal_days: parsed.data.milk_withdrawal_days,
        milk_safe_date: milkSafeDate,
        is_safe_now: new Date().toISOString().slice(0, 10) >= milkSafeDate,
      },
      message: 'Antibiotic treatment recorded with automated withdrawal schedule',
    },
    201
  );
});

outbreakRouter.get('/withdrawal/active-alerts', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const todayStr = new Date().toISOString().slice(0, 10);
  const rows = await db.prepare(
    `SELECT w.*, c.name as cattle_name, c.tag_id
     FROM withdrawal_records w
     JOIN cattle c ON c.id = w.cattle_id
     WHERE w.farmer_id = ? AND w.milk_safe_date > ? AND w.is_active = 1
     ORDER BY w.milk_safe_date ASC`
  ).bind(farmer.id, todayStr).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      record_id: r.id,
      cattle_name: r.cattle_name,
      tag_id: r.tag_id,
      medicine_name: r.medicine_name,
      milk_withdrawal_days: r.milk_withdrawal_days,
      milk_safe_date: r.milk_safe_date,
      warning: `DO NOT SELL OR CONSUME MILK FROM THIS COW UNTIL ${r.milk_safe_date}.`,
    })),
    count: (rows.results || []).length,
    message: 'Active milk withholding alerts',
  });
});

outbreakRouter.get('/withdrawal/cattle/:cattle_id/history', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT * FROM withdrawal_records WHERE cattle_id = ? ORDER BY treatment_start_date DESC`
  ).bind(cattleId).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      medicine_name: r.medicine_name,
      active_ingredient: r.active_ingredient,
      treatment_start_date: r.treatment_start_date,
      treatment_end_date: r.treatment_end_date,
      milk_withdrawal_days: r.milk_withdrawal_days,
      milk_safe_date: r.milk_safe_date,
    })),
    message: 'Cattle antibiotic history',
  });
});
