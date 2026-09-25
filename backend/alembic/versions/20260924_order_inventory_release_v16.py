"""Guard commerce stock release and record checkout payment references.

Revision ID: order_inventory_release_v16
Revises: commerce_shipping_v15
"""
from alembic import op
import sqlalchemy as sa

revision = "order_inventory_release_v16"
down_revision = "commerce_shipping_v15"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "orders",
        sa.Column("inventory_released", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column("orders", sa.Column("is_cod", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("commerce_order_contact", sa.Column("payment_link_id", sa.String(length=100), nullable=True))
    op.add_column("commerce_order_contact", sa.Column("payment_link_reference", sa.String(length=40), nullable=True))
    op.add_column("commerce_order_contact", sa.Column("payment_link_url", sa.String(length=500), nullable=True))
    op.add_column("commerce_order_contact", sa.Column("payment_reference", sa.String(length=100), nullable=True))
    # Existing terminal orders may already have restored stock. Treat them as
    # released so a later staff action cannot credit their inventory again.
    op.execute(
        "UPDATE orders SET inventory_released = TRUE "
        "WHERE status::text IN ('cancelled', 'CANCELLED') "
        "OR payment_status::text IN ('refunded', 'REFUNDED') "
        "OR return_status IN ('RETURN_COMPLETED', 'RTO_DELIVERED')"
    )


def downgrade() -> None:
    op.drop_column("commerce_order_contact", "payment_reference")
    op.drop_column("commerce_order_contact", "payment_link_url")
    op.drop_column("commerce_order_contact", "payment_link_reference")
    op.drop_column("commerce_order_contact", "payment_link_id")
    op.drop_column("orders", "is_cod")
    op.drop_column("orders", "inventory_released")
