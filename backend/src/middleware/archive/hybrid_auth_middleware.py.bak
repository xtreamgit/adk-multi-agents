"""
Hybrid authentication middleware that supports both IAP and Bearer token authentication.
"""

import logging
from typing import Optional

from fastapi import Request, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from services.auth_service import AuthService
from services.iap_service import IAPService
from services.user_service import UserService
from models.user import User

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)

IAP_JWT_HEADER = "X-Goog-IAP-JWT-Assertion"


async def get_current_user_hybrid(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> User:
    """
    FastAPI dependency that supports both IAP and Bearer token authentication.
    
    Priority:
    1. Try IAP authentication (X-Goog-IAP-JWT-Assertion header)
    2. Fall back to Bearer token authentication
    
    Raises:
        HTTPException: If neither authentication method succeeds
        
    Returns:
        User object
    """
    
    # Try IAP authentication first
    iap_jwt = request.headers.get(IAP_JWT_HEADER)
    
    if iap_jwt:
        logger.debug("Found IAP JWT header, attempting IAP authentication")
        try:
            # Verify IAP JWT
            decoded_token = IAPService.verify_iap_jwt(iap_jwt)
            user_info = IAPService.extract_user_info(decoded_token)
            
            email = user_info['email']
            google_id = user_info['google_id']
            name = user_info['name']
            
            logger.info(f"IAP authenticated user: {email}")
            
            # Get or create user in local database
            user = UserService.get_user_by_email(email)
            
            if user is None:
                # Create new user from IAP
                logger.info(f"Creating new user from IAP: {email}")
                user = UserService.create_user_from_iap(
                    email=email,
                    google_id=google_id,
                    full_name=name
                )
            else:
                # Update last login
                from database.repositories.user_repository import UserRepository
                UserRepository.update_last_login(user.id)
                logger.info(f"Updated last login for IAP user: {email}")
            
            if not user.is_active:
                logger.warning(f"Inactive IAP user attempted access: {user.username}")
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Inactive user"
                )
            
            logger.debug(f"IAP authentication successful for user: {user.username}")
            return user
            
        except ValueError as e:
            logger.warning(f"IAP JWT verification failed: {e}")
            # Don't raise exception yet, try Bearer token
        except Exception as e:
            logger.error(f"IAP authentication error: {e}")
            # Don't raise exception yet, try Bearer token
    
    # Try Bearer token authentication
    if credentials:
        logger.debug("Found Bearer token, attempting token authentication")
        token = credentials.credentials
        
        # Verify token and get user
        user = AuthService.get_current_user_from_token(token)
        
        if user is not None:
            if not user.is_active:
                logger.warning(f"Inactive user attempted access: {user.username}")
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Inactive user"
                )
            
            logger.debug(f"Bearer token authentication successful for user: {user.username}")
            return user
        
        logger.warning("Invalid or expired Bearer token")
    
    # Both authentication methods failed
    logger.warning("Authentication failed: no valid IAP JWT or Bearer token")
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Not authenticated",
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_current_user_hybrid_optional(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> Optional[User]:
    """
    Optional hybrid authentication - returns None if not authenticated.
    Useful for endpoints that work with or without authentication.
    """
    try:
        return await get_current_user_hybrid(request, credentials)
    except HTTPException:
        return None
