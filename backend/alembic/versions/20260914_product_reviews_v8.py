"""Store product feedback and identify pre-launch interest in PostgreSQL.

Revision ID: product_reviews_v8
Revises: product_families_v7
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "product_reviews_v8"
down_revision = "product_families_v7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("password_hash", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "orders",
        sa.Column(
            "is_prelaunch_interest",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.create_index(
        "ix_orders_is_prelaunch_interest",
        "orders",
        ["is_prelaunch_interest"],
    )
    op.create_table(
        "product_reviews",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "product_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("products.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("author_name", sa.String(120), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column("headline", sa.String(160), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "source_label",
            sa.String(80),
            nullable=False,
            server_default="Visitor feedback",
        ),
        sa.Column("is_seeded", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_approved", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("rating BETWEEN 1 AND 5", name="ck_product_reviews_rating"),
    )
    op.create_index("ix_product_reviews_product_id", "product_reviews", ["product_id"])
    op.create_index("ix_product_reviews_is_approved", "product_reviews", ["is_approved"])
    op.create_index("ix_product_reviews_created_at", "product_reviews", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_product_reviews_created_at", table_name="product_reviews")
    op.drop_index("ix_product_reviews_is_approved", table_name="product_reviews")
    op.drop_index("ix_product_reviews_product_id", table_name="product_reviews")
    op.drop_table("product_reviews")
    op.drop_index("ix_orders_is_prelaunch_interest", table_name="orders")
    op.drop_column("orders", "is_prelaunch_interest")
    op.drop_column("users", "password_hash")
