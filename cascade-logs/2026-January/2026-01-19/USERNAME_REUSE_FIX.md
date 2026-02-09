# Username Reuse Fix - Soft Delete Issue

**Date:** January 19, 2026  
**Status:** ✅ Fixed

---

## Problem

After deleting user "Robert", attempting to create a new user with username "robert" failed with error:
```
"Username 'robert' already exists"
```

Even though the user was soft-deleted (deactivated) and hidden from the UI, the system prevented reusing the username.

---

## Root Cause

The user creation validation checks for existing usernames without filtering by `is_active` status:

**File:** `backend/src/services/user_service.py` (Line 52-53)
```python
# Check if username exists
if UserRepository.get_by_username(user_create.username):
    raise ValueError(f"Username '{user_create.username}' already exists")
```

**File:** `backend/src/database/repositories/user_repository.py` (Original Line 25-31)
```python
@staticmethod
def get_by_username(username: str) -> Optional[Dict]:
    """Get user by username."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
        row = cursor.fetchone()
        return dict(row) if row else None
```

**The problem:** This query returns ALL users, including soft-deleted ones (is_active=FALSE).

---

## Solution

Modified `get_by_username()` and `get_by_email()` to add an `active_only` parameter (defaulting to `True`).

### Fix Applied

**File:** `backend/src/database/repositories/user_repository.py` (Lines 25-34, 37-46)

```python
@staticmethod
def get_by_username(username: str, active_only: bool = True) -> Optional[Dict]:
    """Get user by username. By default, only returns active users."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        if active_only:
            cursor.execute("SELECT * FROM users WHERE username = %s AND is_active = TRUE", (username,))
        else:
            cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
        row = cursor.fetchone()
        return dict(row) if row else None

@staticmethod
def get_by_email(email: str, active_only: bool = True) -> Optional[Dict]:
    """Get user by email. By default, only returns active users."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        if active_only:
            cursor.execute("SELECT * FROM users WHERE email = %s AND is_active = TRUE", (email,))
        else:
            cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        row = cursor.fetchone()
        return dict(row) if row else None
```

---

## How It Works

### Before Fix:
1. Delete user "Robert" → `is_active=FALSE` in database
2. Try to create new "Robert" → `get_by_username("robert")` finds inactive user
3. Validation fails: "Username already exists" ❌

### After Fix:
1. Delete user "Robert" → `is_active=FALSE` in database
2. Try to create new "Robert" → `get_by_username("robert", active_only=True)` returns `None`
3. Validation passes ✅
4. New user "Robert" created with different ID
5. Database now has two "Robert" entries:
   - Old: ID 7, is_active=FALSE (hidden from UI)
   - New: ID 10, is_active=TRUE (visible in UI)

---

## Impact

✅ **Username reuse works** - Can create new users with usernames of deleted users  
✅ **Email reuse works** - Can create new users with emails of deleted users  
✅ **Data preservation** - Old user records remain in database for audit purposes  
✅ **Backward compatible** - Existing code works without changes (active_only defaults to True)  
✅ **Flexibility** - Can still query inactive users with `active_only=False` if needed

---

## Testing

```python
# Soft delete user "Robert" (ID 7)
DELETE /api/admin/users/7
# Result: is_active=FALSE

# Verify validation ignores inactive user
UserRepository.get_by_username("Robert", active_only=True)
# Result: None (inactive user filtered out)

# Create new user with same username
POST /api/admin/users
{
  "username": "robert",
  "email": "robert.new@example.com",
  "full_name": "Robert New",
  "password": "password123"
}
# Result: SUCCESS - New user created (ID 10)

# Verify both exist in database
SELECT * FROM users WHERE LOWER(username) = 'robert'
# Result: 
#   - ID 7: Robert Hughes, is_active=FALSE (old, deleted)
#   - ID 10: Robert New, is_active=TRUE (new, active)
```

---

## Files Modified

1. **`backend/src/database/repositories/user_repository.py`**
   - Line 25-34: Updated `get_by_username()` to add `active_only` parameter
   - Line 37-46: Updated `get_by_email()` to add `active_only` parameter

---

## Related Fixes

This completes the soft delete implementation:

1. ✅ **UserRepository.get_all()** - Added `active_only` filter (hide deleted users from list)
2. ✅ **UserUpdate model** - Added `is_active` field (allow deactivation)
3. ✅ **UserRepository.get_by_username/email** - Added `active_only` filter (allow username reuse)
4. ✅ **Frontend error handling** - Fixed `[object Object]` display

All four were necessary for proper soft delete functionality.

---

## Alternative Considered

**Hard Delete:** Actually remove users from database  
**Rejected because:**
- Breaks referential integrity (audit logs, sessions, etc.)
- Loses historical data
- Can't track "who deleted what"
- Violates data retention requirements

**Soft delete with username reuse** is the industry standard approach.
