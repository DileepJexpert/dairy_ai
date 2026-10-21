import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';
import { LIVESTOCK_DISEASES, type LivestockDisease } from '../data/livestock_diseases.js';

export const healthRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// 0. Livestock Disease Directory & Clinical Protocols (Public / Instant Access)
// ---------------------------------------------------------------------------

healthRouter.get('/diseases', async (c) => {
  const animal = c.req.query('animal')?.toLowerCase();
  const category = c.req.query('category')?.toLowerCase();
  const severity = c.req.query('severity')?.toLowerCase();
  const symptom = c.req.query('symptom')?.toLowerCase();
  const search = c.req.query('search')?.toLowerCase().trim();

  let results: LivestockDisease[] = [...LIVESTOCK_DISEASES];

  if (animal && animal !== 'all') {
    results = results.filter((d) => d.animalTypes.includes(animal as any));
  }

  if (category && category !== 'all') {
    results = results.filter((d) => d.category.toLowerCase() === category);
  }

  if (severity && severity !== 'all') {
    results = results.filter((d) => d.severity.toLowerCase() === severity);
  }

  if (symptom) {
    results = results.filter((d) => {
      const allSymptoms = [
        ...d.symptoms.primary,
        ...d.symptoms.secondary,
        d.symptoms.vitals.temperatureF,
      ].join(' ').toLowerCase();
      return allSymptoms.includes(symptom);
    });
  }

  if (search) {
    results = results.filter((d) => {
      const searchBlob = [
        d.name,
        d.hindiName,
        d.scientificName,
        d.category,
        d.categoryHindi,
        ...d.symptoms.primary,
        ...d.symptoms.secondary,
        ...d.firstAid.ingredients,
        d.firstAid.preparation,
        d.firstAid.application,
        ...d.suggestedMedicines.map((m) => `${m.molecule} ${m.tradeNames.join(' ')}`),
      ].join(' ').toLowerCase();

      return searchBlob.includes(search);
    });
  }

  return c.json({
    success: true,
    total: results.length,
    data: results,
    timestamp: new Date().toISOString(),
  });
});

healthRouter.get('/diseases/:id', async (c) => {
  const id = c.req.param('id');
  const disease = LIVESTOCK_DISEASES.find((d) => d.id === id);

  if (!disease) {
    throw new HTTPException(404, { message: 'Disease not found in encyclopedia' });
  }

  return c.json({
    success: true,
    data: disease,
  });
});

const RecordTypeEnum = z.enum(['checkup', 'illness', 'treatment', 'surgery', 'observation']);

const HealthRecordCreateSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).default(() => new Date().toISOString().slice(0, 10)),
  record_type: RecordTypeEnum,
  symptoms: z.string().max(2000).nullable().optional(),
  diagnosis: z.string().max(2000).nullable().optional(),
  treatment: z.string().max(2000).nullable().optional(),
  severity: z.number().int().min(1).max(10).nullable().optional(),
  resolved: z.boolean().default(false).optional(),
  notes: z.string().max(1000).nullable().optional(),
});

const VaccinationCreateSchema = z.object({
  vaccine_name: z.string().min(2).max(200),
  batch_number: z.string().max(100).nullable().optional(),
  date_given: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).default(() => new Date().toISOString().slice(0, 10)),
  next_due_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
  administered_by: z.string().max(200).nullable().optional(),
  notes: z.string().max(1000).nullable().optional(),
});

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
// 1. Health Records
// ---------------------------------------------------------------------------

healthRouter.post('/cattle/:cattle_id/health-records', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  await verifyCattleOwnership(db, user.id, cattleId);

  const body = await c.req.json().catch(() => null);
  const parsed = HealthRecordCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid health record details' });
  }

  const recordId = crypto.randomUUID();
  await db.prepare(
    `INSERT INTO health_records (id, cattle_id, date, record_type, symptoms, diagnosis, treatment, severity, resolved, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    recordId,
    cattleId,
    parsed.data.date,
    parsed.data.record_type,
    parsed.data.symptoms || null,
    parsed.data.diagnosis || null,
    parsed.data.treatment || null,
    parsed.data.severity ?? null,
    parsed.data.resolved ? 1 : 0,
    parsed.data.notes || null
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id: recordId,
        cattle_id: cattleId,
        record_type: parsed.data.record_type,
        date: parsed.data.date,
      },
      message: 'Health record created',
    },
    201
  );
});

healthRouter.get('/cattle/:cattle_id/health-records', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  await verifyCattleOwnership(db, user.id, cattleId);

  const rows = await db.prepare(
    `SELECT * FROM health_records
     WHERE cattle_id = ?
     ORDER BY date DESC`
  ).bind(cattleId).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      cattle_id: r.cattle_id,
      date: r.date,
      record_type: r.record_type,
      symptoms: r.symptoms,
      diagnosis: r.diagnosis,
      treatment: r.treatment,
      severity: r.severity,
      resolved: Boolean(r.resolved),
      notes: r.notes,
    })),
    message: 'Health records',
  });
});

// ---------------------------------------------------------------------------
// 2. Vaccinations
// ---------------------------------------------------------------------------

healthRouter.post('/cattle/:cattle_id/vaccinations', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  await verifyCattleOwnership(db, user.id, cattleId);

  const body = await c.req.json().catch(() => null);
  const parsed = VaccinationCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid vaccination details' });
  }

  const vaccId = crypto.randomUUID();
  await db.prepare(
    `INSERT INTO vaccinations (id, cattle_id, vaccine_name, batch_number, date_given, next_due_date, administered_by, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    vaccId,
    cattleId,
    parsed.data.vaccine_name.trim(),
    parsed.data.batch_number?.trim() || null,
    parsed.data.date_given,
    parsed.data.next_due_date || null,
    parsed.data.administered_by?.trim() || null,
    parsed.data.notes || null
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id: vaccId,
        cattle_id: cattleId,
        vaccine_name: parsed.data.vaccine_name.trim(),
        date_given: parsed.data.date_given,
        next_due_date: parsed.data.next_due_date || null,
      },
      message: 'Vaccination recorded',
    },
    201
  );
});

