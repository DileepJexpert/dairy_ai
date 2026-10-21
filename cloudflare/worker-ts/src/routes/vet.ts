import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const vetRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const VetRegisterSchema = z.object({
  license_number: z.string().min(3).max(50),
  qualification: z.string().min(2).max(100),
  specializations: z.array(z.string()).default([]).optional(),
  experience_years: z.number().int().min(0).default(0).optional(),
  languages: z.array(z.string()).default(['hi']).optional(),
  consultation_fee: z.number().nonnegative().default(200.0).optional(),
  bio: z.string().max(1000).nullable().optional(),
  pincode: z.string().max(20).nullable().optional(),
  city: z.string().max(100).nullable().optional(),
  district: z.string().max(100).nullable().optional(),
  state: z.string().max(100).nullable().optional(),
  service_radius_km: z.number().positive().default(25.0).optional(),
});

const VetUpdateSchema = z.object({
  qualification: z.string().min(2).max(100).optional(),
  specializations: z.array(z.string()).optional(),
  experience_years: z.number().int().min(0).optional(),
  languages: z.array(z.string()).optional(),
  consultation_fee: z.number().nonnegative().optional(),
  bio: z.string().max(1000).nullable().optional(),
  pincode: z.string().max(20).nullable().optional(),
  city: z.string().max(100).nullable().optional(),
  district: z.string().max(100).nullable().optional(),
  state: z.string().max(100).nullable().optional(),
  service_radius_km: z.number().positive().optional(),
});

const ConsultationCreateSchema = z.object({
  cattle_id: z.string().min(1),
  consultation_type: z.enum(['video', 'audio', 'chat', 'in_person']).default('video').optional(),
  symptoms: z.string().min(3).max(2000),
  vet_id: z.string().nullable().optional(),
});

const PrescriptionCreateSchema = z.object({
  medicines: z.array(
    z.object({
      name: z.string().min(1),
      dosage: z.string().min(1),
      duration_days: z.number().int().positive(),
      instructions: z.string().optional(),
    })
  ).min(1),
  instructions: z.string().max(2000).nullable().optional(),
  follow_up_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
});

const RatingCreateSchema = z.object({
  rating: z.number().int().min(1).max(5),
  review: z.string().max(1000).nullable().optional(),
});

// Helper: Get Vet Profile
export async function getVetByUserId(db: D1Database, userId: string): Promise<any> {
  return (await db.prepare('SELECT * FROM vets WHERE user_id = ?').bind(userId).first()) as any;
}

// ---------------------------------------------------------------------------
// 1. Vet Profile Endpoints
// ---------------------------------------------------------------------------

