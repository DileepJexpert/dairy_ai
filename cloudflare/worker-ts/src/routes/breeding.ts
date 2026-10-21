import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const breedingRouter = new Hono<{ Bindings: Env }>();

const BreedingEventTypeEnum = z.enum([
  'heat_detected',
  'ai_done',
  'pregnancy_confirmed',
  'calving',
  'abortion',
]);

const BreedingEventCreateSchema = z.object({
  event_type: BreedingEventTypeEnum,
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).default(() => new Date().toISOString().slice(0, 10)),
  bull_id: z.string().max(100).nullable().optional(),
  ai_technician: z.string().max(200).nullable().optional(),
  semen_batch: z.string().max(100).nullable().optional(),
  notes: z.string().max(1000).nullable().optional(),
});

function calculateExpectedCalving(aiDateStr: string): string {
  const d = new Date(aiDateStr);
  d.setDate(d.getDate() + 283); // 283 days bovine gestation
  return d.toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------------
// 1. Record Breeding Event
// ---------------------------------------------------------------------------

breedingRouter.post('/cattle/:cattle_id/breeding', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const cattle = (await db.prepare('SELECT id FROM cattle WHERE id = ? AND farmer_id = ?').bind(cattleId, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = BreedingEventCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid breeding event details' });
  }

  let expectedCalvingDate: string | null = null;
  if (parsed.data.event_type === 'ai_done') {
    expectedCalvingDate = calculateExpectedCalving(parsed.data.date);
  }

  const recordId = crypto.randomUUID();
  await db.prepare(
    `INSERT INTO breeding_records (id, cattle_id, event_type, date, bull_id, ai_technician, semen_batch, expected_calving_date, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    recordId,
    cattleId,
    parsed.data.event_type,
    parsed.data.date,
    parsed.data.bull_id || null,
    parsed.data.ai_technician || null,
    parsed.data.semen_batch || null,
    expectedCalvingDate,
    parsed.data.notes || null
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id: recordId,
        event_type: parsed.data.event_type,
        expected_calving_date: expectedCalvingDate,
      },
      message: 'Breeding event recorded',
    },
    201
  );
});

// ---------------------------------------------------------------------------
// 2. Cattle Breeding Timeline
// ---------------------------------------------------------------------------

breedingRouter.get('/cattle/:cattle_id/breeding', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const cattle = (await db.prepare('SELECT id FROM cattle WHERE id = ? AND farmer_id = ?').bind(cattleId, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  const rows = await db.prepare(
    `SELECT * FROM breeding_records
     WHERE cattle_id = ?
     ORDER BY date DESC`
  ).bind(cattleId).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      event_type: r.event_type,
      date: r.date,
      bull_id: r.bull_id,
      ai_technician: r.ai_technician,
      expected_calving_date: r.expected_calving_date,
      notes: r.notes,
    })),
    message: 'Breeding timeline',
  });
});

// ---------------------------------------------------------------------------
// 3. Expected Calvings Schedule
// ---------------------------------------------------------------------------

const calvingScheduleHandler = async (c: any) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const todayStr = new Date().toISOString().slice(0, 10);
  const rows = await db.prepare(
    `SELECT b.id, b.date as ai_date, b.expected_calving_date, c.id as cattle_id, c.tag_id, c.name as cattle_name, c.breed
     FROM breeding_records b
     JOIN cattle c ON c.id = b.cattle_id
     WHERE c.farmer_id = ? AND b.expected_calving_date >= ? AND b.event_type = 'ai_done'
     ORDER BY b.expected_calving_date ASC`
  ).bind(farmer.id, todayStr).all();

  const today = new Date();
  const data = (rows.results || []).map((r: any) => {
    const expDate = new Date(r.expected_calving_date);
    const diffTime = expDate.getTime() - today.getTime();
    const daysRemaining = Math.max(0, Math.ceil(diffTime / (1000 * 60 * 60 * 24)));

    return {
      record_id: r.id,
      cattle_id: r.cattle_id,
      tag_id: r.tag_id,
      cattle_name: r.cattle_name || r.tag_id,
      breed: r.breed,
      ai_date: r.ai_date,
      expected_calving_date: r.expected_calving_date,
      days_remaining: daysRemaining,
    };
  });

  return c.json({
    success: true,
    data,
    total_expected: data.length,
    message: 'Upcoming expected calvings',
  });
};

breedingRouter.get('/farmers/me/expected-calvings', calvingScheduleHandler);
breedingRouter.get('/farmers/me/calving-schedule', calvingScheduleHandler);

breedingRouter.get('/breeding-records', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    return c.json({ success: true, data: [] });
  }
  const cattleId = c.req.query('cattle_id');
  let sql = `SELECT b.*, c.name as cattle_name FROM breeding_records b JOIN cattle c ON c.id = b.cattle_id WHERE c.farmer_id = ?`;
  const params: any[] = [farmer.id];
  if (cattleId) {
    sql += ` AND b.cattle_id = ?`;
    params.push(cattleId);
  }
  sql += ` ORDER BY b.date DESC`;
  const rows = await db.prepare(sql).bind(...params).all();
  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      cattle_id: r.cattle_id,
      cattle_name: r.cattle_name,
      event_type: r.event_type,
      date: r.date,
      bull_id: r.bull_id,
      ai_tech_id: r.bull_id,
      ai_tech_name: r.ai_technician,
      notes: r.notes,
      expected_calving_date: r.expected_calving_date,
      actual_calving_date: r.actual_calving_date,
      calf_id: r.calf_id,
      created_at: r.created_at,
    })),
  });
});
