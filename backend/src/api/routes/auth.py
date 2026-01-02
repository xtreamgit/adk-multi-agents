"""
Authentication routes: register, login, logout, token refresh.
"""

import logging
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel

from services.auth_service import AuthService
from services.user_service import UserService
from models.user import User, UserCreate
from pydantic import BaseModel
from middleware.auth_middleware import get_current_user

class Token(BaseModel):
    access_token: str
    token_type: str
    user: User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


class LoginRequest(BaseModel):
    """Login request model."""
    username: str
    password: str


class TokenResponse(BaseModel):
    """Token response model."""
    access_token: str
    token_type: str = "bearer"
    user: User


@router.post("/register", response_model=User, status_code=status.HTTP_201_CREATED)
async def register(user_create: UserCreate):
    """
    Register a new user.
    
    - **username**: Unique username (3-50 characters)
    - **email**: Valid email address
    - **password**: Password (min 8 characters)
    - **full_name**: User's full name
    """
    try:
        user = UserService.create_user(user_create)
        logger.info(f"New user registered: {user.username}")
        return user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Registration failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed"
        )


@router.post("/login", response_model=TokenResponse)
async def login(login_request: LoginRequest):
    """
    Login and get access token.
    
    - **username**: Your username
    - **password**: Your password
    
    Returns JWT access token for subsequent requests.
    """
    user = AuthService.authenticate_user(login_request.username, login_request.password)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Create access token
    access_token = AuthService.create_user_token(User(**user.model_dump()))
    
    logger.info(f"User logged in: {user.username}")
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        user=User(**user.model_dump())
    )


@router.post("/logout")
async def logout(current_user: User = Depends(get_current_user)):
    """
    Logout current user.
    
    Note: With JWT, logout is typically handled client-side by discarding the token.
    This endpoint can be used for audit logging or future session invalidation.
    """
    logger.info(f"User logged out: {current_user.username}")
    return {"message": "Successfully logged out"}


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(current_user: User = Depends(get_current_user)):
    """
    Refresh access token.
    
    Requires valid existing token. Returns new token with extended expiration.
    """
    # Create new token
    access_token = AuthService.create_user_token(current_user)
    
    logger.info(f"Token refreshed for user: {current_user.username}")
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        user=current_user
    )


@router.get("/me", response_model=User)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """
    Get current authenticated user information.
    
    Requires valid JWT token in Authorization header.
    """
    return current_user
