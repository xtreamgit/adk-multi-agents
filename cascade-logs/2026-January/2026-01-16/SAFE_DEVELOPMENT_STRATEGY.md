# Safe Development Strategy - Document Retrieval Feature

**Date:** January 16, 2026  
**Concern:** Protect production database from new feature development

---

## Problem Statement

We need to develop the document retrieval feature without:
- Modifying the production Cloud SQL database
- Breaking the existing demo on main branch
- Corrupting production data

**Production Database:**
- Instance: `adk-multi-agents-db`
- Connection: `adk-rag-ma:us-west1:adk-multi-agents-db`
- Database: `adk_agents_db`
- Status: **MUST REMAIN UNTOUCHED**

---

## Recommended Solution: Separate Development Database

### Option 1: Create Development Cloud SQL Instance (RECOMMENDED) ⭐

**Benefits:**
- ✅ Complete isolation from production
- ✅ Test migrations safely
- ✅ Same PostgreSQL environment as production
- ✅ Can destroy/recreate as needed
- ✅ Minimal cost (~$10-15/month for small instance)

**Implementation Steps:**

#### 1. Create Development Database Instance
```bash
# Create a smaller/cheaper Cloud SQL instance for development
gcloud sql instances create adk-multi-agents-db-dev \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-west1 \
  --project=adk-rag-ma \
  --root-password=YOUR_DEV_PASSWORD

# Create the database
gcloud sql databases create adk_agents_db_dev \
  --instance=adk-multi-agents-db-dev \
  --project=adk-rag-ma

# Create app user
gcloud sql users create adk_dev_user \
  --instance=adk-multi-agents-db-dev \
  --password=YOUR_DEV_USER_PASSWORD \
  --project=adk-rag-ma
```

#### 2. Copy Production Schema to Development
```bash
# Export production schema (structure only, no data)
gcloud sql export sql adk-multi-agents-db \
  gs://adk-rag-ma-backups/prod-schema.sql \
  --database=adk_agents_db \
  --project=adk-rag-ma

# Import to development
gcloud sql import sql adk-multi-agents-db-dev \
  gs://adk-rag-ma-backups/prod-schema.sql \
  --database=adk_agents_db_dev \
  --project=adk-rag-ma
```

#### 3. Update Backend Environment Variables
Create separate environment configurations:

**`.env.production` (EXISTING - DO NOT CHANGE)**
```env
DB_TYPE=postgresql
CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db
DB_NAME=adk_agents_db
DB_USER=adk_app_user
DB_HOST=/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db
ENVIRONMENT=production
```

**`.env.development` (NEW)**
```env
DB_TYPE=postgresql
CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db-dev
DB_NAME=adk_agents_db_dev
DB_USER=adk_dev_user
DB_PASSWORD=YOUR_DEV_USER_PASSWORD
DB_HOST=/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db-dev
ENVIRONMENT=development
```

#### 4. Create Feature Branch
```bash
# Create feature branch for document retrieval
git checkout -b feature/document-retrieval

# All development happens here
# Main branch stays untouched
```

#### 5. Deploy to Separate Cloud Run Service
```bash
# Deploy backend to development service
gcloud run deploy backend-dev \
  --source=./backend \
  --region=us-west1 \
  --project=adk-rag-ma \
  --env-vars-file=.env.development \
  --allow-unauthenticated  # For testing only

# This creates: backend-dev (separate from production 'backend' service)
```

---

### Option 2: Local PostgreSQL with Docker (FASTER SETUP) 🐳

**Benefits:**
- ✅ Completely local, zero cloud costs
- ✅ Fast iteration and testing
- ✅ No risk to production
- ✅ Can reset anytime

**Implementation Steps:**

#### 1. Run PostgreSQL in Docker
```bash
# Create docker-compose.yml
cat > backend/docker-compose.dev.yml << 'EOF'
version: '3.8'

services:
  postgres-dev:
    image: postgres:15
    container_name: adk-postgres-dev
    environment:
      POSTGRES_DB: adk_agents_db_dev
      POSTGRES_USER: adk_dev_user
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5433:5432"  # Use 5433 to avoid conflicts
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
    networks:
      - adk-dev-network

volumes:
  postgres_dev_data:

networks:
  adk-dev-network:
    driver: bridge
EOF

# Start the database
docker-compose -f backend/docker-compose.dev.yml up -d
```

#### 2. Configure Local Development Environment
**`.env.local`**
```env
DB_TYPE=postgresql
DB_HOST=localhost
DB_PORT=5433
DB_NAME=adk_agents_db_dev
DB_USER=adk_dev_user
DB_PASSWORD=dev_password
ENVIRONMENT=local
```

#### 3. Initialize Local Database
```bash
cd backend

# Load environment
export $(cat .env.local | xargs)

# Run migrations
python src/database/migrations/run_migrations.py

# Seed with test data if needed
python init_db.py
```

#### 4. Run Backend Locally
```bash
cd backend
source .venv/bin/activate

# Use local environment
export $(cat .env.local | xargs)

# Start server
uvicorn src.api.server:app --reload --host 0.0.0.0 --port 8000
```

---

### Option 3: Database Branching (Cloud SQL Clone)

**Benefits:**
- ✅ Exact copy of production data
- ✅ Can test with real data
- ✅ Quick to create

**Steps:**
```bash
# Create a clone of production database
gcloud sql instances clone adk-multi-agents-db \
  adk-multi-agents-db-clone \
  --project=adk-rag-ma

# Use clone for development
# Point development environment to clone
```

---

## Recommended Workflow

