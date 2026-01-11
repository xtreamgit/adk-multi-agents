"""
IAP (Identity-Aware Proxy) verification service.
Verifies JWT tokens from Google Cloud IAP.
"""

import os
import logging
from typing import Optional, Dict
from google.auth.transport import requests
from google.oauth2 import id_token

logger = logging.getLogger(__name__)

# Get from environment or Cloud Run metadata
PROJECT_NUMBER = os.getenv('PROJECT_NUMBER')
BACKEND_SERVICE_ID = os.getenv('BACKEND_SERVICE_ID')

# Construct IAP audience
# Format: /projects/{PROJECT_NUMBER}/global/backendServices/{BACKEND_SERVICE_ID}
if PROJECT_NUMBER and BACKEND_SERVICE_ID:
    IAP_AUDIENCE = f"/projects/{PROJECT_NUMBER}/global/backendServices/{BACKEND_SERVICE_ID}"
else:
    IAP_AUDIENCE = None
    logger.warning("IAP_AUDIENCE not configured - PROJECT_NUMBER or BACKEND_SERVICE_ID missing")


class IAPService:
    """Service for IAP JWT verification."""
    
    @staticmethod
    def verify_iap_jwt(iap_jwt: str) -> Dict[str, any]:
        """
        Verify IAP JWT assertion from X-Goog-IAP-JWT-Assertion header.
        
        Args:
            iap_jwt: JWT token from IAP header
            
        Returns:
            Decoded JWT payload containing:
            - email: User's email address
            - sub: User's unique Google ID
            - iss: Issuer (should be https://cloud.google.com/iap)
            - aud: Audience (your backend service)
            
        Raises:
            ValueError: If JWT is invalid, expired, or has wrong audience
        """
        if not IAP_AUDIENCE:
            raise ValueError("IAP_AUDIENCE not configured. Set PROJECT_NUMBER and BACKEND_SERVICE_ID environment variables.")
        
        try:
            # Verify JWT signature and decode
            # This automatically fetches Google's public keys
            decoded_token = id_token.verify_oauth2_token(
                iap_jwt,
                requests.Request(),
                audience=IAP_AUDIENCE
            )
            
            # Validate issuer
            if decoded_token.get('iss') != 'https://cloud.google.com/iap':
                raise ValueError(f"Invalid issuer: {decoded_token.get('iss')}")
            
            logger.info(f"IAP JWT verified for user: {decoded_token.get('email')}")
            return decoded_token
            
        except Exception as e:
            logger.error(f"IAP JWT verification failed: {e}")
            raise ValueError(f"Invalid IAP token: {str(e)}")
    
    @staticmethod
    def extract_user_info(decoded_jwt: Dict[str, any]) -> Dict[str, str]:
        """
        Extract user information from verified JWT.
        
        Args:
            decoded_jwt: Verified JWT payload
            
        Returns:
            Dictionary with user info:
            - email: User's Google email
            - google_id: User's unique Google identifier
            - name: User's display name (if available)
        """
        email = decoded_jwt.get('email')
        return {
            'email': email,
            'google_id': decoded_jwt.get('sub'),
            'name': decoded_jwt.get('name', email.split('@')[0] if email else 'User')
        }
    
    @staticmethod
    def get_iap_audience() -> Optional[str]:
        """Get configured IAP audience for debugging."""
        return IAP_AUDIENCE
    
    @staticmethod
    def is_iap_enabled() -> bool:
        """Check if IAP is properly configured."""
        return IAP_AUDIENCE is not None
