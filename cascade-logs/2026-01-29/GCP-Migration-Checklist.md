# GCP Migration Checklist: Moving to Another Google Cloud Account

**Created**: January 29, 2026  
**Source Project**: `adk-rag-ma` (us-west1)  
**Purpose**: Complete checklist for migrating the ADK Multi-Agents codebase to a new GCP project

---

## 📋 Overview of Current GCP Resources

| Resource | Current Value | Needs Migration |
|----------|---------------|-----------------|
| **Project ID** | `adk-rag-ma` | ✅ Yes - Update everywhere |
| **Region** | `us-west1` | ⚠️ Maybe (if client uses different region) |
| **Cloud SQL** | `adk-multi-agents-db` | ✅ Yes - Database + Data |
| **Cloud Run** | backend, frontend | ✅ Yes - Redeploy |
| **Artifact Registry** | `cloud-run-repo1` | ✅ Yes - Recreate |
| **Vertex AI RAG** | Corpora + Documents | ✅ Yes - Recreate |
| **GCS Buckets** | `ipad-book-collection`, `develom-documents` | ✅ Yes - Recreate + Upload |
| **Service Accounts** | 7 accounts | ✅ Yes - Recreate |
| **IAP/OAuth** | Configured | ✅ Yes - Reconfigure |
| **Secret Manager** | JWT, DB creds | ✅ Yes - Recreate |

---

## 🗄️ DATABASE MIGRATION OPTIONS

### Option A: Export/Import (Recommended)

```bash
# On SOURCE project - Export database
gcloud sql export sql adk-multi-agents-db gs://YOUR-BUCKET/db-export.sql \
  --database=adk_agents_db --project=adk-rag-ma

# On TARGET project - Create new instance
gcloud sql instances create NEW-INSTANCE-NAME \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=REGION \
  --project=NEW-PROJECT-ID

# Import data
gcloud sql import sql NEW-INSTANCE-NAME gs://YOUR-BUCKET/db-export.sql \
  --database=adk_agents_db --project=NEW-PROJECT-ID
```

### Option B: pg_dump/pg_restore (More Control)

```bash
# Export with pg_dump
pg_dump -h /cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db \
  -U adk_app_user -d adk_agents_db -F c -f backup.dump

# Restore to new database
pg_restore -h NEW-HOST -U NEW-USER -d adk_agents_db backup.dump
```

### Option C: Fresh Start (If data not needed)

- Run database migrations on new Cloud SQL instance
- Use `sync_corpora_from_vertex.py` to sync corpora after Vertex AI setup

---

## 📝 STEP-BY-STEP MIGRATION TASKS

### Phase 1: New GCP Project Setup

- [ ] Create new GCP project or get project ID from client
- [ ] Enable required APIs:

```bash
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  aiplatform.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  iap.googleapis.com \
  compute.googleapis.com
```

---

### Phase 2: Update Configuration Files

Files that contain hardcoded `adk-rag-ma` or GCP-specific values:

| File | What to Update |
|------|----------------|
| `backend/src/rag_agent/config.py` | `PROJECT_ID` default |
| `setup-secrets.sh` | `PROJECT_ID`, `REGION` |
| `setup-monitoring.sh` | `PROJECT_ID`, `REGION` |
| `infrastructure/deploy-config.sh` | All config values |
| `infrastructure/lib/*.sh` | Project references |
| `docs/DEPLOYMENT_STATE.md` | All URLs and references |

---

### Phase 3: Create Service Accounts

```bash
# Main service accounts needed:
gcloud iam service-accounts create backend-sa \
  --display-name="Backend Service Account"

gcloud iam service-accounts create frontend-sa \
  --display-name="Frontend Service Account"

gcloud iam service-accounts create adk-rag-agent-sa \
  --display-name="ADK RAG Agent Service Account"

gcloud iam service-accounts create iap-accessor \
  --display-name="IAP Accessor Service Account"

# Plus agent1, agent2, agent3 SAs if using multi-agent architecture
gcloud iam service-accounts create adk-rag-agent1-sa
gcloud iam service-accounts create adk-rag-agent2-sa
gcloud iam service-accounts create adk-rag-agent3-sa
```

---

### Phase 4: Set Up Cloud SQL

- [ ] Create Cloud SQL PostgreSQL instance
- [ ] Create database `adk_agents_db`
- [ ] Create user `adk_app_user`
- [ ] Import data (see Database Migration Options above)
- [ ] Grant Cloud SQL Client role to service accounts

```bash
# Create Cloud SQL instance
gcloud sql instances create adk-multi-agents-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=REGION \
  --project=NEW-PROJECT-ID

# Create database
gcloud sql databases create adk_agents_db \
  --instance=adk-multi-agents-db

# Create user
gcloud sql users create adk_app_user \
  --instance=adk-multi-agents-db \
  --password=SECURE_PASSWORD
```

---

### Phase 5: Set Up GCS Buckets

- [ ] Create buckets for document storage
- [ ] Upload documents
- [ ] Update `CORPUS_TO_BUCKET_MAPPING` in `config.py`
- [ ] Grant storage permissions to service accounts

