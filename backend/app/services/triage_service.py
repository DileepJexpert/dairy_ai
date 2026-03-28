import logging
import uuid
from datetime import date
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.triage_scorer import TriageInput, TriageResult, triage_score
from app.repositories import health_repo

logger = logging.getLogger("dairy_ai.services.triage")


async def run_triage(
    db: AsyncSession,
    farmer_id: uuid.UUID,
    cattle_id: uuid.UUID,
    symptoms: str,
    photo_urls: list[str] | None = None,
) -> dict:
    """Run triage: fetch sensor data + history, score, save result."""
    logger.info(f"run_triage called | farmer_id={farmer_id}, cattle_id={cattle_id}")
    logger.info(f"Triage symptoms: {symptoms}")
    if photo_urls:
        logger.debug(f"Photos provided: {len(photo_urls)} image(s)")

    # Fetch latest sensor data
    logger.debug(f"Fetching latest sensor data for cattle_id={cattle_id}")
    sensor_data = None
    latest = await health_repo.get_latest_sensor(db, cattle_id)
    if latest:
        sensor_data = {
            "temperature": latest.temperature,
            "heart_rate": latest.heart_rate,
            "activity_level": latest.activity_level,
        }
        logger.debug(f"Sensor data found | temp={latest.temperature}, heart_rate={latest.heart_rate}, activity={latest.activity_level}")
    else:
        logger.debug(f"No sensor data available for cattle_id={cattle_id}")

    # Fetch recent health records
    logger.debug(f"Fetching recent health records for cattle_id={cattle_id}")
    records = await health_repo.get_health_records(db, cattle_id)
    history = [
        {"date": str(r.date), "type": r.record_type.value if hasattr(r.record_type, 'value') else r.record_type}
        for r in records[:5]
    ]
    logger.debug(f"Health history loaded | cattle_id={cattle_id}, records_used={len(history)}")

    # Run triage
    logger.info(f"Running triage scoring algorithm | cattle_id={cattle_id}")
    triage_input = TriageInput(
        symptoms=symptoms,
        sensor_data=sensor_data,
        health_history=history,
        photo_urls=photo_urls,
    )
    result = triage_score(triage_input)
    logger.info(f"Triage result | cattle_id={cattle_id}, severity={result.severity}, severity_level={result.severity_level}, confidence={result.confidence}")
    logger.debug(f"Triage diagnosis: {result.preliminary_diagnosis}")
    logger.debug(f"Triage reasoning: {result.reasoning}")
    logger.debug(f"Triage recommended action: {result.recommended_action}")

    # Save as health record
    logger.debug(f"Saving triage result as health record | cattle_id={cattle_id}")
    await health_repo.create_health_record(
        db, cattle_id,
        date=date.today(),
        record_type="observation",
        symptoms=symptoms,
        diagnosis=result.preliminary_diagnosis,
        severity=result.severity,
        notes=f"AI Triage: {result.reasoning}",
    )
    logger.info(f"Triage health record saved | cattle_id={cattle_id}, severity={result.severity}")

    if result.severity_level >= 3:
        logger.warning(f"HIGH SEVERITY triage result | cattle_id={cattle_id}, severity={result.severity}, level={result.severity_level} — vet consultation recommended")

    return {
        "severity": result.severity,
        "severity_level": result.severity_level,
        "preliminary_diagnosis": result.preliminary_diagnosis,
        "confidence": result.confidence,
        "recommended_action": result.recommended_action,
        "reasoning": result.reasoning,
        "sensor_data": sensor_data,
    }
