"""
Corpus service for managing corpora and user access.
"""

import logging
from typing import Optional, List

from database.repositories.corpus_repository import CorpusRepository
from models.corpus import Corpus, CorpusCreate, CorpusUpdate, CorpusWithAccess

logger = logging.getLogger(__name__)


class CorpusService:
    """Service for corpus operations."""
    
    @staticmethod
    def create_corpus(corpus_create: CorpusCreate) -> Corpus:
        """
        Create a new corpus.
        
        Args:
            corpus_create: CorpusCreate model with corpus data
            
        Returns:
            Created Corpus object
            
        Raises:
            ValueError: If corpus name already exists
        """
        # Check if corpus name exists
        if CorpusRepository.get_by_name(corpus_create.name):
            raise ValueError(f"Corpus '{corpus_create.name}' already exists")
        
        corpus_dict = CorpusRepository.create(
            name=corpus_create.name,
            display_name=corpus_create.display_name,
            gcs_bucket=corpus_create.gcs_bucket,
            description=corpus_create.description,
            vertex_corpus_id=corpus_create.vertex_corpus_id
        )
        
        logger.info(f"Corpus created: {corpus_create.name} (ID: {corpus_dict['id']})")
        return Corpus(**corpus_dict)
    
    @staticmethod
    def get_corpus_by_id(corpus_id: int) -> Optional[Corpus]:
        """Get corpus by ID."""
        corpus_dict = CorpusRepository.get_by_id(corpus_id)
        return Corpus(**corpus_dict) if corpus_dict else None
    
    @staticmethod
    def get_corpus_by_name(name: str) -> Optional[Corpus]:
        """Get corpus by name."""
        corpus_dict = CorpusRepository.get_by_name(name)
        return Corpus(**corpus_dict) if corpus_dict else None
    
    @staticmethod
    def get_all_corpora(active_only: bool = True) -> List[Corpus]:
        """Get all corpora."""
        corpora_dict = CorpusRepository.get_all(active_only=active_only)
        return [Corpus(**c) for c in corpora_dict]
    
    @staticmethod
    def update_corpus(corpus_id: int, corpus_update: CorpusUpdate) -> Optional[Corpus]:
        """
        Update corpus information.
        
        Args:
            corpus_id: Corpus ID
            corpus_update: CorpusUpdate model with fields to update
            
        Returns:
            Updated Corpus object or None if not found
        """
        update_data = corpus_update.model_dump(exclude_unset=True)
        if not update_data:
            return CorpusService.get_corpus_by_id(corpus_id)
        
        corpus_dict = CorpusRepository.update(corpus_id, **update_data)
        return Corpus(**corpus_dict) if corpus_dict else None
    
    # ========== Group-Corpus Access ==========
    
    @staticmethod
    def grant_group_access(group_id: int, corpus_id: int, permission: str = 'read') -> bool:
        """
        Grant group access to a corpus.
        
        Args:
            group_id: Group ID
            corpus_id: Corpus ID
            permission: Permission level ('read', 'write', 'admin')
            
        Returns:
            True if successful, False otherwise
        """
        success = CorpusRepository.grant_group_access(group_id, corpus_id, permission)
        if success:
            logger.info(f"Group {group_id} granted {permission} access to corpus {corpus_id}")
        return success
    
    @staticmethod
    def revoke_group_access(group_id: int, corpus_id: int) -> bool:
        """
        Revoke group access to a corpus.
        
        Args:
            group_id: Group ID
            corpus_id: Corpus ID
            
        Returns:
            True if successful, False otherwise
        """
        success = CorpusRepository.revoke_group_access(group_id, corpus_id)
        if success:
            logger.info(f"Group {group_id} access revoked for corpus {corpus_id}")
        return success
    
    # ========== User-Corpus Access ==========
    
    @staticmethod
    def get_user_corpora(user_id: int, active_only: bool = True, 
                        active_in_session: Optional[List[int]] = None) -> List[CorpusWithAccess]:
        """
        Get all corpora a user has access to.
        
        Args:
            user_id: User ID
            active_only: Only return active corpora
            active_in_session: List of corpus IDs that are active in the session
            
        Returns:
            List of CorpusWithAccess objects
        """
        corpora_dict = CorpusRepository.get_user_corpora(user_id, active_only=active_only)
        
        active_set = set(active_in_session) if active_in_session else set()
        
        corpora = []
        for corpus_data in corpora_dict:
            corpus = CorpusWithAccess(
                **{k: v for k, v in corpus_data.items() if k != 'permission'},
                has_access=True,
                permission=corpus_data.get('permission'),
                is_active_in_session=(corpus_data['id'] in active_set)
            )
            corpora.append(corpus)
        
        return corpora
    
    @staticmethod
    def validate_corpus_access(user_id: int, corpus_id: int) -> bool:
        """
        Check if user has access to a corpus.
        
        Args:
            user_id: User ID
            corpus_id: Corpus ID
            
        Returns:
            True if user has access, False otherwise
        """
        permission = CorpusRepository.check_user_access(user_id, corpus_id)
        return permission is not None
    
    @staticmethod
    def get_corpus_permission(user_id: int, corpus_id: int) -> Optional[str]:
        """
        Get user's permission level for a corpus.
        
        Args:
            user_id: User ID
            corpus_id: Corpus ID
            
        Returns:
            Permission string ('read', 'write', 'admin') or None if no access
        """
        return CorpusRepository.check_user_access(user_id, corpus_id)
    
    # ========== Session Corpus Management ==========
    
    @staticmethod
    def update_session_selection(user_id: int, corpus_id: int) -> bool:
        """
        Update session corpus selection for a user.
        
        Args:
            user_id: User ID
            corpus_id: Corpus ID
            
        Returns:
            True if successful
        """
        return CorpusRepository.update_session_selection(user_id, corpus_id)
    
    @staticmethod
    def restore_last_corpora(user_id: int, limit: int = 10) -> List[int]:
        """
        Get last selected corpus IDs for a user.
        
        Args:
            user_id: User ID
            limit: Maximum number of corpus IDs to return
            
        Returns:
            List of corpus IDs
        """
        return CorpusRepository.get_last_selected_corpora(user_id, limit=limit)
