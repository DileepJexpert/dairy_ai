"""Payment cycle access must be scoped before any payouts are generated."""
import uuid
from datetime import date
from types import SimpleNamespace

import pytest
import pytest_asyncio
from sqlalchemy import func, select

from app.models.collection import CollectionCenter, MilkCollection
from app.models.cooperative import Cooperative, CooperativeType
from app.models.farmer import Farmer
from app.models.payment import FarmerPayment, PaymentCycle, PaymentCycleType, PaymentStatus
from app.models.user import User, UserRole
from app.services.auth_service import create_access_token


def headers_for(user):
    token = create_access_token(str(user.id), user.role.value)
    return {"Authorization": f"Bearer {token}"}


def cycle_payload(**values):
    return {
        "cycle_type": "weekly",
        "period_start": str(date.today()),
        "period_end": str(date.today()),
        **values,
    }


@pytest_asyncio.fixture
async def cycle_accounts(db_session):
    accounts = []
    for number in (1, 2):
        user = User(phone=f"999997000{number}", role=UserRole.cooperative, is_active=True)
        farmer_user = User(phone=f"999997001{number}", role=UserRole.farmer, is_active=True)
        db_session.add_all([user, farmer_user])
        await db_session.flush()
        cooperative = Cooperative(
            user_id=user.id,
            name=f"Cooperative {number}",
            registration_number=f"CYCLE-ACCESS-{number}",
            cooperative_type=CooperativeType.milk_collection,
        )
        farmer = Farmer(user_id=farmer_user.id, name=f"Farmer {number}")
        db_session.add_all([cooperative, farmer])
        await db_session.flush()
        center = CollectionCenter(
            cooperative_id=cooperative.id,
            name=f"Center {number}",
            code=f"CYCLE-CENTER-{number}",
        )
        cycle = PaymentCycle(
            cooperative_id=cooperative.id,
            cycle_type=PaymentCycleType.weekly,
            period_start=date.today(),
            period_end=date.today(),
        )
        db_session.add_all([center, cycle])
        await db_session.flush()
        db_session.add(MilkCollection(
            center_id=center.id,
            farmer_id=farmer.id,
            date=date.today(),
            shift="morning",
            quantity_litres=10.0 * number,
            fat_pct=4.2,
            snf_pct=8.6,
            net_amount=300.0 * number,
            is_rejected=False,
        ))
        accounts.append(SimpleNamespace(
            cooperative=cooperative, cycle=cycle, farmer=farmer,
            headers=headers_for(user), farmer_headers=headers_for(farmer_user),
        ))
    global_cycle = PaymentCycle(
        cycle_type=PaymentCycleType.weekly,
        period_start=date.today(),
        period_end=date.today(),
    )
    db_session.add(global_cycle)
    await db_session.flush()
    return SimpleNamespace(own=accounts[0], other=accounts[1], global_cycle=global_cycle)


@pytest.mark.asyncio
@pytest.mark.parametrize("scope", ["omitted", "own", "other", "invalid"])
async def test_cooperative_cycle_creation_is_scoped(client, db_session, cycle_accounts, scope):
    own, other = cycle_accounts.own, cycle_accounts.other
    values = {}
    if scope != "omitted":
        values["cooperative_id"] = {
            "own": str(own.cooperative.id),
            "other": str(other.cooperative.id),
            "invalid": "invalid-id",
        }[scope]
    before = await db_session.scalar(select(func.count()).select_from(PaymentCycle))
    response = await client.post(
        "/api/v1/payments/cycles", json=cycle_payload(**values), headers=own.headers,
    )
    if scope in ("other", "invalid"):
        assert response.status_code == (403 if scope == "other" else 422)
        assert await db_session.scalar(select(func.count()).select_from(PaymentCycle)) == before
    else:
        assert response.status_code == 201
        cycle = await db_session.get(PaymentCycle, uuid.UUID(response.json()["data"]["id"]))
        assert cycle.cooperative_id == own.cooperative.id


