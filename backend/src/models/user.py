"""
User data models and schemas.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    """Base user model with common fields."""
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    full_name: str = Field(..., min_length=1, max_length=100)


class UserCreate(UserBase):
    """Model for creating a new user."""
    password: str = Field(..., min_length=8)


class UserUpdate(BaseModel):
    """Model for updating user information."""
    email: Optional[EmailStr] = None
    full_name: Optional[str] = Field(None, min_length=1, max_length=100)
    default_agent_id: Optional[int] = None


class User(UserBase):
    """User model returned to clients."""
    id: int
    is_active: bool = True
    default_agent_id: Optional[int] = None
    google_id: Optional[str] = None
    auth_provider: str = "local"  # 'local', 'iap', 'google'
    created_at: datetime
    updated_at: datetime
    last_login: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserInDB(User):
    """User model with password hash (internal use only)."""
    hashed_password: str


class UserProfile(BaseModel):
    """User profile with preferences."""
    id: int
    user_id: int
    theme: str = "light"
    language: str = "en"
    timezone: str = "UTC"
    preferences: Optional[dict] = None

    class Config:
        from_attributes = True


class UserProfileUpdate(BaseModel):
    """Model for updating user profile."""
    theme: Optional[str] = Field(None, pattern="^(light|dark)$")
    language: Optional[str] = Field(None, min_length=2, max_length=5)
    timezone: Optional[str] = None
    preferences: Optional[dict] = None


class UserWithProfile(User):
    """User model with profile information."""
    profile: Optional[UserProfile] = None
