"""
Alert Engine — Connects anomaly detection to farmer notifications.

Responsibilities:
  1. When sensor data detects anomalies → resolve cattle → farmer → notify
  2. Alert deduplication (don't spam same alert within cooldown window)
  3. Cold chain alerts → notify cooperative manager
  4. Vaccination due reminders → notify farmer
  5. FCM device token management (store/retrieve for push)
"""
import logging
import uuid
from datetime import datetime, timezone, timedelta

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cattle import Cattle
from app.models.farmer import Farmer
from app.models.notification import Notification, NotificationType
from app.services import notification_service

logger = logging.getLogger("dairy_ai.services.alert_engine")

# Deduplication: don't re-send the same alert_type for the same cattle
# within this cooldown window.
ALERT_COOLDOWN_MINUTES = 30


async def _get_farmer_user_id(db: AsyncSession, cattle_id: uuid.UUID) -> uuid.UUID | None:
    """Resolve cattle_id → farmer.user_id for notification targeting."""
    result = await db.execute(
        select(Farmer.user_id)
        .join(Cattle, Cattle.farmer_id == Farmer.id)
        .where(Cattle.id == cattle_id)
    )
    row = result.scalar_one_or_none()
    if row is None:
        logger.warning("Cannot resolve farmer for cattle_id=%s", cattle_id)
    return row


async def _was_recently_notified(
    db: AsyncSession,
    user_id: uuid.UUID,
    alert_type: str,
    cattle_id: uuid.UUID,
    cooldown_minutes: int = ALERT_COOLDOWN_MINUTES,
) -> bool:
    """Check if we already sent a notification for this alert recently."""
    cutoff = datetime.utcnow() - timedelta(minutes=cooldown_minutes)
    result = await db.execute(
        select(Notification.id).where(
            and_(
                Notification.user_id == user_id,
                Notification.type == NotificationType.health_alert,
                Notification.created_at >= cutoff,
                # Store alert_type+cattle_id in the JSON data field for dedup
                Notification.data["alert_type"].as_string() == alert_type,
                Notification.data["cattle_id"].as_string() == str(cattle_id),
            )
        ).limit(1)
    )
    return result.scalar_one_or_none() is not None


async def process_sensor_alerts(
    db: AsyncSession,
    cattle_id: uuid.UUID,
    alerts: list[dict],
) -> list[dict]:
    """
    Process a list of anomaly alerts from check_anomalies().
    For each alert, resolve the farmer, deduplicate, and create notification.

    Returns list of notifications actually sent (after dedup filtering).
    """
    if not alerts:
        return []

    logger.info(
        "process_sensor_alerts | cattle_id=%s, incoming_alerts=%d",
        cattle_id, len(alerts),
    )

    farmer_user_id = await _get_farmer_user_id(db, cattle_id)
    if farmer_user_id is None:
        logger.error(
            "Cannot notify — no farmer found for cattle_id=%s", cattle_id
        )
        return []

    sent = []
    for alert in alerts:
        alert_type = alert.get("alert_type", "unknown")
        message = alert.get("message", "Health anomaly detected")

        # --- Deduplication ---
        try:
            already_sent = await _was_recently_notified(
                db, farmer_user_id, alert_type, cattle_id
            )
        except Exception:
            # JSON operator may not be supported on SQLite (tests).
            # In that case, skip dedup and always notify.
            already_sent = False

        if already_sent:
            logger.info(
                "Skipping duplicate alert | cattle_id=%s, alert_type=%s "
                "(already notified within %d min)",
                cattle_id, alert_type, ALERT_COOLDOWN_MINUTES,
            )
            continue

        # --- Build notification ---
        title = _alert_title(alert_type)
        body = message
        data = {
            "cattle_id": str(cattle_id),
            "alert_type": alert_type,
            "current_value": alert.get("current_value"),
            "threshold": alert.get("threshold"),
        }

        logger.info(
            "Sending health alert notification | user_id=%s, cattle_id=%s, "
            "alert_type=%s",
            farmer_user_id, cattle_id, alert_type,
        )

        notif = await notification_service.notify_farmer(
            db, farmer_user_id,
            type=NotificationType.health_alert.value,
            title=title,
            body=body,
            data=data,
        )

        sent.append({
            "notification_id": str(notif.id),
            "alert_type": alert_type,
            "user_id": str(farmer_user_id),
        })

    logger.info(
        "process_sensor_alerts complete | cattle_id=%s, "
        "incoming=%d, sent=%d, deduplicated=%d",
        cattle_id, len(alerts), len(sent), len(alerts) - len(sent),
    )
    return sent


