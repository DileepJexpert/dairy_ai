import asyncio
import json
import uuid
import logging

logger = logging.getLogger(__name__)


class MQTTSubscriber:
    """MQTT subscriber for cattle sensor data.

    Subscribes to dairy/cattle/+/sensors topics.
    For production, uses paho-mqtt. This implementation provides
    the structure with graceful degradation if MQTT broker is unavailable.
    """

    def __init__(self, broker_host: str = "localhost", broker_port: int = 1883):
        self.broker_host = broker_host
        self.broker_port = broker_port
        self._client = None
        self._running = False

    async def connect(self) -> None:
        """Connect to MQTT broker."""
        try:
            import paho.mqtt.client as mqtt

            self._client = mqtt.Client(client_id=f"dairy-ai-{uuid.uuid4().hex[:8]}")
            self._client.on_connect = self._on_connect
            self._client.on_message = self._on_message
            self._client.on_disconnect = self._on_disconnect

            self._client.connect_async(self.broker_host, self.broker_port, 60)
            self._client.loop_start()
            self._running = True
            logger.info(f"MQTT: Connecting to {self.broker_host}:{self.broker_port}")
        except ImportError:
            logger.warning("MQTT: paho-mqtt not installed. MQTT subscriber disabled.")
        except Exception as e:
            logger.warning(f"MQTT: Could not connect to broker: {e}")

    def _on_connect(self, client, userdata, flags, rc) -> None:
        if rc == 0:
            logger.info("MQTT: Connected successfully")
            client.subscribe("dairy/cattle/+/sensors")
            logger.info("MQTT: Subscribed to dairy/cattle/+/sensors")
        else:
            logger.warning(f"MQTT: Connection failed with code {rc}")

    def _on_message(self, client, userdata, msg) -> None:
        """Handle incoming MQTT message."""
        try:
            topic_parts = msg.topic.split("/")
            if len(topic_parts) >= 3:
                cattle_id_str = topic_parts[2]
                payload = json.loads(msg.payload.decode())
                logger.info(f"MQTT: Received data for cattle {cattle_id_str}")
                # In production, this would call sensor_processor via async bridge
                # For now, log the data
                asyncio.get_event_loop().create_task(
                    self._process_message(cattle_id_str, payload)
                )
        except json.JSONDecodeError:
            logger.warning(f"MQTT: Invalid JSON payload on {msg.topic}")
        except Exception as e:
            logger.error(f"MQTT: Error processing message: {e}")

    async def _process_message(self, cattle_id_str: str, payload: dict) -> None:
        """Process sensor message asynchronously."""
        logger.info(f"MQTT: Processing sensor data for cattle {cattle_id_str}: {payload}")
        # In production, get a DB session and call SensorProcessor.process()

    def _on_disconnect(self, client, userdata, rc) -> None:
        if rc != 0:
            logger.warning(f"MQTT: Unexpected disconnect (rc={rc}). Will auto-reconnect.")

    async def disconnect(self) -> None:
        """Gracefully disconnect from broker."""
        if self._client:
            self._client.loop_stop()
            self._client.disconnect()
            self._running = False
            logger.info("MQTT: Disconnected")


# Singleton instance
mqtt_subscriber = MQTTSubscriber()
