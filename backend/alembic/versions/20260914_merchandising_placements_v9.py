"""Add admin-controlled storefront merchandising placements.

Revision ID: merchandising_placements_v9
Revises: product_reviews_v8
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "merchandising_placements_v9"
down_revision = "product_reviews_v8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "merchandising_placements",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "product_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("products.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("placement_type", sa.String(30), nullable=False),
        sa.Column("headline", sa.String(180), nullable=False),
        sa.Column("subheadline", sa.String(300), nullable=True),
        sa.Column("badge", sa.String(60), nullable=True),
        sa.Column("starts_at", sa.DateTime(), nullable=True),
        sa.Column("ends_at", sa.DateTime(), nullable=True),
        sa.Column("priority", sa.Integer(), nullable=False, server_default="100"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_by_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "placement_type IN ('highlight', 'deal', 'new_launch', 'festival_offer')",
            name="ck_merchandising_placement_type",
        ),
        sa.CheckConstraint(
            "priority BETWEEN 0 AND 1000",
            name="ck_merchandising_priority",
        ),
    )
    op.create_index(
        "ix_merchandising_placements_product_id",
        "merchandising_placements",
        ["product_id"],
    )
    op.create_index(
        "ix_merchandising_placements_placement_type",
        "merchandising_placements",
        ["placement_type"],
    )
    op.create_index(
        "ix_merchandising_placements_is_active",
        "merchandising_placements",
        ["is_active"],
    )
    op.create_index(
        "ix_merchandising_placements_created_at",
        "merchandising_placements",
        ["created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_merchandising_placements_created_at",
        table_name="merchandising_placements",
    )
    op.drop_index(
        "ix_merchandising_placements_is_active",
        table_name="merchandising_placements",
    )
    op.drop_index(
        "ix_merchandising_placements_placement_type",
        table_name="merchandising_placements",
    )
    op.drop_index(
        "ix_merchandising_placements_product_id",
        table_name="merchandising_placements",
    )
    op.drop_table("merchandising_placements")
