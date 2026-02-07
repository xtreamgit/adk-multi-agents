# Session Summary - January 25, 2026

## Objective
Fix document retrieval authentication errors in cloud environment (IAP-protected Cloud Run deployment).

---

## Issue Overview

### Problem Statement
The `/test-documents` page in the cloud environment (`https://34.49.46.115.nip.io/test-documents`) displayed authentication errors when attempting to retrieve or list documents, despite working perfectly in the local development environment.

**Errors Observed:**
- 500 Internal Server Error on document list endpoint
- 403 "Not authenticated" on document retrieval endpoint
- Console errors: `Failed to load documents`, `Failed to retrieve document`

---

## Root Cause Analysis

### Authentication Architecture Mismatch

**Cloud Environment (IAP-Protected):**
- All requests to `https://34.49.46.115.nip.io` pass through Google Identity-Aware Proxy (IAP)
- IAP automatically injects `X-Goog-IAP-JWT-Assertion` header for authenticated users
- User can also log in with local credentials (alice/alice123) which creates Bearer token
- Both authentication methods are present simultaneously

**Local Environment:**
- No IAP layer
- Only Bearer token authentication (username/password login)
- Direct API calls to `http://localhost:8000`

### The Breaking Point

**Document Endpoints Configuration:**
```python
# backend/src/api/routes/documents.py (BEFORE FIX)
from middleware.auth_middleware import get_current_user

@router.get("/retrieve")
async def retrieve_document(
    current_user: User = Depends(get_current_user)  # Bearer-only auth
):
```

**The Problem:**
1. `/api/documents/*` endpoints used `get_current_user` (Bearer token only)
2. `get_current_user` middleware only validates `Authorization: Bearer <token>` headers
3. In IAP environment, even with valid Bearer token, the IAP headers confused the middleware
4. Result: 403 "Not authenticated" error

**Why Other Endpoints Worked:**
- `/api/admin/*` already used `get_current_user_hybrid` (IAP + Bearer support)
- `/api/corpora/*`, `/api/agents/*`, `/api/users/*` also used Bearer-only auth
- These worked because they were called from contexts where IAP auth was properly handled

---

## Solution Implemented

### Updated Authentication Middleware

Changed all document endpoints from Bearer-only to hybrid authentication:

**File Modified:** `backend/src/api/routes/documents.py`

```python
# BEFORE
from middleware.auth_middleware import get_current_user

# AFTER
from middleware.hybrid_auth_middleware import get_current_user_hybrid
```

**Endpoints Updated:**
1. `GET /api/documents/retrieve` - Document retrieval with signed URLs
2. `GET /api/documents/corpus/{corpus_id}/list` - List documents in corpus
3. `GET /api/documents/access-logs` - Get document access logs
4. `GET /api/documents/corpus/{corpus_id}/access-logs` - Get corpus-specific logs

**Hybrid Authentication Flow:**
```python
async def get_current_user_hybrid(request: Request, credentials: Optional[HTTPAuthorizationCredentials]):
    # Priority 1: Try IAP authentication
    iap_jwt = request.headers.get("X-Goog-IAP-JWT-Assertion")
    if iap_jwt:
        # Verify IAP JWT and get/create user
        return user
    
    # Priority 2: Fall back to Bearer token
    if credentials:
        token = credentials.credentials
        return AuthService.get_current_user_from_token(token)
    
    # Both failed
    raise HTTPException(401, "Not authenticated")
```

---

## Additional Fixes

### Storage Permissions (Prerequisite)

Before the authentication fix, resolved GCS access permissions:

**Issue:** Backend service account lacked `storage.objects.get` permission
**Solution:** Granted `roles/storage.objectViewer` role
```bash
gcloud projects add-iam-policy-binding adk-rag-ma \
  --member="serviceAccount:adk-backend-sa@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

---

## Deployment Details

**Git Commit:** `9071202`
**Commit Message:**
```
Fix document endpoint authentication for IAP

