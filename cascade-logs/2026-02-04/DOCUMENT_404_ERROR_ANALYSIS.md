# Document 404 Error Analysis and Solution

**Date:** February 4, 2026  
**Issue:** Recurring 404 "Document not found" errors when opening documents

## Root Cause Analysis

### The Problem

The 404 errors occur because of a **document name mismatch** between what the frontend sends and what the backend searches for in Vertex AI RAG.

### Flow Breakdown

1. **Frontend retrieves document list** (`/api/documents/corpus/{corpus_id}/list`)
   - Returns documents with `display_name` field from Vertex AI
   - Example: `"AI_Research_Paper.pdf"`

2. **User clicks "Open" button**
   - Frontend calls `retrieveDocument(corpusId, document.display_name, true)`
   - This calls `/api/documents/retrieve?corpus_id=X&document_name=AI_Research_Paper.pdf`

3. **Backend `/api/documents/retrieve` endpoint**
   - Calls `DocumentService.find_document(corpus.vertex_corpus_id, document_name)`
   - Searches Vertex AI files by **case-insensitive display name match**
   - Returns document metadata including `source_uri`

4. **Frontend opens DocumentViewer**
   - Uses `document.document.name` (from retrieve response)
   - Builds proxy URL: `/api/documents/proxy/{corpus_id}/{document.document.name}`

5. **Backend `/api/documents/proxy` endpoint** ❌ **FAILS HERE**
   - Calls `DocumentService.find_document(corpus.vertex_corpus_id, document_name)` AGAIN
   - But this time with potentially different name
   - Returns 404 if name doesn't match exactly

### The Critical Issue

**Line 21 in DocumentViewer.tsx:**
```typescript
const documentName = document.document.name;
```

**Line 186-189 in documents.py (retrieve endpoint):**
```python
response_document = {
    'id': document.get('file_id'),
    'name': document.get('display_name'),  # ← Returns display_name
    ...
}
```

**The retrieve endpoint returns `display_name` as `name`**, but when the document was originally added to Vertex AI, it might have been stored with a different internal name or the display name might have changed.

### Why This Causes 404s

1. Document stored in Vertex AI with display_name: `"report.pdf"`
2. Frontend lists documents, gets `"report.pdf"`
3. User clicks Open → retrieve endpoint searches for `"report.pdf"` → **FOUND** ✅
4. Retrieve returns `name: "report.pdf"`
5. DocumentViewer uses `"report.pdf"` to call proxy endpoint
6. Proxy endpoint searches for `"report.pdf"` → **NOT FOUND** ❌

**Why?** Between steps 3-6, the document lookup happens twice, and Vertex AI's internal state or caching might return different results, OR the document's display_name doesn't match what's stored.

## Solutions

### Solution 1: Pass Document ID Instead of Name (RECOMMENDED)

**Pros:**
- IDs are immutable and unique
- No name matching issues
- More reliable

**Cons:**
- Requires API changes
- Need to update DocumentService to support ID-based lookup

**Implementation:**
1. Update proxy endpoint to accept `file_id` instead of `document_name`
2. Update DocumentService to add `find_document_by_id()` method
3. Update frontend to pass `document.id` instead of `document.name`

### Solution 2: Cache Document Metadata in Retrieve Response

**Pros:**
- No additional Vertex AI calls
- Faster performance
- Eliminates duplicate lookups

**Cons:**
- Larger response payload
- Need to pass source_uri through frontend

**Implementation:**
1. Include `source_uri` in retrieve response
2. Update proxy endpoint to accept optional `source_uri` parameter
3. If `source_uri` provided, skip document lookup and use it directly

### Solution 3: Add Retry Logic with Fuzzy Matching

**Pros:**
- Handles edge cases
- Backwards compatible

**Cons:**
- Doesn't solve root cause
- Slower due to retries
- Still unreliable

## Recommended Solution: Hybrid Approach

Combine Solutions 1 and 2 for maximum reliability:

### Phase 1: Immediate Fix (Solution 2)
1. Update retrieve endpoint to include `source_uri` in response
2. Update proxy endpoint to accept `source_uri` as optional parameter
3. Update DocumentViewer to pass `source_uri` when available
4. Fall back to name-based lookup if `source_uri` not provided

### Phase 2: Long-term Fix (Solution 1)
1. Add `find_document_by_id()` to DocumentService
2. Update proxy endpoint to support ID-based lookup
3. Update frontend to use document IDs

## Implementation Plan

### Immediate Fix (30 minutes)

**Backend Changes:**

```python
# documents.py - Update proxy endpoint
@router.get("/proxy/{corpus_id}/{document_name}")
async def proxy_document(
    corpus_id: int,
    document_name: str,
    source_uri: Optional[str] = None,  # NEW: Optional source_uri
    request: Request = None,
    current_user: User = Depends(get_current_user_hybrid)
):
    # Validate corpus access
    if not CorpusService.validate_corpus_access(current_user.id, corpus_id):
        raise HTTPException(status_code=403, detail="Access denied")
    
    # If source_uri provided, use it directly (skip document lookup)
    if source_uri:
        logger.info(f"Using provided source_uri: {source_uri}")
        signed_url, _ = DocumentService.generate_signed_url(source_uri, expiration_minutes=30)
    else:
        # Fall back to name-based lookup
        corpus = CorpusService.get_corpus_by_id(corpus_id)
        if not corpus or not corpus.vertex_corpus_id:
            raise HTTPException(status_code=404, detail="Corpus not found")
        
        document = DocumentService.find_document(corpus.vertex_corpus_id, document_name)
        if not document or not document.get('source_uri'):
            raise HTTPException(status_code=404, detail="Document not found")
        
        signed_url, _ = DocumentService.generate_signed_url(
            document['source_uri'], 
            expiration_minutes=30
        )
    
    # ... rest of proxy logic
```

**Frontend Changes:**

```typescript
// DocumentViewer.tsx
const loadPdfViaProxy = async () => {
  try {
    const corpusId = document.document.corpus_id;
    const documentName = document.document.name;
    const sourceUri = document.document.source_uri; // NEW: Get source_uri
    
    // Build proxy URL with optional source_uri
    const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || 'http://localhost:8000';
    let proxyUrl = `${backendUrl}/api/documents/proxy/${corpusId}/${encodeURIComponent(documentName)}`;
    
    // Add source_uri as query parameter if available
    if (sourceUri) {
      proxyUrl += `?source_uri=${encodeURIComponent(sourceUri)}`;
    }
    
    // ... rest of fetch logic
  }
};
```

```python
# documents.py - Update retrieve endpoint response
response_document = {
    'id': document.get('file_id'),
    'name': document.get('display_name'),
    'corpus_id': corpus_id,
    'corpus_name': corpus.name,
    'file_type': document.get('file_type', 'unknown'),
    'size_bytes': metadata.get('size_bytes'),
    'created_at': document.get('created_at'),
    'updated_at': document.get('updated_at'),
    'source_uri': document.get('source_uri'),  # NEW: Include source_uri
}
```

## Testing Plan

1. **Test with existing documents**
   - Open documents that previously failed
   - Verify no 404 errors
   - Check thumbnail generation works

2. **Test with new documents**
   - Upload new document
   - Verify it appears in list
   - Open and verify it loads

3. **Test edge cases**
   - Documents with special characters in names
   - Documents with very long names
   - Documents with spaces

## Prevention

To prevent this issue in the future:

1. **Always use immutable identifiers** (IDs) for lookups when possible
2. **Cache metadata** to avoid duplicate API calls
3. **Add comprehensive logging** to trace document lookup failures
4. **Implement health checks** that verify document accessibility
5. **Add unit tests** for document name matching logic

## Metrics to Monitor

- Document retrieval success rate
- 404 error frequency
- Average document load time
- Proxy endpoint performance

## Status

- [x] Root cause identified
- [ ] Immediate fix implemented
- [ ] Testing completed
- [ ] Long-term solution planned
