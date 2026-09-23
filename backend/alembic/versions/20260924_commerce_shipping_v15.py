"""Persist courier bookings and tracking events independently of orders.

Revision ID: commerce_shipping_v15
Revises: production_schema_alignment_v14
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "commerce_shipping_v15"
down_revision = "production_schema_alignment_v14"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "commerce_shipments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("order_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False),
        sa.Column("mode", sa.String(12), nullable=False),
        sa.Column("status", sa.String(32), nullable=False),
        sa.Column("courier_code", sa.String(40)),
        sa.Column("courier_name", sa.String(100)),
        sa.Column("awb", sa.String(100)),
        sa.Column("provider_order_id", sa.String(100)),
        sa.Column("label_url", sa.String(1000)),
        sa.Column("quoted_cost", sa.Numeric(10, 2)),
        sa.Column("customer_fee", sa.Numeric(10, 2), nullable=False),
        sa.Column("weight_grams", sa.Integer()),
        sa.Column("package", sa.JSON(), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("last_error", sa.Text()),
        sa.Column("next_attempt_at", sa.DateTime()),
        sa.Column("claimed_at", sa.DateTime()),
        sa.Column("ready_at", sa.DateTime()),
        sa.Column("booked_at", sa.DateTime()),
        sa.Column("picked_up_at", sa.DateTime()),
        sa.Column("delivered_at", sa.DateTime()),
        sa.Column("last_tracking_at", sa.DateTime()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("order_id", name="uq_commerce_shipment_order"),
        sa.UniqueConstraint("courier_name", "awb", name="uq_commerce_shipment_carrier_awb"),
    )
    op.create_index("ix_commerce_shipments_order_id", "commerce_shipments", ["order_id"])
    op.create_index("ix_commerce_shipments_status", "commerce_shipments", ["status"])
    op.create_table(
        "commerce_shipment_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("shipment_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("commerce_shipments.id", ondelete="CASCADE"), nullable=False),
        sa.Column("external_key", sa.String(200), nullable=False),
        sa.Column("status", sa.String(40), nullable=False),
        sa.Column("description", sa.String(500), nullable=False),
        sa.Column("location", sa.String(200), nullable=False),
        sa.Column("occurred_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("shipment_id", "external_key", name="uq_shipment_event_external"),
    )
    op.create_index("ix_commerce_shipment_events_shipment_id", "commerce_shipment_events", ["shipment_id"])


def downgrade() -> None:
    op.drop_index("ix_commerce_shipment_events_shipment_id", table_name="commerce_shipment_events")
    op.drop_table("commerce_shipment_events")
    op.drop_index("ix_commerce_shipments_status", table_name="commerce_shipments")
    op.drop_index("ix_commerce_shipments_order_id", table_name="commerce_shipments")
    op.drop_table("commerce_shipments")
