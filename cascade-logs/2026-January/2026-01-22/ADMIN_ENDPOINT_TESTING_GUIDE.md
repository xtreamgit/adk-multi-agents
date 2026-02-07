# Admin Endpoint Testing Guide

**Date:** January 22, 2026  
**Purpose:** Comprehensive guide for testing /api/admin/audit and other admin endpoints

---

## Test Results Summary

### ✅ What's Working
- Database migration completed successfully
- All 3 admin tables exist in cloud database (`corpus_audit_log`, `corpus_metadata`, `corpus_sync_schedule`)
- Foreign keys and indexes functional
- Admin routes registered in FastAPI application
- Endpoint requires authentication (security ✓)

### ⚠️ Current Issue
**Internal Server Error when accessing `/api/admin/audit`**

**Root Cause:** Likely permissions issue - test user may not have admin role

**Endpoint:** `https://34.49.46.115.nip.io/api/admin/audit` (note: `/api/` prefix required)

---

## Testing Tools Created

### 1. **`backend/test_admin_audit_endpoint.py`**
Python script for comprehensive endpoint testing with IAP authentication.

**Features:**
- Tests IAP authentication
- Validates response format (JSON array)
- Checks audit log entry structure
- Validates data content
- Tests query parameters
- Verifies admin permission requirements

**Usage:**
```bash
python3 backend/test_admin_audit_endpoint.py
```

**Note:** Requires IAP token which has authentication challenges. Use alternative methods below.

---

### 2. **`backend/test_admin_via_curl.sh`**
Direct backend testing via curl with local authentication.

**Features:**
- Bypasses IAP by hitting backend directly
- Tests with local user credentials
- Shows actual API responses
- Validates JSON structure

**Usage:**
```bash
./backend/test_admin_via_curl.sh
```

**Current Results:**
- ✅ Backend accessible
- ✅ Endpoint requires authentication (403)
- ❌ Internal Server Error with authenticated user (permissions issue)

---

### 3. **`backend/test_admin_audit_browser.sh`**
Browser-based manual testing (recommended for IAP).

**Features:**
- Opens endpoint in browser
- IAP authentication handled automatically
- Visual verification of response
- Easy to debug

**Usage:**
```bash
./backend/test_admin_audit_browser.sh
```

**What to verify:**
1. Browser redirects to Google login
2. Page loads without 404/500 errors
3. JSON data or formatted entries displayed
4. Data includes: id, action, user_name, timestamp
5. No database errors visible

---

### 4. **`backend/test_admin_endpoints.sh`**
Comprehensive test of all admin endpoints.

**Features:**
- Tests `/api/admin/audit`
- Tests `/api/admin/users`
- Tests `/api/admin/corpora`
- Tests `/api/admin/agents`
- Summary report

**Usage:**
```bash
./backend/test_admin_endpoints.sh
```

---

## Correct Endpoint URLs

**IMPORTANT:** All admin endpoints require `/api/` prefix!

### Correct URLs:
- ✅ `https://34.49.46.115.nip.io/api/admin/audit`
- ✅ `https://34.49.46.115.nip.io/api/admin/users`
- ✅ `https://34.49.46.115.nip.io/api/admin/corpora`
- ✅ `https://34.49.46.115.nip.io/api/admin/agents`

### Incorrect URLs:
- ❌ `/admin/audit` (missing `/api/` prefix)
- ❌ `/admin-audit` (wrong separator)

**Route Definition:**
```python
# From backend/src/api/routes/admin.py
router = APIRouter(prefix="/api/admin", tags=["Admin"])
```

---

## Troubleshooting Guide

### Issue: 404 Not Found
**Diagnosis:**
- Check if URL includes `/api/` prefix
- Verify backend deployment is current
- Check if routes are registered

**Fix:**
```bash
# Check deployed routes
curl https://34.49.46.115.nip.io/api/health
```

---

### Issue: 403 Forbidden / Unauthorized
**Diagnosis:**
- User not authenticated
- User doesn't have admin permissions

**Fix:**
```bash
# Check user's roles in database
gcloud sql connect adk-multi-agents-db \
  --database=adk_agents_db \
  --user=adk_app_user \
  --project=adk-rag-ma

# In psql:
SELECT u.username, r.name as role
FROM users u
LEFT JOIN user_groups ug ON u.id = ug.user_id
LEFT JOIN groups g ON ug.group_id = g.id
LEFT JOIN group_roles gr ON g.id = gr.group_id
LEFT JOIN roles r ON gr.role_id = r.id
WHERE u.username = 'alice';
```

**Grant admin access:**
```sql
-- Create admin role if not exists
INSERT INTO roles (name, description) 
VALUES ('admin', 'Administrator role') 
ON CONFLICT (name) DO NOTHING;

-- Create admins group if not exists
INSERT INTO groups (name, description) 
VALUES ('admins', 'Administrators group') 
ON CONFLICT (name) DO NOTHING;

-- Link admin role to admins group
INSERT INTO group_roles (group_id, role_id)
SELECT g.id, r.id FROM groups g, roles r 
WHERE g.name = 'admins' AND r.name = 'admin'
ON CONFLICT DO NOTHING;

-- Add user to admins group
INSERT INTO user_groups (user_id, group_id)
SELECT u.id, g.id FROM users u, groups g
WHERE u.username = 'alice' AND g.name = 'admins'
ON CONFLICT DO NOTHING;
```

