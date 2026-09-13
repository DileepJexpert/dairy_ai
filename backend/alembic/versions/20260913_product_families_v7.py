"""Add product families and variant catalogue fields.

Revision ID: product_families_v7
Revises: orders_v6
"""

import uuid

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "product_families_v7"
down_revision = "orders_v6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "product_families",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("vendor_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("vendors.id"), nullable=False),
        sa.Column("slug", sa.String(120), nullable=False, unique=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("brand", sa.String(100), nullable=False, server_default="MILTERRA"),
        sa.Column("department", sa.String(100), nullable=False, server_default="Dairy Foods"),
        sa.Column("collection", sa.String(100)),
        sa.Column("milk_source", sa.String(50)),
        sa.Column("production_method", sa.String(100)),
        sa.Column("ingredients", sa.Text()),
        sa.Column("description", sa.Text()),
        sa.Column("is_published", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_concept", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("supporting_documents", sa.JSON(), nullable=False, server_default=sa.text("'{}'::json")),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_product_families_vendor_id", "product_families", ["vendor_id"])
    op.create_index("ix_product_families_title", "product_families", ["title"])
    op.create_index("ix_product_families_is_published", "product_families", ["is_published"])

    op.add_column("products", sa.Column("family_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.create_foreign_key("fk_products_family_id", "products", "product_families", ["family_id"], ["id"])
    op.create_index("ix_products_family_id", "products", ["family_id"])
    op.add_column("products", sa.Column("compare_at_price", sa.Numeric(12, 2), nullable=True))
    op.add_column("products", sa.Column("weight_grams", sa.Integer(), nullable=True))
    op.add_column(
        "products",
        sa.Column("publication_status", sa.String(30), nullable=False, server_default="published"),
    )
    op.create_index("ix_products_publication_status", "products", ["publication_status"])

    # Preserve existing product UUIDs. If the known variants belong to one
    # vendor, group them into a family without rewriting carts, orders, or URLs.
    bind = op.get_bind()
    groups = (
        ("milterra-cow-ghee", "MILTERRA Cow Ghee", ("MIL-GHEE-500", "MIL-GHEE-1000", "MIL-GHEE-5000")),
        ("milterra-buffalo-ghee", "MILTERRA Buffalo Ghee", ("MIL-BUFF-500", "MIL-BUFF-1000")),
        ("milterra-fresh-paneer", "Milterra Fresh Paneer", ("MIL-PANEER-200",)),
    )
    for slug, title, skus in groups:
        rows = bind.execute(
            sa.text("SELECT DISTINCT vendor_id FROM products WHERE sku = ANY(:skus)"),
            {"skus": list(skus)},
        ).fetchall()
        if len(rows) != 1:
            continue
        family_id = uuid.uuid4()
        bind.execute(
            sa.text(
                "INSERT INTO product_families "
                "(id, vendor_id, slug, title, brand, department, collection, is_published, is_concept, "
                "supporting_documents, created_at, updated_at) "
                "VALUES (:id, :vendor_id, :slug, :title, 'MILTERRA', 'Dairy Foods', :collection, "
                "TRUE, FALSE, '{}'::json, NOW(), NOW())"
            ),
            {"id": family_id, "vendor_id": rows[0][0], "slug": slug, "title": title,
             "collection": "Paneer" if "paneer" in slug else "Ghee"},
        )
        bind.execute(
            sa.text("UPDATE products SET family_id = :family_id WHERE sku = ANY(:skus)"),
            {"family_id": family_id, "skus": list(skus)},
        )


def downgrade() -> None:
    op.drop_index("ix_products_publication_status", table_name="products")
    op.drop_column("products", "publication_status")
    op.drop_column("products", "weight_grams")
    op.drop_column("products", "compare_at_price")
    op.drop_index("ix_products_family_id", table_name="products")
    op.drop_constraint("fk_products_family_id", "products", type_="foreignkey")
    op.drop_column("products", "family_id")
    op.drop_table("product_families")
