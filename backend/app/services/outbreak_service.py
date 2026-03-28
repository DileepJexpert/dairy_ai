import logging
import uuid
import math
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select, func, and_, extract
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.outbreak import (
    DiseaseReport, OutbreakZone,
    ReportSeverity, ReportSource, ReportStatus, OutbreakSeverityLevel,
)

logger = logging.getLogger("dairy_ai.services.outbreak")

# Earth radius in km for Haversine calculation
EARTH_RADIUS_KM = 6371.0

# Cluster detection thresholds
CLUSTER_MIN_REPORTS = 3
CLUSTER_RADIUS_KM = 25.0


def _haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate distance in km between two geographic points using Haversine formula."""
    lat1_r, lat2_r = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlng / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return EARTH_RADIUS_KM * c


def _determine_severity_level(report_count: int) -> OutbreakSeverityLevel:
    """Determine outbreak severity level based on number of reports."""
    if report_count >= 20:
        return OutbreakSeverityLevel.critical
    elif report_count >= 10:
        return OutbreakSeverityLevel.alert
    elif report_count >= 5:
        return OutbreakSeverityLevel.warning
    return OutbreakSeverityLevel.watch


def _generate_advisory(disease_name: str, severity_level: OutbreakSeverityLevel) -> str:
    """Generate advisory text based on disease and severity."""
    base_advisories = {
        OutbreakSeverityLevel.watch: (
            f"Scattered reports of {disease_name} in your area. "
            "Monitor your cattle for symptoms. Maintain hygiene and biosecurity measures."
        ),
        OutbreakSeverityLevel.warning: (
            f"Multiple reports of {disease_name} nearby. "
            "Isolate any symptomatic cattle immediately. Contact your veterinarian for preventive measures. "
            "Restrict cattle movement to and from your farm."
        ),
        OutbreakSeverityLevel.alert: (
            f"Significant outbreak of {disease_name} in your area. "
            "Vaccinate unaffected cattle if available. Strict quarantine for symptomatic animals. "
            "Report any new cases immediately. Do not sell or transport cattle until cleared."
        ),
        OutbreakSeverityLevel.critical: (
            f"CRITICAL: Major {disease_name} outbreak. "
            "All cattle movements must be halted. Contact district veterinary officer immediately. "
            "Implement full biosecurity protocols. Disinfect all equipment and facilities. "
            "Do not consume or sell milk from affected animals without testing."
        ),
    }
    return base_advisories.get(severity_level, "Monitor your cattle and maintain hygiene.")


async def report_disease(
    db: AsyncSession,
    farmer_id: uuid.UUID,
    data: dict,
) -> DiseaseReport:
    """Create a disease report and check if a cluster forms."""
    logger.info(f"report_disease called | farmer_id={farmer_id} | disease={data.get('disease_name')}")

    report = DiseaseReport(
        farmer_id=farmer_id,
        cattle_id=data.get("cattle_id"),
        disease_name=data["disease_name"],
        symptoms=data.get("symptoms"),
        severity=data["severity"],
        lat=data["lat"],
        lng=data["lng"],
        village=data.get("village"),
        district=data.get("district"),
        state=data.get("state"),
        source=data.get("source", ReportSource.farmer_report),
        status=ReportStatus.reported,
        reported_at=datetime.now(timezone.utc),
    )
    db.add(report)
    await db.flush()
    logger.info(f"Disease report created | report_id={report.id} | disease={report.disease_name}")

    # Check if this report triggers a new cluster
    logger.debug(f"Checking for cluster formation | disease={report.disease_name}")
    await detect_clusters(db, report.disease_name, days=14)

    return report


async def get_outbreak_map(
    db: AsyncSession,
    state: Optional[str] = None,
    district: Optional[str] = None,
    radius_km: float = 50.0,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
) -> dict:
    """Return active outbreak zones and recent reports for map display."""
    logger.info(f"get_outbreak_map called | state={state} | district={district} | radius_km={radius_km}")

    # Fetch active outbreak zones
    zone_query = select(OutbreakZone).where(OutbreakZone.is_active == True)  # noqa: E712
    if state:
        zone_query = zone_query.where(OutbreakZone.state == state)
    if district:
        zone_query = zone_query.where(OutbreakZone.district == district)

    result = await db.execute(zone_query)
    zones = list(result.scalars().all())

    # Filter by geographic proximity if coordinates provided
    if lat is not None and lng is not None:
        zones = [
            z for z in zones
            if _haversine_distance(lat, lng, z.center_lat, z.center_lng) <= radius_km
        ]

    # Fetch recent reports (last 30 days)
    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    report_query = select(DiseaseReport).where(
        DiseaseReport.reported_at >= cutoff
    ).order_by(DiseaseReport.reported_at.desc()).limit(200)

    if state:
        report_query = report_query.where(DiseaseReport.state == state)
    if district:
        report_query = report_query.where(DiseaseReport.district == district)

    result = await db.execute(report_query)
    reports = list(result.scalars().all())

    if lat is not None and lng is not None:
        reports = [
            r for r in reports
            if _haversine_distance(lat, lng, r.lat, r.lng) <= radius_km
        ]

    logger.info(f"Outbreak map data | zones={len(zones)} | reports={len(reports)}")

    return {
        "zones": [
            {
                "id": str(z.id),
                "disease_name": z.disease_name,
                "center_lat": z.center_lat,
                "center_lng": z.center_lng,
                "radius_km": z.radius_km,
                "district": z.district,
                "state": z.state,
                "report_count": z.report_count,
                "severity_level": z.severity_level.value,
                "first_reported": str(z.first_reported),
                "last_reported": str(z.last_reported),
                "advisory": z.advisory,
            }
            for z in zones
        ],
        "reports": [
            {
                "id": str(r.id),
                "disease_name": r.disease_name,
                "severity": r.severity.value,
                "lat": r.lat,
                "lng": r.lng,
                "village": r.village,
                "district": r.district,
                "status": r.status.value,
                "source": r.source.value,
                "is_confirmed": r.is_confirmed,
                "reported_at": str(r.reported_at),
            }
            for r in reports
        ],
    }


async def detect_clusters(
    db: AsyncSession,
    disease_name: str,
    days: int = 14,
) -> list[dict]:
    """Find geographic clusters of same disease within time window.

    More than 3 reports within 25km radius = outbreak zone.
    Updates existing zones or creates new ones.
    """
    logger.info(f"detect_clusters called | disease={disease_name} | days={days}")

    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    query = select(DiseaseReport).where(
        and_(
            DiseaseReport.disease_name == disease_name,
            DiseaseReport.reported_at >= cutoff,
            DiseaseReport.status != ReportStatus.resolved,
        )
    )
    result = await db.execute(query)
    reports = list(result.scalars().all())

    logger.debug(f"Found {len(reports)} recent reports for {disease_name}")

    if len(reports) < CLUSTER_MIN_REPORTS:
        logger.debug(f"Not enough reports ({len(reports)}) to form a cluster")
        return []

    # Simple clustering: for each report, check how many others are within CLUSTER_RADIUS_KM
    clusters_found = []
    used_report_ids: set[uuid.UUID] = set()

    for i, report in enumerate(reports):
        if report.id in used_report_ids:
            continue

        nearby = [report]
        for j, other in enumerate(reports):
            if i == j or other.id in used_report_ids:
                continue
            dist = _haversine_distance(report.lat, report.lng, other.lat, other.lng)
            if dist <= CLUSTER_RADIUS_KM:
                nearby.append(other)

        if len(nearby) >= CLUSTER_MIN_REPORTS:
            # Calculate cluster center (centroid)
            center_lat = sum(r.lat for r in nearby) / len(nearby)
            center_lng = sum(r.lng for r in nearby) / len(nearby)

            # Calculate radius that covers all reports
            max_dist = max(
                _haversine_distance(center_lat, center_lng, r.lat, r.lng)
                for r in nearby
            )
            cluster_radius = max(max_dist * 1.2, 5.0)  # At least 5km, 20% buffer

            report_count = len(nearby)
            severity_level = _determine_severity_level(report_count)
            advisory = _generate_advisory(disease_name, severity_level)

            # Determine district/state from most common values
            districts = [r.district for r in nearby if r.district]
            states = [r.state for r in nearby if r.state]
            district = max(set(districts), key=districts.count) if districts else None
            state = max(set(states), key=states.count) if states else None

            first_reported = min(r.reported_at for r in nearby)
            last_reported = max(r.reported_at for r in nearby)

            # Check if there's an existing active zone for this disease in this area
            existing_query = select(OutbreakZone).where(
                and_(
                    OutbreakZone.disease_name == disease_name,
                    OutbreakZone.is_active == True,  # noqa: E712
                )
            )
            existing_result = await db.execute(existing_query)
            existing_zones = list(existing_result.scalars().all())

            updated_existing = False
            for zone in existing_zones:
                dist_to_center = _haversine_distance(
                    center_lat, center_lng, zone.center_lat, zone.center_lng
                )
                if dist_to_center <= CLUSTER_RADIUS_KM:
                    # Update existing zone
                    zone.center_lat = center_lat
                    zone.center_lng = center_lng
                    zone.radius_km = cluster_radius
                    zone.report_count = report_count
                    zone.severity_level = severity_level
                    zone.last_reported = last_reported
                    zone.advisory = advisory
                    zone.district = district
                    zone.state = state
                    await db.flush()
                    logger.info(f"Updated existing outbreak zone | zone_id={zone.id} | reports={report_count}")
                    updated_existing = True
                    break

            if not updated_existing:
                new_zone = OutbreakZone(
                    disease_name=disease_name,
                    center_lat=center_lat,
                    center_lng=center_lng,
                    radius_km=cluster_radius,
                    district=district,
                    state=state,
                    report_count=report_count,
                    severity_level=severity_level,
                    first_reported=first_reported,
                    last_reported=last_reported,
                    is_active=True,
                    advisory=advisory,
                )
                db.add(new_zone)
                await db.flush()
                logger.info(f"Created new outbreak zone | zone_id={new_zone.id} | disease={disease_name} | reports={report_count}")

            for r in nearby:
                used_report_ids.add(r.id)

            clusters_found.append({
                "disease_name": disease_name,
                "center_lat": center_lat,
                "center_lng": center_lng,
                "radius_km": cluster_radius,
                "report_count": report_count,
                "severity_level": severity_level.value,
            })

    logger.info(f"Cluster detection complete | disease={disease_name} | clusters_found={len(clusters_found)}")
    return clusters_found


async def get_nearby_alerts(
    db: AsyncSession,
    lat: float,
    lng: float,
    radius_km: float = 30.0,
) -> list[dict]:
    """Get active outbreak alerts near a farmer's location."""
    logger.info(f"get_nearby_alerts called | lat={lat} | lng={lng} | radius_km={radius_km}")

    query = select(OutbreakZone).where(OutbreakZone.is_active == True)  # noqa: E712
    result = await db.execute(query)
    zones = list(result.scalars().all())

    nearby = []
    for zone in zones:
        dist = _haversine_distance(lat, lng, zone.center_lat, zone.center_lng)
        if dist <= radius_km + zone.radius_km:
            nearby.append({
                "id": str(zone.id),
                "disease_name": zone.disease_name,
                "distance_km": round(dist, 1),
                "severity_level": zone.severity_level.value,
                "report_count": zone.report_count,
                "advisory": zone.advisory,
                "center_lat": zone.center_lat,
                "center_lng": zone.center_lng,
                "radius_km": zone.radius_km,
                "last_reported": str(zone.last_reported),
            })

    nearby.sort(key=lambda x: x["distance_km"])
    logger.info(f"Nearby alerts found | count={len(nearby)}")
    return nearby


