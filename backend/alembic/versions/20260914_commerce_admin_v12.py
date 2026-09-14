"""Persist commerce coupons, redemptions, certificates and audit history.

Revision ID: commerce_admin_v12
Revises: concept_feedback_v11
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "commerce_admin_v12"
down_revision = "concept_feedback_v11"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("commerce_coupons",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("code", sa.String(40), nullable=False, unique=True),
        sa.Column("description", sa.String(500), nullable=False),
        sa.Column("discount_type", sa.String(20), nullable=False),
        sa.Column("discount_value", sa.Numeric(12, 2), nullable=False),
        sa.Column("min_order_value", sa.Numeric(12, 2), nullable=False),
        sa.Column("max_discount_cap", sa.Numeric(12, 2)),
        sa.Column("valid_until", sa.DateTime()),
        sa.Column("is_active", sa.Boolean(), nullable=False))
    op.create_table("order_coupons",
        sa.Column("order_id", UUID(as_uuid=True), sa.ForeignKey("orders.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("coupon_id", UUID(as_uuid=True), sa.ForeignKey("commerce_coupons.id"), nullable=False),
        sa.Column("code", sa.String(40), nullable=False),
        sa.Column("discount", sa.Numeric(12, 2), nullable=False))
    op.create_index("ix_order_coupons_coupon_id", "order_coupons", ["coupon_id"])
    op.create_table("commerce_certificates",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("product_id", UUID(as_uuid=True), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("batch_number", sa.String(100), unique=True, nullable=False),
        sa.Column("test_date", sa.DateTime(), nullable=False),
        sa.Column("laboratory", sa.String(200), nullable=False),
        sa.Column("fssai_license", sa.String(100), nullable=False),
        sa.Column("purity_percent", sa.Numeric(5, 2)),
        sa.Column("test_parameters", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(30), nullable=False),
        sa.Column("certified_by", sa.String(200), nullable=False),
        sa.Column("remarks", sa.Text(), nullable=False),
        sa.Column("report_url", sa.String(1000)))
    op.create_index("ix_commerce_certificates_product_id", "commerce_certificates", ["product_id"])
    op.create_table("commerce_audit",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("actor_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("user_role", sa.String(40), nullable=False),
        sa.Column("action", sa.String(40), nullable=False),
        sa.Column("entity_type", sa.String(60), nullable=False),
        sa.Column("entity_id", sa.String(100), nullable=False),
        sa.Column("details", sa.Text(), nullable=False),
        sa.Column("timestamp", sa.DateTime(), nullable=False))


def downgrade():
    op.drop_table("commerce_audit")
    op.drop_table("commerce_certificates")
    op.drop_table("order_coupons")
    op.drop_table("commerce_coupons")
