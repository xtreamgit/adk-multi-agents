# SQLite Removal Implementation Plan - Option 1

## Branch: feature/remove-sqlite-enforce-postgresql

**Goal:** Remove all SQLite code and enforce PostgreSQL-only architecture

**Started:** January 28, 2026, 12:56 PM

---

## Phase 1: Convert Migration Files to PostgreSQL Syntax ✅

### Files to Convert (8 files):
1. `001_initial_schema.sql` - 1 AUTOINCREMENT
2. `002_add_groups_roles.sql` - 5 AUTOINCREMENT
3. `003_add_agents_corpora.sql` - 6 AUTOINCREMENT
4. `004_add_admin_tables.sql` - 3 AUTOINCREMENT
5. `006_add_iap_support.sql` - 1 AUTOINCREMENT
6. `008_create_document_access_log.sql` - 1 AUTOINCREMENT (already fixed in schema_init.py)

### Conversion Rules:
- `INTEGER PRIMARY KEY AUTOINCREMENT` → `SERIAL PRIMARY KEY`
- `TEXT` → `VARCHAR(255)` or `TEXT` (case by case)
- Remove SQLite `PRAGMA` statements
- Ensure `TIMESTAMP` vs `DATETIME` consistency

---

## Phase 2: Simplify connection.py to PostgreSQL-Only ✅

### Changes:
1. Remove `import sqlite3`
2. Remove `DB_TYPE` variable (always PostgreSQL)
3. Remove `DATABASE_PATH` and SQLite config
4. Remove `PostgreSQLCursorWrapper` (no longer needed with PostgreSQL-only)
5. Simplify `get_db_connection()` to PostgreSQL-only
6. Remove dual-mode logic from `execute_query/insert/update`
7. Remove `init_database()` SQLite branch

---

## Phase 3: Update server.py and Remove SQLite Logic ✅

### Changes:
1. Remove SQLite migration skip logic
2. Always initialize PostgreSQL schema
3. Remove commented `import sqlite3`

---

## Phase 4: Delete SQLite Files ✅

### Files to Delete:
1. `backend/data/users.db`
2. `backend/data/users_backup_20260113_092118.db`
3. `backend/users.db`
4. `backend/scripts/export_sqlite_data.py`
5. `backend/scripts/export_sqlite_schema.py`
6. `backend/scripts/exported_schema.sql`
7. `backend/query_db.py`
8. `backend/fix_sqlite_placeholders.py`

---

## Phase 5: Update Documentation ✅

### Files to Update:
1. `docs/DEPLOYMENT_STATE.md` - Emphasize PostgreSQL-only
2. `backend/README.md` - Remove SQLite references
3. `backend/DEPLOYMENT.md` - Update database section
4. Create `docs/POSTGRESQL_ONLY.md` - Explain architecture decision

---

## Phase 6: Testing ✅

### Test Cases:
1. Verify PostgreSQL connection works
2. Test all CRUD operations
3. Verify migrations run correctly
4. Test Cloud Run deployment
5. Search for remaining "sqlite" references

---

## Phase 7: Final Commit ✅

### Commit Message:
```
Remove SQLite support, enforce PostgreSQL-only architecture

- Converted all migration files from SQLite to PostgreSQL syntax
- Removed dual-mode database support from connection.py
- Simplified codebase by removing ~500 lines of SQLite code
- Deleted SQLite database files and utility scripts
- Updated documentation to reflect PostgreSQL-only architecture
- Prevents future confusion about database type

This change aligns the codebase with production reality:
- Local development uses Docker PostgreSQL
- Cloud deployment uses Cloud SQL PostgreSQL
- No SQLite is used anywhere in the system
```

---

## Execution Log

### Phase 1: Migration Files
- [ ] Convert 001_initial_schema.sql
- [ ] Convert 002_add_groups_roles.sql
- [ ] Convert 003_add_agents_corpora.sql
- [ ] Convert 004_add_admin_tables.sql
- [ ] Convert 006_add_iap_support.sql
- [ ] Verify 008_create_document_access_log.sql (already PostgreSQL)

### Phase 2: connection.py
- [ ] Remove SQLite imports and config
- [ ] Simplify to PostgreSQL-only
- [ ] Remove PostgreSQLCursorWrapper
- [ ] Test connection

### Phase 3: server.py
- [ ] Remove SQLite skip logic
- [ ] Clean up imports

### Phase 4: File Deletion
- [ ] Delete database files
- [ ] Delete utility scripts

### Phase 5: Documentation
- [ ] Update DEPLOYMENT_STATE.md
- [ ] Update README files
- [ ] Create POSTGRESQL_ONLY.md

### Phase 6: Testing
- [ ] Run grep search for "sqlite"
- [ ] Verify no errors

### Phase 7: Commit
- [ ] Git add all changes
- [ ] Create comprehensive commit
- [ ] Update session summary
