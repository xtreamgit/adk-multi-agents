# Username Unique Constraint Fix - Complete Solution

**Date:** January 19, 2026  
**Status:** ✅ Fixed

---

## Problem Evolution

### Initial Issue:
```
Failed to create user: duplicate key value violates unique constraint "users_username_key"
DETAIL: Key (username)=(Robert) already exists.
```

Even though we implemented `active_only` filter for `get_by_username()`, the **database unique constraint** on the `username` column still blocked creating new users with previously deleted usernames.

---

## Root Cause

PostgreSQL unique constraints apply to **ALL rows**, not just active ones:

```sql
-- Database schema
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,  -- ← This constraint blocks ALL rows
    email VARCHAR(255) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);
```

### The Problem:
1. Delete user "Robert" (ID 7) → Set `is_active=FALSE`
2. Username "Robert" **still exists** in database (inactive row)
3. Try to create new user "Robert" → **UNIQUE constraint violation** ❌

### Why Previous Fix Didn't Work:
We fixed `get_by_username()` to only check active users, which prevented **validation errors**. But the database constraint is enforced at the **SQL level**, not the application level.

---

## Complete Solution

### Part 1: Rename Username on Soft Delete

**File:** `backend/src/api/routes/admin.py` (Lines 852-858)

```python
# Deactivate and rename username to avoid unique constraint conflicts
# This allows reusing usernames for new users
deleted_username = f"{user.username}_deleted_{user_id}"
updated_user = UserService.update_user(
    user_id, 
    BaseUserUpdate(is_active=False, username=deleted_username)
)
```

**How it works:**
- User "Robert" (ID 7) is deleted
- Username changed: `"Robert"` → `"Robert_deleted_7"`
- Database constraint satisfied (no duplicate "Robert")
- New user can be created with username "Robert" ✅

### Part 2: Add Username to UserUpdate Model

**File:** `backend/src/models/user.py` (Line 24)

```python
class UserUpdate(BaseModel):
    """Model for updating user information."""
    username: Optional[str] = Field(None, min_length=3, max_length=50)  # ✅ Added
    email: Optional[EmailStr] = None
    full_name: Optional[str] = Field(None, min_length=1, max_length=100)
    is_active: Optional[bool] = None
    default_agent_id: Optional[int] = None
```

Without this, `UserUpdate(username=...)` would be silently ignored by Pydantic.

### Part 3: Rename Existing Inactive Users

**One-time migration:**
```sql
UPDATE users 
SET username = username || '_deleted_' || id::text 
WHERE is_active = FALSE AND username NOT LIKE '%_deleted_%';
```

This cleans up users that were soft-deleted before the rename fix was implemented.

---

## How It Works Now

### Before Complete Fix:
```
1. Delete "Robert" → is_active=FALSE
2. Username still "Robert" in database
3. Try to create new "Robert" → CONSTRAINT VIOLATION ❌
```

### After Complete Fix:
```
1. Delete "Robert" (ID 7)
   → is_active=FALSE
   → username="Robert_deleted_7"
2. Username "Robert" no longer exists in database ✅
3. Create new "Robert" (ID 12) → SUCCESS ✅
```

### Database State:
```
ID  | username           | email                  | is_active
----|-------------------|------------------------|----------
7   | Robert_deleted_7  | robert@develom.com     | FALSE
10  | robert_deleted_10 | robert.new@example.com | FALSE
12  | Robert            | robert.fresh@...       | TRUE ✅
```

---

## Benefits

✅ **Username reuse works** - Can create new users with deleted usernames  
✅ **No constraint violations** - Database stays happy  
✅ **Audit trail preserved** - Old users still in database with renamed usernames  
✅ **Clear deleted status** - `_deleted_` suffix shows user was removed  
✅ **Unique identifier** - User ID in suffix prevents naming conflicts  
✅ **Works with validation** - Combined with `active_only` filter

---

## Testing

```bash
# Step 1: Delete user Robert (ID 7)
DELETE /api/admin/users/7
# Database: username changed to "Robert_deleted_7"

# Step 2: Create new user Robert
POST /api/admin/users
{
  "username": "Robert",
  "email": "robert.fresh@example.com",
  "full_name": "Robert Fresh",
  "password": "password123"
}
# Result: SUCCESS - New user created (ID 12)

# Step 3: Verify database
SELECT id, username, is_active FROM users WHERE username LIKE '%obert%';
# Result:
#   7  | Robert_deleted_7  | FALSE
#   10 | robert_deleted_10 | FALSE
#   12 | Robert            | TRUE ✅
```

---

## Files Modified

1. **`backend/src/models/user.py`** (Line 24)
   - Added `username` field to `UserUpdate` model

2. **`backend/src/api/routes/admin.py`** (Lines 852-858)
   - Modified `delete_user` endpoint to rename username on soft delete

3. **Database migration** (one-time)
   - Renamed existing inactive users to free up usernames

---

## Related Fixes

This is the **third part** of the username reuse solution:

1. ✅ **UserRepository.get_by_username()** - Added `active_only` filter (prevents validation errors)
2. ✅ **UserRepository.get_by_email()** - Added `active_only` filter (prevents email conflicts)
3. ✅ **Rename on delete** - Changes username to avoid unique constraint (this fix)

All three are necessary:
- Without #1 & #2: Validation errors even with renaming
- Without #3: Database constraint violations even with validation working

---

## Alternative Approaches Considered

### Option 1: Partial Unique Index
```sql
CREATE UNIQUE INDEX users_username_active_key 
ON users (username) 
WHERE is_active = TRUE;
```
**Rejected:** Requires database migration, more complex, PostgreSQL-specific

### Option 2: Hard Delete
```sql
DELETE FROM users WHERE id = 7;
```
**Rejected:** Loses audit trail, breaks referential integrity, violates data retention

### Option 3: Rename on Delete (CHOSEN)
```python
username = f"{user.username}_deleted_{user_id}"
```
**Chosen:** Simple, works with all databases, preserves data, clear intent

---

## Email Constraint Note

The same issue applies to email addresses. If needed, we can extend this fix:

```python
deleted_username = f"{user.username}_deleted_{user_id}"
deleted_email = f"deleted_{user_id}_{user.email}"  # Optional

updated_user = UserService.update_user(
    user_id, 
    BaseUserUpdate(
        is_active=False, 
        username=deleted_username,
        email=deleted_email  # If email reuse is needed
    )
)
```

---

## Summary

**Problem:** Database unique constraint on username prevented reusing deleted usernames  
**Solution:** Rename username to `{username}_deleted_{id}` when soft-deleting users  
**Result:** Users can now be deleted and their usernames reused without errors  

This completes the comprehensive soft-delete implementation for the user management system.
