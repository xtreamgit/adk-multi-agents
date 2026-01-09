"""
Admin panel data models.
"""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class AuditLogEntry(BaseModel):
    """Audit log entry model."""
    id: int
    corpus_id: Optional[int] = None
    corpus_name: Optional[str] = None
    user_id: Optional[int] = None
    user_name: Optional[str] = None
    action: str
    changes: Optional[str] = None  # JSON string
    metadata: Optional[str] = None  # JSON string
    timestamp: datetime

    class Config:
        from_attributes = True


class CorpusMetadataBase(BaseModel):
    """Base corpus metadata model."""
    tags: Optional[str] = None  # JSON array as string
    notes: Optional[str] = None


class CorpusMetadata(CorpusMetadataBase):
    """Corpus metadata model."""
    id: int
    corpus_id: int
    created_by: Optional[int] = None
    created_by_name: Optional[str] = None
    created_at: datetime
    last_synced_at: Optional[datetime] = None
    last_synced_by: Optional[int] = None
    last_synced_by_name: Optional[str] = None
    document_count: int = 0
    last_document_count_update: Optional[datetime] = None
    sync_status: str = "active"
    sync_error_message: Optional[str] = None

    class Config:
        from_attributes = True


class CorpusMetadataUpdate(BaseModel):
    """Model for updating corpus metadata."""
    tags: Optional[str] = None
    notes: Optional[str] = None
    sync_status: Optional[str] = None


class GroupAccessInfo(BaseModel):
    """Group access information."""
    group_id: int
    group_name: str
    permission: str


class AdminCorpusDetail(BaseModel):
    """Detailed corpus information for admin panel."""
    id: int
    name: str
    display_name: str
    description: Optional[str] = None
    gcs_bucket: str
    vertex_corpus_id: Optional[str] = None
    is_active: bool
    created_at: datetime
    metadata: Optional[CorpusMetadata] = None
    groups_with_access: List[GroupAccessInfo] = []
    recent_activity: List[AuditLogEntry] = []
    document_count: int = 0


class BulkGrantRequest(BaseModel):
    """Request to grant access to multiple corpora."""
    corpus_ids: List[int] = Field(..., min_items=1)
    group_id: int
    permission: str = "read"


class BulkStatusUpdate(BaseModel):
    """Request to update status of multiple corpora."""
    corpus_ids: List[int] = Field(..., min_items=1)
    is_active: bool


class BulkOperationResult(BaseModel):
    """Result of bulk operation."""
    success: bool
    processed_count: int
    failed_count: int
    errors: List[Dict[str, Any]] = []


class PermissionGrantRequest(BaseModel):
    """Request to grant permission to a corpus."""
    group_id: int
    permission: str = "read"


class SyncResult(BaseModel):
    """Result of corpus sync operation."""
    success: bool
    total_corpora: int
    added_count: int
    deactivated_count: int
    updated_count: int
    errors: List[str] = []
    message: str


class CorpusSyncSchedule(BaseModel):
    """Sync schedule configuration."""
    id: int
    corpus_id: int
    frequency: str
    last_run: Optional[datetime] = None
    next_run: Optional[datetime] = None
    is_active: bool

    class Config:
        from_attributes = True
