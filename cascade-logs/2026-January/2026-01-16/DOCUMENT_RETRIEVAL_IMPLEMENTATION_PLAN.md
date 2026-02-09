# Document Retrieval and Display Feature - Implementation Plan

**Created:** January 16, 2026  
**Session:** file-display  
**Priority:** High  
**Guidelines:** Security-first, Performance-optimized

---

## Executive Summary

This plan outlines the implementation of a document retrieval and display feature that allows users to request, retrieve, and view complete documents from Vertex AI RAG corpora through conversational interaction with the agent.

### User Story
> "As Alice, when I'm searching for a document about hacking in the ai-books corpus, I can ask the agent to open the complete document. The agent will search for the document by name, verify I have access, and open it in a browser view where I can read the full content."

### Key Requirements
- **Security:** Enforce corpus access control, validate user permissions
- **Speed:** Minimize latency through signed URLs, CDN-like delivery
- **UX:** Seamless agent-to-document workflow with proper feedback
- **Format Support:** PDF, TXT, DOCX, and other common document types

---

## Architecture Overview

### Current System Context

**Document Storage:**
- Documents stored in Google Cloud Storage (GCS) buckets
- Indexed in Vertex AI RAG corpora
- Metadata accessible via `rag.list_files(corpus_resource_name)`
- Each file has: `display_name`, `source_uri`, `file_id`, `create_time`

**Security Model:**
- IAP/OAuth authentication at frontend
- JWT-based authentication for API access
- Group-based corpus access control (read/write/admin permissions)
- Session-level corpus activation

**Existing Components:**
- `get_corpus_info` tool - lists files in corpus
- `get_document_resource_name` utility - finds document by display name
- Corpus access validation via `CorpusService.validate_corpus_access()`
- Cloud Storage client available in backend

---

## Security Architecture

### Multi-Layer Security Approach

```
User Request → Agent Tool → Backend API → Security Checks → GCS Access → Document Delivery
                                              ↓
                                   [Corpus Access Validation]
                                   [Document Existence Check]
                                   [Signed URL Generation]
                                   [Audit Logging]
```

### Security Checkpoints

1. **Authentication (Layer 1)**
   - User must be authenticated (JWT token or IAP)
   - Session must be valid and active

2. **Corpus Authorization (Layer 2)**
   - User must have access to the corpus containing the document
   - Validated via `CorpusService.validate_corpus_access(user_id, corpus_id)`
   - Permission level checked (minimum: 'read')

3. **Document Verification (Layer 3)**
   - Document must exist in the specified corpus
   - Verified via Vertex AI RAG `list_files()`
   - Display name match (case-insensitive)

4. **GCS Access Control (Layer 4)**
   - Generate time-limited signed URL (15-30 minutes)
   - URL expires automatically for security
   - No permanent access tokens exposed

5. **Audit Trail (Layer 5)**
   - Log all document access requests
   - Track: user_id, corpus_id, document_name, timestamp, success/failure
   - Enable compliance and security monitoring

### Threat Mitigation

| Threat | Mitigation |
|--------|-----------|
| Unauthorized access | Multi-layer permission checks |
| URL sharing | Time-limited signed URLs (15-30 min expiry) |
| Corpus enumeration | Return only user's accessible corpora |
| Large file DoS | Implement rate limiting per user |
| Injection attacks | Input sanitization, parameterized queries |

---

## Performance Strategy

### Speed Optimization Approach

**Target Metrics:**
- Document search: < 2 seconds
- URL generation: < 1 second
- Document load: < 3 seconds (for typical PDFs)

**Optimization Techniques:**

1. **Caching Layer**
   - Cache Vertex AI RAG file listings (5-minute TTL)
   - Cache corpus metadata in Redis/memory
   - Reduce repeated API calls to Vertex AI

2. **Signed URL Strategy**
   - Generate GCS signed URLs server-side
   - Direct browser-to-GCS download (bypass backend)
   - Leverage GCS edge caching for repeated access

3. **Lazy Loading**
   - Return document metadata immediately
   - Stream large documents progressively
   - Use HTTP range requests for PDF pagination

4. **Parallel Processing**
   - Concurrent permission checks and document lookup
   - Async API calls where possible

5. **Connection Pooling**
   - Reuse GCS client connections
   - Connection pool for database queries

---

## Implementation Phases

## Phase 1: Backend Foundation (Days 1-2)

### 1.1 Database Schema Updates

