"""
Admin API routes for corpus management.
Requires admin permissions.
"""

import logging
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Depends, Query

from middleware.auth_middleware import get_current_user
from models.user import User
from models.admin import (
    AdminCorpusDetail,
    AuditLogEntry,
    CorpusMetadataUpdate,
    BulkGrantRequest,
    BulkStatusUpdate,
    BulkOperationResult,
    PermissionGrantRequest,
    SyncResult,
)
from services.admin_corpus_service import AdminCorpusService
from services.bulk_operation_service import BulkOperationService
from database.repositories import AuditRepository, CorpusMetadataRepository
from database.repositories.group_repository import GroupRepository

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["Admin"])


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """Dependency to require admin privileges."""
    # Check if user is in admin-users group
    from services.user_service import UserService
    from database.repositories import GroupRepository
    
    user_group_ids = UserService.get_user_groups(current_user.id)
    user_groups = [GroupRepository.get_group_by_id(gid) for gid in user_group_ids]
    user_groups = [g for g in user_groups if g is not None]
    is_admin = any(group['name'] == 'admin-users' for group in user_groups)
    
    if not is_admin:
        raise HTTPException(
            status_code=403,
            detail="Admin privileges required"
        )
    
    return current_user


# ========== Corpus Management ==========

@router.get("/corpora", response_model=List[AdminCorpusDetail])
async def list_all_corpora_admin(
    include_inactive: bool = Query(False, description="Include inactive corpora"),
    current_user: User = Depends(require_admin)
):
    """
    Get all corpora with full admin details.
    Includes metadata, groups with access, and recent activity.
    """
    try:
        corpora = AdminCorpusService.get_all_with_details(include_inactive)
        return corpora
    except Exception as e:
        logger.error(f"Failed to get admin corpora: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/corpora/{corpus_id}", response_model=AdminCorpusDetail)
async def get_corpus_detail(
    corpus_id: int,
    current_user: User = Depends(require_admin)
):
    """Get detailed information for a single corpus."""
    try:
        corpus = AdminCorpusService.get_corpus_detail(corpus_id)
        if not corpus:
            raise HTTPException(status_code=404, detail="Corpus not found")
        return corpus
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get corpus detail: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/corpora/{corpus_id}/audit", response_model=List[AuditLogEntry])
async def get_corpus_audit_log(
    corpus_id: int,
    limit: int = Query(100, ge=1, le=1000),
    current_user: User = Depends(require_admin)
):
    """Get audit history for a specific corpus."""
    try:
        logs = AuditRepository.get_by_corpus_id(corpus_id, limit)
        return logs
    except Exception as e:
        logger.error(f"Failed to get audit log: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/corpora/{corpus_id}/metadata")