async def update_report_status(
    db: AsyncSession,
    report_id: uuid.UUID,
    status: ReportStatus,
    confirmed_by: Optional[str] = None,
) -> DiseaseReport:
    """Vet or admin confirms/updates a disease report."""
    logger.info(f"update_report_status called | report_id={report_id} | status={status}")

    query = select(DiseaseReport).where(DiseaseReport.id == report_id)
    result = await db.execute(query)
    report = result.scalar_one_or_none()

    if not report:
        logger.warning(f"Disease report not found | report_id={report_id}")
        raise ValueError(f"Disease report {report_id} not found")

    report.status = status
    if status == ReportStatus.confirmed:
        report.is_confirmed = True
        report.confirmed_by = confirmed_by
    elif status == ReportStatus.resolved:
        report.resolved_at = datetime.now(timezone.utc)

    await db.flush()
    logger.info(f"Report status updated | report_id={report_id} | new_status={status.value}")
    return report


async def get_disease_trends(
    db: AsyncSession,
    district: str,
    months: int = 6,
) -> list[dict]:
    """Get monthly disease counts for a district for trending analysis."""
    logger.info(f"get_disease_trends called | district={district} | months={months}")

    cutoff = datetime.now(timezone.utc) - timedelta(days=months * 30)

    query = (
        select(
            DiseaseReport.disease_name,
            extract("year", DiseaseReport.reported_at).label("year"),
            extract("month", DiseaseReport.reported_at).label("month"),
            func.count(DiseaseReport.id).label("count"),
        )
        .where(
            and_(
                DiseaseReport.district == district,
                DiseaseReport.reported_at >= cutoff,
            )
        )
        .group_by(
            DiseaseReport.disease_name,
            extract("year", DiseaseReport.reported_at),
            extract("month", DiseaseReport.reported_at),
        )
        .order_by(
            extract("year", DiseaseReport.reported_at),
            extract("month", DiseaseReport.reported_at),
        )
    )
    result = await db.execute(query)
    rows = result.all()

    trends = [
        {
            "disease_name": row.disease_name,
            "year": int(row.year),
            "month": int(row.month),
            "count": row.count,
        }
        for row in rows
    ]

    logger.info(f"Disease trends retrieved | district={district} | data_points={len(trends)}")
    return trends
