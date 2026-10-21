import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const cattleRouter = new Hono<{ Bindings: Env }>();

function normalizeBreed(val: string): 'gir' | 'sahiwal' | 'murrah' | 'hf_crossbred' | 'jersey_crossbred' | 'other' {
  const clean = val.toLowerCase().replace(/[\s-]/g, '_');
  if (clean.includes('gir')) return 'gir';
  if (clean.includes('sahiwal')) return 'sahiwal';
  if (clean.includes('murrah')) return 'murrah';
  if (clean.includes('hf') || clean.includes('holstein')) return 'hf_crossbred';
  if (clean.includes('jersey')) return 'jersey_crossbred';
  return 'other';
}

const BreedSchema = z.string().transform(normalizeBreed);
const SexEnum = z.enum(['female', 'male']);
const StatusEnum = z.enum(['active', 'sold', 'dead', 'dry']);

const CattleCreateSchema = z.object({
  tag_id: z.string().min(2).max(30),
  name: z.string().max(100).nullable().optional(),
  breed: BreedSchema,
  sex: SexEnum.default('female').optional(),
  dob: z.string().nullable().optional(),
  weight_kg: z.number().positive().nullable().optional(),
  photo_url: z.string().nullable().optional(),
  status: StatusEnum.default('active').optional(),
  lactation_number: z.number().int().min(0).default(0).optional(),
  last_calving_date: z.string().nullable().optional(),
});

const CattleUpdateSchema = z.object({
  name: z.string().max(100).nullable().optional(),
  tag_id: z.string().min(2).max(30).optional(),
  breed: BreedSchema.optional(),
  sex: SexEnum.optional(),
  dob: z.string().nullable().optional(),
  weight_kg: z.number().positive().nullable().optional(),
  photo_url: z.string().nullable().optional(),
  status: StatusEnum.optional(),
  lactation_number: z.number().int().min(0).optional(),
  last_calving_date: z.string().nullable().optional(),
});

function formatCattle(c: any): any {
  return {
    id: c.id,
    farmer_id: c.farmer_id,
    tag_id: c.tag_id,
    name: c.name || c.tag_id,
    breed: c.breed,
    sex: c.sex || 'female',
    dob: c.dob || null,
    weight_kg: c.weight_kg ?? null,
    photo_url: c.photo_url || null,
    status: c.status || 'active',
    lactation_number: c.lactation_number || 0,
    last_calving_date: c.last_calving_date || null,
    created_at: c.created_at,
  };
}

// ---------------------------------------------------------------------------
// 1. Register Cattle
// ---------------------------------------------------------------------------

