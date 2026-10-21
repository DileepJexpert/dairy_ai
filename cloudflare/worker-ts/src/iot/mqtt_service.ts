import { startMqttBroker } from './mqtt_broker.js';
import { DairyMqttBridge } from './mqtt_bridge.js';

const PORT = parseInt(process.env.MQTT_BROKER_PORT || '1883', 10);
const API_BASE_URL = process.env.API_BASE_URL || 'http://127.0.0.1:8787';

async function main() {
  console.log('🚀 Starting DairyAI Unified MQTT System (Broker + Bridge)...');

  // 1. Start the embedded MQTT Broker
  await startMqttBroker(PORT);

  // 2. Start the Bridge connecting to local broker
  const bridge = new DairyMqttBridge({
    brokerUrl: `mqtt://127.0.0.1:${PORT}`,
    apiBaseUrl: API_BASE_URL,
    clientId: 'dairy-ai-internal-bridge',
  });

  await bridge.start();

  console.log(`✨ All systems ready: Broker (port ${PORT}) + Bridge -> API (${API_BASE_URL})`);
}

main().catch((err) => {
  console.error('Fatal error starting MQTT service:', err);
  process.exit(1);
});
