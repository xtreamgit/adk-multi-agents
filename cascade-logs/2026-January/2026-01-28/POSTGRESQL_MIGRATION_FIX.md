# PostgreSQL Migration Fix - January 28, 2026

## Critical Issue Discovered

The backend was incorrectly configured to use **SQLite** instead of **PostgreSQL** in Cloud Run deployment.

## Root Cause

1. **Missing `DB_TYPE` environment variable** - Backend defaulted to SQLite
2. **Missing Cloud SQL connection configuration** - No Cloud SQL instance attached
3. **Missing IAM permissions** - Service account lacked `roles/cloudsql.client`
4. **Port configuration error** - Unix socket connections should not specify port

## What Was Fixed

### 1. Environment Variables Added
```bash
DB_TYPE=postgresql
CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db
DB_NAME=adk_agents_db
DB_USER=adk_app_user
DB_HOST=/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db
```

### 2. Cloud SQL Instance Attached
```bash
--add-cloudsql-instances=adk-rag-ma:us-west1:adk-multi-agents-db
```

### 3. IAM Permissions Added
```bash
gcloud projects add-iam-policy-binding adk-rag-ma \
  --member="serviceAccount:adk-rag-agent-sa@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

### 4. Connection Code Fixed
**File**: `backend/src/database/connection.py`

**Problem**: Port was being specified for Unix socket connections
```python
PG_CONFIG = {
    'host': '/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db',
    'port': 5432,  # ❌ This causes "Connection refused" for Unix sockets
    ...
}
```

**Solution**: Only add port for TCP connections, not Unix sockets
```python
db_host = os.getenv('DB_HOST', '/cloudsql/' + os.getenv('CLOUD_SQL_CONNECTION_NAME', ''))
PG_CONFIG = {
    'host': db_host,
    'database': os.getenv('DB_NAME', 'adk_agents_db'),
    'user': os.getenv('DB_USER', 'adk_app_user'),
    'password': os.getenv('DB_PASSWORD', ''),
}

# Only add port if not using Unix socket (Cloud SQL)
if not db_host.startswith('/cloudsql/'):
    PG_CONFIG['port'] = int(os.getenv('DB_PORT', '5432'))
```

## Deployment Details

**Backend Revision**: `backend-00099-5hw`  
**Image**: `us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/backend:5128e02`  
**Commit**: `5128e02` - "Fix Cloud SQL connection: remove port for Unix socket"

## Verification

✅ PostgreSQL connection pool initialized successfully  
✅ Backend logs show: `INFO:database.connection:PostgreSQL connection pool initialized`  
✅ Database contains 8 users and 6 active corpora  
✅ No more SQLite-related errors

## Database Status

**Cloud SQL Instance**: `adk-multi-agents-db` (RUNNABLE)  
**Database**: `adk_agents_db`  
**Users**: 8 (admin, charlie, bob, testuser, andrew, etc.)  
**Corpora**: 6 active corpora

## Previous Incorrect Approach

The previous session incorrectly:
- ❌ Converted PostgreSQL `%s` placeholders to SQLite `?` placeholders
- ❌ Created SQLite-specific seed scripts
- ❌ Assumed ephemeral SQLite database in Cloud Run
- ❌ Tried to sync corpora on startup for SQLite

**Reality**: The system was always designed to use PostgreSQL via Cloud SQL. The database already had users and corpora from the January 13, 2026 migration.

## Access Information

**Frontend**: https://34.49.46.115.nip.io (IAP-protected)  
**Existing Users**: admin, charlie, bob, testuser, andrew  
**Database Type**: Cloud SQL PostgreSQL (NOT SQLite)

## Key Takeaway

Always check `DEPLOYMENT_STATE.md` before troubleshooting. The system uses **PostgreSQL** in both local (Docker) and cloud (Cloud SQL) environments. SQLite is deprecated and should not be used.