- Updated /api/documents/* endpoints to use hybrid auth middleware
- Supports both IAP (X-Goog-IAP-JWT-Assertion) and Bearer token auth
- Fixes 403 'Not authenticated' errors in cloud environment
- All document endpoints now work with IAP-protected frontend
```

**Cloud Run Deployment:**
```bash
gcloud run deploy backend \
  --source=backend \
  --region=us-west1 \
  --project=adk-rag-ma \
  --service-account=adk-backend-sa@adk-rag-ma.iam.gserviceaccount.com \
  --allow-unauthenticated
```

**Deployed Revision:** `backend-00084-gdg`
**Service URL:** `https://backend-351592762922.us-west1.run.app`

---

## Testing & Verification

### Test Environment
- **URL:** `https://34.49.46.115.nip.io/test-documents`
- **Authentication:** Both IAP (hector@develom.com) and local (alice/alice123)

### Test Cases
1. ✅ List documents in corpus - Returns document list successfully
2. ✅ Retrieve document with signed URL - Generates valid GCS signed URL
3. ✅ Document preview/download - PDF opens correctly, other files download
4. ✅ No console errors - All 403/500 errors resolved

### Results
**Before Fix:**
- ❌ 500 error: "Failed to list documents"
- ❌ 403 error: "Not authenticated"
- ❌ Documents not accessible

**After Fix:**
- ✅ Document list loads successfully
- ✅ Documents open/download correctly
- ✅ Signed URLs generated properly
- ✅ No authentication errors

---

## Technical Insights

### Why Local Worked But Cloud Didn't

**Local Development:**
```
Frontend (localhost:3000)
    ↓ Bearer token
Backend (localhost:8000)
    ↓ get_current_user validates token
✅ Success
```

**Cloud (Before Fix):**
```
User → IAP Gateway → Frontend
    ↓ IAP JWT + Bearer token
Backend (Cloud Run)
    ↓ get_current_user only checks Bearer token
    ↓ Ignores/confused by IAP headers
❌ 403 Not authenticated
```

**Cloud (After Fix):**
```
User → IAP Gateway → Frontend
    ↓ IAP JWT + Bearer token
Backend (Cloud Run)
    ↓ get_current_user_hybrid
    ↓ Checks IAP JWT first ✓
    ↓ Falls back to Bearer token ✓
✅ Success
```

### Frontend API Client Complexity

The `/test-documents` page uses **two different API clients**, which initially complicated diagnosis:

- `api-enhanced.ts` - Used for corpus listing (`getAllCorporaWithAccess()`)
- `api.ts` - Used for document retrieval (`retrieveDocument()`)

Both clients:
- Read `auth_token` from localStorage
- Send `Authorization: Bearer <token>` header
- Should behave identically

The issue was **backend middleware**, not frontend client configuration.

---

## Key Learnings

### IAP-Protected Cloud Run Best Practices

1. **Use Hybrid Auth for All Authenticated Endpoints**
   - IAP is always present in cloud environment
   - Users may also have local username/password login
   - Endpoints must support both authentication methods

2. **Admin Routes Already Followed This Pattern**
   - `/api/admin/*` used `get_current_user_hybrid` from the start
   - Should have been consistent across all protected routes

3. **Local vs Cloud Parity**
   - Code is identical, but IAP layer changes request flow
   - Always test authenticated endpoints in both environments
   - Don't assume local success means cloud success

4. **Deployment Doesn't Overwrite Fixes**
   - Source code (Git) is single source of truth
   - Deploying from local **applies** fixes to cloud
   - Changes are permanent until next deployment

---

## Files Modified

### Backend
- `backend/src/api/routes/documents.py`
  - Changed import: `auth_middleware` → `hybrid_auth_middleware`
  - Updated 5 endpoint dependencies: `get_current_user` → `get_current_user_hybrid`
  - Lines modified: 14, 34, 214, 277, 307

### Configuration
- IAM Policy: Added `roles/storage.objectViewer` to backend service account

---

## Architecture Summary

### Authentication Layers in Cloud

```
┌─────────────────────────────────────────┐
│  User (browser)                         │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Identity-Aware Proxy (IAP)             │
│  - Google OAuth                         │
│  - Injects X-Goog-IAP-JWT-Assertion     │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Frontend (Cloud Run)                   │
│  - User can also login with alice/alice │
│  - Stores Bearer token in localStorage  │
└──────────────┬──────────────────────────┘
               │
               ▼ (API calls with both headers)
┌─────────────────────────────────────────┐
│  Backend (Cloud Run)                    │
│  - get_current_user_hybrid middleware   │
│  - Validates IAP JWT OR Bearer token    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Vertex AI RAG / Cloud Storage          │
└─────────────────────────────────────────┘
```

---

## Current System Status

### ✅ Working Features
1. **Document Retrieval** - Fixed in this session
   - List documents in corpus
   - Retrieve document with signed URL
   - Document preview/download
   - Access logs

2. **Authentication** - Fully functional
   - IAP (Google OAuth) authentication
   - Local username/password login
   - Hybrid auth middleware
   - JWT token management

3. **Cloud Deployment** - Stable
   - Backend: revision backend-00084-gdg
   - Frontend: IAP-protected domain
   - Storage permissions: Configured
   - CORS: Properly configured

### 🔄 Consistency Improvements Needed

**Other routes still use Bearer-only auth:**
- `/api/agents/*` - Uses `get_current_user`
- `/api/corpora/*` - Uses `get_current_user`
- `/api/users/*` - Uses `get_current_user`
- `/api/groups/*` - Uses `get_current_user`

**Recommendation:** Consider migrating all authenticated endpoints to `get_current_user_hybrid` for consistency, even though they currently work. This would:
- Prevent future issues
- Standardize authentication approach
- Support dual auth universally

**Note:** Not critical since users log in with username/password in cloud, establishing Bearer token. But inconsistency could cause confusion in troubleshooting.

---

## Production Readiness

- [x] Document retrieval working in cloud
- [x] IAP authentication functional
- [x] Local username/password authentication functional
- [x] Hybrid auth implemented for document endpoints
- [x] Storage permissions configured
- [x] CORS configuration correct
- [ ] Consider hybrid auth for all endpoints (optional, low priority)

---

## Status: ✅ ISSUE RESOLVED

Document retrieval now works correctly in both local and cloud environments. Authentication architecture properly handles IAP-protected Cloud Run deployment with dual authentication support.

**Deployed:** backend-00084-gdg  
**Tested:** ✅ All document operations working  
**Next Focus:** Continue normal development with confidence in authentication layer

