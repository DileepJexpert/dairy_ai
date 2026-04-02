"""Computer vision module for phone-camera based cattle health assessment.
MVP uses rule-based analysis from manual observations; designed to plug in ONNX models later.
"""
import logging
from dataclasses import dataclass, field

logger = logging.getLogger("dairy_ai.ml.cattle_vision")


@dataclass
class BodyConditionResult:
    score: float       # 1.0 - 5.0 in 0.25 increments
    category: str      # emaciated/thin/ideal/fat/obese
    confidence: float
    observations: dict
    recommendations: list[str]


@dataclass
class PossibleCondition:
    name: str
    probability: float
    description: str
    treatment: str
    urgency: str


@dataclass
class SkinAnalysisResult:
    conditions: list[PossibleCondition]
    severity: str
    recommendations: list[str]


@dataclass
class LamenessResult:
    score: int         # 1-5
    category: str
    possible_causes: list[PossibleCondition]
    recommendations: list[str]


@dataclass
class UdderHealthResult:
    health_score: int  # 1-10
    quarter_assessment: dict  # LF, RF, LR, RR
    conditions: list[str]
    recommendations: list[str]


@dataclass
class FecalScoreResult:
    score: int         # 1-5
    interpretation: str
    possible_causes: list[str]
    action_needed: str


def analyze_body_condition(
    image_url: str | None = None,
    manual_observations: dict | None = None,
) -> BodyConditionResult:
    """Score body condition (BCS) from observations."""
    obs = manual_observations or {}

    pin_bones = obs.get("pin_bones_visible", False)
    ribs_visible = obs.get("ribs_visible", False)
    hip_bones = obs.get("hip_bones_prominent", False)
    tailhead_sunken = obs.get("tailhead_sunken", False)
    spine_visible = obs.get("spine_visible", False)
    fat_deposits = obs.get("fat_deposits_visible", False)
    rounded_appearance = obs.get("rounded_appearance", False)

    score = 3.0  # start at ideal
    if pin_bones:
        score -= 0.5
    if ribs_visible:
        score -= 0.75
    if hip_bones:
        score -= 0.5
    if tailhead_sunken:
        score -= 0.5
    if spine_visible:
        score -= 0.5
    if fat_deposits:
        score += 0.5
    if rounded_appearance:
        score += 0.75

    score = max(1.0, min(5.0, round(score * 4) / 4))

    if score <= 1.5:
        category = "emaciated"
    elif score <= 2.5:
        category = "thin"
    elif score <= 3.5:
        category = "ideal"
    elif score <= 4.25:
        category = "fat"
    else:
        category = "obese"

    recommendations = []
    if score < 2.5:
        recommendations.append("Increase energy in diet immediately — add concentrate and bypass fat")
        recommendations.append("Check for parasites or chronic disease")
        recommendations.append("Target BCS gain of 0.25 per month")
    elif score > 3.75:
        recommendations.append("Reduce concentrate gradually to prevent metabolic disorders")
        recommendations.append("Risk of ketosis and milk fever at calving — monitor closely")
    else:
        recommendations.append("Body condition is ideal — maintain current feeding regimen")

    confidence = 0.6 if manual_observations else 0.3
    if len([v for v in obs.values() if isinstance(v, bool)]) >= 4:
        confidence = 0.8

    logger.info("BCS assessment: score=%.2f, category=%s, confidence=%.2f", score, category, confidence)
    return BodyConditionResult(score=score, category=category, confidence=confidence, observations=obs, recommendations=recommendations)


