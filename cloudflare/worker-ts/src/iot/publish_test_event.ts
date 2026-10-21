import mqtt from 'mqtt';
import { Kafka } from 'kafkajs';

function parseArgs() {
  const args = process.argv.slice(2);
  let device = 'ESP32-COLLAR-001';
  let topic = '';
  let temp: number | null = null;
  let hr: number | null = null;
  let act: number | null = null;
  let rum: number | null = null;
  let batt: number | null = null;
  let scenario = 'normal';
  let useKafka = false;
  let kafkaBrokers = ['127.0.0.1:9092'];
  let kafkaTopic = 'cattle-health-events';

  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--device' && args[i + 1]) device = args[++i];
    if (a === '--topic' && args[i + 1]) topic = args[++i];
    if (a === '--temp' && args[i + 1]) temp = parseFloat(args[++i]);
    if (a === '--hr' && args[i + 1]) hr = parseInt(args[++i], 10);
    if (a === '--act' && args[i + 1]) act = parseInt(args[++i], 10);
    if (a === '--rum' && args[i + 1]) rum = parseFloat(args[++i]);
    if (a === '--battery' && args[i + 1]) batt = parseInt(args[++i], 10);
    if (a === '--fever') scenario = 'fever';
    if (a === '--estrus' || a === '--heat') scenario = 'estrus';
    if (a === '--low-battery' || a === '--batt') scenario = 'low_battery';
    if (a === '--normal') scenario = 'normal';
    if (a === '--kafka') useKafka = true;
    if (a === '--kafka-broker' && args[i + 1]) kafkaBrokers = [args[++i]];
    if (a === '--kafka-topic' && args[i + 1]) kafkaTopic = args[++i];
  }

  return { device, topic, temp, hr, act, rum, batt, scenario, useKafka, kafkaBrokers, kafkaTopic };
}

const opts = parseArgs();

// Default scenario values
let finalTemp = opts.temp ?? 38.6;
let finalHr = opts.hr ?? 66;
let finalAct = opts.act ?? 78;
let finalRum = opts.rum ?? 480.0;
let finalBatt = opts.batt ?? 94;
let status = 'NORMAL';

if (opts.scenario === 'fever') {
  finalTemp = opts.temp ?? 40.6;
  finalHr = opts.hr ?? 94;
  finalAct = opts.act ?? 38;
  finalRum = opts.rum ?? 230.0;
  status = 'FEVER_ALERT';
} else if (opts.scenario === 'estrus') {
  finalTemp = opts.temp ?? 39.2;
  finalHr = opts.hr ?? 76;
  finalAct = opts.act ?? 172; // Hyperactive estrus standing heat
  finalRum = opts.rum ?? 410.0;
  status = 'ESTRUS_DETECTED';
} else if (opts.scenario === 'low_battery') {
  finalBatt = opts.batt ?? 8;
  status = 'LOW_BATTERY';
}

const targetTopic = opts.topic || `devices/${opts.device}/health`;

const payload = {
  deviceId: opts.device,
  timestamp: new Date().toISOString(),
  temperature: finalTemp,
  heartRate: finalHr,
  activityLevel: finalAct,
  ruminationMinutes: finalRum,
  batteryPct: finalBatt,
  rssi: -64,
  status,
  scenario: opts.scenario,
};

async function publishViaMqtt() {
  const brokerUrl = process.env.MQTT_BROKER_URL || 'mqtt://127.0.0.1:1883';
  console.log(`[Publisher] 🌐 Connecting to MQTT broker at ${brokerUrl}...`);

  const client = mqtt.connect(brokerUrl, {
    clientId: `test-publisher-${Math.random().toString(16).slice(2, 6)}`,
    clean: true,
  });

  client.on('connect', () => {
    console.log(`[Publisher] 🟢 Connected!`);
    console.log(`[Publisher] 📡 Publishing to topic: ${targetTopic}`);
    console.log(`[Publisher] 📦 Payload:`, JSON.stringify(payload, null, 2));

    client.publish(targetTopic, JSON.stringify(payload), { qos: 1 }, (err) => {
      if (err) {
        console.error(`[Publisher] ❌ Publish failed:`, err.message);
      } else {
        console.log(`[Publisher] ✅ Successfully published health event!`);
      }
      client.end(false, {}, () => process.exit(err ? 1 : 0));
    });
  });

  client.on('error', (err) => {
    console.error('[Publisher] ❌ MQTT Connection error:', err.message);
    process.exit(1);
  });
}

async function publishViaKafka() {
  console.log(`[Publisher] 🐘 Connecting to Kafka broker at ${opts.kafkaBrokers.join(', ')}...`);
  try {
    const kafka = new Kafka({
      clientId: 'dairy-ai-test-publisher',
      brokers: opts.kafkaBrokers,
    });
    const producer = kafka.producer();
    await producer.connect();
    console.log(`[Publisher] 🟢 Connected to Kafka!`);
    console.log(`[Publisher] 📡 Publishing to topic: ${opts.kafkaTopic}`);
    console.log(`[Publisher] 📦 Payload:`, JSON.stringify(payload, null, 2));

    await producer.send({
      topic: opts.kafkaTopic,
      messages: [{ key: opts.device, value: JSON.stringify(payload) }],
    });

    console.log(`[Publisher] ✅ Successfully published to Kafka!`);
    await producer.disconnect();
    process.exit(0);
  } catch (err: any) {
    console.error(`[Publisher] ❌ Kafka publish failed:`, err.message);
    process.exit(1);
  }
}

if (opts.useKafka) {
  publishViaKafka();
} else {
  publishViaMqtt();
}
