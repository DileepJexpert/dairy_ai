import logging
from typing import Optional

import httpx

from app.config import get_settings

logger = logging.getLogger("dairy_ai.integrations.pashudhan")

# Default base URL for Pashudhan Sanjivani / INAPH API.
# Override via PASHUDHAN_API_URL env var in settings.
DEFAULT_BASE_URL = "https://inaph.gov.in/api/v1"


class PashudhanClient:
    """Integration with Pashudhan Sanjivani / INAPH (Information Network for
    Animal Productivity and Health) for cattle registration, vaccination
    reporting, AI event reporting, and disease outbreak reporting.

    The actual INAPH API is not publicly documented. This client provides a
    well-structured interface with realistic endpoints that can be configured
    once official API access is available.
    """

    @staticmethod
    def _get_base_url() -> str:
        """Return the Pashudhan API base URL from settings or default."""
        settings = get_settings()
        url = getattr(settings, "PASHUDHAN_API_URL", "") or DEFAULT_BASE_URL
        return url.rstrip("/")

    @staticmethod
    def _get_headers() -> dict[str, str]:
        """Return request headers with API key authentication."""
        settings = get_settings()
        api_key = getattr(settings, "PASHUDHAN_API_KEY", "") or ""
        headers: dict[str, str] = {
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        if api_key:
            headers["X-API-Key"] = api_key
        return headers

    @staticmethod
    async def register_cattle(
        owner_name: str,
        owner_phone: str,
        cattle_details: dict,
    ) -> Optional[dict]:
        """Register cattle with the national database and obtain a Pashu Aadhaar
        (12-digit ear tag UID).

        Args:
            owner_name: Full name of the cattle owner.
            owner_phone: Owner's phone number.
            cattle_details: Dict containing cattle information:
                - species: 'bovine' or 'bubaline'
                - breed: Breed name (e.g. 'Gir', 'Murrah')
                - sex: 'male' or 'female'
                - dob: Date of birth (ISO format string)
                - color: Coat color description
                - village: Village name
                - district: District name
                - state: State name
                - lat: Latitude (optional)
                - lng: Longitude (optional)

        Returns:
            Registration result dict with 'uid' (12-digit tag number),
            'registration_id', 'status', etc., or None on failure.
        """
        logger.info(
            "Registering cattle: owner=%s, phone=%s, breed=%s, species=%s",
            owner_name, owner_phone,
            cattle_details.get("breed", "unknown"),
            cattle_details.get("species", "unknown"),
        )

        base_url = PashudhanClient._get_base_url()
        headers = PashudhanClient._get_headers()

        payload = {
            "owner": {
                "name": owner_name,
                "phone": owner_phone,
            },
            "animal": {
                "species": cattle_details.get("species", "bovine"),
                "breed": cattle_details.get("breed", ""),
                "sex": cattle_details.get("sex", ""),
                "dob": cattle_details.get("dob", ""),
                "color": cattle_details.get("color", ""),
            },
            "location": {
                "village": cattle_details.get("village", ""),
                "district": cattle_details.get("district", ""),
                "state": cattle_details.get("state", ""),
                "latitude": cattle_details.get("lat"),
                "longitude": cattle_details.get("lng"),
            },
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{base_url}/animals/register",
                    headers=headers,
                    json=payload,
                )
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Pashudhan register_cattle error: status=%d, body=%s",
                        response.status_code, result,
                    )
                    return None
                logger.info(
                    "Cattle registered: uid=%s, registration_id=%s",
                    result.get("uid"), result.get("registration_id"),
                )
                return result
        except Exception as e:
            logger.exception("Exception registering cattle: %s", e)
            return None

    @staticmethod
    async def fetch_cattle_by_uid(uid: str) -> Optional[dict]:
        """Fetch cattle details from the national database by Pashu Aadhaar UID.

        Args:
            uid: 12-digit ear tag number (Pashu Aadhaar).

        Returns:
            Cattle details dict with owner info, health history, breed details,
            etc., or None on failure.
        """
        logger.info("Fetching cattle by UID: uid=%s", uid)

        base_url = PashudhanClient._get_base_url()
        headers = PashudhanClient._get_headers()

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{base_url}/animals/{uid}",
                    headers=headers,
                )
                if response.status_code == 404:
                    logger.warning("Cattle not found in national DB: uid=%s", uid)
                    return None
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Pashudhan fetch_cattle error: status=%d, uid=%s, body=%s",
                        response.status_code, uid, result,
                    )
                    return None
                logger.info(
                    "Cattle fetched: uid=%s, breed=%s, owner=%s",
                    uid, result.get("breed", ""), result.get("owner_name", ""),
                )
                return result
        except Exception as e:
            logger.exception("Exception fetching cattle uid=%s: %s", uid, e)
            return None

    @staticmethod
    async def report_vaccination(
        uid: str,
        vaccine_name: str,
        date: str,
        administered_by: str,
        batch_no: str,
    ) -> Optional[dict]:
        """Report a vaccination event to the national database.

        Args:
            uid: 12-digit Pashu Aadhaar of the vaccinated animal.
            vaccine_name: Name of the vaccine (e.g. 'FMD', 'Brucella', 'HS-BQ').
            date: Date of vaccination (ISO format, e.g. '2026-03-28').
            administered_by: Name or ID of the person who administered the vaccine.
            batch_no: Vaccine batch/lot number for traceability.

        Returns:
            Confirmation dict with 'event_id', 'status', etc., or None on failure.
        """
        logger.info(
            "Reporting vaccination: uid=%s, vaccine=%s, date=%s, batch=%s",
            uid, vaccine_name, date, batch_no,
        )

        base_url = PashudhanClient._get_base_url()
        headers = PashudhanClient._get_headers()

        payload = {
            "animal_uid": uid,
            "event_type": "vaccination",
            "vaccine_name": vaccine_name,
            "date": date,
            "administered_by": administered_by,
            "batch_no": batch_no,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{base_url}/animals/{uid}/vaccinations",
                    headers=headers,
                    json=payload,
                )
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Pashudhan report_vaccination error: status=%d, uid=%s, body=%s",
                        response.status_code, uid, result,
                    )
                    return None
                logger.info(
                    "Vaccination reported: uid=%s, vaccine=%s, event_id=%s",
                    uid, vaccine_name, result.get("event_id"),
                )
                return result
        except Exception as e:
            logger.exception(
                "Exception reporting vaccination for uid=%s: %s", uid, e,
            )
            return None

    @staticmethod
    async def report_ai_event(
        uid: str,
        semen_bull_id: str,
        ai_tech_name: str,
        date: str,
    ) -> Optional[dict]:
        """Report an artificial insemination (AI) event to the national database.

        Args:
            uid: 12-digit Pashu Aadhaar of the inseminated animal.
            semen_bull_id: Bull ID / semen straw identification number.
            ai_tech_name: Name or ID of the AI technician.
            date: Date of AI event (ISO format, e.g. '2026-03-28').

        Returns:
            Confirmation dict with 'event_id', 'status', etc., or None on failure.
        """
        logger.info(
            "Reporting AI event: uid=%s, bull_id=%s, tech=%s, date=%s",
            uid, semen_bull_id, ai_tech_name, date,
        )

        base_url = PashudhanClient._get_base_url()
        headers = PashudhanClient._get_headers()

        payload = {
            "animal_uid": uid,
            "event_type": "artificial_insemination",
            "semen_bull_id": semen_bull_id,
            "ai_technician": ai_tech_name,
            "date": date,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{base_url}/animals/{uid}/breeding",
                    headers=headers,
                    json=payload,
                )
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Pashudhan report_ai_event error: status=%d, uid=%s, body=%s",
                        response.status_code, uid, result,
                    )
                    return None
                logger.info(
                    "AI event reported: uid=%s, bull_id=%s, event_id=%s",
                    uid, semen_bull_id, result.get("event_id"),
                )
                return result
        except Exception as e:
            logger.exception(
                "Exception reporting AI event for uid=%s: %s", uid, e,
            )
            return None

    @staticmethod
    async def report_disease(
        uid: str,
        disease_name: str,
        symptoms: list[str],
        location_lat: Optional[float] = None,
        location_lng: Optional[float] = None,
    ) -> Optional[dict]:
        """Report a disease / outbreak event to the national surveillance system.

        Args:
            uid: 12-digit Pashu Aadhaar of the affected animal.
            disease_name: Name or suspected name of the disease (e.g. 'FMD',
                'Lumpy Skin Disease', 'Mastitis').
            symptoms: List of observed symptom descriptions.
            location_lat: Latitude of the animal's location (for outbreak mapping).
            location_lng: Longitude of the animal's location.

        Returns:
            Confirmation dict with 'report_id', 'status', etc., or None on failure.
        """
        logger.info(
            "Reporting disease: uid=%s, disease=%s, symptoms_count=%d, lat=%s, lng=%s",
            uid, disease_name, len(symptoms), location_lat, location_lng,
        )

        base_url = PashudhanClient._get_base_url()
        headers = PashudhanClient._get_headers()

        payload: dict = {
            "animal_uid": uid,
            "event_type": "disease_report",
            "disease_name": disease_name,
            "symptoms": symptoms,
        }
        if location_lat is not None and location_lng is not None:
            payload["location"] = {
                "latitude": location_lat,
                "longitude": location_lng,
            }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{base_url}/disease-reports",
                    headers=headers,
                    json=payload,
                )
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Pashudhan report_disease error: status=%d, uid=%s, body=%s",
                        response.status_code, uid, result,
                    )
                    return None
                logger.info(
                    "Disease reported: uid=%s, disease=%s, report_id=%s",
                    uid, disease_name, result.get("report_id"),
                )
                return result
        except Exception as e:
            logger.exception(
                "Exception reporting disease for uid=%s: %s", uid, e,
            )
            return None

    @staticmethod
    async def get_cattle_history(uid: str) -> Optional[dict]:
        """Fetch the complete health and breeding history for an animal from the
        national database.

        Args:
            uid: 12-digit Pashu Aadhaar of the animal.

        Returns:
            Dict containing 'vaccinations', 'treatments', 'breeding_events',
            'disease_reports', and 'calvings' lists, or None on failure.
        """
        logger.info("Fetching cattle history: uid=%s", uid)

        base_url = PashudhanClient._get_base_url()
        headers = PashudhanClient._get_headers()

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{base_url}/animals/{uid}/history",
                    headers=headers,
                )
                if response.status_code == 404:
                    logger.warning(
                        "No history found for cattle: uid=%s", uid,
                    )
                    return None
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Pashudhan get_cattle_history error: status=%d, uid=%s, body=%s",
                        response.status_code, uid, result,
                    )
                    return None

                vacc_count = len(result.get("vaccinations", []))
                breed_count = len(result.get("breeding_events", []))
                disease_count = len(result.get("disease_reports", []))
                logger.info(
                    "Cattle history fetched: uid=%s, vaccinations=%d, breeding=%d, diseases=%d",
                    uid, vacc_count, breed_count, disease_count,
                )
                return result
        except Exception as e:
            logger.exception(
                "Exception fetching cattle history for uid=%s: %s", uid, e,
            )
            return None
