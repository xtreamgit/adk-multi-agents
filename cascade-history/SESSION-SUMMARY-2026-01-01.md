# Session Summary - January 1, 2026

## Objective
Investigate and fix RBAC (Role-Based Access Control) permission issues preventing users from accessing corpora through group memberships.

---

## Problems Identified

### 1. Users Couldn't See Corpora
- Test users (Alice, Bob, Charlie) showed 0 corpora despite permissions being "set"
- `/api/users/me/groups` returned empty arrays
- RBAC testing script appeared to succeed but didn't actually work

### 2. Root Cause Analysis
Investigation revealed **two critical API endpoint bugs** in `test_rbac.sh`:

**Bug 1: User-to-Group Assignment**
- ❌ Script used: `POST /api/groups/{group_id}/members/{user_id}/{role}`
- ✅ Actual endpoint: `PUT /api/groups/{group_id}/users/{user_id}`
- **Impact**: Users were never added to groups, so they had no permissions

**Bug 2: Corpus Permission Grants**
- ❌ Script used: `POST /api/corpora/{corpus_id}/groups/{group_id}/{permission}`
- ✅ Actual endpoint: `POST /api/corpora/{corpus_id}/grant` with JSON body
- **Impact**: Group permissions were never granted to corpora

### 3. Additional Issue
- Password validation: Bob's password "bob123" was too short (min 8 chars required)

---

## Solutions Implemented

### File: `/backend/scripts/test_rbac.sh`

**Fix 1: Updated User-to-Group Assignment**
```bash
# Before (wrong)
curl -s -X POST "$BASE_URL/api/groups/$DEVS_ID/members/$ALICE_ID/admin"

# After (correct)
curl -s -X PUT "$BASE_URL/api/groups/$DEVS_ID/users/$ALICE_ID"
```

**Fix 2: Updated Corpus Permission Grants**
```bash
# Before (wrong)
curl -s -X POST "$BASE_URL/api/corpora/$CORPUS_ID/groups/$DEVS_ID/admin"

# After (correct)
curl -s -X POST "$BASE_URL/api/corpora/$CORPUS_ID/grant" \
  -H "Content-Type: application/json" \
  -d "{\"group_id\":$DEVS_ID,\"permission\":\"admin\"}"
```

**Fix 3: Updated Bob's Password**
- Changed from "bob123" (7 chars) to "bob12345" (8 chars)

---

## Verification Results

### Database Validation
```sql
-- User-Group Memberships (verified)
SELECT * FROM user_groups WHERE user_id IN (2,3,4);
-- Result: Alice→Developers, Bob→Managers, Charlie→Viewers ✓

-- Corpus Permissions (verified)
SELECT * FROM group_corpus_access;
-- Result: All groups have appropriate corpus access ✓
```

### API Testing Results

**Alice (Developer - Admin Access):**
```json
[
  { "name": "ai-books", "permission": "admin" },
  { "name": "develom-general", "permission": "admin" }
]
```

**Bob (Manager - Admin Access):**
```json
[
  { "name": "ai-books", "permission": "admin" },
  { "name": "develom-general", "permission": "admin" }
]
```

**Charlie (Viewer - Read-Only):**
```json
[
  { "name": "ai-books", "permission": "read" },
  { "name": "develom-general", "permission": "read" }
]
```

**Permission Enforcement:**
- Charlie attempting to create corpus: `"Insufficient permissions. Required: create:corpus"` ✓

---

## RBAC System Architecture

### Test Data Created
| User | Password | Group | Role | Permissions |
|------|----------|-------|------|-------------|
| alice | alice123 | Developers (ID: 4) | Member | Admin access to all corpora |
| bob | bob12345 | Managers (ID: 5) | Member | Admin access to all corpora |
| charlie | charlie123 | Viewers (ID: 6) | Member | Read-only access to all corpora |

