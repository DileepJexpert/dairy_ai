import uuid
from datetime import datetime, timedelta, timezone

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.cattle import Cattle, Breed, Sex, CattleStatus
from app.models.vet import VetProfile, Consultation, Prescription, ConsultationStatus  # noqa: F401 — register models
from app.services.auth_service import create_access_token, hash_otp


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def vet_user(db_session: AsyncSession) -> User:
    user = User(
        id=uuid.uuid4(),
        phone="9999900010",
        role=UserRole.vet,
        is_active=True,
        otp_hash=hash_otp("123456"),
        otp_expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
    )
    db_session.add(user)
    await db_session.flush()
    return user


@pytest_asyncio.fixture
async def vet_headers(vet_user: User) -> dict[str, str]:
    token = create_access_token(str(vet_user.id), vet_user.role.value)
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def vet_profile(db_session: AsyncSession, vet_user: User) -> VetProfile:
    """A verified, available vet profile."""
    vet = VetProfile(
        id=uuid.uuid4(),
        user_id=vet_user.id,
        license_number="VET-12345",
        qualification="bvsc",
        specializations=["cattle", "dairy"],
        experience_years=5,
        languages=["hi", "en"],
        consultation_fee=500.0,
        is_verified=True,
        is_available=True,
    )
    db_session.add(vet)
    await db_session.flush()
    return vet


@pytest_asyncio.fixture
async def farmer_user(db_session: AsyncSession) -> User:
    user = User(
        id=uuid.uuid4(),
        phone="9999900020",
        role=UserRole.farmer,
        is_active=True,
        otp_hash=hash_otp("123456"),
        otp_expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
    )
    db_session.add(user)
    await db_session.flush()
    return user


@pytest_asyncio.fixture
async def farmer_headers(farmer_user: User) -> dict[str, str]:
    token = create_access_token(str(farmer_user.id), farmer_user.role.value)
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def farmer_profile(db_session: AsyncSession, farmer_user: User) -> Farmer:
    farmer = Farmer(
        id=uuid.uuid4(),
        user_id=farmer_user.id,
        name="Test Farmer",
        village="TestVillage",
        district="TestDistrict",
        state="TestState",
        language="hi",
    )
    db_session.add(farmer)
    await db_session.flush()
    return farmer


