# User Profiles Schema Missing Columns Fix

**Date:** January 19, 2026  
**Status:** ✅ Fixed

---

## Problem

User creation was failing with error:
```
Failed to create user: column "theme" of relation "user_profiles" does not exist
LINE 2: INSERT INTO user_profiles (user_id, theme, lan...
```

Users were being created in the `users` table, but profile creation failed due to missing columns.

---

## Root Cause

**Schema Mismatch:** The `user_profiles` table in PostgreSQL database was missing columns that the code expected:

### Missing Columns:
1. `theme` (VARCHAR)
2. `language` (VARCHAR)
3. `timezone` (VARCHAR)

### Code Expected (user_repository.py:156):
```python
INSERT INTO user_profiles (user_id, theme, language, timezone, preferences)
VALUES (%s, %s, %s, %s, %s)
```

### Database Had:
- id
- user_id
- bio
- avatar_url
- preferences
- created_at
- updated_at

---

## Solution

### 1. Added Missing Columns to Database

```sql
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS theme VARCHAR(50) DEFAULT 'light';

ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en';

ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) DEFAULT 'UTC';
```

### 2. Updated Schema File

Modified `backend/init_postgresql_schema.sql` to include these columns for future deployments:

```sql
CREATE TABLE IF NOT EXISTS user_profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    theme VARCHAR(50) DEFAULT 'light',      -- ADDED
    language VARCHAR(10) DEFAULT 'en',      -- ADDED
    timezone VARCHAR(50) DEFAULT 'UTC',     -- ADDED
    preferences JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

---

## Files Modified

1. **`backend/init_postgresql_schema.sql`** (Lines 26-28)
   - Added theme, language, timezone columns to user_profiles table definition

2. **PostgreSQL Database (direct ALTER TABLE)**
   - Added three missing columns with default values

---

## Verification

After fix, `user_profiles` table now has:
- ✅ id
- ✅ user_id
- ✅ bio
- ✅ avatar_url
- ✅ **theme** (DEFAULT: 'light')
- ✅ **language** (DEFAULT: 'en')
- ✅ **timezone** (DEFAULT: 'UTC')
- ✅ preferences
- ✅ created_at
- ✅ updated_at

---

## Impact

### Before Fix:
- Users created in `users` table ✅
- Profile creation failed ❌
- Browser showed error: "column theme does not exist"

### After Fix:
- Users created in `users` table ✅
- Profile created in `user_profiles` table ✅
- All columns match between code and database ✅

---

## Related Issues

This fix completes the trilogy of user creation bugs:

1. ✅ **execute_insert() dict access bug** - prevented audit logs and some entity creation
2. ✅ **fetchone()[0] dict access bugs** - prevented user/agent/corpus/group creation
3. ✅ **user_profiles schema mismatch** - prevented profile creation after user creation

All three needed to be fixed for complete user creation functionality.

---

## Testing

User creation through admin UI should now work end-to-end:

1. Go to `/admin/users`
2. Click "Add User"
3. Fill in username, email, full name, password
4. Select groups (optional)
5. User should be created successfully with:
   - ✅ User record in `users` table
   - ✅ Profile record in `user_profiles` table with theme/language/timezone
   - ✅ Group assignments (if any)
   - ✅ No browser errors

---

## Prevention

For future schema changes:
- [ ] Keep `init_postgresql_schema.sql` in sync with repository code
- [ ] Create migration scripts for schema changes
- [ ] Test against PostgreSQL before deploying
- [ ] Verify all INSERT statements match actual table columns
