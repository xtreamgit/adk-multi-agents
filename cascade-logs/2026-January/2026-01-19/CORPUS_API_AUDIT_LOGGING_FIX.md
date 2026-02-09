# Corpus API Audit Logging Fix

**Date:** January 19, 2026  
**Status:** ✅ Fixed

---

## Problem

User-created corpus "hacker-books" did not appear in audit logs. Investigation revealed that the **user-facing corpus API endpoints** in `/api/corpora/` were **not creating audit log entries** at all.

### Affected Endpoints

All user corpus operations in `@/Users/hector/github.com/xtreamgit/adk-multi-agents/backend/src/api/routes/corpora.py`:

1. ❌ `POST /api/corpora/` - Create corpus (NO audit log)
2. ❌ `PUT /api/corpora/{corpus_id}` - Update corpus (NO audit log)
3. ❌ `POST /api/corpora/{corpus_id}/grant` - Grant access (NO audit log)
4. ❌ `DELETE /api/corpora/{corpus_id}/revoke/{group_id}` - Revoke access (NO audit log)

### Contrast with Admin API

The admin endpoints in `/api/admin/` **DO** create audit logs for similar operations, which is why admin operations appear in audit logs but user operations don't.

---

## Root Causes

### Issue 1: execute_insert Bug (PRIMARY)
The `execute_insert()` bug in `connection.py` prevented ALL audit log creation across the entire system. This was fixed earlier.

### Issue 2: Missing Audit Logging in User API (SECONDARY)
Even with `execute_insert()` fixed, the user corpus API endpoints never called `AuditRepository.create()`. These endpoints need explicit audit logging added.

---

## Solution

Added `AuditRepository.create()` calls to all corpus operation endpoints:

### 1. Corpus Creation (Lines 112-123)
```python
# Create audit log entry
AuditRepository.create({
    'corpus_id': corpus.id,
    'user_id': current_user.id,
    'action': 'created',
    'changes': {
        'name': corpus.name,
        'display_name': corpus.display_name,
        'gcs_bucket': corpus.gcs_bucket
    },
    'metadata': {'source': 'user_api', 'username': current_user.username}
})
```

### 2. Corpus Update (Lines 154-161)
```python
# Create audit log entry
AuditRepository.create({
    'corpus_id': corpus_id,
    'user_id': current_user.id,
    'action': 'updated',
    'changes': corpus_update.dict(exclude_unset=True),
    'metadata': {'source': 'user_api', 'username': current_user.username}
})
```

### 3. Grant Access (Lines 222-233)
```python
# Create audit log entry
AuditRepository.create({
    'corpus_id': corpus_id,
    'user_id': current_user.id,
    'action': 'granted_access',
    'changes': {
        'group_id': access_request.group_id,
        'group_name': group.name,
        'permission': access_request.permission
    },
    'metadata': {'source': 'user_api', 'username': current_user.username}
})
```

### 4. Revoke Access (Lines 259-266)
```python
# Create audit log entry
AuditRepository.create({
    'corpus_id': corpus_id,
    'user_id': current_user.id,
    'action': 'revoked_access',
    'changes': {'group_id': group_id},
    'metadata': {'source': 'user_api', 'username': current_user.username}
})
```

---

## Files Modified

1. **`backend/src/api/routes/corpora.py`**
   - Line 17: Added `AuditRepository` import
   - Lines 112-123: Added audit logging to `create_corpus()`
   - Lines 154-161: Added audit logging to `update_corpus()`
   - Lines 222-233: Added audit logging to `grant_corpus_access()`
   - Lines 259-266: Added audit logging to `revoke_corpus_access()`

---

## Impact

### ❌ Previous Operations (NOT Logged)
The "hacker-books" corpus creation and all other user operations performed before this fix were **not logged** and cannot be recovered. This includes:
- All corpus creations by users
- All corpus updates by users
- All permission grants/revokes by users

### ✅ New Operations (WILL Be Logged)
Starting now, all user corpus operations will create proper audit log entries with:
- Full details of what changed
- Who performed the action
- When it happened
- Source identification (`'source': 'user_api'`)

---

## Verification

To verify the fix works, create a new corpus through the UI:

1. Create a new corpus (e.g., "test-corpus")
2. Check `/admin/audit` - should show "created" action
3. Check `/admin/corpora/{corpus_id}/audit` - should show the creation log

Expected audit log fields:
- **Action:** `created`
- **Corpus:** Corpus name from database
- **User:** Username who created it
- **Changes:** Name, display_name, gcs_bucket
- **Metadata:** `{"source": "user_api", "username": "..."}`

---

## Related Fixes

This is the **third** audit logging fix in this session:

1. ✅ Fixed `execute_insert()` bug (all audit creation failed)
2. ✅ Fixed admin endpoint audit logging (partial)
3. ✅ **Fixed user API endpoint audit logging** (this fix)

All three were necessary for complete audit logging coverage.
