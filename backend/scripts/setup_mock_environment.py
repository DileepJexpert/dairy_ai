#!/usr/bin/env python3
"""
Set up a local mock environment for testing the full sensor → notification pipeline.

Creates:
  - A test farmer user with auth token
  - 3 cattle registered to the farmer
  - Prints the auth token and cattle IDs for use with the simulator

Usage:
  # Start infra first
  docker compose -f infra/docker-compose.yml up -d

  # Run the backend
  cd backend && uvicorn app.main:app --reload

  # In another terminal, seed mock data
  cd backend && python scripts/setup_mock_environment.py

  # Then run the simulator
  python scripts/mock_sensor_simulator.py --scenario mixed
"""

import asyncio
import sys
import os
import uuid
from datetime import datetime, timedelta, timezone

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.database import engine, async_session_factory, Base, init_db
from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.cattle import Cattle, Breed, Sex, CattleStatus
from app.services.auth_service import create_access_token, hash_otp


# Fixed UUIDs matching the simulator defaults
FARMER_USER_ID = uuid.UUID("10000000-0000-0000-0000-000000000001")
FARMER_ID = uuid.UUID("20000000-0000-0000-0000-000000000001")
CATTLE_IDS = [
    uuid.UUID("00000000-0000-0000-0000-000000000001"),
    uuid.UUID("00000000-0000-0000-0000-000000000002"),
    uuid.UUID("00000000-0000-0000-0000-000000000003"),
]

CATTLE_NAMES = ["Lakshmi", "Ganga", "Nandini"]
CATTLE_TAGS = ["MH-001", "MH-002", "MH-003"]
CATTLE_BREEDS = [Breed.gir, Breed.sahiwal, Breed.hf_crossbred]


async def setup():
    print("=" * 60)
    print("DairyAI Mock Environment Setup")
    print("=" * 60)

    await init_db()
    print("[OK] Database tables created")

    async with async_session_factory() as db:
        # Check if already seeded
        from sqlalchemy import select
        existing = await db.execute(select(User).where(User.id == FARMER_USER_ID))
        if existing.scalar_one_or_none():
            print("[SKIP] Mock data already exists")
        else:
            # Create farmer user
            user = User(
                id=FARMER_USER_ID,
                phone="9876543210",
                role=UserRole.farmer,
                is_active=True,
                otp_hash=hash_otp("123456"),
                otp_expires_at=datetime.now(timezone.utc) + timedelta(days=365),
            )
            db.add(user)
            await db.flush()
            print(f"[OK] Created farmer user: {FARMER_USER_ID}")

            # Create farmer profile
            farmer = Farmer(
                id=FARMER_ID,
                user_id=FARMER_USER_ID,
                name="Test Farmer (Raju)",
                village="Pune",
                district="Pune",
                state="Maharashtra",
                language="hi",
                total_cattle=3,
            )
            db.add(farmer)
            await db.flush()
            print(f"[OK] Created farmer profile: {farmer.name}")

            # Create cattle
            for i, (cid, name, tag, breed) in enumerate(
                zip(CATTLE_IDS, CATTLE_NAMES, CATTLE_TAGS, CATTLE_BREEDS)
            ):
                cattle = Cattle(
                    id=cid,
                    farmer_id=FARMER_ID,
                    tag_id=tag,
                    name=name,
                    breed=breed,
                    sex=Sex.female,
                    status=CattleStatus.active,
                    lactation_number=2 + i,
                )
                db.add(cattle)
                print(f"[OK] Created cattle: {name} ({tag}) → {cid}")

            await db.commit()

        # Generate auth token
        token = create_access_token(str(FARMER_USER_ID), "farmer")

        print()
        print("=" * 60)
        print("MOCK ENVIRONMENT READY")
        print("=" * 60)
        print()
        print(f"Farmer User ID : {FARMER_USER_ID}")
        print(f"Farmer Phone   : 9876543210")
        print(f"Auth Token     : {token}")
        print()
        print("Cattle IDs:")
        for cid, name, tag in zip(CATTLE_IDS, CATTLE_NAMES, CATTLE_TAGS):
            print(f"  {name} ({tag}): {cid}")
        print()
        print("-" * 60)
        print("NEXT STEPS:")
        print("-" * 60)
        print()
        print("Option 1: MQTT mode (full pipeline)")
        print("  # Terminal 1: Start infra")
        print("  docker compose -f infra/docker-compose.yml up -d")
        print()
        print("  # Terminal 2: Start backend with MQTT")
        print("  cd backend")
        print("  MQTT_BROKER_HOST=localhost uvicorn app.main:app --reload")
        print()
        print("  # Terminal 3: Run simulator")
        print("  cd backend")
        print("  python scripts/mock_sensor_simulator.py --scenario mixed --interval 10")
        print()
        print("Option 2: HTTP mode (no broker needed)")
        print(f"  cd backend")
        print(f"  python scripts/mock_sensor_simulator.py --http --token {token} --scenario mixed --interval 10")
        print()
        print("Check notifications:")
        print(f'  curl -H "Authorization: Bearer {token}" http://localhost:8000/api/v1/notifications')
        print()
        print("Check sensor data:")
        print(f'  curl -H "Authorization: Bearer {token}" http://localhost:8000/api/v1/cattle/{CATTLE_IDS[0]}/sensors/latest')
        print()
        print("Health dashboard:")
        print(f'  curl -H "Authorization: Bearer {token}" http://localhost:8000/api/v1/cattle/{CATTLE_IDS[0]}/health-dashboard')
        print()


if __name__ == "__main__":
    asyncio.run(setup())
