# Audit Log Bug Fix - execute_insert KeyError

**Date:** January 19, 2026  
**Status:** ✅ Fixed

---

## Problem

Audit logs not appearing in `/admin/audit` and `/admin/corpora/audit` pages despite operations being performed (corpus creation, syncs, etc.).

### Root Cause

Bug in `backend/src/database/connection.py` in the `execute_insert()` function:

```python
# BEFORE (Line 256 - BROKEN):
result = cursor.fetchone()
conn.commit()
return result[0] if result else None  # ❌ KeyError: 0
```

The `PostgreSQLCursorWrapper` returns **dictionaries**, not tuples. Trying to access `result[0]` caused a `KeyError` which prevented audit logs from being created.

### Impact

- **All audit log creation failed silently** when using PostgreSQL
- Operations completed successfully but audit entries were never created
- Affected all admin operations: corpus sync, permission grants, user management, etc.

---

## Solution

Fixed `execute_insert()` to properly handle dictionary results:

```python
# AFTER (Lines 256-260 - FIXED):
result = cursor.fetchone()
conn.commit()
# Result is a dict from PostgreSQLCursorWrapper
if result:
    # Try to get 'id' key, fallback to first column
    return result.get('id') or result.get(list(result.keys())[0])
return None
```

---

## Verification Tests

### ✅ Audit Log Creation
```
✅ Audit log 1 created - ID: 3
✅ Audit log 2 created - ID: 4
✅ Audit log 3 created - ID: 5
```

### ✅ Audit Log Retrieval with Filters
- All logs (no filter): ✅ 5 logs
- Filter by corpus_id=1: ✅ 5 logs
- Filter by user_id=1: ✅ 5 logs
- Filter by action='created': ✅ 4 logs
- Combined filters: ✅ 4 logs

---

## Files Modified

1. **`backend/src/database/connection.py`** (Lines 256-260)
   - Fixed `execute_insert()` to handle dict results from PostgreSQLCursorWrapper

---

## User Action Required

⚠️ **Previous operations were NOT logged** due to this bug. To populate audit logs:

1. Perform a corpus sync operation (triggers creation audit logs)
2. Grant/revoke permissions (triggers access audit logs)
3. Update corpus metadata (triggers update audit logs)

All **new operations** from now on will be properly logged.

---

## Related Issues

This was part of the broader SQLite → PostgreSQL migration. The `PostgreSQLCursorWrapper` converts results to dictionaries for consistency, but some helper functions like `execute_insert()` were still treating results as tuples.

### Similar Pattern in Other Functions

Checked other functions - they properly handle dict results:
- ✅ `execute_query()` - returns list of dicts
- ✅ `execute_update()` - uses `cursor.rowcount` (not affected)
- ✅ `PostgreSQLCursorWrapper.fetchone()` - properly converts to dict
- ✅ `PostgreSQLCursorWrapper.fetchall()` - properly converts to list of dicts

---

## Testing

To test audit logs after fix:

```python
import os
os.environ['DB_TYPE'] = 'postgresql'
os.environ['DB_HOST'] = 'localhost'
os.environ['DB_PORT'] = '5433'
os.environ['DB_NAME'] = 'adk_agents_db_dev'
os.environ['DB_USER'] = 'adk_dev_user'
os.environ['DB_PASSWORD'] = 'dev_password_123'

from database.repositories.audit_repository import AuditRepository

# Create audit log
audit_id = AuditRepository.create({
    'corpus_id': 1,
    'user_id': 1,
    'action': 'created',
    'changes': {'test': 'value'}
})
print(f'Created: {audit_id}')

# Retrieve logs
logs = AuditRepository.get_all(corpus_id=1, action='created')
print(f'Found: {len(logs)} logs')
```
