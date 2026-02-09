# Complete IAP Authentication Solution - Final

**Date:** January 22, 2026  
**Time:** 5:25 PM PST  
**Status:** ✅ **FULLY RESOLVED**

---

## 🎉 Success!

The `/api/admin/audit` endpoint is now **fully functional** via IAP authentication at:
```
https://34.49.46.115.nip.io/api/admin/audit
```

---

## Journey to Solution

### Problem 1: Database Schema Missing Admin Tables ✅ FIXED
**Error:** 500 Internal Server Error  
**Cause:** `corpus_audit_log` table didn't exist  
**Solution:** Created migration script and synced database  
**Files:**
- `backend/migrations/fix_cloud_schema.sql`
- `backend/sync_database_schemas.sh`

### Problem 2: Pydantic Validation Error ✅ FIXED
**Error:** 500 Internal Server Error  
**Cause:** `AuditLogEntry` model validation failed - expected strings but got dicts  
**Solution:** Changed `changes` and `metadata` fields to `Any` type  
**File:** `backend/src/models/admin.py`

### Problem 3: Missing Admin Role ✅ FIXED
**Error:** 403 Forbidden  
**Cause:** No "admin" role in database  
**Solution:** Created admin role and granted to users  
**File:** `backend/grant_admin_access.sql`

### Problem 4: IAP Authentication Not Supported ✅ FIXED
**Error:** `{"detail":"Not authenticated"}`  
**Cause:** Admin endpoints only checked Bearer tokens, not IAP headers  
**Solution:** Created hybrid authentication middleware  
**File:** `backend/src/middleware/hybrid_auth_middleware.py`

### Problem 5: Missing IAP Configuration ✅ FIXED
**Error:** `IAP_AUDIENCE not configured`  
**Cause:** Backend missing IAP environment variables  
**Solution:** Added `PROJECT_NUMBER` and `BACKEND_SERVICE_ID`  
**Command:**
```bash
gcloud run services update backend \
  --update-env-vars="PROJECT_NUMBER=351592762922,BACKEND_SERVICE_ID=2781125957286789109"
```

### Problem 6: Certificate Verification Failure ✅ FIXED
**Error:** `Certificate for key id yUwjVg not found`  
**Cause:** Google's `id_token.verify_oauth2_token()` couldn't fetch IAP public keys  
**Solution:** Implemented manual JWT verification using PyJWT  
**Changes:**
- Added `PyJWT==2.8.0` to requirements.txt
- Rewrote `IAPService.verify_iap_jwt()` to manually fetch and verify IAP tokens
- Fixed google-auth dependency conflict

### Problem 7: Missing Admin Module (import error) ✅ FIXED
**Error:** `ModuleNotFoundError: No module named 'jwt'`  
**Cause:** PyJWT not installed, causing admin routes to fail import  
**Solution:** Fixed requirements.txt dependencies and rebuilt

### Problem 8: User Missing Admin Privileges ✅ FIXED
**Error:** 403 Forbidden  
**Cause:** IAP user `hector@develom.com` auto-created but not in admin groups  
**Solution:** Granted admin access to hector  
**File:** `backend/grant_admin_to_hector.sql`

---

## Final Working Solution

### Architecture

```
Browser → Google OAuth → IAP → Load Balancer → Backend (Cloud Run)
                          ↓        ↓                ↓
                      JWT Token Headers      Hybrid Auth Middleware
                                                   ↓
                                          1. Check IAP JWT first
                                          2. Manually verify with PyJWT
                                          3. Fetch IAP public keys
                                          4. Decode and validate token
                                          5. Get/create user in database
                                          6. Check admin-users group
                                                   ↓
                                          Return Audit Log Data
```

### Key Components

**1. Hybrid Authentication Middleware**
```python
# backend/src/middleware/hybrid_auth_middleware.py
async def get_current_user_hybrid(request: Request, credentials: Optional) -> User:
    # Try IAP JWT first
    iap_jwt = request.headers.get("X-Goog-IAP-JWT-Assertion")
    if iap_jwt:
        # Verify IAP token manually
        user = verify_and_get_user_from_iap(iap_jwt)
        if user:
            return user
    
    # Fall back to Bearer token
    if credentials:
        user = get_user_from_bearer_token(credentials.credentials)
        if user:
            return user
    
    raise HTTPException(401, "Not authenticated")
```

