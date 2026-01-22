# Permissions Reference - ADK Multi-Agents

**Date:** January 19, 2026  
**Status:** Current Implementation

---

## Permission System Overview

The app uses a **role-based access control (RBAC)** system where:

1. **Users** belong to **Groups**
2. **Groups** are assigned **Roles**
3. **Roles** contain **Permissions** (array of strings)
4. Access is checked via `require_permission()` middleware

---

## Permission Format

Permissions follow the pattern: `<action>:<resource>`

**Examples:**
- `read:corpora` - Read corpora
- `manage:agents` - Manage agents
- `create:corpus` - Create new corpus

### Wildcards

The system supports wildcard permissions:

| Wildcard | Meaning | Example |
|----------|---------|---------|
| `*` | All permissions | Full admin access |
| `action:*` | All resources for an action | `read:*` = read everything |
| `manage:*` | All management permissions | All admin operations |

**Wildcard matching logic:**
```python
# Check in order:
1. Exact match: "manage:corpora"
2. Global wildcard: "*"
3. Action wildcard: "manage:*"
```

---

## Currently Used Permissions

### 1. Corpus Management

| Permission | Used In | Description |
|------------|---------|-------------|
| `manage:corpora` | `GET /api/corpora/all` | List all corpora (admin view) |
| `create:corpus` | `POST /api/corpora/` | Create new corpus |
| `update:corpus` | `PUT /api/corpora/{id}` | Update corpus details |
| `manage:corpus_access` | `POST /api/corpora/{id}/access`<br>`DELETE /api/corpora/{id}/access/{group}` | Grant/revoke group access to corpora |

### 2. Agent Management

| Permission | Used In | Description |
|------------|---------|-------------|
| `manage:agents` | `POST /api/agents/`<br>`PUT /api/agents/{id}/activate`<br>`PUT /api/agents/{id}/deactivate` | Create and manage agents |
| `manage:agent_access` | `POST /api/agents/{id}/users/{user}`<br>`DELETE /api/agents/{id}/users/{user}` | Grant/revoke user access to agents |

### 3. Groups & Roles

| Permission | Used In | Description |
|------------|---------|-------------|
| `manage:groups` | All `/api/groups/*` endpoints | Full group management (documented in code comments, not enforced) |
| `manage:roles` | All `/api/groups/roles/*` endpoints | Full role management (documented in code comments, not enforced) |

**Note:** Groups and Roles routes currently use `require_admin` (group-based check) instead of permission-based checks.

### 4. Admin Panel

**All admin routes use `require_admin` dependency** which checks:
- User is in `admin-users` group, **OR**
- User has `admin:all` permission

Admin routes include:
- User management (`/api/admin/users/*`)
- Corpus admin (`/api/admin/corpora/*`)
- Audit logs (`/api/admin/audit/*`)
- Bulk operations (`/api/admin/corpora/bulk/*`)

---

## Permission Implementation Details

### Middleware: `require_permission()`

**File:** `backend/src/middleware/authorization_middleware.py`

```python
@router.get("/corpora/all")
async def list_all_corpora(
    current_user: User = Depends(require_permission("manage:corpora"))
):
    # Only users with "manage:corpora" permission can access
```

**Available decorators:**
1. `require_permission(permission)` - Single permission required
2. `require_any_permission(*permissions)` - Any of multiple permissions
3. `require_all_permissions(*permissions)` - All of multiple permissions

### Permission Check Logic

**File:** `backend/src/services/group_service.py` (Line 209)

```python
def check_permission(user_id: int, permission: str) -> bool:
    """
    Check if user has permission through their groups/roles.
    
    Process:
    1. Get all user's roles (via group memberships)
    2. For each role, check permissions array:
       - If "*" exists → GRANTED
       - If exact match → GRANTED
       - If "action:*" matches → GRANTED
    3. Return False if no match
    """
```

### Admin Check Logic

**File:** `backend/src/api/routes/admin.py` (Line 36)

```python
def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """
    Check if user is admin via:
    1. Member of 'admin-users' group, OR
    2. Has 'admin:all' permission
    """
```

---

## Recommended Complete Permission Set

Based on the app's functionality, here's a suggested complete permission set:

### **Corpus Permissions**
- `read:corpora` - View accessible corpora
- `create:corpus` - Create new corpus
- `update:corpus` - Modify corpus metadata
- `delete:corpus` - Delete/deactivate corpus
- `manage:corpora` - Full corpus admin (includes all above)
- `manage:corpus_access` - Grant/revoke group access

### **Agent Permissions**
- `read:agents` - View agents
- `create:agent` - Create new agent
- `update:agent` - Modify agent config
- `delete:agent` - Delete/deactivate agent
- `manage:agents` - Full agent admin (includes all above)
- `manage:agent_access` - Grant/revoke user access to agents

### **User & Group Permissions**
- `read:users` - View user list
- `create:user` - Create new user
- `update:user` - Modify user details
- `delete:user` - Deactivate user
- `manage:users` - Full user admin
- `read:groups` - View groups
- `create:group` - Create new group
- `update:group` - Modify group
- `delete:group` - Delete group
- `manage:groups` - Full group admin
- `manage:user_groups` - Add/remove users from groups

