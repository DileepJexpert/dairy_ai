"""Tests for location-based vet search, distance sorting, fee filtering."""
import uuid
from datetime import datetime, timedelta, timezone

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.vet import VetProfile
from app.services.auth_service import create_access_token, hash_otp
from app.repositories.vet_repo import haversine_distance


# ---------------------------------------------------------------------------
# Fixtures: create vets at known locations
# ---------------------------------------------------------------------------

# Jaipur: 26.9124, 75.7873
# Ajmer: 26.4499, 74.6399  (~120 km from Jaipur)
# Udaipur: 24.5854, 73.7125 (~260 km from Jaipur)
# Jodhpur: 26.2389, 73.0243 (~280 km from Jaipur)
# Near Jaipur (Amber): 26.9855, 75.8513 (~10 km from Jaipur)


@pytest_asyncio.fixture
async def farmer_for_search(db_session: AsyncSession) -> User:
    user = User(
        id=uuid.uuid4(),
        phone="9999950001",
        role=UserRole.farmer,
        is_active=True,
    )
    db_session.add(user)
    await db_session.flush()
    return user


@pytest_asyncio.fixture
async def farmer_search_headers(farmer_for_search: User) -> dict:
    token = create_access_token(str(farmer_for_search.id), farmer_for_search.role.value)
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def vet_jaipur(db_session: AsyncSession) -> VetProfile:
    user = User(id=uuid.uuid4(), phone="9999960001", role=UserRole.vet, is_active=True)
    db_session.add(user)
    await db_session.flush()
    vet = VetProfile(
        id=uuid.uuid4(),
        user_id=user.id,
        license_number="VET-JP-001",
        qualification="bvsc",
        specializations=["cattle", "dairy"],
        languages=["hi", "en"],
        consultation_fee=300.0,
        is_verified=True,
        is_available=True,
        pincode="302001",
        city="Jaipur",
        district="Jaipur",
        state="Rajasthan",
        lat=26.9124,
        lng=75.7873,
    )
    db_session.add(vet)
    await db_session.flush()
    return vet


@pytest_asyncio.fixture
async def vet_amber(db_session: AsyncSession) -> VetProfile:
    """Near Jaipur — ~10 km away."""
    user = User(id=uuid.uuid4(), phone="9999960002", role=UserRole.vet, is_active=True)
    db_session.add(user)
    await db_session.flush()
    vet = VetProfile(
        id=uuid.uuid4(),
        user_id=user.id,
        license_number="VET-AMB-001",
        qualification="mvsc",
        specializations=["cattle"],
        languages=["hi"],
        consultation_fee=200.0,
        is_verified=True,
        is_available=True,
        pincode="302028",
        city="Amber",
        district="Jaipur",
        state="Rajasthan",
        lat=26.9855,
        lng=75.8513,
    )
    db_session.add(vet)
    await db_session.flush()
    return vet


@pytest_asyncio.fixture
async def vet_ajmer(db_session: AsyncSession) -> VetProfile:
    """~120 km from Jaipur."""
    user = User(id=uuid.uuid4(), phone="9999960003", role=UserRole.vet, is_active=True)
    db_session.add(user)
    await db_session.flush()
    vet = VetProfile(
        id=uuid.uuid4(),
        user_id=user.id,
        license_number="VET-AJM-001",
        qualification="bvsc",
        specializations=["cattle", "poultry"],
        languages=["hi"],
        consultation_fee=500.0,
        is_verified=True,
        is_available=True,
        pincode="305001",
        city="Ajmer",
        district="Ajmer",
        state="Rajasthan",
        lat=26.4499,
        lng=74.6399,
    )
    db_session.add(vet)
    await db_session.flush()
    return vet


@pytest_asyncio.fixture
async def vet_udaipur_unavailable(db_session: AsyncSession) -> VetProfile:
    """Far away and unavailable."""
    user = User(id=uuid.uuid4(), phone="9999960004", role=UserRole.vet, is_active=True)
    db_session.add(user)
    await db_session.flush()
    vet = VetProfile(
        id=uuid.uuid4(),
        user_id=user.id,
        license_number="VET-UDP-001",
        qualification="phd",
        specializations=["cattle"],
        languages=["hi", "en"],
        consultation_fee=800.0,
        is_verified=True,
        is_available=False,
        pincode="313001",
        city="Udaipur",
        district="Udaipur",
        state="Rajasthan",
        lat=24.5854,
        lng=73.7125,
    )
    db_session.add(vet)
    await db_session.flush()
    return vet


# ---------------------------------------------------------------------------
# Tests: Haversine distance calculation
# ---------------------------------------------------------------------------

class TestHaversineDistance:
    def test_same_point_zero_distance(self):
        d = haversine_distance(26.9124, 75.7873, 26.9124, 75.7873)
        assert d == 0.0

    def test_jaipur_to_amber_approx_10km(self):
        d = haversine_distance(26.9124, 75.7873, 26.9855, 75.8513)
        assert 5.0 < d < 15.0  # ~10 km

    def test_jaipur_to_ajmer_approx_120km(self):
        d = haversine_distance(26.9124, 75.7873, 26.4499, 74.6399)
        assert 100.0 < d < 140.0  # ~120 km


# ---------------------------------------------------------------------------
# Tests: Nearby vet search
# ---------------------------------------------------------------------------

