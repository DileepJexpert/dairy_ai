"""Production schema alignment: add serviceable_pincodes, storefront_banners, and missing vendor/order columns.

Revision ID: production_schema_alignment_v14
Revises: customer_commerce_v13
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy import inspect

revision = 'production_schema_alignment_v14'
down_revision = 'customer_commerce_v13'
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = inspect(bind)

    # 1. Create serviceable_pincodes table if it doesn't exist
    if not insp.has_table("serviceable_pincodes"):
        op.create_table(
            "serviceable_pincodes",
            sa.Column("pincode", sa.String(6), primary_key=True),
            sa.Column("city", sa.String(100), nullable=False),
            sa.Column("state", sa.String(100), nullable=False),
            sa.Column("is_serviceable", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("delivery_days_min", sa.Integer(), nullable=False, server_default="1"),
            sa.Column("delivery_days_max", sa.Integer(), nullable=False, server_default="2"),
            sa.Column("express_available", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("delivery_fee", sa.Numeric(8, 2), nullable=False, server_default="0.00"),
            sa.Column("delivery_message", sa.String(250), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index("ix_serviceable_pincodes_pincode", "serviceable_pincodes", ["pincode"])
        op.create_index("ix_serviceable_pincodes_is_serviceable", "serviceable_pincodes", ["is_serviceable"])

    # 2. Create storefront_banners table if it doesn't exist
    if not insp.has_table("storefront_banners"):
        op.create_table(
            "storefront_banners",
            sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
            sa.Column("title", sa.String(200), nullable=False),
            sa.Column("subtitle", sa.String(300), nullable=True),
            sa.Column("image_url", sa.String(500), nullable=True),
            sa.Column("icon_name", sa.String(50), nullable=True),
            sa.Column("action_type", sa.String(20), nullable=False, server_default="category"),
            sa.Column("action_value", sa.String(200), nullable=False),
            sa.Column("bg_color", sa.String(9), nullable=False, server_default="#173f35"),
            sa.Column("text_color", sa.String(9), nullable=False, server_default="#ffffff"),
            sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("starts_at", sa.DateTime(), nullable=True),
            sa.Column("ends_at", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index("ix_storefront_banners_display_order", "storefront_banners", ["display_order"])
        op.create_index("ix_storefront_banners_is_active", "storefront_banners", ["is_active"])
        op.create_index("ix_storefront_banners_created_at", "storefront_banners", ["created_at"])

    # 3. Add missing columns to vendors table
    existing_vendor_cols = {c["name"] for c in insp.get_columns("vendors")}
    vendor_cols_to_add = [
        ("bank_name", sa.Column("bank_name", sa.String(100), nullable=True)),
        ("account_number", sa.Column("account_number", sa.String(50), nullable=True)),
        ("ifsc_code", sa.Column("ifsc_code", sa.String(20), nullable=True)),
        ("account_holder_name", sa.Column("account_holder_name", sa.String(100), nullable=True)),
        ("upi_id", sa.Column("upi_id", sa.String(100), nullable=True)),
        ("logo_url", sa.Column("logo_url", sa.String(500), nullable=True)),
        ("banner_url", sa.Column("banner_url", sa.String(500), nullable=True)),
        ("support_phone", sa.Column("support_phone", sa.String(30), nullable=True)),
        ("support_email", sa.Column("support_email", sa.String(100), nullable=True)),
        ("return_policy", sa.Column("return_policy", sa.Text(), nullable=True)),
        ("commission_rate", sa.Column("commission_rate", sa.Float(), server_default="5.0", nullable=False)),
    ]
    for col_name, col_obj in vendor_cols_to_add:
        if col_name not in existing_vendor_cols:
            op.add_column("vendors", col_obj)

    # 4. Add missing columns to orders table
    existing_order_cols = {c["name"] for c in insp.get_columns("orders")}
    order_cols_to_add = [
        ("return_reason", sa.Column("return_reason", sa.String(255), nullable=True)),
        ("return_status", sa.Column("return_status", sa.String(50), nullable=True)),
        ("return_requested_at", sa.Column("return_requested_at", sa.DateTime(), nullable=True)),
        ("return_processed_at", sa.Column("return_processed_at", sa.DateTime(), nullable=True)),
        ("return_remarks", sa.Column("return_remarks", sa.Text(), nullable=True)),
    ]
    for col_name, col_obj in order_cols_to_add:
        if col_name not in existing_order_cols:
            op.add_column("orders", col_obj)


def downgrade() -> None:
    pass
