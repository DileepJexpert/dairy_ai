"""Add marketplace, outbreak, withdrawal, carbon, schemes, mandi,
pashu_aadhaar, and milk_purity tables.

Revision ID: 002_new_modules
Revises: 001_initial
Create Date: 2026-06-13
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSON

revision = "002_new_modules"
down_revision = "001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── cattle_listings ──
    op.create_table(
        "cattle_listings",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("seller_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=True, index=True),
        sa.Column("category", sa.Enum("cow", "buffalo", "bull", "calf", "heifer", name="listingcategory"), nullable=False),
        sa.Column("breed", sa.String(100), nullable=False),
        sa.Column("age_months", sa.Integer),
        sa.Column("weight_kg", sa.Float),
        sa.Column("milk_yield_litres", sa.Float),
        sa.Column("fat_pct", sa.Float),
        sa.Column("lactation_number", sa.Integer),
        sa.Column("is_pregnant", sa.Boolean, server_default="false"),
        sa.Column("months_pregnant", sa.Integer),
        sa.Column("health_verified", sa.Boolean, server_default="false"),
        sa.Column("vaccination_verified", sa.Boolean, server_default="false"),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("price", sa.Float, nullable=False),
        sa.Column("is_negotiable", sa.Boolean, server_default="true"),
        sa.Column("photos", JSON),
        sa.Column("video_url", sa.String(500)),
        sa.Column("location_village", sa.String(100)),
        sa.Column("location_district", sa.String(100)),
        sa.Column("location_state", sa.String(100)),
        sa.Column("lat", sa.Float),
        sa.Column("lng", sa.Float),
        sa.Column("views_count", sa.Integer, server_default="0"),
        sa.Column("inquiries_count", sa.Integer, server_default="0"),
        sa.Column("status", sa.Enum("draft", "active", "sold", "expired", "cancelled", name="listingstatus"), server_default="active"),
        sa.Column("featured", sa.Boolean, server_default="false"),
        sa.Column("expires_at", sa.DateTime),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── listing_inquiries ──
    op.create_table(
        "listing_inquiries",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("listing_id", UUID(as_uuid=True), sa.ForeignKey("cattle_listings.id"), nullable=False, index=True),
        sa.Column("buyer_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("message", sa.Text, nullable=False),
        sa.Column("offered_price", sa.Float),
        sa.Column("phone_shared", sa.Boolean, server_default="false"),
        sa.Column("status", sa.Enum("pending", "accepted", "rejected", "completed", name="inquirystatus"), server_default="pending"),
        sa.Column("seller_response", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── listing_favorites ──
    op.create_table(
        "listing_favorites",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("listing_id", UUID(as_uuid=True), sa.ForeignKey("cattle_listings.id"), nullable=False, index=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.UniqueConstraint("listing_id", "user_id", name="uq_listing_favorite"),
    )

    # ── disease_reports ──
    op.create_table(
        "disease_reports",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=True, index=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("disease_name", sa.String(200), nullable=False, index=True),
        sa.Column("symptoms", sa.Text),
        sa.Column("severity", sa.Enum("mild", "moderate", "severe", "fatal", name="reportseverity"), nullable=False),
        sa.Column("lat", sa.Float, nullable=False),
        sa.Column("lng", sa.Float, nullable=False),
        sa.Column("village", sa.String(200)),
        sa.Column("district", sa.String(200), index=True),
        sa.Column("state", sa.String(200), index=True),
        sa.Column("is_confirmed", sa.Boolean, server_default="false"),
        sa.Column("confirmed_by", sa.String(200)),
        sa.Column("source", sa.Enum("farmer_report", "vet_diagnosis", "lab_confirmed", "sensor_alert", name="reportsource"), nullable=False, server_default="farmer_report"),
        sa.Column("status", sa.Enum("reported", "investigating", "confirmed", "resolved", name="reportstatus"), nullable=False, server_default="reported"),
        sa.Column("reported_at", sa.DateTime, nullable=False, server_default=sa.func.now()),
        sa.Column("resolved_at", sa.DateTime),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── outbreak_zones ──
    op.create_table(
        "outbreak_zones",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("disease_name", sa.String(200), nullable=False, index=True),
        sa.Column("center_lat", sa.Float, nullable=False),
        sa.Column("center_lng", sa.Float, nullable=False),
        sa.Column("radius_km", sa.Float, nullable=False),
        sa.Column("district", sa.String(200), index=True),
        sa.Column("state", sa.String(200), index=True),
        sa.Column("report_count", sa.Integer, nullable=False, server_default="0"),
        sa.Column("severity_level", sa.Enum("watch", "warning", "alert", "critical", name="outbreakseveritylevel"), nullable=False, server_default="watch"),
        sa.Column("first_reported", sa.DateTime, nullable=False),
        sa.Column("last_reported", sa.DateTime, nullable=False),
        sa.Column("is_active", sa.Boolean, server_default="true"),
        sa.Column("advisory", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── withdrawal_records ──
    op.create_table(
        "withdrawal_records",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False, index=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("consultation_id", UUID(as_uuid=True), sa.ForeignKey("consultations.id")),
        sa.Column("medicine_name", sa.String(200), nullable=False),
        sa.Column("active_ingredient", sa.String(200), nullable=False),
        sa.Column("dosage", sa.String(100)),
        sa.Column("route", sa.Enum("oral", "injection", "topical", "intramammary", name="administrationroute"), nullable=False),
        sa.Column("treatment_start_date", sa.Date, nullable=False),
        sa.Column("treatment_end_date", sa.Date, nullable=False),
        sa.Column("milk_withdrawal_days", sa.Integer, nullable=False),
        sa.Column("meat_withdrawal_days", sa.Integer, nullable=False),
        sa.Column("milk_safe_date", sa.Date, nullable=False),
        sa.Column("meat_safe_date", sa.Date, nullable=False),
        sa.Column("is_milk_cleared", sa.Boolean, server_default="false"),
        sa.Column("is_meat_cleared", sa.Boolean, server_default="false"),
        sa.Column("cleared_by", sa.String(200)),
        sa.Column("cleared_at", sa.DateTime),
        sa.Column("notes", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── carbon_records ──
    op.create_table(
        "carbon_records",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("period_start", sa.Date, nullable=False),
        sa.Column("period_end", sa.Date, nullable=False),
        sa.Column("total_cattle", sa.Integer, nullable=False),
        sa.Column("total_milk_litres", sa.Float, nullable=False, server_default="0"),
        sa.Column("enteric_methane_kg", sa.Float, nullable=False, server_default="0"),
        sa.Column("manure_methane_kg", sa.Float, nullable=False, server_default="0"),
        sa.Column("feed_production_co2_kg", sa.Float, nullable=False, server_default="0"),
        sa.Column("energy_co2_kg", sa.Float, nullable=False, server_default="0"),
        sa.Column("transport_co2_kg", sa.Float, nullable=False, server_default="0"),
        sa.Column("total_co2_equivalent_kg", sa.Float, nullable=False, server_default="0"),
        sa.Column("co2_per_litre", sa.Float, nullable=False, server_default="0"),
        sa.Column("carbon_credits_potential", sa.Float, nullable=False, server_default="0"),
        sa.Column("methodology", sa.String(100), nullable=False, server_default="IPCC_2019"),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── carbon_reduction_actions ──
    op.create_table(
        "carbon_reduction_actions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("action_type", sa.Enum("biogas_plant", "improved_feed", "manure_composting", "solar_energy", "tree_planting", "methane_inhibitor", name="carbonactiontype"), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("estimated_reduction_kg_co2", sa.Float, nullable=False, server_default="0"),
        sa.Column("start_date", sa.Date, nullable=False),
        sa.Column("is_verified", sa.Boolean, server_default="false"),
        sa.Column("verified_by", sa.String(200)),
        sa.Column("verified_at", sa.Date),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── government_schemes ──
    op.create_table(
        "government_schemes",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(300), nullable=False),
        sa.Column("short_name", sa.String(50), nullable=False),
        sa.Column("category", sa.Enum("breed_improvement", "dairy_infrastructure", "credit", "insurance", "fodder", "biogas", "training", "cooperative", "women_empowerment", "organic", name="schemecategory"), nullable=False, index=True),
        sa.Column("level", sa.Enum("central", "state", "district", name="schemelevel"), nullable=False, index=True),
        sa.Column("description", sa.Text, nullable=False),
        sa.Column("benefits", sa.Text, nullable=False),
        sa.Column("subsidy_amount_max", sa.Float),
        sa.Column("subsidy_percentage", sa.Float),
        sa.Column("eligibility_criteria", JSON),
        sa.Column("required_documents", JSON),
        sa.Column("applicable_states", JSON),
        sa.Column("min_cattle_count", sa.Integer),
        sa.Column("max_cattle_count", sa.Integer),
        sa.Column("min_land_acres", sa.Float),
        sa.Column("gender_specific", sa.String(10)),
        sa.Column("caste_categories", JSON),
        sa.Column("age_min", sa.Integer),
        sa.Column("age_max", sa.Integer),
        sa.Column("application_url", sa.String(500)),
        sa.Column("helpline", sa.String(50)),
        sa.Column("nodal_agency", sa.String(200), nullable=False),
        sa.Column("implementing_agency", sa.String(200), nullable=False),
        sa.Column("is_active", sa.Boolean, server_default="true"),
        sa.Column("last_date", sa.Date),
        sa.Column("budget_crores", sa.Float),
        sa.Column("beneficiaries_target", sa.Integer),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── scheme_applications ──
    op.create_table(
        "scheme_applications",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("scheme_id", UUID(as_uuid=True), sa.ForeignKey("government_schemes.id"), nullable=False, index=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("status", sa.Enum("draft", "submitted", "under_review", "approved", "rejected", "disbursed", name="schemeapplicationstatus"), nullable=False, server_default="draft"),
        sa.Column("application_ref", sa.String(100)),
        sa.Column("documents_uploaded", JSON),
        sa.Column("applied_amount", sa.Float),
        sa.Column("approved_amount", sa.Float),
        sa.Column("rejection_reason", sa.Text),
        sa.Column("notes", sa.Text),
        sa.Column("applied_at", sa.Date, nullable=False),
        sa.Column("reviewed_at", sa.Date),
        sa.Column("disbursed_at", sa.Date),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── scheme_bookmarks ──
    op.create_table(
        "scheme_bookmarks",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("scheme_id", UUID(as_uuid=True), sa.ForeignKey("government_schemes.id"), nullable=False, index=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.UniqueConstraint("scheme_id", "user_id", name="uq_scheme_bookmark_user"),
    )

    # ── mandi_prices ──
    op.create_table(
        "mandi_prices",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("ingredient_name", sa.String(200), nullable=False, index=True),
        sa.Column("category", sa.Enum("green_fodder", "dry_fodder", "concentrate", "mineral", "cattle_feed", "supplement", name="mandicategory"), nullable=False),
        sa.Column("price_per_kg", sa.Float, nullable=False),
        sa.Column("unit", sa.String(20), server_default="kg"),
        sa.Column("mandi_name", sa.String(200)),
        sa.Column("district", sa.String(100), index=True),
        sa.Column("state", sa.String(100)),
        sa.Column("date", sa.Date, nullable=False, index=True),
        sa.Column("source", sa.String(200)),
        sa.Column("min_price", sa.Float),
        sa.Column("max_price", sa.Float),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── cattle_market_prices ──
    op.create_table(
        "cattle_market_prices",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("breed", sa.String(50), nullable=False, index=True),
        sa.Column("category", sa.String(50), nullable=False),
        sa.Column("age_range", sa.String(30)),
        sa.Column("milk_yield_range", sa.String(30)),
        sa.Column("avg_price", sa.Float, nullable=False),
        sa.Column("min_price", sa.Float),
        sa.Column("max_price", sa.Float),
        sa.Column("mandi_name", sa.String(200)),
        sa.Column("district", sa.String(100), index=True),
        sa.Column("state", sa.String(100)),
        sa.Column("date", sa.Date, nullable=False, index=True),
        sa.Column("sample_count", sa.Integer, server_default="1"),
        sa.Column("source", sa.String(200)),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── pashu_aadhaar ──
    op.create_table(
        "pashu_aadhaar",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), unique=True, nullable=False, index=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("pashu_aadhaar_number", sa.String(20), unique=True, index=True),
        sa.Column("ear_tag_number", sa.String(20), unique=True, index=True),
        sa.Column("identification_method", sa.Enum("ear_tag", "muzzle_print", "photo_id", "manual", name="identificationmethod"), server_default="ear_tag"),
        sa.Column("muzzle_print_hash", sa.String(255)),
        sa.Column("photo_front_url", sa.Text),
        sa.Column("photo_side_url", sa.Text),
        sa.Column("ear_tag_photo_url", sa.Text),
        sa.Column("species", sa.String(20), server_default="cattle"),
        sa.Column("breed_govt", sa.String(100)),
        sa.Column("color", sa.String(50)),
        sa.Column("horn_type", sa.String(50)),
        sa.Column("special_marks", sa.Text),
        sa.Column("owner_name_govt", sa.String(200)),
        sa.Column("owner_aadhaar_last4", sa.String(4)),
        sa.Column("village_code", sa.String(20)),
        sa.Column("block_code", sa.String(20)),
        sa.Column("district_code", sa.String(20)),
        sa.Column("inaph_vaccinations", JSON),
        sa.Column("inaph_ai_records", JSON),
        sa.Column("status", sa.Enum("pending", "registered", "verified", "rejected", name="pashuregistrationstatus"), server_default="pending"),
        sa.Column("registered_at", sa.Date),
        sa.Column("verified_at", sa.Date),
        sa.Column("verified_by", sa.String(200)),
        sa.Column("last_synced_at", sa.DateTime),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── milk_brands ──
    op.create_table(
        "milk_brands",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(200), nullable=False, index=True),
        sa.Column("slug", sa.String(200), nullable=False, unique=True, index=True),
        sa.Column("parent_company", sa.String(200)),
        sa.Column("variant", sa.Enum("full_cream", "toned", "double_toned", "standardised", "organic", "a2", "flavoured", "skimmed", name="milkvariant"), nullable=False, server_default="toned"),
        sa.Column("available_regions", JSON),
        sa.Column("available_states", JSON),
        sa.Column("price_range_min", sa.Float),
        sa.Column("price_range_max", sa.Float),
        sa.Column("packaging_type", sa.String(50)),
        sa.Column("label_fat_pct", sa.Float),
        sa.Column("label_snf_pct", sa.Float),
        sa.Column("fssai_licence_no", sa.String(50)),
        sa.Column("logo_url", sa.String(500)),
        sa.Column("is_active", sa.Boolean, server_default="true"),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── lab_reports ──
    op.create_table(
        "lab_reports",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("brand_id", UUID(as_uuid=True), sa.ForeignKey("milk_brands.id"), nullable=False, index=True),
        sa.Column("lab_name", sa.String(200), nullable=False),
        sa.Column("lab_accreditation", sa.String(100)),
        sa.Column("report_date", sa.Date, nullable=False),
        sa.Column("report_pdf_url", sa.String(500)),
        sa.Column("status", sa.Enum("pending", "completed", "disputed", name="labreportstatus"), nullable=False, server_default="completed"),
        sa.Column("actual_fat_pct", sa.Float),
        sa.Column("actual_snf_pct", sa.Float),
        sa.Column("urea_detected", sa.Boolean, server_default="false"),
        sa.Column("detergent_detected", sa.Boolean, server_default="false"),
        sa.Column("starch_detected", sa.Boolean, server_default="false"),
        sa.Column("neutraliser_detected", sa.Boolean, server_default="false"),
        sa.Column("hydrogen_peroxide_detected", sa.Boolean, server_default="false"),
        sa.Column("total_plate_count", sa.Integer),
        sa.Column("coliform_count", sa.Integer),
        sa.Column("aflatoxin_m1_ppb", sa.Float),
        sa.Column("antibiotic_residue_detected", sa.Boolean, server_default="false"),
        sa.Column("added_water_pct", sa.Float),
        sa.Column("notes", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── fssai_violations ──
    op.create_table(
        "fssai_violations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("brand_id", UUID(as_uuid=True), sa.ForeignKey("milk_brands.id"), nullable=False, index=True),
        sa.Column("violation_date", sa.Date, nullable=False),
        sa.Column("severity", sa.Enum("minor", "major", "critical", name="violationseverity"), nullable=False),
        sa.Column("violation_type", sa.String(200), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("order_number", sa.String(100)),
        sa.Column("penalty_amount", sa.Float),
        sa.Column("is_recall", sa.Boolean, server_default="false"),
        sa.Column("is_licence_suspension", sa.Boolean, server_default="false"),
        sa.Column("source_url", sa.String(500)),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── purity_scores ──
    op.create_table(
        "purity_scores",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("brand_id", UUID(as_uuid=True), sa.ForeignKey("milk_brands.id"), nullable=False, index=True),
        sa.Column("version", sa.Integer, nullable=False, server_default="1"),
        sa.Column("overall_score", sa.Float, nullable=False),
        sa.Column("band", sa.Enum("excellent", "good", "caution", "poor", name="scoreband"), nullable=False),
        sa.Column("fat_accuracy_score", sa.Float, nullable=False, server_default="100"),
        sa.Column("snf_compliance_score", sa.Float, nullable=False, server_default="100"),
        sa.Column("adulteration_score", sa.Float, nullable=False, server_default="100"),
        sa.Column("bacterial_score", sa.Float, nullable=False, server_default="100"),
        sa.Column("fssai_compliance_score", sa.Float, nullable=False, server_default="100"),
        sa.Column("data_sources_count", sa.Integer, server_default="0"),
        sa.Column("has_limited_data", sa.Boolean, server_default="true"),
        sa.Column("calculation_details", JSON),
        sa.Column("calculated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── purity_waitlist ──
    op.create_table(
        "purity_waitlist",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, index=True),
        sa.Column("name", sa.String(200)),
        sa.Column("phone", sa.String(15)),
        sa.Column("preferred_brands", JSON),
        sa.Column("city", sa.String(100)),
        sa.Column("state", sa.String(100)),
        sa.Column("source", sa.String(50)),
        sa.Column("referral_code", sa.String(50)),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.UniqueConstraint("email", name="uq_purity_waitlist_email"),
    )

    # ── brand_requests ──
    op.create_table(
        "brand_requests",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("brand_name", sa.String(200), nullable=False),
        sa.Column("variant", sa.String(100)),
        sa.Column("city", sa.String(100)),
        sa.Column("requested_by_email", sa.String(255)),
        sa.Column("status", sa.Enum("pending", "in_progress", "completed", "rejected", name="brandrequeststs"), nullable=False, server_default="pending"),
        sa.Column("vote_count", sa.Integer, server_default="1"),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── purity_score_alerts ──
    op.create_table(
        "purity_score_alerts",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, index=True),
        sa.Column("brand_id", UUID(as_uuid=True), sa.ForeignKey("milk_brands.id"), nullable=False, index=True),
        sa.Column("is_active", sa.Boolean, server_default="true"),
        sa.Column("last_notified_score", sa.Float),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.UniqueConstraint("email", "brand_id", name="uq_purity_alert_email_brand"),
    )


def downgrade() -> None:
    op.drop_table("purity_score_alerts")
    op.drop_table("brand_requests")
    op.drop_table("purity_waitlist")
    op.drop_table("purity_scores")
    op.drop_table("fssai_violations")
    op.drop_table("lab_reports")
    op.drop_table("milk_brands")
    op.drop_table("pashu_aadhaar")
    op.drop_table("cattle_market_prices")
    op.drop_table("mandi_prices")
    op.drop_table("scheme_bookmarks")
    op.drop_table("scheme_applications")
    op.drop_table("government_schemes")
    op.drop_table("carbon_reduction_actions")
    op.drop_table("carbon_records")
    op.drop_table("withdrawal_records")
    op.drop_table("outbreak_zones")
    op.drop_table("disease_reports")
    op.drop_table("listing_favorites")
    op.drop_table("listing_inquiries")
    op.drop_table("cattle_listings")
    for enum_name in [
        "listingcategory", "listingstatus", "inquirystatus",
        "reportseverity", "reportsource", "reportstatus", "outbreakseveritylevel",
        "administrationroute",
        "carbonactiontype",
        "schemecategory", "schemelevel", "schemeapplicationstatus",
        "mandicategory",
        "identificationmethod", "pashuregistrationstatus",
        "milkvariant", "labreportstatus", "violationseverity", "scoreband",
        "brandrequeststs",
    ]:
        op.execute(f"DROP TYPE IF EXISTS {enum_name}")
