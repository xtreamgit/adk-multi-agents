# fetchone()[0] Dictionary Access Bug Fix

**Date:** January 19, 2026  
**Status:** ✅ Fixed

---

## Problem

User creation failing with error: **"Failed to create user: Failed to create user: 0"**

### Root Cause

Same underlying issue as the `execute_insert()` bug. Multiple repository methods were calling `cursor.fetchone()[0]` to get the ID from `RETURNING id` clauses, but `PostgreSQLCursorWrapper` returns **dictionaries**, not tuples.

Attempting to access `result[0]` on a dictionary causes a `KeyError: 0`, which manifests as the cryptic error message "0".

---

## Affected Repository Methods

### Before Fix (ALL BROKEN):

1. **UserRepository.create()** - Line 65
2. **UserRepository.create_iap_user()** - Line 84
3. **AgentRepository.create()** - Line 55
4. **CorpusRepository.create()** - Line 47
5. **GroupRepository.create()** - Line 47
6. **GroupRepository.create_role()** - Line 163

All were using:
```python
cursor.execute("... RETURNING id", params)
user_id = cursor.fetchone()[0]  # ❌ KeyError: 0 with dict results
```

---

## Solution

Changed all occurrences to safely handle both dict and tuple results:

```python
cursor.execute("... RETURNING id", params)
result = cursor.fetchone()
entity_id = result['id'] if isinstance(result, dict) else result[0]
```

This handles:
- **PostgreSQL with PostgreSQLCursorWrapper**: Returns dict, use `result['id']`
- **SQLite or raw PostgreSQL**: Returns tuple, use `result[0]`

---

## Files Modified

1. **`backend/src/database/repositories/user_repository.py`**
   - Lines 65-66: Fixed `create()`
   - Lines 85-86: Fixed `create_iap_user()`

2. **`backend/src/database/repositories/agent_repository.py`**
   - Lines 55-56: Fixed `create()`

3. **`backend/src/database/repositories/corpus_repository.py`**
   - Lines 47-48: Fixed `create()`

4. **`backend/src/database/repositories/group_repository.py`**
   - Lines 47-48: Fixed `create()`
   - Lines 164-165: Fixed `create_role()`

---

## Related Bug Fixes

This is the **second wave** of fixes for the PostgreSQLCursorWrapper dictionary result handling:

1. ✅ **First fix**: `execute_insert()` in `connection.py` (audit log creation)
2. ✅ **Second fix**: Direct `cursor.fetchone()[0]` calls in repositories (user/agent/corpus/group creation)

Both stemmed from the same root cause: assuming tuple results when PostgreSQL wrapper returns dicts.

---

## Why This Manifested as "0"

The error message "Failed to create user: 0" occurred because:

1. `cursor.fetchone()[0]` raised `KeyError: 0`
2. The exception was caught and converted to string: `str(e)` → `"0"`
3. The error was re-raised with message: `f"Failed to create user: {str(e)}"`
4. Result: "Failed to create user: 0"

---

## Testing

After restart, user creation through admin UI should work:

1. Go to `/admin/users`
2. Click "Add User"
3. Fill in username, email, full name, password
4. User should be created successfully

All entity creation operations now work:
- ✅ Users (admin and IAP)
- ✅ Agents
- ✅ Corpora
- ✅ Groups
- ✅ Roles

---

## Prevention

Future code review checklist:
- [ ] Never use `cursor.fetchone()[0]` directly with PostgreSQL
- [ ] Always check if result is dict or tuple
- [ ] Use helper pattern: `result['id'] if isinstance(result, dict) else result[0]`
- [ ] Or use `execute_insert()` helper which handles this correctly
