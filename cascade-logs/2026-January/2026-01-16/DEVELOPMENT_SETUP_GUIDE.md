# Development Setup Guide - Document Retrieval Feature

**Date:** January 16, 2026  
**Environment:** Docker Local PostgreSQL  
**Feature Branch:** `feature/document-retrieval`

---

## Quick Start (5 Minutes)

### Step 1: Create Feature Branch
```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents

# Create and switch to feature branch
git checkout -b feature/document-retrieval

# Verify you're on the feature branch
git branch
```

### Step 2: Start Local Database
```bash
cd backend

# Start PostgreSQL container
./scripts/start-dev-db.sh

# Expected output:
# ✅ PostgreSQL is ready!
# 📊 Database Info:
#    Host: localhost
#    Port: 5433
```

### Step 3: Configure Environment
```bash
# Load local environment variables
export $(cat .env.local | xargs)

# Verify configuration
echo $DB_HOST  # Should be: localhost
echo $DB_PORT  # Should be: 5433
echo $ENVIRONMENT  # Should be: local
```

### Step 4: Initialize Database
```bash
# Run all existing migrations
python src/database/migrations/run_migrations.py

# Expected output:
# ✅ Migration 001_initial_schema.sql applied
# ✅ Migration 002_add_groups.sql applied
# ...
# ✅ All migrations completed successfully
```

### Step 5: Apply New Migration (Document Access Log)
```bash
# Apply the document access log migration
psql "postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev" \
  -f src/database/migrations/008_create_document_access_log.sql

# Verify table was created
psql "postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev" \
  -c "\dt document_access_log"
```

### Step 6: Start Backend Server
```bash
# Make sure you're in backend directory
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend

# Activate virtual environment (if using one)
source .venv/bin/activate  # or however you activate your venv

# Load environment
export $(cat .env.local | xargs)

# Start server
uvicorn src.api.server:app --reload --host 0.0.0.0 --port 8000
```

### Step 7: Test New Endpoints
```bash
# In a new terminal, test the health endpoint
curl http://localhost:8000/api/health

# Test document retrieval endpoint (after authentication)
# First, login to get token
TOKEN=$(curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' | jq -r '.access_token')

# Test document retrieval
curl "http://localhost:8000/api/documents/retrieve?corpus_id=1&document_name=test.pdf" \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## Database Management

### View Database Tables
```bash
psql "postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev" \
  -c "\dt"
```

### View Document Access Logs
```bash
psql "postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev" \
  -c "SELECT * FROM document_access_log ORDER BY accessed_at DESC LIMIT 10;"
```

### Reset Database (Start Fresh)
```bash
# Stop and remove all data
cd backend
docker-compose -f docker-compose.dev.yml down -v

# Start again
./scripts/start-dev-db.sh

# Re-run migrations
export $(cat .env.local | xargs)
python src/database/migrations/run_migrations.py
```

### Backup Local Database
```bash
pg_dump "postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev" \
  > backup-local-$(date +%Y%m%d-%H%M%S).sql
```

---

## Development Workflow

### Daily Workflow
```bash
# 1. Start your day
cd /Users/hector/github.com/xtreamgit/adk-multi-agents/backend
./scripts/start-dev-db.sh

# 2. Load environment
export $(cat .env.local | xargs)

# 3. Start backend
uvicorn src.api.server:app --reload --port 8000

# 4. Make changes, test, commit
git add .
git commit -m "Add document retrieval feature"

# 5. End of day
./scripts/stop-dev-db.sh
```

### Testing New Features
```bash
# 1. Make code changes in your editor

# 2. Backend auto-reloads (thanks to --reload flag)

# 3. Test via curl or frontend

# 4. Check logs in terminal

# 5. Verify database changes
psql "postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev"
```

### Git Workflow
```bash
# Commit frequently
git add backend/src/services/document_service.py
git commit -m "Add DocumentService for GCS signed URLs"

# Push to remote (creates feature branch on GitHub)
git push origin feature/document-retrieval

