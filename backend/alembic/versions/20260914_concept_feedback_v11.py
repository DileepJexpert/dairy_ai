"""Persist concept feedback and update registrations.

Revision ID: concept_feedback_v11
Revises: customer_identity_v10
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "concept_feedback_v11"
down_revision = "customer_identity_v10"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "concept_feedback",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("concept_key", sa.String(120), nullable=False),
        sa.Column("concept_title", sa.String(200), nullable=False),
        sa.Column("visitor_name", sa.String(120), nullable=False),
        sa.Column("email", sa.String(254), nullable=True),
        sa.Column("phone", sa.String(15), nullable=True),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column("wants_updates", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_concept_feedback_concept_key", "concept_feedback", ["concept_key"])
    op.create_index("ix_concept_feedback_created_at", "concept_feedback", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_concept_feedback_created_at", table_name="concept_feedback")
    op.drop_index("ix_concept_feedback_concept_key", table_name="concept_feedback")
    op.drop_table("concept_feedback")