**New Table: `document_access_log`**
```sql
CREATE TABLE document_access_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    corpus_id INTEGER NOT NULL REFERENCES corpora(id),
    document_name VARCHAR(255) NOT NULL,
    document_file_id VARCHAR(255),
    access_type VARCHAR(50) DEFAULT 'view',
    success BOOLEAN NOT NULL,
    error_message TEXT,
    source_uri TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_document_access_user ON document_access_log(user_id);
CREATE INDEX idx_document_access_corpus ON document_access_log(corpus_id);
CREATE INDEX idx_document_access_time ON document_access_log(accessed_at);
```

**Purpose:** Audit trail, compliance, security monitoring

### 1.2 New Agent Tool: `retrieve_document`

**Location:** `backend/src/rag_agent/tools/retrieve_document.py`

**Function Signature:**
```python
def retrieve_document(
    corpus_name: str,
    document_name: str,
    tool_context: ToolContext,
) -> dict:
    """
    Retrieve a document from a corpus by name.
    
    Args:
        corpus_name: Name of the corpus containing the document
        document_name: Display name of the document to retrieve
        tool_context: Tool context for state management
        
    Returns:
        dict with document metadata and retrieval URL
    """
```

**Logic Flow:**
1. Validate corpus exists using `check_corpus_exists()`
2. Get corpus resource name via `get_corpus_resource_name()`
3. Search for document using `get_document_resource_name()`
4. Extract document metadata (file_id, source_uri, display_name)
5. Return document details for backend API call
6. Log tool invocation with context

**Return Format:**
```python
{
    "status": "success",
    "corpus_name": "ai-books",
    "document_name": "Hacking with Python.pdf",
    "file_id": "1234567890",
    "source_uri": "gs://bucket/path/to/file.pdf",
    "display_name": "Hacking with Python.pdf",
    "file_type": "pdf",
    "create_time": "2024-01-15T10:30:00Z",
    "message": "Document found. Use the backend API to retrieve."
}
```

### 1.3 Backend API Endpoint

**Location:** `backend/src/api/routes/documents.py` (new file)

**Endpoint:** `GET /api/documents/retrieve`

**Request Parameters:**
- `corpus_id` (int, required): Corpus ID
- `document_name` (str, required): Document display name
- `generate_url` (bool, optional): Whether to generate signed URL (default: true)

**Response Format:**
```python
{
    "status": "success",
    "document": {
        "id": "file_id",
        "name": "Hacking with Python.pdf",
        "corpus_id": 5,
        "corpus_name": "ai-books",
        "file_type": "pdf",
        "size_bytes": 2457600,
        "created_at": "2024-01-15T10:30:00Z"
    },
    "access": {
        "url": "https://storage.googleapis.com/...[signed_url]...",
        "expires_at": "2024-01-16T11:00:00Z",
        "valid_for_seconds": 1800
    },
    "metadata": {
        "page_count": 247,
        "author": "John Doe"
    }
}
```

**Security Implementation:**
```python
from fastapi import APIRouter, HTTPException, Depends, Request
from services.corpus_service import CorpusService
from services.document_service import DocumentService  # New service
from middleware.auth_middleware import get_current_user
from models.user import User

router = APIRouter(prefix="/api/documents", tags=["Documents"])

@router.get("/retrieve")
async def retrieve_document(
    corpus_id: int,
    document_name: str,
    generate_url: bool = True,
    request: Request = None,
    current_user: User = Depends(get_current_user)
):
    # 1. Validate corpus access
    if not CorpusService.validate_corpus_access(current_user.id, corpus_id):
        raise HTTPException(status_code=403, detail="No access to corpus")
    
    # 2. Get corpus details
    corpus = CorpusService.get_corpus_by_id(corpus_id)
    if not corpus:
        raise HTTPException(status_code=404, detail="Corpus not found")
    
    # 3. Search for document
    document = DocumentService.find_document(corpus.vertex_corpus_id, document_name)
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # 4. Generate signed URL if requested
    signed_url = None
    expires_at = None
    if generate_url:
        signed_url, expires_at = DocumentService.generate_signed_url(
            document['source_uri'],
            expiration_minutes=30
        )
    
    # 5. Log access
    DocumentService.log_access(
        user_id=current_user.id,
        corpus_id=corpus_id,
        document_name=document_name,
        document_file_id=document['file_id'],
        source_uri=document['source_uri'],
        success=True,
        ip_address=request.client.host if request else None,
        user_agent=request.headers.get('user-agent') if request else None
    )
    
    # 6. Return response
    return {
        "status": "success",
        "document": document,
        "access": {
            "url": signed_url,
            "expires_at": expires_at,
            "valid_for_seconds": 1800
        }
    }
```

