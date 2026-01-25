"""
Document retrieval API routes.
Handles document search, signed URL generation, and access control.
"""

import logging
from typing import Optional
from fastapi import APIRouter, HTTPException, status, Request, Depends
from pydantic import BaseModel

from services.corpus_service import CorpusService
from services.document_service import DocumentService
from models.user import User
from middleware.hybrid_auth_middleware import get_current_user_hybrid

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/documents", tags=["Documents"])


class DocumentRetrievalResponse(BaseModel):
    """Response model for document retrieval."""
    status: str
    document: dict
    access: Optional[dict] = None


@router.get("/retrieve", response_model=DocumentRetrievalResponse)
async def retrieve_document(
    corpus_id: int,
    document_name: str,
    generate_url: bool = True,
    request: Request = None,
    current_user: User = Depends(get_current_user_hybrid)
):
    """
    Retrieve a document from a corpus and generate signed access URL.
    
    **Security**: User must have 'read' access to the corpus.
    
    **Parameters**:
    - **corpus_id**: ID of the corpus containing the document
    - **document_name**: Display name of the document to retrieve
    - **generate_url**: Whether to generate a signed URL (default: true)
    
    **Returns**:
    - Document metadata
    - Signed GCS URL (if generate_url=true)
    - URL expiration time
    
    **Access Control**:
    1. Validates user has access to corpus
    2. Searches for document in Vertex AI RAG
    3. Generates time-limited signed URL (30 minutes)
    4. Logs access attempt to audit trail
    """
    
    # Step 1: Validate corpus access
    if not CorpusService.validate_corpus_access(current_user.id, corpus_id):
        logger.warning(
            f"User {current_user.username} (ID: {current_user.id}) "
            f"denied access to corpus {corpus_id}"
        )
        
        # Log failed access attempt
        DocumentService.log_access(
            user_id=current_user.id,
            corpus_id=corpus_id,
            document_name=document_name,
            success=False,
            error_message="User does not have access to corpus",
            ip_address=request.client.host if request else None,
            user_agent=request.headers.get('user-agent') if request else None
        )
        
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this corpus"
        )
    
    # Step 2: Get corpus details
    corpus = CorpusService.get_corpus_by_id(corpus_id)
    if not corpus:
        logger.error(f"Corpus {corpus_id} not found")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Corpus not found"
        )
    
    if not corpus.vertex_corpus_id:
        logger.error(f"Corpus {corpus_id} has no vertex_corpus_id")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Corpus is not properly configured"
        )
    
    # Step 3: Search for document in Vertex AI RAG
    document = DocumentService.find_document(corpus.vertex_corpus_id, document_name)
    
    if not document:
        logger.warning(
            f"Document '{document_name}' not found in corpus '{corpus.name}' "
            f"(ID: {corpus_id})"
        )
        
        # Log failed access attempt
        DocumentService.log_access(
            user_id=current_user.id,
            corpus_id=corpus_id,
            document_name=document_name,
            success=False,
            error_message="Document not found in corpus",
            ip_address=request.client.host if request else None,
            user_agent=request.headers.get('user-agent') if request else None
        )
        
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Document '{document_name}' not found in corpus '{corpus.name}'"
        )
    
    # Step 4: Get additional metadata from GCS
    metadata = {}
    if document.get('source_uri'):
        metadata = DocumentService.get_document_metadata(document['source_uri'])
    
    # Step 5: Generate signed URL if requested
    signed_url = None
    expires_at = None
    valid_for_seconds = None
    
    logger.info(f"[DEBUG] generate_url={generate_url}, document.source_uri={document.get('source_uri')}")
    
    if generate_url and document.get('source_uri'):
        logger.info(f"[DEBUG] Generating signed URL for: {document['source_uri']}")
        signed_url, expires_at = DocumentService.generate_signed_url(
            document['source_uri'],
            expiration_minutes=30
        )
        logger.info(f"[DEBUG] Generated signed_url={'<url>' if signed_url else 'None'}, expires_at={expires_at}")
        
        if not signed_url:
            logger.error(f"Failed to generate signed URL for {document['source_uri']}")
            
            # Log failed access attempt
            DocumentService.log_access(
                user_id=current_user.id,
                corpus_id=corpus_id,
                document_name=document_name,
                document_file_id=document.get('file_id'),
                source_uri=document.get('source_uri'),
                success=False,
                error_message="Failed to generate signed URL",
                ip_address=request.client.host if request else None,
                user_agent=request.headers.get('user-agent') if request else None
            )
            
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to generate access URL for document"
            )
        
        valid_for_seconds = 1800  # 30 minutes
    
    # Step 6: Log successful access
    DocumentService.log_access(
        user_id=current_user.id,
        corpus_id=corpus_id,
        document_name=document_name,
        document_file_id=document.get('file_id'),
        source_uri=document.get('source_uri'),
        success=True,
        access_type='view',
        ip_address=request.client.host if request else None,
        user_agent=request.headers.get('user-agent') if request else None
    )
    
    logger.info(
        f"Document retrieval successful: user={current_user.username}, "
        f"corpus={corpus.name}, document={document_name}"
    )
    
    # Step 7: Build response
    response_document = {
        'id': document.get('file_id'),
        'name': document.get('display_name'),
        'corpus_id': corpus_id,
        'corpus_name': corpus.name,
        'file_type': document.get('file_type', 'unknown'),
        'size_bytes': metadata.get('size_bytes'),
        'created_at': document.get('created_at'),
        'updated_at': document.get('updated_at'),
    }
    
    response_access = None
    if signed_url:
        response_access = {
            'url': signed_url,
            'expires_at': expires_at.isoformat() if expires_at else None,
            'valid_for_seconds': valid_for_seconds
        }
    
    return DocumentRetrievalResponse(
        status="success",
        document=response_document,
        access=response_access
    )