cattleRouter.post('/', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found. Create profile first.' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = CattleCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid cattle registration details' });
  }

  const cattleId = crypto.randomUUID();
  const stmts: D1PreparedStatement[] = [
    db.prepare(
      `INSERT INTO cattle (id, farmer_id, tag_id, name, breed, sex, dob, weight_kg, photo_url, status, lactation_number, last_calving_date)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      cattleId,
      farmer.id,
      parsed.data.tag_id.trim().toUpperCase(),
      parsed.data.name?.trim() || null,
      parsed.data.breed,
      parsed.data.sex || 'female',
      parsed.data.dob || null,
      parsed.data.weight_kg ?? null,
      parsed.data.photo_url || null,
      parsed.data.status || 'active',
      parsed.data.lactation_number || 0,
      parsed.data.last_calving_date || null
    ),
    db.prepare('UPDATE farmers SET total_cattle = total_cattle + 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?').bind(farmer.id),
  ];

  try {
    await db.batch(stmts);
  } catch (err: any) {
    if (String(err).toUpperCase().includes('UNIQUE')) {
      throw new HTTPException(409, { message: 'Cattle with this tag_id already exists' });
    }
    throw err;
  }

  const created = (await db.prepare('SELECT * FROM cattle WHERE id = ?').bind(cattleId).first()) as any;
  return c.json({ success: true, data: formatCattle(created), message: 'Cattle registered' }, 201);
});

// ---------------------------------------------------------------------------
// 2. List Cattle
// ---------------------------------------------------------------------------

cattleRouter.get('/', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found. Create profile first.' });
  }

  const status = c.req.query('status');
  const breed = c.req.query('breed');
  const limit = Math.min(Math.max(Number(c.req.query('limit') || 50), 1), 100);
  const offset = Math.max(Number(c.req.query('offset') || 0), 0);

  let query = 'SELECT * FROM cattle WHERE farmer_id = ?';
  let countQuery = 'SELECT COUNT(*) as cnt FROM cattle WHERE farmer_id = ?';
  const params: any[] = [farmer.id];
  const countParams: any[] = [farmer.id];

  if (status) {
    query += ' AND status = ?';
    countQuery += ' AND status = ?';
    params.push(status);
    countParams.push(status);
  }
  if (breed) {
    query += ' AND breed = ?';
    countQuery += ' AND breed = ?';
    params.push(breed);
    countParams.push(breed);
  }

  query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const [rows, countRow] = await Promise.all([
    db.prepare(query).bind(...params).all(),
    (db.prepare(countQuery).bind(...countParams).first()) as Promise<any>,
  ]);

  const total = countRow?.cnt || 0;
  return c.json({
    success: true,
    data: (rows.results || []).map(formatCattle),
    total,
    message: 'Cattle list',
  });
});

// ---------------------------------------------------------------------------
// 3. Cattle Dashboard
// ---------------------------------------------------------------------------

const cattleDashboardHandler = async (c: any) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found. Create profile first.' });
  }

  const rows = await db.prepare(
    'SELECT status, breed, count(*) as count FROM cattle WHERE farmer_id = ? GROUP BY status, breed'
  ).bind(farmer.id).all();

  let totalCattle = 0;
  let active = 0;
  let dry = 0;
  let sold = 0;
  let dead = 0;
  const breeds: Record<string, number> = {};

  for (const r of (rows.results || []) as any[]) {
    const cnt = Number(r.count);
    totalCattle += cnt;
    if (r.status === 'active') active += cnt;
    if (r.status === 'dry') dry += cnt;
    if (r.status === 'sold') sold += cnt;
    if (r.status === 'dead') dead += cnt;

    breeds[r.breed] = (breeds[r.breed] || 0) + cnt;
  }

  return c.json({
    success: true,
    data: {
      total_cattle: totalCattle,
      active,
      active_cattle: active,
      dry,
      sold,
      dead,
      breeds_breakdown: breeds,
      by_breed: breeds,
    },
    message: 'Cattle dashboard',
  });
};

cattleRouter.get('/dashboard', cattleDashboardHandler);
cattleRouter.get('/stats/dashboard', cattleDashboardHandler);

// ---------------------------------------------------------------------------
// 4. Get Cattle Details
// ---------------------------------------------------------------------------

cattleRouter.get('/:cattle_id', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const cattle = (await db.prepare(
    'SELECT * FROM cattle WHERE id = ? AND farmer_id = ?'
  ).bind(cattleId, farmer.id).first()) as any;

  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  return c.json({ success: true, data: formatCattle(cattle), message: 'Cattle details' });
});

// ---------------------------------------------------------------------------
// 5. Update Cattle Details
// ---------------------------------------------------------------------------

cattleRouter.put('/:cattle_id', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const current = (await db.prepare(
    'SELECT * FROM cattle WHERE id = ? AND farmer_id = ?'
  ).bind(cattleId, farmer.id).first()) as any;

  if (!current) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  const body = await c.req.json().catch(() => ({}));
  const parsed = CattleUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid cattle update details' });
  }

  const name = parsed.data.name !== undefined ? parsed.data.name?.trim() || null : current.name;
  const tagId = parsed.data.tag_id !== undefined ? parsed.data.tag_id.trim() : current.tag_id;
  const breed = parsed.data.breed !== undefined ? parsed.data.breed : current.breed;
  const sex = parsed.data.sex !== undefined ? parsed.data.sex : current.sex;
  const dob = parsed.data.dob !== undefined ? parsed.data.dob : current.dob;
  const weight = parsed.data.weight_kg !== undefined ? parsed.data.weight_kg : current.weight_kg;
  const photo = parsed.data.photo_url !== undefined ? parsed.data.photo_url : current.photo_url;
  const status = parsed.data.status !== undefined ? parsed.data.status : current.status;
  const lactation = parsed.data.lactation_number !== undefined ? parsed.data.lactation_number : current.lactation_number;
  const calving = parsed.data.last_calving_date !== undefined ? parsed.data.last_calving_date : current.last_calving_date;

  await db.prepare(
    `UPDATE cattle
     SET name = ?, tag_id = ?, breed = ?, sex = ?, dob = ?, weight_kg = ?, photo_url = ?, status = ?,
         lactation_number = ?, last_calving_date = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?`
  ).bind(name, tagId, breed, sex, dob, weight, photo, status, lactation, calving, cattleId).run();

  const updated = (await db.prepare('SELECT * FROM cattle WHERE id = ?').bind(cattleId).first()) as any;
  return c.json({ success: true, data: formatCattle(updated), message: 'Cattle updated' });
});

// ---------------------------------------------------------------------------
// 6. Delete Cattle
// ---------------------------------------------------------------------------

cattleRouter.delete('/:cattle_id', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const current = (await db.prepare(
    'SELECT id FROM cattle WHERE id = ? AND farmer_id = ?'
  ).bind(cattleId, farmer.id).first()) as any;

  if (!current) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  await db.batch([
    db.prepare('DELETE FROM cattle WHERE id = ?').bind(cattleId),
    db.prepare('UPDATE farmers SET total_cattle = MAX(0, total_cattle - 1), updated_at = CURRENT_TIMESTAMP WHERE id = ?').bind(farmer.id),
  ]);

  return c.json({ success: true, data: {}, message: 'Cattle deleted' });
});