### 1.4 Document Service

**Location:** `backend/src/services/document_service.py` (new file)

**Key Methods:**

```python
class DocumentService:
    @staticmethod
    def find_document(corpus_resource_name: str, document_name: str) -> Optional[dict]:
        """Search for document in corpus by display name."""
        # Use rag.list_files() to find document
        # Return document metadata
        
    @staticmethod
    def generate_signed_url(source_uri: str, expiration_minutes: int = 30) -> tuple[str, datetime]:
        """Generate time-limited signed URL for GCS object."""
        # Parse GCS URI: gs://bucket/path/to/file
        # Use google.cloud.storage to generate signed URL
        # Return (url, expiration_datetime)
        
    @staticmethod
    def log_access(user_id: int, corpus_id: int, document_name: str, 
                   document_file_id: str, source_uri: str, success: bool,
                   ip_address: str = None, user_agent: str = None,
                   error_message: str = None):
        """Log document access to audit trail."""
        # Insert into document_access_log table
        
    @staticmethod
    def get_document_metadata(source_uri: str) -> dict:
        """Extract metadata from document (size, type, etc)."""
        # Parse GCS URI and get object metadata
        # Return file size, content type, etc
```

**GCS Signed URL Implementation:**
```python
from google.cloud import storage
from datetime import datetime, timedelta
import re

def generate_signed_url(source_uri: str, expiration_minutes: int = 30) -> tuple[str, datetime]:
    # Parse gs://bucket/path/to/file
    match = re.match(r'gs://([^/]+)/(.+)', source_uri)
    if not match:
        raise ValueError(f"Invalid GCS URI: {source_uri}")
    
    bucket_name = match.group(1)
    object_path = match.group(2)
    
    # Initialize GCS client
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(object_path)
    
    # Generate signed URL (v4 signing)
    expiration = timedelta(minutes=expiration_minutes)
    expires_at = datetime.now(timezone.utc) + expiration
    
    signed_url = blob.generate_signed_url(
        version="v4",
        expiration=expiration,
        method="GET"
    )
    
    return signed_url, expires_at
```

---

## Phase 2: Frontend Integration (Days 3-4)

### 2.1 Document Viewer Component

**Location:** `frontend/src/components/DocumentViewer.tsx`

**Features:**
- PDF rendering using `react-pdf` or `@react-pdf-viewer/core`
- Text file display with syntax highlighting
- Document metadata display
- Download button
- Close/minimize controls
- Loading states and error handling

**Component Structure:**
```typescript
interface DocumentViewerProps {
  documentUrl: string;
  documentName: string;
  documentType: string;
  expiresAt: string;
  onClose: () => void;
}

export function DocumentViewer({
  documentUrl,
  documentName,
  documentType,
  expiresAt,
  onClose
}: DocumentViewerProps) {
  // PDF.js or iframe rendering
  // Handle different document types
  // Show expiration warning
}
```

**Rendering Strategy:**

1. **PDF Files:**
   - Use `react-pdf` library or `@react-pdf-viewer`
   - Progressive loading with page navigation
   - Zoom controls, search functionality
   
2. **Text Files:**
   - Direct text rendering with code highlighting (Prism.js)
   - Markdown rendering if applicable
   
3. **Other Formats:**
   - Use iframe with Google Docs Viewer fallback
   - Or direct download with file icon

**Modal/Drawer Options:**
- Full-screen overlay modal for immersive reading
- Side drawer that slides from right (keeps chat visible)
- Resizable split-pane view

### 2.2 API Integration

**Location:** `frontend/src/lib/api-documents.ts` (new file)

