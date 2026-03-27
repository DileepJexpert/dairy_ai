"""Seed script for demo data. Run: python -m scripts.seed_data"""
import asyncio
import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.database import engine, async_session_factory, Base, init_db
from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.cattle import Cattle
from app.models.health import HealthRecord, Vaccination, SensorReading
from app.models.milk import MilkRecord, MilkPrice
from app.models.vet import VetProfile
from app.models.finance import Transaction
from app.services.auth_service import hash_otp


async def seed():
    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session_factory() as db:
        print("Seeding database...")

        # === ADMIN USER ===
        admin = User(id=uuid.uuid4(), phone="9999900000", role=UserRole.admin, is_active=True,
                     otp_hash=hash_otp("123456"), otp_expires_at=datetime.now(timezone.utc) + timedelta(days=365))
        db.add(admin)

        # === DEMO FARMERS ===
        farmers_data = [
            {"name": "Ramesh Patel", "village": "Anand", "district": "Anand", "state": "Gujarat", "phone": "9999900001"},
            {"name": "Suresh Kumar", "village": "Karnal", "district": "Karnal", "state": "Haryana", "phone": "9999900002"},
            {"name": "Lakshmi Devi", "village": "Pune", "district": "Pune", "state": "Maharashtra", "phone": "9999900003"},
        ]

        farmer_objs = []
        for fd in farmers_data:
            user = User(id=uuid.uuid4(), phone=fd["phone"], role=UserRole.farmer, is_active=True,
                        otp_hash=hash_otp("123456"), otp_expires_at=datetime.now(timezone.utc) + timedelta(days=365))
            db.add(user)
            await db.flush()

            farmer = Farmer(
                id=uuid.uuid4(), user_id=user.id, name=fd["name"],
                village=fd["village"], district=fd["district"], state=fd["state"],
            )
            db.add(farmer)
            farmer_objs.append(farmer)

        await db.flush()

        # === CATTLE ===
        cattle_data = [
            # Farmer 0: Ramesh — 3 cattle
            (0, "IN000000000001", "Lakshmi", "gir", "female", 380, "active"),
            (0, "IN000000000002", "Gauri", "sahiwal", "female", 420, "active"),
            (0, "IN000000000003", "Nandi", "gir", "male", 500, "active"),
            # Farmer 1: Suresh — 3 cattle
            (1, "IN000000000004", "Kamdhenu", "hf_crossbred", "female", 450, "active"),
            (1, "IN000000000005", "Dhenu", "jersey_crossbred", "female", 400, "dry"),
            (1, "IN000000000006", "Sundari", "murrah", "female", 500, "active"),
            # Farmer 2: Lakshmi — 2 cattle
            (2, "IN000000000007", "Radha", "gir", "female", 350, "active"),
            (2, "IN000000000008", "Sita", "sahiwal", "female", 370, "active"),
        ]

        cattle_objs = []
        for fi, tag, name, breed, sex, weight, status in cattle_data:
            c = Cattle(
                id=uuid.uuid4(), farmer_id=farmer_objs[fi].id,
                tag_id=tag, name=name, breed=breed, sex=sex,
                weight_kg=weight, status=status,
                dob=date.today() - timedelta(days=365 * 3),
            )
            db.add(c)
            cattle_objs.append(c)
        await db.flush()

        # Update farmer total_cattle
        farmer_objs[0].total_cattle = 3
        farmer_objs[1].total_cattle = 3
        farmer_objs[2].total_cattle = 2

        # === MILK RECORDS (last 7 days) ===
        for cattle in cattle_objs:
            if cattle.sex == "male" or cattle.status == "dry":
                continue
            for day in range(7):
                d = date.today() - timedelta(days=day)
                for session in ["morning", "evening"]:
                    qty = 5.0 + (day % 3) * 0.5
                    price = 35.0
                    db.add(MilkRecord(
                        cattle_id=cattle.id, date=d, session=session,
                        quantity_litres=qty, price_per_litre=price, total_amount=round(qty * price, 2),
                        fat_pct=3.5 + (day % 3) * 0.2,
                    ))

        # === SENSOR READINGS (last 7 days, every 4 hours) ===
        now = datetime.now(timezone.utc)
        for cattle in cattle_objs[:4]:
            for h in range(0, 168, 4):  # 7 days * 24h / 4h = 42 readings
                t = now - timedelta(hours=h)
                db.add(SensorReading(
                    cattle_id=cattle.id, time=t,
                    temperature=38.2 + (h % 10) * 0.1,
                    heart_rate=60 + (h % 8) * 2,
                    activity_level=40 + (h % 12) * 3,
                    rumination_minutes=30 + (h % 6),
                    battery_pct=max(20, 100 - h // 4),
                ))

        # === HEALTH RECORDS ===
        db.add(HealthRecord(
            cattle_id=cattle_objs[0].id, date=date.today() - timedelta(days=5),
            record_type="illness", symptoms="Mild fever, reduced appetite",
            diagnosis="Mild infection", treatment="Antibiotics course", severity=4, resolved=True,
        ))
        db.add(HealthRecord(
            cattle_id=cattle_objs[3].id, date=date.today() - timedelta(days=2),
            record_type="checkup", symptoms="Routine checkup",
            diagnosis="Healthy", severity=1, resolved=True,
        ))

        # === VACCINATIONS ===
        db.add(Vaccination(
            cattle_id=cattle_objs[0].id, vaccine_name="FMD",
            date_given=date.today() - timedelta(days=90), next_due_date=date.today() + timedelta(days=90),
        ))
        db.add(Vaccination(
            cattle_id=cattle_objs[1].id, vaccine_name="Brucellosis",
            date_given=date.today() - timedelta(days=60), next_due_date=date.today() + timedelta(days=300),
        ))

        # === MILK PRICES ===
        db.add(MilkPrice(district="Anand", state="Gujarat", buyer_name="Amul Cooperative",
                         buyer_type="cooperative", price_per_litre=35.0, fat_pct_basis=3.5, date=date.today()))
        db.add(MilkPrice(district="Anand", state="Gujarat", buyer_name="Param Dairy",
                         buyer_type="private", price_per_litre=38.0, fat_pct_basis=4.0, date=date.today()))
        db.add(MilkPrice(district="Anand", state="Gujarat", buyer_name="Village Shop",
                         buyer_type="local", price_per_litre=42.0, fat_pct_basis=4.5, date=date.today()))

        # === TRANSACTIONS ===
        db.add(Transaction(farmer_id=farmer_objs[0].id, type="income", category="milk_sale",
                           amount=5000, description="Weekly milk sale", date=date.today() - timedelta(days=3)))
        db.add(Transaction(farmer_id=farmer_objs[0].id, type="expense", category="feed_purchase",
                           amount=2000, description="Cattle feed", date=date.today() - timedelta(days=5)))

        # === VET PROFILES ===
        for i, vd in enumerate([
            {"name": "Dr. Amit Shah", "phone": "9999900010", "license": "GJ-VET-001", "qual": "mvsc", "spec": ["cattle", "surgery"], "fee": 200},
            {"name": "Dr. Priya Verma", "phone": "9999900011", "license": "HR-VET-001", "qual": "bvsc", "spec": ["cattle", "reproduction"], "fee": 150},
        ]):
            vet_user = User(id=uuid.uuid4(), phone=vd["phone"], role=UserRole.vet, is_active=True,
                            otp_hash=hash_otp("123456"), otp_expires_at=datetime.now(timezone.utc) + timedelta(days=365))
            db.add(vet_user)
            await db.flush()
            db.add(VetProfile(
                user_id=vet_user.id, license_number=vd["license"],
                qualification=vd["qual"], specializations=vd["spec"],
                experience_years=5 + i * 3, languages=["hi", "en"],
                consultation_fee=vd["fee"], is_verified=True, is_available=True,
                bio=f"{vd['name']} - Experienced cattle specialist",
            ))

        await db.commit()
        print("\n=== SEED DATA CREATED ===")
        print("Demo credentials (all use OTP: 123456):")
        print(f"  Admin:    9999900000")
        print(f"  Farmer 1: 9999900001 (Ramesh Patel, 3 cattle)")
        print(f"  Farmer 2: 9999900002 (Suresh Kumar, 3 cattle)")
        print(f"  Farmer 3: 9999900003 (Lakshmi Devi, 2 cattle)")
        print(f"  Vet 1:    9999900010 (Dr. Amit Shah)")
        print(f"  Vet 2:    9999900011 (Dr. Priya Verma)")
        print("=============================\n")


if __name__ == "__main__":
    asyncio.run(seed())