@pytest.mark.asyncio
@pytest.mark.parametrize("target", ["other", "global"])
async def test_cooperative_cannot_process_outside_its_scope(client, db_session, cycle_accounts, target):
    cycle = cycle_accounts.other.cycle if target == "other" else cycle_accounts.global_cycle
    response = await client.post(
        f"/api/v1/payments/cycles/{cycle.id}/process", headers=cycle_accounts.own.headers,
    )
    assert response.status_code == 404
    await db_session.refresh(cycle)
    assert cycle.status == PaymentStatus.pending
    assert cycle.processed_at is None
    assert cycle.net_payout == 0
    assert await db_session.scalar(select(func.count()).select_from(FarmerPayment)) == 0


@pytest.mark.asyncio
async def test_own_cycle_processes_only_own_collections(client, db_session, cycle_accounts):
    own = cycle_accounts.own
    response = await client.post(
        f"/api/v1/payments/cycles/{own.cycle.id}/process", headers=own.headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["status"] == "processing"
    assert data["farmers_count"] == 1
    assert data["total_litres"] == 10
    assert data["net_payout"] == 305
    payments = list((await db_session.scalars(select(FarmerPayment))).all())
    assert [(p.cycle_id, p.farmer_id) for p in payments] == [(own.cycle.id, own.farmer.id)]


@pytest.mark.asyncio
@pytest.mark.parametrize("profile", ["missing", "inactive"])
async def test_cooperative_requires_active_profile(
    client, db_session, cycle_accounts, cooperative_headers, profile,
):
    own = cycle_accounts.own
    headers = cooperative_headers
    if profile == "inactive":
        own.cooperative.is_active = False
        await db_session.flush()
        headers = own.headers
    responses = [
        await client.post("/api/v1/payments/cycles", json=cycle_payload(), headers=headers),
        await client.get("/api/v1/payments/cycles", headers=headers),
        await client.post(f"/api/v1/payments/cycles/{own.cycle.id}/process", headers=headers),
    ]
    assert [response.status_code for response in responses] == [403, 403, 403]
    await db_session.refresh(own.cycle)
    assert own.cycle.status == PaymentStatus.pending
    assert await db_session.scalar(select(func.count()).select_from(PaymentCycle)) == 3
    assert await db_session.scalar(select(func.count()).select_from(FarmerPayment)) == 0


@pytest.mark.asyncio
async def test_cycle_listing_is_scoped_to_cooperative_or_farmer(client, db_session, cycle_accounts):
    own, other = cycle_accounts.own, cycle_accounts.other
    db_session.add(FarmerPayment(cycle_id=own.cycle.id, farmer_id=own.farmer.id))
    await db_session.flush()
    for headers, expected in (
        (own.headers, [str(own.cycle.id)]),
        (other.headers, [str(other.cycle.id)]),
        (own.farmer_headers, [str(own.cycle.id)]),
        (other.farmer_headers, []),
    ):
        response = await client.get("/api/v1/payments/cycles", headers=headers)
        assert response.status_code == 200
        assert [cycle["id"] for cycle in response.json()["data"]] == expected


@pytest.mark.asyncio
@pytest.mark.parametrize("role", ["admin", "super_admin"])
async def test_administrators_retain_all_cycle_access(
    client, db_session, cycle_accounts, admin_headers, super_admin_headers, role,
):
    headers = admin_headers if role == "admin" else super_admin_headers
    response = await client.get("/api/v1/payments/cycles", headers=headers)
    assert response.status_code == 200
    assert {cycle["id"] for cycle in response.json()["data"]} == {
        str(cycle_accounts.own.cycle.id), str(cycle_accounts.other.cycle.id),
        str(cycle_accounts.global_cycle.id),
    }
    for scope in (None, str(cycle_accounts.other.cooperative.id)):
        response = await client.post(
            "/api/v1/payments/cycles", json=cycle_payload(cooperative_id=scope), headers=headers,
        )
        assert response.status_code == 201
        cycle = await db_session.get(PaymentCycle, uuid.UUID(response.json()["data"]["id"]))
        assert cycle.cooperative_id == (uuid.UUID(scope) if scope else None)
        response = await client.post(f"/api/v1/payments/cycles/{cycle.id}/process", headers=headers)
        assert response.status_code == 200
        assert response.json()["data"]["total_litres"] == (20 if scope else 30)


@pytest.mark.asyncio
async def test_unrelated_role_cannot_list_cycles(client, cycle_accounts, vendor_headers):
    response = await client.get("/api/v1/payments/cycles", headers=vendor_headers)
    assert response.status_code == 403
