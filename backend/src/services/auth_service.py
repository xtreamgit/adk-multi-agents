"""
Authentication service for user login, token management, and password handling.
"""

import os
import logging
from typing import Optional
from datetime import datetime, timedelta, timezone

from passlib.context import CryptContext
from jose import JWTError, jwt

from database.repositories.user_repository import UserRepository
from models.user import User, UserInDB

logger = logging.getLogger(__name__)

# Security configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = int(os.getenv("ACCESS_TOKEN_EXPIRE_DAYS", "30"))

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AuthService:
    """Service for authentication operations."""
    
    @staticmethod
    def hash_password(password: str) -> str:
        """Hash a plain password."""
        return pwd_context.hash(password)
    
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """Verify a password against its hash."""
        return pwd_context.verify(plain_password, hashed_password)
    
    @staticmethod
    def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
        """
        Create a JWT access token.
        
        Args:
            data: Dictionary of data to encode in the token
            expires_delta: Optional custom expiration time
            
        Returns:
            Encoded JWT token string
        """
        to_encode = data.copy()
        
        if expires_delta:
            expire = datetime.now(timezone.utc) + expires_delta
        else:
            expire = datetime.now(timezone.utc) + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
        
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt
    
    @staticmethod
    def verify_token(token: str) -> Optional[str]:
        """
        Verify and decode a JWT token.
        
        Args:
            token: JWT token string
            
        Returns:
            Username from token payload, or None if invalid
        """
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            username: str = payload.get("sub")
            if username is None:
                return None
            return username
        except JWTError as e:
            logger.warning(f"Token verification failed: {e}")
            return None
    
    @staticmethod
    def authenticate_user(username: str, password: str) -> Optional[UserInDB]:
        """
        Authenticate a user with username and password.
        
        Args:
            username: Username
            password: Plain text password
            
        Returns:
            UserInDB object if authentication successful, None otherwise
        """
        user_dict = UserRepository.get_by_username(username)
        if not user_dict:
            logger.info(f"Authentication failed: user '{username}' not found")
            return None
        
        if not AuthService.verify_password(password, user_dict['hashed_password']):
            logger.info(f"Authentication failed: invalid password for user '{username}'")
            return None
        
        # Update last login
        UserRepository.update_last_login(user_dict['id'])
        
        # Return user object
        return UserInDB(**user_dict)
    
    @staticmethod
    def get_current_user_from_token(token: str) -> Optional[User]:
        """
        Get current user from a JWT token.
        
        Args:
            token: JWT token string
            
        Returns:
            User object if token is valid, None otherwise
        """
        username = AuthService.verify_token(token)
        if not username:
            return None
        
        user_dict = UserRepository.get_by_username(username)
        if not user_dict:
            return None
        
        return User(**user_dict)
    
    @staticmethod
    def create_user_token(user: User) -> str:
        """
        Create an access token for a user.
        
        Args:
            user: User object
            
        Returns:
            JWT token string
        """
        access_token = AuthService.create_access_token(
            data={"sub": user.username}
        )
        return access_token
