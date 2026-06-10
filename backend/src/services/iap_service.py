"""
IAP (Identity-Aware Proxy) verification service.
Verifies JWT tokens from Google Cloud IAP.
"""

import os
import logging
import jwt
import requests as http_requests
from typing import Optional, Dict, List
from google.auth.transport import requests
from google.oauth2 import id_token

logger = logging.getLogger(__name__)

# Get from environment or Cloud Run metadata
PROJECT_NUMBER = os.getenv('PROJECT_NUMBER')
BACKEND_SERVICE_ID = os.getenv('BACKEND_SERVICE_ID')

# Construct IAP audiences — accept JWTs for any backend service in this project.
# IAP may issue JWTs with the audience of the backend service the request is
# routed to OR the one the initial auth session was established against.
IAP_AUDIENCES: List[str] = []
if PROJECT_NUMBER and BACKEND_SERVICE_ID:
    IAP_AUDIENCES.append(f"/projects/{PROJECT_NUMBER}/global/backendServices/{BACKEND_SERVICE_ID}")
if PROJECT_NUMBER:
    IAP_AUDIENCE_PREFIX = f"/projects/{PROJECT_NUMBER}/global/backendServices/"
else:
    IAP_AUDIENCE_PREFIX = None

if not IAP_AUDIENCES:
    logger.warning("IAP_AUDIENCE not configured - PROJECT_NUMBER or BACKEND_SERVICE_ID missing")
else:
    logger.info(f"IAP audiences configured: {IAP_AUDIENCES}")


class IAPService:
    """Service for IAP JWT verification."""

    @staticmethod
    def verify_iap_jwt(iap_jwt: str) -> Dict[str, any]:
        """
        Verify IAP JWT assertion from X-Goog-IAP-JWT-Assertion header.

        Verifies the signature using Google's public keys, validates the issuer,
        and checks the audience belongs to this project. On first successful
        verification, the audience is cached so future requests skip the
        audience discovery step.

        Raises:
            ValueError: If JWT is invalid, expired, or has wrong audience
        """
        if not PROJECT_NUMBER:
            raise ValueError("PROJECT_NUMBER not configured.")

        try:
            # Decode without verification to inspect the audience claim
            unverified = jwt.decode(
                iap_jwt,
                options={"verify_signature": False, "verify_aud": False, "verify_exp": False},
            )
            actual_aud = unverified.get('aud', '')
            logger.info(f"IAP JWT audience from token: {actual_aud}, email: {unverified.get('email')}")

            # Determine the audience to verify against
            if actual_aud in IAP_AUDIENCES:
                verify_aud = actual_aud
            elif IAP_AUDIENCE_PREFIX and actual_aud.startswith(IAP_AUDIENCE_PREFIX):
                # Audience is for a backend service in our project — accept it
                logger.info(f"Auto-accepting audience {actual_aud} (matches project {PROJECT_NUMBER})")
                IAP_AUDIENCES.append(actual_aud)
                verify_aud = actual_aud
            else:
                raise ValueError(
                    f"Audience mismatch: token has '{actual_aud}', "
                    f"expected prefix '{IAP_AUDIENCE_PREFIX}'"
                )

            # Fetch IAP public keys
            certs_url = 'https://www.gstatic.com/iap/verify/public_key'
            response = http_requests.get(certs_url, timeout=10)
            response.raise_for_status()
            certs = response.json()

            # Decode JWT header to get key id
            header = jwt.get_unverified_header(iap_jwt)
            key_id = header.get('kid')

            if key_id not in certs:
                raise ValueError(f"Certificate for key id {key_id} not found in IAP public keys")

            # Get the public key
            public_key = certs[key_id]

            # Verify and decode the token with signature + audience check
            decoded_token = jwt.decode(
                iap_jwt,
                public_key,
                algorithms=['ES256'],
                audience=verify_aud,
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
        return IAP_AUDIENCES[0] if IAP_AUDIENCES else None

    @staticmethod
    def is_iap_enabled() -> bool:
        """Check if IAP is properly configured."""
        return bool(PROJECT_NUMBER)