### API Endpoints Used
- `POST /api/auth/register` - Create users
- `POST /api/auth/login` - Authenticate users
- `POST /api/groups/` - Create groups
- `PUT /api/groups/{group_id}/users/{user_id}` - Add user to group
- `POST /api/corpora/{corpus_id}/grant` - Grant group access to corpus
- `GET /api/corpora/` - List corpora (filtered by user permissions)
- `GET /api/users/me/groups` - Get user's group memberships

### Database Schema
```
users
  ↓ (1:N)
user_groups (junction table)
  ↓ (N:1)
groups
  ↓ (N:M)
group_corpus_access
  ↓ (N:1)
corpora
```

---

## Key Learnings

### 1. API Endpoint Discovery
- No `/api/users/` GET endpoint exists (no public user listing)
- Users can only be created via `/api/auth/register`
- User IDs obtained by logging in and extracting from token response

### 2. RBAC Permission Flow
```
User → user_groups → Group → group_corpus_access → Corpus
```
- Users don't have direct corpus access
- All access is through group memberships
- `CorpusRepository.get_user_corpora()` joins these tables

### 3. Password Validation
- Minimum 8 characters enforced at model level
- Validation happens before database insert

---

## Questions & Answers

### Q1: Does the API interact with the database?
**A:** Yes, the API fully interacts with SQLite database at `/backend/data/users.db`:
- Routes → Services → Repositories → Database
- All user, group, and permission data persists in SQLite

### Q2: Are we using PostgreSQL?
**A:** No, currently using **SQLite** (file-based database at `/backend/data/users.db`)
- Suitable for local development
- **Not suitable for Cloud Run production** (ephemeral file systems)

### Q3: Can we deploy to GCP Cloud Run?
**A:** Yes, but **requires migration to PostgreSQL (Cloud SQL)** first:
- ❌ SQLite: Each container has isolated file system, data not shared
- ✅ Cloud SQL: Shared database across all container instances
- Current REST API architecture is compatible with Cloud Run
- Load balancing and multi-service setup (backend, backend-agent1, etc.) will work

---

## Testing Instructions

### Run Automated Script
```bash
cd backend/scripts
./test_rbac.sh
```

### Manual Frontend Testing
1. Logout from admin account
2. Login as each test user:
   - `alice` / `alice123` → Should see 2 corpora with admin access
   - `bob` / `bob12345` → Should see 2 corpora with admin access
   - `charlie` / `charlie123` → Should see 2 corpora with read-only access
3. Verify permission enforcement:
   - Charlie should NOT be able to create/edit corpora
   - Alice and Bob should have full access

---

## Files Modified

### `/backend/scripts/test_rbac.sh`
- Fixed user-to-group assignment endpoint
- Fixed corpus permission grant endpoint
- Updated Bob's password length
- Enhanced error handling for existing users/groups
- All RBAC operations now use correct API endpoints

---

## Status: ✅ COMPLETE

**RBAC system is fully functional:**
- ✅ Users can be created and assigned to groups
- ✅ Groups can be granted permissions on corpora
- ✅ Permission filtering works correctly
- ✅ Read-only enforcement works for viewers
- ✅ Admin/write permissions work for developers/managers
- ✅ Group memberships properly stored and queryable
- ✅ Automated testing script works end-to-end

**Next Steps for Production:**
1. Migrate from SQLite to PostgreSQL/Cloud SQL
2. Update database connection code for Cloud SQL
3. Deploy to Cloud Run with existing multi-service architecture
4. Test RBAC in production environment

---

## Technical Context

**Database:** SQLite (local: `/backend/data/users.db`)  
**Backend:** FastAPI with JWT authentication  
**Frontend:** Next.js with TypeScript  
**Architecture:** Service layer → Repository layer → SQLite  
**Testing:** Automated bash script + manual frontend testing  

**Deployment Ready:** Local ✅ | Cloud Run ⏳ (needs PostgreSQL migration)
