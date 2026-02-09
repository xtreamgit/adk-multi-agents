"""
IAP authentication middleware for FastAPI.
Verifies IAP JWT and creates/updates user in local database.
"""

from fastapi import Request, HTTPException, status
from typing import Optional
import logging

from services.iap_service import IAPService
from services.user_service import UserService
from models.user import User

logger = logging.getLogger(__name__)

# Header names for IAP
IAP_JWT_HEADER = "X-Goog-IAP-JWT-Assertion"
IAP_EMAIL_HEADER = "X-Goog-Authenticated-User-Email"
IAP_ID_HEADER = "X-Goog-Authenticated-User-ID"


async def get_current_user_iap(request: Request) -> User:
    """
    FastAPI dependency to get current user from IAP headers.
    
    Flow:
    1. Extract IAP JWT from header
    2. Verify JWT signature and audience
    3. Extract user email from verified JWT
    4. Get or create user in local database
    5. Return User object with groups/permissions
    
    Raises:
        HTTPException 401: If IAP JWT is missing or invalid
        HTTPException 403: If user is inactive
        
    Returns:
        User object from local database
    """
    # Extract IAP JWT header
    iap_jwt = request.headers.get(IAP_JWT_HEADER)
    
    if not iap_jwt:
        logger.warning("Missing IAP JWT header - request not from IAP?")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing IAP authentication. Access must be through Load Balancer.",
        )
    
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
        
        if not user:
            # Create new user from IAP authentication
            user = UserService.create_user_from_iap(
                email=email,
                google_id=google_id,
                full_name=name
            )
            logger.info(f"New user created from IAP: {email}")
        else:
            # Update last login
            UserService.update_last_login(user.id)
            
            # Update google_id if not set
            if not hasattr(user, 'google_id') or not user.google_id:
                UserService.update_google_id(user.id, google_id)
                logger.info(f"Updated google_id for existing user: {email}")
        
        # Check if user is active
        if not user.is_active:
            logger.warning(f"Inactive user attempted access: {email}")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Your account is inactive. Please contact an administrator."
            )
        
        return user
        
    except ValueError as e:
        logger.error(f"IAP JWT verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid IAP token: {str(e)}",
        )
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication failed"
        )


async def get_current_user_optional_iap(request: Request) -> Optional[User]:
    """
    Optional IAP authentication - returns None if not authenticated.
    Useful for endpoints that work with or without authentication.
    """
    iap_jwt = request.headers.get(IAP_JWT_HEADER)
    
    if not iap_jwt:
        return None
    
    try:
        return await get_current_user_iap(request)
    except HTTPException:
        return None


# Re-export canonical hybrid auth from hybrid_auth_middleware for backward compatibility
from middleware.hybrid_auth_middleware import get_current_user_hybrid
