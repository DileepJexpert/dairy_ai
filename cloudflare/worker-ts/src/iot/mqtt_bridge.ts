import mqtt, { type MqttClient } from 'mqtt';

export interface MqttBridgeOptions {
  brokerUrl?: string;
  apiBaseUrl?: string;
  topicPrefix?: string;
  clientId?: string;
}

export class DairyMqttBridge {
  private client: MqttClient | null = null;
  private brokerUrl: string;
  private apiBaseUrl: string;
  private topicPrefix: string;
  private clientId: string;
  private isRunning: boolean = false;

  constructor(options: MqttBridgeOptions = {}) {
    this.brokerUrl = options.brokerUrl || process.env.MQTT_BROKER_URL || 'mqtt://127.0.0.1:1883';
    this.apiBaseUrl = options.apiBaseUrl || process.env.API_BASE_URL || 'http://127.0.0.1:8787';
    this.topicPrefix = options.topicPrefix || 'dairy/cattle';
    this.clientId = options.clientId || `dairy-ai-bridge-${Math.random().toString(16).slice(2, 10)}`;
  }

  public start(): Promise<void> {
    return new Promise((resolve, reject) => {
      console.log(`[MQTT Bridge] Connecting to broker at ${this.brokerUrl}...`);

      this.client = mqtt.connect(this.brokerUrl, {
        clientId: this.clientId,
        clean: true,
        connectTimeout: 5000,
        reconnectPeriod: 3000,
      });

      this.client.on('connect', () => {
        this.isRunning = true;
        console.log(`[MQTT Bridge] Connected successfully as ${this.clientId}`);

        const sensorTopic = `${this.topicPrefix}/+/sensors`;
        this.client?.subscribe(sensorTopic, (err) => {
          if (err) {
            console.error(`[MQTT Bridge] Failed to subscribe to ${sensorTopic}:`, err);
          } else {
            console.log(`[MQTT Bridge] Subscribed to ${sensorTopic}`);
            resolve();
          }
        });
      });

      this.client.on('message', async (topic: string, message: Buffer) => {
        try {
          await this.handleMessage(topic, message);
        } catch (err) {
          console.error(`[MQTT Bridge] Error processing message on topic ${topic}:`, err);
        }
      });

      this.client.on('error', (err) => {
        console.error('[MQTT Bridge] MQTT Error:', err.message);
      });

      this.client.on('offline', () => {
        console.warn('[MQTT Bridge] Broker offline, awaiting reconnection...');
      });

      // Avoid hanging if initial connection times out
      setTimeout(() => {
        if (!this.isRunning) {
          resolve(); // Let caller proceed without crashing
        }
      }, 3000);
    });
  }

  public async handleMessage(topic: string, message: Buffer): Promise<void> {
    const parts = topic.split('/');
    // Format: dairy/cattle/<cattle_id>/sensors
    if (parts.length >= 4 && parts[3] === 'sensors') {
      const cattleId = parts[2];
      const payloadStr = message.toString();

      let payload: any;
      try {
        payload = JSON.parse(payloadStr);
      } catch {
        console.warn(`[MQTT Bridge] Invalid JSON payload received on ${topic}`);
        return;
      }

      console.log(`[MQTT Bridge] Ingesting sensor payload for cattle ${cattleId}`);

      try {
        const response = await fetch(`${this.apiBaseUrl}/api/v1/iot/cattle/${cattleId}/sensors`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });

        if (response.ok) {
          const resData = (await response.json()) as any;
          const alertsCount = resData.data?.alerts?.length || 0;
          if (alertsCount > 0) {
            console.warn(`[MQTT Bridge] ⚠️ ${alertsCount} anomaly alert(s) detected for cattle ${cattleId}:`, resData.data.alerts);
          } else {
            console.log(`[MQTT Bridge] ✅ Ingested sensor data for cattle ${cattleId}`);
          }
        } else {
          const errBody = await response.text();
          console.error(`[MQTT Bridge] Ingestion failed (HTTP ${response.status}):`, errBody);
        }
      } catch (err: any) {
        console.error(`[MQTT Bridge] Failed to forward to API:`, err.message);
      }
    }
  }

  public async sendCommand(cattleId: string, command: string, paramInt?: number, paramStr?: string): Promise<boolean> {
    if (!this.client || !this.isRunning) {
      console.warn('[MQTT Bridge] Cannot send command: MQTT client is not connected');
      return false;
    }

    const topic = `${this.topicPrefix}/${cattleId}/commands`;
    const payload = JSON.stringify({
      command,
      param_int: paramInt,
      param_str: paramStr,
      timestamp: new Date().toISOString(),
    });

    return new Promise((resolve) => {
      this.client?.publish(topic, payload, { qos: 1 }, (err) => {
        if (err) {
          console.error(`[MQTT Bridge] Failed to send command to ${topic}:`, err);
          resolve(false);
        } else {
          console.log(`[MQTT Bridge] Sent command ${command} to ${topic}`);
          resolve(true);
        }
      });
    });
  }

  public stop(): Promise<void> {
    return new Promise((resolve) => {
      if (this.client) {
        this.client.end(false, {}, () => {
          this.isRunning = false;
          console.log('[MQTT Bridge] Disconnected');
          resolve();
        });
      } else {
        resolve();
      }
    });
  }
}

// Standalone execution entrypoint
if (import.meta.url === `file:///${process.argv[1]?.replace(/\\/g, '/')}`) {
  const bridge = new DairyMqttBridge();
  bridge.start();

  process.on('SIGINT', async () => {
    console.log('\n[MQTT Bridge] Shutting down...');
    await bridge.stop();
    process.exit(0);
  });
}
