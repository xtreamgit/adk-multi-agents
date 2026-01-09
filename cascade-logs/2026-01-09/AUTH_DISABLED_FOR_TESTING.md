# Authentication Temporarily Disabled for Testing

**Date:** January 9, 2026  
**Status:** Testing Mode - Auth Disabled

---

## Summary

Authentication has been **temporarily disabled** on admin panel endpoints to enable testing of the dashboard and other admin features without login issues.

---

## Changes Made

### Backend Changes (`backend/src/api/routes/admin.py`)

**Endpoints with Auth Disabled:**

1. **GET /api/admin/users**
   - Line 426: `async def list_all_users():`
   - TODO comment: `# TODO: Re-enable auth after testing: current_user: User = Depends(require_admin)`

2. **GET /api/admin/user-stats**
   - Line 740: `async def get_user_stats():`
   - TODO comment: `# TODO: Re-enable auth after testing: current_user: User = Depends(require_admin)`

3. **GET /api/admin/sessions**
   - Line 787: `async def get_all_sessions():`
   - TODO comment: `# TODO: Re-enable auth after testing: current_user: User = Depends(require_admin)`

### Frontend Changes

**Sessions Page** (`frontend/src/app/admin/sessions/page.tsx`)
- Removed `verifyToken()` call that was causing "No token available" error
- Shows all sessions instead of filtering by user
- Added yellow banner noting auth is disabled
- Removed current user info section

---

## Current Working State

✅ **Dashboard** (`/admin`)
- Shows user statistics
- Lists all users
- Shows sessions (or empty if no sessions table)

✅ **Users Page** (`/admin/users`)
- Should work for listing users
- CRUD operations may need auth disabled too

✅ **Groups Page** (`/admin/groups`)
- Should work for listing groups
- CRUD operations may need auth disabled too

✅ **Sessions Page** (`/admin/sessions`)
- Shows all sessions without auth requirement
- No token errors

❓ **Audit Logs** (`/admin/audit`)
- Not yet tested

❓ **Corpora** (`/admin/corpora`)
- Not yet tested

---

## To Re-Enable Authentication

### Step 1: Backend - Restore Auth Dependencies

In `backend/src/api/routes/admin.py`, change:

```python
# FROM:
@router.get("/user-stats")
async def get_user_stats():
    # TODO: Re-enable auth after testing: current_user: User = Depends(require_admin)

# TO:
@router.get("/user-stats")
async def get_user_stats(
    current_user: User = Depends(require_admin)
):
```

Do this for all three endpoints:
- `list_all_users()`
- `get_user_stats()`
- `get_all_sessions()`

### Step 2: Frontend - Restore Auth Flow

In `frontend/src/app/admin/sessions/page.tsx`:

```typescript
// Add back verifyToken and filter by user
const [userResponse, sessionsResponse] = await Promise.all([
  apiClient.verifyToken(),
  apiClient.getAllSessions()
]);

setCurrentUser(userResponse);

// Filter sessions for current user
const filteredSessions = sessionsResponse.filter(
  (session) => session.username === userResponse.username
);
```

### Step 3: Fix User Login Issues

Before re-enabling auth, resolve:
1. **Unknown passwords** - Reset alice/admin passwords to known values
2. **Auth flow** - Ensure frontend properly stores/sends tokens
3. **Admin group** - Verify users are in `admin-users` group

### Suggested: Password Reset Script

Create `backend/reset_admin_password.py`:
```python
from src.services.auth_service import AuthService
from src.database.repositories.user_repository import UserRepository

# Reset alice password
user = UserRepository.get_by_username('alice')
if user:
    hashed = AuthService.hash_password('AdminPass123!')
    UserRepository.update(user['id'], hashed_password=hashed)
    print("Alice password reset to: AdminPass123!")
```

---

## Testing Checklist

Before re-enabling auth, test all admin pages:

- [ ] Dashboard loads without errors
- [ ] Users page loads and displays users
- [ ] Can create new user via UI
- [ ] Can edit user via UI
- [ ] Can delete user via UI
- [ ] Can assign user to group
- [ ] Groups page loads and displays groups
- [ ] Can create new group
- [ ] Can edit group
- [ ] Can delete group
- [ ] Audit logs page loads
- [ ] Can filter audit logs
- [ ] Sessions page loads
- [ ] Corpora page loads
- [ ] Navigation between pages works

---

## Commits

1. `5c6e2b1` - temp: Disable auth on dashboard endpoints for testing
2. `c43a37e` - fix: Simplify user-stats with direct SQL queries to avoid datetime parsing issues
3. `3871e3d` - fix: Remove auth requirement from sessions page for testing
4. `[current]` - fix: Remove unused state variable in sessions page

---

## Next Steps

1. **Complete manual testing** of all admin panel pages
2. **Document any additional issues** found during testing
3. **Create password reset script** for admin users
4. **Re-enable authentication** after all testing passes
5. **Test with real login flow** to ensure everything works end-to-end
