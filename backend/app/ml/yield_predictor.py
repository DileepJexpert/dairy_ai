"""Milk yield prediction using Wood's lactation curve model."""
import logging
import math
from dataclasses import dataclass

logger = logging.getLogger("dairy_ai.ml.yield_predictor")


@dataclass
class YieldInput:
    breed: str
    lactation_number: int = 1
    days_in_milk: int = 60
    current_daily_yield: float = 10.0
    age_months: int | None = None
    weight_kg: float | None = None
    feed_quality_score: int = 3  # 1-5
    season: str | None = None  # summer/monsoon/winter
    sensor_data: dict | None = None


@dataclass
class YieldPrediction:
    predicted_daily_yield: float
    predicted_monthly_yield: float
    predicted_305_day_yield: float
    peak_yield_estimate: float
    days_to_peak: int
    trend: str  # increasing/plateau/declining
    factors_affecting: list[str]
    recommendations: list[str]
    lactation_curve: list[dict]  # [{day, predicted_yield}] for charting


# Wood's model parameters: Y = a * t^b * e^(-c*t)
# a = scaling factor, b = incline, c = decline rate
BREED_PARAMS: dict[str, dict] = {
    "gir": {"a": 5.5, "b": 0.18, "c": 0.003, "peak_day": 60, "peak_range": (8, 12), "avg_305": 1800},
    "sahiwal": {"a": 6.0, "b": 0.20, "c": 0.003, "peak_day": 55, "peak_range": (8, 14), "avg_305": 2200},
    "murrah": {"a": 6.5, "b": 0.22, "c": 0.0035, "peak_day": 50, "peak_range": (8, 15), "avg_305": 2400},
    "hf_crossbred": {"a": 9.0, "b": 0.25, "c": 0.004, "peak_day": 45, "peak_range": (15, 25), "avg_305": 4500},
    "jersey_crossbred": {"a": 7.5, "b": 0.22, "c": 0.0035, "peak_day": 50, "peak_range": (12, 18), "avg_305": 3500},
    "other": {"a": 7.0, "b": 0.20, "c": 0.0035, "peak_day": 55, "peak_range": (10, 16), "avg_305": 3000},
}

# Parity (lactation number) adjustment
PARITY_FACTOR = {1: 0.85, 2: 0.95, 3: 1.0, 4: 1.0, 5: 0.97, 6: 0.93, 7: 0.88}

# Season adjustment
SEASON_FACTOR = {"summer": 0.85, "monsoon": 0.95, "winter": 1.05}


def _wood_curve(a: float, b: float, c: float, day: int) -> float:
    """Calculate yield at given day using Wood's model."""
    if day <= 0:
        return 0.0
    return a * (day ** b) * math.exp(-c * day)


def _calibrate_params(breed_params: dict, current_yield: float, dim: int) -> tuple[float, float, float]:
    """Calibrate Wood's parameters to match observed current yield."""
    a, b, c = breed_params["a"], breed_params["b"], breed_params["c"]
    if dim <= 0:
        return a, b, c

    predicted_at_dim = _wood_curve(a, b, c, dim)
    if predicted_at_dim > 0:
        ratio = current_yield / predicted_at_dim
        a = a * ratio  # adjust scaling to match observed
    return a, b, c


