import uuid
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession

from app.services import health_service
from app.schemas.health import SensorDataCreate


class SensorProcessor:
    @staticmethod
    async def process(db: AsyncSession, cattle_id: uuid.UUID, payload: dict) -> dict:
        """Validate, store, and check anomalies for sensor data."""
        # Validate ranges
        temp = payload.get("temperature")
        if temp is not None and not (35.0 <= temp <= 42.0):
            raise ValueError(f"Temperature {temp} out of valid range (35-42°C)")

        hr = payload.get("heart_rate")
        if hr is not None and not (40 <= hr <= 120):
            raise ValueError(f"Heart rate {hr} out of valid range (40-120 bpm)")

        activity = payload.get("activity_level")
        if activity is not None and not (0 <= activity <= 100):
            raise ValueError(f"Activity level {activity} out of valid range (0-100)")

        data = SensorDataCreate(
            temperature=temp,
            heart_rate=hr,
            activity_level=activity,
            rumination_minutes=payload.get("rumination_minutes"),
            battery_pct=payload.get("battery_pct"),
            rssi=payload.get("rssi"),
        )

        reading = await health_service.ingest_sensor_data(db, cattle_id, data)
        alerts = await health_service.check_anomalies(db, cattle_id)

        # Check low battery
        if data.battery_pct is not None and data.battery_pct < 15:
            alerts.append({
                "cattle_id": str(cattle_id),
                "alert_type": "low_battery",
                "message": f"Collar battery low ({data.battery_pct}%). Please charge.",
                "current_value": float(data.battery_pct),
                "threshold": 15.0,
            })

        return {"reading_time": str(reading.time), "alerts": alerts}
