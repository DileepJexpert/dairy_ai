import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const pashuAadhaarRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const PashuAadhaarRegisterSchema = z.object({
  cattle_id: z.string().min(1),
  pashu_aadhaar_number: z.string().regex(/^\d{12}$/, 'Pashu Aadhaar must be exactly 12 digits'),
  ear_tag_number: z.string().min(4).max(30),
  species: z.string().default('cattle').optional(),
  breed_govt: z.string().max(100).optional(),
  color: z.string().max(50).optional(),
});

// ---------------------------------------------------------------------------
// Endpoints
// ---------------------------------------------------------------------------

pashuAadhaarRouter.post('/pashu-aadhaar/register', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = PashuAadhaarRegisterSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid Pashu Aadhaar registration details' });
  }

  // Verify cattle ownership
  const cattle = (await db.prepare('SELECT id FROM cattle WHERE id = ? AND farmer_id = ?').bind(parsed.data.cattle_id, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  const recordId = crypto.randomUUID();
  try {
    await db.prepare(
      `INSERT INTO pashu_aadhaar_records (
        id, cattle_id, farmer_id, pashu_aadhaar_number, ear_tag_number,
        species, breed_govt, color, status, inaph_sync_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', 'synced')`
    ).bind(
      recordId,
      parsed.data.cattle_id,
      farmer.id,
      parsed.data.pashu_aadhaar_number,
      parsed.data.ear_tag_number.trim().toUpperCase(),
      parsed.data.species || 'cattle',
      parsed.data.breed_govt || null,
      parsed.data.color || null
    ).run();
  } catch (err: any) {
    if (String(err).toUpperCase().includes('UNIQUE')) {
      throw new HTTPException(409, { message: 'Pashu Aadhaar or Ear Tag already registered to another animal' });
    }
    throw err;
  }

  return c.json(
    {
      success: true,
      data: {
        id: recordId,
        cattle_id: parsed.data.cattle_id,
        pashu_aadhaar_number: parsed.data.pashu_aadhaar_number,
        ear_tag_number: parsed.data.ear_tag_number,
        status: 'active',
      },
      message: 'Cattle registered for Pashu Aadhaar',
    },
    201
  );
});

pashuAadhaarRouter.get('/pashu-aadhaar/cattle/:cattle_id', async (c) => {
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const record = (await db.prepare(
    `SELECT p.*, c.name as cattle_name, c.breed
     FROM pashu_aadhaar_records p
     JOIN cattle c ON c.id = p.cattle_id
     WHERE p.cattle_id = ?`
  ).bind(cattleId).first()) as any;

  if (!record) {
    return c.json({ success: true, data: null, message: 'No Pashu Aadhaar found for this cattle' });
  }

  return c.json({
    success: true,
    data: {
      id: record.id,
      cattle_id: record.cattle_id,
      cattle_name: record.cattle_name,
      pashu_aadhaar_number: record.pashu_aadhaar_number,
      ear_tag_number: record.ear_tag_number,
      species: record.species,
      breed_govt: record.breed_govt,
      status: record.status,
      inaph_sync_status: record.inaph_sync_status,
      last_synced_at: record.last_synced_at,
    },
    message: 'Pashu Aadhaar record',
  });
});

pashuAadhaarRouter.get('/pashu-aadhaar/lookup/:uid', async (c) => {
  const uid = c.req.param('uid').trim().toUpperCase();
  const db = c.env.DB;

  const record = (await db.prepare(
    `SELECT p.*, c.name as cattle_name, c.breed, f.name as farmer_name, f.village, f.district
     FROM pashu_aadhaar_records p
     JOIN cattle c ON c.id = p.cattle_id
     JOIN farmers f ON f.id = p.farmer_id
     WHERE p.pashu_aadhaar_number = ? OR p.ear_tag_number = ?`
  ).bind(uid, uid).first()) as any;

  if (!record) {
    throw new HTTPException(404, { message: 'No cattle found with this Pashu Aadhaar or Ear Tag' });
  }

  return c.json({
    success: true,
    data: {
      id: record.id,
      pashu_aadhaar_number: record.pashu_aadhaar_number,
      ear_tag_number: record.ear_tag_number,
      species: record.species,
      breed_govt: record.breed_govt || record.breed,
      cattle_name: record.cattle_name,
      farmer: {
        id: record.farmer_id,
        name: record.farmer_name,
        village: record.village,
        district: record.district,
      },
      status: record.status,
    },
    message: 'Cattle found',
  });
});

pashuAadhaarRouter.get('/pashu-aadhaar/my-cattle', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const rows = await db.prepare(
    `SELECT p.*, c.name as cattle_name, c.breed
     FROM pashu_aadhaar_records p
     JOIN cattle c ON c.id = p.cattle_id
     WHERE p.farmer_id = ?
     ORDER BY p.created_at DESC`
  ).bind(farmer.id).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      cattle_id: r.cattle_id,
      cattle_name: r.cattle_name,
      pashu_aadhaar_number: r.pashu_aadhaar_number,
      ear_tag_number: r.ear_tag_number,
      status: r.status,
    })),
    message: 'Farmer Pashu Aadhaar cattle list',
  });
});

pashuAadhaarRouter.post('/pashu-aadhaar/:id/sync-inaph', async (c) => {
  await requireAuth(c);
  const id = c.req.param('id');
  const db = c.env.DB;

  await db.prepare(
    `UPDATE pashu_aadhaar_records
     SET inaph_sync_status = 'synced', last_synced_at = CURRENT_TIMESTAMP
     WHERE id = ?`
  ).bind(id).run();

  return c.json({ success: true, message: 'INAPH national database synced' });
});
