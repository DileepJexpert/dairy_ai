"""Government Scheme Navigator service."""
import logging
import uuid
from datetime import date
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.schemes import GovernmentScheme, SchemeApplication, SchemeBookmark, SchemeCategory, SchemeLevel

logger = logging.getLogger("dairy_ai.services.scheme")


async def get_all_schemes(
    db: AsyncSession, category: str | None = None, level: str | None = None,
    state: str | None = None, is_active: bool = True,
) -> list[GovernmentScheme]:
    query = select(GovernmentScheme)
    if is_active:
        query = query.where(GovernmentScheme.is_active == True)
    if category:
        query = query.where(GovernmentScheme.category == SchemeCategory(category))
    if level:
        query = query.where(GovernmentScheme.level == SchemeLevel(level))
    query = query.order_by(GovernmentScheme.name)
    result = await db.execute(query)
    return list(result.scalars().all())


async def get_scheme_detail(db: AsyncSession, scheme_id: uuid.UUID) -> GovernmentScheme | None:
    return await db.get(GovernmentScheme, scheme_id)


async def check_eligibility(db: AsyncSession, farmer_id: uuid.UUID, scheme_id: uuid.UUID) -> dict:
    """Check if a farmer qualifies for a scheme."""
    from app.models.farmer import Farmer
    from app.models.cattle import Cattle

    scheme = await db.get(GovernmentScheme, scheme_id)
    if not scheme:
        return {"eligible": False, "reasons": ["Scheme not found"]}

    farmer_result = await db.execute(select(Farmer).where(Farmer.id == farmer_id))
    farmer = farmer_result.scalar_one_or_none()
    if not farmer:
        return {"eligible": False, "reasons": ["Farmer not found"]}

    cattle_count_result = await db.execute(
        select(func.count()).select_from(Cattle).where(Cattle.farmer_id == farmer_id)
    )
    cattle_count = cattle_count_result.scalar() or 0

    met = []
    unmet = []

    # State check
    states = scheme.applicable_states or []
    if states and farmer.state and farmer.state not in states:
        unmet.append(f"Scheme available in: {', '.join(states)}. Your state: {farmer.state}")
    elif states:
        met.append(f"State eligible: {farmer.state}")

    # Cattle count
    if scheme.min_cattle_count and cattle_count < scheme.min_cattle_count:
        unmet.append(f"Need minimum {scheme.min_cattle_count} cattle, you have {cattle_count}")
    elif scheme.min_cattle_count:
        met.append(f"Cattle count: {cattle_count} >= {scheme.min_cattle_count}")

    if scheme.max_cattle_count and cattle_count > scheme.max_cattle_count:
        unmet.append(f"Maximum {scheme.max_cattle_count} cattle allowed, you have {cattle_count}")

    eligible = len(unmet) == 0
    return {
        "eligible": eligible,
        "met_criteria": met,
        "unmet_criteria": unmet,
        "missing_documents": scheme.required_documents or [],
        "scheme_name": scheme.name,
        "max_benefit": scheme.subsidy_amount_max,
    }


async def get_recommended_schemes(db: AsyncSession, farmer_id: uuid.UUID) -> list[dict]:
    """Get schemes the farmer qualifies for, sorted by potential benefit."""
    schemes = await get_all_schemes(db)
    recommended = []
    for scheme in schemes:
        result = await check_eligibility(db, farmer_id, scheme.id)
        if result["eligible"]:
            recommended.append({
                "scheme_id": str(scheme.id),
                "name": scheme.name,
                "short_name": scheme.short_name,
                "category": scheme.category.value,
                "max_benefit": scheme.subsidy_amount_max,
                "description": scheme.description[:200] if scheme.description else "",
            })
    recommended.sort(key=lambda x: x.get("max_benefit") or 0, reverse=True)
    return recommended


async def apply_for_scheme(
    db: AsyncSession, farmer_id: uuid.UUID, user_id: uuid.UUID,
    scheme_id: uuid.UUID, documents: list | None = None,
) -> SchemeApplication:
    app = SchemeApplication(
        scheme_id=scheme_id, farmer_id=farmer_id, user_id=user_id,
        documents_uploaded=documents or [],
        status="submitted", applied_at=date.today(),
    )
    db.add(app)
    await db.flush()
    logger.info("Scheme application created: farmer=%s, scheme=%s", farmer_id, scheme_id)
    return app


async def get_my_applications(db: AsyncSession, user_id: uuid.UUID) -> list[SchemeApplication]:
    result = await db.execute(
        select(SchemeApplication).where(SchemeApplication.user_id == user_id)
        .order_by(SchemeApplication.created_at.desc())
    )
    return list(result.scalars().all())