```bash
# Create buckets
gcloud storage buckets create gs://YOUR-BUCKET-NAME --location=REGION

# Grant access
gcloud storage buckets add-iam-policy-binding gs://YOUR-BUCKET-NAME \
  --member="serviceAccount:adk-rag-agent-sa@PROJECT.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

---

### Phase 6: Set Up Vertex AI RAG

- [ ] Create RAG corpora via API or the app itself
- [ ] Upload/index documents to corpora
- [ ] Run `sync_corpora_from_vertex.py` to sync DB

**Note**: Vertex AI RAG corpora cannot be exported - they must be recreated in the new project.

```bash
# After creating corpora in new project, sync to database
cd backend
python sync_corpora_from_vertex.py
```

---

### Phase 7: Set Up Artifact Registry

```bash
gcloud artifacts repositories create cloud-run-repo1 \
  --repository-format=docker \
  --location=REGION \
  --description="Docker images for ADK RAG Agent"
```

---

### Phase 8: Build & Deploy

```bash
# Authenticate Docker with Artifact Registry
gcloud auth configure-docker REGION-docker.pkg.dev

# Build images
docker build -t REGION-docker.pkg.dev/PROJECT/REPO/backend:TAG ./backend
docker build -t REGION-docker.pkg.dev/PROJECT/REPO/frontend:TAG ./frontend

# Push to Artifact Registry
docker push REGION-docker.pkg.dev/PROJECT/REPO/backend:TAG
docker push REGION-docker.pkg.dev/PROJECT/REPO/frontend:TAG

# Deploy to Cloud Run
gcloud run deploy backend \
  --image=REGION-docker.pkg.dev/PROJECT/REPO/backend:TAG \
  --region=REGION \
  --service-account=adk-rag-agent-sa@PROJECT.iam.gserviceaccount.com \
  --set-env-vars="PROJECT_ID=NEW-PROJECT,GOOGLE_CLOUD_LOCATION=REGION,..."

gcloud run deploy frontend \
  --image=REGION-docker.pkg.dev/PROJECT/REPO/frontend:TAG \
  --region=REGION
```

---

### Phase 9: Configure IAP (if needed)

- [ ] Set up OAuth consent screen in Google Cloud Console
- [ ] Configure IAP for Cloud Run services
- [ ] Add authorized users/domains

```bash
# Enable IAP
gcloud iap oauth-brands create --application_title="ADK RAG Agent"

# Configure IAP for backend
gcloud iap web enable --resource-type=backend-services
```

---

### Phase 10: Set Up Secrets

```bash
# Create secrets
gcloud secrets create jwt-secret-key --project=NEW-PROJECT
gcloud secrets create database-url --project=NEW-PROJECT

# Add secret values
echo -n "YOUR_JWT_SECRET" | gcloud secrets versions add jwt-secret-key --data-file=-
echo -n "postgresql://..." | gcloud secrets versions add database-url --data-file=-

# Grant access to service accounts
gcloud secrets add-iam-policy-binding jwt-secret-key \
  --member="serviceAccount:adk-rag-agent-sa@PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## 🔧 RECOMMENDED APPROACH

### For a Clean Migration:

1. **Use the existing Terraform** in `/terraform/` folder - it can provision most resources
2. **Parameterize the project ID** - create a new `terraform.tfvars` for the client
3. **Export database** - use `gcloud sql export` for data migration
4. **Rebuild Vertex AI corpora** - these cannot be exported, must be recreated

### For the Database Specifically:

| Scenario | Approach |
|----------|----------|
| Client needs existing data | Use Option A (Export/Import) |
| Starting fresh | Run migrations, seed users, sync corpora |
| Development/Testing | Use Option C (Fresh Start) |

---

## 🔑 Environment Variables Reference

### Backend Cloud Run Service

```
PROJECT_ID=NEW-PROJECT-ID
GOOGLE_CLOUD_LOCATION=REGION
VERTEXAI_PROJECT=NEW-PROJECT-ID
VERTEXAI_LOCATION=REGION
DB_TYPE=postgresql
CLOUD_SQL_CONNECTION_NAME=PROJECT:REGION:INSTANCE
DB_NAME=adk_agents_db
DB_USER=adk_app_user
DB_HOST=/cloudsql/PROJECT:REGION:INSTANCE
SECRET_KEY=YOUR_SECRET_KEY
FRONTEND_URL=https://YOUR-FRONTEND-URL
```

### Frontend Cloud Run Service

```
NEXT_PUBLIC_BACKEND_URL=https://YOUR-BACKEND-URL
```

---

## ✅ Post-Migration Verification

- [ ] Backend health check: `curl https://BACKEND-URL/api/health`
- [ ] Frontend loads: `https://FRONTEND-URL`
- [ ] User login works
- [ ] Corpora list correctly
- [ ] Document upload/retrieval works
- [ ] RAG queries return results
- [ ] PDF thumbnails generate correctly

---

## 📁 Files to Update with New Project ID

Run this to find all hardcoded references:

```bash
grep -r "adk-rag-ma" --include="*.py" --include="*.sh" --include="*.md" --include="*.yaml" .
```

---

## 📞 Quick Reference Commands

### Test Authentication (New Project)
```bash
curl -X POST "https://NEW-BACKEND-URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### Connect to Cloud SQL
```bash
gcloud sql connect NEW-INSTANCE-NAME \
  --database=adk_agents_db \
  --user=adk_app_user \
  --project=NEW-PROJECT-ID
```

### View Cloud Run Logs
```bash
gcloud logging read "resource.labels.service_name=backend" \
  --project=NEW-PROJECT-ID --limit=50
```

---

**🎯 Bottom Line**: The migration involves recreating infrastructure, exporting/importing database, and rebuilding Vertex AI corpora. Use the deployment scripts in `/infrastructure/` as templates, updating the project-specific values.
