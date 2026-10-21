import mqtt, { type MqttClient } from 'mqtt';
import { Kafka, type Consumer as KafkaConsumer } from 'kafkajs';

export interface ConsumerOptions {
  mqttBrokerUrl?: string;
  apiBaseUrl?: string;
  kafkaBrokers?: string[];
  kafkaTopic?: string;
  enableKafka?: boolean;
}

export interface IngestedHealthEvent {
  source: 'mqtt' | 'kafka';
  topic: string;
  deviceId: string;
  temperature: number;
  heartRate: number;
  activityLevel: number;
  ruminationMinutes: number;
  batteryPct: number;
  rssi?: number;
  timestamp: string;
  statusLabel?: string;
  alerts: string[];
}

export class DeviceHealthConsumer {
  private mqttClient: MqttClient | null = null;
  private kafkaConsumer: KafkaConsumer | null = null;
  private mqttBrokerUrl: string;
  private apiBaseUrl: string;
  private kafkaBrokers: string[];
  private kafkaTopic: string;
  private enableKafka: boolean;
  private isRunning: boolean = false;

  constructor(options: ConsumerOptions = {}) {
    this.mqttBrokerUrl =
      options.mqttBrokerUrl ||
      process.env.MQTT_BROKER_URL ||
      'mqtt://127.0.0.1:1883';
    this.apiBaseUrl =
      options.apiBaseUrl ||
      process.env.API_BASE_URL ||
      'http://127.0.0.1:8787';
    this.kafkaBrokers =
      options.kafkaBrokers ||
      (process.env.KAFKA_BROKERS ? process.env.KAFKA_BROKERS.split(',') : ['127.0.0.1:9092']);
    this.kafkaTopic = options.kafkaTopic || process.env.KAFKA_TOPIC || 'cattle-health-events';
    this.enableKafka = options.enableKafka ?? Boolean(process.env.ENABLE_KAFKA === 'true');
  }

  public async start(): Promise<void> {
    console.log('===============================================================');
    console.log(' 📡 DairyAI Smart Collar & Device Health Consumer');
    console.log(` 🌐 MQTT Broker:    ${this.mqttBrokerUrl}`);
    console.log(` 🔗 Backend API:    ${this.apiBaseUrl}`);
    console.log(` 🐘 Kafka Mode:     ${this.enableKafka ? `Enabled (${this.kafkaBrokers.join(', ')})` : 'Disabled (MQTT Primary)'}`);
    console.log('===============================================================');

    // 1. Connect to MQTT Broker
    await this.startMqtt();

    // 2. Connect to Kafka (if requested)
    if (this.enableKafka) {
      await this.startKafka();
    }
  }

  private startMqtt(): Promise<void> {
    return new Promise((resolve) => {
      const clientId = `dairy-health-consumer-${Math.random().toString(16).slice(2, 8)}`;
      console.log(`[MQTT Consumer] Connecting to ${this.mqttBrokerUrl} as ${clientId}...`);

      this.mqttClient = mqtt.connect(this.mqttBrokerUrl, {
        clientId,
        clean: true,
        connectTimeout: 5000,
        reconnectPeriod: 3000,
      });

      this.mqttClient.on('connect', () => {
        this.isRunning = true;
        console.log(`[MQTT Consumer] ✅ Connected to MQTT Broker!`);

        // Subscribes to device telemetry across all standard topic conventions
        const topics = [
          'devices/+/health',
          'devices/+/telemetry',
          'dairy/cattle/+/sensors',
          'dairy/devices/+/events',
          'cattle/+/health',
          'cattle/+/sensors',
          '+/health',
          '+/sensors',
        ];

        this.mqttClient?.subscribe(topics, (err) => {
          if (err) {
            console.error('[MQTT Consumer] ❌ Subscription error:', err);
          } else {
            console.log(`[MQTT Consumer] 📥 Subscribed to device topics:`);
            topics.forEach((t) => console.log(`   └─ ${t}`));
            console.log('[MQTT Consumer] 🚀 Listening for hardware device telemetry...');
          }
          resolve();
        });
      });

      this.mqttClient.on('message', async (topic: string, message: Buffer) => {
        try {
          await this.processIncomingEvent('mqtt', topic, message.toString());
        } catch (err: any) {
          console.error(`[MQTT Consumer] Error processing message on ${topic}:`, err.message);
        }
      });

      this.mqttClient.on('error', (err) => {
        console.warn(`[MQTT Consumer] ⚠️ MQTT connection warning:`, err.message);
      });

      this.mqttClient.on('offline', () => {
        console.warn('[MQTT Consumer] ⚠️ Broker offline. Waiting for reconnection...');
      });

      // Avoid hanging if broker is still starting
      setTimeout(() => resolve(), 3000);
    });
  }

