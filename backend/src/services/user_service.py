"""
User service for user management and profile operations.
"""

import logging
from typing import Optional, List, Dict

from database.repositories.user_repository import UserRepository
from database.repositories.group_repository import GroupRepository
from models.user import User, UserCreate, UserUpdate, UserProfile, UserProfileUpdate, UserInDB
from services.auth_service import AuthService

logger = logging.getLogger(__name__)


class UserService:
    """Service for user operations."""
    
    @staticmethod
    def create_user(user_create: UserCreate) -> User:
        """
        Create a new user.
        
        Args:
            user_create: UserCreate model with user data
            
        Returns:
            Created User object
            
        Raises:
            ValueError: If username or email already exists
        """
        # Check if username exists
        if UserRepository.get_by_username(user_create.username):
            raise ValueError(f"Username '{user_create.username}' already exists")
        
        # Check if email exists
        if UserRepository.get_by_email(user_create.email):
            raise ValueError(f"Email '{user_create.email}' already exists")
        
        # Hash password
        hashed_password = AuthService.hash_password(user_create.password)
        
        # Create user
        user_dict = UserRepository.create(
            username=user_create.username,
            email=user_create.email,
            full_name=user_create.full_name,
            hashed_password=hashed_password
        )
        
        # Create default profile
        UserRepository.create_profile(user_dict['id'])
        
        # If this is the first user, add them to admin-users group
        try:
            all_users = UserRepository.get_all()
            if len(all_users) == 1:  # This is the first user
                admin_group = GroupRepository.get_group_by_name('admin-users')
                if admin_group:
                    UserService.add_user_to_group(user_dict['id'], admin_group['id'])
                    logger.info(f"First user {user_create.username} added to admin-users group")
        except Exception as e:
            logger.warning(f"Failed to add first user to admin group: {e}")
        
        logger.info(f"User created: {user_create.username} (ID: {user_dict['id']})")
        return User(**user_dict)
    
    @staticmethod
    def get_user_by_id(user_id: int) -> Optional[User]:
        """Get user by ID."""
        user_dict = UserRepository.get_by_id(user_id)
        return User(**user_dict) if user_dict else None
    
    @staticmethod
    def get_user_by_username(username: str) -> Optional[User]:
        """Get user by username."""
        user_dict = UserRepository.get_by_username(username)
        return User(**user_dict) if user_dict else None
    
    @staticmethod
    def get_user_by_email(email: str) -> Optional[User]:
        """Get user by email address."""
        user_dict = UserRepository.get_by_email(email)
        return User(**user_dict) if user_dict else None
    
    @staticmethod
    def get_user_by_google_id(google_id: str) -> Optional[User]:
        """Get user by Google ID (from IAP)."""
        user_dict = UserRepository.get_by_google_id(google_id)
        return User(**user_dict) if user_dict else None
    
    @staticmethod
    def get_all_users() -> List[User]:
        """Get all users."""
        user_dicts = UserRepository.get_all()
        return [User(**user_dict) for user_dict in user_dicts]
    
    @staticmethod
    def update_user(user_id: int, user_update: UserUpdate) -> Optional[User]:
        """
        Update user information.
        
        Args:
            user_id: User ID
            user_update: UserUpdate model with fields to update
            
        Returns:
            Updated User object or None if user not found
        """
        update_data = user_update.model_dump(exclude_unset=True)
        if not update_data:
            return UserService.get_user_by_id(user_id)
        
        user_dict = UserRepository.update(user_id, **update_data)
        return User(**user_dict) if user_dict else None
    
    @staticmethod
    def get_user_profile(user_id: int) -> Optional[UserProfile]:
        """Get user profile."""
        profile_dict = UserRepository.get_profile(user_id)
        return UserProfile(**profile_dict) if profile_dict else None
    
    @staticmethod
    def update_user_profile(user_id: int, profile_update: UserProfileUpdate) -> Optional[UserProfile]:
        """
        Update user profile.
        
        Args:
            user_id: User ID
            profile_update: UserProfileUpdate model with fields to update
            
        Returns:
            Updated UserProfile object or None if not found
        """
        update_data = profile_update.model_dump(exclude_unset=True)
        if not update_data:
            return UserService.get_user_profile(user_id)
        
        # Ensure profile exists
        profile = UserRepository.get_profile(user_id)
        if not profile:
            UserRepository.create_profile(user_id)
        
        profile_dict = UserRepository.update_profile(user_id, **update_data)
        return UserProfile(**profile_dict) if profile_dict else None
    
    @staticmethod
    def set_default_agent(user_id: int, agent_id: int) -> bool:
        """
        Set user's default agent.
        
        Args:
            user_id: User ID
            agent_id: Agent ID to set as default
            
        Returns:
            True if successful, False otherwise
        """
        user_dict = UserRepository.update(user_id, default_agent_id=agent_id)
        return user_dict is not None
    
    @staticmethod
    def get_user_groups(user_id: int) -> List[int]:
        """Get group IDs for a user."""
        return UserRepository.get_groups(user_id)
    
    @staticmethod
    def get_user_roles(user_id: int) -> List[Dict]:
        """Get roles for a user (through their groups)."""
        return GroupRepository.get_user_roles(user_id)
    
    @staticmethod
    def add_user_to_group(user_id: int, group_id: int) -> bool:
        """
        Add user to a group.
        
        Args:
            user_id: User ID
            group_id: Group ID
            
        Returns:
            True if successful, False otherwise
        """
        success = UserRepository.add_to_group(user_id, group_id)
        if success:
            logger.info(f"User {user_id} added to group {group_id}")
        return success
    
    @staticmethod
    def remove_user_from_group(user_id: int, group_id: int) -> bool:
        """
        Remove user from a group.
        
        Args:
            user_id: User ID
            group_id: Group ID
            
        Returns:
            True if successful, False otherwise
        """
        success = UserRepository.remove_from_group(user_id, group_id)
        if success:
            logger.info(f"User {user_id} removed from group {group_id}")
        return success
    
    @staticmethod
    def save_corpus_selection(user_id: int, corpus_names: List[str]) -> Optional[UserProfile]:
        """
        Save user's selected corpora to preferences.
        
        Args:
            user_id: User ID
            corpus_names: List of corpus names to save
            
        Returns:
            Updated UserProfile object or None if failed
        """
        # Get current profile
        profile = UserService.get_user_profile(user_id)
        if not profile:
            # Create profile if it doesn't exist
            UserRepository.create_profile(user_id)
            profile = UserService.get_user_profile(user_id)
        
        # Update preferences with selected corpora
        current_prefs = profile.preferences or {}
        current_prefs['selected_corpora'] = corpus_names
        
        # Update profile
        profile_update = UserProfileUpdate(preferences=current_prefs)
        updated_profile = UserService.update_user_profile(user_id, profile_update)
        
        if updated_profile:
            logger.info(f"Saved corpus selection for user {user_id}: {corpus_names}")
        else:
            logger.error(f"Failed to save corpus selection for user {user_id}")
        
        return updated_profile
    
    @staticmethod
    def get_corpus_selection(user_id: int) -> List[str]:
        """
        Get user's saved corpus selection.
        
        Args:
            user_id: User ID
            
        Returns:
            List of corpus names (empty list if none saved)
        """
        profile = UserService.get_user_profile(user_id)
        if not profile or not profile.preferences:
            return []
        
        corpus_list = profile.preferences.get('selected_corpora', [])
        logger.debug(f"Retrieved corpus selection for user {user_id}: {corpus_list}")
        return corpus_list if isinstance(corpus_list, list) else []
    
    @staticmethod
    def create_user_from_iap(email: str, google_id: str, full_name: str) -> User:
        """
        Create a new user from IAP authentication.
        
        Args:
            email: User's email from Google
            google_id: User's unique Google ID
            full_name: User's display name
            
        Returns:
            Created User object
            
        Raises:
            ValueError: If email already exists
        """
        # Check if email exists
        if UserRepository.get_by_email(email):
            raise ValueError(f"Email '{email}' already exists")
        
        # Generate username from email
        username = email.split('@')[0]
        
        # Ensure username is unique by adding suffix if needed
        base_username = username
        counter = 1
        while UserRepository.get_by_username(username):
            username = f"{base_username}{counter}"
            counter += 1
        
        # Create user without password (IAP handles authentication)
        user_dict = UserRepository.create_iap_user(
            username=username,
            email=email,
            full_name=full_name,
            google_id=google_id
        )
        
        # Create default profile
        UserRepository.create_profile(user_dict['id'])
        
        logger.info(f"User created from IAP: {email} (ID: {user_dict['id']})")
        return User(**user_dict)
    
    @staticmethod
    def update_google_id(user_id: int, google_id: str) -> bool:
        """
        Update user's Google ID.
        
        Args:
            user_id: User ID
            google_id: Google ID to set
            
        Returns:
            True if successful, False otherwise
        """
        user_dict = UserRepository.update(user_id, google_id=google_id, auth_provider='iap')
        if user_dict:
            logger.info(f"Updated google_id for user {user_id}")
            return True
        return False
    
    @staticmethod
    def update_last_login(user_id: int) -> bool:
        """
        Update user's last login timestamp.
        
        Args:
            user_id: User ID
            
        Returns:
            True if successful, False otherwise
        """
        return UserRepository.update_last_login(user_id)