async def update_corpus_metadata(
    corpus_id: int,
    metadata: CorpusMetadataUpdate,
    current_user: User = Depends(require_admin)
):
    """Update corpus metadata (tags, notes, sync status)."""
    try:
        updates = metadata.dict(exclude_unset=True)
        if not updates:
            raise HTTPException(status_code=400, detail="No updates provided")
        
        result = AdminCorpusService.update_metadata(
            corpus_id,
            updates,
            current_user.id
        )
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update metadata: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/corpora/{corpus_id}/status")
async def update_corpus_status(
    corpus_id: int,
    is_active: bool,
    current_user: User = Depends(require_admin)
):
    """Activate or deactivate a corpus."""
    try:
        success = AdminCorpusService.update_corpus_status(
            corpus_id,
            is_active,
            current_user.id
        )
        if not success:
            raise HTTPException(status_code=404, detail="Corpus not found")
        
        return {
            "success": True,
            "corpus_id": corpus_id,
            "is_active": is_active
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update corpus status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/corpora/{corpus_id}/permissions/grant")
async def grant_corpus_permission(
    corpus_id: int,
    grant: PermissionGrantRequest,
    current_user: User = Depends(require_admin)
):
    """Grant group access to a corpus."""
    try:
        CorpusRepository.grant_corpus_access(
            group_id=grant.group_id,
            corpus_id=corpus_id,
            permission=grant.permission
        )
        
        # Log the action
        AuditRepository.create({
            'corpus_id': corpus_id,
            'user_id': current_user.id,
            'action': 'granted_access',
            'changes': {
                'group_id': grant.group_id,
                'permission': grant.permission
            },
            'metadata': {'operation': 'grant_permission'}
        })
        
        return {
            "success": True,
            "corpus_id": corpus_id,
            "group_id": grant.group_id,
            "permission": grant.permission
        }
    except Exception as e:
        logger.error(f"Failed to grant permission: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/corpora/{corpus_id}/permissions/{group_id}")
async def revoke_corpus_permission(
    corpus_id: int,
    group_id: int,
    current_user: User = Depends(require_admin)
):
    """Revoke group access from a corpus."""
    try:
        CorpusRepository.revoke_corpus_access(
            group_id=group_id,
            corpus_id=corpus_id
        )
        
        # Log the action
        AuditRepository.create({
            'corpus_id': corpus_id,
            'user_id': current_user.id,
            'action': 'revoked_access',
            'changes': {
                'group_id': group_id
            },
            'metadata': {'operation': 'revoke_permission'}
        })
        
        return {
            "success": True,
            "corpus_id": corpus_id,
            "group_id": group_id
        }
    except Exception as e:
        logger.error(f"Failed to revoke permission: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ========== Bulk Operations ==========

@router.post("/corpora/bulk/grant-access", response_model=BulkOperationResult)
async def bulk_grant_access(
    request: BulkGrantRequest,
    current_user: User = Depends(require_admin)
):
    """Grant access to multiple corpora at once."""
    try:
        result = BulkOperationService.grant_access(
            corpus_ids=request.corpus_ids,
            group_id=request.group_id,
            permission=request.permission,
            user_id=current_user.id
        )
        return result
    except Exception as e:
        logger.error(f"Failed to bulk grant access: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/corpora/bulk/update-status", response_model=BulkOperationResult)
async def bulk_update_status(
    request: BulkStatusUpdate,
    current_user: User = Depends(require_admin)
):
    """Activate or deactivate multiple corpora."""
    try:
        result = BulkOperationService.update_status(
            corpus_ids=request.corpus_ids,
            is_active=request.is_active,
            user_id=current_user.id
        )
        return result
    except Exception as e:
        logger.error(f"Failed to bulk update status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ========== Audit Log ==========

@router.get("/audit", response_model=List[AuditLogEntry])
async def get_audit_log(
    corpus_id: Optional[int] = Query(None, description="Filter by corpus ID"),
    user_id: Optional[int] = Query(None, description="Filter by user ID"),
    action: Optional[str] = Query(None, description="Filter by action type"),
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(require_admin)
):
    """Get audit log with optional filters."""
    try:
        logs = AuditRepository.get_all(
            corpus_id=corpus_id,
            user_id=user_id,
            action=action,
            limit=limit,
            offset=offset
        )
        return logs
    except Exception as e:
        logger.error(f"Failed to get audit log: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/audit/actions")
async def get_action_counts(
    corpus_id: Optional[int] = Query(None, description="Filter by corpus ID"),
    current_user: User = Depends(require_admin)
):
    """Get count of each action type in audit log."""
    try:
        counts = AuditRepository.get_action_counts(corpus_id)
        return counts
    except Exception as e:
        logger.error(f"Failed to get action counts: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ========== Sync Operations ==========

@router.post("/corpora/sync", response_model=SyncResult)
async def trigger_corpus_sync(
    current_user: User = Depends(require_admin)
):
    """
    Trigger manual sync with Vertex AI.
    This will add new corpora from Vertex AI and deactivate ones that no longer exist.
    """
    try:
        # Import sync logic from existing sync script
        from services.corpus_service import CorpusService
        from database.repositories import CorpusRepository
        
        # Get all corpora from Vertex AI
        try:
            from tools.rag import list_corpora
            vertex_corpora = list(list_corpora())
            vertex_corpus_names = {c.display_name for c in vertex_corpora}
            
        except Exception as e:
            logger.error(f"Failed to fetch from Vertex AI: {e}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to sync with Vertex AI: {str(e)}"
            )
        
        # Get all corpora from database
        db_corpora = CorpusRepository.get_all(active_only=False)
        db_corpus_names = {c['name'] for c in db_corpora}
        
        # Track changes
        added_count = 0
        deactivated_count = 0
        updated_count = 0
        errors = []
        
        # Add new corpora from Vertex AI
        for vertex_corpus in vertex_corpora:
            if vertex_corpus.display_name not in db_corpus_names:
                try:
                    # Create new corpus
                    new_corpus = CorpusRepository.create(
                        name=vertex_corpus.display_name,
                        display_name=vertex_corpus.display_name,
                        description=f"Synced from Vertex AI",
                        gcs_bucket="",  # Will be populated later
                        vertex_corpus_id=vertex_corpus.name
                    )
                    
                    # Create metadata
                    CorpusMetadataRepository.create(
                        corpus_id=new_corpus['id'],
                        created_by=current_user.id
                    )
                    
                    # Log the action
                    AuditRepository.create({
                        'corpus_id': new_corpus['id'],
                        'user_id': current_user.id,
                        'action': 'created',
                        'changes': {'source': 'vertex_ai_sync'},
                        'metadata': {'operation': 'sync'}
                    })
                    
                    added_count += 1
                except Exception as e:
                    logger.error(f"Failed to add corpus {vertex_corpus.display_name}: {e}")
                    errors.append(str(e))
        
        # Deactivate corpora not in Vertex AI
        for db_corpus in db_corpora:
            if db_corpus['name'] not in vertex_corpus_names and db_corpus['is_active']:
                try:
                    CorpusRepository.update(db_corpus['id'], {'is_active': False})
                    
                    # Log the action
                    AuditRepository.create({
                        'corpus_id': db_corpus['id'],
                        'user_id': current_user.id,
                        'action': 'deactivated',
                        'changes': {'reason': 'not_in_vertex_ai'},
                        'metadata': {'operation': 'sync'}
                    })
                    
                    deactivated_count += 1
                except Exception as e:
                    logger.error(f"Failed to deactivate corpus {db_corpus['name']}: {e}")
                    errors.append(str(e))
        
        return SyncResult(
            success=len(errors) == 0,
            total_corpora=len(vertex_corpora),
            added_count=added_count,
            deactivated_count=deactivated_count,
            updated_count=updated_count,
            errors=errors,
            message=f"Sync complete: {added_count} added, {deactivated_count} deactivated"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to sync corpora: {e}")
        raise HTTPException(status_code=500, detail=str(e))
