"""add saved delivery addresses

Revision ID: delivery_addresses_v5
Revises: cart_feature_v4
Create Date: 2026-09-04
"""

from alembic import op
import sqlalchemy as sa

revision = "delivery_addresses_v5"
down_revision = "cart_feature_v4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "delivery_addresses",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("recipient_name", sa.String(120), nullable=False),
        sa.Column("phone", sa.String(20), nullable=False),
        sa.Column("address_line1", sa.String(250), nullable=False),
        sa.Column("address_line2", sa.String(250)),
        sa.Column("landmark", sa.String(160)),
        sa.Column("village_or_city", sa.String(120), nullable=False),
        sa.Column("district", sa.String(120), nullable=False),
        sa.Column("state", sa.String(120), nullable=False),
        sa.Column("postal_code", sa.String(10), nullable=False),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_delivery_addresses_user_id", "delivery_addresses", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_delivery_addresses_user_id", table_name="delivery_addresses")
    op.drop_table("delivery_addresses")
