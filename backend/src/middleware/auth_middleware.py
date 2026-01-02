"""
Authentication middleware for JWT token validation.
"""

import logging
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from services.auth_service import AuthService
from models.user import User

logger = logging.getLogger(__name__)

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> User:
    """
    FastAPI dependency to get the current authenticated user from JWT token.
    
    Raises:
        HTTPException: If token is invalid or user not found
        
    Returns:
        User object
    """
    token = credentials.credentials
    
    # Verify token and get user
    user = AuthService.get_current_user_from_token(token)
    
    if user is None:
        logger.warning("Invalid or expired token")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        logger.warning(f"Inactive user attempted access: {user.username}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )
    
    return user


async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False))
) -> Optional[User]:
    """
    FastAPI dependency to optionally get the current authenticated user.
    Returns None if no token provided or token is invalid.
    
    Returns:
        User object or None
    """
    if credentials is None:
        return None
    
    token = credentials.credentials
    user = AuthService.get_current_user_from_token(token)
    
    if user and not user.is_active:
        return None
    
    return user
