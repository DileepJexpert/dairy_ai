import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';

export const iotRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

export const SensorDataCreateSchema = z.object({
  temperature: z.number().nullable().optional(),
  heart_rate: z.number().int().nullable().optional(),
  activity_level: z.number().int().nullable().optional(),
  rumination_minutes: z.number().nullable().optional(),
  battery_pct: z.number().int().min(0).max(100).nullable().optional(),
  rssi: z.number().int().nullable().optional(),
});

export const IoTCommandCreateSchema = z.object({
  command: z.enum(['SET_INTERVAL', 'REBOOT', 'OTA_UPDATE', 'STATUS_REQUEST']),
  param_int: z.number().int().optional(),
  param_str: z.string().max(500).optional(),
});

export interface AnomalyAlert {
  cattle_id: string;
  alert_type: 'high_temperature' | 'high_heart_rate' | 'activity_drop' | 'low_battery';
  message: string;
  current_value: number;
  threshold: number;
}

// ---------------------------------------------------------------------------
// Sensor Validation & Anomaly Engine
// ---------------------------------------------------------------------------

export function validateSensorRanges(payload: {
  temperature?: number | null;
  heart_rate?: number | null;
  activity_level?: number | null;
}): {
  temp: number | null;
  hr: number | null;
  activity: number | null;
} {
  let temp = payload.temperature ?? null;
  if (temp !== null && temp < 0) temp = null; // Negative treated as sensor unavailable
  if (temp !== null && (temp < 35.0 || temp > 42.0)) {
    throw new HTTPException(422, { message: `Temperature ${temp}°C out of valid biological range (35.0-42.0°C)` });
  }

  let hr = payload.heart_rate ?? null;
  if (hr !== null && hr < 0) hr = null;
  if (hr !== null && (hr < 40 || hr > 120)) {
    throw new HTTPException(422, { message: `Heart rate ${hr} bpm out of valid biological range (40-120 bpm)` });
  }

  let activity = payload.activity_level ?? null;
  if (activity !== null && activity < 0) activity = null;
  if (activity !== null && (activity < 0 || activity > 100)) {
    throw new HTTPException(422, { message: `Activity level ${activity} out of valid range (0-100)` });
  }

  return { temp, hr, activity };
}

export async function detectAnomalies(
  db: D1Database,
  cattleId: string,
  reading: {
    temp: number | null;
    hr: number | null;
    activity: number | null;
    battery_pct?: number | null;
  }
): Promise<AnomalyAlert[]> {
  const alerts: AnomalyAlert[] = [];

  // 1. Fever / High Temperature Check (> 39.5°C)
  if (reading.temp !== null && reading.temp > 39.5) {
    alerts.push({
      cattle_id: cattleId,
      alert_type: 'high_temperature',
      message: `Temperature ${reading.temp}°C is above normal (>39.5°C). Possible fever or systemic infection.`,
      current_value: reading.temp,
      threshold: 39.5,
    });
  }

  // 2. High Heart Rate Check (> 80 bpm)
  if (reading.hr !== null && reading.hr > 80) {
    alerts.push({
      cattle_id: cattleId,
      alert_type: 'high_heart_rate',
      message: `Heart rate ${reading.hr} bpm is above normal (>80 bpm). Tachycardia or acute distress.`,
      current_value: reading.hr,
      threshold: 80.0,
    });
  }

  // 3. Activity Drop vs 7-Day Baseline (< 60% of average)
  if (reading.activity !== null) {
    const stats = (await db.prepare(
      `SELECT AVG(activity_level) as avg_activity
       FROM sensor_readings
       WHERE cattle_id = ? AND activity_level IS NOT NULL
         AND created_at >= datetime('now', '-7 days')`
    ).bind(cattleId).first()) as any;

    const avg = stats?.avg_activity ? Number(stats.avg_activity) : null;
    if (avg !== null && avg > 0 && reading.activity < avg * 0.6) {
      alerts.push({
        cattle_id: cattleId,
        alert_type: 'activity_drop',
        message: `Activity level dropped significantly (${reading.activity} vs 7-day avg ${Math.round(avg * 10) / 10}). Possible lameness or lethargy.`,
        current_value: reading.activity,
        threshold: Math.round(avg * 0.6 * 10) / 10,
      });
    }
  }

  // 4. Low Collar Battery Check (< 15%)
  if (reading.battery_pct !== null && reading.battery_pct !== undefined && reading.battery_pct < 15) {
    alerts.push({
      cattle_id: cattleId,
      alert_type: 'low_battery',
      message: `Collar battery low (${reading.battery_pct}%). Please recharge the IoT collar.`,
      current_value: Number(reading.battery_pct),
      threshold: 15.0,
    });
  }

  return alerts;
}

