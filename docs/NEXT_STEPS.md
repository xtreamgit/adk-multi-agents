# Cloud SQL Migration - Next Steps

## Current Status Summary

### ✅ What's Working
- **Cloud SQL Instance**: `adk-multi-agents-db` is running with PostgreSQL
- **Database**: `adk_agents_db` contains all migrated data
- **Backend Code**: Updated with PostgreSQL support (connection wrappers, query conversion)
- **Backend Deployed**: Revision `backend-00021-r58` is live and handling traffic

### ❌ Current Issue
**Backend is still using SQLite instead of PostgreSQL**

Despite setting environment variables (`DB_TYPE=postgresql`), the backend revision `backend-00021-r58` was deployed with secret-based `DB_PASSWORD` configuration that prevents new deployments. The current revision is actually using SQLite, not PostgreSQL.

**Evidence:**
- Logs show: `INFO:root:Database initialized successfully at /app/data/users.db`
- This confirms SQLite is being used instead of PostgreSQL

### 🔧 Root Cause
The environment variable conflict with `DB_PASSWORD` (secret vs string) is preventing clean deployments. Revision `backend-00029-l6g` keeps failing because it tries to use the secret-based configuration that doesn't have proper IAM permissions.

## 🎯 Required Actions

### Option 1: Clean State Deployment (Recommended)

1. **Delete all existing revisions that aren't serving traffic:**
   ```bash
   # This will clear the broken configurations
   gcloud run services delete backend --region=us-west1 --project=adk-rag-ma
   ```

2. **Deploy fresh with correct configuration:**
   ```bash
   cd backend
   gcloud run deploy backend \
     --source . \
     --region=us-west1 \
     --platform=managed \
     --allow-unauthenticated \
     --set-env-vars="DB_TYPE=postgresql,CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db,DB_NAME=adk_agents_db,DB_USER=adk_app_user,DB_HOST=/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db,DB_PASSWORD=AkdDB2024!SecurePass" \
     --add-cloudsql-instances=adk-rag-ma:us-west1:adk-multi-agents-db \
     --project=adk-rag-ma
   ```

3. **Verify PostgreSQL connection:**
   ```bash
   # Should show PostgreSQL connection logs
   gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=backend" \
     --limit=50 --format='value(textPayload)' --project=adk-rag-ma --freshness=2m | grep -i postgresql
   ```

### Option 2: Fix Existing Service

1. **Remove secret-based DB_PASSWORD:**
   ```bash
   gcloud run services update backend \
     --region=us-west1 \
     --clear-secrets \
     --project=adk-rag-ma
   ```

2. **Set environment variables correctly:**
   ```bash
   gcloud run services update backend \
     --region=us-west1 \
     --set-env-vars="DB_TYPE=postgresql,DB_PASSWORD=AkdDB2024!SecurePass" \
     --project=adk-rag-ma
   ```

## 📋 Verification Steps

After successful deployment:

1. **Check environment variables:**
   ```bash
   curl -s "https://backend-351592762922.us-west1.run.app/api/health" | jq '.'
   ```

2. **Verify PostgreSQL connection in logs:**
   ```bash
   gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=backend" \
     --limit=100 --project=adk-rag-ma --freshness=2m | grep "PostgreSQL connection successful"
   ```

3. **Test authentication:**
   ```bash
   curl -X POST "https://backend-351592762922.us-west1.run.app/api/auth/login" \
     -H "Content-Type: application/json" \
     -d '{"username":"alice","password":"alice123"}' | jq '.'
   ```

## 🚨 Important Notes

- The password hash issue is SECONDARY - first we need to get the backend actually using PostgreSQL
- Once PostgreSQL is confirmed working, THEN we can address password hash mismatches
- The current backend-00021-r58 is using SQLite, so authentication "works" but data is ephemeral
- All data is safely stored in Cloud SQL, we just need to connect to it properly

## 📝 Files Created for Reference

- `backend/scripts/update_cloudsql_passwords.sql` - SQL to fix password hashes (for later)
- `backend/scripts/fix_cloudsql_passwords.py` - Generate fresh bcrypt hashes
- `MIGRATION_STATUS.md` - Full migration status document
- `CLOUD_SQL_PASSWORD_FIX.md` - Password fix instructions (for after PostgreSQL is connected)
