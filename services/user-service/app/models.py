from pydantic import BaseModel, Field, EmailStr
from typing import Optional
from datetime import datetime
from uuid import UUID, uuid4


class UserBase(BaseModel):
    """Base user model"""
    email: EmailStr
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)


class UserCreate(UserBase):
    """Model for user registration"""
    password: str = Field(..., min_length=8, max_length=100)


class UserUpdate(BaseModel):
    """Model for updating user profile"""
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)


class UserPasswordUpdate(BaseModel):
    """Model for password change"""
    old_password: str = Field(..., min_length=8)
    new_password: str = Field(..., min_length=8, max_length=100)


class User(UserBase):
    """Complete user model (without password)"""
    id: UUID = Field(default_factory=uuid4)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        from_attributes = True


class UserInDB(User):
    """User model with password hash (internal use only)"""
    password_hash: str


class UserLogin(BaseModel):
    """Login request model"""
    email: EmailStr
    password: str = Field(..., min_length=1)


class Token(BaseModel):
    """JWT token response"""
    access_token: str
    token_type: str = "bearer"
    expires_in: int  # seconds


class TokenData(BaseModel):
    """JWT token payload"""
    user_id: UUID
    email: str
    exp: datetime


class Session(BaseModel):
    """User session model"""
    session_id: str
    user_id: UUID
    email: str
    created_at: datetime
    expires_at: datetime


class UserEvent(BaseModel):
    """User event for message queue"""
    event: str  # user.created, user.login, user.logout
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    data: dict


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    service: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    dependencies: dict = {}
