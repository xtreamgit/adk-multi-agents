# Cloud SQL Migration Plan
**Date**: January 13, 2026  
**Objective**: Migrate from ephemeral SQLite to persistent Cloud SQL PostgreSQL  
**Target Instance**: `adk-multi-agents-db` (existing Cloud SQL instance)

---

## Migration Overview

### Current State
- **Database**: SQLite (`./data/users.db`)
- **Location**: Local filesystem / Cloud Run ephemeral storage
- **Data Loss**: Every container restart/redeployment
- **Current Data**:
  - 6 users (admin, alice, bob, charlie, testuser, andrew)
  - 6 groups (default-users, admin-users, develom-group, developers, managers, viewers)
  - 9 corpora (5 active, 4 inactive)

### Target State
- **Database**: PostgreSQL on Cloud SQL
- **Instance**: `adk-multi-agents-db` (adk-rag-ma:us-west1:adk-multi-agents-db)
- **Location**: Google Cloud SQL (us-west1)
- **Benefits**: Persistent storage, shared across all Cloud Run instances, automated backups

---

## Pre-Migration Checklist

### 1. Cloud SQL Instance Verification
```bash
# Verify Cloud SQL instance exists and is running
gcloud sql instances describe adk-multi-agents-db \
  --project=adk-rag-ma

# Check instance status
gcloud sql instances list --project=adk-rag-ma --filter="name:adk-multi-agents-db"

# Get connection name
gcloud sql instances describe adk-multi-agents-db \
  --project=adk-rag-ma \
  --format="value(connectionName)"
```

**Expected Output**: 
- Status: RUNNABLE
- Connection Name: `adk-rag-ma:us-west1:adk-multi-agents-db`

### 2. Database Credentials Verification
```bash
# Verify database user exists
gcloud sql users list \
  --instance=adk-multi-agents-db \
  --project=adk-rag-ma

# If needed, create user
gcloud sql users create adk_app_user \
  --instance=adk-multi-agents-db \
  --password=<SECURE_PASSWORD> \
  --project=adk-rag-ma
```

### 3. Local SQLite Backup
```bash
# Create timestamped backup of current SQLite database
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend
cp data/users.db data/users_backup_$(date +%Y%m%d_%H%M%S).db

# Verify backup
ls -lh data/users_backup_*.db
```

---

## Phase 1: Data Export from SQLite

### Step 1.1: Export Schema
Create script: `backend/scripts/export_sqlite_schema.py`

```python
#!/usr/bin/env python3
"""Export SQLite schema to PostgreSQL-compatible SQL."""
import sqlite3
import os

DB_PATH = './data/users.db'
OUTPUT_PATH = './scripts/exported_schema.sql'

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

# Get all table schemas
cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
tables = cursor.fetchall()

with open(OUTPUT_PATH, 'w') as f:
    f.write("-- Exported from SQLite\n")
    f.write("-- Convert to PostgreSQL syntax\n\n")
    for table in tables:
        f.write(table[0] + ";\n\n")

conn.close()
print(f"✅ Schema exported to {OUTPUT_PATH}")
```

**Execute**:
```bash
cd backend
python scripts/export_sqlite_schema.py
```

**Verification**: Check `scripts/exported_schema.sql` contains all table definitions

### Step 1.2: Export Data
Create script: `backend/scripts/export_sqlite_data.py`

```python
#!/usr/bin/env python3
"""Export all data from SQLite to JSON for migration."""
import sqlite3
import json
from datetime import datetime

DB_PATH = './data/users.db'
OUTPUT_PATH = './scripts/exported_data.json'

def export_table(cursor, table_name):
    """Export all rows from a table."""
    cursor.execute(f"SELECT * FROM {table_name}")
    columns = [description[0] for description in cursor.description]
    rows = cursor.fetchall()
    
    return {
        'columns': columns,
        'rows': [dict(zip(columns, row)) for row in rows]
    }

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

# Get all table names
cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
tables = [row[0] for row in cursor.fetchall()]

export_data = {
    'export_timestamp': datetime.utcnow().isoformat(),
    'source_database': 'SQLite',
    'tables': {}
}

for table_name in tables:
    print(f"Exporting {table_name}...")
    export_data['tables'][table_name] = export_table(cursor, table_name)
    row_count = len(export_data['tables'][table_name]['rows'])
    print(f"  ✅ {row_count} rows exported")

with open(OUTPUT_PATH, 'w') as f:
    json.dump(export_data, f, indent=2, default=str)

conn.close()

# Summary
print(f"\n✅ Data exported to {OUTPUT_PATH}")
print("\nSummary:")
for table, data in export_data['tables'].items():
    print(f"  {table}: {len(data['rows'])} rows")
```

