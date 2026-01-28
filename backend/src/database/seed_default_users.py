"""
Seed default users for development/testing.
This runs automatically on server startup if no users exist.
Also syncs corpora from Vertex AI and grants admin-users group access.
"""

import logging
from database.repositories.user_repository import UserRepository
from database.repositories.group_repository import GroupRepository
from database.repositories.corpus_repository import CorpusRepository
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
                UserRepository.add_to_group(user['id'], admin_group['id'])
                logger.info(f"   Added {user_data['username']} to admin-users group")
        
        logger.info("✅ Default users seeded successfully")
        
        # Sync corpora from Vertex AI and grant admin-users group access
        try:
            sync_corpora_and_grant_access(admin_group['id'])
        except Exception as e:
            logger.warning(f"⚠️  Failed to sync corpora (non-critical): {e}")
        
    except Exception as e:
        logger.error(f"❌ Failed to seed default users: {e}")
        raise


def sync_corpora_and_grant_access(admin_group_id: int):
    """Sync corpora from Vertex AI and grant admin-users group access."""
    try:
        import vertexai
        from vertexai import rag
        from rag_agent.config import PROJECT_ID, LOCATION
        from datetime import datetime
        
        logger.info("🔄 Syncing corpora from Vertex AI...")
        
        # Initialize Vertex AI
        import google.auth
        credentials, _ = google.auth.default()
        vertexai.init(project=PROJECT_ID, location=LOCATION, credentials=credentials)
        
        # Fetch corpora from Vertex AI
        vertex_corpora = list(rag.list_corpora())
        logger.info(f"📚 Found {len(vertex_corpora)} corpora in Vertex AI")
        
        # Get existing corpora from database
        db_corpora = CorpusRepository.get_all(active_only=False)
        db_corpus_names = {c['name']: c for c in db_corpora}
        
        # Add new corpora from Vertex AI
        added_count = 0
        for vertex_corpus in vertex_corpora:
            corpus_name = vertex_corpus.display_name
            
            if corpus_name not in db_corpus_names:
                # Create corpus in database
                corpus_dict = CorpusRepository.create(
                    name=corpus_name,
                    display_name=corpus_name,
                    gcs_bucket=f"gs://adk-rag-ma-{corpus_name}",
                    description=f"Synced from Vertex AI",
                    vertex_corpus_id=vertex_corpus.name
                )
                logger.info(f"   ✅ Added corpus: {corpus_name}")
                
                # Grant admin-users group access
                CorpusRepository.grant_group_access(admin_group_id, corpus_dict['id'])
                added_count += 1
            else:
                # Grant access if not already granted
                corpus_id = db_corpus_names[corpus_name]['id']
                existing_groups = CorpusRepository.get_groups_for_corpus(corpus_id)
                existing_group_ids = [g.get('id') or g.get('group_id') for g in existing_groups]
                
                if admin_group_id not in existing_group_ids:
                    CorpusRepository.grant_group_access(admin_group_id, corpus_id)
                    logger.info(f"   ✅ Granted access: {corpus_name}")
        
        logger.info(f"✅ Corpus sync complete: {added_count} new corpora added")
        
    except Exception as e:
        logger.warning(f"⚠️  Corpus sync failed (non-critical): {e}")
        # Don't raise - this is non-critical for startup
