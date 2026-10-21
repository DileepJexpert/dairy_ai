import mqtt from 'mqtt';

interface CollarProfile {
  deviceId: string;
  cattleName: string;
  tagId: string;
  breed: string;
  batteryPct: number;
}

const COLLARS: CollarProfile[] = [
  { deviceId: 'ESP32-COLLAR-001', cattleName: 'Ganga', tagId: 'COW-GJ-01', breed: 'Gir Cow', batteryPct: 96 },
  { deviceId: 'ESP32-COLLAR-002', cattleName: 'Yamuna', tagId: 'BUF-GJ-02', breed: 'Murrah Buffalo', batteryPct: 88 },
  { deviceId: 'ESP32-COLLAR-003', cattleName: 'Lakshmi', tagId: 'COW-HR-01', breed: 'Sahiwal Cow', batteryPct: 92 },
];

function parseArgs() {
  const args = process.argv.slice(2);
  let device = 'ESP32-COLLAR-001';
  let intervalSec = 4;
  let mode: 'cycle' | 'normal' | 'fever' | 'estrus' | 'low_battery' = 'cycle';
  let count = 0; // 0 = continuous

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--device' && args[i + 1]) device = args[++i];
    if (args[i] === '--interval' && args[i + 1]) intervalSec = Math.max(1, parseInt(args[++i], 10));
    if (args[i] === '--mode' && args[i + 1]) mode = args[++i] as any;
    if (args[i] === '--count' && args[i + 1]) count = parseInt(args[++i], 10);
  }

  return { device, intervalSec, mode, count };
}

const { device, intervalSec, mode, count } = parseArgs();
const BROKER_URL = process.env.MQTT_BROKER_URL || 'mqtt://127.0.0.1:1883';

console.log('===============================================================');
console.log(' 🐄 DairyAI Hardware Device Smart Collar Simulator');
console.log(` 🌐 MQTT Broker:    ${BROKER_URL}`);
console.log(` 🏷️  Target Device:  ${device}`);
console.log(` ⚙️  Simulation Mode: ${mode.toUpperCase()} (Every ${intervalSec}s)`);
console.log('===============================================================');

const activeCollar = COLLARS.find((c) => c.deviceId === device) || {
  deviceId: device,
  cattleName: 'Test Cattle',
  tagId: device,
  breed: 'Gir Cow',
  batteryPct: 95,
};

const client = mqtt.connect(BROKER_URL, {
  clientId: `sim-device-${device}`,
  clean: true,
});

client.on('connect', () => {
  console.log(`[Simulator] 🟢 Connected to MQTT broker! Transmitting live telemetry...`);

  let tick = 0;
  let publishedCount = 0;

  const timer = setInterval(() => {
    tick++;
    publishedCount++;

    let temp = parseFloat((38.4 + Math.random() * 0.4).toFixed(1));
    let hr = Math.floor(62 + Math.random() * 10);
    let act = Math.floor(60 + Math.random() * 25);
    let rum = parseFloat((460 + Math.random() * 30).toFixed(1));
    let battery = Math.max(8, activeCollar.batteryPct - Math.floor(tick / 5));
    let status = 'NORMAL';
    let simulationNote = 'Normal resting/grazing vitals';

    if (mode === 'fever' || (mode === 'cycle' && tick % 6 === 4)) {
      temp = 40.5;
      hr = 94;
      act = 38;
      rum = 240.0;
      status = 'FEVER_ALERT';
      simulationNote = '⚠️ SIMULATED FEVER SPIKE (40.5°C)';
    } else if (mode === 'estrus' || (mode === 'cycle' && tick % 6 === 2)) {
      temp = 39.2;
      hr = 78;
      act = 168; // High hyperactivity
      rum = 420.0;
      status = 'HEAT_ESTRUS';
      simulationNote = '🐂 SIMULATED ESTRUS / HEAT ACTIVITY SPIKE';
    } else if (mode === 'low_battery' || (mode === 'cycle' && tick % 12 === 11)) {
      battery = 9;
      status = 'LOW_BATTERY';
      simulationNote = '🔋 SIMULATED LOW BATTERY (9%)';
    }

    const payload = {
      deviceId: activeCollar.deviceId,
      tagId: activeCollar.tagId,
      cattleName: activeCollar.cattleName,
      timestamp: new Date().toISOString(),
      temperature: temp,
      heartRate: hr,
      activityLevel: act,
      ruminationMinutes: rum,
      batteryPct: battery,
      rssi: -60 - Math.floor(Math.random() * 12),
      status,
      firmwareVersion: 'ESP32-DAIRY-v2.4.1',
    };

    const topic = `devices/${activeCollar.deviceId}/health`;

    client.publish(topic, JSON.stringify(payload), { qos: 1 }, (err) => {
      if (err) {
        console.error(`[Simulator] ❌ Publish failed:`, err.message);
      } else {
        console.log(
          `[Simulator #${publishedCount}] 📡 Transmitted to ${topic} -> ${simulationNote}`
        );
        console.log(
          `              Temp: ${temp}°C | HR: ${hr} bpm | Act: ${act} | Batt: ${battery}%`
        );
      }
    });

    if (count > 0 && publishedCount >= count) {
      clearInterval(timer);
      console.log(`\n[Simulator] ✅ Finished transmitting ${count} events.`);
      client.end(false, {}, () => process.exit(0));
    }
  }, intervalSec * 1000);
});

client.on('error', (err) => {
  console.error('[Simulator] ❌ MQTT Error:', err.message);
});