```typescript
export interface DocumentRetrievalRequest {
  corpusId: number;
  documentName: string;
  generateUrl?: boolean;
}

export interface DocumentRetrievalResponse {
  status: string;
  document: {
    id: string;
    name: string;
    corpus_id: number;
    corpus_name: string;
    file_type: string;
    size_bytes: number;
    created_at: string;
  };
  access: {
    url: string;
    expires_at: string;
    valid_for_seconds: number;
  };
}

export async function retrieveDocument(
  request: DocumentRetrievalRequest,
  token: string
): Promise<DocumentRetrievalResponse> {
  const response = await fetch(
    `/api/documents/retrieve?corpus_id=${request.corpusId}&document_name=${encodeURIComponent(request.documentName)}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    }
  );
  
  if (!response.ok) {
    throw new Error('Failed to retrieve document');
  }
  
  return response.json();
}
```

### 2.3 Chat Interface Integration

**Location:** `frontend/src/components/ChatInterface.tsx`

**Enhancement:**
- Detect document retrieval responses from agent
- Parse document metadata from agent response
- Trigger `DocumentViewer` component automatically
- Show "Opening document..." loading state
- Handle errors gracefully with retry option

**Agent Response Detection:**
```typescript
// Look for structured response from retrieve_document tool
if (message.includes('document retrieval') || 
    message.metadata?.action === 'retrieve_document') {
  const corpusId = extractCorpusId(message);
  const documentName = extractDocumentName(message);
  
  // Fetch document URL
  const docResponse = await retrieveDocument({ corpusId, documentName }, token);
  
  // Open viewer
  setActiveDocument(docResponse);
  setShowDocumentViewer(true);
}
```

---

## Phase 3: Agent Integration (Day 5)

### 3.1 Update Agent Tool Registry

**Location:** `backend/src/rag_agent/tools/__init__.py`

```python
from .retrieve_document import retrieve_document

__all__ = [
    # ... existing tools ...
    "retrieve_document",
]
```

### 3.2 Agent Prompt Enhancement

Update agent system prompt to include document retrieval capabilities:

```
You have access to a document retrieval tool. When a user asks to view or open 
a complete document, use the retrieve_document tool to find it. Always confirm 
the exact document name before retrieving.

Example workflow:
User: "Show me the document about Python hacking in ai-books"
1. Search for document with matching name in ai-books corpus
2. Use retrieve_document(corpus_name="ai-books", document_name="Python Hacking.pdf")
3. Inform user the document will open in their browser
```

### 3.3 Tool Usage Guidelines

**Agent should:**
- Confirm corpus name and document name with user if ambiguous
- Suggest document names if multiple matches found
- Explain what will happen ("I'll open this document for you...")
- Handle errors gracefully ("Document not found. Did you mean...?")

**Agent should NOT:**
- Retrieve documents without user request
- Open multiple documents simultaneously without asking
- Expose internal file paths or GCS URIs to user

---

## Phase 4: Testing & Optimization (Day 6)

### 4.1 Security Testing

**Test Cases:**
1. **Unauthorized Access**
   - User without corpus access tries to retrieve document
   - Expected: 403 Forbidden
   
2. **Invalid Corpus**
   - Request document from non-existent corpus
   - Expected: 404 Not Found
   
3. **Invalid Document**
   - Request non-existent document from valid corpus
   - Expected: 404 Not Found
   
4. **Expired URL**
   - Try to access document after signed URL expiration
   - Expected: GCS 403 error
   
5. **URL Tampering**
   - Modify signed URL parameters
   - Expected: GCS signature validation failure

### 4.2 Performance Testing

**Metrics to Measure:**
1. Document search latency (target: < 2s)
2. Signed URL generation time (target: < 1s)
3. First byte time for document load (target: < 2s)
4. Concurrent request handling (10+ users)

**Load Testing:**
```bash
# Use Apache Bench or k6
k6 run document-retrieval-load-test.js
```

### 4.3 User Acceptance Testing

**Test Scenarios:**
1. Alice searches for "hacking" in ai-books corpus
2. Agent suggests 3 matching documents
3. Alice says "open the first one"
4. Document opens in modal viewer
5. Alice reads, zooms, navigates pages
6. Alice closes and continues chat

---

## Phase 5: Deployment & Monitoring (Day 7)

### 5.1 Deployment Checklist

- [ ] Database migration applied to Cloud SQL
- [ ] New service deployed to Cloud Run
- [ ] GCS IAM permissions configured
- [ ] Frontend assets rebuilt and deployed
- [ ] API endpoints tested in production
- [ ] Audit logging verified
- [ ] Monitoring dashboards created

### 5.2 IAM Configuration

**GCS Bucket Permissions:**
```bash
# Service account needs Storage Object Viewer role
gcloud projects add-iam-policy-binding adk-rag-ma \
  --member="serviceAccount:backend-sa@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
  
# For signed URL generation, also need signBlob permission
gcloud iam service-accounts add-iam-policy-binding \
  backend-sa@adk-rag-ma.iam.gserviceaccount.com \
  --member="serviceAccount:backend-sa@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

### 5.3 Monitoring & Alerts

**Metrics to Track:**
- Document retrieval success rate
- Average response time
- Failed access attempts (security)
- GCS bandwidth usage
- Signed URL generation errors