### Phase 1: Setup (Choose One Approach Above)
- [ ] Create development database (Cloud SQL or Docker)
- [ ] Copy production schema to development
- [ ] Create `.env.development` or `.env.local`
- [ ] Create feature branch: `feature/document-retrieval`

### Phase 2: Development
- [ ] Apply new migration to **development database only**
- [ ] Test all new features in development
- [ ] Run integration tests
- [ ] Verify no breaking changes

### Phase 3: Testing
- [ ] Deploy to separate Cloud Run service (`backend-dev`)
- [ ] Test with development database
- [ ] Verify production remains untouched

### Phase 4: Production Deployment (When Ready)
- [ ] Get approval from stakeholders
- [ ] Backup production database
- [ ] Merge feature branch to main
- [ ] Apply migration to production (with rollback plan)
- [ ] Deploy to production Cloud Run service

---

## Git Branch Strategy

```
main (protected - production)
  ↓
feature/document-retrieval (development)
  ├── Apply migrations to dev DB
  ├── Implement features
  ├── Test thoroughly
  └── Merge to main when ready
```

**Commands:**
```bash
# Create feature branch
git checkout -b feature/document-retrieval

# Work on feature
git add backend/src/services/document_service.py
git commit -m "Add DocumentService for GCS signed URLs"

# Keep main untouched
# Only merge when ready for production
```

---

## Environment Variable Management

### Update `backend/src/database/connection.py`

Add environment detection:

```python
import os

# Detect environment
ENVIRONMENT = os.getenv('ENVIRONMENT', 'production')

# Configure based on environment
if ENVIRONMENT == 'development':
    # Use development database
    CLOUD_SQL_CONNECTION_NAME = os.getenv(
        'CLOUD_SQL_CONNECTION_NAME',
        'adk-rag-ma:us-west1:adk-multi-agents-db-dev'
    )
elif ENVIRONMENT == 'local':
    # Use local PostgreSQL
    PG_CONFIG = {
        'host': 'localhost',
        'port': 5433,
        'database': 'adk_agents_db_dev',
        'user': 'adk_dev_user',
        'password': os.getenv('DB_PASSWORD', 'dev_password'),
    }
else:
    # Production (default)
    CLOUD_SQL_CONNECTION_NAME = 'adk-rag-ma:us-west1:adk-multi-agents-db'
```

---

## Migration Safety Checks

### Add Migration Guard

Update `backend/src/database/migrations/run_migrations.py`:

```python
import os

def run_migrations():
    """Run database migrations with safety checks."""
    
    # Safety check: Prevent accidental production migration
    environment = os.getenv('ENVIRONMENT', 'production')
    
    if environment == 'production':
        confirm = input(
            "⚠️  WARNING: Running migrations on PRODUCTION database!\n"
            "   Are you sure? Type 'yes' to continue: "
        )
        if confirm.lower() != 'yes':
            print("❌ Migration cancelled.")
            return
    
    # ... rest of migration logic
```

---

## Cost Comparison

| Option | Setup Time | Monthly Cost | Isolation | Data Parity |
|--------|------------|--------------|-----------|-------------|
| Cloud SQL Dev | 15 min | $10-15 | Complete | Schema only |
| Docker Local | 5 min | $0 | Complete | None |
| Cloud SQL Clone | 10 min | $25-40 | Complete | Exact copy |

**Recommendation:** Start with **Docker Local** for speed, move to **Cloud SQL Dev** for final testing.

---

## Quick Start (Docker Local Approach)

```bash
# 1. Create feature branch
git checkout -b feature/document-retrieval

# 2. Start local PostgreSQL
cd backend
docker-compose -f docker-compose.dev.yml up -d

# 3. Configure environment
cat > .env.local << 'EOF'
DB_TYPE=postgresql
DB_HOST=localhost
DB_PORT=5433
DB_NAME=adk_agents_db_dev
DB_USER=adk_dev_user
DB_PASSWORD=dev_password
ENVIRONMENT=local
VERTEX_AI_LOCATION=us-west1
PROJECT_ID=adk-rag-ma
EOF

# 4. Initialize database
export $(cat .env.local | xargs)
python src/database/migrations/run_migrations.py

# 5. Apply new migration
python src/database/migrations/008_create_document_access_log.sql

# 6. Start backend
uvicorn src.api.server:app --reload --port 8000

# 7. Test new features
# Production remains completely untouched! ✅
```

---

## Rollback Plan

If something goes wrong in development:

### Docker Local
```bash
# Destroy and recreate
docker-compose -f docker-compose.dev.yml down -v
docker-compose -f docker-compose.dev.yml up -d
python src/database/migrations/run_migrations.py
```

### Cloud SQL Dev
```bash
# Delete and recreate instance
gcloud sql instances delete adk-multi-agents-db-dev --project=adk-rag-ma
# Then recreate from scratch
```

---

## Summary

**Recommended Approach:**
1. ✅ Use **Docker Local PostgreSQL** for development
2. ✅ Work in **feature branch** (`feature/document-retrieval`)
3. ✅ Keep **main branch and production database untouched**
4. ✅ Deploy to **separate Cloud Run service** for testing
5. ✅ Only merge to main when feature is production-ready

**Protection Guarantees:**
- ✅ Production database never touched during development
- ✅ Main branch remains stable for demos
- ✅ Can iterate and test freely in isolation
- ✅ Zero risk to existing functionality

---

## Next Steps

Choose your preferred approach:
- **Fast & Free**: Docker Local (recommended for now)
- **Cloud Parity**: Cloud SQL Dev instance
- **Real Data Testing**: Cloud SQL Clone

Once you decide, I'll help you set it up and continue with Phase 1 implementation safely!
