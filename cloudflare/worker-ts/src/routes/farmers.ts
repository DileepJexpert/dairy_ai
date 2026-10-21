import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';

export const farmersRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const FarmerCreateSchema = z.object({
  name: z.string().min(2).max(100),
  village: z.string().max(100).nullable().optional(),
  district: z.string().max(100).nullable().optional(),
  state: z.string().max(100).nullable().optional(),
  language: z.string().max(10).default('hi').optional(),
  lat: z.number().nullable().optional(),
  lng: z.number().nullable().optional(),
  profile_photo_url: z.string().nullable().optional(),
});

const FarmerUpdateSchema = z.object({
  name: z.string().min(2).max(100).optional(),
  village: z.string().max(100).nullable().optional(),
  district: z.string().max(100).nullable().optional(),
  state: z.string().max(100).nullable().optional(),
  language: z.string().max(10).optional(),
  lat: z.number().nullable().optional(),
  lng: z.number().nullable().optional(),
  profile_photo_url: z.string().nullable().optional(),
});

// ---------------------------------------------------------------------------
// Helper: Resolve Farmer Profile (Auto-Provisions Tenant Space for any User)
// ---------------------------------------------------------------------------

export async function getFarmerByUserId(db: D1Database, userId: string): Promise<any> {
  let row = (await db.prepare('SELECT * FROM farmers WHERE user_id = ?').bind(userId).first()) as any;
  if (!row) {
    const customer = (await db.prepare('SELECT * FROM customers WHERE id = ?').bind(userId).first()) as any;
    const name = customer?.full_name || 'Dairy Farm Owner';
    const phone = customer?.phone || '';
    const farmerId = `farmer-${crypto.randomUUID().slice(0, 10)}`;
    try {
      await db.prepare(
        `INSERT INTO farmers (id, user_id, name, phone, village, district, state, total_cattle)
         VALUES (?, ?, ?, ?, ?, ?, ?, 0)`
      ).bind(farmerId, userId, name, phone, 'My Village', 'My District', 'India').run();
      row = (await db.prepare('SELECT * FROM farmers WHERE id = ?').bind(farmerId).first()) as any;
    } catch {
      row = (await db.prepare('SELECT * FROM farmers WHERE user_id = ?').bind(userId).first()) as any;
    }
  }
  return row || null;
}

// ---------------------------------------------------------------------------
// Endpoints
// ---------------------------------------------------------------------------

farmersRouter.get('/me', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);

  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  return c.json({
    success: true,
    data: {
      id: farmer.id,
      user_id: farmer.user_id,
      name: farmer.name,
      village: farmer.village || '',
      district: farmer.district || '',
      state: farmer.state || '',
      language: farmer.language || 'hi',
      lat: farmer.lat,
      lng: farmer.lng,
      total_cattle: farmer.total_cattle || 0,
      profile_photo_url: farmer.profile_photo_url,
    },
    message: 'Farmer profile',
  });
});

farmersRouter.post('/me', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const existing = (await db.prepare('SELECT * FROM farmers WHERE user_id = ?').bind(user.id).first()) as any;
  const body = await c.req.json().catch(() => null);
  const parsed = FarmerCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid farmer profile details' });
  }

  if (existing) {
    await db.prepare(
      `UPDATE farmers
       SET name = ?, village = ?, district = ?, state = ?, language = ?, lat = ?, lng = ?,
           profile_photo_url = ?, updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`
    ).bind(
      parsed.data.name,
      parsed.data.village || null,
      parsed.data.district || null,
      parsed.data.state || null,
      parsed.data.language || 'hi',
      parsed.data.lat ?? null,
      parsed.data.lng ?? null,
      parsed.data.profile_photo_url || null,
      existing.id
    ).run();

    return c.json({
      success: true,
      data: { id: existing.id, user_id: user.id, ...parsed.data },
      message: 'Farmer profile updated',
    });
  }

  const id = `farmer-${crypto.randomUUID().slice(0, 10)}`;
  await db.prepare(
    `INSERT INTO farmers (id, user_id, name, village, district, state, language, lat, lng, profile_photo_url, total_cattle)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`
  ).bind(
    id,
    user.id,
    parsed.data.name,
    parsed.data.village || null,
    parsed.data.district || null,
    parsed.data.state || null,
    parsed.data.language || 'hi',
    parsed.data.lat ?? null,
    parsed.data.lng ?? null,
    parsed.data.profile_photo_url || null
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id,
        user_id: user.id,
        ...parsed.data,
        total_cattle: 0,
      },
      message: 'Farmer profile created',
    },
    201
  );
});