def _alert_title(alert_type: str) -> str:
    """Human-readable title per alert type."""
    titles = {
        "high_temperature": "Fever Alert",
        "high_heart_rate": "Heart Rate Alert",
        "activity_drop": "Low Activity Alert",
        "low_battery": "Collar Battery Low",
    }
    return titles.get(alert_type, "Health Alert")


# ---------------------------------------------------------------------------
# Vaccination reminder
# ---------------------------------------------------------------------------

async def send_vaccination_reminders(db: AsyncSession) -> int:
    """
    Check all vaccinations due in the next 3 days and notify farmers.
    Meant to be called by a daily scheduled task.
    Returns count of notifications sent.
    """
    from app.models.health import Vaccination
    from datetime import date

    logger.info("send_vaccination_reminders | checking upcoming vaccinations")

    today = date.today()
    due_cutoff = today + timedelta(days=3)

    result = await db.execute(
        select(Vaccination, Cattle.farmer_id)
        .join(Cattle, Cattle.id == Vaccination.cattle_id)
        .where(
            and_(
                Vaccination.next_due_date >= today,
                Vaccination.next_due_date <= due_cutoff,
            )
        )
    )
    rows = result.all()
    logger.info(
        "Found %d vaccinations due within 3 days", len(rows)
    )

    count = 0
    for vacc, farmer_id in rows:
        # Get user_id from farmer
        farmer_result = await db.execute(
            select(Farmer.user_id).where(Farmer.id == farmer_id)
        )
        user_id = farmer_result.scalar_one_or_none()
        if not user_id:
            continue

        days_until = (vacc.next_due_date - today).days
        title = "Vaccination Reminder"
        body = (
            f"{vacc.vaccine_name} is due "
            f"{'today' if days_until == 0 else f'in {days_until} day(s)'}."
        )

        await notification_service.notify_farmer(
            db, user_id,
            type=NotificationType.vaccination_due.value,
            title=title,
            body=body,
            data={
                "cattle_id": str(vacc.cattle_id),
                "vaccine_name": vacc.vaccine_name,
                "due_date": str(vacc.next_due_date),
            },
        )
        count += 1

    logger.info("Vaccination reminders sent: %d", count)
    return count


# ---------------------------------------------------------------------------
# Cold chain → cooperative notification
# ---------------------------------------------------------------------------

async def notify_cold_chain_alert(
    db: AsyncSession,
    center_id: uuid.UUID,
    temperature: float,
    severity: str,
) -> None:
    """
    Notify the cooperative/admin when cold chain threshold is breached.
    Called from collection_service.record_cold_chain_reading().
    """
    from app.models.collection import CollectionCenter
    from app.models.cooperative import Cooperative

    logger.info(
        "notify_cold_chain_alert | center_id=%s, temp=%.1f°C, severity=%s",
        center_id, temperature, severity,
    )

    # Get center and cooperative
    center_result = await db.execute(
        select(CollectionCenter).where(CollectionCenter.id == center_id)
    )
    center = center_result.scalar_one_or_none()
    if not center:
        logger.warning("Center not found for cold chain alert: %s", center_id)
        return

    title = f"Cold Chain {'CRITICAL' if severity == 'critical' else 'Warning'}"
    body = (
        f"Temperature at {center.name} ({center.code}) is {temperature}°C. "
        f"{'Milk at risk — immediate action required!' if severity == 'critical' else 'Check chilling unit.'}"
    )

    # Notify cooperative owner if linked
    if center.cooperative_id:
        coop_result = await db.execute(
            select(Cooperative.user_id).where(
                Cooperative.id == center.cooperative_id
            )
        )
        coop_user_id = coop_result.scalar_one_or_none()
        if coop_user_id:
            await notification_service.notify_farmer(
                db, coop_user_id,
                type=NotificationType.general.value,
                title=title,
                body=body,
                data={
                    "center_id": str(center_id),
                    "temperature": temperature,
                    "severity": severity,
                },
            )
            logger.info(
                "Cold chain alert sent to cooperative | user_id=%s", coop_user_id
            )


# ---------------------------------------------------------------------------
# FCM Device Token Management
# ---------------------------------------------------------------------------

# In-memory token store for MVP. In production, store in DB (users table or
# separate device_tokens table).
_device_tokens: dict[str, str] = {}


async def register_device_token(user_id: uuid.UUID, token: str) -> None:
    """Store FCM device token for a user."""
    _device_tokens[str(user_id)] = token
    logger.info("Device token registered | user_id=%s, token=%s...", user_id, token[:20])


async def get_device_token(user_id: uuid.UUID) -> str | None:
    """Retrieve FCM device token for a user."""
    return _device_tokens.get(str(user_id))
