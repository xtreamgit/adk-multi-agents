# Document Download Test Results

**Date:** January 23, 2026  
**Testing:** /test-documents page functionality  
**User:** hector/hector123

---

## ✅ What Works

### 1. Authentication
- Login with hector/hector123 ✅ Working
- JWT token generation ✅ Working

### 2. Corpus Access
- User has access to 6 corpora ✅ Working:
  - ai-books
  - design
  - management  
  - recipes
  - semantic-web
  - test-corpus

### 3. Document Listing
- `/api/corpora/` endpoint ✅ Working
- `/api/documents/corpus/{corpus_id}/list` ✅ Working
- Returns 148 documents from ai-books corpus

### 4. Document Retrieval API
- `/api/documents/retrieve` endpoint ✅ Working
- Document metadata retrieval ✅ Working
- Access logging ✅ Working

---

## ⚠️ What Needs Fixing

### Signed URL Generation

**Problem:** Backend generates public URLs but bucket access is denied

**Test Results:**
```json
{
  "status": "success",
  "document": {
    "id": "5584739968713799868",
    "name": "0132366754_Jang_book.pdf",
    "corpus_id": 2,
    "corpus_name": "ai-books",
    "file_type": "pdf",
    "size_bytes": 8883908
  },
  "access": {
    "url": "https://storage.googleapis.com/develom-documents/0132366754_Jang_book.pdf",
    "expires_at": "2026-01-23T23:15:41.507875+00:00",
    "valid_for_seconds": 1800
  }
}
```

**Accessing the URL returns:** HTTP 403 Forbidden

**Root Cause:**
1. Backend uses default compute service account: `351592762922-compute@developer.gserviceaccount.com`
2. This account doesn't support signed URL generation (no `sign_bytes` capability)
3. Code falls back to public URL: `https://storage.googleapis.com/bucket/path`
4. Bucket `gs://develom-documents` has public access prevention enforced
5. Result: URL generated but not accessible

**Backend Log:**
```
WARNING: Current credentials don't support signing. 
Using public access URL instead of signed URL for gs://develom-documents/...
```

---

## 🔧 Solutions

### Option 1: Use Service Account with Signing Capability (Recommended)

Create a dedicated service account for the backend with signing permissions:

```bash
# 1. Create service account
gcloud iam service-accounts create adk-backend-sa \
  --display-name="ADK Backend Service Account" \
  --project=adk-rag-ma

# 2. Grant necessary permissions
gcloud projects add-iam-policy-binding adk-rag-ma \
  --member="serviceAccount:adk-backend-sa@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding adk-rag-ma \
  --member="serviceAccount:adk-backend-sa@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# 3. Grant storage access with signing capability
gcloud storage buckets add-iam-policy-binding gs://develom-documents \
  --member="serviceAccount:adk-backend-sa@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

gcloud iam service-accounts add-iam-policy-binding \
  adk-backend-sa@adk-rag-ma.iam.gserviceaccount.com \
  --member="serviceAccount:351592762922-compute@developer.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"

# 4. Update Cloud Run service to use new service account
gcloud run services update backend \
  --service-account=adk-backend-sa@adk-rag-ma.iam.gserviceaccount.com \
  --region=us-west1 \
  --project=adk-rag-ma
```

**Benefits:**
- Proper signed URLs with time-limited access
- Secure document downloads
- Audit trail of access
- No public bucket access needed

### Option 2: Remove Public Access Prevention (Not Recommended)

This would make all documents publicly accessible:

```bash
gcloud storage buckets update gs://develom-documents \
  --public-access-prevention=inherited \
  --project=adk-rag-ma

gcloud storage buckets add-iam-policy-binding gs://develom-documents \
  --member="allUsers" \
  --role="roles/storage.objectViewer" \
  --project=adk-rag-ma
```

**Risks:**
- ❌ All documents become publicly accessible
- ❌ No access control
- ❌ Security compliance issues
- ❌ Audit logging limited

### Option 3: Use GCS Signed URLs via Cloud Function (Complex)

Create a Cloud Function that generates signed URLs using a service account with signing permissions, then have the backend call this function.

**Pros:** Separation of concerns  
**Cons:** Added complexity, latency, cost

---

## 📊 Current Status Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Authentication | ✅ Working | hector/hector123 login successful |
| Corpus Access | ✅ Fixed | admin-users group has access to all corpora |
| GCS Permissions | ✅ Fixed | Backend SA can read objects |
| Document API | ✅ Working | Metadata retrieval works |
| URL Generation | ⚠️ Partial | URLs generated but not accessible |
| Document Download | ❌ Blocked | 403 Forbidden on generated URLs |

---

## 🎯 Recommended Next Steps

1. **Immediate:** Create dedicated service account with signing capability
2. **Update:** Cloud Run backend to use new service account
3. **Test:** Document download with properly signed URLs
4. **Verify:** Time-limited access works correctly
5. **Document:** Update deployment guide with service account setup

---

## 📝 Testing Commands

### Test Document Download
```bash
./backend/test_document_download.sh
```

### Manual Test
```bash
# 1. Login
TOKEN=$(curl -s -X POST "https://backend-351592762922.us-west1.run.app/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "hector", "password": "hector123"}' | jq -r '.access_token')

# 2. Get corpora
curl -s -X GET "https://backend-351592762922.us-west1.run.app/api/corpora/" \
  -H "Authorization: Bearer $TOKEN" | jq '.[0]'

# 3. List documents
curl -s -X GET "https://backend-351592762922.us-west1.run.app/api/documents/corpus/2/list" \
  -H "Authorization: Bearer $TOKEN" | jq '.documents[0]'

# 4. Retrieve document
curl -s -X GET "https://backend-351592762922.us-west1.run.app/api/documents/retrieve?corpus_id=2&document_name=DataStructures.pdf&generate_url=true" \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

---

## 🔐 Security Considerations

**Current State:**
- Backend can read GCS objects ✅
- Cannot generate signed URLs ❌
- Falls back to public URLs ❌
- Bucket has public access prevention ✅

**Required State:**
- Backend can read GCS objects ✅
- Can generate time-limited signed URLs ✅
- No public bucket access needed ✅
- Proper audit logging ✅

---

**Conclusion:** Document retrieval system is 90% functional. Only missing piece is proper signed URL generation with a service account that has signing capability. Recommend implementing Option 1 (dedicated service account).