vetRouter.post('/vets/register', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const existing = await getVetByUserId(db, user.id);
  if (existing) {
    throw new HTTPException(400, { message: 'Vet profile already exists' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = VetRegisterSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid vet registration details' });
  }

  const vetId = crypto.randomUUID();
  try {
    await db.prepare(
      `INSERT INTO vets (
        id, user_id, license_number, qualification, specializations, experience_years,
        languages, consultation_fee, bio, pincode, city, district, state, service_radius_km
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      vetId,
      user.id,
      parsed.data.license_number.trim().toUpperCase(),
      parsed.data.qualification.trim(),
      JSON.stringify(parsed.data.specializations || []),
      parsed.data.experience_years ?? 0,
      JSON.stringify(parsed.data.languages || ['hi']),
      parsed.data.consultation_fee ?? 200.0,
      parsed.data.bio || null,
      parsed.data.pincode || null,
      parsed.data.city || null,
      parsed.data.district || null,
      parsed.data.state || null,
      parsed.data.service_radius_km ?? 25.0
    ).run();

    // Upgrade customer role to vet so routing and permissions apply immediately
    await db.prepare("UPDATE customers SET role = 'vet' WHERE id = ?").bind(user.id).run();
  } catch (err: any) {
    if (String(err).toUpperCase().includes('UNIQUE')) {
      throw new HTTPException(409, { message: 'License number already registered' });
    }
    throw err;
  }

  return c.json(
    {
      success: true,
      data: { id: vetId, license_number: parsed.data.license_number },
      message: 'Vet profile registered. Awaiting verification.',
    },
    201
  );
});

vetRouter.get('/vets/search', async (c) => {
  const db = c.env.DB;
  const district = c.req.query('district');
  const pincode = c.req.query('pincode');
  const availableOnly = c.req.query('available') === 'true';

  let query = 'SELECT v.*, u.full_name as vet_name, u.phone as vet_phone FROM vets v JOIN customers u ON u.id = v.user_id WHERE 1=1';
  const params: any[] = [];

  if (district) {
    query += ' AND v.district = ?';
    params.push(district);
  }
  if (pincode) {
    query += ' AND v.pincode = ?';
    params.push(pincode);
  }
  if (availableOnly) {
    query += ' AND v.is_available = 1';
  }

  query += ' ORDER BY v.rating_avg DESC, v.total_consultations DESC LIMIT 50';

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      user_id: r.user_id || r.id,
      name: r.vet_name || 'Veterinarian',
      license_number: r.license_number,
      license_no: r.license_number,
      qualification: r.qualification,
      experience_years: r.experience_years,
      consultation_fee: r.consultation_fee,
      fee: r.consultation_fee,
      rating_avg: r.rating_avg,
      rating: r.rating_avg,
      total_consultations: r.total_consultations,
      is_verified: Boolean(r.is_verified),
      is_available: Boolean(r.is_available),
      specializations: r.specializations ? r.specializations.split(',').map((s: string) => s.trim()) : ['Bovine Health'],
      languages: r.languages ? r.languages.split(',').map((l: string) => l.trim()) : ['Hindi', 'English'],
      district: r.district,
      city: r.city,
      pincode: r.pincode,
      lat: r.lat,
      lng: r.lng,
      bio: r.bio,
    })),
    message: 'Veterinarians',
  });
});

vetRouter.get('/vets/me', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const vet = await getVetByUserId(db, user.id);
  if (!vet) {
    throw new HTTPException(404, { message: 'Vet profile not found' });
  }

  return c.json({
    success: true,
    data: {
      id: vet.id,
      user_id: vet.user_id,
      license_number: vet.license_number,
      qualification: vet.qualification,
      experience_years: vet.experience_years,
      consultation_fee: vet.consultation_fee,
      rating_avg: vet.rating_avg,
      total_consultations: vet.total_consultations,
      total_earnings: vet.total_earnings,
      is_verified: Boolean(vet.is_verified),
      is_available: Boolean(vet.is_available),
      district: vet.district,
      city: vet.city,
    },
    message: 'Vet profile',
  });
});

vetRouter.put('/vets/me', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const vet = await getVetByUserId(db, user.id);
  if (!vet) {
    throw new HTTPException(404, { message: 'Vet profile not found' });
  }

  const body = await c.req.json().catch(() => ({}));
  const parsed = VetUpdateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid vet update data' });
  }

  const qual = parsed.data.qualification || vet.qualification;
  const exp = parsed.data.experience_years ?? vet.experience_years;
  const fee = parsed.data.consultation_fee ?? vet.consultation_fee;
  const bio = parsed.data.bio !== undefined ? parsed.data.bio : vet.bio;
  const dist = parsed.data.district || vet.district;

  await db.prepare(
    `UPDATE vets
     SET qualification = ?, experience_years = ?, consultation_fee = ?, bio = ?, district = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?`
  ).bind(qual, exp, fee, bio, dist, vet.id).run();

  return c.json({ success: true, message: 'Vet profile updated' });
});

vetRouter.put('/vets/me/availability', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const vet = await getVetByUserId(db, user.id);
  if (!vet) {
    throw new HTTPException(404, { message: 'Vet profile not found' });
  }

  const body = await c.req.json().catch(() => ({}));
  const isAvailable = body.is_available ? 1 : 0;

  await db.prepare('UPDATE vets SET is_available = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').bind(isAvailable, vet.id).run();

  return c.json({
    success: true,
    data: { is_available: Boolean(isAvailable) },
    message: 'Availability updated',
  });
});

vetRouter.get('/vets/me/dashboard', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const vet = await getVetByUserId(db, user.id);
  if (!vet) {
    throw new HTTPException(404, { message: 'Vet profile not found' });
  }

  const queueCount = (await db.prepare(
    "SELECT COUNT(*) as count FROM consultations WHERE status = 'requested'"
  ).first()) as any;

  const activeCount = (await db.prepare(
    "SELECT COUNT(*) as count FROM consultations WHERE vet_id = ? AND status = 'in_progress'"
  ).bind(vet.id).first()) as any;

  const completedToday = (await db.prepare(
    "SELECT COUNT(*) as count, COALESCE(SUM(vet_payout), 0) as earnings FROM consultations WHERE vet_id = ? AND status = 'completed' AND DATE(ended_at) = DATE('now')"
  ).bind(vet.id).first()) as any;

  return c.json({
    success: true,
    data: {
      pending_requests: queueCount?.count || 0,
      active_consultations: activeCount?.count || 0,
      today_completed: completedToday?.count || 0,
      today_earnings: Math.round(Number(completedToday?.earnings || 0) * 100) / 100,
      overall_rating: vet.rating_avg,
      total_consultations: vet.total_consultations,
      is_available: Boolean(vet.is_available),
    },
    message: 'Vet dashboard',
  });
});

vetRouter.post('/vets/:id/verify', async (c) => {
  await requireAuth(c, ['admin', 'super_admin']);
  const vetId = c.req.param('id');
  const db = c.env.DB;

  const vet = (await db.prepare('SELECT id FROM vets WHERE id = ?').bind(vetId).first()) as any;
  if (!vet) {
    throw new HTTPException(404, { message: 'Vet not found' });
  }

  await db.prepare('UPDATE vets SET is_verified = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?').bind(vetId).run();

  return c.json({ success: true, message: 'Vet license verified' });
});

// ---------------------------------------------------------------------------
// 2. Consultation Flow Endpoints
// ---------------------------------------------------------------------------

vetRouter.post('/consultations', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found. Register farmer profile first.' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = ConsultationCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid consultation request' });
  }

  const cattle = (await db.prepare('SELECT id FROM cattle WHERE id = ? AND farmer_id = ?').bind(parsed.data.cattle_id, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  const consultationId = crypto.randomUUID();
  const feeAmount = 250.0;
  const platformFee = 25.0;
  const vetPayout = 225.0;

  await db.prepare(
    `INSERT INTO consultations (id, farmer_id, cattle_id, vet_id, consultation_type, status, symptoms, fee_amount, platform_fee, vet_payout)
     VALUES (?, ?, ?, ?, ?, 'requested', ?, ?, ?, ?)`
  ).bind(
    consultationId,
    farmer.id,
    parsed.data.cattle_id,
    parsed.data.vet_id || null,
    parsed.data.consultation_type || 'video',
    parsed.data.symptoms.trim(),
    feeAmount,
    platformFee,
    vetPayout
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id: consultationId,
        farmer_id: farmer.id,
        cattle_id: parsed.data.cattle_id,
        status: 'requested',
        fee_amount: feeAmount,
      },
      message: 'Consultation requested',
    },
    201
  );
});

vetRouter.get('/consultations/me', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const rows = await db.prepare(
    `SELECT c.*, cat.name as cattle_name, cat.tag_id
     FROM consultations c
     JOIN cattle cat ON cat.id = c.cattle_id
     WHERE c.farmer_id = ?
     ORDER BY c.created_at DESC`
  ).bind(farmer.id).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      cattle_name: r.cattle_name,
      tag_id: r.tag_id,
      type: r.consultation_type,
      status: r.status,
      symptoms: r.symptoms,
      vet_diagnosis: r.vet_diagnosis,
      fee_amount: r.fee_amount,
      created_at: r.created_at,
    })),
    message: 'Farmer consultations',
  });
});

vetRouter.get('/consultations/queue', async (c) => {
  await requireAuth(c);
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT c.*, cat.name as cattle_name, cat.tag_id, f.name as farmer_name, f.village
     FROM consultations c
     JOIN cattle cat ON cat.id = c.cattle_id
     JOIN farmers f ON f.id = c.farmer_id
     WHERE c.status = 'requested'
     ORDER BY c.created_at ASC LIMIT 50`
  ).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      farmer_name: r.farmer_name,
      village: r.village,
      cattle_name: r.cattle_name,
      tag_id: r.tag_id,
      type: r.consultation_type,
      symptoms: r.symptoms,
      fee_amount: r.fee_amount,
      created_at: r.created_at,
    })),
    message: 'Consultation queue',
  });
});