class TestNearbyVetSearch:
    @pytest.mark.asyncio
    async def test_search_within_50km(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_amber, vet_ajmer,
    ):
        """Farmer in Jaipur searches 50km radius — should get Jaipur + Amber, not Ajmer."""
        resp = await client.get(
            "/api/v1/vets/search?lat=26.9124&lng=75.7873&max_distance_km=50&sort_by=distance",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 2  # Jaipur + Amber only
        # Should be sorted by distance — Jaipur is closer than Amber
        assert data[0]["city"] == "Jaipur"
        assert data[1]["city"] == "Amber"
        # Distance field present
        assert data[0]["distance_km"] < data[1]["distance_km"]

    @pytest.mark.asyncio
    async def test_search_within_200km_includes_ajmer(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_amber, vet_ajmer,
    ):
        """200km radius from Jaipur includes Ajmer."""
        resp = await client.get(
            "/api/v1/vets/search?lat=26.9124&lng=75.7873&max_distance_km=200",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 3
        cities = [v["city"] for v in data]
        assert "Ajmer" in cities

    @pytest.mark.asyncio
    async def test_search_no_location_returns_all(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_amber, vet_ajmer,
    ):
        """Search without lat/lng returns all verified available vets (no distance filter)."""
        resp = await client.get(
            "/api/v1/vets/search",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 3


# ---------------------------------------------------------------------------
# Tests: Fee-based filtering
# ---------------------------------------------------------------------------

class TestFeeFiltering:
    @pytest.mark.asyncio
    async def test_max_fee_filter(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_amber, vet_ajmer,
    ):
        """Max fee 400 excludes Ajmer vet (₹500)."""
        resp = await client.get(
            "/api/v1/vets/search?max_fee=400",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        fees = [v["consultation_fee"] for v in data]
        assert all(f <= 400 for f in fees)
        assert len(data) == 2

    @pytest.mark.asyncio
    async def test_min_fee_filter(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_amber, vet_ajmer,
    ):
        """Min fee 300 excludes Amber vet (₹200)."""
        resp = await client.get(
            "/api/v1/vets/search?min_fee=300",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        fees = [v["consultation_fee"] for v in data]
        assert all(f >= 300 for f in fees)
        assert len(data) == 2

    @pytest.mark.asyncio
    async def test_fee_range_filter(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_amber, vet_ajmer,
    ):
        """Fee between 250-400 returns only Jaipur vet (₹300)."""
        resp = await client.get(
            "/api/v1/vets/search?min_fee=250&max_fee=400",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 1
        assert data[0]["consultation_fee"] == 300.0


# ---------------------------------------------------------------------------
# Tests: Sorting
# ---------------------------------------------------------------------------

class TestSorting:
    @pytest.mark.asyncio
    async def test_sort_by_fee_low(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_amber, vet_ajmer,
    ):
        resp = await client.get(
            "/api/v1/vets/search?sort_by=fee_low",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        fees = [v["consultation_fee"] for v in data]
        assert fees == sorted(fees)  # ascending

    @pytest.mark.asyncio
    async def test_sort_by_fee_high(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_amber, vet_ajmer,
    ):
        resp = await client.get(
            "/api/v1/vets/search?sort_by=fee_high",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        fees = [v["consultation_fee"] for v in data]
        assert fees == sorted(fees, reverse=True)  # descending


# ---------------------------------------------------------------------------
# Tests: Pincode search
# ---------------------------------------------------------------------------

class TestPincodeSearch:
    @pytest.mark.asyncio
    async def test_pincode_exact_match(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_amber, vet_ajmer,
    ):
        """Pincode 302001 returns only Jaipur vet."""
        resp = await client.get(
            "/api/v1/vets/search?pincode=302001",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert len(data) == 1
        assert data[0]["pincode"] == "302001"
        assert data[0]["city"] == "Jaipur"


# ---------------------------------------------------------------------------
# Tests: Available filter
# ---------------------------------------------------------------------------

class TestAvailableFilter:
    @pytest.mark.asyncio
    async def test_available_filter_excludes_unavailable(
        self, client: AsyncClient, farmer_search_headers: dict,
        vet_jaipur, vet_udaipur_unavailable,
    ):
        """available=true excludes Udaipur vet (unavailable)."""
        resp = await client.get(
            "/api/v1/vets/search?available=true",
            headers=farmer_search_headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        for v in data:
            assert v["is_available"] is True
        cities = [v["city"] for v in data]
        assert "Udaipur" not in cities


# ---------------------------------------------------------------------------
# Tests: Vet registration with location
# ---------------------------------------------------------------------------

class TestVetRegistrationWithLocation:
    @pytest.mark.asyncio
    async def test_register_vet_with_location(self, client: AsyncClient, db_session: AsyncSession):
        """Vet registers with pincode and lat/lng."""
        user = User(id=uuid.uuid4(), phone="9999960099", role=UserRole.vet, is_active=True)
        db_session.add(user)
        await db_session.flush()
        token = create_access_token(str(user.id), user.role.value)
        headers = {"Authorization": f"Bearer {token}"}

        resp = await client.post(
            "/api/v1/vets/register",
            json={
                "license_number": "VET-LOC-001",
                "qualification": "bvsc",
                "specializations": ["cattle"],
                "experience_years": 3,
                "languages": ["hi", "en"],
                "consultation_fee": 350.0,
                "pincode": "302017",
                "city": "Jaipur",
                "district": "Jaipur",
                "state": "Rajasthan",
                "address": "123, MG Road, Jaipur",
                "lat": 26.8800,
                "lng": 75.7800,
                "service_radius_km": 30.0,
            },
            headers=headers,
        )
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["pincode"] == "302017"
        assert data["city"] == "Jaipur"
        assert data["district"] == "Jaipur"
        assert data["lat"] == 26.88
        assert data["lng"] == 75.78
        assert data["service_radius_km"] == 30.0