def analyze_skin_condition(
    image_url: str | None = None,
    affected_area: str = "body",
    manual_observations: dict | None = None,
) -> SkinAnalysisResult:
    """Analyze skin conditions from observations."""
    obs = manual_observations or {}
    lesion_type = obs.get("lesion_type", "").lower()
    distribution = obs.get("distribution", "localized")
    itching = obs.get("itching", False)
    hair_loss = obs.get("hair_loss", False)
    color = obs.get("color", "")

    conditions = []

    if "raised" in lesion_type or "nodule" in lesion_type:
        conditions.append(PossibleCondition("Lumpy Skin Disease (LSD)", 0.7,
            "Viral disease causing hard nodules on skin", "Supportive care, antibiotics for secondary infections, anti-inflammatory", "high"))
    if "circular" in lesion_type or "ring" in color or (hair_loss and "circular" in str(obs)):
        conditions.append(PossibleCondition("Ringworm (Dermatophytosis)", 0.65,
            "Fungal infection causing circular lesions with hair loss", "Topical antifungal (Miconazole); oral Griseofulvin for severe cases", "medium"))
    if itching and hair_loss:
        conditions.append(PossibleCondition("Mange/Scabies", 0.6,
            "Mite infestation causing intense itching and hair loss", "Ivermectin injection + topical acaricide; treat all in-contact animals", "medium"))
    if "crusty" in lesion_type or "scab" in lesion_type:
        conditions.append(PossibleCondition("Dermatophilosis", 0.5,
            "Bacterial skin infection (rain scald) causing crusty scabs", "Parenteral antibiotics (Penicillin/Streptomycin); remove crusts gently", "medium"))
    if "warty" in lesion_type or "wart" in lesion_type:
        conditions.append(PossibleCondition("Papillomatosis (Warts)", 0.7,
            "Viral skin growths, common in young cattle", "Usually self-resolving in 3-6 months; surgical removal if obstructing", "low"))
    if obs.get("ticks_visible", False):
        conditions.append(PossibleCondition("Tick Infestation", 0.85,
            "External parasite burden", "Acaricide spray (Deltamethrin); pour-on Ivermectin; clean shed", "medium"))

    if not conditions:
        conditions.append(PossibleCondition("Unspecified Dermatitis", 0.4,
            "Skin inflammation of unknown cause", "Consult vet for proper diagnosis; topical antiseptic wash", "medium"))

    conditions.sort(key=lambda c: c.probability, reverse=True)
    severity = "high" if any(c.urgency == "high" for c in conditions) else "medium"
    recommendations = [f"Most likely: {conditions[0].name} — {conditions[0].treatment}"]
    if distribution == "widespread":
        recommendations.append("Widespread lesions — isolate animal and consult vet immediately")

    logger.info("Skin analysis: %d conditions detected, top=%s", len(conditions), conditions[0].name)
    return SkinAnalysisResult(conditions=conditions, severity=severity, recommendations=recommendations)


def analyze_lameness(
    gait_description: str = "",
    affected_limb: str | None = None,
    manual_observations: dict | None = None,
) -> LamenessResult:
    """Assess lameness score and possible causes."""
    obs = manual_observations or {}
    gait = gait_description.lower()

    score = 1
    if "slight" in gait or "mild" in gait:
        score = 2
    if "obvious" in gait or "head bob" in gait:
        score = 3
    if "severe" in gait or "reluctant" in gait:
        score = 4
    if "non-weight" in gait or "cannot" in gait or "three leg" in gait:
        score = 5

    categories = {1: "Normal", 2: "Mildly lame", 3: "Moderately lame", 4: "Severely lame", 5: "Non-weight bearing"}

    causes = []
    swelling = obs.get("swelling", False)
    heat = obs.get("heat", False)
    hoof_condition = obs.get("hoof_condition", "")

    if "foul" in gait or "smell" in str(obs) or "interdigital" in hoof_condition:
        causes.append(PossibleCondition("Foot Rot", 0.7, "Bacterial infection between digits", "Clean, trim, topical antibiotics + parenteral Oxytetracycline", "medium"))
    if "sole" in hoof_condition or "ulcer" in hoof_condition:
        causes.append(PossibleCondition("Sole Ulcer", 0.6, "Damage to sole corium", "Corrective hoof trimming, therapeutic block on sound claw", "medium"))
    if swelling and heat:
        causes.append(PossibleCondition("Joint Infection (Arthritis)", 0.5, "Infected joint causing swelling and heat", "Joint lavage + systemic antibiotics; NSAIDs for pain", "high"))
    if score >= 4:
        causes.append(PossibleCondition("Possible Fracture", 0.3, "Bone injury", "Immobilize, urgent vet assessment, X-ray needed", "emergency"))

    if not causes:
        causes.append(PossibleCondition("Digital Dermatitis", 0.5, "Bacterial infection of heel skin", "Topical antibiotics, foot bath with CuSO4", "medium"))

    recommendations = [f"Lameness score {score}/5 — {'urgent vet needed' if score >= 4 else 'monitor and treat'}"]
    if score >= 3:
        recommendations.append("Provide soft bedding and limit walking distance")

    logger.info("Lameness assessment: score=%d, limb=%s, causes=%d", score, affected_limb, len(causes))
    return LamenessResult(score=score, category=categories[score], possible_causes=causes, recommendations=recommendations)