healthRouter.get('/cattle/:cattle_id/vaccinations', async (c) => {
  const user = await requireAuth(c);
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  await verifyCattleOwnership(db, user.id, cattleId);

  const rows = await db.prepare(
    `SELECT * FROM vaccinations
     WHERE cattle_id = ?
     ORDER BY date_given DESC`
  ).bind(cattleId).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      cattle_id: r.cattle_id,
      vaccine_name: r.vaccine_name,
      batch_number: r.batch_number,
      date_given: r.date_given,
      next_due_date: r.next_due_date,
      administered_by: r.administered_by,
      notes: r.notes,
    })),
    message: 'Vaccinations list',
  });
});

// ---------------------------------------------------------------------------
// 3. Upcoming Herd Vaccinations Alert
// ---------------------------------------------------------------------------

healthRouter.get('/farmers/me/upcoming-vaccinations', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const todayStr = new Date().toISOString().slice(0, 10);
  const rows = await db.prepare(
    `SELECT v.id, v.vaccine_name, v.date_given, v.next_due_date, c.id as cattle_id, c.tag_id, c.name as cattle_name
     FROM vaccinations v
     JOIN cattle c ON c.id = v.cattle_id
     WHERE c.farmer_id = ? AND v.next_due_date >= ?
     ORDER BY v.next_due_date ASC`
  ).bind(farmer.id, todayStr).all();

  const today = new Date();
  const data = (rows.results || []).map((r: any) => {
    const dueDate = new Date(r.next_due_date);
    const diffTime = dueDate.getTime() - today.getTime();
    const daysUntilDue = Math.max(0, Math.ceil(diffTime / (1000 * 60 * 60 * 24)));

    return {
      vaccination_id: r.id,
      cattle_id: r.cattle_id,
      tag_id: r.tag_id,
      cattle_name: r.cattle_name || r.tag_id,
      vaccine_name: r.vaccine_name,
      last_given: r.date_given,
      next_due_date: r.next_due_date,
      days_until_due: daysUntilDue,
    };
  });

  return c.json({
    success: true,
    data,
    total_upcoming: data.length,
    message: 'Upcoming herd vaccinations',
  });
});

healthRouter.get('/health-records', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) return c.json({ success: true, data: [] });
  const cattleId = c.req.query('cattle_id');
  let sql = `SELECT h.*, c.name as cattle_name FROM health_records h JOIN cattle c ON c.id = h.cattle_id WHERE c.farmer_id = ?`;
  const params: any[] = [farmer.id];
  if (cattleId) {
    sql += ` AND h.cattle_id = ?`;
    params.push(cattleId);
  }
  sql += ` ORDER BY h.date DESC`;
  const rows = await db.prepare(sql).bind(...params).all();
  return c.json({
    success: true,
    data: (rows.results || []).map((h: any) => ({
      id: h.id,
      cattle_id: h.cattle_id,
      cattle_name: h.cattle_name,
      date: h.date,
      record_type: h.record_type,
      symptoms: h.symptoms,
      diagnosis: h.diagnosis,
      treatment: h.treatment,
      vet_id: h.vet_id,
      severity: h.severity,
      resolved: h.resolved === 1,
      notes: h.notes,
      created_at: h.created_at,
    })),
  });
});

healthRouter.get('/vaccinations', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;
  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) return c.json({ success: true, data: [] });
  const cattleId = c.req.query('cattle_id');
  let sql = `SELECT v.*, c.name as cattle_name FROM vaccinations v JOIN cattle c ON c.id = v.cattle_id WHERE c.farmer_id = ?`;
  const params: any[] = [farmer.id];
  if (cattleId) {
    sql += ` AND v.cattle_id = ?`;
    params.push(cattleId);
  }
  sql += ` ORDER BY v.date_given DESC`;
  const rows = await db.prepare(sql).bind(...params).all();
  return c.json({
    success: true,
    data: (rows.results || []).map((v: any) => ({
      id: v.id,
      cattle_id: v.cattle_id,
      cattle_name: v.cattle_name,
      vaccine_name: v.vaccine_name,
      batch_number: v.batch_number,
      date_given: v.date_given,
      next_due_date: v.next_due_date,
      administered_by: v.administered_by,
      notes: v.notes,
      created_at: v.created_at,
    })),
  });
});