**Execute**:
```bash
cd backend
python scripts/export_sqlite_data.py
```

**Verification**: 
- Check `scripts/exported_data.json` exists
- Verify row counts match SQLite database
- Manually inspect critical data (users, groups, corpora)

---

## Phase 2: Cloud SQL Database Preparation

### Step 2.1: Connect to Cloud SQL
```bash
# Install Cloud SQL Proxy (if not already installed)
# Download from: https://cloud.google.com/sql/docs/postgres/connect-admin-proxy

# Start Cloud SQL Proxy
cloud_sql_proxy -instances=adk-rag-ma:us-west1:adk-multi-agents-db=tcp:5432 &

# Test connection
psql "host=127.0.0.1 port=5432 sslmode=disable user=adk_app_user dbname=adk_agents_db"
```

**Verification**: Should connect successfully without errors

### Step 2.2: Drop and Recreate Database
```bash
# Connect as postgres user (admin)
gcloud sql connect adk-multi-agents-db --user=postgres --project=adk-rag-ma

# In psql prompt:
DROP DATABASE IF EXISTS adk_agents_db;
CREATE DATABASE adk_agents_db OWNER adk_app_user;
\q
```

**Verification**: Database created fresh, no existing tables

### Step 2.3: Run Migration Scripts
```bash
# Connect to new database
psql "host=127.0.0.1 port=5432 sslmode=disable user=adk_app_user dbname=adk_agents_db"

# Run all migrations in order
\i backend/src/database/migrations/001_initial_schema.sql
\i backend/src/database/migrations/002_add_groups_roles.sql
\i backend/src/database/migrations/003_add_corpora.sql
\i backend/src/database/migrations/004_add_message_count.sql
\i backend/src/database/migrations/005_add_corpus_agent_mapping.sql

# Verify tables created
\dt
\q
```

**Verification**: All tables exist with correct schema

---

## Phase 3: Data Import to Cloud SQL

### Step 3.1: Create Import Script
Create script: `backend/scripts/import_to_cloudsql.py`

```python
#!/usr/bin/env python3
"""Import data from JSON export to Cloud SQL PostgreSQL."""
import json
import psycopg2
from psycopg2.extras import execute_values
import os

# Configuration
EXPORT_FILE = './scripts/exported_data.json'
DB_CONFIG = {
    'host': '127.0.0.1',  # Cloud SQL Proxy
    'port': 5432,
    'database': 'adk_agents_db',
    'user': 'adk_app_user',
    'password': os.environ.get('DB_PASSWORD'),
}

# Table import order (respects foreign key constraints)
IMPORT_ORDER = [
    'users',
    'user_profiles',
    'groups',
    'roles',
    'user_groups',
    'group_roles',
    'corpora',
    'corpus_groups',
    'corpus_agent_mapping',
    'sessions',
    'chat_history',
    'user_queries',
    'audit_logs',
]

def import_table(cursor, table_name, data):
    """Import data into a single table."""
    if not data['rows']:
        print(f"  ⚠️  No data to import for {table_name}")
        return 0
    
    columns = data['columns']
    rows = [tuple(row[col] for col in columns) for row in data['rows']]
    
    # Build INSERT statement
    placeholders = ', '.join(['%s'] * len(columns))
    cols = ', '.join([f'"{col}"' for col in columns])
    query = f'INSERT INTO {table_name} ({cols}) VALUES ({placeholders})'
    
    # Import data
    cursor.executemany(query, rows)
    return len(rows)

# Load exported data
print("📂 Loading exported data...")
with open(EXPORT_FILE, 'r') as f:
    export_data = json.load(f)

print(f"✅ Loaded data from {export_data['export_timestamp']}")

# Connect to Cloud SQL
print("\n🔌 Connecting to Cloud SQL...")
conn = psycopg2.connect(**DB_CONFIG)
cursor = conn.cursor()
print("✅ Connected to Cloud SQL")

# Import tables in order
print("\n📥 Importing data...")
imported_counts = {}

try:
    for table_name in IMPORT_ORDER:
        if table_name not in export_data['tables']:
            print(f"  ⚠️  Table {table_name} not in export")
            continue
        
        print(f"  Importing {table_name}...")
        count = import_table(cursor, table_name, export_data['tables'][table_name])
        imported_counts[table_name] = count
        print(f"    ✅ {count} rows imported")
    
    # Commit transaction
    conn.commit()
    print("\n✅ All data imported successfully")
    
except Exception as e:
    conn.rollback()
    print(f"\n❌ Import failed: {e}")
    raise
finally:
    cursor.close()
    conn.close()

# Summary
print("\n📊 Import Summary:")
for table, count in imported_counts.items():
    print(f"  {table}: {count} rows")
```

