import uuid
from datetime import date
from decimal import Decimal
from pydantic import BaseModel, Field, model_validator
from app.models.product import ProductCategory, MediaType
class ProductCreate(BaseModel):
    sku: str = Field(min_length=1, max_length=100); title: str = Field(min_length=2, max_length=200); category: ProductCategory; base_price: Decimal = Field(gt=0); unit: str = Field(min_length=1, max_length=30)
    subcategory: str|None=None; brand:str|None=None; description:str|None=None; short_description:str|None=None; gst_rate:Decimal|None=Field(default=None,ge=0,le=100); pack_size:str|None=None; specifications:dict=Field(default_factory=dict); is_featured:bool=False; is_rentable:bool=False; rental_rate_per_hour:Decimal|None=Field(default=None,gt=0); rental_rate_per_acre:Decimal|None=Field(default=None,gt=0); min_order_quantity:int=Field(default=1,ge=1)
    @model_validator(mode="after")
    def rent_rules(self):
        if self.is_rentable and not (self.rental_rate_per_hour or self.rental_rate_per_acre): raise ValueError("Rentable products need a rental rate")
        if self.category != ProductCategory.equipment and self.is_rentable: raise ValueError("Only equipment can be rentable")
        return self
class ProductUpdate(BaseModel):
    title:str|None=Field(default=None,min_length=2,max_length=200); subcategory:str|None=None; brand:str|None=None; description:str|None=None; short_description:str|None=None; base_price:Decimal|None=Field(default=None,gt=0); gst_rate:Decimal|None=Field(default=None,ge=0,le=100); unit:str|None=None; pack_size:str|None=None; specifications:dict|None=None; is_active:bool|None=None; is_featured:bool|None=None; is_rentable:bool|None=None; rental_rate_per_hour:Decimal|None=Field(default=None,gt=0); rental_rate_per_acre:Decimal|None=Field(default=None,gt=0); min_order_quantity:int|None=Field(default=None,ge=1)
class InventoryUpdate(BaseModel): available_quantity:int=Field(ge=0); reserved_quantity:int=Field(default=0,ge=0); reorder_level:int=Field(default=0,ge=0); warehouse_location:str|None=None; batch_number:str|None=None; manufacture_date:date|None=None; expiry_date:date|None=None
class ProductMediaCreate(BaseModel): url:str=Field(min_length=1,max_length=500); media_type:MediaType=MediaType.image; sort_order:int=Field(default=0,ge=0); is_primary:bool=False
