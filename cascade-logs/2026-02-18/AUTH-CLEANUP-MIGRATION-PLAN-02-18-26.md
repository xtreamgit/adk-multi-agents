# Authentication System Cleanup - Detailed Migration Plan

**Date:** February 18, 2026  
**Objective:** Remove legacy authentication components and simplify to IAP + Google Groups Bridge only  
**Estimated Duration:** 2-3 days  
**Risk Level:** Medium (requires database changes and code removal)

---

## Table of Contents

1. [Overview](#overview)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Phase 1: Database Table Removal](#phase-1-database-table-removal)
4. [Phase 2: Users Table Simplification](#phase-2-users-table-simplification)
5. [Phase 3: Backend API Cleanup](#phase-3-backend-api-cleanup)
6. [Phase 4: Frontend Admin Page Simplification](#phase-4-frontend-admin-page-simplification)
7. [Phase 5: Testing and Validation](#phase-5-testing-and-validation)
8. [Rollback Plan](#rollback-plan)
9. [Post-Migration Verification](#post-migration-verification)

---

## Overview

### Current State
- **Authentication:** IAP (Google OAuth) with local password fallback
- **Authorization:** Google Groups Bridge + legacy RBAC tables
- **User Management:** Manual creation via admin UI + auto-creation on IAP login

### Target State
- **Authentication:** IAP only (no local passwords)
- **Authorization:** Google Groups Bridge only (no legacy RBAC)
- **User Management:** Auto-creation on IAP login only

### What Will Be Removed

**Database:**
- 4 tables: `groups`, `user_groups`, `roles`, `group_roles`
- 3 columns from `users`: `hashed_password`, `username`, `auth_provider`

**Backend:**
- Legacy auth endpoints (already archived)
- Legacy admin user/group management endpoints
- ~10 API routes

**Frontend:**
- User creation UI
- Group management UI
- User→group assignment UI

---

## Pre-Migration Checklist

### 1. Backup Database

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend

# Create timestamped backup
python backup_database.py

# Verify backup exists
ls -lh database_backups/
```

### 2. Verify Current State

```sql
-- Check if legacy tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('groups', 'user_groups', 'roles', 'group_roles')
ORDER BY table_name;

-- Check users table columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- Count records in legacy tables
SELECT 'groups' as table_name, COUNT(*) as count FROM groups
UNION ALL SELECT 'user_groups', COUNT(*) FROM user_groups
UNION ALL SELECT 'roles', COUNT(*) FROM roles
UNION ALL SELECT 'group_roles', COUNT(*) FROM group_roles;
```

### 3. Document Dependencies

```sql
-- Find foreign keys referencing legacy tables
SELECT 
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_name IN ('groups', 'user_groups', 'roles', 'group_roles')
ORDER BY tc.table_name;
```

### 4. Create Git Branch

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents
git checkout -b feature/auth-cleanup
git push -u origin feature/auth-cleanup
```

---

## Phase 1: Database Table Removal

**Duration:** 30 minutes  
**Risk:** Low (these tables are not used by current code)

### Step 1.1: Verify Tables Are Unused

```bash
# Search for references to legacy tables in backend code
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend
grep -r "group_roles" src/ --include="*.py" || echo "No references found"
grep -r "user_groups" src/ --include="*.py" || echo "No references found"
grep -r "\"roles\"" src/ --include="*.py" || echo "No references found"
grep -r "\"groups\"" src/ --include="*.py" || echo "No references found"
```

**Expected:** No references (or only in archived files)

### Step 1.2: Create Migration Script

**File:** `backend/src/database/migrations/013_remove_legacy_auth_tables.sql`

```sql
-- Migration 013: Remove Legacy Auth Tables
-- Date: 2026-02-18
-- Description: Remove groups, user_groups, roles, group_roles tables
--              These are replaced by Google Groups Bridge

BEGIN;

-- Drop tables in correct order (respect foreign keys)
DROP TABLE IF EXISTS group_roles CASCADE;
DROP TABLE IF EXISTS user_groups CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS groups CASCADE;

-- Add migration record
INSERT INTO schema_migrations (version, description, applied_at)
VALUES (13, 'Remove legacy auth tables (groups, user_groups, roles, group_roles)', CURRENT_TIMESTAMP);

COMMIT;
```

### Step 1.3: Execute Migration

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend

# Run migration
psql $DATABASE_URL -f src/database/migrations/013_remove_legacy_auth_tables.sql

# Verify tables are gone
psql $DATABASE_URL -c "\dt" | grep -E "(groups|user_groups|roles|group_roles)" || echo "Tables removed successfully"
```

### Step 1.4: Verify Application Still Works

```bash
# Restart backend
pkill -f "uvicorn"
bash start-backend.sh

# Test IAP login
curl -s http://localhost:8000/api/health | jq

# Test Google Groups Bridge
curl -s http://localhost:8000/api/admin/google-groups/status | jq
```

### Step 1.5: Commit Changes

```bash
git add backend/src/database/migrations/013_remove_legacy_auth_tables.sql
git commit -m "feat: remove legacy auth tables (groups, user_groups, roles, group_roles)

- Dropped 4 legacy RBAC tables replaced by Google Groups Bridge
- Migration 013 applied successfully
- Verified no code references to dropped tables"
```

---

## Phase 2: Users Table Simplification

**Duration:** 1 hour  
**Risk:** Medium (requires code changes to handle missing columns)

### Step 2.1: Identify Code References

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend

# Find references to columns being removed
grep -r "hashed_password" src/ --include="*.py" | grep -v "test_" | grep -v ".pyc"
grep -r "username" src/ --include="*.py" | grep -v "test_" | grep -v ".pyc" | head -20
grep -r "auth_provider" src/ --include="*.py" | grep -v "test_" | grep -v ".pyc"
```

### Step 2.2: Update Code Before Migration

**Files to update:**

1. **`src/models/user.py`** (if exists) — Remove fields from Pydantic models
2. **`src/api/routes/users.py`** — Remove username/password handling
3. **`src/middleware/iap_auth_middleware.py`** — Already uses email/google_id only
4. **`src/services/user_service.py`** — Update user creation logic

**Example changes:**

```python
# Before (src/services/user_service.py)
def create_user_from_iap(email: str, google_id: str, full_name: str):
    cursor.execute("""
        INSERT INTO users (username, email, google_id, full_name, auth_provider, is_active)
        VALUES (%s, %s, %s, %s, 'iap', TRUE)
        RETURNING id
    """, (email.split('@')[0], email, google_id, full_name))

# After
def create_user_from_iap(email: str, google_id: str, full_name: str):
    cursor.execute("""
        INSERT INTO users (email, google_id, full_name, is_active)
        VALUES (%s, %s, %s, TRUE)
        RETURNING id
    """, (email, google_id, full_name))
```

### Step 2.3: Create Migration Script

**File:** `backend/src/database/migrations/014_simplify_users_table.sql`

```sql
-- Migration 014: Simplify Users Table
-- Date: 2026-02-18
-- Description: Remove hashed_password, username, auth_provider columns
--              All users now authenticate via IAP only

BEGIN;

-- Remove local auth columns
ALTER TABLE users DROP COLUMN IF EXISTS hashed_password;
ALTER TABLE users DROP COLUMN IF EXISTS username;
ALTER TABLE users DROP COLUMN IF EXISTS auth_provider;

-- Verify email is unique (should already be)
-- This is a safety check
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'users_email_key'
    ) THEN
        ALTER TABLE users ADD CONSTRAINT users_email_key UNIQUE (email);
    END IF;
END $$;

-- Add migration record
INSERT INTO schema_migrations (version, description, applied_at)
VALUES (14, 'Simplify users table - remove local auth columns', CURRENT_TIMESTAMP);

COMMIT;
```

### Step 2.4: Execute Migration

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend

# Run migration
psql $DATABASE_URL -f src/database/migrations/014_simplify_users_table.sql

# Verify columns are gone
psql $DATABASE_URL -c "\d users"
```

### Step 2.5: Test User Creation

```bash
# Restart backend with updated code
pkill -f "uvicorn"
bash start-backend.sh

# Test IAP login (should auto-create user)
# Login via browser at http://localhost:3000
# Or test with dev mode:
curl -s http://localhost:8000/api/users/me \
  -H "X-Goog-Authenticated-User-Email: account:test@develom.com" | jq
```

### Step 2.6: Commit Changes

```bash
git add backend/src/database/migrations/014_simplify_users_table.sql
git add backend/src/services/user_service.py
git add backend/src/models/  # if Pydantic models updated
git commit -m "feat: simplify users table - remove local auth columns

- Removed hashed_password, username, auth_provider columns
- Updated user creation logic to use email as primary identifier
- All users now authenticate via IAP only
- Migration 014 applied successfully"
```

---

## Phase 3: Backend API Cleanup

**Duration:** 2 hours  
**Risk:** Low (removing unused endpoints)

### Step 3.1: Identify Endpoints to Remove

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend

# List all route files
find src/api/routes -name "*.py" -type f

# Check for legacy auth routes (should already be archived)
ls -la src/api/routes/auth.py 2>/dev/null || echo "Already removed"
ls -la src/middleware/auth_middleware.py 2>/dev/null || echo "Already removed"
```

### Step 3.2: Remove Legacy Admin Endpoints

**File:** `src/api/routes/admin.py` (or similar)

**Endpoints to remove:**

```python
# REMOVE: User creation (users auto-created on IAP login)
@router.post("/users", response_model=UserResponse)
async def create_user(...):
    # DELETE THIS ENDPOINT

# REMOVE: User→group assignment (Google Groups Bridge manages this)
@router.post("/users/{user_id}/groups/{group_id}")
async def assign_user_to_group(...):
    # DELETE THIS ENDPOINT

@router.delete("/users/{user_id}/groups/{group_id}")
async def remove_user_from_group(...):
    # DELETE THIS ENDPOINT

# REMOVE: Group management (use Google Workspace)
@router.get("/groups", response_model=List[GroupResponse])
async def list_groups(...):
    # DELETE THIS ENDPOINT

@router.post("/groups", response_model=GroupResponse)
async def create_group(...):
    # DELETE THIS ENDPOINT

@router.put("/groups/{group_id}", response_model=GroupResponse)
async def update_group(...):
    # DELETE THIS ENDPOINT

@router.delete("/groups/{group_id}")
async def delete_group(...):
    # DELETE THIS ENDPOINT
```

**Endpoints to keep:**

```python
# KEEP: View users (read-only)
@router.get("/users", response_model=List[UserResponse])
async def list_users(...):
    # KEEP - for admin visibility

# KEEP: Deactivate user
@router.delete("/users/{user_id}")
async def deactivate_user(...):
    # KEEP - still need to deactivate users

# KEEP: Update user preferences
@router.put("/users/{user_id}/preferences")
async def update_user_preferences(...):
    # KEEP - users can update theme, language, etc.
```

### Step 3.3: Update OpenAPI Documentation

**File:** `src/server.py`

Remove route imports and registrations:

```python
# REMOVE these imports
# from api.routes.auth import router as auth_router
# from api.routes.groups import router as groups_router  # if exists

# REMOVE these registrations
# app.include_router(auth_router, prefix="/api/auth", tags=["auth"])
# app.include_router(groups_router, prefix="/api/groups", tags=["groups"])
```

### Step 3.4: Test API Endpoints

```bash
# Restart backend
pkill -f "uvicorn"
bash start-backend.sh

# Verify removed endpoints return 404
curl -s -X POST http://localhost:8000/api/admin/users -d '{}' -H "Content-Type: application/json" | jq
# Expected: 404 Not Found

# Verify kept endpoints still work
curl -s http://localhost:8000/api/admin/users | jq
# Expected: List of users

# Verify Google Groups Bridge endpoints work
curl -s http://localhost:8000/api/admin/google-groups/status | jq
# Expected: Bridge status
```

### Step 3.5: Commit Changes

```bash
git add backend/src/api/routes/
git add backend/src/server.py
git commit -m "feat: remove legacy admin user/group management endpoints

- Removed user creation endpoint (auto-created on IAP login)
- Removed user→group assignment endpoints (Google Groups Bridge manages)
- Removed group management endpoints (use Google Workspace)
- Kept user listing, deactivation, and preference updates
- Updated OpenAPI documentation"
```

---

## Phase 4: Frontend Admin Page Simplification

**Duration:** 3 hours  
**Risk:** Medium (UI changes visible to users)

### Step 4.1: Identify Admin Pages to Update

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/frontend

# Find admin pages
find src/app/admin -name "*.tsx" -type f

# Expected pages:
# - src/app/admin/users/page.tsx
# - src/app/admin/groups/page.tsx (if exists)
# - src/app/admin/chatbot-users/page.tsx
# - src/app/admin/chatbot-groups/page.tsx
```

### Step 4.2: Update Users Admin Page

**File:** `src/app/admin/users/page.tsx`

**Changes:**

1. **Remove "Create User" button**
   ```tsx
   // REMOVE THIS
   <Button onClick={() => setShowCreateDialog(true)}>
     <Plus className="h-4 w-4 mr-2" />
     Create User
   </Button>
   ```

2. **Remove "Assign to Group" action**
   ```tsx
   // REMOVE THIS
   <DropdownMenuItem onClick={() => handleAssignToGroup(user.id)}>
     <Users className="h-4 w-4 mr-2" />
     Assign to Group
   </DropdownMenuItem>
   ```

3. **Add "Sync from Google Groups" button**
   ```tsx
   // ADD THIS
   <Button 
     onClick={() => handleSyncFromGoogleGroups(user.id)}
     variant="outline"
   >
     <RefreshCw className="h-4 w-4 mr-2" />
     Sync from Google Groups
   </Button>
   ```

4. **Add Google Groups display (read-only)**
   ```tsx
   // ADD THIS to user details
   <div className="mt-4">
     <h4 className="text-sm font-medium mb-2">Google Groups</h4>
     {user.google_groups?.length > 0 ? (
       <div className="flex flex-wrap gap-2">
         {user.google_groups.map(group => (
           <Badge key={group} variant="secondary">{group}</Badge>
         ))}
       </div>
     ) : (
       <p className="text-sm text-muted-foreground">No Google Groups</p>
     )}
   </div>
   ```

5. **Update API calls**
   ```tsx
   // REMOVE createUser API call
   // REMOVE assignUserToGroup API call
   
   // ADD syncUserFromGoogleGroups API call
   const handleSyncFromGoogleGroups = async (userId: number) => {
     try {
       await fetch(`/api/admin/google-groups/sync/${userId}`, {
         method: 'POST',
         credentials: 'include',
       });
       toast.success('User synced from Google Groups');
       loadData();
     } catch (error) {
       toast.error('Failed to sync user');
     }
   };
   ```

### Step 4.3: Remove Groups Admin Page

**If exists:** `src/app/admin/groups/page.tsx`

```bash
# Remove the entire page
rm -f src/app/admin/groups/page.tsx

# Remove from navigation
# Edit src/components/admin/AdminNav.tsx or similar
# Remove "Groups" link
```

### Step 4.4: Update Admin Navigation

**File:** `src/components/admin/AdminNav.tsx` (or similar)

```tsx
// REMOVE this nav item
{
  label: 'Groups',
  href: '/admin/groups',
  icon: Users,
}

// KEEP these nav items
{
  label: 'Users',
  href: '/admin/users',
  icon: Users,
},
{
  label: 'Chatbot Users',
  href: '/admin/chatbot-users',
  icon: Bot,
},
{
  label: 'Chatbot Groups',
  href: '/admin/chatbot-groups',
  icon: Users,
},
{
  label: 'Google Groups Bridge',
  href: '/admin/google-groups',
  icon: RefreshCw,
}
```

### Step 4.5: Add Google Groups Bridge Status Page

**File:** `src/app/admin/google-groups/page.tsx`

```tsx
'use client';

import { useEffect, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { RefreshCw, CheckCircle, XCircle } from 'lucide-react';

export default function GoogleGroupsBridgePage() {
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(true);

  const loadStatus = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/admin/google-groups/status', {
        credentials: 'include',
      });
      const data = await res.json();
      setStatus(data);
    } catch (error) {
      console.error('Failed to load bridge status:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSyncAll = async () => {
    try {
      await fetch('/api/admin/google-groups/sync-all', {
        method: 'POST',
        credentials: 'include',
      });
      alert('Sync started for all users');
      loadStatus();
    } catch (error) {
      alert('Failed to sync all users');
    }
  };

  useEffect(() => {
    loadStatus();
  }, []);

  if (loading) return <div>Loading...</div>;

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold">Google Groups Bridge</h1>
        <Button onClick={handleSyncAll}>
          <RefreshCw className="h-4 w-4 mr-2" />
          Sync All Users
        </Button>
      </div>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Status</CardTitle>
          </CardHeader>
          <CardContent>
            {status?.enabled ? (
              <div className="flex items-center text-green-600">
                <CheckCircle className="h-5 w-5 mr-2" />
                Enabled
              </div>
            ) : (
              <div className="flex items-center text-red-600">
                <XCircle className="h-5 w-5 mr-2" />
                Disabled
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Agent Mappings</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{status?.agent_mappings_count || 0}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Corpus Mappings</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{status?.corpus_mappings_count || 0}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Synced Users</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{status?.synced_users_count || 0}</div>
          </CardContent>
        </Card>
      </div>

      {/* Add more details: mappings table, sync history, etc. */}
    </div>
  );
}
```

### Step 4.6: Test Frontend Changes

```bash
# Restart frontend
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/frontend
npm run dev

# Test in browser:
# 1. Navigate to http://localhost:3000/admin/users
# 2. Verify "Create User" button is gone
# 3. Verify "Sync from Google Groups" button works
# 4. Navigate to http://localhost:3000/admin/google-groups
# 5. Verify bridge status page displays correctly
```

### Step 4.7: Commit Changes

```bash
git add frontend/src/app/admin/
git add frontend/src/components/admin/
git commit -m "feat: simplify admin UI - remove legacy user/group management

- Removed 'Create User' button (auto-created on IAP login)
- Removed 'Assign to Group' UI (Google Groups Bridge manages)
- Removed Groups admin page (use Google Workspace)
- Added 'Sync from Google Groups' button
- Added Google Groups Bridge status page
- Display user's Google Groups (read-only)"
```

---

## Phase 5: Testing and Validation

**Duration:** 2 hours  
**Risk:** Low (verification only)

### Step 5.1: Database Integrity Check

```sql
-- Verify no orphaned records
SELECT 'users' as table_name, COUNT(*) as count FROM users WHERE is_active = TRUE
UNION ALL SELECT 'chatbot_users', COUNT(*) FROM chatbot_users WHERE is_active = TRUE
UNION ALL SELECT 'chatbot_groups', COUNT(*) FROM chatbot_groups WHERE is_active = TRUE
UNION ALL SELECT 'chatbot_user_groups', COUNT(*) FROM chatbot_user_groups
UNION ALL SELECT 'chatbot_corpus_access', COUNT(*) FROM chatbot_corpus_access
UNION ALL SELECT 'user_google_group_sync', COUNT(*) FROM user_google_group_sync;

-- Verify foreign key integrity
SELECT 
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    confrelid::regclass AS referenced_table
FROM pg_constraint
WHERE contype = 'f'
  AND connamespace = 'public'::regnamespace
ORDER BY table_name;
```

### Step 5.2: IAP Login Test

```bash
# Test IAP login flow
# 1. Clear browser cookies
# 2. Navigate to http://localhost:3000
# 3. Login with Google (or use IAP_DEV_MODE)
# 4. Verify user is auto-created in database
# 5. Verify Google Groups are synced
# 6. Verify chatbot group assignment
# 7. Verify corpus access
```

### Step 5.3: Google Groups Bridge Test

```bash
# Test bridge sync
curl -s -X POST http://localhost:8000/api/admin/google-groups/sync/5 | jq

# Expected output:
# {
#   "user_id": 5,
#   "email": "hector@develom.com",
#   "google_groups": ["rag-admins@develom.com", ...],
#   "chatbot_group": "admin-group",
#   "corpora_synced": 4,
#   "from_cache": false,
#   "status": "synced"
# }
```

### Step 5.4: Run Bridge Validation Tests

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend
source .venv/bin/activate
python tests/test_bridge_validation.py --email hector@develom.com

# Expected: 57 passed, 0 failed
```

### Step 5.5: Admin UI Test

**Manual testing checklist:**

- [ ] Navigate to `/admin/users` — users list displays
- [ ] "Create User" button is gone
- [ ] "Sync from Google Groups" button works
- [ ] User details show Google Groups (read-only)
- [ ] Navigate to `/admin/groups` — page does not exist (404)
- [ ] Navigate to `/admin/google-groups` — bridge status displays
- [ ] "Sync All Users" button works
- [ ] Navigate to `/admin/chatbot-users` — still works
- [ ] Navigate to `/admin/chatbot-groups` — still works

### Step 5.6: API Endpoint Test

```bash
# Test removed endpoints return 404
curl -s -X POST http://localhost:8000/api/admin/users -d '{}' -H "Content-Type: application/json"
# Expected: 404

curl -s http://localhost:8000/api/admin/groups
# Expected: 404

# Test kept endpoints still work
curl -s http://localhost:8000/api/admin/users | jq
# Expected: List of users

curl -s http://localhost:8000/api/admin/google-groups/status | jq
# Expected: Bridge status
```

---

## Rollback Plan

### If Issues Occur in Phase 1 (Database Table Removal)

```sql
-- Restore from backup
psql $DATABASE_URL < database_backups/backup_TIMESTAMP.sql

-- Or recreate tables manually
CREATE TABLE groups (...);
CREATE TABLE user_groups (...);
CREATE TABLE roles (...);
CREATE TABLE group_roles (...);
```

### If Issues Occur in Phase 2 (Users Table Simplification)

```sql
-- Restore from backup
psql $DATABASE_URL < database_backups/backup_TIMESTAMP.sql

-- Or add columns back
ALTER TABLE users ADD COLUMN hashed_password VARCHAR(255);
ALTER TABLE users ADD COLUMN username VARCHAR(255);
ALTER TABLE users ADD COLUMN auth_provider VARCHAR(50) DEFAULT 'iap';
```

### If Issues Occur in Phase 3-4 (Code Changes)

```bash
# Revert git commits
git log --oneline -10
git revert <commit-hash>

# Or reset to previous commit
git reset --hard <commit-hash>
git push --force
```

---

## Post-Migration Verification

### Checklist

- [ ] All users can login via IAP
- [ ] Google Groups Bridge syncs correctly
- [ ] Chatbot group assignments work
- [ ] Corpus access permissions work
- [ ] User preferences (theme, language) still work
- [ ] Admin pages display correctly
- [ ] No 500 errors in backend logs
- [ ] No console errors in frontend
- [ ] Database backup created and verified
- [ ] All tests pass
- [ ] Documentation updated

### Metrics to Monitor

```sql
-- Active users count
SELECT COUNT(*) FROM users WHERE is_active = TRUE;

-- Synced users count
SELECT COUNT(*) FROM user_google_group_sync WHERE google_groups != '[]'::jsonb;

-- Chatbot group assignments
SELECT COUNT(*) FROM chatbot_user_groups;

-- Corpus access entries
SELECT COUNT(*) FROM chatbot_corpus_access;
```

### Documentation Updates

**Files to update:**

1. `backend/README.md` — Remove local auth instructions
2. `docs/DEPLOYMENT.md` — Update auth section
3. `docs/ADMIN_GUIDE.md` — Update user management section
4. `cascade-logs/2026-02-18/AUTH-CLEANUP-MIGRATION-PLAN-02-18-26.md` — Mark as completed

---

## Summary

### What Was Removed

- **4 database tables:** groups, user_groups, roles, group_roles
- **3 user columns:** hashed_password, username, auth_provider
- **~10 API endpoints:** user creation, group management, user→group assignment
- **3 frontend pages:** user creation form, group management, user→group assignment

### What Remains

- **IAP authentication:** All users authenticate via Google
- **Google Groups Bridge:** All authorization via Google Groups
- **User management:** View, deactivate, update preferences
- **Bridge management:** Sync, status, configuration

### Benefits

1. **Simpler architecture** — Single source of truth (Google)
2. **Less code to maintain** — Removed ~1000 lines of code
3. **Better security** — No local passwords
4. **Easier onboarding** — Auto-create users on first login
5. **Centralized management** — All user/group management in Google Workspace

### Estimated Impact

- **Database size:** -4 tables, -3 columns
- **Code size:** -~1000 lines
- **API endpoints:** -~10 routes
- **Maintenance effort:** -30%
- **Security risk:** -50% (no local passwords)

---

## Next Steps

After successful migration:

1. Monitor production for 1 week
2. Update client documentation
3. Train admins on new Google Groups Bridge workflow
4. Consider further simplifications (e.g., merge users + chatbot_users)
5. Archive legacy auth code to separate repository
