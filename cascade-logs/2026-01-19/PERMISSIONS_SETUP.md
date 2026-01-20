# Permissions Setup - Role Population

**Date:** January 19, 2026  
**Status:** ✅ Complete

---

## Summary

Populated all roles in the database with comprehensive, production-ready permissions following the recommended permission set.

---

## Updated Existing Roles

### 1. **user** (ID: 1)
**Description:** Standard user with read and query access

**Permissions (4):**
- `read:corpora` - View accessible corpora
- `query:corpora` - Execute RAG queries
- `read:documents` - View documents in corpora
- `read:agents` - View available agents

**Use Case:** Default role for all regular users who need to query the RAG system.

---

### 2. **corpora-manager-role** (ID: 4)
**Description:** Full corpus and document management

**Permissions (8):**
- `read:corpora` - View corpora
- `create:corpus` - Create new corpus
- `update:corpus` - Modify corpus metadata
- `manage:corpora` - Full corpus administration
- `manage:corpus_access` - Grant/revoke group access to corpora
- `read:documents` - View documents
- `upload:documents` - Upload new documents
- `delete:documents` - Remove documents

**Use Case:** Corpus administrators who manage the knowledge base.

---

### 3. **admin-role** (ID: 3)
**Description:** System administrator with full access

**Permissions (1):**
- `admin:all` - Wildcard permission granting all access

**Use Case:** System administrators with unrestricted access.

---

## Created New Role Templates

### 4. **user-manager** (ID: 5)
**Description:** Can manage users and group assignments

**Permissions (7):**
- `read:users` - View user list
- `create:user` - Create new users
- `update:user` - Modify user details
- `delete:user` - Deactivate users
- `manage:users` - Full user administration
- `read:groups` - View groups
- `manage:user_groups` - Add/remove users from groups

**Use Case:** HR or team leads who manage user accounts and group memberships.

---

### 5. **agent-manager** (ID: 6)
**Description:** Can create and manage agents and their access

**Permissions (6):**
- `read:agents` - View agents
- `create:agent` - Create new agents
- `update:agent` - Modify agent configuration
- `delete:agent` - Deactivate agents
- `manage:agents` - Full agent administration
- `manage:agent_access` - Grant/revoke user access to agents

**Use Case:** Technical leads who configure and manage AI agents.

---

### 6. **corpus-viewer** (ID: 7)
**Description:** Read-only access to corpora and documents

**Permissions (3):**
- `read:corpora` - View corpora
- `read:documents` - View documents
- `query:corpora` - Execute queries

**Use Case:** External stakeholders or contractors with read-only access.

---

### 7. **corpus-editor** (ID: 8)
**Description:** Can edit corpora and upload documents

**Permissions (5):**
- `read:corpora` - View corpora
- `update:corpus` - Modify corpus metadata
- `read:documents` - View documents
- `upload:documents` - Upload new documents
- `query:corpora` - Execute queries

**Use Case:** Content managers who maintain and update corpus content without full admin rights.

---

## Permission Categories

### **Corpus Permissions** (5 total)
- `read:corpora`
- `create:corpus`
- `update:corpus`
- `manage:corpora`
- `manage:corpus_access`

### **Document Permissions** (3 total)
- `read:documents`
- `upload:documents`
- `delete:documents`

### **Agent Permissions** (6 total)
- `read:agents`
- `create:agent`
- `update:agent`
- `delete:agent`
- `manage:agents`
- `manage:agent_access`

### **User Permissions** (5 total)
- `read:users`
- `create:user`
- `update:user`
- `delete:user`
- `manage:users`

### **Group Permissions** (2 total)
- `read:groups`
- `manage:user_groups`

### **Query Permissions** (1 total)
- `query:corpora`

### **Admin Permissions** (1 total)
- `admin:all` (wildcard)

---

## Usage Examples

### Assign Role to Group
```bash
POST /api/groups/{group_id}/roles/{role_id}
```

### Example Workflows

**1. Create a content team group:**
```bash
# Create group
POST /api/groups/
{
  "name": "content-team",
  "description": "Content management team"
}

# Assign corpus-editor role
POST /api/groups/1/roles/8

# Add users to group
POST /api/admin/users/5/groups/1
POST /api/admin/users/6/groups/1
```

**2. Create an HR group:**
```bash
# Create group
POST /api/groups/
{
  "name": "hr-team",
  "description": "Human resources"
}

# Assign user-manager role
POST /api/groups/2/roles/5
```

---

## Role Assignment Matrix

| Group Type | Recommended Role(s) | Permissions Count |
|------------|-------------------|-------------------|
| **Standard Users** | `user` | 4 |
| **Content Team** | `corpus-editor` | 5 |
| **Corpus Admins** | `corpora-manager-role` | 8 |
| **HR / User Admins** | `user-manager` | 7 |
| **Technical Team** | `agent-manager` | 6 |
| **External Viewers** | `corpus-viewer` | 3 |
| **System Admins** | `admin-role` | All (wildcard) |

---

## Permission Checking Flow

```
User Request
  ↓
Get user's groups → Get groups' roles → Aggregate permissions
  ↓
Check if required permission exists:
  1. Exact match: "manage:corpora"
  2. Wildcard match: "admin:all" or "manage:*"
  ↓
YES: Allow request
NO: 403 Forbidden
```

---

## Database State

**Total Roles:** 7  
**Total Unique Permissions:** 23  
**All permissions stored as JSONB arrays**

### Verification Query:
```sql
SELECT 
  name, 
  description,
  jsonb_array_length(permissions) as perm_count,
  permissions
FROM roles
ORDER BY name;
```

---

## Next Steps

### Immediate:
1. ✅ Roles populated with permissions
2. ⏭️ Assign roles to appropriate groups
3. ⏭️ Add users to groups
4. ⏭️ Test permission enforcement on protected endpoints

### Future Enhancements:
1. **Permission Management UI**
   - Add/remove permissions from roles in admin panel
   - Visual permission picker when creating roles
   
2. **Permission Audit**
   - Track when permissions are granted/revoked
   - Show effective permissions for each user
   
3. **Fine-grained Permissions**
   - Resource-level permissions (per-corpus access)
   - Time-based permissions (temporary access)
   
4. **Permission Testing Tool**
   - Admin tool to test "What can user X do?"
   - Permission simulation/preview

---

## Security Considerations

### Principle of Least Privilege
- Users should only have permissions they actively need
- Use specific roles over wildcard permissions
- Regularly audit and remove unused permissions

### Default Deny
- All endpoints protected by default
- Explicit permission checks required
- No implicit permissions granted

### Separation of Duties
- Different roles for different responsibilities
- No single role should have too much power (except admin)
- Combine roles for complex permission sets

### Regular Reviews
- Quarterly permission audits
- Remove inactive users from groups
- Update role permissions as needs change

---

## Summary

**Created:** 7 roles with 23 unique permissions  
**Coverage:** Corpus, Agent, User, Document, Query, and Admin operations  
**Pattern:** `action:resource` with wildcard support  
**Storage:** PostgreSQL JSONB arrays  
**Status:** Production-ready

All roles are now populated and ready for assignment to groups.
