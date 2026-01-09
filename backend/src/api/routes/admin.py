"""
Admin API routes for corpus management.
Requires admin permissions.
"""

import logging
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Depends, Query, status

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
    AdminUserDetail,
    AdminUserCreate,
    AdminUserUpdate,
    UserGroupAssignment,
)
from services.admin_corpus_service import AdminCorpusService
from services.bulk_operation_service import BulkOperationService
from database.repositories import AuditRepository, CorpusMetadataRepository, CorpusRepository, UserRepository
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
        CorpusRepository.grant_group_access(
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
        CorpusRepository.revoke_group_access(
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
            from rag_agent.tools.list_corpora import list_corpora
            result = list_corpora()
            if result['status'] != 'success':
                raise Exception(result.get('message', 'Failed to list corpora'))
            
            vertex_corpora = result['corpora']
            vertex_corpus_names = {c['display_name'] for c in vertex_corpora}
            
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
            if vertex_corpus['display_name'] not in db_corpus_names:
                try:
                    # Create new corpus
                    new_corpus = CorpusRepository.create(
                        name=vertex_corpus['display_name'],
                        display_name=vertex_corpus['display_name'],
                        description=f"Synced from Vertex AI",
                        gcs_bucket="",  # Will be populated later
                        vertex_corpus_id=vertex_corpus['resource_name']
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


# ========== User Management Endpoints ==========

@router.get("/users", response_model=List[AdminUserDetail])
async def list_all_users():
    # TODO: Re-enable auth after testing: current_user: User = Depends(require_admin)
    """Get all users with their group memberships."""
    try:
        from services.user_service import UserService
        
        users = UserService.get_all_users()
        user_details = []
        
        for user in users:
            # Get user's groups
            group_ids = UserService.get_user_groups(user.id)
            groups = []
            for gid in group_ids:
                group = GroupRepository.get_group_by_id(gid)
                if group:
                    groups.append({
                        'id': group['id'],
                        'name': group['name'],
                        'description': group.get('description', '')
                    })
            
            user_details.append(AdminUserDetail(
                id=user.id,
                username=user.username,
                email=user.email,
                full_name=user.full_name,
                is_active=user.is_active,
                created_at=user.created_at,
                updated_at=user.updated_at,
                last_login=user.last_login,
                groups=groups
            ))
        
        return user_details
    except Exception as e:
        logger.error(f"Failed to list users: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list users: {str(e)}")


@router.post("/users", response_model=AdminUserDetail, status_code=status.HTTP_201_CREATED)
async def create_user(
    user_create: AdminUserCreate,
    current_user: User = Depends(require_admin)
):
    """Create a new user (admin only)."""
    try:
        from services.user_service import UserService
        from models.user import UserCreate
        
        # Create the user
        new_user = UserService.create_user(UserCreate(
            username=user_create.username,
            email=user_create.email,
            full_name=user_create.full_name,
            password=user_create.password
        ))
        
        if not new_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create user (username or email may already exist)"
            )
        
        # Add user to initial groups
        for group_id in user_create.group_ids:
            UserService.add_user_to_group(new_user.id, group_id)
        
        # Log the action
        AuditRepository.create({
            'user_id': current_user.id,
            'action': 'created_user',
            'changes': {
                'new_user_id': new_user.id,
                'username': new_user.username,
                'groups': user_create.group_ids
            },
            'metadata': {'operation': 'user_create'}
        })
        
        # Get groups for response
        group_ids = UserService.get_user_groups(new_user.id)
        groups = []
        for gid in group_ids:
            group = GroupRepository.get_group_by_id(gid)
            if group:
                groups.append({
                    'id': group['id'],
                    'name': group['name'],
                    'description': group.get('description', '')
                })
        
        return AdminUserDetail(
            id=new_user.id,
            username=new_user.username,
            email=new_user.email,
            full_name=new_user.full_name,
            is_active=new_user.is_active,
            created_at=new_user.created_at,
            updated_at=new_user.updated_at,
            last_login=new_user.last_login,
            groups=groups
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to create user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create user: {str(e)}")


@router.put("/users/{user_id}", response_model=AdminUserDetail)
async def update_user(
    user_id: int,
    user_update: AdminUserUpdate,
    current_user: User = Depends(require_admin)
):
    """Update user information (admin only)."""
    try:
        from services.user_service import UserService
        from models.user import UserUpdate as BaseUserUpdate
        
        # Get existing user
        user = UserService.get_user_by_id(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Update basic user info
        update_data = {}
        if user_update.email is not None:
            update_data['email'] = user_update.email
        if user_update.full_name is not None:
            update_data['full_name'] = user_update.full_name
        if user_update.is_active is not None:
            update_data['is_active'] = user_update.is_active
        
        if update_data:
            updated_user = UserService.update_user(user_id, BaseUserUpdate(**update_data))
            if not updated_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Failed to update user"
                )
        else:
            updated_user = user
        
        # Handle password reset if provided
        if user_update.password:
            from passlib.context import CryptContext
            pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
            hashed_password = pwd_context.hash(user_update.password)
            
            from database.repositories import UserRepository
            UserRepository.update_password(user_id, hashed_password)
        
        # Log the action
        AuditRepository.create({
            'user_id': current_user.id,
            'action': 'updated_user',
            'changes': {
                'target_user_id': user_id,
                'updates': update_data,
                'password_reset': bool(user_update.password)
            },
            'metadata': {'operation': 'user_update'}
        })
        
        # Get groups for response
        group_ids = UserService.get_user_groups(updated_user.id)
        groups = []
        for gid in group_ids:
            group = GroupRepository.get_group_by_id(gid)
            if group:
                groups.append({
                    'id': group['id'],
                    'name': group['name'],
                    'description': group.get('description', '')
                })
        
        return AdminUserDetail(
            id=updated_user.id,
            username=updated_user.username,
            email=updated_user.email,
            full_name=updated_user.full_name,
            is_active=updated_user.is_active,
            created_at=updated_user.created_at,
            updated_at=updated_user.updated_at,
            last_login=updated_user.last_login,
            groups=groups
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update user: {str(e)}")


@router.post("/users/{user_id}/groups/{group_id}")
async def assign_user_to_group(
    user_id: int,
    group_id: int,
    current_user: User = Depends(require_admin)
):
    """Assign user to a group (admin only)."""
    try:
        from services.user_service import UserService
        
        # Verify user exists
        user = UserService.get_user_by_id(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Verify group exists
        group = GroupRepository.get_group_by_id(group_id)
        if not group:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Group not found"
            )
        
        success = UserService.add_user_to_group(user_id, group_id)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to add user to group (may already be member)"
            )
        
        # Log the action
        AuditRepository.create({
            'user_id': current_user.id,
            'action': 'assigned_user_to_group',
            'changes': {
                'target_user_id': user_id,
                'group_id': group_id,
                'username': user.username,
                'group_name': group['name']
            },
            'metadata': {'operation': 'user_group_assignment'}
        })
        
        return {
            "success": True,
            "message": f"User {user.username} added to group {group['name']}"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to assign user to group: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to assign user to group: {str(e)}")


@router.delete("/users/{user_id}/groups/{group_id}")
async def remove_user_from_group(
    user_id: int,
    group_id: int,
    current_user: User = Depends(require_admin)
):
    """Remove user from a group (admin only)."""
    try:
        from services.user_service import UserService
        
        # Verify user exists
        user = UserService.get_user_by_id(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Verify group exists
        group = GroupRepository.get_group_by_id(group_id)
        if not group:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Group not found"
            )
        
        success = UserService.remove_user_from_group(user_id, group_id)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not in group or removal failed"
            )
        
        # Log the action
        AuditRepository.create({
            'user_id': current_user.id,
            'action': 'removed_user_from_group',
            'changes': {
                'target_user_id': user_id,
                'group_id': group_id,
                'username': user.username,
                'group_name': group['name']
            },
            'metadata': {'operation': 'user_group_removal'}
        })
        
        return {
            "success": True,
            "message": f"User {user.username} removed from group {group['name']}"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to remove user from group: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to remove user from group: {str(e)}")


@router.get("/user-stats")
async def get_user_stats():
    # TODO: Re-enable auth after testing: current_user: User = Depends(require_admin)
    """Get user statistics for dashboard."""
    try:
        from services.user_service import UserService
        from database.connection import get_db_connection
        from datetime import datetime, timedelta
        
        all_users = UserService.get_all_users()
        total_users = len(all_users)
        
        # Query database directly for more reliable date filtering
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Count users created today
            cursor.execute("""
                SELECT COUNT(*) FROM users 
                WHERE date(created_at) = date('now')
            """)
            users_created_today = cursor.fetchone()[0]
            
            # Count active users in last week (with last_login)
            cursor.execute("""
                SELECT COUNT(*) FROM users 
                WHERE last_login IS NOT NULL 
                AND datetime(last_login) >= datetime('now', '-7 days')
            """)
            active_users_last_week = cursor.fetchone()[0]
        
        return {
            "total_users": total_users,
            "users_created_today": users_created_today,
            "active_users_last_week": active_users_last_week
        }
    except Exception as e:
        logger.error(f"Failed to get user stats: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to get user stats: {str(e)}")


@router.get("/sessions")
async def get_all_sessions():
    # TODO: Re-enable auth after testing: current_user: User = Depends(require_admin)
    """Get all active sessions for dashboard."""
    try:
        from database.connection import get_db_connection
        
        # Get all sessions from database
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT s.session_id, u.username, s.created_at, s.updated_at,
                       COUNT(m.id) as message_count
                FROM sessions s
                LEFT JOIN users u ON s.user_id = u.id
                LEFT JOIN messages m ON s.session_id = m.session_id
                GROUP BY s.session_id, u.username, s.created_at, s.updated_at
                ORDER BY s.updated_at DESC
                LIMIT 50
            """)
            rows = cursor.fetchall()
        
        # Format sessions for frontend
        formatted_sessions = []
        for row in rows:
            formatted_sessions.append({
                "session_id": row['session_id'],
                "username": row['username'] if row['username'] else 'Unknown',
                "created_at": row['created_at'],
                "last_activity": row['updated_at'] if row['updated_at'] else row['created_at'],
                "chat_messages": row['message_count'] if row['message_count'] else 0
            })
        
        return formatted_sessions
    except Exception as e:
        logger.error(f"Failed to get sessions: {e}")
        # Return empty list if sessions not available (table might not exist yet)
        return []


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    current_user: User = Depends(require_admin)
):
    """Delete (deactivate) a user (admin only)."""
    try:
        from services.user_service import UserService
        from models.user import UserUpdate as BaseUserUpdate
        
        # Prevent self-deletion
        if user_id == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot delete your own account"
            )
        
        # Get existing user
        user = UserService.get_user_by_id(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Deactivate instead of deleting
        updated_user = UserService.update_user(user_id, BaseUserUpdate(is_active=False))
        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to deactivate user"
            )
        
        # Log the action
        AuditRepository.create({
            'user_id': current_user.id,
            'action': 'deleted_user',
            'changes': {
                'target_user_id': user_id,
                'username': user.username
            },
            'metadata': {'operation': 'user_delete'}
        })
        
        return {
            "success": True,
            "message": f"User {user.username} has been deactivated"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete user: {str(e)}")