def analyze_udder_health(
    image_url: str | None = None,
    manual_observations: dict | None = None,
) -> UdderHealthResult:
    """Assess udder health."""
    obs = manual_observations or {}

    score = 10
    conditions = []
    quarters = {"LF": "normal", "RF": "normal", "LR": "normal", "RR": "normal"}

    if obs.get("swelling"):
        score -= 2
        conditions.append("Udder edema detected")
    if obs.get("heat"):
        score -= 2
        conditions.append("Localized heat — possible infection")
    if obs.get("asymmetry"):
        score -= 1
        conditions.append("Quarter asymmetry — check individual quarters")
    if obs.get("abnormal_milk"):
        score -= 3
        conditions.append("Abnormal milk (clots/blood/watery) — mastitis likely")
    if obs.get("teat_damage"):
        score -= 2
        conditions.append("Teat damage — risk of ascending infection")

    affected = obs.get("affected_quarter", "")
    if affected:
        quarters[affected] = "affected"

    recommendations = []
    if score <= 5:
        recommendations.append("Likely mastitis — start CMT test, consult vet, begin intramammary therapy")
    elif score <= 7:
        recommendations.append("Monitor closely — do daily CMT checks, maintain milking hygiene")
    else:
        recommendations.append("Udder health appears good — continue regular teat dipping and hygiene")

    score = max(1, score)
    logger.info("Udder health: score=%d/10, conditions=%d", score, len(conditions))
    return UdderHealthResult(health_score=score, quarter_assessment=quarters, conditions=conditions, recommendations=recommendations)


def analyze_fecal_score(
    image_url: str | None = None,
    manual_observations: dict | None = None,
) -> FecalScoreResult:
    """Score fecal consistency (1=watery, 3=ideal, 5=hard)."""
    obs = manual_observations or {}
    consistency = obs.get("consistency", "normal").lower()

    score_map = {"watery": 1, "liquid": 1, "loose": 2, "soft": 3, "normal": 3, "firm": 4, "hard": 5, "dry": 5}
    score = score_map.get(consistency, 3)

    interpretations = {
        1: "Severe diarrhea — risk of dehydration",
        2: "Loose stool — mild digestive upset",
        3: "Normal — ideal consistency",
        4: "Slightly firm — adequate hydration needed",
        5: "Hard/dry — possible constipation or dehydration",
    }

    causes_map = {
        1: ["Bacterial infection (E.coli, Salmonella)", "Viral infection (Rotavirus, Coronavirus)", "Heavy parasitic load", "Severe acidosis"],
        2: ["Dietary change", "Mild parasites", "Subclinical acidosis", "High moisture feed"],
        3: [],
        4: ["Low water intake", "High dry roughage diet", "Early dehydration"],
        5: ["Dehydration", "Impaction", "Obstruction", "Inadequate water access"],
    }

    action = {
        1: "URGENT: Start oral rehydration (ORS), call vet, check for blood/mucus, isolate from herd",
        2: "Monitor 24-48h, ensure water access, consider deworming if not done recently",
        3: "No action needed — healthy digestive function",
        4: "Ensure 24/7 water access, add moisture to feed, monitor",
        5: "Provide water, consider mineral oil drench, check for impaction, call vet if persistent",
    }

    logger.info("Fecal score: %d/5, consistency=%s", score, consistency)
    return FecalScoreResult(score=score, interpretation=interpretations[score], possible_causes=causes_map[score], action_needed=action[score])