async def update_application_status(
    db: AsyncSession, application_id: uuid.UUID, status: str, notes: str | None = None,
) -> SchemeApplication | None:
    app = await db.get(SchemeApplication, application_id)
    if not app:
        return None
    app.status = status
    if notes:
        app.notes = notes
    if status == "approved":
        app.reviewed_at = date.today()
    elif status == "disbursed":
        app.disbursed_at = date.today()
    await db.flush()
    return app


async def toggle_bookmark(db: AsyncSession, scheme_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    result = await db.execute(
        select(SchemeBookmark).where(
            and_(SchemeBookmark.scheme_id == scheme_id, SchemeBookmark.user_id == user_id)
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        await db.delete(existing)
        await db.flush()
        return False
    bm = SchemeBookmark(scheme_id=scheme_id, user_id=user_id)
    db.add(bm)
    await db.flush()
    return True


async def get_my_bookmarks(db: AsyncSession, user_id: uuid.UUID) -> list[GovernmentScheme]:
    result = await db.execute(
        select(GovernmentScheme).join(SchemeBookmark, SchemeBookmark.scheme_id == GovernmentScheme.id)
        .where(SchemeBookmark.user_id == user_id)
    )
    return list(result.scalars().all())


async def seed_schemes(db: AsyncSession) -> int:
    """Seed real Indian government dairy schemes."""
    schemes_data = [
        {
            "name": "Rashtriya Gokul Mission (RGM)",
            "short_name": "RGM",
            "category": SchemeCategory.breed_improvement,
            "level": SchemeLevel.central,
            "description": "National programme for conservation and development of indigenous cattle breeds. Supports establishment of Gokul Grams, genomic selection, AI infrastructure.",
            "benefits": "Funding for breed improvement, Gokul Grams, semen stations, AI coverage expansion",
            "subsidy_amount_max": 500000,
            "subsidy_percentage": 50,
            "required_documents": ["Aadhaar Card", "Cattle Details", "Bank Passbook", "Land Document"],
            "applicable_states": [],
            "nodal_agency": "DAHD, Ministry of Fisheries, Animal Husbandry & Dairying",
            "implementing_agency": "State Animal Husbandry Department",
            "is_active": True,
        },
        {
            "name": "Dairy Entrepreneurship Development Scheme (DEDS)",
            "short_name": "DEDS",
            "category": SchemeCategory.dairy_infrastructure,
            "level": SchemeLevel.central,
            "description": "NABARD-backed scheme for setting up small dairy farms (2-10 animals), milking machines, milk chilling facilities. Back-ended capital subsidy.",
            "benefits": "25% subsidy (33% for SC/ST) on dairy unit setup up to ₹7 lakh for 10 animals",
            "subsidy_amount_max": 700000,
            "subsidy_percentage": 25,
            "required_documents": ["Aadhaar Card", "Bank Account", "Project Report", "Land Ownership/Lease", "Caste Certificate (if applicable)"],
            "applicable_states": [],
            "min_cattle_count": 2,
            "max_cattle_count": 10,
            "nodal_agency": "NABARD",
            "implementing_agency": "Scheduled Banks / Regional Rural Banks",
            "is_active": True,
        },
        {
            "name": "Animal Husbandry Infrastructure Development Fund (AHIDF)",
            "short_name": "AHIDF",
            "category": SchemeCategory.dairy_infrastructure,
            "level": SchemeLevel.central,
            "description": "₹15,000 crore fund for dairy processing, value addition, cattle feed infrastructure. 3% interest subvention and credit guarantee.",
            "benefits": "3% interest subvention for 8 years on loans up to ₹100 crore; 25% credit guarantee by GOI",
            "subsidy_amount_max": 10000000,
            "required_documents": ["Project Report", "Company/FPO Registration", "Financial Statements", "Land Document"],
            "nodal_agency": "DAHD",
            "implementing_agency": "Scheduled Banks via NABARD",
            "is_active": True,
        },
        {
            "name": "Kisan Credit Card for Animal Husbandry",
            "short_name": "KCC-AH",
            "category": SchemeCategory.credit,
            "level": SchemeLevel.central,
            "description": "Kisan Credit Card extended to animal husbandry and dairying. Short-term credit at 7% (4% with subsidy). Up to ₹3 lakh.",
            "benefits": "Credit up to ₹3 lakh at 4% effective interest (7% minus 3% interest subvention). No collateral up to ₹1.6 lakh",
            "subsidy_amount_max": 300000,
            "required_documents": ["Aadhaar Card", "Land Record / Cattle Ownership Proof", "Bank Account", "Passport Photo"],
            "applicable_states": [],
            "nodal_agency": "RBI / NABARD",
            "implementing_agency": "All Scheduled Commercial Banks, RRBs, Cooperative Banks",
            "is_active": True,
        },
        {
            "name": "National Livestock Mission (NLM)",
            "short_name": "NLM",
            "category": SchemeCategory.fodder,
            "level": SchemeLevel.central,
            "description": "Supports entrepreneurship in livestock, fodder/feed development, innovation. Sub-missions for breed improvement, feed & fodder, skill development.",
            "benefits": "50% subsidy for fodder production units; 25-33% for feed plants; training support",
            "subsidy_amount_max": 2500000,
            "subsidy_percentage": 50,
            "required_documents": ["Aadhaar Card", "Project Proposal", "Land Document", "Bank Account"],
            "applicable_states": [],
            "nodal_agency": "DAHD",
            "implementing_agency": "State Animal Husbandry Departments",
            "is_active": True,
        },
        {
            "name": "Gobar-Dhan Scheme (GOBARDHAN)",
            "short_name": "GOBARDHAN",
            "category": SchemeCategory.biogas,
            "level": SchemeLevel.central,
            "description": "Convert cattle dung and agricultural waste to biogas and bio-CNG. Supports community and individual biogas plants.",
            "benefits": "Financial support for biogas plant setup; ₹12,000-50,000 per household plant; community plants up to ₹50 lakh",
            "subsidy_amount_max": 5000000,
            "required_documents": ["Aadhaar Card", "Cattle Ownership Proof", "Land Document", "Bank Account", "Gram Panchayat NOC (community)"],
            "applicable_states": [],
            "min_cattle_count": 3,
            "nodal_agency": "Ministry of Jal Shakti / DAHD",
            "implementing_agency": "District Magistrate / Block Development Officer",
            "is_active": True,
        },
        {
            "name": "Livestock Insurance Scheme",
            "short_name": "LIS",
            "category": SchemeCategory.insurance,
            "level": SchemeLevel.central,
            "description": "50% premium subsidy for insuring high-yielding cattle and buffaloes against death due to disease, accident, natural calamity.",
            "benefits": "50% premium subsidy by central + state govt; covers market value of animal",
            "subsidy_amount_max": 50000,
            "subsidy_percentage": 50,
            "required_documents": ["Aadhaar Card", "Cattle Photo with Ear Tag", "Veterinary Health Certificate", "Bank Account"],
            "applicable_states": [],
            "nodal_agency": "DAHD",
            "implementing_agency": "Empaneled Insurance Companies via State AH Dept",
            "is_active": True,
        },
        {
            "name": "Mukhyamantri Pashupalan Vikas Yojana (UP)",
            "short_name": "MPVY-UP",
            "category": SchemeCategory.dairy_infrastructure,
            "level": SchemeLevel.state,
            "description": "Uttar Pradesh state scheme for dairy development. Subsidized loans for dairy units of 5-25 animals.",
            "benefits": "25-35% subsidy on dairy unit establishment; interest subvention on bank loans",
            "subsidy_amount_max": 1000000,
            "subsidy_percentage": 30,
            "required_documents": ["Aadhaar Card", "UP Domicile", "Land Document", "Bank Account", "Project Report"],
            "applicable_states": ["Uttar Pradesh"],
            "nodal_agency": "UP Animal Husbandry Department",
            "implementing_agency": "District Animal Husbandry Officer",
            "is_active": True,
        },
        {
            "name": "Kamdhenu Yojana (Rajasthan)",
            "short_name": "KAMDHENU-RJ",
            "category": SchemeCategory.dairy_infrastructure,
            "level": SchemeLevel.state,
            "description": "Rajasthan state scheme promoting dairy farming. Supports establishment of dairy units and cow shelters.",
            "benefits": "30% subsidy on dairy unit (max ₹3 lakh); fodder bank support; free AI services",
            "subsidy_amount_max": 300000,
            "subsidy_percentage": 30,
            "required_documents": ["Aadhaar Card", "Rajasthan Domicile", "Land Document", "Bank Account"],
            "applicable_states": ["Rajasthan"],
            "nodal_agency": "Rajasthan Animal Husbandry Department",
            "implementing_agency": "District Collector / Block AH Officer",
            "is_active": True,
        },
        {
            "name": "National Programme for Dairy Development (NPDD)",
            "short_name": "NPDD",
            "category": SchemeCategory.cooperative,
            "level": SchemeLevel.central,
            "description": "Strengthening dairy cooperative infrastructure — bulk milk coolers, processing equipment, quality testing labs.",
            "benefits": "Central assistance for BMC installation, AMCU, milk testing equipment for cooperatives",
            "subsidy_amount_max": 2000000,
            "required_documents": ["Cooperative Registration", "Annual Report", "Project Proposal", "Bank Account"],
            "applicable_states": [],
            "nodal_agency": "NDDB / DAHD",
            "implementing_agency": "State Dairy Federations",
            "is_active": True,
        },
    ]

    count = 0
    for data in schemes_data:
        scheme = GovernmentScheme(**data)
        db.add(scheme)
        count += 1
    await db.flush()
    logger.info("Seeded %d government schemes", count)
    return count
