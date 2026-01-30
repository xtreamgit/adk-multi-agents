# Role Creation Error Fix - Missing Permissions Column

**Date:** January 19, 2026  
**Status:** ✅ Fixed

---

## Problem

**Error when creating roles:**
```
Failed to create role: Load failed
```

**Backend Error:**
```
psycopg2.errors.UndefinedColumn: column "permissions" of relation "roles" does not exist
LINE 2: ...INSERT INTO roles (name, description, permissions, created_at)
```

---

## Root Cause

The `roles` table schema in PostgreSQL was missing the `permissions` column, but the repository code (`GroupRepository.create_role()`) was trying to insert into it.

**Schema mismatch:**
- **Database schema:** Only had `id`, `name`, `description`, `created_at`
- **Repository code:** Tried to insert `permissions` as well

This occurred during the SQLite → PostgreSQL migration. The original SQLite schema may not have had the permissions column either, or it was missed during migration.

---

## Solution

### 1. Add Missing Column to Database

```sql
ALTER TABLE roles 
ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '[]'::jsonb;
```

**Why JSONB?**
- PostgreSQL native JSON type with indexing support
- Automatically validates JSON structure
- More efficient than storing as TEXT
- Repository code uses `json.dumps()` to store, expects JSON back

### 2. Update Schema File

**File:** `backend/init_postgresql_schema.sql` (Line 59)

```sql
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '[]'::jsonb,  -- ✅ Added
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## How Permissions Work

### Storage Format:
```sql
-- Stored as JSONB array in PostgreSQL
permissions = '["read:users", "write:users", "manage:roles"]'::jsonb
```

### Repository Code:
**File:** `backend/src/database/repositories/group_repository.py`

```python
@staticmethod
def create_role(name: str, description: Optional[str] = None, 
               permissions: Optional[List[str]] = None) -> Dict:
    """Create a new role."""
    permissions_json = json.dumps(permissions) if permissions else None
    
    cursor.execute("""
        INSERT INTO roles (name, description, permissions, created_at)
        VALUES (%s, %s, %s, %s)
        RETURNING id
    """, (name, description, permissions_json, created_at))
```

### Retrieval:
```python
@staticmethod
def get_all_roles() -> List[Dict]:
    """Get all roles."""
    # PostgreSQL JSONB is automatically parsed to Python list
    cursor.execute("SELECT * FROM roles ORDER BY name")
    # No JSON parsing needed - JSONB → list happens automatically
```

**PostgreSQL advantage:** JSONB columns are automatically converted to Python types by psycopg2, unlike SQLite where we had to manually parse JSON strings.

---

## Testing

```bash
# Create role with permissions
curl -X POST http://localhost:8000/api/groups/roles/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-role",
    "description": "Test role",
    "permissions": ["read:users", "write:users"]
  }'

# Response:
{
  "id": 2,
  "name": "test-role",
  "description": "Test role",
  "permissions": ["read:users", "write:users"],  # ✅ Stored correctly
  "created_at": "2026-01-20T00:28:59.616148"
}
```

**Database verification:**
```sql
SELECT id, name, permissions FROM roles WHERE name = 'test-role';

-- Result:
id | name      | permissions
2  | test-role | ["read:users", "write:users"]  -- Stored as JSONB array
```

---

## Files Modified

1. **Database:** Added `permissions` column to `roles` table
2. **`backend/init_postgresql_schema.sql`** (Line 59)
   - Added `permissions JSONB DEFAULT '[]'::jsonb` to CREATE TABLE statement

---

## Impact

✅ **Role creation now works** - Can create roles with permissions  
✅ **Permissions stored correctly** - As JSONB array in PostgreSQL  
✅ **No repository code changes needed** - Existing code works with new schema  
✅ **Future-proof** - Schema file updated for fresh deployments

---

## Related Components

**Roles System:**
- Roles define permission sets (e.g., "admin" role has ["manage:*"])
- Groups are assigned roles via `group_roles` junction table
- Users inherit permissions through group membership
- Permissions format: `action:resource` (e.g., "read:corpora", "write:users")

**Permission Check Flow:**
1. User logs in → Get user's groups
2. For each group → Get assigned roles
3. For each role → Get permissions array
4. Aggregate all permissions
5. Check if required permission exists

**Example:**
```
User "alice" → Group "admin-users" → Role "admin" → ["manage:*"]
User "bob" → Group "users" → Role "user" → ["read:corpora", "write:documents"]
```

---

## Summary

**Problem:** Missing `permissions` column in roles table blocked role creation  
**Solution:** Added JSONB column to roles table and updated schema file  
**Result:** Role creation works, permissions stored as native PostgreSQL JSONB  

This completes the roles management system for the admin panel.
