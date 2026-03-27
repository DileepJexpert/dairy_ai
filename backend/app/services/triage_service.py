import uuid
from datetime import date
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.triage_scorer import TriageInput, TriageResult, triage_score
from app.repositories import health_repo


async def run_triage(
    db: AsyncSession,
    farmer_id: uuid.UUID,
    cattle_id: uuid.UUID,
    symptoms: str,
    photo_urls: list[str] | None = None,
) -> dict:
    """Run triage: fetch sensor data + history, score, save result."""
    # Fetch latest sensor data
    sensor_data = None
    latest = await health_repo.get_latest_sensor(db, cattle_id)
    if latest:
        sensor_data = {
            "temperature": latest.temperature,
            "heart_rate": latest.heart_rate,
            "activity_level": latest.activity_level,
        }

    # Fetch recent health records
    records = await health_repo.get_health_records(db, cattle_id)
    history = [
        {"date": str(r.date), "type": r.record_type.value if hasattr(r.record_type, 'value') else r.record_type}
        for r in records[:5]
    ]

    # Run triage
    triage_input = TriageInput(
        symptoms=symptoms,
        sensor_data=sensor_data,
        health_history=history,
        photo_urls=photo_urls,
    )
    result = triage_score(triage_input)

    # Save as health record
    await health_repo.create_health_record(
        db, cattle_id,
        date=date.today(),
        record_type="observation",
        symptoms=symptoms,
        diagnosis=result.preliminary_diagnosis,
        severity=result.severity,
        notes=f"AI Triage: {result.reasoning}",
    )

    return {
        "severity": result.severity,
        "severity_level": result.severity_level,
        "preliminary_diagnosis": result.preliminary_diagnosis,
        "confidence": result.confidence,
        "recommended_action": result.recommended_action,
        "reasoning": result.reasoning,
        "sensor_data": sensor_data,
    }
