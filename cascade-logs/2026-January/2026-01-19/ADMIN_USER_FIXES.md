# Admin User Management Fixes

**Date:** January 19, 2026  
**Status:** ✅ Partial Fix Applied, Testing in Progress

---

## Issues Reported

### 1. User Creation Error
**Error:** "Failed to create user: [object Object]"  
**Backend Log:** `422 Unprocessable Entity`

### 2. Deleted Users Still Showing
**Issue:** When deleting a user, it still shows in `/admin/users` page

---

## Root Causes

### Issue #1: 422 Validation Error
- HTTP 422 = Pydantic validation error
- Backend receiving data that doesn't match `AdminUserCreate` model
- Need to check what frontend is sending vs what backend expects
- Added logging to capture actual request data

### Issue #2: Inactive Users Showing in List
**Root Cause:** `UserRepository.get_all()` was returning ALL users, including deactivated ones.

The delete endpoint correctly deactivates users:
```python
# Deactivate instead of deleting
updated_user = UserService.update_user(user_id, BaseUserUpdate(is_active=False))
```

But `get_all()` didn't filter by `is_active` status, so deactivated users appeared in the admin list.

---

## Fixes Applied

### Fix #1: Add active_only Filter to get_all()

**File:** `backend/src/database/repositories/user_repository.py` (Line 219-227)

**Before:**
```python
@staticmethod
def get_all() -> List[Dict]:
    """Get all users."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users ORDER BY created_at DESC")
        return [dict(row) for row in cursor.fetchall()]
```

**After:**
```python
@staticmethod
def get_all(active_only: bool = True) -> List[Dict]:
    """Get all users, optionally filtering by active status."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        if active_only:
            cursor.execute("SELECT * FROM users WHERE is_active = TRUE ORDER BY created_at DESC")
        else:
            cursor.execute("SELECT * FROM users ORDER BY created_at DESC")
        return [dict(row) for row in cursor.fetchall()]
```

**Impact:**
- ✅ Deleted (deactivated) users no longer appear in admin user list
- ✅ Can still retrieve all users (including inactive) if needed with `active_only=False`
- ✅ Frontend will automatically refresh and show only active users

### Fix #2: Add Logging to Create User Endpoint

**File:** `backend/src/api/routes/admin.py` (Line 473)

Added logging to capture validation errors:
```python
logger.info(f"Creating user with data: username={user_create.username}, email={user_create.email}, groups={user_create.group_ids}")
```

This will help identify what data is being sent and why validation is failing.

---

## Expected Model Structure

The `AdminUserCreate` model expects:
```python
class AdminUserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    full_name: str = Field(..., min_length=1, max_length=100)
    password: str = Field(..., min_length=8)
    group_ids: List[int] = []  # Initial group assignments
```

**Common Validation Failures:**
- Username too short (< 3 chars) or too long (> 50 chars)
- Invalid email format
- Full name empty or too long (> 100 chars)
- Password too short (< 8 chars)
- group_ids not a list of integers

---

## Testing Steps

1. **Test Delete User:**
   - Delete a user via admin UI
   - User should disappear from list immediately after page refresh
   - User still exists in DB with `is_active=FALSE`

2. **Test Create User:**
   - Try to create a new user
   - Check backend logs for validation error details
   - Fix frontend or backend based on findings

---

## Status

- ✅ **Delete Fix Applied:** Backend restarted (PID 56751)
- 🔄 **Create Fix In Progress:** Waiting for user to test and provide validation error details from logs

---

## Next Steps

1. User tests delete functionality - should work now
2. User tests create functionality - monitor logs for validation details
3. Fix create validation issue based on log findings
4. Restart backend if needed
