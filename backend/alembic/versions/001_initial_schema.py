"""Initial schema — all tables for DairyAI platform.

Revision ID: 001_initial
Revises:
Create Date: 2026-03-28
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSON

revision = "001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── users ──
    op.create_table(
        "users",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("phone", sa.String(15), unique=True, nullable=False, index=True),
        sa.Column("otp_hash", sa.String(255), nullable=True),
        sa.Column("otp_expires_at", sa.DateTime, nullable=True),
        sa.Column("role", sa.Enum("farmer", "vet", "vendor", "cooperative", "admin", "super_admin", name="userrole"), nullable=False, server_default="farmer"),
        sa.Column("is_active", sa.Boolean, server_default="true"),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── farmers ──
    op.create_table(
        "farmers",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), unique=True, nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("village", sa.String(100)),
        sa.Column("district", sa.String(100)),
        sa.Column("state", sa.String(100)),
        sa.Column("language", sa.String(10), server_default="hi"),
        sa.Column("lat", sa.Float),
        sa.Column("lng", sa.Float),
        sa.Column("total_cattle", sa.Integer, server_default="0"),
        sa.Column("profile_photo_url", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── cattle ──
    op.create_table(
        "cattle",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("tag_id", sa.String(20), unique=True, nullable=False, index=True),
        sa.Column("name", sa.String(100)),
        sa.Column("breed", sa.Enum("gir", "sahiwal", "murrah", "hf_crossbred", "jersey_crossbred", "other", name="breed"), nullable=False),
        sa.Column("sex", sa.Enum("female", "male", name="sex"), server_default="female"),
        sa.Column("dob", sa.Date),
        sa.Column("weight_kg", sa.Float),
        sa.Column("photo_url", sa.String(500)),
        sa.Column("status", sa.Enum("active", "sold", "dead", "dry", name="cattlestatus"), server_default="active"),
        sa.Column("lactation_number", sa.Integer, server_default="0"),
        sa.Column("last_calving_date", sa.Date),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── health_records ──
    op.create_table(
        "health_records",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False, index=True),
        sa.Column("date", sa.Date, nullable=False),
        sa.Column("record_type", sa.Enum("checkup", "illness", "treatment", "surgery", "observation", name="recordtype"), nullable=False),
        sa.Column("symptoms", sa.Text),
        sa.Column("diagnosis", sa.Text),
        sa.Column("treatment", sa.Text),
        sa.Column("vet_id", UUID(as_uuid=True)),
        sa.Column("severity", sa.Integer),
        sa.Column("resolved", sa.Boolean, server_default="false"),
        sa.Column("notes", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── vaccinations ──
    op.create_table(
        "vaccinations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False, index=True),
        sa.Column("vaccine_name", sa.String(200), nullable=False),
        sa.Column("batch_number", sa.String(100)),
        sa.Column("date_given", sa.Date, nullable=False),
        sa.Column("next_due_date", sa.Date),
        sa.Column("administered_by", sa.String(200)),
        sa.Column("notes", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── sensor_readings (TimescaleDB hypertable in production) ──
    op.create_table(
        "sensor_readings",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("time", sa.DateTime, nullable=False, index=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False, index=True),
        sa.Column("temperature", sa.Float),
        sa.Column("heart_rate", sa.Integer),
        sa.Column("activity_level", sa.Float),
        sa.Column("rumination_minutes", sa.Integer),
        sa.Column("battery_pct", sa.Integer),
        sa.Column("rssi", sa.Integer),
    )
    # NOTE: In production, run: SELECT create_hypertable('sensor_readings', 'time');

    # ── milk_records ──
    op.create_table(
        "milk_records",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False, index=True),
        sa.Column("date", sa.Date, nullable=False, index=True),
        sa.Column("session", sa.Enum("morning", "evening", name="milksession"), nullable=False),
        sa.Column("quantity_litres", sa.Float, nullable=False),
        sa.Column("fat_pct", sa.Float),
        sa.Column("snf_pct", sa.Float),
        sa.Column("buyer_name", sa.String(200)),
        sa.Column("price_per_litre", sa.Float),
        sa.Column("total_amount", sa.Float),
        sa.Column("quality_grade", sa.String(5)),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── milk_prices ──
    op.create_table(
        "milk_prices",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("district", sa.String(100), nullable=False, index=True),
        sa.Column("state", sa.String(100)),
        sa.Column("buyer_name", sa.String(200), nullable=False),
        sa.Column("buyer_type", sa.Enum("cooperative", "private", "local", name="buyertype"), nullable=False),
        sa.Column("price_per_litre", sa.Float, nullable=False),
        sa.Column("fat_pct_basis", sa.Float),
        sa.Column("date", sa.Date, nullable=False),
        sa.Column("source", sa.String(200)),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── feed_plans ──
    op.create_table(
        "feed_plans",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False, index=True),
        sa.Column("plan", JSON, nullable=False),
        sa.Column("total_cost_per_day", sa.Float, nullable=False),
        sa.Column("nutrition_score", sa.Float),
        sa.Column("created_by", sa.String(20), server_default="ai"),
        sa.Column("valid_from", sa.Date, nullable=False),
        sa.Column("valid_to", sa.Date),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── breeding_records ──
    op.create_table(
        "breeding_records",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False, index=True),
        sa.Column("event_type", sa.Enum("heat_detected", "ai_done", "pregnancy_confirmed", "calving", "abortion", name="breedingeventtype"), nullable=False),
        sa.Column("date", sa.Date, nullable=False),
        sa.Column("bull_id", sa.String(100)),
        sa.Column("ai_technician", sa.String(200)),
        sa.Column("semen_batch", sa.String(100)),
        sa.Column("expected_calving_date", sa.Date),
        sa.Column("actual_calving_date", sa.Date),
        sa.Column("calf_id", UUID(as_uuid=True)),
        sa.Column("notes", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── transactions ──
    op.create_table(
        "transactions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("type", sa.Enum("income", "expense", name="transactiontype"), nullable=False),
        sa.Column("category", sa.Enum("milk_sale", "feed_purchase", "medicine", "vet_fee", "equipment", "subsidy", "loan_emi", "other", name="transactioncategory"), nullable=False),
        sa.Column("amount", sa.Float, nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("cattle_id", UUID(as_uuid=True)),
        sa.Column("date", sa.Date, nullable=False),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── vet_profiles ──
    op.create_table(
        "vet_profiles",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), unique=True, nullable=False),
        sa.Column("license_number", sa.String(100), unique=True, nullable=False),
        sa.Column("qualification", sa.Enum("bvsc", "mvsc", "phd", "paravet", name="qualification"), nullable=False),
        sa.Column("specializations", JSON),
        sa.Column("experience_years", sa.Integer, server_default="0"),
        sa.Column("languages", JSON),
        sa.Column("consultation_fee", sa.Float, server_default="0"),
        sa.Column("rating_avg", sa.Float, server_default="0"),
        sa.Column("total_consultations", sa.Integer, server_default="0"),
        sa.Column("total_earnings", sa.Float, server_default="0"),
        sa.Column("is_verified", sa.Boolean, server_default="false"),
        sa.Column("is_available", sa.Boolean, server_default="false"),
        sa.Column("availability_start", sa.String(10)),
        sa.Column("availability_end", sa.String(10)),
        sa.Column("bio", sa.Text),
        sa.Column("photo_url", sa.Text),
        sa.Column("certificate_url", sa.Text),
        sa.Column("pincode", sa.String(10), index=True),
        sa.Column("city", sa.String(100)),
        sa.Column("district", sa.String(100), index=True),
        sa.Column("state", sa.String(100)),
        sa.Column("address", sa.Text),
        sa.Column("lat", sa.Float),
        sa.Column("lng", sa.Float),
        sa.Column("service_radius_km", sa.Float, server_default="25"),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── consultations ──
    op.create_table(
        "consultations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False),
        sa.Column("vet_id", UUID(as_uuid=True), sa.ForeignKey("vet_profiles.id"), index=True),
        sa.Column("consultation_type", sa.Enum("video", "audio", "chat", "in_person", name="consultationtype"), server_default="video"),
        sa.Column("triage_severity", sa.Enum("low", "medium", "high", "emergency", name="triageseverity")),
        sa.Column("ai_diagnosis", sa.Text),
        sa.Column("ai_confidence", sa.Float),
        sa.Column("vet_diagnosis", sa.Text),
        sa.Column("vet_notes", sa.Text),
        sa.Column("status", sa.Enum("requested", "assigned", "in_progress", "completed", "cancelled", "no_show", name="consultationstatus"), server_default="requested"),
        sa.Column("symptoms", sa.Text),
        sa.Column("agora_channel_name", sa.String(255)),
        sa.Column("agora_token", sa.String(500)),
        sa.Column("started_at", sa.DateTime),
        sa.Column("ended_at", sa.DateTime),
        sa.Column("duration_seconds", sa.Integer),
        sa.Column("fee_amount", sa.Float),
        sa.Column("platform_fee", sa.Float),
        sa.Column("vet_payout", sa.Float),
        sa.Column("farmer_rating", sa.Integer),
        sa.Column("farmer_review", sa.Text),
        sa.Column("follow_up_date", sa.Date),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── prescriptions ──
    op.create_table(
        "prescriptions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("consultation_id", UUID(as_uuid=True), sa.ForeignKey("consultations.id"), nullable=False, index=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False),
        sa.Column("vet_id", UUID(as_uuid=True), sa.ForeignKey("vet_profiles.id"), nullable=False),
        sa.Column("medicines", JSON),
        sa.Column("instructions", sa.Text),
        sa.Column("follow_up_date", sa.Date),
        sa.Column("is_fulfilled", sa.Boolean, server_default="false"),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── conversations ──
    op.create_table(
        "conversations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id")),
        sa.Column("channel", sa.Enum("whatsapp", "app", "voice", name="channel"), nullable=False),
        sa.Column("messages", JSON),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── notifications ──
    op.create_table(
        "notifications",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("type", sa.Enum("health_alert", "vaccination_due", "consultation_request", "payment", "general", name="notificationtype"), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("body", sa.Text, nullable=False),
        sa.Column("data", JSON),
        sa.Column("is_read", sa.Boolean, server_default="false"),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── vendors ──
    op.create_table(
        "vendors",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), unique=True, nullable=False),
        sa.Column("business_name", sa.String(200), nullable=False),
        sa.Column("vendor_type", sa.Enum("milk_buyer", "feed_supplier", "medicine_supplier", "equipment_supplier", "ai_technician", "other", name="vendortype"), nullable=False),
        sa.Column("contact_person", sa.String(100)),
        sa.Column("address", sa.Text),
        sa.Column("district", sa.String(100)),
        sa.Column("state", sa.String(100)),
        sa.Column("gst_number", sa.String(20)),
        sa.Column("license_number", sa.String(100)),
        sa.Column("description", sa.Text),
        sa.Column("products_services", JSON),
        sa.Column("service_areas", JSON),
        sa.Column("rating_avg", sa.Float, server_default="0"),
        sa.Column("total_orders", sa.Integer, server_default="0"),
        sa.Column("total_revenue", sa.Float, server_default="0"),
        sa.Column("is_verified", sa.Boolean, server_default="false"),
        sa.Column("is_active", sa.Boolean, server_default="true"),
        sa.Column("lat", sa.Float),
        sa.Column("lng", sa.Float),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── cooperatives ──
    op.create_table(
        "cooperatives",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), unique=True, nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("registration_number", sa.String(100), unique=True, nullable=False),
        sa.Column("cooperative_type", sa.Enum("milk_collection", "dairy_processing", "multi_purpose", "marketing", name="cooperativetype"), nullable=False),
        sa.Column("chairman_name", sa.String(100)),
        sa.Column("secretary_name", sa.String(100)),
        sa.Column("address", sa.Text),
        sa.Column("village", sa.String(100)),
        sa.Column("district", sa.String(100)),
        sa.Column("state", sa.String(100)),
        sa.Column("total_members", sa.Integer, server_default="0"),
        sa.Column("total_milk_collected_litres", sa.Float, server_default="0"),
        sa.Column("total_revenue", sa.Float, server_default="0"),
        sa.Column("total_payouts", sa.Float, server_default="0"),
        sa.Column("milk_price_per_litre", sa.Float, server_default="0"),
        sa.Column("collection_centers", JSON),
        sa.Column("services_offered", JSON),
        sa.Column("is_verified", sa.Boolean, server_default="false"),
        sa.Column("is_active", sa.Boolean, server_default="true"),
        sa.Column("lat", sa.Float),
        sa.Column("lng", sa.Float),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── collection_centers ──
    op.create_table(
        "collection_centers",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("code", sa.String(20), unique=True, nullable=False),
        sa.Column("cooperative_id", UUID(as_uuid=True), sa.ForeignKey("cooperatives.id"), index=True),
        sa.Column("address", sa.Text),
        sa.Column("village", sa.String(100)),
        sa.Column("district", sa.String(100), index=True),
        sa.Column("state", sa.String(100)),
        sa.Column("pincode", sa.String(10)),
        sa.Column("lat", sa.Float),
        sa.Column("lng", sa.Float),
        sa.Column("capacity_litres", sa.Float, server_default="500"),
        sa.Column("current_stock_litres", sa.Float, server_default="0"),
        sa.Column("chilling_temp_celsius", sa.Float, server_default="4"),
        sa.Column("has_fat_analyzer", sa.Boolean, server_default="false"),
        sa.Column("has_snf_analyzer", sa.Boolean, server_default="false"),
        sa.Column("manager_name", sa.String(100)),
        sa.Column("manager_phone", sa.String(15)),
        sa.Column("status", sa.Enum("active", "inactive", "maintenance", name="centerstatus"), server_default="active"),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── milk_collections ──
    op.create_table(
        "milk_collections",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("center_id", UUID(as_uuid=True), sa.ForeignKey("collection_centers.id"), nullable=False, index=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("date", sa.Date, nullable=False, index=True),
        sa.Column("shift", sa.Enum("morning", "evening", name="collectionshift"), nullable=False),
        sa.Column("quantity_litres", sa.Float, nullable=False),
        sa.Column("fat_pct", sa.Float),
        sa.Column("snf_pct", sa.Float),
        sa.Column("temperature_celsius", sa.Float),
        sa.Column("milk_grade", sa.Enum("A", "B", "C", "rejected", name="milkgrade")),
        sa.Column("rate_per_litre", sa.Float),
        sa.Column("total_amount", sa.Float),
        sa.Column("quality_bonus", sa.Float, server_default="0"),
        sa.Column("deductions", sa.Float, server_default="0"),
        sa.Column("net_amount", sa.Float),
        sa.Column("is_rejected", sa.Boolean, server_default="false"),
        sa.Column("rejection_reason", sa.String(200)),
        sa.Column("collected_by", sa.String(100)),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── collection_routes ──
    op.create_table(
        "collection_routes",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("date", sa.Date, nullable=False, index=True),
        sa.Column("shift", sa.Enum("morning", "evening", name="collectionshift", create_type=False), nullable=False),
        sa.Column("vehicle_number", sa.String(20)),
        sa.Column("driver_name", sa.String(100)),
        sa.Column("driver_phone", sa.String(15)),
        sa.Column("center_ids", JSON),
        sa.Column("waypoints", JSON),
        sa.Column("total_distance_km", sa.Float),
        sa.Column("estimated_duration_mins", sa.Integer),
        sa.Column("actual_start_time", sa.DateTime),
        sa.Column("actual_end_time", sa.DateTime),
        sa.Column("total_collected_litres", sa.Float, server_default="0"),
        sa.Column("status", sa.Enum("planned", "in_progress", "completed", "cancelled", name="routestatus"), server_default="planned"),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── cold_chain_readings ──
    op.create_table(
        "cold_chain_readings",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("center_id", UUID(as_uuid=True), sa.ForeignKey("collection_centers.id"), index=True),
        sa.Column("route_id", UUID(as_uuid=True), sa.ForeignKey("collection_routes.id"), index=True),
        sa.Column("temperature_celsius", sa.Float, nullable=False),
        sa.Column("humidity_pct", sa.Float),
        sa.Column("recorded_at", sa.DateTime, server_default=sa.func.now(), index=True),
        sa.Column("device_id", sa.String(50)),
        sa.Column("is_alert", sa.Boolean, server_default="false"),
    )

    # ── cold_chain_alerts ──
    op.create_table(
        "cold_chain_alerts",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("center_id", UUID(as_uuid=True), sa.ForeignKey("collection_centers.id"), index=True),
        sa.Column("route_id", UUID(as_uuid=True), sa.ForeignKey("collection_routes.id"), index=True),
        sa.Column("temperature_celsius", sa.Float, nullable=False),
        sa.Column("threshold_celsius", sa.Float, server_default="4"),
        sa.Column("severity", sa.Enum("info", "warning", "critical", name="alertseverity"), server_default="warning"),
        sa.Column("status", sa.Enum("active", "acknowledged", "resolved", name="alertstatus"), server_default="active"),
        sa.Column("message", sa.String(500), nullable=False),
        sa.Column("acknowledged_by", sa.String(100)),
        sa.Column("resolved_at", sa.DateTime),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── payment_cycles ──
    op.create_table(
        "payment_cycles",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cooperative_id", UUID(as_uuid=True), sa.ForeignKey("cooperatives.id"), index=True),
        sa.Column("cycle_type", sa.Enum("weekly", "fortnightly", "monthly", name="paymentcycletype"), nullable=False),
        sa.Column("period_start", sa.Date, nullable=False),
        sa.Column("period_end", sa.Date, nullable=False),
        sa.Column("total_litres", sa.Float, server_default="0"),
        sa.Column("total_amount", sa.Float, server_default="0"),
        sa.Column("total_deductions", sa.Float, server_default="0"),
        sa.Column("total_bonuses", sa.Float, server_default="0"),
        sa.Column("net_payout", sa.Float, server_default="0"),
        sa.Column("farmers_count", sa.Integer, server_default="0"),
        sa.Column("status", sa.Enum("pending", "processing", "completed", "failed", name="paymentstatus"), server_default="pending"),
        sa.Column("processed_at", sa.DateTime),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── farmer_payments ──
    op.create_table(
        "farmer_payments",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("cycle_id", UUID(as_uuid=True), sa.ForeignKey("payment_cycles.id"), nullable=False, index=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("total_litres", sa.Float, server_default="0"),
        sa.Column("avg_fat_pct", sa.Float),
        sa.Column("avg_snf_pct", sa.Float),
        sa.Column("base_amount", sa.Float, server_default="0"),
        sa.Column("quality_bonus", sa.Float, server_default="0"),
        sa.Column("loan_deduction", sa.Float, server_default="0"),
        sa.Column("other_deductions", sa.Float, server_default="0"),
        sa.Column("net_amount", sa.Float, server_default="0"),
        sa.Column("payment_method", sa.Enum("upi", "bank_transfer", "cash", "cheque", name="paymentmethod")),
        sa.Column("upi_id", sa.String(100)),
        sa.Column("bank_account", sa.String(20)),
        sa.Column("bank_ifsc", sa.String(15)),
        sa.Column("transaction_ref", sa.String(100)),
        sa.Column("status", sa.Enum("pending", "processing", "completed", "failed", name="paymentstatus", create_type=False), server_default="pending"),
        sa.Column("paid_at", sa.DateTime),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── loans ──
    op.create_table(
        "loans",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("loan_type", sa.Enum("cattle_purchase", "feed_advance", "equipment", "emergency", "dairy_infra", name="loantype"), nullable=False),
        sa.Column("principal_amount", sa.Float, nullable=False),
        sa.Column("interest_rate_pct", sa.Float, server_default="0"),
        sa.Column("tenure_months", sa.Integer, nullable=False),
        sa.Column("emi_amount", sa.Float, server_default="0"),
        sa.Column("total_paid", sa.Float, server_default="0"),
        sa.Column("outstanding_amount", sa.Float, server_default="0"),
        sa.Column("disbursed_at", sa.Date),
        sa.Column("next_emi_date", sa.Date),
        sa.Column("status", sa.Enum("applied", "approved", "disbursed", "active", "closed", "defaulted", "rejected", name="loanstatus"), server_default="applied"),
        sa.Column("purpose", sa.Text),
        sa.Column("approved_by", sa.String(100)),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── subsidy_applications ──
    op.create_table(
        "subsidy_applications",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("scheme", sa.Enum("nabard_dairy", "ndp_ii", "didf", "state_scheme", "pmmsy", "other", name="subsidyscheme"), nullable=False),
        sa.Column("scheme_name", sa.String(200), nullable=False),
        sa.Column("applied_amount", sa.Float, nullable=False),
        sa.Column("approved_amount", sa.Float),
        sa.Column("disbursed_amount", sa.Float),
        sa.Column("application_ref", sa.String(100)),
        sa.Column("documents", JSON),
        sa.Column("status", sa.Enum("identified", "applied", "documents_submitted", "under_review", "approved", "disbursed", "rejected", name="subsidystatus"), server_default="identified"),
        sa.Column("applied_at", sa.Date),
        sa.Column("approved_at", sa.Date),
        sa.Column("disbursed_at", sa.Date),
        sa.Column("rejection_reason", sa.Text),
        sa.Column("notes", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )

    # ── cattle_insurance ──
    op.create_table(
        "cattle_insurance",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id"), nullable=False, index=True),
        sa.Column("cattle_id", UUID(as_uuid=True), sa.ForeignKey("cattle.id"), nullable=False, index=True),
        sa.Column("policy_number", sa.String(100), unique=True, nullable=False),
        sa.Column("insurer_name", sa.String(200), nullable=False),
        sa.Column("sum_insured", sa.Float, nullable=False),
        sa.Column("premium_amount", sa.Float, nullable=False),
        sa.Column("govt_subsidy_pct", sa.Float, server_default="0"),
        sa.Column("farmer_premium", sa.Float, server_default="0"),
        sa.Column("start_date", sa.Date, nullable=False),
        sa.Column("end_date", sa.Date, nullable=False),
        sa.Column("status", sa.Enum("active", "expired", "claimed", "claim_processing", "claim_approved", "claim_rejected", name="insurancestatus"), server_default="active"),
        sa.Column("claim_amount", sa.Float),
        sa.Column("claim_reason", sa.Text),
        sa.Column("claim_date", sa.Date),
        sa.Column("claim_approved_amount", sa.Float),
        sa.Column("ear_tag_photo_url", sa.Text),
        sa.Column("cattle_photo_url", sa.Text),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("cattle_insurance")
    op.drop_table("subsidy_applications")
    op.drop_table("loans")
    op.drop_table("farmer_payments")
    op.drop_table("payment_cycles")
    op.drop_table("cold_chain_alerts")
    op.drop_table("cold_chain_readings")
    op.drop_table("collection_routes")
    op.drop_table("milk_collections")
    op.drop_table("collection_centers")
    op.drop_table("cooperatives")
    op.drop_table("vendors")
    op.drop_table("notifications")
    op.drop_table("conversations")
    op.drop_table("prescriptions")
    op.drop_table("consultations")
    op.drop_table("vet_profiles")
    op.drop_table("transactions")
    op.drop_table("breeding_records")
    op.drop_table("feed_plans")
    op.drop_table("milk_prices")
    op.drop_table("milk_records")
    op.drop_table("sensor_readings")
    op.drop_table("vaccinations")
    op.drop_table("health_records")
    op.drop_table("cattle")
    op.drop_table("farmers")
    op.drop_table("users")
    # Drop enums
    for enum_name in [
        "userrole", "breed", "sex", "cattlestatus", "recordtype",
        "milksession", "buyertype", "breedingeventtype", "transactiontype",
        "transactioncategory", "qualification", "consultationtype",
        "triageseverity", "consultationstatus", "channel", "notificationtype",
        "vendortype", "cooperativetype", "centerstatus", "collectionshift",
        "milkgrade", "routestatus", "alertseverity", "alertstatus",
        "paymentcycletype", "paymentstatus", "paymentmethod",
        "loanstatus", "loantype", "subsidystatus", "subsidyscheme",
        "insurancestatus",
    ]:
        op.execute(f"DROP TYPE IF EXISTS {enum_name}")