  private async startKafka(): Promise<void> {
    try {
      console.log(`[Kafka Consumer] Initializing Kafka connection to ${this.kafkaBrokers.join(', ')}...`);
      const kafka = new Kafka({
        clientId: 'dairy-ai-consumer',
        brokers: this.kafkaBrokers,
        connectionTimeout: 4000,
      });

      this.kafkaConsumer = kafka.consumer({ groupId: 'dairy-health-group' });
      await this.kafkaConsumer.connect();
      await this.kafkaConsumer.subscribe({ topic: this.kafkaTopic, fromBeginning: false });

      console.log(`[Kafka Consumer] ✅ Subscribed to Kafka topic: ${this.kafkaTopic}`);

      this.kafkaConsumer.run({
        eachMessage: async ({ topic, message }) => {
          if (!message.value) return;
          await this.processIncomingEvent('kafka', topic, message.value.toString());
        },
      });
    } catch (err: any) {
      console.warn(`[Kafka Consumer] ⚠️ Kafka not reachable (${err.message}). Continuing in MQTT mode.`);
    }
  }

  public extractDeviceId(topic: string, payload: any): string {
    // 1. Explicit in payload
    if (payload.deviceId || payload.device_id || payload.deviceName || payload.device_name || payload.collarId || payload.collar_id) {
      return String(payload.deviceId || payload.device_id || payload.deviceName || payload.device_name || payload.collarId || payload.collar_id);
    }

    // 2. Extract from topic structure
    // e.g. "devices/ESP32-COLLAR-001/health" -> "ESP32-COLLAR-001"
    // e.g. "dairy/cattle/COW-GJ-01/sensors" -> "COW-GJ-01"
    const parts = topic.split('/');
    if (parts.length >= 2) {
      if (parts[0] === 'devices' || parts[0] === 'cattle') {
        return parts[1];
      }
      if (parts[0] === 'dairy' && (parts[1] === 'cattle' || parts[1] === 'devices') && parts.length >= 3) {
        return parts[2];
      }
      // Single wildcard like "ESP32-COLLAR-001/health"
      if (parts[1] === 'health' || parts[1] === 'sensors') {
        return parts[0];
      }
    }

    return 'ESP32-COLLAR-001'; // Default test device fallback
  }

