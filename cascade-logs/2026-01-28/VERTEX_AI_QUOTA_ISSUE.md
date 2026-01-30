# Vertex AI Quota Exceeded Issue

**Date:** January 28, 2026, 5:00 PM PST  
**Issue:** "Failed to list documents" error on /open-document page  
**Root Cause:** Google Cloud Vertex AI RAG API quota exceeded  
**Status:** ⚠️ **QUOTA LIMIT - Not a Code Bug**

---

## Error Details

### Frontend Error
```
Failed to list documents
src/lib/api-enhanced.ts (447:33)
```

### Backend Error
```json
{
  "detail": "Failed to list documents: ('Failed in listing the RagFiles due to: ', 
  ResourceExhausted(\"Quota exceeded for quota metric 'VertexRagDataService requests' 
  and limit 'VertexRagDataService requests per minute per region' of service 
  'aiplatform.googleapis.com' for consumer 'project_number:351592762922'.\"))"
}
```

**HTTP Status:** 500 Internal Server Error

---

## Root Cause

### Vertex AI RAG API Quota Limits

**Service:** `aiplatform.googleapis.com`  
**Metric:** `VertexRagDataService requests`  
**Limit:** Requests per minute per region  
**Region:** us-west1  
**Project:** adk-rag-ma (351592762922)

### What Triggered It

During testing, multiple rapid requests were made to:
- `/api/documents/corpus/{id}/list` - Lists all documents in a corpus
- `/api/documents/retrieve` - Retrieves individual documents

Each request calls Vertex AI RAG API's `list_files()` method, which counts against the quota.

---

## Current Implementation

### Backend Has Retry Logic ✅

**File:** `backend/src/services/document_service.py`

```python
@staticmethod
def list_documents(corpus_resource_name: str, max_retries: int = 3) -> list:
    """List all documents in a corpus with retry logic."""
    for attempt in range(max_retries + 1):
        try:
            files = rag.list_files(corpus_resource_name)
            # ... process files ...
            return documents
            
        except google_exceptions.ResourceExhausted as e:
            # 429 RESOURCE_EXHAUSTED - retry with exponential backoff
            if attempt < max_retries:
                wait_time = (2 ** attempt) + (0.1 * attempt)  # 1s, 2.1s, 4.2s
                logger.warning(
                    f"Rate limit hit while listing documents from corpus "
                    f"(attempt {attempt + 1}/{max_retries + 1}). Retrying in {wait_time:.1f}s..."
                )
                time.sleep(wait_time)
                continue
            else:
                logger.error(f"Rate limit exceeded after {max_retries + 1} attempts: {e}")
                raise
```

**Retry Strategy:**
- Attempt 1: Immediate
- Attempt 2: Wait 1.0s
- Attempt 3: Wait 2.1s
- Attempt 4: Wait 4.2s
- Total: 4 attempts over ~7.3 seconds

**Problem:** Even with retries, if the quota is exhausted, all retries fail.

---

## Solutions

### Immediate Workaround (User Action)

**Wait 60 seconds** before retrying the operation. The quota resets every minute.

**Steps:**
1. Wait 1 minute
2. Refresh the browser
3. Navigate to `/open-document`
4. Select corpus and documents

### Short-Term Solutions

#### 1. Implement Caching ⭐ (Recommended)

Cache document lists in PostgreSQL to reduce API calls:

```python
# Cache document list for 5 minutes
@staticmethod
def list_documents_cached(corpus_id: int) -> list:
    # Check cache in database
    cached = DocumentCache.get(corpus_id)
    if cached and not cached.is_expired(minutes=5):
        return cached.documents
    
    # Fetch from Vertex AI
    documents = DocumentService.list_documents(corpus_resource_name)
    
    # Store in cache
    DocumentCache.set(corpus_id, documents)
    return documents
```

**Benefits:**
- Reduces API calls by 90%+
- Faster response times
- Stays within quota limits

#### 2. Increase Retry Wait Times

Increase exponential backoff to spread requests over longer period:

```python
wait_time = (5 ** attempt) + (0.5 * attempt)  # 5s, 25.5s, 125.5s
```

#### 3. Add Rate Limiting Middleware

Implement request throttling on backend:

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.get("/corpus/{corpus_id}/list")
@limiter.limit("10/minute")  # Max 10 requests per minute
async def list_corpus_documents(...):
    ...
```

### Long-Term Solutions

#### 1. Request Quota Increase from Google Cloud

**Steps:**
1. Go to Google Cloud Console
2. Navigate to IAM & Admin → Quotas
3. Search for "VertexRagDataService"
4. Request quota increase for us-west1 region

**Typical Limits:**
- Default: 60 requests/minute
- Can request: 300-600 requests/minute

#### 2. Implement Multi-Region Failover

Distribute requests across multiple regions:
- Primary: us-west1
- Fallback: us-central1, us-east1

#### 3. Use Pagination

Instead of listing all documents at once, implement pagination:

```python
@router.get("/corpus/{corpus_id}/list")
async def list_corpus_documents(
    corpus_id: int,
    page: int = 1,
    page_size: int = 50
):
    # Only fetch requested page
    documents = DocumentService.list_documents_paginated(
        corpus_resource_name,
        page=page,
        page_size=page_size
    )
    return documents