def predict_yield(input: YieldInput) -> YieldPrediction:
    """Predict milk yield trajectory using calibrated Wood's curve."""
    logger.info("Yield prediction: breed=%s, DIM=%d, current=%.1f, lactation=%d",
                input.breed, input.days_in_milk, input.current_daily_yield, input.lactation_number)

    breed = BREED_PARAMS.get(input.breed, BREED_PARAMS["other"])
    a, b, c = _calibrate_params(breed, input.current_daily_yield, input.days_in_milk)

    # Apply adjustments
    parity_adj = PARITY_FACTOR.get(input.lactation_number, 0.85)
    season_adj = SEASON_FACTOR.get(input.season, 1.0)
    feed_adj = 0.85 + (input.feed_quality_score - 1) * 0.0375  # 1->0.85, 5->1.0

    total_adj = parity_adj * season_adj * feed_adj

    # Peak yield
    if b > 0 and c > 0:
        peak_day = int(b / c)
    else:
        peak_day = breed["peak_day"]
    peak_yield = _wood_curve(a, b, c, peak_day) * total_adj

    # Predicted yield today
    predicted_today = _wood_curve(a, b, c, input.days_in_milk) * total_adj

    # Generate 305-day curve
    curve = []
    total_305 = 0.0
    for day in range(1, 306):
        y = _wood_curve(a, b, c, day) * total_adj
        y = max(y, 0.5)  # minimum yield
        total_305 += y
        if day % 15 == 0 or day == 1 or day == 305:
            curve.append({"day": day, "predicted_yield": round(y, 1)})

    # Monthly prediction (next 30 days)
    monthly_total = sum(_wood_curve(a, b, c, input.days_in_milk + d) * total_adj for d in range(1, 31))

    # Trend determination
    yield_tomorrow = _wood_curve(a, b, c, input.days_in_milk + 1) * total_adj
    yield_week = _wood_curve(a, b, c, input.days_in_milk + 7) * total_adj
    if input.days_in_milk < peak_day - 5:
        trend = "increasing"
    elif abs(predicted_today - yield_week) / max(predicted_today, 0.1) < 0.02:
        trend = "plateau"
    else:
        trend = "declining"

    days_to_peak = max(0, peak_day - input.days_in_milk)

    # Factors affecting yield
    factors = []
    if input.season == "summer":
        factors.append("Summer heat stress reducing yield by ~15%")
    if input.feed_quality_score <= 2:
        factors.append("Poor feed quality limiting yield potential")
    if input.lactation_number == 1:
        factors.append("First lactation — yield typically 15% below peak potential")
    elif input.lactation_number >= 6:
        factors.append(f"Lactation {input.lactation_number} — age-related decline expected")
    if input.days_in_milk > 200:
        factors.append("Late lactation — natural decline in yield curve")
    if input.sensor_data:
        temp = input.sensor_data.get("temperature", 0)
        if temp > 39.5:
            factors.append(f"Elevated body temperature ({temp}°C) may indicate illness affecting yield")
        activity = input.sensor_data.get("activity_level", 50)
        if activity < 20:
            factors.append("Low activity level — potential health issue affecting yield")

    # Recommendations
    recommendations = []
    if trend == "increasing" and days_to_peak > 0:
        recommendations.append(f"Peak expected around day {peak_day} — gradually increase concentrate by 0.5kg/week")
    if input.feed_quality_score < 4:
        recommendations.append("Improving feed quality (more protein, better concentrate mix) could boost yield 1-3L/day")
    if input.season == "summer":
        recommendations.append("Provide cool water, shade, and fans; consider night feeding schedule")
    if input.days_in_milk > 250:
        recommendations.append("Consider dry-off planning; start reducing concentrate gradually")
    if peak_yield < breed["peak_range"][0]:
        recommendations.append(f"Yield below breed average ({breed['peak_range'][0]}-{breed['peak_range'][1]}L). Check for subclinical health issues or feed deficiency")

    result = YieldPrediction(
        predicted_daily_yield=round(predicted_today, 1),
        predicted_monthly_yield=round(monthly_total, 1),
        predicted_305_day_yield=round(total_305, 0),
        peak_yield_estimate=round(peak_yield, 1),
        days_to_peak=days_to_peak,
        trend=trend,
        factors_affecting=factors,
        recommendations=recommendations,
        lactation_curve=curve,
    )

    logger.info("Yield prediction result: daily=%.1f, 305-day=%.0f, peak=%.1f at day %d, trend=%s",
                result.predicted_daily_yield, result.predicted_305_day_yield,
                result.peak_yield_estimate, peak_day, result.trend)
    return result