@pytest_asyncio.fixture
async def cattle(db_session: AsyncSession, farmer_profile: Farmer) -> Cattle:
    c = Cattle(
        id=uuid.uuid4(),
        farmer_id=farmer_profile.id,
        tag_id="TAG001",
        name="Lakshmi",
        breed=Breed.gir,
        sex=Sex.female,
        status=CattleStatus.active,
    )
    db_session.add(c)
    await db_session.flush()
    return c


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_vet_registration(client: AsyncClient, vet_user: User, vet_headers: dict):
    """Register a new vet profile — should be unverified."""
    resp = await client.post(
        "/api/v1/vets/register",
        json={
            "license_number": "VET-99999",
            "qualification": "mvsc",
            "specializations": ["cattle"],
            "experience_years": 3,
            "languages": ["hi"],
            "consultation_fee": 300.0,
            "bio": "Experienced dairy vet",
        },
        headers=vet_headers,
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["success"] is True
    assert body["data"]["is_verified"] is False
    assert body["data"]["license_number"] == "VET-99999"


@pytest.mark.asyncio
async def test_vet_search_available(
    client: AsyncClient,
    vet_profile: VetProfile,
    farmer_headers: dict,
    farmer_user: User,
    farmer_profile: Farmer,
):
    """Search should return only available and verified vets."""
    resp = await client.get(
        "/api/v1/vets/search?available=true",
        headers=farmer_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["success"] is True
    assert len(body["data"]) >= 1
    for vet in body["data"]:
        assert vet["is_verified"] is True
        assert vet["is_available"] is True


@pytest.mark.asyncio
async def test_request_consultation(
    client: AsyncClient,
    farmer_user: User,
    farmer_headers: dict,
    farmer_profile: Farmer,
    cattle: Cattle,
    vet_profile: VetProfile,
):
    """Farmer requests a consultation — status should be 'requested'."""
    resp = await client.post(
        "/api/v1/consultations",
        json={
            "cattle_id": str(cattle.id),
            "symptoms": "Not eating, low milk yield",
            "consultation_type": "video",
        },
        headers=farmer_headers,
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["success"] is True
    assert body["data"]["status"] == "requested"
    assert body["data"]["symptoms"] == "Not eating, low milk yield"
    assert body["data"]["agora_channel_name"] is not None


@pytest.mark.asyncio
async def test_consultation_lifecycle(
    client: AsyncClient,
    db_session: AsyncSession,
    farmer_user: User,
    farmer_headers: dict,
    farmer_profile: Farmer,
    cattle: Cattle,
    vet_user: User,
    vet_headers: dict,
    vet_profile: VetProfile,
):
    """Full lifecycle: request → accept → start → end → rate."""
    # 1. Farmer requests consultation
    resp = await client.post(
        "/api/v1/consultations",
        json={
            "cattle_id": str(cattle.id),
            "symptoms": "Fever and reduced appetite",
            "consultation_type": "video",
        },
        headers=farmer_headers,
    )
    assert resp.status_code == 201
    consultation_id = resp.json()["data"]["id"]

    # 2. Vet accepts
    resp = await client.put(
        f"/api/v1/consultations/{consultation_id}/accept",
        headers=vet_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["status"] == "assigned"
    assert resp.json()["data"]["vet_id"] == str(vet_profile.id)

    # 3. Vet starts
    resp = await client.put(
        f"/api/v1/consultations/{consultation_id}/start",
        headers=vet_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["status"] == "in_progress"
    assert resp.json()["data"]["started_at"] is not None

    # 4. Vet ends with diagnosis
    resp = await client.put(
        f"/api/v1/consultations/{consultation_id}/end",
        json={
            "vet_diagnosis": "Mastitis — early stage",
            "vet_notes": "Prescribe antibiotics, follow up in 3 days",
        },
        headers=vet_headers,
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["status"] == "completed"
    assert data["vet_diagnosis"] == "Mastitis — early stage"
    assert data["fee_amount"] == 500.0
    assert data["platform_fee"] == 100.0
    assert data["vet_payout"] == 400.0

    # 5. Farmer rates
    resp = await client.put(
        f"/api/v1/consultations/{consultation_id}/rate",
        json={"rating": 5, "review": "Excellent vet!"},
        headers=farmer_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["farmer_rating"] == 5
    assert resp.json()["data"]["farmer_review"] == "Excellent vet!"


@pytest.mark.asyncio
async def test_prescription_creation(
    client: AsyncClient,
    db_session: AsyncSession,
    farmer_user: User,
    farmer_headers: dict,
    farmer_profile: Farmer,
    cattle: Cattle,
    vet_user: User,
    vet_headers: dict,
    vet_profile: VetProfile,
):
    """Create a prescription for a consultation that has a vet assigned."""
    # Request + accept consultation
    resp = await client.post(
        "/api/v1/consultations",
        json={
            "cattle_id": str(cattle.id),
            "symptoms": "Swollen udder",
            "consultation_type": "video",
        },
        headers=farmer_headers,
    )
    consultation_id = resp.json()["data"]["id"]

    await client.put(
        f"/api/v1/consultations/{consultation_id}/accept",
        headers=vet_headers,
    )

    # Create prescription
    resp = await client.post(
        f"/api/v1/consultations/{consultation_id}/prescription",
        json={
            "medicines": [
                {
                    "name": "Ceftriaxone",
                    "dosage": "500mg",
                    "frequency": "twice daily",
                    "duration_days": 5,
                }
            ],
            "instructions": "Administer intramuscularly. Discard milk for 72 hours.",
            "follow_up_date": "2026-04-01",
        },
        headers=vet_headers,
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["success"] is True
    assert len(body["data"]["medicines"]) == 1
    assert body["data"]["medicines"][0]["name"] == "Ceftriaxone"
    assert body["data"]["instructions"] is not None


@pytest.mark.asyncio
async def test_vet_rating_update(
    client: AsyncClient,
    db_session: AsyncSession,
    farmer_user: User,
    farmer_headers: dict,
    farmer_profile: Farmer,
    cattle: Cattle,
    vet_user: User,
    vet_headers: dict,
    vet_profile: VetProfile,
):
    """After rating, vet avg rating should be recalculated."""
    # Create two consultations, rate them differently
    for rating_val, tag_suffix in [(4, "A"), (2, "B")]:
        # Need unique cattle for second iteration — reuse same cattle for simplicity
        resp = await client.post(
            "/api/v1/consultations",
            json={
                "cattle_id": str(cattle.id),
                "symptoms": f"Symptoms {tag_suffix}",
                "consultation_type": "video",
            },
            headers=farmer_headers,
        )
        cid = resp.json()["data"]["id"]

        await client.put(f"/api/v1/consultations/{cid}/accept", headers=vet_headers)
        await client.put(f"/api/v1/consultations/{cid}/start", headers=vet_headers)
        await client.put(
            f"/api/v1/consultations/{cid}/end",
            json={"vet_diagnosis": "Diagnosis", "vet_notes": "Notes"},
            headers=vet_headers,
        )
        await client.put(
            f"/api/v1/consultations/{cid}/rate",
            json={"rating": rating_val},
            headers=farmer_headers,
        )

    # Check vet dashboard for updated rating
    resp = await client.get("/api/v1/vets/me/dashboard", headers=vet_headers)
    assert resp.status_code == 200
    dashboard = resp.json()["data"]
    # Average of 4 and 2 = 3.0
    assert dashboard["rating_avg"] == 3.0
    assert dashboard["total_consultations"] == 2


@pytest.mark.asyncio
async def test_farmer_cannot_access_vet_routes(
    client: AsyncClient,
    farmer_user: User,
    farmer_headers: dict,
    farmer_profile: Farmer,
):
    """Farmer trying vet-only routes should get 403."""
    # Try to register as vet
    resp = await client.post(
        "/api/v1/vets/register",
        json={
            "license_number": "FAKE-001",
            "qualification": "bvsc",
            "specializations": [],
            "experience_years": 0,
            "languages": ["hi"],
            "consultation_fee": 100.0,
        },
        headers=farmer_headers,
    )
    assert resp.status_code == 403

    # Try to access vet dashboard
    resp = await client.get("/api/v1/vets/me/dashboard", headers=farmer_headers)
    assert resp.status_code == 403

    # Try to access vet queue
    resp = await client.get("/api/v1/consultations/queue", headers=farmer_headers)
    assert resp.status_code == 403