// ---------------------------------------------------------------------------
// 1. Ingest Sensor Telemetry (MQTT bridge or HTTP webhook)
// ---------------------------------------------------------------------------

iotRouter.post('/cattle/:cattle_id/sensors', async (c) => {
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  // Verify cattle exists
  const cattle = (await db.prepare('SELECT id FROM cattle WHERE id = ?').bind(cattleId).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = SensorDataCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid sensor payload format' });
  }

  const { temp, hr, activity } = validateSensorRanges({
    temperature: parsed.data.temperature,
    heart_rate: parsed.data.heart_rate,
    activity_level: parsed.data.activity_level,
  });

  const alerts = await detectAnomalies(db, cattleId, {
    temp,
    hr,
    activity,
    battery_pct: parsed.data.battery_pct,
  });

  const readingId = crypto.randomUUID();
  const stmts: D1PreparedStatement[] = [
    db.prepare(
      `INSERT INTO sensor_readings (id, cattle_id, temperature, heart_rate, activity_level, rumination_minutes, battery_pct, rssi)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      readingId,
      cattleId,
      temp,
      hr,
      activity,
      parsed.data.rumination_minutes ?? null,
      parsed.data.battery_pct ?? null,
      parsed.data.rssi ?? null
    ),
  ];

  // Store anomaly alerts
  for (const alert of alerts) {
    const alertId = crypto.randomUUID();
    stmts.push(
      db.prepare(
        `INSERT INTO sensor_anomalies (id, cattle_id, reading_id, alert_type, message, current_value, threshold)
         VALUES (?, ?, ?, ?, ?, ?, ?)`
      ).bind(
        alertId,
        cattleId,
        readingId,
        alert.alert_type,
        alert.message,
        alert.current_value,
        alert.threshold
      )
    );
  }

  await db.batch(stmts);

  return c.json(
    {
      success: true,
      data: {
        reading_id: readingId,
        cattle_id: cattleId,
        temperature: temp,
        heart_rate: hr,
        activity_level: activity,
        rumination_minutes: parsed.data.rumination_minutes ?? null,
        battery_pct: parsed.data.battery_pct ?? null,
        rssi: parsed.data.rssi ?? null,
        alerts,
      },
      message: alerts.length > 0 ? `Sensor data ingested with ${alerts.length} anomaly alert(s)` : 'Sensor data ingested',
    },
    201
  );
});

// ---------------------------------------------------------------------------
// 2. Latest Cattle Sensor Telemetry
// ---------------------------------------------------------------------------

iotRouter.get('/cattle/:cattle_id/sensors/latest', async (c) => {
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const reading = (await db.prepare(
    `SELECT * FROM sensor_readings WHERE cattle_id = ? ORDER BY created_at DESC, rowid DESC LIMIT 1`
  ).bind(cattleId).first()) as any;

  if (!reading) {
    return c.json({ success: true, data: null, message: 'No sensor telemetry available for this cattle' });
  }

  return c.json({
    success: true,
    data: {
      id: reading.id,
      cattle_id: reading.cattle_id,
      temperature: reading.temperature,
      heart_rate: reading.heart_rate,
      activity_level: reading.activity_level,
      rumination_minutes: reading.rumination_minutes,
      battery_pct: reading.battery_pct,
      rssi: reading.rssi,
      recorded_at: reading.created_at,
    },
    message: 'Latest sensor telemetry',
  });
});

// ---------------------------------------------------------------------------
// 3. Historical Telemetry for Charts
// ---------------------------------------------------------------------------

iotRouter.get('/cattle/:cattle_id/sensors/history', async (c) => {
  const cattleId = c.req.param('cattle_id');
  const hours = Math.min(Math.max(Number(c.req.query('hours') || 24), 1), 720); // 1 to 30 days
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT * FROM sensor_readings
     WHERE cattle_id = ? AND created_at >= datetime('now', '-' || ? || ' hours')
     ORDER BY created_at ASC`
  ).bind(cattleId, hours).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      temperature: r.temperature,
      heart_rate: r.heart_rate,
      activity_level: r.activity_level,
      rumination_minutes: r.rumination_minutes,
      battery_pct: r.battery_pct,
      rssi: r.rssi,
      timestamp: r.created_at,
    })),
    count: (rows.results || []).length,
    message: `Historical sensor readings for last ${hours} hour(s)`,
  });
});

