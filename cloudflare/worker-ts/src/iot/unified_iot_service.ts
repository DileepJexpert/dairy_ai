import { startMqttBroker } from './mqtt_broker.js';
import { DeviceHealthConsumer } from './device_consumer.js';

const PORT = parseInt(process.env.MQTT_BROKER_PORT || '1883', 10);
const API_BASE_URL = process.env.API_BASE_URL || 'http://127.0.0.1:8787';
const ENABLE_KAFKA = process.argv.includes('--kafka') || process.env.ENABLE_KAFKA === 'true';

async function main() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║       🐄 DairyAI Unified IoT Telemetry & Health System       ║');
  console.log('║   Embedded MQTT Broker + Multi-Device Health Consumer        ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');

  // 1. Start the embedded local MQTT Broker (Aedes)
  const { server } = await startMqttBroker(PORT);

  // 2. Start the Device Health Consumer
  const consumer = new DeviceHealthConsumer({
    mqttBrokerUrl: `mqtt://127.0.0.1:${PORT}`,
    apiBaseUrl: API_BASE_URL,
    enableKafka: ENABLE_KAFKA,
  });

  await consumer.start();

  console.log('\n🟢 [SYSTEM READY]');
  console.log(`   └─ MQTT Broker listening on :${PORT}`);
  console.log(`   └─ Health Consumer listening on devices/+/health & dairy/cattle/+/sensors`);
  console.log('   └─ Ready to receive events from physical hardware or simulator!\n');

  // Graceful shutdown
  const shutdown = async () => {
    console.log('\n[System] Graceful shutdown in progress...');
    await consumer.stop();
    server.close(() => {
      console.log('[System] Broker stopped. Goodbye!');
      process.exit(0);
    });
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error('Fatal error starting IoT system:', err);
  process.exit(1);
});
