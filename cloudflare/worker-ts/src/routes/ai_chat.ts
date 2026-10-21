import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const aiChatRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const TriageRequestSchema = z.object({
  cattle_id: z.string().min(1),
  symptoms: z.string().min(3).max(2000),
  photo_urls: z.array(z.string()).optional(),
});

const ChatMessageSchema = z.object({
  message: z.string().min(1).max(2000),
  cattle_id: z.string().optional(),
});

// ---------------------------------------------------------------------------
// Clinical Triage Scoring Engine (Rule-based Expert System)
// ---------------------------------------------------------------------------

export interface TriageResult {
  severity: number; // 1-10
  severity_level: 'low' | 'medium' | 'high' | 'emergency';
  preliminary_diagnosis: string;
  confidence: number;
  recommended_action: 'self_care' | 'schedule_visit' | 'video_consult' | 'emergency';
  reasoning: string;
}

export function evaluateTriage(
  symptoms: string,
  sensorData?: { temperature?: number | null; heart_rate?: number | null; activity_level?: number | null } | null
): TriageResult {
  let score = 0;
  const reasons: string[] = [];

  // 1. Evaluate Sensor Data
  if (sensorData) {
    const temp = sensorData.temperature;
    const hr = sensorData.heart_rate;
    const activity = sensorData.activity_level;

    if (temp && temp > 40.0) {
      score += 3;
      reasons.push(`High fever (${temp}°C)`);
    } else if (temp && temp > 39.5) {
      score += 2;
      reasons.push(`Elevated body temperature (${temp}°C)`);
    }

    if (hr && hr > 80) {
      score += 2;
      reasons.push(`High heart rate (${hr} bpm)`);
    }

    if (activity !== null && activity !== undefined && activity < 20) {
      score += 2;
      reasons.push(`Very low physical activity (${activity})`);
    }
  }

  // 2. Keyword Symptom Scoring
  const sLower = symptoms.toLowerCase();
  const keywords: Record<string, number> = {
    'down': 4, 'collapsed': 4, 'cannot stand': 4,
    'bloat': 3, 'bloated': 3,
    'mastitis': 3, 'udder': 2, 'swollen udder': 3,
    'blood': 3, 'bleeding': 3,
    'not eating': 2, 'off feed': 2, 'no appetite': 2,
    'fever': 2, 'shivering': 2,
    'swelling': 2, 'discharge': 2,
    'diarrhea': 2, 'loose motion': 2,
    'limping': 1, 'lame': 1,
    'cough': 1, 'coughing': 1,
  };

  for (const [kw, pts] of Object.entries(keywords)) {
    if (sLower.includes(kw)) {
      score += pts;
      reasons.push(`Reported symptom: ${kw}`);
    }
  }

  // 3. Preliminary Clinical Diagnosis Mapping
  let preliminaryDiagnosis = 'General observation needed';
  if (sLower.includes('bloat') || sLower.includes('bloated')) {
    preliminaryDiagnosis = 'Acute Ruminal Tympany (Bloat)';
  } else if (sLower.includes('mastitis') || sLower.includes('udder')) {
    preliminaryDiagnosis = 'Bovine Clinical Mastitis';
  } else if (score >= 4 && (sLower.includes('fever') || (sensorData?.temperature && sensorData.temperature > 39.5))) {
    preliminaryDiagnosis = 'Bovine Ephemeral Fever / Systemic Infection';
  } else if (sLower.includes('limp') || sLower.includes('lame')) {
    preliminaryDiagnosis = 'Foot Rot / Locomotor Lameness';
  } else if (sLower.includes('down') || sLower.includes('collapsed')) {
    preliminaryDiagnosis = 'Downer Cow Syndrome / Hypocalcemia (Milk Fever)';
  }

  // 4. Severity Level & Recommended Action
  const severity = Math.min(10, Math.max(1, score));
  let severityLevel: 'low' | 'medium' | 'high' | 'emergency';
  let recommendedAction: 'self_care' | 'schedule_visit' | 'video_consult' | 'emergency';

  if (severity >= 7) {
    severityLevel = 'emergency';
    recommendedAction = 'emergency';
  } else if (severity >= 5) {
    severityLevel = 'high';
    recommendedAction = 'video_consult';
  } else if (severity >= 3) {
    severityLevel = 'medium';
    recommendedAction = 'schedule_visit';
  } else {
    severityLevel = 'low';
    recommendedAction = 'self_care';
  }

  return {
    severity,
    severity_level: severityLevel,
    preliminary_diagnosis: preliminaryDiagnosis,
    confidence: score > 3 ? 0.85 : 0.70,
    recommended_action: recommendedAction,
    reasoning: reasons.length > 0 ? reasons.join('; ') : 'Routine physical checkup recommended',
  };
}

// ---------------------------------------------------------------------------
// 1. Symptom Triage Endpoint
// ---------------------------------------------------------------------------

