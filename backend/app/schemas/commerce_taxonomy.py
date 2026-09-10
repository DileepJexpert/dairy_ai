from typing import Literal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class TaxonomyFields(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    name: str = Field(min_length=2, max_length=100)
    slug: str = Field(min_length=2, max_length=120, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    description: str = Field(default="", max_length=500)
    parent_id: UUID | None = None
    sort_order: int = Field(default=0, ge=0, le=10000)
    is_active: bool = True


class TaxonomyCreate(TaxonomyFields):
    kind: Literal["department", "category"]


class TaxonomyUpdate(TaxonomyFields):
    expected_version: int = Field(ge=1)


class ClassificationUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    category_id: UUID
    expected_version: int = Field(default=0, ge=0)
