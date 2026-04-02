import asyncio
import json
import uuid
import logging

from app.config import settings

logger = logging.getLogger("dairy_ai.iot.mqtt")


class MQTTSubscriber:
    """MQTT subscriber for cattle sensor data.

    Subscribes to dairy/cattle/+/sensors topics.
    When a message arrives:
      1. Parse cattle_id + sensor payload
      2. Get a DB session
      3. Call SensorProcessor.process() to validate, store, check anomalies
      4. Call alert_engine.process_sensor_alerts() to notify farmer if needed
    """

    def __init__(self, broker_host: str = "", broker_port: int = 1883):
        self.broker_host = broker_host or settings.MQTT_BROKER_HOST
        self.broker_port = broker_port or settings.MQTT_BROKER_PORT
        self._client = None
        self._running = False
        self._loop: asyncio.AbstractEventLoop | None = None

    async def connect(self) -> None:
        """Connect to MQTT broker."""
        if not self.broker_host:
            logger.info("MQTT: No broker host configured, skipping MQTT")
            return

        self._loop = asyncio.get_running_loop()

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
        """Handle incoming MQTT message — runs in paho's thread."""
        try:
            topic_parts = msg.topic.split("/")
            if len(topic_parts) >= 4 and topic_parts[3] == "sensors":
                cattle_id_str = topic_parts[2]
                payload = json.loads(msg.payload.decode())
                logger.info(f"MQTT: Received data for cattle {cattle_id_str}")
                if self._loop and self._loop.is_running():
                    asyncio.run_coroutine_threadsafe(
                        self._process_message(cattle_id_str, payload),
                        self._loop,
                    )
        except json.JSONDecodeError:
            logger.warning(f"MQTT: Invalid JSON payload on {msg.topic}")
        except Exception as e:
            logger.error(f"MQTT: Error processing message: {e}")

    async def _process_message(self, cattle_id_str: str, payload: dict) -> None:
        """Process sensor message: validate, store, check anomalies, notify."""
        logger.info(f"MQTT: Processing sensor data for cattle {cattle_id_str}")
        try:
            from app.database import async_session_factory
            from app.iot.sensor_processor import SensorProcessor
            from app.services import alert_engine

            cattle_id = uuid.UUID(cattle_id_str)

            async with async_session_factory() as db:
                try:
                    result = await SensorProcessor.process(db, cattle_id, payload)
                    alerts = result.get("alerts", [])

                    if alerts:
                        logger.warning(
                            f"MQTT: {len(alerts)} alert(s) for cattle {cattle_id_str}"
                        )
                        sent = await alert_engine.process_sensor_alerts(
                            db, cattle_id, alerts
                        )
                        logger.info(
                            f"MQTT: {len(sent)} notification(s) sent for cattle {cattle_id_str}"
                        )

                    await db.commit()
                    logger.info(
                        f"MQTT: Sensor data processed and committed for cattle {cattle_id_str}"
                    )
                except Exception as e:
                    await db.rollback()
                    logger.error(
                        f"MQTT: DB error processing cattle {cattle_id_str}: {e}"
                    )
        except ValueError:
            logger.error(f"MQTT: Invalid cattle UUID: {cattle_id_str}")
        except Exception as e:
            logger.error(f"MQTT: Error processing sensor data: {e}")

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

    @property
    def is_connected(self) -> bool:
        return self._running


mqtt_subscriber = MQTTSubscriber()