**Execute**:
```bash
# Set database password
export DB_PASSWORD=<YOUR_SECURE_PASSWORD>

# Run import
cd backend
python scripts/import_to_cloudsql.py
```

**Verification**: Check output for successful import of all tables

### Step 3.2: Verify Data Integrity
Create script: `backend/scripts/verify_migration.py`

```python
#!/usr/bin/env python3
"""Verify data migration from SQLite to Cloud SQL."""
import sqlite3
import psycopg2
import json
import os

SQLITE_DB = './data/users.db'
PG_CONFIG = {
    'host': '127.0.0.1',
    'port': 5432,
    'database': 'adk_agents_db',
    'user': 'adk_app_user',
    'password': os.environ.get('DB_PASSWORD'),
}

TABLES_TO_VERIFY = [
    'users',
    'groups',
    'corpora',
    'user_groups',
    'sessions',
    'chat_history',
]

def get_row_count(cursor, table):
    """Get row count for a table."""
    cursor.execute(f"SELECT COUNT(*) FROM {table}")
    return cursor.fetchone()[0]

def get_sample_data(cursor, table, limit=5):
    """Get sample rows from table."""
    cursor.execute(f"SELECT * FROM {table} LIMIT {limit}")
    return cursor.fetchall()

print("🔍 Verifying Migration...")
print("=" * 60)

# Connect to both databases
sqlite_conn = sqlite3.connect(SQLITE_DB)
pg_conn = psycopg2.connect(**PG_CONFIG)

sqlite_cursor = sqlite_conn.cursor()
pg_cursor = pg_conn.cursor()

verification_results = []
all_passed = True

for table in TABLES_TO_VERIFY:
    print(f"\n📋 Verifying {table}:")
    
    # Get row counts
    try:
        sqlite_count = get_row_count(sqlite_cursor, table)
        pg_count = get_row_count(pg_cursor, table)
        
        match = "✅" if sqlite_count == pg_count else "❌"
        print(f"  SQLite: {sqlite_count} rows")
        print(f"  PostgreSQL: {pg_count} rows")
        print(f"  {match} Row counts match: {sqlite_count == pg_count}")
        
        if sqlite_count != pg_count:
            all_passed = False
            
        verification_results.append({
            'table': table,
            'sqlite_count': sqlite_count,
            'pg_count': pg_count,
            'match': sqlite_count == pg_count
        })
        
    except Exception as e:
        print(f"  ❌ Error verifying {table}: {e}")
        all_passed = False
        verification_results.append({
            'table': table,
            'error': str(e),
            'match': False
        })

# Close connections
sqlite_cursor.close()
sqlite_conn.close()
pg_cursor.close()
pg_conn.close()

# Final summary
print("\n" + "=" * 60)
print("📊 Migration Verification Summary:")
print("=" * 60)

for result in verification_results:
    status = "✅" if result.get('match', False) else "❌"
    if 'error' in result:
        print(f"{status} {result['table']}: ERROR - {result['error']}")
    else:
        print(f"{status} {result['table']}: {result['sqlite_count']} → {result['pg_count']}")

print("=" * 60)
if all_passed:
    print("✅ MIGRATION SUCCESSFUL - All data verified")
else:
    print("❌ MIGRATION ISSUES DETECTED - Review errors above")

# Save verification report
report_path = './scripts/migration_verification_report.json'
with open(report_path, 'w') as f:
    json.dump({
        'verification_date': __import__('datetime').datetime.utcnow().isoformat(),
        'results': verification_results,
        'all_passed': all_passed
    }, f, indent=2)

print(f"\n📄 Report saved to: {report_path}")
```