**Cloud Monitoring Alerts:**
```yaml
- name: High Document Retrieval Failures
  condition: error_rate > 5%
  notification: email + slack
  
- name: Slow Document Retrieval
  condition: p95_latency > 5s
  notification: email
  
- name: Suspicious Access Pattern
  condition: failed_auth_attempts > 10 per user per minute
  notification: security-team
```

---

## Alternative Approaches Considered

### Option 1: Direct GCS Access (Not Recommended)
**Pros:** Simplest implementation, lowest latency
**Cons:** No access control, security risk, audit trail missing
**Decision:** Rejected due to security concerns

### Option 2: Proxy All Document Traffic Through Backend (Not Recommended)
**Pros:** Complete control, easy to monitor
**Cons:** High bandwidth costs, increased latency, scalability issues
**Decision:** Rejected due to performance impact

### Option 3: Signed URLs with Backend Validation (Selected)
**Pros:** Secure, performant, scalable, audit-able
**Cons:** Slightly more complex implementation
**Decision:** **Selected** - Best balance of security and performance

### Option 4: WebSocket Streaming
**Pros:** Real-time progress, better for large files
**Cons:** More complex, requires persistent connections
**Decision:** Consider for Phase 6 enhancement

---

## Dependencies

### Backend
```txt
google-cloud-storage==2.10.0  # For GCS signed URLs
PyPDF2==3.0.1  # Optional: PDF metadata extraction
python-magic==0.4.27  # File type detection
```

### Frontend
```json
{
  "react-pdf": "^7.5.1",
  "@react-pdf-viewer/core": "^3.12.0",
  "pdfjs-dist": "^3.11.174"
}
```

---

## Success Criteria

### Functional Requirements
- ✅ User can request document through agent chat
- ✅ Agent searches and confirms document name
- ✅ Document opens in browser viewer
- ✅ User can read, navigate, zoom, download
- ✅ All access is logged for audit

### Non-Functional Requirements
- ✅ Document retrieval < 3 seconds end-to-end
- ✅ 100% access control enforcement
- ✅ Zero unauthorized document access
- ✅ Support for PDF, TXT, DOCX formats
- ✅ Works on desktop and mobile browsers

---

## Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| GCS signed URL quota limits | Low | High | Implement caching, rate limiting |
| Large file performance | Medium | Medium | Stream files, add size limits |
| Browser compatibility | Medium | Low | Test on Chrome, Firefox, Safari |
| Cost overrun (GCS egress) | Low | Medium | Monitor bandwidth, set alerts |
| Security vulnerability | Low | High | Penetration testing, code review |

---

## Future Enhancements (Phase 6+)

1. **Document Preview in Chat**
   - Show thumbnail or first page in chat
   - Inline preview without opening full viewer

2. **Document Annotations**
   - Highlight and comment on documents
   - Save annotations per user
   - Share annotations with team

3. **Multi-Document Comparison**
   - Open multiple documents side-by-side
   - Compare versions
   - Cross-reference citations

4. **Advanced Search**
   - Full-text search within documents
   - Search across all accessible documents
   - Semantic search integration

5. **Offline Access**
   - Download for offline reading
   - PWA caching strategy
   - Sync read position across devices

6. **Document Management**
   - Upload new documents through chat
   - Update/replace existing documents
   - Delete documents (with proper permissions)

---

## Timeline Summary

| Phase | Duration | Deliverables |
|-------|----------|-------------|
| Phase 1: Backend | 2 days | Agent tool, API endpoint, DocumentService |
| Phase 2: Frontend | 2 days | DocumentViewer component, API integration |
| Phase 3: Agent | 1 day | Tool registration, prompt updates |
| Phase 4: Testing | 1 day | Security tests, performance tests |
| Phase 5: Deployment | 1 day | Production deployment, monitoring |
| **Total** | **7 days** | **Complete feature ready for production** |

---

## Conclusion

This implementation plan provides a secure, performant, and user-friendly document retrieval system that integrates seamlessly with the existing RAG agent architecture. By using GCS signed URLs, we achieve direct browser-to-storage access while maintaining full security control. The phased approach allows for iterative testing and refinement, ensuring a robust production-ready feature.

**Next Steps:**
1. Review and approve this plan
2. Create JIRA/GitHub issues for each phase
3. Assign developers and set sprint goals
4. Begin Phase 1 implementation

**Questions for Product/Engineering:**
- Preferred document viewer library (react-pdf vs iframe)?
- Signed URL expiration time (15 min, 30 min, 1 hour)?
- Document size limits (per file, per user)?
- Rate limiting thresholds?
- Monitoring dashboard preferences?
