"""add product catalog

Revision ID: product_catalog_v2
Revises: 002_new_modules
"""
from alembic import op
import sqlalchemy as sa
revision="product_catalog_v2"; down_revision="002_new_modules"; branch_labels=None; depends_on=None
def upgrade():
 category=sa.Enum("EQUIPMENT","FEED_NUTRITION",name="productcategory"); media=sa.Enum("image","video",name="mediatype")
 op.create_table("products",sa.Column("id",sa.Uuid(),primary_key=True),sa.Column("vendor_id",sa.Uuid(),sa.ForeignKey("vendors.id"),nullable=False),sa.Column("sku",sa.String(100),unique=True,nullable=False),sa.Column("title",sa.String(200),nullable=False),sa.Column("slug",sa.String(240),nullable=False),sa.Column("category",category,nullable=False),sa.Column("subcategory",sa.String(100)),sa.Column("brand",sa.String(100)),sa.Column("description",sa.Text()),sa.Column("short_description",sa.String(500)),sa.Column("base_price",sa.Numeric(12,2),nullable=False),sa.Column("gst_rate",sa.Numeric(5,2)),sa.Column("unit",sa.String(30),nullable=False),sa.Column("pack_size",sa.String(100)),sa.Column("specifications",sa.JSON()),sa.Column("is_active",sa.Boolean(),nullable=False,server_default=sa.true()),sa.Column("is_featured",sa.Boolean(),nullable=False,server_default=sa.false()),sa.Column("is_rentable",sa.Boolean(),nullable=False,server_default=sa.false()),sa.Column("rental_rate_per_hour",sa.Numeric(12,2)),sa.Column("rental_rate_per_acre",sa.Numeric(12,2)),sa.Column("min_order_quantity",sa.Integer(),nullable=False,server_default="1"),sa.Column("created_at",sa.DateTime(),nullable=False),sa.Column("updated_at",sa.DateTime(),nullable=False))
 for col in ["vendor_id","category","slug","is_active","created_at"]:op.create_index(f"ix_products_{col}","products",[col])
 op.create_table("product_inventory",sa.Column("id",sa.Uuid(),primary_key=True),sa.Column("product_id",sa.Uuid(),sa.ForeignKey("products.id"),nullable=False,unique=True),sa.Column("available_quantity",sa.Integer(),nullable=False,server_default="0"),sa.Column("reserved_quantity",sa.Integer(),nullable=False,server_default="0"),sa.Column("reorder_level",sa.Integer(),nullable=False,server_default="0"),sa.Column("warehouse_location",sa.String(200)),sa.Column("batch_number",sa.String(100)),sa.Column("manufacture_date",sa.Date()),sa.Column("expiry_date",sa.Date()),sa.Column("updated_at",sa.DateTime(),nullable=False));op.create_index("ix_product_inventory_product_id","product_inventory",["product_id"])
 op.create_table("product_media",sa.Column("id",sa.Uuid(),primary_key=True),sa.Column("product_id",sa.Uuid(),sa.ForeignKey("products.id"),nullable=False),sa.Column("media_type",media,nullable=False),sa.Column("url",sa.String(500),nullable=False),sa.Column("sort_order",sa.Integer(),nullable=False,server_default="0"),sa.Column("is_primary",sa.Boolean(),nullable=False,server_default=sa.false()))
def downgrade():
 op.drop_table("product_media");op.drop_table("product_inventory");op.drop_table("products")