**Execute**:
```bash
cd backend
python scripts/verify_migration.py
```

**Verification**: All row counts should match between SQLite and PostgreSQL

---

## Phase 4: Backend Configuration Update

### Step 4.1: Update Connection Configuration
File: `backend/src/database/connection.py`

Add PostgreSQL support while maintaining SQLite fallback:

```python
import os
import psycopg2
from psycopg2.pool import SimpleConnectionPool
from contextlib import contextmanager

# Database type from environment
DB_TYPE = os.environ.get('DB_TYPE', 'sqlite')  # 'sqlite' or 'postgresql'

# PostgreSQL configuration
PG_CONFIG = {
    'host': '/cloudsql/' + os.environ.get('CLOUD_SQL_CONNECTION_NAME', ''),  # Unix socket
    'database': os.environ.get('DB_NAME', 'adk_agents_db'),
    'user': os.environ.get('DB_USER', 'adk_app_user'),
    'password': os.environ.get('DB_PASSWORD', ''),
}

# Connection pool for PostgreSQL
pg_pool = None

def init_database():
    """Initialize database based on DB_TYPE."""
    global pg_pool
    
    if DB_TYPE == 'postgresql':
        print("🔌 Connecting to PostgreSQL (Cloud SQL)...")
        pg_pool = SimpleConnectionPool(
            minconn=1,
            maxconn=10,
            **PG_CONFIG
        )
        print("✅ PostgreSQL connection pool initialized")
        
        # Run migrations
        run_migrations_pg()
        
    else:
        print("🔌 Using SQLite database...")
        # Existing SQLite initialization
        init_database_sqlite()

@contextmanager
def get_db_connection():
    """Get database connection based on DB_TYPE."""
    if DB_TYPE == 'postgresql':
        conn = pg_pool.getconn()
        try:
            yield conn
        finally:
            pg_pool.putconn(conn)
    else:
        # Existing SQLite connection logic
        yield get_sqlite_connection()
```

### Step 4.2: Update Repository Classes
Update all repository classes to handle both SQLite and PostgreSQL:

**Key Changes**:
- Use parameterized queries compatible with both databases
- Handle different placeholder syntax (? for SQLite, %s for PostgreSQL)
- Handle different RETURNING clause behavior
- Handle different auto-increment ID retrieval

Example for UserRepository:

```python
def create_user(username, email, full_name, hashed_password):
    """Create new user - compatible with SQLite and PostgreSQL."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        if DB_TYPE == 'postgresql':
            cursor.execute("""
                INSERT INTO users (username, email, full_name, hashed_password)
                VALUES (%s, %s, %s, %s)
                RETURNING id
            """, (username, email, full_name, hashed_password))
            user_id = cursor.fetchone()[0]
        else:
            cursor.execute("""
                INSERT INTO users (username, email, full_name, hashed_password)
                VALUES (?, ?, ?, ?)
            """, (username, email, full_name, hashed_password))
            user_id = cursor.lastrowid
        
        conn.commit()
        return user_id
```

### Step 4.3: Test Database Connection
Create test script: `backend/scripts/test_cloudsql_connection.py`

```python
#!/usr/bin/env python3
"""Test Cloud SQL connection."""
import os
os.environ['DB_TYPE'] = 'postgresql'
os.environ['CLOUD_SQL_CONNECTION_NAME'] = 'adk-rag-ma:us-west1:adk-multi-agents-db'
os.environ['DB_NAME'] = 'adk_agents_db'
os.environ['DB_USER'] = 'adk_app_user'
os.environ['DB_PASSWORD'] = os.environ.get('DB_PASSWORD', '')

from database.connection import init_database, get_db_connection

print("Testing Cloud SQL connection...")

init_database()

with get_db_connection() as conn:
    cursor = conn.cursor()
    
    # Test query
    cursor.execute("SELECT COUNT(*) FROM users")
    count = cursor.fetchone()[0]
    print(f"✅ Successfully connected to Cloud SQL")
    print(f"   Users in database: {count}")
    
    # Test each table
    tables = ['users', 'groups', 'corpora', 'sessions']
    for table in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        print(f"   {table}: {count} rows")

print("\n✅ Cloud SQL connection test passed")
```