# When ready for production
git checkout main
git merge feature/document-retrieval
git push origin main
```

---

## Production Migration (When Ready)

### Pre-Migration Checklist
- [ ] All features tested locally
- [ ] Integration tests passing
- [ ] Code reviewed and approved
- [ ] Migration script tested on local database
- [ ] Rollback plan documented
- [ ] Backup production database

### Migration Steps
```bash
# 1. Backup production database
gcloud sql export sql adk-multi-agents-db \
  gs://adk-rag-ma-backups/backup-before-migration-$(date +%Y%m%d-%H%M%S).sql \
  --database=adk_agents_db \
  --project=adk-rag-ma

# 2. Connect to production via Cloud SQL Proxy
cloud_sql_proxy -instances=adk-rag-ma:us-west1:adk-multi-agents-db=tcp:5432

# 3. Apply migration to production (in another terminal)
psql "postgresql://adk_app_user:PROD_PASSWORD@localhost:5432/adk_agents_db" \
  -f src/database/migrations/008_create_document_access_log.sql

# 4. Deploy backend to production
gcloud run deploy backend \
  --source=./backend \
  --region=us-west1 \
  --project=adk-rag-ma

# 5. Verify production
curl https://backend-351592762922.us-west1.run.app/api/health

# 6. Monitor logs
gcloud logging read "resource.labels.service_name=backend" \
  --project=adk-rag-ma --limit=50 --format=json
```

### Rollback (If Needed)
```bash
# 1. Restore database from backup
gcloud sql import sql adk-multi-agents-db \
  gs://adk-rag-ma-backups/backup-before-migration-TIMESTAMP.sql \
  --database=adk_agents_db \
  --project=adk-rag-ma

# 2. Revert to previous backend revision
gcloud run services update-traffic backend \
  --to-revisions=backend-00021-r58=100 \
  --region=us-west1 \
  --project=adk-rag-ma
```

---

## Troubleshooting

### Database Won't Start
```bash
# Check Docker is running
docker info

# Check container status
docker-compose -f docker-compose.dev.yml ps

# View logs
docker-compose -f docker-compose.dev.yml logs postgres-dev

# Force restart
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml up -d
```

### Can't Connect to Database
```bash
# Test connection
psql "postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev" \
  -c "SELECT version();"

# Check port is open
lsof -i :5433

# Verify environment variables
echo $DB_HOST
echo $DB_PORT
```

### Migration Fails
```bash
# Check migration table
psql "postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev" \
  -c "SELECT * FROM migrations;"

# Manually apply migration
psql "postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev" \
  -f src/database/migrations/008_create_document_access_log.sql

# Check for errors
tail -f /var/log/postgresql/postgresql-15-main.log
```

---

## Environment Files Reference

### .env.local (Development)
```env
DB_TYPE=postgresql
DB_HOST=localhost
DB_PORT=5433
DB_NAME=adk_agents_db_dev
DB_USER=adk_dev_user
DB_PASSWORD=dev_password_123
ENVIRONMENT=local
```

### .env.production (Cloud Run)
```env
DB_TYPE=postgresql
CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db
DB_NAME=adk_agents_db
DB_USER=adk_app_user
DB_HOST=/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db
ENVIRONMENT=production
```

---

## Phase 1 Implementation Status

### ✅ Completed
- [x] Database migration created (`008_create_document_access_log.sql`)
- [x] DocumentService implemented
- [x] retrieve_document agent tool created
- [x] API endpoints implemented (`/api/documents/*`)
- [x] Tools and routes registered
- [x] Docker development environment configured

### ⏳ In Progress
- [ ] Initialize local database
- [ ] Test document retrieval flow
- [ ] Verify audit logging

### 📋 Todo
- [ ] Frontend DocumentViewer component
- [ ] API client integration
- [ ] Chat interface updates
- [ ] Production deployment

---

## Summary

**Development Environment:** ✅ Ready  
**Database:** Docker PostgreSQL on localhost:5433  
**Branch:** feature/document-retrieval  
**Production:** Completely isolated and safe ✅

**Next:** Run through Quick Start steps above to get your local environment running!
