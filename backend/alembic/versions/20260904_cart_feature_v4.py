"""add product shopping cart

Revision ID: cart_feature_v4
Revises: product_catalog_v2
Create Date: 2026-09-04
"""

from alembic import op
import sqlalchemy as sa

revision = "cart_feature_v4"
down_revision = "product_catalog_v2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    cart_status = sa.Enum("ACTIVE", "CHECKED_OUT", "ABANDONED", name="cartstatus")
    op.create_table(
        "carts",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("status", cart_status, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("user_id", "status", name="uq_cart_user_status"),
    )
    op.create_index("ix_carts_user_id", "carts", ["user_id"])
    op.create_table(
        "cart_items",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("cart_id", sa.Uuid(), sa.ForeignKey("carts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", sa.Uuid(), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("price_when_added", sa.Numeric(12, 2), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("quantity > 0", name="ck_cart_item_positive_quantity"),
        sa.UniqueConstraint("cart_id", "product_id", name="uq_cart_item_product"),
    )
    op.create_index("ix_cart_items_cart_id", "cart_items", ["cart_id"])


def downgrade() -> None:
    op.drop_index("ix_cart_items_cart_id", table_name="cart_items")
    op.drop_table("cart_items")
    op.drop_index("ix_carts_user_id", table_name="carts")
    op.drop_table("carts")
    sa.Enum(name="cartstatus").drop(op.get_bind(), checkfirst=True)
