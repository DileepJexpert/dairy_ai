import logging
import uuid
import math
from datetime import date, timedelta, datetime
from collections import defaultdict
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.collection import MilkCollection

logger = logging.getLogger("dairy_ai.ml.demand_forecaster")


async def forecast_demand(
    db: AsyncSession,
    center_id: uuid.UUID,
    days_ahead: int = 7,
) -> list[dict]:
    """Forecast daily milk collection for the next N days.

    Fetches the last 30 days of MilkCollection records for the given center,
    groups them by date, and calculates weekday vs weekend averages to produce
    per-day predictions with a confidence band of ±1.5 * std_dev.

    Args:
        db: Async SQLAlchemy session.
        center_id: UUID of the milk collection center.
        days_ahead: Number of future days to forecast (default 7).

    Returns:
        List of dicts with keys: date, predicted_litres, confidence_low,
        confidence_high.
    """
    logger.info(
        "Starting demand forecast for center_id=%s, days_ahead=%d",
        center_id,
        days_ahead,
    )

    today = date.today()
    start_date = today - timedelta(days=30)

    logger.debug(
        "Fetching MilkCollection records from %s to %s for center_id=%s",
        start_date,
        today,
        center_id,
    )

    stmt = select(MilkCollection).where(
        MilkCollection.center_id == center_id,
        MilkCollection.collection_date >= start_date,
        MilkCollection.collection_date < today,
    )
    result = await db.execute(stmt)
    records = result.scalars().all()

    logger.info(
        "Fetched %d MilkCollection records for center_id=%s",
        len(records),
        center_id,
    )

    # Group records by date and sum quantity_litres
    daily_totals: dict[date, float] = defaultdict(float)
    for record in records:
        daily_totals[record.collection_date] += float(record.quantity_litres)

    logger.debug("Daily totals grouped: %d distinct dates", len(daily_totals))

    if not daily_totals:
        logger.warning(
            "No historical data found for center_id=%s; returning zero forecasts",
            center_id,
        )
        forecasts = []
        for i in range(1, days_ahead + 1):
            forecast_date = today + timedelta(days=i)
            forecasts.append(
                {
                    "date": forecast_date.isoformat(),
                    "predicted_litres": 0.0,
                    "confidence_low": 0.0,
                    "confidence_high": 0.0,
                }
            )
        return forecasts

    # Separate weekday (Mon–Fri, weekday() 0–4) vs weekend (Sat–Sun, 5–6)
    weekday_values: list[float] = []
    weekend_values: list[float] = []
    all_values: list[float] = list(daily_totals.values())

    for collection_date, total in daily_totals.items():
        if collection_date.weekday() < 5:
            weekday_values.append(total)
        else:
            weekend_values.append(total)

    logger.debug(
        "Weekday samples: %d, weekend samples: %d",
        len(weekday_values),
        len(weekend_values),
    )

    def _mean(values: list[float]) -> float:
        return sum(values) / len(values) if values else 0.0

    def _std_dev(values: list[float], mean: float) -> float:
        if len(values) < 2:
            return 0.0
        variance = sum((v - mean) ** 2 for v in values) / (len(values) - 1)
        return math.sqrt(variance)

    avg_daily = _mean(all_values)
    std_dev = _std_dev(all_values, avg_daily)

    weekday_avg = _mean(weekday_values) if weekday_values else avg_daily
    weekend_avg = _mean(weekend_values) if weekend_values else avg_daily

    logger.info(
        "Computed averages — avg_daily=%.2f, std_dev=%.2f, "
        "weekday_avg=%.2f, weekend_avg=%.2f",
        avg_daily,
        std_dev,
        weekday_avg,
        weekend_avg,
    )

    seasonal_factor = 1.0
    confidence_multiplier = 1.5

    forecasts: list[dict] = []
    for i in range(1, days_ahead + 1):
        forecast_date = today + timedelta(days=i)
        is_weekend = forecast_date.weekday() >= 5

        base_avg = weekend_avg if is_weekend else weekday_avg
        predicted = base_avg * seasonal_factor
        confidence_low = max(0.0, predicted - confidence_multiplier * std_dev)
        confidence_high = predicted + confidence_multiplier * std_dev

        logger.debug(
            "Forecast for %s (is_weekend=%s): predicted=%.2f, "
            "confidence_low=%.2f, confidence_high=%.2f",
            forecast_date.isoformat(),
            is_weekend,
            predicted,
            confidence_low,
            confidence_high,
        )

        forecasts.append(
            {
                "date": forecast_date.isoformat(),
                "predicted_litres": round(predicted, 2),
                "confidence_low": round(confidence_low, 2),
                "confidence_high": round(confidence_high, 2),
            }
        )

    logger.info(
        "Demand forecast complete for center_id=%s: %d days forecasted",
        center_id,
        len(forecasts),
    )
    return forecasts


