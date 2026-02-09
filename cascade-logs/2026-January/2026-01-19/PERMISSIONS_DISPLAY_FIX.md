# Permissions Display Fix - PostgreSQL JSONB Type Handling

**Date:** January 19, 2026  
**Status:** ✅ Fixed

---

## Problem

Roles table showed **"No permissions"** for all roles in the admin UI, even though permissions were stored correctly in the database.

**Screenshot:** Shows "No permissions" for:
- admin-role
- corpora-manager-role  
- user

---

## Root Cause

PostgreSQL JSONB columns are **automatically converted to Python types** by psycopg2. The repository code was treating them as JSON strings and trying to parse them again.

### What Was Happening:

1. **Database:** `permissions` column stores `["admin:all"]` as JSONB
2. **psycopg2:** Automatically converts JSONB → Python `list`
3. **Repository code:** Tried to `json.loads(["admin:all"])` ← **FAIL**
4. **Exception handler:** Silently caught error, returned `[]`
5. **Result:** Empty permissions array sent to frontend

### The Buggy Code:

```python
# In GroupRepository.get_all_roles()
permissions_str = role.get('permissions')
if permissions_str:
    try:
        role['permissions'] = json.loads(permissions_str)  # ❌ Trying to parse a list!
    except (json.JSONDecodeError, TypeError):
        role['permissions'] = []  # Silent failure
```

**Why it failed silently:**
- `json.loads()` expects a string
- Passing a list raises `TypeError`
- Exception was caught and returned empty array `[]`
- No error logged, just empty permissions

---

## Solution

Check if permissions is already a list before attempting JSON parsing.

### Fixed Code:

```python
# PostgreSQL JSONB is already a Python list
permissions = role.get('permissions')
if isinstance(permissions, list):
    role['permissions'] = permissions  # ✅ Already a list, use it
elif isinstance(permissions, str):
    # Fallback for string (shouldn't happen with JSONB)
    try:
        role['permissions'] = json.loads(permissions)
    except (json.JSONDecodeError, TypeError):
        role['permissions'] = []
else:
    role['permissions'] = []
```

---

## Files Modified

**File:** `backend/src/database/repositories/group_repository.py`

Fixed permissions parsing in **5 methods**:

1. **`get_role_by_id()`** - Line 117-127
2. **`get_role_by_name()`** - Line 140-145  
3. **`get_all_roles()`** - Line 179-191
4. **`get_group_roles()`** - Line 236-246
5. **`get_user_roles()`** - Line 264-274

---

## Testing Results

### Before Fix:
```json
{
  "name": "admin-role",
  "permissions": [],  // ❌ Empty despite DB having ["admin:all"]
  "id": 3
}
```

### After Fix:
```json
{
  "name": "admin-role",
  "permissions": ["admin:all"],  // ✅ Correct!
  "id": 3
},
{
  "name": "corpora-manager-role",
  "permissions": ["manage:corpora"],  // ✅ Correct!
  "id": 4
}
```

---

## PostgreSQL vs SQLite Difference

This bug was introduced during the SQLite → PostgreSQL migration.

| Database | JSON Handling | Our Code Expected |
|----------|--------------|-------------------|
| **SQLite** | Stores JSON as TEXT | String → `json.loads()` needed ✅ |
| **PostgreSQL** | Stores as JSONB, auto-converts to Python types | Already a list, no parsing needed |

### Why It Worked in SQLite:
```python
# SQLite
permissions = '["admin:all"]'  # String from TEXT column
json.loads(permissions)  # Works! → ["admin:all"]
```

### Why It Failed in PostgreSQL:
```python
# PostgreSQL  
permissions = ["admin:all"]  # Already a list from JSONB column
json.loads(permissions)  # TypeError! Can't parse a list
```

---

## Key Learnings

### PostgreSQL JSONB Advantages:
1. **Automatic type conversion** - No manual JSON parsing needed
2. **Type safety** - Invalid JSON rejected at insert time
3. **Better indexing** - Can index specific JSON fields
4. **Native queries** - Can query JSON contents with SQL

### Best Practice:
```python
# Always check type before parsing
if isinstance(data, list):
    use_as_is = data
elif isinstance(data, str):
    parsed = json.loads(data)
```

---

## Impact

✅ **Permissions now display correctly** in admin UI  
✅ **All role retrieval methods fixed**  
✅ **No breaking changes** - backward compatible with string fallback  
✅ **Frontend requires no changes** - receives correct data structure

---

## Related Issues Fixed

This is part of the broader **roles and permissions system** fixes:

1. ✅ **Missing permissions column** - Added JSONB column to roles table
2. ✅ **Role creation error** - Fixed database schema mismatch
3. ✅ **Permissions display** - Fixed JSONB type handling (this fix)

All three issues stemmed from the SQLite → PostgreSQL migration where JSONB behaves differently than TEXT columns.

---

## Summary

**Problem:** Permissions showed as "No permissions" despite correct database values  
**Cause:** Tried to JSON parse already-parsed JSONB data, failed silently  
**Solution:** Check if data is already a list before attempting JSON parsing  
**Result:** Permissions now display correctly in admin UI

This completes the roles and permissions display system.
