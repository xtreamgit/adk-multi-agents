# User Delete Bug Fix

**Date:** January 19, 2026  
**Status:** ✅ Fixed

---

## Problem

Delete user endpoint returned **200 OK** with message "User has been deactivated", but the user remained **ACTIVE** in the database and continued to appear in the admin user list.

---

## Root Cause

The `UserUpdate` model was **missing the `is_active` field**.

### Code Flow:
1. Admin clicks "Delete User" 
2. Frontend calls `DELETE /api/admin/users/{id}`
3. Backend endpoint tries: `UserService.update_user(user_id, UserUpdate(is_active=False))`
4. `UserUpdate` model only had: `email`, `full_name`, `default_agent_id`
5. Pydantic's `model_dump(exclude_unset=True)` returned `{}` (empty dict)
6. `UserRepository.update()` received no fields to update
7. User remained ACTIVE ❌

**The delete endpoint was calling the right code, but the model was silently dropping the field!**

---

## Fix Applied

**File:** `backend/src/models/user.py` (Line 26)

**Before:**
```python
class UserUpdate(BaseModel):
    """Model for updating user information."""
    email: Optional[EmailStr] = None
    full_name: Optional[str] = Field(None, min_length=1, max_length=100)
    default_agent_id: Optional[int] = None
```

**After:**
```python
class UserUpdate(BaseModel):
    """Model for updating user information."""
    email: Optional[EmailStr] = None
    full_name: Optional[str] = Field(None, min_length=1, max_length=100)
    is_active: Optional[bool] = None  # ADDED
    default_agent_id: Optional[int] = None
```

---

## How It Works Now

1. Admin clicks "Delete User"
2. Frontend: `DELETE /api/admin/users/{id}`
3. Backend: `UserUpdate(is_active=False)` ✅ Field now exists
4. `model_dump(exclude_unset=True)` returns `{'is_active': False}` ✅
5. `UserRepository.update(user_id, is_active=False)` ✅
6. SQL: `UPDATE users SET is_active = FALSE WHERE id = {user_id}` ✅
7. `UserRepository.get_all(active_only=True)` filters out inactive users ✅
8. User disappears from admin UI ✅

---

## Verification Steps

### Direct Repository Test:
```python
UserRepository.update(9, is_active=False)
# ✅ Works - user deactivated in DB
```

### API Test:
```bash
DELETE /api/admin/users/9
# Response: {"success": true, "message": "User testuser999 has been deactivated"}
# ✅ User actually deactivated (is_active=FALSE in DB)
```

### Admin UI:
```python
UserRepository.get_all(active_only=True)
# ✅ testuser999 not in list (hidden from admin UI)
```

---

## Files Modified

1. **`backend/src/models/user.py`** (Line 26)
   - Added `is_active: Optional[bool] = None` to `UserUpdate` model

2. **`backend/src/database/repositories/user_repository.py`** (Line 219-227)
   - Already had `active_only` filter (from previous fix)

---

## Impact

- ✅ **Delete user works correctly**
- ✅ **Deleted users are deactivated (is_active=FALSE)**
- ✅ **Deleted users hidden from admin list by default**
- ✅ **Can still retrieve all users (including inactive) if needed**
- ✅ **Audit logs record deletion action**

---

## Related Fixes

This completes the admin user management fixes:

1. ✅ **UserRepository.get_all()** - Added `active_only` filter to hide inactive users
2. ✅ **UserUpdate model** - Added `is_active` field to allow deactivation
3. ✅ **Frontend error handling** - Fixed `[object Object]` display for validation errors

All three were necessary for the complete fix:
- Without #1: Deactivated users would still show in list
- Without #2: Users couldn't be deactivated (this bug)
- Without #3: Users wouldn't see readable error messages

---

## Testing

After backend restart (PID 71425):
1. Delete a user via admin UI
2. User should disappear from list immediately
3. User remains in database with `is_active=FALSE`
4. Can verify: `SELECT * FROM users WHERE is_active = FALSE`
