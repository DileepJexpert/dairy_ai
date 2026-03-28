import logging
import uuid
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession

from app.services import health_service
from app.schemas.health import SensorDataCreate

logger = logging.getLogger("dairy_ai.iot.processor")


class SensorProcessor:
    @staticmethod
    async def process(db: AsyncSession, cattle_id: uuid.UUID, payload: dict) -> dict:
        """Validate, store, and check anomalies for sensor data."""
        logger.info("Processing sensor data for cattle_id=%s: payload_keys=%s", cattle_id, list(payload.keys()))

        # Validate ranges
        temp = payload.get("temperature")
        if temp is not None:
            logger.debug("Validating temperature: %s (valid range 35.0-42.0°C)", temp)
            if not (35.0 <= temp <= 42.0):
                logger.error("Temperature validation failed: %s out of range (35-42°C) for cattle %s", temp, cattle_id)
                raise ValueError(f"Temperature {temp} out of valid range (35-42°C)")
            logger.debug("Temperature %s°C is within valid range", temp)

        hr = payload.get("heart_rate")
        if hr is not None:
            logger.debug("Validating heart_rate: %s (valid range 40-120 bpm)", hr)
            if not (40 <= hr <= 120):
                logger.error("Heart rate validation failed: %s out of range (40-120 bpm) for cattle %s", hr, cattle_id)
                raise ValueError(f"Heart rate {hr} out of valid range (40-120 bpm)")
            logger.debug("Heart rate %s bpm is within valid range", hr)

        activity = payload.get("activity_level")
        if activity is not None:
            logger.debug("Validating activity_level: %s (valid range 0-100)", activity)
            if not (0 <= activity <= 100):
                logger.error("Activity level validation failed: %s out of range (0-100) for cattle %s", activity, cattle_id)
                raise ValueError(f"Activity level {activity} out of valid range (0-100)")
            logger.debug("Activity level %s is within valid range", activity)

        data = SensorDataCreate(
            temperature=temp,
            heart_rate=hr,
            activity_level=activity,
            rumination_minutes=payload.get("rumination_minutes"),
            battery_pct=payload.get("battery_pct"),
            rssi=payload.get("rssi"),
        )
        logger.debug("SensorDataCreate built: temp=%s, hr=%s, activity=%s, rumination=%s, battery=%s, rssi=%s",
                      data.temperature, data.heart_rate, data.activity_level,
                      data.rumination_minutes, data.battery_pct, data.rssi)

        logger.debug("Ingesting sensor data for cattle %s", cattle_id)
        reading = await health_service.ingest_sensor_data(db, cattle_id, data)
        logger.info("Sensor data ingested for cattle %s at time=%s", cattle_id, reading.time)

        logger.debug("Checking anomalies for cattle %s", cattle_id)
        alerts = await health_service.check_anomalies(db, cattle_id)
        if alerts:
            logger.warning("Anomaly alerts detected for cattle %s: %d alert(s)", cattle_id, len(alerts))
            for alert in alerts:
                logger.warning("Alert for cattle %s: type=%s, message=%s",
                               cattle_id, alert.get("alert_type"), alert.get("message"))
        else:
            logger.debug("No anomaly alerts for cattle %s", cattle_id)

        # Check low battery
        if data.battery_pct is not None and data.battery_pct < 15:
            logger.warning("Low battery alert for cattle %s: battery_pct=%s%% (threshold=15%%)",
                           cattle_id, data.battery_pct)
            alerts.append({
                "cattle_id": str(cattle_id),
                "alert_type": "low_battery",
                "message": f"Collar battery low ({data.battery_pct}%). Please charge.",
                "current_value": float(data.battery_pct),
                "threshold": 15.0,
            })

        logger.info("Sensor processing complete for cattle %s: reading_time=%s, total_alerts=%d",
                     cattle_id, reading.time, len(alerts))
        return {"reading_time": str(reading.time), "alerts": alerts}