```

---

## Recommended Implementation Priority

### Phase 1: Immediate (Today)
1. ✅ Document the issue (this file)
2. ⏳ Add user-friendly error message in frontend
3. ⏳ Implement basic caching (5-minute TTL)

### Phase 2: This Week
1. Request quota increase from Google Cloud
2. Add rate limiting middleware
3. Implement pagination for large corpora

### Phase 3: Future
1. Multi-region failover
2. Advanced caching strategies
3. Background sync jobs

---

## Code Changes Needed

### 1. Better Error Handling in Frontend

**File:** `frontend/src/lib/api-enhanced.ts`

```typescript
async listCorpusDocuments(corpusId: number): Promise<{...}> {
  const response = await fetch(this.buildUrl(`/api/documents/corpus/${corpusId}/list`), {
    method: 'GET',
    headers: this.getAuthHeaders(),
  });
  
  if (!response.ok) {
    const error = await response.json();
    
    // Check for quota error
    if (error.detail?.includes('Quota exceeded') || error.detail?.includes('ResourceExhausted')) {
      throw new Error('API quota exceeded. Please wait a minute and try again.');
    }
    
    throw new Error('Failed to list documents');
  }
  
  return response.json();
}
```

### 2. User-Friendly Error Display

**File:** `frontend/src/components/emerald-retriever/EmeraldRetriever.tsx`

```typescript
const loadDocuments = async (corpusId: number) => {
  try {
    setLoadingDocuments(true);
    setDocuments([]);
    setSelectedDocument(null);
    
    const response = await apiClient.listCorpusDocuments(corpusId);
    setDocuments(response.documents || []);
  } catch (error) {
    console.error('Failed to load documents:', error);
    
    // Show user-friendly error
    if (error instanceof Error && error.message.includes('quota exceeded')) {
      setError('API rate limit reached. Please wait 60 seconds and try again.');
    } else {
      setError('Failed to load documents. Please try again.');
    }
    
    setDocuments([]);
  } finally {
    setLoadingDocuments(false);
  }
};
```

### 3. Implement Document Caching

**New File:** `backend/src/database/repositories/document_cache_repository.py`

```python
class DocumentCacheRepository:
    @staticmethod
    def get_cached_documents(corpus_id: int) -> Optional[Dict]:
        """Get cached document list if not expired."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT documents, cached_at
                FROM document_cache
                WHERE corpus_id = %s
                AND cached_at > NOW() - INTERVAL '5 minutes'
            """, (corpus_id,))
            return cursor.fetchone()
    
    @staticmethod
    def cache_documents(corpus_id: int, documents: List[Dict]):
        """Cache document list."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO document_cache (corpus_id, documents, cached_at)
                VALUES (%s, %s, NOW())
                ON CONFLICT (corpus_id)
                DO UPDATE SET documents = %s, cached_at = NOW()
            """, (corpus_id, json.dumps(documents), json.dumps(documents)))
            conn.commit()
```

**New Migration:** `backend/src/database/migrations/009_create_document_cache.sql`

```sql
CREATE TABLE IF NOT EXISTS document_cache (
    corpus_id INTEGER PRIMARY KEY REFERENCES corpora(id) ON DELETE CASCADE,
    documents JSONB NOT NULL,
    cached_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_document_cache_cached_at ON document_cache(cached_at);
```

---

## Monitoring

### Check Current Quota Usage

```bash
gcloud monitoring time-series list \
  --filter='metric.type="serviceruntime.googleapis.com/quota/rate/net_usage" AND resource.labels.service="aiplatform.googleapis.com"' \
  --project=adk-rag-ma
```

### View Quota Limits

```bash
gcloud compute project-info describe \
  --project=adk-rag-ma \
  --format="value(quotas)"
```

---

## Testing After Fix

1. Implement caching
2. Wait for quota to reset (60 seconds)
3. Test document listing:
   - First request: Hits Vertex AI API (slow)
   - Second request: Returns from cache (fast)
   - After 5 minutes: Cache expires, hits API again

---

## Related Files

- `backend/src/services/document_service.py` - Has retry logic
- `backend/src/api/routes/documents.py` - Document endpoints
- `frontend/src/lib/api-enhanced.ts` - API client
- `frontend/src/components/emerald-retriever/EmeraldRetriever.tsx` - UI component

---

## Status

⚠️ **QUOTA LIMIT ISSUE**

**Not a code bug** - the application is working correctly. The issue is Google Cloud API rate limits.

**Immediate Action:** Wait 60 seconds before retrying  
**Next Steps:** Implement caching to reduce API calls

---

**Documented By:** Cascade AI Assistant  
**Date:** January 28, 2026, 5:00 PM PST  
**Priority:** Medium (impacts user experience during heavy testing)