**2. Manual IAP JWT Verification**
```python
# backend/src/services/iap_service.py
def verify_iap_jwt(iap_jwt: str) -> Dict:
    # Fetch IAP public keys
    response = requests.get('https://www.gstatic.com/iap/verify/public_key')
    certs = response.json()
    
    # Decode JWT header to get key id
    header = jwt.get_unverified_header(iap_jwt)
    key_id = header.get('kid')
    
    # Get the public key
    public_key = certs[key_id]
    
    # Verify and decode
    decoded_token = jwt.decode(
        iap_jwt,
        public_key,
        algorithms=['ES256'],
        audience=IAP_AUDIENCE
    )
    
    return decoded_token
```

**3. Admin Route Protection**
```python
# backend/src/api/routes/admin.py
async def require_admin(current_user: User = Depends(get_current_user_hybrid)) -> User:
    # Check if user is in admin-users group
    user_groups = get_user_groups(current_user.id)
    is_admin = any(group['name'] == 'admin-users' for group in user_groups)
    
    if not is_admin:
        raise HTTPException(403, "Admin privileges required")
    
    return current_user

@router.get("/audit", response_model=List[AuditLogEntry])
async def get_audit_log(current_user: User = Depends(require_admin)):
    return AuditRepository.get_all()
```

---

## Environment Variables

**Backend Cloud Run Service:**
```bash
PROJECT_NUMBER=351592762922
BACKEND_SERVICE_ID=2781125957286789109
DB_TYPE=postgresql
CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db
DB_NAME=adk_agents_db
DB_USER=adk_app_user
# ... other vars
```

**IAP Audience:** `/projects/351592762922/global/backendServices/2781125957286789109`

---

## Database Schema

**Users with Admin Access:**
| ID | Username | Email | Groups | Roles |
|----|----------|-------|--------|-------|
| 1 | admin | admin@develom.com | admins, admin-users | admin |
| 2 | alice | alice@example.com | admins, admin-users | admin |
| 6 | andrew | andrew.stratton@usda.gov | admin-users | admin |
| 7 | robert | robert@develom.com | admin-users | admin |
| 8 | hector | hector@develom.com | admins, admin-users | admin |

**Admin Tables:**
- ✅ `corpus_audit_log` - Audit trail for all corpus operations
- ✅ `corpus_metadata` - Additional corpus metadata
- ✅ `corpus_sync_schedule` - Scheduled sync operations

---

## Testing

### ✅ Browser Test (IAP)
```bash
open "https://34.49.46.115.nip.io/api/admin/audit"
```
**Expected:** JSON array with audit logs

### ✅ Direct Backend Test (Bearer Token)
```bash
./backend/test_admin_via_curl.sh
```
**Expected:** Valid JSON response with audit data

---

## Deployment History

| Revision | Changes | Status |
|----------|---------|--------|
| backend-00070-qt8 | Original (Pydantic error) | ❌ |
| backend-00071-lnm | Fixed Pydantic validation | ✅ |
| backend-00072-b4h | Added hybrid auth middleware | ⚠️ (missing IAP config) |
| backend-00073-n9b | Added IAP env vars | ⚠️ (cert fetching issue) |
| backend-00074-8z9 | Attempted network fix | ❌ |
| backend-00075-k8m | Attempted cert fix | ⚠️ (404 - import error) |
| backend-00076-kwr | Wrong cert URL approach | ❌ |
| backend-00077-q99 | Manual JWT (missing PyJWT) | ❌ (404 - import error) |
| **backend-00078-5t6** | **PyJWT + Fixed deps** | ✅ **WORKING** |

---

## Files Created/Modified This Session

### Database Migration (8 files)
1. `backend/compare_database_schemas.py`
2. `backend/migrations/fix_cloud_schema.sql`
3. `backend/sync_database_schemas.sh`
4. `backend/test_cloud_schema.sh`
5. `backend/check_admin_permissions.sql`
6. `backend/grant_admin_access.sql`
7. `backend/grant_admin_to_hector.sql`

### Authentication (2 files)
8. `backend/src/middleware/hybrid_auth_middleware.py` ⭐
9. `backend/src/services/iap_service.py` (modified) ⭐

### Model Fix (1 file)
10. `backend/src/models/admin.py` (modified)

### Dependencies (1 file)
11. `backend/requirements.txt` (modified - added PyJWT, fixed google-auth)

### Testing Scripts (4 files)
12. `backend/test_admin_audit_endpoint.py`
13. `backend/test_admin_via_curl.sh`
14. `backend/test_admin_audit_browser.sh`
15. `backend/test_admin_endpoints.sh`