  public async processIncomingEvent(source: 'mqtt' | 'kafka', topic: string, rawText: string): Promise<IngestedHealthEvent | null> {
    let payload: any;
    try {
      payload = JSON.parse(rawText);
    } catch {
      console.warn(`[Consumer] ⚠️ Received non-JSON payload on ${topic}:`, rawText);
      return null;
    }

    const deviceId = this.extractDeviceId(topic, payload);

    // Normalize field variations from different firmware SDKs
    const temp = Number(
      payload.temperature ?? payload.temp ?? payload.temp_c ?? payload.body_temp ?? payload.rumen_temp ?? 38.5
    );
    const hr = Math.round(
      Number(payload.heart_rate ?? payload.heartRate ?? payload.bpm ?? payload.pulse ?? payload.hr ?? 68)
    );
    const act = Math.round(
      Number(payload.activity_level ?? payload.activityLevel ?? payload.activity ?? payload.steps ?? 75)
    );
    const rum = Number(
      payload.rumination_minutes ?? payload.ruminationMinutes ?? payload.rumination ?? payload.chew_time ?? 460
    );
    const batt = Math.round(
      Number(payload.battery_pct ?? payload.batteryPct ?? payload.battery ?? payload.batt ?? 95)
    );
    const rssi = payload.rssi != null ? Math.round(Number(payload.rssi)) : -62;

    // Detect Biological Anomalies
    const alerts: string[] = [];
    let statusLabel = 'NORMAL HEALTH (स्वस्थ)';

    if (temp > 40.2) {
      alerts.push(`🚨 CRITICAL FEVER (${temp}°C > 40.2°C) - Suspected Mastitis / Acute Infection`);
      statusLabel = 'CRITICAL FEVER 🌡️';
    } else if (temp > 39.5) {
      alerts.push(`⚠️ ELEVATED FEVER (${temp}°C > 39.5°C)`);
      statusLabel = 'FEVER WARNING ⚠️';
    } else if (temp < 37.5) {
      alerts.push(`⚠️ HYPOTHERMIA (${temp}°C < 37.5°C) - Possible Milk Fever`);
      statusLabel = 'HYPOTHERMIA ❄️';
    }

    if (hr > 80) {
      alerts.push(`⚠️ TACHYCARDIA (${hr} bpm > 80 bpm) - Pain / Acute Distress`);
    } else if (hr < 45) {
      alerts.push(`⚠️ BRADYCARDIA (${hr} bpm < 45 bpm)`);
    }

    if (act > 140) {
      alerts.push(`🐂 ESTRUS / HEAT SPIKE (${act} activity) - Optimal AI Breeding Window!`);
      statusLabel = 'HEAT / ESTRUS DETECTED 🐂';
    } else if (act < 35) {
      alerts.push(`⚠️ LETHARGY / LAMENESS (${act} activity) - Check Foot & Rumen`);
      statusLabel = 'LETHARGY / LAME 📉';
    }

    if (batt < 15) {
      alerts.push(`🔋 LOW COLLAR BATTERY (${batt}%) - Please recharge`);
    }

    // Format rich terminal event card
    const timestamp = new Date().toLocaleTimeString('en-US', { hour12: false });
    console.log('\n┌────────────────────────────────────────────────────────────────────────┐');
    console.log(`│ 📡 [${source.toUpperCase()} EVENT @ ${timestamp}] Topic: ${topic.padEnd(41)}│`);
    console.log(`│ 🏷️  Device Name / ID: ${deviceId.padEnd(48)}│`);
    console.log(`│ 📊 Vitals: Temp ${temp.toFixed(1)}°C | HR ${hr} bpm | Act ${act} | Rum ${rum}m | Bat ${batt}% │`);
    console.log(`│ 🩺 Status: ${statusLabel.padEnd(58)}│`);
    if (alerts.length > 0) {
      console.log('│ ⚠️  ANOMALIES DETECTED:                                                │');
      alerts.forEach((a) => {
        console.log(`│    └─ ${a.slice(0, 62).padEnd(62)}│`);
      });
    }
    console.log('└────────────────────────────────────────────────────────────────────────┘');

    // Forward to DairyAI Backend Ingestion API
    await this.forwardToApi(deviceId, {
      temperature: temp,
      heart_rate: hr,
      activity_level: act,
      rumination_minutes: rum,
      battery_pct: batt,
      rssi,
    });

    return {
      source,
      topic,
      deviceId,
      temperature: temp,
      heartRate: hr,
      activityLevel: act,
      ruminationMinutes: rum,
      batteryPct: batt,
      rssi,
      timestamp: new Date().toISOString(),
      statusLabel,
      alerts,
    };
  }

  private async forwardToApi(deviceId: string, data: any): Promise<void> {
    try {
      const url = `${this.apiBaseUrl}/api/v1/iot/cattle/${encodeURIComponent(deviceId)}/sensors`;
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });

      if (res.ok) {
        const body = (await res.json().catch(() => ({}))) as any;
        const cattleName = body?.data?.cattle_name || deviceId;
        const tag = body?.data?.tag_id ? ` (${body.data.tag_id})` : '';
        console.log(`   ✅ Ingested to Database -> Cattle: ${cattleName}${tag} (HTTP ${res.status})`);
      } else {
        const errText = await res.text();
        console.log(`   ℹ️ Ingestion response (HTTP ${res.status}): ${errText.slice(0, 90)}`);
      }
    } catch (err: any) {
      // In standalone or disconnected mode, consumer still handles and verifies events locally
      console.log(`   ℹ️ Standalone Mode (Backend HTTP forward skipped: ${err.message})`);
    }
  }

  public async stop(): Promise<void> {
    if (this.mqttClient) {
      await new Promise<void>((resolve) => {
        this.mqttClient?.end(false, {}, () => resolve());
      });
      console.log('[MQTT Consumer] Disconnected.');
    }
    if (this.kafkaConsumer) {
      await this.kafkaConsumer.disconnect();
      console.log('[Kafka Consumer] Disconnected.');
    }
    this.isRunning = false;
  }
}

// Standalone execution entrypoint: `tsx src/iot/device_consumer.ts`
if (import.meta.url === `file:///${process.argv[1]?.replace(/\\/g, '/')}`) {
  const consumer = new DeviceHealthConsumer({
    enableKafka: process.argv.includes('--kafka'),
  });

  consumer.start();

  process.on('SIGINT', async () => {
    console.log('\n[Device Consumer] Shutting down...');
    await consumer.stop();
    process.exit(0);
  });
}
