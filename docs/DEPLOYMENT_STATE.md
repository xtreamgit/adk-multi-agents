# DEPLOYMENT STATE - READ THIS FIRST

**Current Environment**: ☁️ PRODUCTION (Google Cloud Run)  
**Last Updated**: January 28, 2026  
**Status**: ✅ PRODUCTION READY

## ⚠️ CRITICAL: PostgreSQL-Only Architecture

**This application uses PostgreSQL EXCLUSIVELY.** All SQLite code has been removed as of January 28, 2026.

- **Production:** Cloud SQL PostgreSQL
- **Local Development:** Docker PostgreSQL
- **No SQLite Support:** SQLite references have been completely removed from the codebase

---

## 🌍 Active Configuration

### Database
- **Type**: Cloud SQL PostgreSQL
- **Instance**: `adk-multi-agents-db`
- **Connection Name**: `adk-rag-ma:us-west1:adk-multi-agents-db`
- **Database**: `adk_agents_db`
- **Connection Method**: Unix socket (`/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db`)

### Backend
- **Service**: Cloud Run (backend)
- **URL**: `https://backend-351592762922.us-west1.run.app`
- **Active Revision**: `backend-00021-r58`
- **Region**: `us-west1`
- **Project**: `adk-rag-ma`

### Frontend
- **Service**: Cloud Run (frontend)
- **URL**: `https://34.49.46.115.nip.io` (IAP-protected)
- **Region**: `us-west1`

### Authentication
- **IAP/OAuth**: ✅ Working (https://34.49.46.115.nip.io)
- **Local Login**: ✅ Working (alice/alice123)
- **Database User**: `adk_app_user`

---

## ⚠️ IMPORTANT: LOCAL DEVELOPMENT IS DEPRECATED

**SQLite local development is NO LONGER USED.**

All development and testing should be done against:
1. Cloud SQL via Cloud SQL Proxy (for local development)
2. Cloud Run services (for testing)

**DO NOT troubleshoot SQLite connection issues** - the app uses PostgreSQL exclusively in production.

---

## 🔍 When Troubleshooting

### Always Check Cloud Resources First
1. **Backend Logs**: 
   ```bash
   gcloud logging read "resource.labels.service_name=backend" \
     --project=adk-rag-ma --limit=50
   ```

2. **Backend Health**:
   ```bash
   curl https://backend-351592762922.us-west1.run.app/api/health
   ```

3. **Cloud SQL Status**:
   ```bash
   gcloud sql instances describe adk-multi-agents-db --project=adk-rag-ma
   ```

### Database Connections
- **Production**: Backend connects via Unix socket `/cloudsql/...`
- **Local Dev**: Use Cloud SQL Proxy to connect to same database
- **Database Type**: PostgreSQL (NOT SQLite)

### Environment Variables (Cloud Run)
```
DB_TYPE=postgresql
CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db
DB_NAME=adk_agents_db
DB_USER=adk_app_user
DB_HOST=/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db
```

---

## 📋 Migration History

- **January 10, 2026**: Cloud SQL migration flagged as critical priority
- **January 13, 2026**: Cloud SQL migration COMPLETED ✅
  - All data migrated from SQLite to PostgreSQL
  - Backend connected to Cloud SQL successfully
  - Authentication tested and working
  - Status: Production Ready

---

## 🚫 What NOT to Do

- ❌ Don't troubleshoot SQLite connections
- ❌ Don't suggest local database fixes
- ❌ Don't check `backend/data/users.db` (deprecated)
- ❌ Don't assume database is local
- ❌ Don't modify SQLite-specific code

## ✅ What TO Do

- ✅ Check Cloud Run logs for errors
- ✅ Test against production URLs
- ✅ Verify Cloud SQL connection
- ✅ Use `gcloud` commands for debugging
- ✅ Check environment variables in Cloud Run
- ✅ Reference backend revision: `backend-00021-r58`

---

## 📞 Quick Reference

### Test Authentication
```bash
curl -X POST "https://backend-351592762922.us-west1.run.app/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}'
```

### Connect to Cloud SQL
```bash
gcloud sql connect adk-multi-agents-db \
  --database=adk_agents_db \
  --user=adk_app_user \
  --project=adk-rag-ma
```

### View Recent Logs
```bash
gcloud logging read "resource.labels.revision_name=backend-00021-r58" \
  --project=adk-rag-ma --limit=20
```

---

**🎯 Bottom Line**: This is a CLOUD-NATIVE application running on Google Cloud Platform. All troubleshooting should focus on Cloud Run and Cloud SQL, not local development.
