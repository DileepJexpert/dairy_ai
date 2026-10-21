import { createServer, type Server } from 'node:net';
import { Aedes, type Client, type AedesPublishPacket, type Subscription } from 'aedes';

const PORT = parseInt(process.env.MQTT_BROKER_PORT || '1883', 10);
const HOST = process.env.MQTT_BROKER_HOST || '0.0.0.0';

export async function startMqttBroker(
  port = PORT,
  host = HOST
): Promise<{ aedes: Aedes; server: Server }> {
  const aedes = await Aedes.createBroker();
  const server = createServer(aedes.handle.bind(aedes));

  aedes.on('client', (client: Client) => {
    console.log(`[MQTT Broker] 🟢 Client connected: ${client ? client.id : 'unknown'}`);
  });

  aedes.on('clientDisconnect', (client: Client) => {
    console.log(`[MQTT Broker] 🔴 Client disconnected: ${client ? client.id : 'unknown'}`);
  });

  aedes.on('subscribe', (subscriptions: Subscription[], client: Client) => {
    const topicList = subscriptions.map((s: Subscription) => s.topic).join(', ');
    console.log(`[MQTT Broker] 📥 Client ${client?.id} subscribed to: ${topicList}`);
  });

  aedes.on('publish', (packet: AedesPublishPacket, client: Client | null) => {
    // Suppress internal broker keep-alive topics like $SYS
    if (packet.topic.startsWith('$SYS/')) return;
    if (client) {
      console.log(`[MQTT Broker] 📡 [${client.id}] -> ${packet.topic} (${packet.payload.length} bytes)`);
    }
  });

  await new Promise<void>((resolve) => {
    server.listen(port, host, () => {
      console.log('====================================================');
      console.log(` DairyAI Local MQTT Broker (Aedes) is RUNNING`);
      console.log(` Listening on: mqtt://${host}:${port}`);
      console.log(' Ready to receive cattle smart collar telemetry!');
      console.log('====================================================');
      resolve();
    });
  });

  return { aedes, server };
}

// When executed directly via `npm run mqtt:broker` or `tsx src/iot/mqtt_broker.ts`
if (process.argv[1]?.includes('mqtt_broker')) {
  startMqttBroker().catch((err) => {
    console.error('Failed to start MQTT broker:', err);
    process.exit(1);
  });
}