async def detect_collection_anomaly(
    db: AsyncSession,
    center_id: uuid.UUID,
    today_litres: float,
) -> dict:
    """Detect whether today's milk collection volume is anomalous.

    Compares today_litres against the 14-day rolling average to flag low or
    high collection events.

    Args:
        db: Async SQLAlchemy session.
        center_id: UUID of the milk collection center.
        today_litres: Total litres collected today.

    Returns:
        Dict with keys: is_anomaly, anomaly_type, severity, today_litres,
        avg_14day, deviation_pct.
    """
    logger.info(
        "Detecting collection anomaly for center_id=%s, today_litres=%.2f",
        center_id,
        today_litres,
    )

    today = date.today()
    start_date = today - timedelta(days=14)

    logger.debug(
        "Fetching last 14 days of MilkCollection records from %s for center_id=%s",
        start_date,
        center_id,
    )

    stmt = select(MilkCollection).where(
        MilkCollection.center_id == center_id,
        MilkCollection.collection_date >= start_date,
        MilkCollection.collection_date < today,
    )
    result = await db.execute(stmt)
    records = result.scalars().all()

    logger.info(
        "Fetched %d records for 14-day anomaly window, center_id=%s",
        len(records),
        center_id,
    )

    # Group by date, then compute daily totals, then overall average
    daily_totals: dict[date, float] = defaultdict(float)
    for record in records:
        daily_totals[record.collection_date] += float(record.quantity_litres)

    if not daily_totals:
        logger.warning(
            "No historical records for center_id=%s; cannot detect anomaly",
            center_id,
        )
        return {
            "is_anomaly": False,
            "anomaly_type": None,
            "severity": None,
            "today_litres": today_litres,
            "avg_14day": 0.0,
            "deviation_pct": 0.0,
        }

    avg_14day = sum(daily_totals.values()) / len(daily_totals)
    logger.debug("14-day average for center_id=%s: %.2f litres", center_id, avg_14day)

    if avg_14day == 0.0:
        logger.warning(
            "14-day average is zero for center_id=%s; skipping anomaly detection",
            center_id,
        )
        deviation_pct = 0.0
        return {
            "is_anomaly": False,
            "anomaly_type": None,
            "severity": None,
            "today_litres": today_litres,
            "avg_14day": avg_14day,
            "deviation_pct": deviation_pct,
        }

    deviation_pct = round(((today_litres - avg_14day) / avg_14day) * 100, 2)
    logger.debug(
        "Deviation: today_litres=%.2f, avg_14day=%.2f, deviation_pct=%.2f%%",
        today_litres,
        avg_14day,
        deviation_pct,
    )

    # Classify anomaly
    is_anomaly = False
    anomaly_type: str | None = None
    severity: str | None = None

    if today_litres < avg_14day * 0.3:
        is_anomaly = True
        anomaly_type = "critical_low"
        severity = "critical"
        logger.warning(
            "CRITICAL anomaly detected for center_id=%s: today=%.2f < 30%% of avg=%.2f",
            center_id,
            today_litres,
            avg_14day,
        )
    elif today_litres < avg_14day * 0.6:
        is_anomaly = True
        anomaly_type = "low"
        severity = "warning"
        logger.warning(
            "Low anomaly detected for center_id=%s: today=%.2f < 60%% of avg=%.2f",
            center_id,
            today_litres,
            avg_14day,
        )
    elif today_litres > avg_14day * 1.5:
        is_anomaly = True
        anomaly_type = "high"
        severity = "info"
        logger.info(
            "High anomaly detected for center_id=%s: today=%.2f > 150%% of avg=%.2f",
            center_id,
            today_litres,
            avg_14day,
        )
    else:
        logger.info(
            "No anomaly detected for center_id=%s: today=%.2f within normal range of avg=%.2f",
            center_id,
            today_litres,
            avg_14day,
        )

    return {
        "is_anomaly": is_anomaly,
        "anomaly_type": anomaly_type,
        "severity": severity,
        "today_litres": today_litres,
        "avg_14day": round(avg_14day, 2),
        "deviation_pct": deviation_pct,
    }


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate the great-circle distance in kilometres between two points.

    Uses the haversine formula.

    Args:
        lat1: Latitude of point 1 in decimal degrees.
        lng1: Longitude of point 1 in decimal degrees.
        lat2: Latitude of point 2 in decimal degrees.
        lng2: Longitude of point 2 in decimal degrees.

    Returns:
        Distance in kilometres.
    """
    earth_radius_km = 6371.0

    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)

    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(d_lng / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return earth_radius_km * c


def optimize_route(centers: list[dict]) -> list[dict]:
    """Optimize the collection route using nearest-neighbour heuristic.

    Starting from the first center in the list, always visits the nearest
    unvisited center next. Returns the ordered route with the distance from
    the previous stop appended to each entry.

    Args:
        centers: List of dicts, each containing "id", "lat", and "lng".

    Returns:
        Ordered list of center dicts with an additional "distance_km" key
        representing the distance from the previous stop (0.0 for the first).
    """
    logger.info("Starting route optimization for %d centers", len(centers))

    if not centers:
        logger.warning("No centers provided; returning empty route")
        return []

    if len(centers) == 1:
        logger.info("Only one center; returning it as the sole stop")
        result = dict(centers[0])
        result["distance_km"] = 0.0
        return [result]

    unvisited = list(centers)
    current = unvisited.pop(0)

    route: list[dict] = []
    first_stop = dict(current)
    first_stop["distance_km"] = 0.0
    route.append(first_stop)

    logger.debug(
        "Route start: id=%s, lat=%.6f, lng=%.6f",
        current.get("id"),
        current.get("lat", 0.0),
        current.get("lng", 0.0),
    )

    while unvisited:
        nearest_index = -1
        nearest_distance = math.inf

        for idx, candidate in enumerate(unvisited):
            dist = _haversine_km(
                current["lat"],
                current["lng"],
                candidate["lat"],
                candidate["lng"],
            )
            logger.debug(
                "Distance from id=%s to id=%s: %.3f km",
                current.get("id"),
                candidate.get("id"),
                dist,
            )
            if dist < nearest_distance:
                nearest_distance = dist
                nearest_index = idx

        next_center = unvisited.pop(nearest_index)
        stop = dict(next_center)
        stop["distance_km"] = round(nearest_distance, 3)

        logger.debug(
            "Next stop: id=%s, distance_km=%.3f",
            next_center.get("id"),
            nearest_distance,
        )

        route.append(stop)
        current = next_center

    total_distance = sum(stop["distance_km"] for stop in route)
    logger.info(
        "Route optimization complete: %d stops, total distance=%.3f km",
        len(route),
        total_distance,
    )

    return route
