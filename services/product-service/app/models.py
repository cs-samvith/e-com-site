from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from uuid import UUID, uuid4


class ProductBase(BaseModel):
    """Base product model"""
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    price: float = Field(..., gt=0)
    category: str = Field(..., min_length=1, max_length=100)
    inventory_count: int = Field(default=0, ge=0)


class ProductCreate(ProductBase):
    """Model for creating a product"""
    pass


class ProductUpdate(BaseModel):
    """Model for updating a product"""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    price: Optional[float] = Field(None, gt=0)
    category: Optional[str] = Field(None, min_length=1, max_length=100)
    inventory_count: Optional[int] = Field(None, ge=0)


class Product(ProductBase):
    """Complete product model"""
    id: UUID = Field(default_factory=uuid4)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True


class InventoryUpdate(BaseModel):
    """Model for inventory update events"""
    product_id: UUID
    old_count: int
    new_count: int
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    service: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    dependencies: dict = {}