### **Role Permissions**
- `read:roles` - View roles
- `create:role` - Create new role
- `update:role` - Modify role
- `delete:role` - Delete role
- `manage:roles` - Full role admin
- `manage:group_roles` - Assign/remove roles from groups

### **Document Permissions**
- `read:documents` - View documents in corpora
- `upload:documents` - Upload new documents
- `delete:documents` - Remove documents
- `manage:documents` - Full document admin

### **System Permissions**
- `read:audit` - View audit logs
- `manage:audit` - Full audit log access
- `read:stats` - View statistics/dashboards
- `manage:system` - System configuration
- `admin:all` - Full admin access (wildcard)

### **Query Permissions**
- `query:corpora` - Execute RAG queries (default for all users)
- `query:advanced` - Advanced query features

---

## Current Database Roles

**From database:**

| Role ID | Name | Permissions |
|---------|------|-------------|
| 1 | `user` | `[]` (empty - needs population) |
| 3 | `admin-role` | `["admin:all"]` |
| 4 | `corpora-manager-role` | `["manage:corpora"]` |

---

## Permission Assignment Workflow

### 1. **Create Role with Permissions**
```bash
POST /api/groups/roles/
{
  "name": "corpus-editor",
  "description": "Can create and edit corpora",
  "permissions": [
    "read:corpora",
    "create:corpus",
    "update:corpus"
  ]
}
```

### 2. **Assign Role to Group**
```bash
POST /api/groups/{group_id}/roles/{role_id}
```

### 3. **Add Users to Group**
```bash
POST /api/admin/users/{user_id}/groups/{group_id}
```

### 4. **Permission Check Flow**
```
User Login
  ↓
Get User's Groups → Get Groups' Roles → Aggregate Permissions
  ↓
User makes request to protected endpoint
  ↓
Middleware checks: Does user have required permission?
  ↓
YES: Allow    NO: 403 Forbidden
```

---

## Implementation Status

### ✅ Implemented
- Permission middleware (`require_permission`)
- Permission checking logic (exact, wildcard)
- JSONB storage for permissions
- Role creation with permissions
- Permission display in UI

### ⚠️ Partially Implemented
- Some routes use `require_admin` instead of specific permissions
- Groups/Roles routes documented permissions but don't enforce them

### ❌ Not Yet Implemented
- Permission management UI (add/remove permissions from roles)
- Document-level permissions
- Query permissions
- Fine-grained read/write separation for most resources
- Permission inheritance/cascading
- Permission audit trail (who granted what to whom)

---

## Migration Path

To move from `require_admin` to granular permissions:

### Phase 1: Define Permission Set
1. Create comprehensive permission list (use recommended set above)
2. Document which endpoints need which permissions

### Phase 2: Populate Existing Roles
```sql
-- Update default roles with appropriate permissions
UPDATE roles 
SET permissions = '["read:corpora", "query:corpora"]'::jsonb
WHERE name = 'user';

UPDATE roles
SET permissions = '["admin:all"]'::jsonb  
WHERE name = 'admin-role';
```

### Phase 3: Replace require_admin
```python
# Before:
@router.get("/users")
async def list_users(current_user: User = Depends(require_admin)):
    ...

# After:
@router.get("/users")
async def list_users(
    current_user: User = Depends(require_permission("read:users"))
):
    ...
```

### Phase 4: UI Enhancements
- Add permission picker when creating/editing roles
- Show effective permissions for users in admin panel
- Add permission testing tool for admins

---

## Security Best Practices

1. **Principle of Least Privilege**
   - Grant minimum permissions needed
   - Use specific permissions over wildcards

2. **Default Deny**
   - All routes protected by default
   - Explicitly define which permissions are needed

3. **Audit Everything**
   - Log permission changes
   - Track who granted access to whom

4. **Regular Review**
   - Periodically audit role assignments
   - Remove unused permissions

5. **Separation of Duties**
   - Don't give one role too many permissions
   - Use multiple roles for different responsibilities

---

## Example Role Definitions

### Standard User
```json
{
  "name": "standard-user",
  "permissions": [
    "read:corpora",
    "query:corpora",
    "read:documents"
  ]
}
```

### Corpus Editor
```json
{
  "name": "corpus-editor",
  "permissions": [
    "read:corpora",
    "create:corpus",
    "update:corpus",
    "upload:documents",
    "delete:documents"
  ]
}
```

### Corpus Administrator
```json
{
  "name": "corpus-admin",
  "permissions": [
    "manage:corpora",
    "manage:corpus_access",
    "manage:documents"
  ]
}
```

### User Manager
```json
{
  "name": "user-manager",
  "permissions": [
    "read:users",
    "create:user",
    "update:user",
    "manage:user_groups"
  ]
}
```

### System Administrator
```json
{
  "name": "system-admin",
  "permissions": [
    "*"
  ]
}
```

---

## Summary

**Current State:**
- Permission system is **implemented and functional**
- **7 unique permissions** currently in use
- Mix of permission-based and group-based checks
- Roles can store permissions as JSONB arrays

**Recommended Actions:**
1. Define complete permission set (30-40 permissions)
2. Update existing roles with appropriate permissions
3. Replace `require_admin` with specific permission checks
4. Add permission management UI
5. Document permission requirements for all endpoints

**Permission Format:** `action:resource` with wildcard support  
**Storage:** JSONB array in roles table  
**Checking:** Via `GroupService.check_permission()`
