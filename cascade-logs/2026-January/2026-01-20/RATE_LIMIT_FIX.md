# 429 RESOURCE_EXHAUSTED Error - Rate Limit Fix

**Date:** January 20, 2026  
**Issue:** 429 RESOURCE_EXHAUSTED errors when browsing documents in large corpora (148 documents in ai-books)

---

## Problem

### Error Message
```
Error API request failed: {"detail":"Error processing request: 429 RESOURCE_EXHAUSTED. 
{'error': {'code': 429, 'message': 'Resource exhausted. Please try again later. 
Please refer to https://cloud.google.com/vertex-ai/generative-ai/docs/error-code-429 
for more details.', 'status': 'RESOURCE_EXHAUSTED'}}"}
```

### Root Cause
Vertex AI RAG API has rate limits on `rag.list_files()` calls. The document service was making these calls without any retry logic:

1. **Loading document list** → `rag.list_files()` for 148 documents
2. **Clicking a document** → `rag.list_files()` again to find specific file
3. **Multiple rapid actions** → Exceeds rate limit quota

**Files Affected:**
- `backend/src/services/document_service.py`
  - `find_document()` - No retry logic
  - `list_documents()` - No retry logic

**Contrast:** `rag_agent/tools/rag_multi_query.py` already had retry logic for rate limits.

---

## Solution

### Implemented Exponential Backoff Retry Logic

Added automatic retry with exponential backoff matching the pattern already used in `rag_multi_query.py`:

#### Retry Pattern
```python
for attempt in range(max_retries + 1):
    try:
        files = rag.list_files(corpus_resource_name)
        # ... process files ...
        
    except google_exceptions.ResourceExhausted as e:
        if attempt < max_retries:
            wait_time = (2 ** attempt) + (0.1 * attempt)  # 1s, 2.1s, 4.2s
            logger.warning(f"Rate limit hit, retrying in {wait_time:.1f}s...")
            time.sleep(wait_time)
            continue
        else:
            logger.error(f"Rate limit exceeded after {max_retries + 1} attempts")
            raise
```

#### Retry Schedule
- **Attempt 1:** Immediate
- **Attempt 2:** Wait 1.0s
- **Attempt 3:** Wait 2.1s  
- **Attempt 4:** Wait 4.2s
- **After 4 attempts:** Raise exception

### Changes Made

**File:** `backend/src/services/document_service.py`

#### 1. Added Imports
```python
import time
from google.api_core import exceptions as google_exceptions
```

#### 2. Updated `find_document()` Method
- Added `max_retries` parameter (default: 3)
- Wrapped in retry loop
- Catches `google_exceptions.ResourceExhausted`
- Implements exponential backoff
- Logs retry attempts

#### 3. Updated `list_documents()` Method
- Added `max_retries` parameter (default: 3)
- Same retry logic as `find_document()`
- Automatically retries on rate limit errors

---

## Benefits

✅ **Automatic Recovery:** Rate limit errors automatically retry instead of failing  
✅ **User Experience:** No immediate error - transparent retry in background  
✅ **Progressive Backoff:** Reduces load on API with increasing wait times  
✅ **Consistent Pattern:** Matches existing retry logic in `rag_multi_query.py`  
✅ **Configurable:** `max_retries` parameter allows tuning if needed  

---

## Testing

### Test Scenario
1. Navigate to `/test-documents`
2. Select `ai-books` corpus (148 documents)
3. Click multiple documents rapidly
4. Observe:
   - Document list loads successfully (may see retry warnings in logs)
   - Individual documents preview/download successfully
   - No 429 errors shown to user

### Expected Log Output (on rate limit)
```
WARNING: Rate limit hit while listing documents from corpus 
(attempt 2/4). Retrying in 1.0s...
INFO: Listed 148 documents from corpus ...
```

---

## Additional Recommendations

### 1. Implement Caching (Future Enhancement)
Cache `list_files()` results for short duration (30-60 seconds) to reduce API calls:
```python
from functools import lru_cache
from datetime import datetime, timedelta

@lru_cache(maxsize=10)
def _cached_list_files(corpus_resource_name: str, cache_key: int):
    return list(rag.list_files(corpus_resource_name))

# Use with time-based cache invalidation
cache_key = int(datetime.now().timestamp() / 60)  # 1-minute buckets
files = _cached_list_files(corpus_resource_name, cache_key)
```

### 2. Batch Processing
For very large corpora (>200 documents), consider:
- Pagination in frontend
- Loading documents in chunks
- Virtual scrolling for document list

### 3. Monitor Rate Limits
Add metrics/logging to track:
- Rate limit hit frequency
- Retry success rate
- API call patterns by user/corpus

---

## Files Modified

1. **backend/src/services/document_service.py**
   - Lines 6-14: Added imports (`time`, `google_exceptions`)
   - Lines 25-101: Updated `find_document()` with retry loop
   - Lines 104-170: Updated `list_documents()` with retry loop

---

## Deployment

**Backend Server:** Restarted with PID 80348  
**Status:** ✅ Ready for testing  
**No frontend changes required**

---

## References

- [Vertex AI Error Code 429](https://cloud.google.com/vertex-ai/generative-ai/docs/error-code-429)
- Existing retry pattern: `backend/src/rag_agent/tools/rag_multi_query.py:90-109`
