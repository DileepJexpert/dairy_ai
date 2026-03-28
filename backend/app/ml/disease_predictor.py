"""Disease prediction model — rule-based MVP for common Indian cattle diseases."""
import logging
from dataclasses import dataclass, field

logger = logging.getLogger("dairy_ai.ml.disease_predictor")


@dataclass
class DiseaseInput:
    symptoms: list[str]
    sensor_data: dict | None = None  # temperature, heart_rate, activity_level
    age_months: int | None = None
    breed: str | None = None
    lactation_stage: str | None = None  # early/mid/late/dry
    season: str | None = None  # summer/monsoon/winter
    days_in_milk: int | None = None
    recent_history: list[str] | None = None


@dataclass
class PredictedDisease:
    name: str
    probability: float
    description: str
    urgency: str  # low/medium/high/emergency
    recommended_treatment: str
    prevention_tips: str


DISEASE_DB: dict[str, dict] = {
    "mastitis": {
        "symptom_triggers": ["udder swelling", "swollen udder", "abnormal milk", "clots in milk",
                             "blood in milk", "reduced milk", "hot udder", "painful udder", "mastitis"],
        "sensor_triggers": {"temperature_min": 39.5, "heart_rate_min": 75},
        "base_score": 0.0,
        "description": "Bacterial infection of the udder causing inflammation",
        "urgency": "high",
        "treatment": "Intramammary antibiotic infusion (Ceftriaxone/Amoxicillin); strip affected quarter 3x/day; cold compresses; NSAIDs for pain",
        "prevention": "Proper milking hygiene; teat dipping post-milking; dry cow therapy; clean bedding; regular CMT testing",
    },
    "foot_and_mouth_disease": {
        "symptom_triggers": ["drooling", "blisters", "mouth sores", "lameness", "foot lesions",
                             "salivation", "not eating", "off feed", "vesicles"],
        "sensor_triggers": {"temperature_min": 40.0},
        "base_score": 0.0,
        "description": "Highly contagious viral disease causing blisters in mouth and feet",
        "urgency": "emergency",
        "treatment": "No specific treatment; supportive care; wound washing with KMnO4; soft feed; antiseptic application on lesions; isolate immediately; report to authorities",
        "prevention": "FMD vaccination every 6 months; quarantine new animals; restrict movement during outbreaks",
    },
    "hemorrhagic_septicemia": {
        "symptom_triggers": ["swollen throat", "difficulty breathing", "sudden death", "neck swelling",
                             "edema", "high fever", "depression"],
        "sensor_triggers": {"temperature_min": 40.5, "heart_rate_min": 90},
        "base_score": 0.0,
        "description": "Acute bacterial disease (Pasteurella multocida) causing rapid death",
        "urgency": "emergency",
        "treatment": "Oxytetracycline IV immediately; Sulphonamides; antihistamines; EMERGENCY VET NEEDED; often fatal if not treated within hours",
        "prevention": "HS vaccination before monsoon; avoid waterlogged areas; proper drainage",
        "season_boost": {"monsoon": 0.15},
    },
    "black_quarter": {
        "symptom_triggers": ["sudden lameness", "muscle swelling", "crepitus", "crackling sound",
                             "gas gangrene", "leg swelling", "sudden death"],
        "sensor_triggers": {"temperature_min": 40.0},
        "base_score": 0.0,
        "description": "Acute clostridial infection causing gas gangrene in muscles",
        "urgency": "emergency",
        "treatment": "High-dose Penicillin immediately; incision and drainage of affected muscle; anti-inflammatory; often fatal if delayed",
        "prevention": "BQ vaccination annually before monsoon; avoid grazing on flooded pastures",
        "season_boost": {"monsoon": 0.15},
        "age_boost": {"max_months": 36, "boost": 0.1},  # young animals more susceptible
    },
    "theileriosis": {
        "symptom_triggers": ["enlarged lymph nodes", "swollen lymph", "jaundice", "anemia",
                             "pale mucous", "weakness", "tick"],
        "sensor_triggers": {"temperature_min": 39.5},
        "base_score": 0.0,
        "description": "Tick-borne protozoan disease (Theileria annulata) causing anemia and lymph node enlargement",
        "urgency": "high",
        "treatment": "Buparvaquone (Butalex) injection; supportive therapy with iron and B12; blood transfusion in severe cases; tick removal",
        "prevention": "Regular tick control (Deltamethrin spray); keep premises clean; prophylactic Buparvaquone in endemic areas",
    },
    "babesiosis": {
        "symptom_triggers": ["red urine", "dark urine", "hemoglobinuria", "anemia", "jaundice",
                             "high fever", "tick"],
        "sensor_triggers": {"temperature_min": 40.0},
        "base_score": 0.0,
        "description": "Tick-borne protozoan disease causing red blood cell destruction",
        "urgency": "high",
        "treatment": "Diminazene aceturate (Berenil) or Imidocarb injection; supportive with IV fluids and iron; blood transfusion if severe",
        "prevention": "Tick control spraying every 2 weeks in season; Imidocarb prophylaxis for imported cattle",
    },
    "ketosis": {
        "symptom_triggers": ["reduced appetite", "weight loss", "reduced milk", "sweet breath",
                             "acetone smell", "dull", "constipation"],
        "sensor_triggers": {"activity_max": 30},
        "base_score": 0.0,
        "description": "Metabolic disorder from negative energy balance in early lactation",
        "urgency": "medium",
        "treatment": "IV Dextrose (500ml 25%); Propylene glycol oral drench 300ml 2x/day for 3 days; Dexamethasone; improve energy in diet",
        "prevention": "Gradual increase of concentrate before calving; avoid obesity at calving (BCS 3-3.5); adequate transition diet",
        "lactation_boost": {"early": 0.2},  # most common in first 6 weeks
    },
    "milk_fever": {
        "symptom_triggers": ["down cow", "cannot stand", "staggering", "cold ears", "muscle tremors",
                             "S-bend neck", "dilated pupils", "constipation"],
        "sensor_triggers": {"temperature_max": 37.5, "heart_rate_min": 80},
        "base_score": 0.0,
        "description": "Hypocalcemia usually within 48h of calving; calcium depletion",
        "urgency": "emergency",
        "treatment": "Calcium borogluconate IV (slow, 400ml); monitor heart during infusion; oral calcium gel after standing; prop in sternal position",
        "prevention": "Low-calcium diet in dry period; anionic salts in transition diet; oral calcium bolus at calving",
        "lactation_boost": {"early": 0.25},
    },
    "bloat": {
        "symptom_triggers": ["bloat", "bloated", "distended abdomen", "difficulty breathing",
                             "restless", "kicking at belly", "left side swollen"],
        "sensor_triggers": {"heart_rate_min": 85},
        "base_score": 0.0,
        "description": "Gas accumulation in rumen; can be frothy (legume) or free gas",
        "urgency": "emergency",
        "treatment": "EMERGENCY: pass stomach tube; Poloxalene (anti-bloat) oral; trocar and cannula for severe cases; massage left flank; walk the animal",
        "prevention": "Gradual introduction to lush pasture; mixed grass-legume grazing; anti-bloat licks; avoid feeding wet legumes",
    },
    "acidosis": {
        "symptom_triggers": ["off feed", "loose stool", "diarrhea", "low milk fat",
                             "laminitis", "grain overload"],
        "sensor_triggers": {"activity_max": 40},
        "base_score": 0.0,
        "description": "Rumen pH drop from excess concentrate/grain intake",
        "urgency": "medium",
        "treatment": "Remove concentrate; oral buffer (sodium bicarbonate 200g); rumen transfaunation in severe cases; IV fluids; B-complex vitamins",
        "prevention": "Gradual concentrate increase; maintain 40:60 roughage:concentrate ratio; buffer in TMR; adequate fiber",
    },
    "tick_fever": {
        "symptom_triggers": ["tick", "ticks", "fever", "anemia", "weakness", "pale gums",
                             "loss of appetite"],
        "sensor_triggers": {"temperature_min": 39.5},
        "base_score": 0.0,
        "description": "General term for tick-borne diseases (Babesiosis/Theileriosis/Anaplasmosis)",
        "urgency": "high",
        "treatment": "Identify specific tick-borne disease; Diminazene or Buparvaquone; tick removal; supportive care",
        "prevention": "Regular spraying with acaricide (Deltamethrin); keep shed clean; check cattle daily for ticks",
    },
    "respiratory_infection": {
        "symptom_triggers": ["cough", "coughing", "nasal discharge", "labored breathing",
                             "runny nose", "pneumonia", "wheezing"],
        "sensor_triggers": {"temperature_min": 39.5},
        "base_score": 0.0,
        "description": "Bovine Respiratory Disease (BRD) — bacterial/viral lung infection",
        "urgency": "high",
        "treatment": "Broad-spectrum antibiotics (Enrofloxacin/Ceftiofur); NSAIDs; expectorants; ensure ventilation; isolate",
        "prevention": "Proper ventilation in shed; avoid overcrowding; vaccinate (IBR, PI3); reduce stress during transport",
        "season_boost": {"winter": 0.1},
    },
}