farmersRouter.put('/me', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = await c.req.json().catch(() => ({}));
  const parsed = FarmerUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid update details' });
  }

  const name = parsed.data.name !== undefined ? parsed.data.name.trim() : farmer.name;
  const village = parsed.data.village !== undefined ? parsed.data.village?.trim() || null : farmer.village;
  const district = parsed.data.district !== undefined ? parsed.data.district?.trim() || null : farmer.district;
  const state = parsed.data.state !== undefined ? parsed.data.state?.trim() || null : farmer.state;
  const language = parsed.data.language !== undefined ? parsed.data.language : farmer.language;
  const lat = parsed.data.lat !== undefined ? parsed.data.lat : farmer.lat;
  const lng = parsed.data.lng !== undefined ? parsed.data.lng : farmer.lng;
  const photo = parsed.data.profile_photo_url !== undefined ? parsed.data.profile_photo_url : farmer.profile_photo_url;

  await db.prepare(
    `UPDATE farmers
     SET name = ?, village = ?, district = ?, state = ?, language = ?, lat = ?, lng = ?,
         profile_photo_url = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?`
  ).bind(name, village, district, state, language, lat, lng, photo, farmer.id).run();

  return c.json({
    success: true,
    data: { id: farmer.id, name },
    message: 'Profile updated',
  });
});

farmersRouter.get('/me/dashboard', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found. Please create your profile first.' });
  }

  const todayStr = new Date().toISOString().slice(0, 10);

  // Cattle count
  const cattleCountRow = (await db.prepare('SELECT COUNT(*) as cnt FROM cattle WHERE farmer_id = ?').bind(farmer.id).first()) as any;
  const cattleCount = cattleCountRow?.cnt || 0;

  // Milk today
  const milkTodayRow = (await db.prepare(
    `SELECT COALESCE(SUM(m.quantity_litres), 0) as total_litres
     FROM milk_records m
     JOIN cattle c ON c.id = m.cattle_id
     WHERE c.farmer_id = ? AND m.date = ?`
  ).bind(farmer.id, todayStr).first()) as any;
  const milkToday = milkTodayRow?.total_litres || 0;

  // Health records count
  const healthCountRow = (await db.prepare(
    `SELECT COUNT(*) as cnt
     FROM health_records h
     JOIN cattle c ON c.id = h.cattle_id
     WHERE c.farmer_id = ?`
  ).bind(farmer.id).first()) as any;
  const healthCount = healthCountRow?.cnt || 0;

  return c.json({
    success: true,
    data: {
      profile: {
        id: farmer.id,
        name: farmer.name,
        village: farmer.village || '',
        district: farmer.district || '',
        state: farmer.state || '',
      },
      stats: {
        total_cattle: cattleCount,
        milk_today_litres: Math.round(Number(milkToday) * 100) / 100,
        total_health_records: healthCount,
      },
    },
    message: 'Farmer dashboard',
  });
});

farmersRouter.get('/:farmer_id', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const farmerId = c.req.param('farmer_id');
  const db = c.env.DB;

  const farmer = (await db.prepare('SELECT * FROM farmers WHERE id = ?').bind(farmerId).first()) as any;
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer not found' });
  }

  return c.json({
    success: true,
    data: {
      id: farmer.id,
      user_id: farmer.user_id,
      name: farmer.name,
      village: farmer.village || '',
      district: farmer.district || '',
      state: farmer.state || '',
      language: farmer.language || 'hi',
      total_cattle: farmer.total_cattle || 0,
    },
    message: 'Farmer profile',
  });
});
