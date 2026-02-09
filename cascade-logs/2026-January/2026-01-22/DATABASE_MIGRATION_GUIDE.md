# Database Schema Migration Guide

**Date:** January 22, 2026  
**Purpose:** Fix cloud database schema to match local development environment

## Problem

The cloud production database is missing admin panel tables, causing:
- `/admin/audit` endpoint to fail
- Chat UI issues (potentially)
- Database-related errors in cloud logs

**Root Cause:** Admin panel tables (`corpus_audit_log`, `corpus_metadata`, `corpus_sync_schedule`) were added to local database via migrations but never applied to cloud.

---

## Solution: 3-Step Process

### Step 1: Compare Schemas

**Check what's different between local and cloud databases:**

```bash
cd ~/github.com/xtreamgit/adk-multi-agents/backend

# Option A: Quick comparison (recommended)
./sync_database_schemas.sh compare

# Option B: Direct Python script
python3 compare_database_schemas.py
```

**Expected Output:**
```
❌ TABLES MISSING IN CLOUD:
   • corpus_audit_log
   • corpus_metadata
   • corpus_sync_schedule

⚠️  TABLE STRUCTURE DIFFERENCES:
  ...

📄 Report saved to: schema_comparison_report.json
```

### Step 2: Backup Cloud Database

**Always backup before migrations!**

```bash
# Automatic backup (included in migration script)
./sync_database_schemas.sh migrate

# OR manual backup
gcloud sql backups create \
  --instance=adk-multi-agents-db \
  --project=adk-rag-ma \
  --description="Pre-migration backup $(date +%Y%m%d)"
```

### Step 3: Apply Migration

**Apply the SQL migration to cloud database:**

```bash
# Option A: Automated (RECOMMENDED - includes backup + verification)
./sync_database_schemas.sh full

# Option B: Migration only (if already backed up)
./sync_database_schemas.sh migrate

# Option C: Manual application
gcloud sql connect adk-multi-agents-db \
  --database=adk_agents_db \
  --user=adk_app_user \
  --project=adk-rag-ma < migrations/fix_cloud_schema.sql
```

---

## Files Created

### 1. `compare_database_schemas.py`
**Purpose:** Python script to compare local and cloud PostgreSQL schemas

**Features:**
- Compares tables, columns, data types
- Checks indexes and foreign keys
- Generates detailed JSON report
- Color-coded terminal output

**Usage:**
```bash
# Set environment variables (optional, has defaults)
export DB_HOST=localhost
export DB_PORT=5433
export DB_NAME=adk_agents_db_dev
export DB_USER=adk_dev_user
export DB_PASSWORD=dev_password_123

# Run comparison
python3 compare_database_schemas.py
```

**Output:**
- Terminal: Color-coded comparison report
- File: `schema_comparison_report.json` (detailed JSON)

### 2. `migrations/fix_cloud_schema.sql`
**Purpose:** SQL migration to fix cloud database schema

**What it does:**
- Creates `corpus_audit_log` table (for admin audit logs)
- Creates `corpus_metadata` table (for corpus sync tracking)
- Creates `corpus_sync_schedule` table (for automated syncs)
- Adds missing columns to existing tables (if any)
- Creates all necessary indexes
- Initializes corpus_metadata for existing corpora

**Safe to run multiple times:** Uses `CREATE TABLE IF NOT EXISTS` and `DO $$ BEGIN ... END $$` blocks.

### 3. `sync_database_schemas.sh`
**Purpose:** Automated script for comparison, backup, and migration

**Commands:**
```bash
./sync_database_schemas.sh compare    # Check differences only
./sync_database_schemas.sh migrate    # Backup + migrate
./sync_database_schemas.sh full       # Compare + backup + migrate + verify
./sync_database_schemas.sh help       # Show usage
```

**Features:**
- Automatic prerequisite checks (gcloud, psql, Python)
- Cloud database backup before migration
- Schema verification after migration
- Color-coded output for easy reading
- Safety confirmations before destructive operations

---

## Verification Steps

### After Migration, Verify Tables Exist:

```bash
# Connect to cloud database
gcloud sql connect adk-multi-agents-db \
  --database=adk_agents_db \
  --user=adk_app_user \
  --project=adk-rag-ma
```

```sql
-- Check admin tables exist
\dt

-- Should see:
-- corpus_audit_log
-- corpus_metadata
-- corpus_sync_schedule

-- Check table structures
\d corpus_audit_log
\d corpus_metadata
\d corpus_sync_schedule

-- Test admin tables work
SELECT COUNT(*) FROM corpus_audit_log;
SELECT COUNT(*) FROM corpus_metadata;
SELECT COUNT(*) FROM corpus_sync_schedule;

-- Exit
\q
```

