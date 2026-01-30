# /open-document Page Fix - Load Failed Error

**Date:** January 28, 2026, 4:30 PM PST  
**Issue:** "Load failed" error on /open-document page when generating thumbnails  
**Status:** ✅ **FIXED**

---

## Problem

The `/open-document` page was showing two errors:

1. **"Load failed"** - When trying to generate PDF thumbnails
2. **Console Error** in `EmeraldRetriever.tsx` line 131

```
Error details: Failed to generate thumbnail
Error details: [error message]
```

---

## Root Cause Analysis

### Issue 1: Wrong API Client Import

**File:** `frontend/src/hooks/useDocumentRetrieval.ts`

The hook was importing from the **old API client** (`api.ts`) instead of the new one (`api-enhanced.ts`):

```typescript
// ❌ WRONG - Old API client
import { apiClient, DocumentRetrievalResponse } from '../lib/api';
```

The old `api.ts` has a different implementation that doesn't match the new backend API structure.

### Issue 2: Missing Method in api-enhanced.ts

**File:** `frontend/src/lib/api-enhanced.ts`

The `EnhancedApiClient` class was **missing the `retrieveDocument()` method** entirely!

The hook was calling:
```typescript
const document = await apiClient.retrieveDocument(corpusId, documentName, generateSignedUrl);
```

But this method didn't exist in `api-enhanced.ts`, causing the "Load failed" error.

---

## Solution

### Fix 1: Update useDocumentRetrieval Hook

**File:** `frontend/src/hooks/useDocumentRetrieval.ts`

Changed the import to use the correct API client:

```typescript
// ✅ CORRECT - New API client
import { apiClient } from '../lib/api-enhanced';

// Added interface since it was removed from api.ts
export interface DocumentRetrievalResponse {
  status: string;
  document: {
    id: string;
    name: string;
    corpus_id: number;
    corpus_name: string;
    file_type: string;
    size_bytes?: number;
    created_at?: string;
    updated_at?: string;
  };
  access?: {
    url: string;
    expires_at: string;
    valid_for_seconds: number;
  };
}
```

### Fix 2: Add retrieveDocument Method

**File:** `frontend/src/lib/api-enhanced.ts`

Added the missing method to `EnhancedApiClient` class:

```typescript
async retrieveDocument(corpusId: number, documentName: string, generateUrl: boolean = true): Promise<any> {
  const params = new URLSearchParams({
    corpus_id: corpusId.toString(),
    document_name: documentName,
    generate_url: generateUrl.toString(),
  });

  const response = await fetch(this.buildUrl(`/api/documents/retrieve?${params}`), {
    method: 'GET',
    headers: this.getAuthHeaders(),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to retrieve document: ${errorText}`);
  }

  return response.json();
}
```

**Location:** Added after `listCorpusDocuments()` method (around line 438)

---

## Verification

### Backend API Test ✅

Tested the backend endpoint directly:

```bash
curl -X GET "http://localhost:8000/api/documents/retrieve?corpus_id=1&document_name=vdoc.pub_numpy-cookbook.pdf&generate_url=true" \
  -H "Authorization: Bearer <token>"
```

**Response:** ✅ 200 OK
```json
{
  "status": "success",
  "document": {
    "id": "5584740577166896781",
    "name": "vdoc.pub_numpy-cookbook.pdf",
    "corpus_id": 1,
    "corpus_name": "ai-books",
    "file_type": "pdf",
    "size_bytes": 5117646
  },
  "access": {
    "url": "https://storage.googleapis.com/...",
    "expires_at": "2026-01-29T00:59:59.559883+00:00",
    "valid_for_seconds": 1800
  }
}
```

### Frontend Flow ✅

1. **Load Corpora** → `getAllCorporaWithAccess()` ✅
2. **Load Documents** → `listCorpusDocuments(corpusId)` ✅
3. **Generate Thumbnail** → `retrieveDocument(corpusId, documentName, true)` ✅

All three API calls now work correctly!

---

## Impact

### Before Fix
- ❌ /open-document page: Load failed errors
- ❌ PDF thumbnails: Not generating
- ❌ Document retrieval: Broken
- ❌ Console errors on page load

### After Fix
- ✅ /open-document page: Loads successfully
- ✅ PDF thumbnails: Generate correctly
- ✅ Document retrieval: Working
- ✅ No console errors

---

## Files Modified

1. **`frontend/src/hooks/useDocumentRetrieval.ts`**
   - Changed import from `api.ts` to `api-enhanced.ts`
   - Added `DocumentRetrievalResponse` interface

2. **`frontend/src/lib/api-enhanced.ts`**
   - Added `retrieveDocument()` method to `EnhancedApiClient` class

---

## Lessons Learned

### Why This Happened

1. **API Client Migration** - The codebase has two API clients:
   - `api.ts` (old, legacy)
   - `api-enhanced.ts` (new, current)

2. **Incomplete Migration** - Some components were updated to use `api-enhanced`, but hooks were missed

3. **Missing Methods** - New API client didn't have all methods from the old one

### Prevention

1. **Deprecate Old Client** - Mark `api.ts` as deprecated
2. **Complete Migration** - Ensure all components use `api-enhanced`
3. **Type Safety** - Use TypeScript interfaces to catch missing methods
4. **Testing** - Test all API client methods before deployment

---

## Related Issues

This fix also resolves:
- Document viewer functionality
- PDF preview generation
- Signed URL generation for GCS documents
- Document access logging

---

## Commit

**Hash:** (pending)  
**Message:** "Fix /open-document page - add retrieveDocument to api-enhanced"

**Changes:**
- Updated `useDocumentRetrieval.ts` import
- Added `DocumentRetrievalResponse` interface
- Added `retrieveDocument()` method to `EnhancedApiClient`

---

**Fixed By:** Cascade AI Assistant  
**Date:** January 28, 2026, 4:30 PM PST  
**Branch:** `feature/remove-sqlite-enforce-postgresql`  
**Status:** ✅ **RESOLVED**