vetRouter.put('/consultations/:id/accept', async (c) => {
  const user = await requireAuth(c);
  const consultationId = c.req.param('id');
  const db = c.env.DB;

  const vet = await getVetByUserId(db, user.id);
  if (!vet) {
    throw new HTTPException(404, { message: 'Vet profile not found' });
  }

  await db.prepare(
    `UPDATE consultations SET vet_id = ?, status = 'accepted' WHERE id = ? AND status = 'requested'`
  ).bind(vet.id, consultationId).run();

  return c.json({ success: true, message: 'Consultation accepted' });
});

vetRouter.put('/consultations/:id/start', async (c) => {
  await requireAuth(c);
  const consultationId = c.req.param('id');
  const db = c.env.DB;

  await db.prepare(
    `UPDATE consultations SET status = 'in_progress', started_at = CURRENT_TIMESTAMP WHERE id = ?`
  ).bind(consultationId).run();

  return c.json({ success: true, message: 'Consultation started' });
});

vetRouter.put('/consultations/:id/end', async (c) => {
  const user = await requireAuth(c);
  const consultationId = c.req.param('id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => ({}));
  const diagnosis = body.vet_diagnosis || 'Examination completed';
  const notes = body.vet_notes || null;

  const cObj = (await db.prepare('SELECT vet_id, vet_payout FROM consultations WHERE id = ?').bind(consultationId).first()) as any;
  if (!cObj) {
    throw new HTTPException(404, { message: 'Consultation not found' });
  }

  const stmts: D1PreparedStatement[] = [
    db.prepare(
      `UPDATE consultations
       SET status = 'completed', vet_diagnosis = ?, vet_notes = ?, ended_at = CURRENT_TIMESTAMP, duration_seconds = 600
       WHERE id = ?`
    ).bind(diagnosis, notes, consultationId),
  ];

  if (cObj.vet_id) {
    stmts.push(
      db.prepare(
        `UPDATE vets
         SET total_consultations = total_consultations + 1,
             total_earnings = total_earnings + ?,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = ?`
      ).bind(cObj.vet_payout || 225.0, cObj.vet_id)
    );
  }

  await db.batch(stmts);

  return c.json({ success: true, message: 'Consultation completed' });
});

vetRouter.post('/consultations/:id/prescription', async (c) => {
  const user = await requireAuth(c);
  const consultationId = c.req.param('id');
  const db = c.env.DB;

  const vet = await getVetByUserId(db, user.id);
  if (!vet) {
    throw new HTTPException(404, { message: 'Vet profile not found' });
  }

  const cObj = (await db.prepare('SELECT cattle_id FROM consultations WHERE id = ?').bind(consultationId).first()) as any;
  if (!cObj) {
    throw new HTTPException(404, { message: 'Consultation not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = PrescriptionCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid prescription format' });
  }

  const presId = crypto.randomUUID();
  await db.prepare(
    `INSERT INTO prescriptions (id, consultation_id, cattle_id, vet_id, medicines, instructions, follow_up_date)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    presId,
    consultationId,
    cObj.cattle_id,
    vet.id,
    JSON.stringify(parsed.data.medicines),
    parsed.data.instructions || null,
    parsed.data.follow_up_date || null
  ).run();

  return c.json(
    {
      success: true,
      data: { id: presId, medicines: parsed.data.medicines },
      message: 'Prescription issued',
    },
    201
  );
});

vetRouter.put('/consultations/:id/rate', async (c) => {
  await requireAuth(c);
  const consultationId = c.req.param('id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = RatingCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid rating (1 to 5 required)' });
  }

  const cObj = (await db.prepare('SELECT vet_id FROM consultations WHERE id = ?').bind(consultationId).first()) as any;
  if (!cObj) {
    throw new HTTPException(404, { message: 'Consultation not found' });
  }

  await db.prepare(
    `UPDATE consultations SET farmer_rating = ?, farmer_review = ? WHERE id = ?`
  ).bind(parsed.data.rating, parsed.data.review || null, consultationId).run();

  if (cObj.vet_id) {
    const avgRow = (await db.prepare(
      `SELECT AVG(farmer_rating) as avg_rating FROM consultations WHERE vet_id = ? AND farmer_rating IS NOT NULL`
    ).bind(cObj.vet_id).first()) as any;

    if (avgRow?.avg_rating) {
      await db.prepare('UPDATE vets SET rating_avg = ? WHERE id = ?').bind(Math.round(Number(avgRow.avg_rating) * 10) / 10, cObj.vet_id).run();
    }
  }

  return c.json({ success: true, message: 'Consultation rated successfully' });
});