@router.get("/corpus/{corpus_id}/list")
async def list_corpus_documents(
    corpus_id: int,
    request: Request = None,
    current_user: User = Depends(get_current_user_hybrid)
):
    """
    List all documents in a corpus.
    
    **Security**: User must have access to the corpus.
    
    **Parameters**:
    - **corpus_id**: ID of the corpus
    
    **Returns**: List of documents with metadata
    """
    # Validate corpus access
    if not CorpusService.validate_corpus_access(current_user.id, corpus_id):
        logger.warning(
            f"User {current_user.username} (ID: {current_user.id}) "
            f"denied access to list documents in corpus {corpus_id}"
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this corpus"
        )
    
    # Get corpus details
    corpus = CorpusService.get_corpus_by_id(corpus_id)
    if not corpus:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Corpus not found"
        )
    
    if not corpus.vertex_corpus_id:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Corpus is not properly configured"
        )
    
    # Get documents from Vertex AI
    try:
        documents = DocumentService.list_documents(corpus.vertex_corpus_id)
        logger.info(
            f"Listed {len(documents)} documents from corpus '{corpus.name}' "
            f"for user {current_user.username}"
        )
        return {
            "status": "success",
            "corpus_id": corpus_id,
            "corpus_name": corpus.name,
            "documents": documents,
            "count": len(documents)
        }
    except Exception as e:
        logger.error(f"Error listing documents in corpus {corpus_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list documents: {str(e)}"
        )


@router.get("/access-logs")
async def get_document_access_logs(
    limit: int = 100,
    request: Request = None,
    current_user: User = Depends(get_current_user_hybrid)
):
    """
    Get document access logs for current user.
    
    **Parameters**:
    - **limit**: Maximum number of records to return (default: 100, max: 500)
    
    **Returns**: List of access log entries
    """
    # Limit the maximum to prevent abuse
    limit = min(limit, 500)
    
    logs = DocumentService.get_access_logs(
        user_id=current_user.id,
        limit=limit
    )
    
    return {
        "logs": logs,
        "count": len(logs),
        "user": current_user.username
    }


@router.get("/corpus/{corpus_id}/access-logs")
async def get_corpus_access_logs(
    corpus_id: int,
    limit: int = 100,
    request: Request = None,
    current_user: User = Depends(get_current_user_hybrid)
):
    """
    Get document access logs for a specific corpus.
    
    **Security**: User must have access to the corpus.
    
    **Parameters**:
    - **corpus_id**: Corpus ID
    - **limit**: Maximum number of records to return
    
    **Returns**: List of access log entries for the corpus
    """
    # Validate corpus access
    if not CorpusService.validate_corpus_access(current_user.id, corpus_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this corpus"
        )
    
    # Limit the maximum
    limit = min(limit, 500)
    
    logs = DocumentService.get_access_logs(
        user_id=current_user.id,
        corpus_id=corpus_id,
        limit=limit
    )
    
    return {
        "logs": logs,
        "count": len(logs),
        "corpus_id": corpus_id,
        "user": current_user.username
    }
