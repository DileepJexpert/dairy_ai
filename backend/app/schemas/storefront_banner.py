"""Pydantic schemas for storefront banner CRUD."""
from datetime import datetime
from typing import Literal, Optional
from pydantic import BaseModel, Field


class BannerCreate(BaseModel):
    title: str = Field(..., max_length=200)
    subtitle: Optional[str] = Field(None, max_length=300)
    image_url: Optional[str] = Field(None, max_length=500)
    icon_name: Optional[str] = Field(None, max_length=50)
    action_type: Literal["category", "product", "url", "division"] = "category"
    action_value: str = Field(..., max_length=200)
    bg_color: str = Field("#173f35", max_length=9)
    text_color: str = Field("#ffffff", max_length=9)
    display_order: int = 0
    is_active: bool = True
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None


class BannerUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    subtitle: Optional[str] = Field(None, max_length=300)
    image_url: Optional[str] = Field(None, max_length=500)
    icon_name: Optional[str] = Field(None, max_length=50)
    action_type: Optional[Literal["category", "product", "url", "division"]] = None
    action_value: Optional[str] = Field(None, max_length=200)
    bg_color: Optional[str] = Field(None, max_length=9)
    text_color: Optional[str] = Field(None, max_length=9)
    display_order: Optional[int] = None
    is_active: Optional[bool] = None
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None


class BannerReorderItem(BaseModel):
    id: str
    display_order: int


class BannerReorderRequest(BaseModel):
    banners: list[BannerReorderItem]