def predict_diseases(input: DiseaseInput) -> list[PredictedDisease]:
    """Predict probable diseases from symptoms and sensor data."""
    logger.info("Disease prediction: symptoms=%s, sensor=%s, breed=%s",
                input.symptoms, bool(input.sensor_data), input.breed)

    results: dict[str, float] = {}
    symptoms_lower = [s.lower() for s in input.symptoms]
    symptoms_text = " ".join(symptoms_lower)

    for disease_name, db in DISEASE_DB.items():
        score = db["base_score"]

        # Check symptom matches
        matched = 0
        for trigger in db["symptom_triggers"]:
            if trigger in symptoms_text:
                matched += 1
        if matched == 0:
            continue
        score += min(matched * 0.2, 0.6)

        # Sensor data checks
        if input.sensor_data:
            temp = input.sensor_data.get("temperature")
            hr = input.sensor_data.get("heart_rate")
            activity = input.sensor_data.get("activity_level")

            if temp and "temperature_min" in db.get("sensor_triggers", {}):
                if temp >= db["sensor_triggers"]["temperature_min"]:
                    score += 0.15
            if temp and "temperature_max" in db.get("sensor_triggers", {}):
                if temp <= db["sensor_triggers"]["temperature_max"]:
                    score += 0.15
            if hr and "heart_rate_min" in db.get("sensor_triggers", {}):
                if hr >= db["sensor_triggers"]["heart_rate_min"]:
                    score += 0.1
            if activity is not None and "activity_max" in db.get("sensor_triggers", {}):
                if activity <= db["sensor_triggers"]["activity_max"]:
                    score += 0.1

        # Season boost
        if input.season and "season_boost" in db:
            boost = db["season_boost"].get(input.season, 0)
            score += boost

        # Lactation stage boost
        if input.lactation_stage and "lactation_boost" in db:
            boost = db["lactation_boost"].get(input.lactation_stage, 0)
            score += boost

        # Age boost
        if input.age_months and "age_boost" in db:
            if input.age_months <= db["age_boost"].get("max_months", 999):
                score += db["age_boost"].get("boost", 0)

        score = min(score, 0.95)
        if score >= 0.15:
            results[disease_name] = round(score, 3)

    # Sort by probability, take top 5
    sorted_diseases = sorted(results.items(), key=lambda x: x[1], reverse=True)[:5]

    predictions = []
    for disease_name, probability in sorted_diseases:
        db = DISEASE_DB[disease_name]
        predictions.append(PredictedDisease(
            name=disease_name.replace("_", " ").title(),
            probability=probability,
            description=db["description"],
            urgency=db["urgency"],
            recommended_treatment=db["treatment"],
            prevention_tips=db["prevention"],
        ))

    logger.info("Predicted %d diseases: %s",
                len(predictions), [(p.name, p.probability) for p in predictions])
    return predictions
