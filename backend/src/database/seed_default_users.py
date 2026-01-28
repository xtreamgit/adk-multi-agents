"""
Seed default users for development/testing.
This runs automatically on server startup if no users exist.
"""

import logging
from database.repositories.user_repository import UserRepository
from database.repositories.group_repository import GroupRepository
from services.auth_service import AuthService

logger = logging.getLogger(__name__)


def seed_default_users():
    """Create default users if none exist."""
    try:
        # Check if any users exist
        all_users = UserRepository.get_all()
        if all_users:
            logger.info(f"Users already exist ({len(all_users)} users), skipping seed")
            return
        
        logger.info("🌱 Seeding default users...")
        
        # Get or create admin-users group
        admin_group = GroupRepository.get_group_by_name('admin-users')
        if not admin_group:
            admin_group = GroupRepository.create_group(
                name='admin-users',
                description='Administrators with full system access'
            )
            logger.info(f"✅ Created admin-users group (ID: {admin_group['id']})")
        
        # Create default users
        default_users = [
            {
                'username': 'hector',
                'email': 'hector@develom.com',
                'password': 'hector123',
                'full_name': 'Hector DeJesus'
            },
            {
                'username': 'alice',
                'email': 'alice@example.com',
                'password': 'alice123',
                'full_name': 'Alice Admin'
            },
            {
                'username': 'bob',
                'email': 'bob@example.com',
                'password': 'bob123',
                'full_name': 'Bob User'
            }
        ]
        
        for user_data in default_users:
            # Hash password
            hashed_password = AuthService.hash_password(user_data['password'])
            
            # Create user
            user = UserRepository.create(
                username=user_data['username'],
                email=user_data['email'],
                full_name=user_data['full_name'],
                hashed_password=hashed_password
            )
            
            logger.info(f"✅ Created user: {user_data['username']} (ID: {user['id']})")
            
            # Add to admin-users group
            if admin_group:
                GroupRepository.add_user_to_group(user['id'], admin_group['id'])
                logger.info(f"   Added {user_data['username']} to admin-users group")
        
        logger.info("✅ Default users seeded successfully")
        
    except Exception as e:
        logger.error(f"❌ Failed to seed default users: {e}")
        raise