**Execute**:
```bash
export DB_PASSWORD=<YOUR_SECURE_PASSWORD>
cd backend
python scripts/test_cloudsql_connection.py
```

**Verification**: Should connect and display row counts matching migrated data

---

## Phase 5: Deployment

### Step 5.1: Update Backend Environment Variables
```bash
# Set Cloud Run environment variables for backend
gcloud run services update backend \
  --region=us-west1 \
  --set-env-vars="DB_TYPE=postgresql" \
  --set-env-vars="CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db" \
  --set-env-vars="DB_NAME=adk_agents_db" \
  --set-env-vars="DB_USER=adk_app_user" \
  --set-env-vars="DB_PASSWORD=<SECURE_PASSWORD>" \
  --add-cloudsql-instances=adk-rag-ma:us-west1:adk-multi-agents-db \
  --project=adk-rag-ma
```

### Step 5.2: Deploy Backend
```bash
cd backend
gcloud run deploy backend \
  --source . \
  --region us-west1 \
  --platform managed \
  --allow-unauthenticated \
  --project=adk-rag-ma
```

### Step 5.3: Verify Deployment
```bash
# Check backend logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=backend" \
  --limit 20 \
  --format=json \
  --project=adk-rag-ma | jq -r '.[] | .textPayload'

# Test health endpoint
curl https://backend-351592762922.us-west1.run.app/api/health

# Test user endpoint
curl https://34.49.46.115.nip.io/api/users/me
```

**Verification**: 
- Backend starts without database connection errors
- Health endpoint returns success
- User data from Cloud SQL is accessible

---

## Phase 6: Post-Migration Verification

### Step 6.1: Functional Testing
1. **User Registration**: Register a new test user
2. **User Login**: Login with migrated user credentials
3. **Admin Panel**: Access /admin and verify all pages load
4. **Groups**: Verify group membership and admin access
5. **Corpora**: Verify corpus list matches migrated data
6. **Chat**: Submit a query and verify session creation
7. **Sessions**: Check session history shows correctly

### Step 6.2: Data Integrity Checks
```bash
# Check specific user data
psql "host=127.0.0.1 port=5432 sslmode=disable user=adk_app_user dbname=adk_agents_db" \
  -c "SELECT id, username, email FROM users ORDER BY id;"

# Check group memberships
psql "host=127.0.0.1 port=5432 sslmode=disable user=adk_app_user dbname=adk_agents_db" \
  -c "SELECT u.username, g.name FROM users u JOIN user_groups ug ON u.id = ug.user_id JOIN groups g ON ug.group_id = g.id ORDER BY u.username;"

# Check active corpora
psql "host=127.0.0.1 port=5432 sslmode=disable user=adk_app_user dbname=adk_agents_db" \
  -c "SELECT name, vertex_corpus_id, is_active FROM corpora WHERE is_active = true ORDER BY name;"
```

### Step 6.3: Performance Testing
Monitor initial performance metrics:
- Database query response times
- Connection pool utilization
- Memory usage
- Error rates

---

## Phase 7: Cleanup

### Step 7.1: Archive SQLite Data
```bash
# Archive local SQLite database
cd backend/data
mkdir -p archive
mv users.db archive/users_pre_migration_$(date +%Y%m%d).db
mv users_backup_*.db archive/

# Create README
cat > archive/README.md << EOF
# SQLite Database Archive

These databases were archived after successful migration to Cloud SQL PostgreSQL.

Migration Date: $(date)
Migrated to: adk-rag-ma:us-west1:adk-multi-agents-db

Files:
- users_pre_migration_*.db: Final SQLite database before migration
- users_backup_*.db: Backup copies created during migration process

These files can be safely deleted after confirming Cloud SQL migration success.
EOF

echo "✅ SQLite databases archived to backend/data/archive/"
```

