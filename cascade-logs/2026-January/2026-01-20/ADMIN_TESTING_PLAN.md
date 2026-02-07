# Admin Section Testing Plan

**Date:** January 20, 2026  
**Status:** 🔄 In Progress

---

## Objective

Comprehensive testing of admin sections to verify permissions, access control, and functionality:
1. Corpus Management
2. Group Management  
3. User Management

---

## Test Environment

**Users:**
- `hector` - Admin user (has `admin:all` permission)
- `testuser` - Standard user (needs role assignment for testing)

**Roles Available:**
1. `admin-role` - `admin:all`
2. `user` - `read:corpora`, `query:corpora`, `read:documents`, `read:agents`
3. `corpora-manager-role` - Full corpus management (8 permissions)
4. `corpus-viewer` - Read-only (3 permissions)
5. `corpus-editor` - Edit access (5 permissions)
6. `user-manager` - User/group management (7 permissions)
7. `agent-manager` - Agent management (6 permissions)

---

## 1. Corpus Management Testing

### Endpoints to Test

| Endpoint | Method | Permission Required | Description |
|----------|--------|-------------------|-------------|
| `/api/corpora/` | GET | (authenticated) | List user's accessible corpora |
| `/api/corpora/all` | GET | `manage:corpora` | List all corpora (admin) |
| `/api/corpora/{id}` | GET | (has access) | Get corpus details |
| `/api/corpora/` | POST | `create:corpus` | Create new corpus |
| `/api/corpora/{id}` | PUT | `update:corpus` | Update corpus |
| `/api/corpora/{id}/access` | POST | `manage:corpus_access` | Grant group access |
| `/api/corpora/{id}/access/{group_id}` | DELETE | `manage:corpus_access` | Revoke group access |

### Test Scenarios

#### A. Admin User (hector)
- [ ] List all corpora
- [ ] Create new corpus
- [ ] Update corpus metadata
- [ ] Grant group access to corpus
- [ ] Revoke group access from corpus
- [ ] View corpus details

#### B. Standard User (no special permissions)
- [ ] List accessible corpora only
- [ ] Cannot list all corpora (403)
- [ ] Cannot create corpus (403)
- [ ] Cannot update corpus (403)
- [ ] Cannot manage corpus access (403)
- [ ] Can view corpus if has access

#### C. Corpus Manager User
- [ ] Can list all corpora
- [ ] Can create corpus
- [ ] Can update corpus
- [ ] Can manage corpus access
- [ ] Full corpus CRUD operations

#### D. Corpus Viewer User
- [ ] Can read corpora with access
- [ ] Cannot create/update/delete
- [ ] Cannot manage access

#### E. Corpus Editor User
- [ ] Can read and update corpora
- [ ] Can upload documents
- [ ] Cannot create new corpora
- [ ] Cannot manage access

---

## 2. Group Management Testing

### Endpoints to Test

| Endpoint | Method | Permission Required | Description |
|----------|--------|-------------------|-------------|
| `/api/groups/` | GET | (authenticated) | List all groups |
| `/api/groups/` | POST | `manage:groups` | Create group |
| `/api/groups/{id}` | PUT | `manage:groups` | Update group |
| `/api/groups/{id}` | DELETE | `manage:groups` | Delete group |
| `/api/groups/{id}/roles/{role_id}` | PUT | `admin` | Assign role to group |
| `/api/groups/{id}/roles/{role_id}` | DELETE | `admin` | Remove role from group |

### Test Scenarios

#### A. Admin User
- [ ] List all groups
- [ ] Create new group
- [ ] Update group details
- [ ] Delete group
- [ ] Assign roles to group
- [ ] Remove roles from group
- [ ] Verify role permissions display in UI

#### B. Standard User
- [ ] Can view groups (if permitted)
- [ ] Cannot create/update/delete groups
- [ ] Cannot manage roles

---

## 3. User Management Testing

### Endpoints to Test

| Endpoint | Method | Permission Required | Description |
|----------|--------|-------------------|-------------|
| `/api/admin/users` | GET | `admin` | List all users |
| `/api/admin/users` | POST | `admin` | Create user |
| `/api/admin/users/{id}` | PUT | `admin` | Update user |
| `/api/admin/users/{id}` | DELETE | `admin` | Deactivate user |
| `/api/admin/users/{id}/groups/{group_id}` | POST | `admin` | Add user to group |
| `/api/admin/users/{id}/groups/{group_id}` | DELETE | `admin` | Remove user from group |

### Test Scenarios

#### A. Admin User
- [ ] List all users
- [ ] Create new user
- [ ] Update user details
- [ ] Deactivate user (soft delete)
- [ ] Add user to group
- [ ] Remove user from group
- [ ] Verify user can be recreated after deactivation

#### B. User Manager
- [ ] Can manage users
- [ ] Can manage group assignments
- [ ] Cannot manage roles (admin only)

---

## Test Data Setup

### Groups to Create:
1. `test-corpus-managers` - Assign `corpora-manager-role`
2. `test-viewers` - Assign `corpus-viewer`
3. `test-editors` - Assign `corpus-editor`

### Users to Create:
1. `corpus-manager-test` - Add to `test-corpus-managers`
2. `viewer-test` - Add to `test-viewers`
3. `editor-test` - Add to `test-editors`

### Corpora to Test:
- Use existing corpora
- Create test corpus if needed

---

## Testing Notes

### Found Issues:
(To be filled in during testing)

### Expected Behavior:
- Permissions correctly enforce access control
- UI displays appropriate options based on user permissions
- Error messages are clear and helpful
- Idempotent operations work correctly (e.g., assigning same role twice)

### Success Criteria:
- All permission checks work correctly
- No unauthorized access allowed
- No errors for valid operations
- Clear error messages for unauthorized operations
- UI matches backend permissions

---

## Progress Tracking

### Corpus Management: 🔄 In Progress
- [ ] Admin scenarios
- [ ] Standard user scenarios
- [ ] Role-based scenarios

### Group Management: ⏳ Pending
- [ ] Admin scenarios
- [ ] Standard user scenarios

### User Management: ⏳ Pending
- [ ] Admin scenarios
- [ ] User manager scenarios

---

## Next Steps After Testing

1. Fix any bugs discovered
2. Update documentation with findings
3. Create regression test suite if needed
4. Document best practices for permission assignment