### Test Admin Panel Endpoint:

```bash
# Test audit endpoint (will need IAP authentication)
curl https://34.49.46.115.nip.io/admin/audit

# Or open in browser:
# https://34.49.46.115.nip.io/admin/audit
```

### Check Cloud Logs for Errors:

```bash
# Check for database-related errors
gcloud logging read 'severity>=ERROR resource.labels.service_name="backend" AND textPayload:"relation"' \
  --project=adk-rag-ma \
  --limit=20 \
  --format=json

# Should see no "relation does not exist" errors
```

---

## Troubleshooting

### Issue: Cannot connect to local database
**Solution:**
```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# If not running, start it
docker run -d \
  -p 5433:5432 \
  -e POSTGRES_DB=adk_agents_db_dev \
  -e POSTGRES_USER=adk_dev_user \
  -e POSTGRES_PASSWORD=dev_password_123 \
  postgres:15
```

### Issue: Cannot connect to cloud database
**Solution:**
```bash
# Option 1: Use Cloud Shell (recommended)
gcloud cloud-shell ssh

# Then run scripts from Cloud Shell

# Option 2: Use Cloud SQL Proxy locally
cloud-sql-proxy adk-rag-ma:us-west1:adk-multi-agents-db
```

### Issue: Permission denied on migration
**Solution:**
```bash
# Make scripts executable
chmod +x sync_database_schemas.sh
chmod +x compare_database_schemas.py
```

### Issue: Migration partially failed
**Solution:**
```bash
# Restore from backup
gcloud sql backups list --instance=adk-multi-agents-db --project=adk-rag-ma

# Restore specific backup
gcloud sql backups restore BACKUP_ID \
  --backup-instance=adk-multi-agents-db \
  --backup-project=adk-rag-ma

# Re-run migration
./sync_database_schemas.sh migrate
```

---

## Best Practices

### 1. Always Compare First
```bash
./sync_database_schemas.sh compare
```
Check what will change before applying migrations.

### 2. Use Full Automated Process
```bash
./sync_database_schemas.sh full
```
Includes comparison, backup, migration, and verification.

### 3. Review Migration SQL
Before running, review:
```bash
cat backend/migrations/fix_cloud_schema.sql
```

### 4. Test in Staging First
If you have a staging environment, test there first.

### 5. Monitor After Migration
```bash
# Watch logs for errors
gcloud logging tail "resource.labels.service_name=backend" \
  --project=adk-rag-ma
```

---

## Future: Prevent Schema Drift

### Recommendation: Use Database Migration Tool

**Option 1: Alembic (SQLAlchemy-based)**
```bash
# Install
pip install alembic

# Initialize
alembic init alembic

# Create migration
alembic revision --autogenerate -m "add admin tables"

# Apply to local
alembic upgrade head

# Apply to cloud
# (set cloud database URL)
alembic upgrade head
```

**Option 2: Manual Migration Tracking**
- Keep all migrations in `backend/migrations/` numbered sequentially
- Track applied migrations in a `schema_migrations` table
- Apply missing migrations during deployment

### Update Deployment Process

Add to CI/CD pipeline:
```yaml
- name: Check schema changes
  run: python3 compare_database_schemas.py
  
- name: Apply migrations if needed
  run: ./sync_database_schemas.sh migrate
```

---

## Summary

**Quick Fix (Right Now):**
```bash
cd ~/github.com/xtreamgit/adk-multi-agents/backend
./sync_database_schemas.sh full
```

**What it does:**
1. ✅ Compares local vs cloud schemas
2. ✅ Creates backup of cloud database
3. ✅ Applies missing admin tables to cloud
4. ✅ Verifies migration succeeded
5. ✅ Fixes `/admin/audit` endpoint

**Time to complete:** ~5 minutes

**Risk level:** LOW (automatic backup + idempotent migrations)

---

## Related Files

- **Schema Definition:** `backend/src/database/schema_init.py`
- **Existing Migrations:** `backend/src/database/migrations/`
- **Local Environment:** `backend/.env.local`
- **Cloud SQL Connection:** Use `gcloud sql connect`

## Next Steps After Migration

1. ✅ Test admin panel: https://34.49.46.115.nip.io/admin/audit
2. ✅ Test chat UI for any remaining issues
3. ✅ Check cloud logs for database errors
4. ✅ Update main schema file to include admin tables
5. ✅ Implement proper migration system (Alembic)