aiChatRouter.post('/triage', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = TriageRequestSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid triage request details' });
  }

  const cattle = (await db.prepare('SELECT id, name, breed FROM cattle WHERE id = ? AND farmer_id = ?').bind(parsed.data.cattle_id, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  // Fetch latest sensor reading if available
  const latestSensor = (await db.prepare(
    'SELECT temperature, heart_rate, activity_level FROM sensor_readings WHERE cattle_id = ? ORDER BY created_at DESC, rowid DESC LIMIT 1'
  ).bind(parsed.data.cattle_id).first()) as any;

  const result = evaluateTriage(parsed.data.symptoms, latestSensor);

  // Auto-record as an observation health record
  const recordId = crypto.randomUUID();
  const todayStr = new Date().toISOString().slice(0, 10);
  await db.prepare(
    `INSERT INTO health_records (id, cattle_id, date, record_type, symptoms, diagnosis, severity, notes)
     VALUES (?, ?, ?, 'observation', ?, ?, ?, ?)`
  ).bind(
    recordId,
    parsed.data.cattle_id,
    todayStr,
    parsed.data.symptoms.trim(),
    result.preliminary_diagnosis,
    result.severity,
    `AI Triage: ${result.reasoning}`
  ).run();

  return c.json({
    success: true,
    data: {
      health_record_id: recordId,
      cattle_name: cattle.name,
      severity: result.severity,
      severity_level: result.severity_level,
      preliminary_diagnosis: result.preliminary_diagnosis,
      confidence: result.confidence,
      recommended_action: result.recommended_action,
      reasoning: result.reasoning,
    },
    message: 'Triage complete',
  });
});

// ---------------------------------------------------------------------------
// 2. Pashu Mitra AI Farmer Chat Assistant
// ---------------------------------------------------------------------------

aiChatRouter.post('/chat/message', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = ChatMessageSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Message cannot be empty' });
  }

  let cattleContext = '';
  if (parsed.data.cattle_id) {
    const cattle = (await db.prepare('SELECT name, breed, status, weight_kg FROM cattle WHERE id = ?').bind(parsed.data.cattle_id).first()) as any;
    if (cattle) {
      cattleContext = `Cattle: ${cattle.name || 'Unnamed'} (${cattle.breed}, Status: ${cattle.status}, Weight: ${cattle.weight_kg}kg). `;
    }
  }

  // Domain expert knowledge responder for dairy farmers
  const msgLower = parsed.data.message.toLowerCase();
  let reply = '';

  if (msgLower.includes('mastitis') || msgLower.includes('udder')) {
    reply = `${cattleContext}Mastitis is an inflammation of the mammary gland. Recommended immediate actions: 1. Clean teats with potassium permanganate (1:1000) or povidone-iodine teat dip. 2. Completely strip out the affected quarter into a discard container. 3. Apply cold water compresses if swollen. 4. Consult a veterinarian immediately for antibiotic intramammary infusion. Do NOT mix this milk with normal bulk milk.`;
  } else if (msgLower.includes('feed') || msgLower.includes('diet') || msgLower.includes('fodder')) {
    reply = `${cattleContext}Optimal dairy cow nutrition requires: 1. Green Fodder (Napier/Lucerne): 15-20 kg/day. 2. Dry Straw: 4-6 kg/day. 3. Concentrate feed (20% bypass protein): 3 kg base + 1 kg per 2.5 litres of milk produced. 4. Chelated mineral mixture: 50-100 grams/day with clean drinking water available ad libitum.`;
  } else if (msgLower.includes('heat') || msgLower.includes('ai') || msgLower.includes('breeding')) {
    reply = `${cattleContext}Standing heat in cattle lasts 12-18 hours. Follow the AM-PM rule: If cow shows estrus (mounting, clear vaginal discharge, bellowing) in morning, perform Artificial Insemination (AI) in evening. If heat detected in evening, perform AI next morning. Bovine gestation lasts 283 days.`;
  } else if (msgLower.includes('vaccin') || msgLower.includes('fmd') || msgLower.includes('hs') || msgLower.includes('bq')) {
    reply = `${cattleContext}Core vaccination calendar for dairy cattle: 1. Foot & Mouth Disease (FMD): Every 6 months (Pre-monsoon & Post-monsoon). 2. Haemorrhagic Septicaemia (HS): Annually in May-June. 3. Black Quarter (BQ): Annually in May-June. 4. Brucellosis: Once in lifetime for female calves (4-8 months old).`;
  } else {
    reply = `${cattleContext}Hello! I am Pashu Mitra, your DairyAI dairy farm advisor. I can assist you with feed formulation, cattle breeding & calving dates, disease triage & symptoms, vaccination schedules, and milk production forecasting. How can I assist your herd today?`;
  }

  return c.json({
    success: true,
    data: { response: reply },
    message: 'Chat response',
  });
});
