from dataclasses import dataclass


@dataclass
class TriageInput:
    symptoms: str
    sensor_data: dict | None = None
    health_history: list | None = None
    photo_urls: list | None = None


@dataclass
class TriageResult:
    severity: int  # 1-10
    severity_level: str  # low/medium/high/emergency
    preliminary_diagnosis: str
    confidence: float  # 0-1
    recommended_action: str  # self_care/schedule_visit/video_consult/emergency
    reasoning: str


def triage_score(input: TriageInput) -> TriageResult:
    """Rule-based triage scoring for MVP."""
    score = 0
    reasons = []
    diagnosis = "General observation needed"

    # Check sensor data
    if input.sensor_data:
        temp = input.sensor_data.get("temperature")
        hr = input.sensor_data.get("heart_rate")
        activity = input.sensor_data.get("activity_level")

        if temp and temp > 40.0:
            score += 3
            reasons.append(f"High temperature ({temp}°C)")
        elif temp and temp > 39.5:
            score += 2
            reasons.append(f"Elevated temperature ({temp}°C)")

        if hr and hr > 80:
            score += 2
            reasons.append(f"High heart rate ({hr} bpm)")

        if activity is not None and activity < 20:
            score += 2
            reasons.append(f"Very low activity ({activity})")

    # Check symptom keywords
    symptoms_lower = input.symptoms.lower()
    keyword_scores = {
        "not eating": 2, "off feed": 2, "no appetite": 2,
        "blood": 3, "bleeding": 3,
        "swelling": 2, "swollen": 2,
        "limping": 1, "lame": 1, "lameness": 1,
        "discharge": 2,
        "bloat": 3, "bloated": 3,
        "down": 4, "collapsed": 4, "cannot stand": 4,
        "fever": 2,
        "diarrhea": 2, "loose motion": 2,
        "cough": 1, "coughing": 1,
        "mastitis": 3, "udder": 2,
    }

    for keyword, points in keyword_scores.items():
        if keyword in symptoms_lower:
            score += points
            reasons.append(f"Symptom: {keyword}")

    # Check health history
    if input.health_history:
        recent_issues = len(input.health_history)
        if recent_issues > 0:
            score += 1
            reasons.append(f"Has {recent_issues} recent health record(s)")

    # Clamp score
    score = min(score, 10)

    # Map to severity level
    if score <= 3:
        level = "low"
        action = "self_care"
    elif score <= 6:
        level = "medium"
        action = "schedule_visit"
    elif score <= 8:
        level = "high"
        action = "video_consult"
    else:
        level = "emergency"
        action = "emergency"

    # Diagnosis mapping
    if "bloat" in symptoms_lower:
        diagnosis = "Possible bloat — EMERGENCY"
    elif "down" in symptoms_lower or "collapsed" in symptoms_lower:
        diagnosis = "Animal down — EMERGENCY"
    elif ("fever" in symptoms_lower or (input.sensor_data and input.sensor_data.get("temperature", 0) > 39.5)):
        if "udder" in symptoms_lower or "mastitis" in symptoms_lower:
            diagnosis = "Possible mastitis"
        else:
            diagnosis = "Possible fever/infection"
    elif "blood" in symptoms_lower:
        diagnosis = "Possible internal/external bleeding"
    elif "diarrhea" in symptoms_lower or "loose motion" in symptoms_lower:
        diagnosis = "Possible gastrointestinal issue"
    elif "limping" in symptoms_lower or "lame" in symptoms_lower:
        diagnosis = "Possible limb injury or foot rot"
    elif "not eating" in symptoms_lower or "off feed" in symptoms_lower:
        diagnosis = "Possible digestive issue or general illness"

    confidence = min(0.3 + len(reasons) * 0.1, 0.85)

    return TriageResult(
        severity=score,
        severity_level=level,
        preliminary_diagnosis=diagnosis,
        confidence=round(confidence, 2),
        recommended_action=action,
        reasoning="; ".join(reasons) if reasons else "No specific indicators found",
    )