// ---------------------------------------------------------------------------
// 4. Anomaly Alerts Query & Resolution
// ---------------------------------------------------------------------------

iotRouter.get('/cattle/:cattle_id/anomalies', async (c) => {
  const cattleId = c.req.param('cattle_id');
  const unresolvedOnly = c.req.query('unresolved') === 'true';
  const db = c.env.DB;

  let query = 'SELECT * FROM sensor_anomalies WHERE cattle_id = ?';
  const params: any[] = [cattleId];

  if (unresolvedOnly) {
    query += ' AND is_resolved = 0';
  }

  query += ' ORDER BY created_at DESC LIMIT 50';

  const rows = await db.prepare(query).bind(...params).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      reading_id: r.reading_id,
      alert_type: r.alert_type,
      message: r.message,
      current_value: r.current_value,
      threshold: r.threshold,
      is_resolved: Boolean(r.is_resolved),
      created_at: r.created_at,
    })),
    message: 'Cattle anomaly alerts',
  });
});

iotRouter.patch('/anomalies/:anomaly_id/resolve', async (c) => {
  const anomalyId = c.req.param('anomaly_id');
  const db = c.env.DB;

  await db.prepare('UPDATE sensor_anomalies SET is_resolved = 1 WHERE id = ?').bind(anomalyId).run();

  return c.json({ success: true, message: 'Anomaly alert marked as resolved' });
});

// ---------------------------------------------------------------------------
// 5. IoT Device Commands (Remote Collar Management)
// ---------------------------------------------------------------------------

iotRouter.post('/cattle/:cattle_id/commands', async (c) => {
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = IoTCommandCreateSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid IoT command format' });
  }

  const commandId = crypto.randomUUID();
  await db.prepare(
    `INSERT INTO iot_device_commands (id, cattle_id, command, param_int, param_str, status)
     VALUES (?, ?, ?, ?, ?, 'pending')`
  ).bind(
    commandId,
    cattleId,
    parsed.data.command,
    parsed.data.param_int ?? null,
    parsed.data.param_str || null
  ).run();

  return c.json(
    {
      success: true,
      data: {
        id: commandId,
        cattle_id: cattleId,
        command: parsed.data.command,
        param_int: parsed.data.param_int,
        param_str: parsed.data.param_str,
        status: 'pending',
      },
      message: 'Command queued for collar',
    },
    201
  );
});

iotRouter.get('/cattle/:cattle_id/commands/pending', async (c) => {
  const cattleId = c.req.param('cattle_id');
  const db = c.env.DB;

  const rows = await db.prepare(
    `SELECT * FROM iot_device_commands WHERE cattle_id = ? AND status = 'pending' ORDER BY created_at ASC`
  ).bind(cattleId).all();

  return c.json({
    success: true,
    data: (rows.results || []).map((r: any) => ({
      id: r.id,
      command: r.command,
      param_int: r.param_int,
      param_str: r.param_str,
      created_at: r.created_at,
    })),
    message: 'Pending device commands',
  });
});

iotRouter.patch('/commands/:command_id/status', async (c) => {
  const commandId = c.req.param('command_id');
  const db = c.env.DB;

  const body = await c.req.json().catch(() => ({}));
  const status = body.status === 'acknowledged' ? 'acknowledged' : 'failed';

  await db.prepare(
    `UPDATE iot_device_commands SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`
  ).bind(status, commandId).run();

  return c.json({ success: true, message: `Command status updated to ${status}` });
});
