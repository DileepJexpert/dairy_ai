import mqtt from 'mqtt';

const BROKER_URL = process.env.MQTT_BROKER_URL || 'mqtt://127.0.0.1:1883';
const CATTLE_ID = process.argv[2] || 'cattle-sim-101';
const INTERVAL_SEC = 5;

console.log('========================================================');
console.log(` 🐄 DairyAI ESP32 Collar Simulator`);
console.log(` Connecting to Broker: ${BROKER_URL}`);
console.log(` Target Cattle ID:     ${CATTLE_ID}`);
console.log('========================================================');

const client = mqtt.connect(BROKER_URL, {
  clientId: `esp32-collar-${CATTLE_ID}`,
  clean: true,
});

const sensorTopic = `dairy/cattle/${CATTLE_ID}/sensors`;
const commandTopic = `dairy/cattle/${CATTLE_ID}/commands`;

client.on('connect', () => {
  console.log(`[Simulator] 🟢 Connected to MQTT broker!`);

  // Subscribe to commands topic
  client.subscribe(commandTopic, (err) => {
    if (err) console.error('[Simulator] Failed to subscribe to commands:', err);
    else console.log(`[Simulator] 📥 Subscribed to collar commands: ${commandTopic}`);
  });

  let tick = 0;
  setInterval(() => {
    tick++;
    // Simulate elevated fever every 4th reading
    const isFever = tick % 4 === 0;
    const payload = {
      temperature: isFever ? 40.3 : parseFloat((38.4 + Math.random() * 0.4).toFixed(1)),
      heart_rate: isFever ? 92 : Math.floor(62 + Math.random() * 10),
      activity_level: Math.floor(40 + Math.random() * 30),
      rumination_minutes: 410.0,
      battery_pct: Math.max(10, 100 - tick),
      rssi: -65,
    };

    console.log(`[Simulator] 📡 Publishing ${isFever ? '⚠️ FEVER' : '✅ Normal'} reading -> ${sensorTopic}`);
    console.log(`            Temp: ${payload.temperature}°C, HR: ${payload.heart_rate} bpm, Battery: ${payload.battery_pct}%`);

    client.publish(sensorTopic, JSON.stringify(payload));
  }, INTERVAL_SEC * 1000);
});

client.on('message', (topic, message) => {
  console.log(`[Simulator] ⚡ RECEIVED COMMAND on ${topic}:`, message.toString());
});

client.on('error', (err) => {
  console.error('[Simulator] MQTT Error:', err.message);
});