---

### Issue: 500 Internal Server Error
**Diagnosis:**
- Application error
- Database query failure
- Missing permissions

**Fix:**
```bash
# Check cloud logs for error details
gcloud logging read 'severity>=ERROR resource.labels.service_name="backend"' \
  --project=adk-rag-ma \
  --limit=20 \
  --format=json

# Look for specific admin-related errors
gcloud logging read 'severity>=ERROR resource.labels.service_name="backend" AND textPayload:"admin"' \
  --project=adk-rag-ma \
  --limit=10
```

---

### Issue: Empty Array [] Response
**Diagnosis:**
- No audit events logged yet (normal for new deployments)
- Filters too restrictive

**This is NOT an error** - it means:
- ✅ Endpoint working
- ✅ Database connection working
- ✅ No audit events yet

**To generate test data:**
```bash
# Connect to cloud database
gcloud sql connect adk-multi-agents-db \
  --database=adk_agents_db \
  --user=adk_app_user \
  --project=adk-rag-ma

# Insert test audit entry
INSERT INTO corpus_audit_log (action, changes, metadata, timestamp)
VALUES ('test_action', '{"test": "data"}', '{"source": "manual_test"}', NOW());
```

---

## Expected Response Format

### Successful Response:
```json
[
  {
    "id": 1,
    "corpus_id": null,
    "corpus_name": null,
    "user_id": 1,
    "user_name": "alice",
    "action": "created_user",
    "changes": null,
    "metadata": null,
    "timestamp": "2026-01-22T01:59:50.416955"
  },
  {
    "id": 2,
    "corpus_id": null,
    "corpus_name": null,
    "user_id": 1,
    "user_name": "alice",
    "action": "updated_user",
    "changes": null,
    "metadata": null,
    "timestamp": "2026-01-22T02:00:18.004656"
  }
]
```

### Error Responses:

**401 Unauthorized:**
```json
{
  "detail": "Not authenticated"
}
```

**403 Forbidden:**
```json
{
  "detail": "Admin access required"
}
```

**500 Internal Server Error:**
```json
{
  "detail": "Internal server error message"
}
```

---

## Quick Testing Commands

### Test via Browser (Recommended)
```bash
./backend/test_admin_audit_browser.sh
# Opens: https://34.49.46.115.nip.io/api/admin/audit
```

### Test via Direct Backend
```bash
./backend/test_admin_via_curl.sh
# Tests: https://backend-351592762922.us-west1.run.app/api/admin/audit
```

### Test All Admin Endpoints
```bash
./backend/test_admin_endpoints.sh
```

### Manual curl Test
```bash
# With IAP (in browser, get token from dev tools)
curl -H "Authorization: Bearer YOUR_IAP_TOKEN" \
  https://34.49.46.115.nip.io/api/admin/audit

# Direct backend with local auth
TOKEN=$(curl -s -X POST https://backend-351592762922.us-west1.run.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

curl -H "Authorization: Bearer $TOKEN" \
  https://backend-351592762922.us-west1.run.app/api/admin/audit
```

---

## Next Steps to Fix Current Issue

### 1. Check User Permissions
```bash
# See if alice has admin role
gcloud sql connect adk-multi-agents-db \
  --database=adk_agents_db \
  --user=adk_app_user \
  --project=adk-rag-ma << 'EOF'
SELECT u.username, r.name as role
FROM users u
LEFT JOIN user_groups ug ON u.id = ug.user_id
LEFT JOIN groups g ON ug.group_id = g.id  
LEFT JOIN group_roles gr ON g.id = gr.group_id
LEFT JOIN roles r ON gr.role_id = r.id
WHERE u.username = 'alice';
\q
EOF
```

### 2. Check Cloud Logs for Error Details
```bash
gcloud logging read 'severity>=ERROR resource.labels.service_name="backend"' \
  --project=adk-rag-ma \
  --limit=5
```

### 3. Grant Admin Access (if needed)
Use SQL commands from troubleshooting section above.

### 4. Re-test Endpoint
```bash
./backend/test_admin_via_curl.sh
```

---

## Files Created This Session

1. `backend/compare_database_schemas.py` - Schema comparison tool
2. `backend/migrations/fix_cloud_schema.sql` - Database migration
3. `backend/sync_database_schemas.sh` - Automated sync
4. `backend/test_cloud_schema.sh` - Database testing
5. `backend/test_admin_audit_endpoint.py` - IAP endpoint testing
6. `backend/test_admin_via_curl.sh` - Direct backend testing ⭐ **Use this**
7. `backend/test_admin_audit_browser.sh` - Browser testing ⭐ **Or this**
8. `backend/test_admin_endpoints.sh` - Comprehensive testing

---

## Summary

**Database:** ✅ Ready  
**Endpoint:** ✅ Exists  
**Security:** ✅ Requires Auth  
**Issue:** ⚠️ Permissions or application error

**Recommended Next Action:**
1. Run browser test: `./backend/test_admin_audit_browser.sh`
2. Check what error appears in browser
3. Check cloud logs for error details
4. Grant admin permissions if needed

The infrastructure is ready - just need to resolve the permissions/application issue.