### Step 7.2: Remove SQLite Dependencies (Optional)
After confirming Cloud SQL works for at least 1 week:

```python
# backend/requirements.txt
# Remove or comment out if no longer needed:
# sqlite3  # Now using PostgreSQL via psycopg2
```

---

## Rollback Plan

If migration fails or issues are detected:

### Immediate Rollback
```bash
# Revert backend environment variables to SQLite
gcloud run services update backend \
  --region=us-west1 \
  --remove-env-vars="DB_TYPE,CLOUD_SQL_CONNECTION_NAME,DB_NAME,DB_USER,DB_PASSWORD" \
  --remove-cloudsql-instances=adk-rag-ma:us-west1:adk-multi-agents-db \
  --project=adk-rag-ma

# Redeploy backend (will use SQLite by default)
cd backend
gcloud run deploy backend \
  --source . \
  --region us-west1 \
  --platform managed \
  --allow-unauthenticated \
  --project=adk-rag-ma
```

### Restore SQLite Data
```bash
# Restore from backup
cd backend/data
cp archive/users_pre_migration_*.db users.db
```

---

## Testing Checkpoints

Throughout migration, test database connectivity:

### Checkpoint 1: After Data Export
```bash
cd backend
python scripts/export_sqlite_data.py
# ✅ Verify: exported_data.json contains all expected data
```

### Checkpoint 2: After Cloud SQL Schema Creation
```bash
psql "host=127.0.0.1 port=5432 user=adk_app_user dbname=adk_agents_db"
\dt
# ✅ Verify: All tables exist
```

### Checkpoint 3: After Data Import
```bash
python scripts/verify_migration.py
# ✅ Verify: All row counts match
```

### Checkpoint 4: After Backend Update
```bash
python scripts/test_cloudsql_connection.py
# ✅ Verify: Backend can connect to Cloud SQL
```

### Checkpoint 5: After Deployment
```bash
curl https://34.49.46.115.nip.io/api/health
# ✅ Verify: Health check passes with Cloud SQL
```

---

## Success Criteria

Migration is considered successful when:

- ✅ All data transferred (users, groups, corpora, sessions)
- ✅ Row counts match between SQLite and PostgreSQL
- ✅ Backend connects to Cloud SQL without errors
- ✅ All admin pages load correctly
- ✅ User authentication works
- ✅ New data can be created and retrieved
- ✅ No database connection errors in logs
- ✅ Performance is acceptable (< 100ms query times)
- ✅ Data persists across backend redeployments

---

## Timeline Estimate

- **Phase 1** (Data Export): 30 minutes
- **Phase 2** (Cloud SQL Prep): 30 minutes
- **Phase 3** (Data Import): 1 hour
- **Phase 4** (Backend Update): 2 hours
- **Phase 5** (Deployment): 30 minutes
- **Phase 6** (Verification): 1 hour
- **Phase 7** (Cleanup): 30 minutes

**Total Estimated Time**: 6 hours

---

## Support Information

### Connection Troubleshooting
If connection issues occur:

```bash
# Test Cloud SQL Proxy
cloud_sql_proxy -instances=adk-rag-ma:us-west1:adk-multi-agents-db=tcp:5432

# Test with psql
psql "host=127.0.0.1 port=5432 user=adk_app_user dbname=adk_agents_db"

# Check Cloud SQL logs
gcloud sql operations list \
  --instance=adk-multi-agents-db \
  --project=adk-rag-ma
```

### Data Issues
If data is missing or incorrect:

```bash
# Re-run import script
cd backend
python scripts/import_to_cloudsql.py

# Check specific table
psql -c "SELECT * FROM users LIMIT 10;"
```

---

## Next Steps After Migration

1. **Monitor Performance**: Watch database metrics for first 24 hours
2. **Enable Backups**: Configure automated Cloud SQL backups
3. **Set Up Alerts**: Create alerts for connection failures
4. **Document Changes**: Update deployment documentation
5. **Train Team**: Ensure team knows how to access Cloud SQL
6. **Test Disaster Recovery**: Verify backup restoration process

---

*End of Migration Plan*
