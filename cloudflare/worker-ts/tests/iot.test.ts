import path from 'node:path';
import { describe, it, expect, beforeAll } from 'vitest';
import app from '../src/index.js';
import { MockD1Database } from './helpers/mock_d1.js';
import { DairyMqttBridge } from '../src/iot/mqtt_bridge.js';
import { startMqttBroker } from '../src/iot/mqtt_broker.js';
import mqtt from 'mqtt';
import type { Env } from '../src/types/env.js';

describe('IoT Smart Collar & Sensor Telemetry Suite', () => {
  let mockDb: MockD1Database;
  let testEnv: Env;
  const farmerUserId = 'farmer-iot-user';
  let testCattleId = '';
  let highTempReadingId = '';
  let feverAnomalyId = '';
  let queuedCommandId = '';

  beforeAll(async () => {
    mockDb = new MockD1Database();
    const migrationsDir = path.resolve('./migrations');
    mockDb.loadMigrations(migrationsDir);

    // Seed customer and farmer
    await mockDb.exec(`
      INSERT OR REPLACE INTO customers (id, phone, full_name, role, is_active)
      VALUES ('${farmerUserId}', '9876500077', 'IoT Dairy Farmer', 'subscriber', 1);

      INSERT OR REPLACE INTO farmers (id, user_id, name, village, district, state)
      VALUES ('farmer-iot-1', '${farmerUserId}', 'IoT Dairy Farmer', 'Mogar', 'Anand', 'Gujarat');

      INSERT OR REPLACE INTO cattle (id, farmer_id, tag_id, name, breed, sex, weight_kg, status)
      VALUES ('cattle-iot-1', 'farmer-iot-1', 'IN-GJ-COLLAR-01', 'Kaveri', 'gir', 'female', 410.0, 'active');
    `);

    testCattleId = 'cattle-iot-1';

    testEnv = {
      DB: mockDb as any,
      ENVIRONMENT: 'test',
      STOREFRONT_BASE_URL: 'https://dairyai.local',
    };
  });

  // =========================================================================
  // 1. Telemetry Ingestion & Biological Range Validation
  // =========================================================================

  it('POST /api/v1/iot/cattle/:cattle_id/sensors ingests normal sensor reading', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/sensors`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          temperature: 38.6,
          heart_rate: 68,
          activity_level: 55,
          rumination_minutes: 420.0,
          battery_pct: 95,
          rssi: -65,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.reading_id).toBeDefined();
    expect(data.data.temperature).toBe(38.6);
    expect(data.data.heart_rate).toBe(68);
    expect(data.data.alerts.length).toBe(0); // Normal readings generate 0 alerts
  });

  it('POST /api/v1/iot/cattle/:cattle_id/sensors normalizes negative readings (sensor unavailable)', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/sensors`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          temperature: -1, // Sensor disconnected
          heart_rate: 70,
          activity_level: 60,
          battery_pct: 88,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.temperature).toBeNull(); // Converted to null
    expect(data.data.heart_rate).toBe(70);
  });

  it('POST /api/v1/iot/cattle/:cattle_id/sensors rejects biologically impossible temperature with 422', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/sensors`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          temperature: 46.5, // Lethal / sensor artifact > 42°C
          heart_rate: 70,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(422);
    const data = (await res.json()) as any;
    expect(data.message).toContain('out of valid biological range');
  });

  it('POST /api/v1/iot/cattle/:cattle_id/sensors rejects biologically impossible heart rate with 422', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/sensors`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          temperature: 38.5,
          heart_rate: 180, // Impossible > 120 bpm
        }),
      },
      testEnv
    );

    expect(res.status).toBe(422);
  });

  // =========================================================================
  // 2. Anomaly Detection Engine (Fever, Heart Rate, Low Battery)
  // =========================================================================

  it('POST /api/v1/iot/cattle/:cattle_id/sensors flags high temperature fever (> 39.5°C)', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/sensors`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          temperature: 40.2, // Fever (> 39.5°C)
          heart_rate: 72,
          activity_level: 40,
          battery_pct: 75,
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.alerts.length).toBe(1);
    expect(data.data.alerts[0].alert_type).toBe('high_temperature');
    expect(data.data.alerts[0].current_value).toBe(40.2);
    highTempReadingId = data.data.reading_id;
  });

  it('POST /api/v1/iot/cattle/:cattle_id/sensors flags tachycardia and low collar battery simultaneously', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/sensors`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          temperature: 38.8,
          heart_rate: 98, // High heart rate (> 80 bpm)
          activity_level: 50,
          battery_pct: 12, // Low battery (< 15%)
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.data.alerts.length).toBe(2);

    const alertTypes = data.data.alerts.map((a: any) => a.alert_type);
    expect(alertTypes).toContain('high_heart_rate');
    expect(alertTypes).toContain('low_battery');
  });

  // =========================================================================
  // 3. Telemetry Queries & Anomaly Alert Management
  // =========================================================================

  it('GET /api/v1/iot/cattle/:cattle_id/sensors/latest returns current collar reading', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/sensors/latest`,
      {},
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.cattle_id).toBe(testCattleId);
    expect(data.data.heart_rate).toBe(98);
    expect(data.data.battery_pct).toBe(12);
  });

  it('GET /api/v1/iot/cattle/:cattle_id/sensors/history returns time-series sensor points', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/sensors/history?hours=24`,
      {},
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBeGreaterThanOrEqual(3);
  });

  it('GET /api/v1/iot/cattle/:cattle_id/anomalies lists active and historical alerts', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/anomalies?unresolved=true`,
      {},
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBeGreaterThanOrEqual(3);
    feverAnomalyId = data.data[0].id;
  });

  it('PATCH /api/v1/iot/anomalies/:id/resolve marks anomaly as addressed', async () => {
    const res = await app.request(
      `/api/v1/iot/anomalies/${feverAnomalyId}/resolve`,
      { method: 'PATCH' },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
  });

  // =========================================================================
  // 4. Remote IoT Collar Device Commands
  // =========================================================================

  it('POST /api/v1/iot/cattle/:cattle_id/commands queues a remote collar command', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/commands`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          command: 'SET_INTERVAL',
          param_int: 30, // Send telemetry every 30 seconds
        }),
      },
      testEnv
    );

    expect(res.status).toBe(201);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.command).toBe('SET_INTERVAL');
    expect(data.data.status).toBe('pending');
    queuedCommandId = data.data.id;
  });

  it('GET /api/v1/iot/cattle/:cattle_id/commands/pending allows collar to poll pending commands', async () => {
    const res = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/commands/pending`,
      {},
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);
    expect(data.data.length).toBe(1);
    expect(data.data[0].id).toBe(queuedCommandId);
    expect(data.data[0].command).toBe('SET_INTERVAL');
    expect(data.data[0].param_int).toBe(30);
  });

  it('PATCH /api/v1/iot/commands/:id/status updates command status to acknowledged', async () => {
    const res = await app.request(
      `/api/v1/iot/commands/${queuedCommandId}/status`,
      {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'acknowledged' }),
      },
      testEnv
    );

    expect(res.status).toBe(200);
    const data = (await res.json()) as any;
    expect(data.success).toBe(true);

    // Verify pending list is now empty
    const checkRes = await app.request(
      `/api/v1/iot/cattle/${testCattleId}/commands/pending`,
      {},
      testEnv
    );
    const checkData = (await checkRes.json()) as any;
    expect(checkData.data.length).toBe(0);
  });

  // =========================================================================
  // 5. Node.js DairyMqttBridge Class Unit Tests
  // =========================================================================

  it('DairyMqttBridge parses MQTT topic and ingests payload correctly', async () => {
    const bridge = new DairyMqttBridge({
      brokerUrl: 'mqtt://mock-broker.local',
      apiBaseUrl: 'http://127.0.0.1:8787',
    });

    expect(bridge).toBeDefined();

    // Mock payload from ESP32 collar
    const samplePayload = Buffer.from(
      JSON.stringify({
        temperature: 38.7,
        heart_rate: 65,
        activity_level: 60,
        battery_pct: 90,
      })
    );

    // Verify handleMessage processes the message without throwing
    await expect(
      bridge.handleMessage('dairy/cattle/cattle-iot-1/sensors', samplePayload)
    ).resolves.not.toThrow();
  });

  it('Aedes MQTT broker starts, receives collar telemetry, and closes cleanly', async () => {
    const testPort = 18835;
    const { aedes, server } = await startMqttBroker(testPort, '127.0.0.1');

    const client = mqtt.connect(`mqtt://127.0.0.1:${testPort}`);
    let receivedPayload: any = null;

    await new Promise<void>((resolve, reject) => {
      client.on('connect', () => {
        client.subscribe('dairy/cattle/cattle-test-collar/sensors', (err) => {
          if (err) return reject(err);
          client.publish(
            'dairy/cattle/cattle-test-collar/sensors',
            JSON.stringify({ temperature: 38.8, heart_rate: 70 })
          );
        });
      });

      client.on('message', (_topic, message) => {
        receivedPayload = JSON.parse(message.toString());
        resolve();
      });

      setTimeout(() => reject(new Error('MQTT test timed out')), 4000);
    });

    expect(receivedPayload).toEqual({ temperature: 38.8, heart_rate: 70 });

    client.end(true);
    await new Promise<void>((resolve) => aedes.close(() => server.close(() => resolve())));
  });
});