### Documentation (7 files)
16. `cascade-logs/2026-01-22/DATABASE_MIGRATION_GUIDE.md`
17. `cascade-logs/2026-01-22/SCHEMA_MIGRATION_TEST_RESULTS.md`
18. `cascade-logs/2026-01-22/ADMIN_ENDPOINT_TESTING_GUIDE.md`
19. `cascade-logs/2026-01-22/ADMIN_ENDPOINT_FIX_SUMMARY.md`
20. `cascade-logs/2026-01-22/IAP_AUTH_FIX_COMPLETE.md`
21. `cascade-logs/2026-01-22/FINAL_IAP_SOLUTION.md`
22. `cascade-logs/2026-01-22/COMPLETE_IAP_SOLUTION.md` (this file)

**Total:** 22 files created/modified

---

## Key Learnings

### 1. IAP JWT Verification Challenges
Google's `id_token.verify_oauth2_token()` can fail to fetch public keys in Cloud Run environments. Manual verification with PyJWT is more reliable:
- Fetch keys from `https://www.gstatic.com/iap/verify/public_key`
- Use JWT header's `kid` to select correct public key
- Verify with ES256 algorithm

### 2. Hybrid Authentication Pattern
Supporting both IAP and Bearer tokens enables:
- Browser access via Google OAuth (IAP)
- API/CLI access via local authentication
- Smooth transition between auth methods

### 3. Dependency Management
Python dependency conflicts require careful version management:
- google-auth >=2.26.1 (for google-cloud-storage compatibility)
- PyJWT for manual JWT operations
- Watch for transitive dependency conflicts

### 4. Admin Permission Model
Two-level admin check:
1. User must be authenticated (IAP or Bearer)
2. User must be in `admin-users` group
3. Group has `admin` role via `group_roles` table

---

## Troubleshooting Guide

### Issue: "Not authenticated"
**Check:**
1. Accessing via browser (not curl)?
2. Google account logged in?
3. IAP JWT present in request headers?

**Fix:**
```bash
# Check IAP status
curl https://34.49.46.115.nip.io/api/iap/status

# Check backend logs
gcloud logging read 'resource.labels.service_name="backend"' --limit=20
```

### Issue: 403 Forbidden
**Check:**
1. User created in database?
2. User in admin-users group?

**Fix:**
```sql
-- Check user groups
SELECT u.username, g.name FROM users u
JOIN user_groups ug ON u.id = ug.user_id
JOIN groups g ON ug.group_id = g.id
WHERE u.email = 'your-email@example.com';

-- Grant admin access
INSERT INTO user_groups (user_id, group_id)
SELECT u.id, g.id FROM users u, groups g
WHERE u.email = 'your-email@example.com' AND g.name = 'admin-users';
```

### Issue: 404 Not Found
**Check:**
1. Admin routes imported in server.py?
2. Import errors in logs?

**Fix:**
```bash
# Check for import errors
gcloud logging read 'resource.labels.service_name="backend" AND severity=ERROR' --limit=10
```

---

## Success Metrics

✅ **IAP Authentication:** Working  
✅ **Bearer Token Auth:** Working  
✅ **Admin Permission Check:** Working  
✅ **Database Schema:** Complete  
✅ **User Auto-Creation:** Working  
✅ **Audit Log Retrieval:** Working  
✅ **Error Handling:** Proper HTTP codes  
✅ **Cloud Deployment:** Stable revision  

---

## Next Steps (Future Enhancements)

1. **Caching:** Cache IAP public keys to reduce latency
2. **Rate Limiting:** Add rate limits to admin endpoints
3. **Audit Detail:** Enhance audit log with request metadata
4. **Admin UI:** Build React admin panel consuming these APIs
5. **Monitoring:** Set up Cloud Monitoring alerts for auth failures
6. **Testing:** Add integration tests for IAP flow

---

## Summary

**Duration:** ~5 hours  
**Issues Resolved:** 8 major problems  
**Deployments:** 9 Cloud Run revisions  
**Files Created:** 22 scripts, tools, and docs  

**Root Causes:**
1. Missing database tables
2. Model validation errors
3. Missing authentication support
4. Configuration gaps
5. Library limitations
6. Import/dependency issues
7. Permission gaps

**Final Status:** ✅ **PRODUCTION READY**

**Current Revision:** `backend-00078-5t6`  
**IAP URL:** `https://34.49.46.115.nip.io/api/admin/audit`  
**Backend URL:** `https://backend-351592762922.us-west1.run.app`

---

**The admin panel is now fully functional with IAP authentication!** 🚀
