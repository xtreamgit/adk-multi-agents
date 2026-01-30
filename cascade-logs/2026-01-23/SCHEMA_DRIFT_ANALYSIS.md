# Schema Drift Analysis - Missing user_sessions Columns

**Date:** January 23, 2026  
**Issue:** Cloud SQL missing `message_count` and `user_query_count` columns  
**Impact:** Chat UI completely broken (500 errors)

---

## 🔍 Root Cause

### What Happened

The columns were **never added to Cloud SQL**, not deleted. Here's the timeline:

**December 31, 2025 - January 10, 2026:**
- Migrations `004_add_message_count.sql` and `005_add_user_query_count.sql` were created
- These migrations were applied to **local SQLite/PostgreSQL** database
- Local database had the columns working correctly

**January 13, 2026 - Cloud SQL Migration:**
- Migrated from SQLite to Cloud SQL PostgreSQL
- Used `backend/init_postgresql_schema.sql` as the base schema
- **Problem:** Base schema doesn't include these columns (see lines 119-132)
- Data was migrated, but the schema used was the **old base schema**
- Migrations 004 and 005 were **never run against Cloud SQL**

**January 23, 2026 - Today:**
- Chat UI tries to create session → inserts `message_count` and `user_query_count`
- PostgreSQL rejects: `column "user_query_count" does not exist`
- Backend returns 500 error without CORS headers
- Browser shows CORS error (misleading)

---

## 📋 Evidence

### Base Schema (init_postgresql_schema.sql)
```sql
-- Lines 120-132
CREATE TABLE IF NOT EXISTS user_sessions (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(255) UNIQUE NOT NULL,
    user_id INTEGER NOT NULL,
    active_agent_id INTEGER,
    active_corpora TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    -- ❌ NO message_count
    -- ❌ NO user_query_count
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (active_agent_id) REFERENCES agents(id)
);
```

### Migrations (Should Have Been Applied)
- `004_add_message_count.sql` - Adds `message_count INTEGER DEFAULT 0`
- `005_add_user_query_count.sql` - Adds `user_query_count INTEGER DEFAULT 0`

### Code Expecting Columns
`backend/src/services/session_service.py:38-43`:
```python
cursor.execute("""
    INSERT INTO user_sessions 
    (session_id, user_id, active_agent_id, active_corpora, 
     created_at, last_activity, expires_at, is_active,
     message_count, user_query_count)  # ← Code expects these columns
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
""", ...)
```

---

## 🔧 What We Did Today

Applied migration manually:
```sql
ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS message_count INTEGER DEFAULT 0;
ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS user_query_count INTEGER DEFAULT 0;
```

Result: ✅ Columns added successfully

---

## 📊 Current State

### Local Database (if you have one running)
- **Status:** Likely has the columns already
- **Reason:** Migrations 004 and 005 were applied during local development
- **Check with:**
  ```bash
  # If using local PostgreSQL
  psql -d adk_agents_db_dev -c "\d user_sessions"
  ```

### Cloud SQL Database  
- **Status:** ✅ NOW has the columns (as of today)
- **Applied:** January 23, 2026
- **Method:** Manual ALTER TABLE via migration 004_add_session_counters.sql

---

## 🎯 Why This Happened

**Schema Drift Pattern:**
1. Initial schema created (`init_postgresql_schema.sql`)
2. Migrations added over time (004, 005, 006, etc.)
3. Cloud SQL initialized with base schema only
4. **Migrations never run against Cloud SQL** ← Root cause
5. Code evolved to use new columns
6. Cloud SQL schema fell behind

**Missing Process:**
- No automated migration runner for Cloud SQL
- Manual schema updates not tracked
- Base schema file not kept in sync with migrations

---

## ✅ Recommendations

### 1. Update Base Schema File
Add the missing columns to `init_postgresql_schema.sql`:
```sql
CREATE TABLE IF NOT EXISTS user_sessions (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(255) UNIQUE NOT NULL,
    user_id INTEGER NOT NULL,
    active_agent_id INTEGER,
    active_corpora TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    message_count INTEGER DEFAULT 0,        -- ✅ ADD
    user_query_count INTEGER DEFAULT 0,     -- ✅ ADD
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (active_agent_id) REFERENCES agents(id)
);
```

### 2. Create Migration Tracking
- Use `schema_migrations` table to track which migrations have been applied
- Run migration script during deployment
- Example: `backend/src/database/migrations/run_migrations.py`

### 3. Document Schema Sync Process
- When adding new migrations, update base schema file
- Test migrations against Cloud SQL before deploying
- Keep local and cloud schemas in sync

### 4. Verify No Other Drift
Check if other migrations are missing from Cloud SQL:
```sql
SELECT migration_name, applied_at 
FROM schema_migrations 
ORDER BY id;
```

Compare with migrations in `backend/src/database/migrations/`:
- 001_initial_schema.sql
- 002_add_groups_roles.sql
- 003_add_agents_corpora.sql
- 004_add_admin_tables.sql
- 005_add_user_query_count.sql ← **This one was missing**
- 006_add_iap_support.sql
- 007_fix_message_count.sql
- 008-010 (document access logs, corpus metadata, audit logs)

---

## 🚨 Action Items

- [ ] Verify local database has these columns (if using local dev)
- [ ] Update `init_postgresql_schema.sql` to include new columns
- [ ] Check if other migrations need to be applied to Cloud SQL
- [ ] Consider implementing automated migration runner for deployments
- [ ] Document schema sync process in deployment guide
