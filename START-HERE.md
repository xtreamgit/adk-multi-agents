# START HERE — New Client Deployment Guide

Complete step-by-step instructions for deploying the ADK RAG Multi-Agent application to a **new client's Google Cloud environment** after cloning the repository.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Gather Client Information](#2-gather-client-information)
3. [Create the Environment YAML](#3-create-the-environment-yaml)
4. [Generate Configuration Files](#4-generate-configuration-files)
5. [Register the New Account in the Config Loader](#5-register-the-new-account-in-the-config-loader)
6. [Create the Agent Instructions](#6-create-the-agent-instructions)
7. [Generate the Secret Key](#7-generate-the-secret-key)
8. [Create the Frontend Environment File](#8-create-the-frontend-environment-file)
9. [Initialize the GCP Project](#9-initialize-the-gcp-project)
10. [Create GCS Buckets for Corpora](#10-create-gcs-buckets-for-corpora)
11. [Create Vertex AI Corpora and Upload Documents](#11-create-vertex-ai-corpora-and-upload-documents)
12. [Create and Seed the Database](#12-create-and-seed-the-database)
13. [Deploy to Cloud Run](#13-deploy-to-cloud-run)
14. [Verify the Deployment](#14-verify-the-deployment)
15. [Set Up Local Development](#15-set-up-local-development)
16. [File Reference](#16-file-reference)
17. [Troubleshooting](#17-troubleshooting)

---

## 1. Prerequisites

Install these tools on your workstation before starting:

| Tool | Version | Install |
|------|---------|---------|
| **Google Cloud SDK** (`gcloud`) | Latest | https://cloud.google.com/sdk/docs/install |
| **Cloud SQL Proxy** | v2+ | `gcloud components install cloud-sql-proxy` |
| **Python** | 3.12+ | https://www.python.org/downloads/ |
| **Node.js** | 18+ | https://nodejs.org/ |
| **Docker** | Latest | https://docs.docker.com/get-docker/ |
| **Git** | Latest | https://git-scm.com/ |

### Clone the Repository

```bash
git clone https://github.com/xtreamgit/adk-multi-agents.git
cd adk-multi-agents
```

### Install Backend Dependencies

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd ..
```

### Install Frontend Dependencies

```bash
cd frontend
npm install
cd ..
```

---

## 2. Gather Client Information

Before configuring anything, collect all client-specific values. **Every value below will be different per client.**

| Item | Example (Develom) | Your Client |
|------|-------------------|-------------|
| **Client name** (short, lowercase, no spaces) | `develom` | `__________` |
| **Account environment ID** | `develom` | `__________` |
| **GCP Project ID** | `adk-rag-ma` | `__________` |
| **GCP Project Number** | `351592762922` | `__________` |
| **Region** | `us-west1` | `__________` |
| **Organization domain** | `develom.com` | `__________` |
| **IAP admin user email** | `hector@develom.com` | `__________` |
| **Artifact Registry repo name** | `cloud-run-repo1` | `__________` |
| **Cloud SQL instance name** | `adk-multi-agents-db` | `__________` |
| **Database name** | `adk_agents_db` | `__________` |
| **Database user** | `adk_app_user` | `__________` |
| **Billing account ID** | `ABCDEF-123456-GHIJKL` | `__________` |

**Per-corpus information** (repeat for each corpus):

| Corpus Name | GCS Bucket Name | Description |
|-------------|----------------|-------------|
| e.g., `forest-policies` | `client-forest-policies` | Forest policy documents |
| e.g., `fire-management` | `client-fire-management-docs` | Fire management reports |

**Users to create** (at minimum, one admin):

| Username | Email | Full Name | Group |
|----------|-------|-----------|-------|
| e.g., `admin` | `admin@client.com` | Admin User | admin-users |

> **Important Region Note:** Vertex AI RAG Engine is only available in certain regions.
> - `us-west1` — Available without restrictions
> - `us-east4` — Restricted, requires allowlist from Google
> - `us-west2` — NOT supported for Vertex AI RAG

---

## 3. Create the Environment YAML

This is the **single source of truth** for all client-specific configuration. Every other config file is generated from it.

```bash
cp environments/client-template.yaml environments/<client-name>.yaml
```

Edit `environments/<client-name>.yaml` and fill in **all** values. Here is what each section controls:

### 3.1 Core Identity

```yaml
client_name: "acme"                    # Short identifier, used in file paths
account_env: "acme"                    # Must match backend/config/<account_env>/
project_id: "acme-rag-agent"           # GCP Project ID
project_number: "123456789012"         # GCP Project Number
region: "us-west1"                     # GCP region (must support Vertex AI RAG)
organization_domain: "acme.com"        # Used for OAuth consent screen
```

### 3.2 IAP & Authentication

```yaml
iap_admin_user: "admin@acme.com"       # Email of the IAP admin
```

### 3.3 Artifact Registry

```yaml
repo: "cloud-run-repo1"               # Docker image repository name
```

### 3.4 Database

```yaml
database:
  cloud_sql_instance: "acme-multi-agents-db"
  cloud_sql_connection: "acme-rag-agent:us-west1:acme-multi-agents-db"
  name: "adk_agents_db"
  user: "adk_app_user"
  password: ""                         # Leave empty; use password_secret_name
  password_secret_name: "db-password"  # Secret Manager secret name

  local:
    host: "localhost"
    port: 5433
    name: "adk_agents_db_dev"
    user: "adk_dev_user"
    password: "dev_password_123"
```

### 3.5 Vertex AI & RAG Settings

```yaml
vertex_ai:
  location: "us-west1"                # Must match region
  embedding_model: "publishers/google/models/text-embedding-005"
  embedding_requests_per_min: 1000

rag:
  default_chunk_size: 512
  default_chunk_overlap: 100
  default_top_k: 3
  default_distance_threshold: 0.5
```

### 3.6 Corpus-to-Bucket Mapping

**This maps each Vertex AI corpus name to its GCS bucket.** Every client will have different corpora and buckets.

```yaml
corpus_to_bucket_mapping:
  "forest-policies": "acme-forest-policies"
  "fire-management": "acme-fire-management-docs"
  "environmental-reports": "acme-environmental-reports"

default_corpus_name: "forest-policies"
```

### 3.7 Secrets

```yaml
secrets:
  secret_key_source: "file"           # "file" reads from secrets.env
  secret_key_secret_name: ""          # Set if using GCP Secret Manager
```

### 3.8 Service Accounts

Leave empty — they are auto-derived from `project_id` during deployment:

```yaml
service_accounts:
  backend_sa: ""
  frontend_sa: ""
  rag_agent_sa: ""
```

### 3.9 Seed Data

Define the users, groups, memberships, and corpus access permissions for the new environment:

```yaml
seed_data:
  users:
    - username: "admin"
      email: "admin@acme.com"
      full_name: "Admin User"
      password: "CHANGE_ME_STRONG_PASSWORD"
      auth_provider: "local"

  groups:
    - name: "admin-users"
      description: "Administrators with full system access"
    - name: "users"
      description: "Default user group"
    - name: "viewers"
      description: "Users with read-only access"

  memberships:
    admin:
      - "admin-users"
      - "users"

  group_corpus_access:
    admin-users:
      - corpus: "forest-policies"
        permission: "admin"
      - corpus: "fire-management"
        permission: "admin"
    users:
      - corpus: "forest-policies"
        permission: "read"
    viewers:
      - corpus: "forest-policies"
        permission: "read"
```

---

## 4. Generate Configuration Files

The `deploy_env_config.py` script reads your environment YAML and generates **three files** automatically:

| Generated File | Purpose |
|----------------|---------|
| `deployment.config` | Shell variables sourced by infrastructure scripts |
| `backend/.env.local` | Local development environment variables |
| `backend/config/<account>/config.py` | Python config with project ID, region, corpus-bucket mapping |

### 4.1 Preview (Dry Run)

```bash
cd backend
python deploy_env_config.py --env ../environments/<client-name>.yaml --dry-run
```

### 4.2 Generate All Configs

```bash
python deploy_env_config.py --env ../environments/<client-name>.yaml
cd ..
```

### 4.3 Verify Generated Files

Check that these files were created/updated:

```bash
cat deployment.config                          # Should show your client's PROJECT_ID, REGION, etc.
cat backend/.env.local                         # Should show local DB settings + your PROJECT_ID
cat backend/config/<account-env>/config.py     # Should show CORPUS_TO_BUCKET_MAPPING with your corpora
```

> **Never manually edit `deployment.config` or `backend/.env.local`.** Always update the YAML and regenerate.

---

## 5. Register the New Account in the Config Loader

The backend uses a config loader that validates account identifiers. You must register your new account.

### 5.1 Edit `backend/config/config_loader.py`

Add your account to the `VALID_ACCOUNTS` list (around line 25):

```python
VALID_ACCOUNTS = [
    "develom",
    "usfs",
    "tt",
    "agent1",
    "agent2",
    "agent3",
    "acme",          # <-- Add your new account here
]
```

### 5.2 Verify the Config Directory Was Created

The `deploy_env_config.py` script should have created:

```
backend/config/<account-env>/
  __init__.py
  config.py
```

If `__init__.py` is missing, create it:

```bash
echo '"""Configuration for <client-name> account."""' > backend/config/<account-env>/__init__.py
```

---

## 6. Create the Agent Instructions

Each account needs an agent instruction file that defines the AI agent's behavior, tools, and personality.

### 6.1 Copy the Template

```bash
cp backend/config/agent_instructions/develom.json backend/config/agent_instructions/<account-env>.json
```

### 6.2 Customize the Agent Instructions

Edit `backend/config/agent_instructions/<account-env>.json` and update:

- **`agent_name`** — A unique identifier for this client's agent
- **`display_name`** — Human-readable name shown in the UI
- **`description`** — What this agent does for this client
- **`model.location`** — Must match your region (e.g., `us-west1`)
- **`tools`** — Which tools this agent can use (keep all or restrict as needed)
- **`instruction.role`** — The system prompt that defines the agent's personality and behavior
- **`instruction.capabilities`** — What the agent tells users it can do

Example changes for a USFS client:

```json
{
  "agent_name": "usfs_rag_agent",
  "display_name": "USFS RAG Agent",
  "description": "Forest Service document retrieval and analysis agent",
  "model": {
    "type": "gemini-2.5-flash",
    "location": "us-west1"
  }
}
```

---

## 7. Generate the Secret Key

The application needs a cryptographic secret key for JWT token signing.

```bash
python generate_secret_key.py
```

Copy the output and save it to `secrets.env` in the project root:

```bash
echo "SECRET_KEY=<paste-generated-key-here>" > secrets.env
```

> **`secrets.env` is gitignored.** Never commit it. Each environment needs its own unique key.

---

## 8. Create the Frontend Environment File

The frontend needs to know the backend URL. For local development:

```bash
echo "NEXT_PUBLIC_BACKEND_URL=http://localhost:8000" > frontend/.env.local
```

For cloud deployment, this is set automatically during the Docker build via the `NEXT_PUBLIC_BACKEND_URL` build argument in `infrastructure/lib/cloudrun.sh`.

> **`frontend/.env.local` is gitignored.** Each developer creates their own.

---

## 9. Initialize the GCP Project

This step creates the GCP project, enables billing, and enables required APIs.

### 9.1 Authenticate with Google Cloud

```bash
gcloud auth login
gcloud auth application-default login
```

### 9.2 Run the Initialization Script

```bash
cd infrastructure
./deploy-init.sh --project-id=<your-project-id> --region=<your-region>
cd ..
```

This script will:
1. Authenticate and confirm your Google account
2. Create the GCP project (or use existing)
3. Link a billing account
4. Enable required APIs (Cloud Run, Artifact Registry, IAP, Vertex AI, etc.)
5. Set the default region
6. Save configuration to `deployment.config`

> **Note:** The `deployment.config` generated by `deploy-init.sh` is a minimal version. You should regenerate it from your YAML afterward:
> ```bash
> cd backend
> python deploy_env_config.py --env ../environments/<client-name>.yaml --only deployment
> cd ..
> ```

---

## 10. Create GCS Buckets for Corpora

Each corpus needs a GCS bucket to store its source documents. Create one bucket per corpus.

```bash
PROJECT_ID="<your-project-id>"
REGION="<your-region>"

# Create a bucket for each corpus in your corpus_to_bucket_mapping
gsutil mb -p $PROJECT_ID -l $REGION gs://<bucket-name-1>/
gsutil mb -p $PROJECT_ID -l $REGION gs://<bucket-name-2>/
gsutil mb -p $PROJECT_ID -l $REGION gs://<bucket-name-3>/
```

### 10.1 Upload Source Documents

Upload the documents that will be indexed into each corpus:

```bash
# Upload PDFs, text files, etc. to the appropriate bucket
gsutil -m cp /path/to/documents/*.pdf gs://<bucket-name-1>/
gsutil -m cp /path/to/other-docs/*.pdf gs://<bucket-name-2>/
```

### 10.2 Update Bucket IAM in Infrastructure Script

The RAG agent service accounts need read access to these buckets. The `infrastructure/lib/infrastructure.sh` script grants this access, but **it has hardcoded bucket names** that must be updated for your client.

Edit `infrastructure/lib/infrastructure.sh` (around lines 160-178) and replace the default bucket names with your client's buckets:

**Before (default/develom):**
```bash
gcloud storage buckets add-iam-policy-binding "gs://ipad-book-collection" \
    --member="serviceAccount:${sa}" \
    --role="roles/storage.objectViewer" \
    --quiet 2>/dev/null || true

gcloud storage buckets add-iam-policy-binding "gs://develom-documents" \
    --member="serviceAccount:${sa}" \
    --role="roles/storage.objectViewer" \
    --quiet 2>/dev/null || true
```

**After (your client):**
```bash
gcloud storage buckets add-iam-policy-binding "gs://<your-bucket-1>" \
    --member="serviceAccount:${sa}" \
    --role="roles/storage.objectViewer" \
    --quiet 2>/dev/null || true

gcloud storage buckets add-iam-policy-binding "gs://<your-bucket-2>" \
    --member="serviceAccount:${sa}" \
    --role="roles/storage.objectViewer" \
    --quiet 2>/dev/null || true
```

> **This is a known hardcoded dependency.** The bucket names in `infrastructure/lib/infrastructure.sh` must match your `corpus_to_bucket_mapping` in the YAML.

---

## 11. Create Vertex AI Corpora and Upload Documents

Vertex AI RAG corpora are the searchable indexes that the agent queries. They are created from the documents in your GCS buckets.

### 11.1 Create Corpora via the Application

Once the backend is running (locally or in the cloud), you can create corpora through the chat interface:

```
User: "Create a corpus called forest-policies"
Agent: "Created corpus 'forest-policies'"

User: "Add data from gs://<bucket-name>/ to forest-policies"
Agent: "Added documents to forest-policies"
```

### 11.2 Or Create Corpora via Python SDK

```python
import vertexai
from vertexai import rag

vertexai.init(project="<your-project-id>", location="<your-region>")

# Create a corpus
corpus = rag.create_corpus(display_name="forest-policies")
print(f"Created: {corpus.name}")

# Import documents from GCS
rag.import_files(
    corpus_name=corpus.name,
    paths=["gs://<bucket-name>/"],
    chunk_size=512,
    chunk_overlap=100,
)
```

### 11.3 Verify Corpora Exist

```python
for corpus in rag.list_corpora():
    print(f"{corpus.display_name}: {corpus.name}")
```

---

## 12. Create and Seed the Database

See [DATABASE-DEPLOYMENT-GUIDE.md](docs/DATABASE-DEPLOYMENT-GUIDE.md) for the full detailed procedure. Here is the summary:

### 12.1 Create Cloud SQL Instance

```bash
PROJECT_ID="<your-project-id>"
REGION="<your-region>"
INSTANCE="<your-cloud-sql-instance>"
DB_NAME="adk_agents_db"
DB_USER="adk_app_user"
DB_PASSWORD="<generate-strong-password>"

gcloud sql instances create $INSTANCE \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=$REGION \
  --project=$PROJECT_ID \
  --storage-type=SSD \
  --storage-size=10GB

gcloud sql databases create $DB_NAME --instance=$INSTANCE --project=$PROJECT_ID
gcloud sql users create $DB_USER --instance=$INSTANCE --project=$PROJECT_ID --password=$DB_PASSWORD

# Store password in Secret Manager
echo -n "$DB_PASSWORD" | gcloud secrets create db-password --data-file=- --project=$PROJECT_ID
```

### 12.2 Apply Schema

```bash
# Terminal 1: Start Cloud SQL Proxy
cloud-sql-proxy $PROJECT_ID:$REGION:$INSTANCE --port=5434

# Terminal 2: Apply schema
PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -p 5434 -U $DB_USER -d $DB_NAME \
  -f backend/init_postgresql_schema.sql
```

### 12.3 Run Migrations

```bash
cd backend
python src/database/migrations/run_migrations.py
python add_missing_columns.py
```

### 12.4 Sync Corpora from Vertex AI

This is the **source of truth** for corpora. Do NOT manually insert corpora into the database.

```bash
cd backend
export PROJECT_ID="<your-project-id>"
export GOOGLE_CLOUD_LOCATION="<your-region>"
python sync_corpora_from_vertex.py
```

### 12.5 Seed Users, Groups & Permissions

```bash
# Preview first
python seed_data.py --env ../environments/<client-name>.yaml --target cloud --dry-run --verbose

# Execute
python seed_data.py --env ../environments/<client-name>.yaml --target cloud
cd ..
```

---

## 13. Deploy to Cloud Run

### 13.1 Verify Prerequisites

Ensure these files exist and are correct:

```bash
cat deployment.config    # Core variables (PROJECT_ID, REGION, etc.)
cat secrets.env          # SECRET_KEY=...
```

### 13.2 Run the Full Deployment

```bash
cd infrastructure
./deploy-all.sh
```

This orchestrates 7 deployment phases:

| Phase | Module | What It Does |
|-------|--------|-------------|
| 1 | `lib/prerequisites.sh` | Validates auth, enables APIs |
| 2 | `lib/infrastructure.sh` | Creates Artifact Registry, service accounts, IAM |
| 3 | `lib/cloudrun.sh` | Builds Docker images, deploys Cloud Run services |
| 4 | `lib/oauth.sh` | Configures OAuth consent screen |
| 5 | `lib/loadbalancer.sh` | Creates HTTPS Load Balancer with SSL |
| 6 | `lib/iap.sh` | Enables Identity-Aware Proxy |
| 7 | `lib/finalize.sh` | Rebuilds frontend with final URLs, prints summary |

### 13.3 Partial Redeployment

After the first full deployment, you can skip phases:

```bash
# Redeploy only Cloud Run (code changes)
./deploy-all.sh --skip-apis --skip-load-balancer --skip-iap --skip-oauth

# Skip everything except Cloud Run
./deploy-all.sh --skip-apis --skip-load-balancer
```

---

## 14. Verify the Deployment

### 14.1 Check Cloud Run Services

```bash
gcloud run services list --project=<your-project-id> --region=<your-region>
```

You should see:
- `backend` — Primary backend service
- `backend-agent1` — Agent 1 backend
- `backend-agent2` — Agent 2 backend
- `backend-agent3` — Agent 3 backend
- `frontend` — Next.js frontend

### 14.2 Test the Health Endpoint

```bash
BACKEND_URL=$(gcloud run services describe backend --region=<your-region> --format='value(status.url)')
curl $BACKEND_URL/api/health
```

### 14.3 Test Authentication

```bash
curl -s -X POST $BACKEND_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"<admin-username>","password":"<admin-password>"}' | python3 -m json.tool
```

### 14.4 Test Corpora Listing

```bash
TOKEN="<token-from-login-response>"
curl -s $BACKEND_URL/api/admin/corpora \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

### 14.5 Check Logs

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --project=<your-project-id> \
  --limit=10 \
  --freshness=30m
```

---

## 15. Set Up Local Development

For local development after the cloud deployment is complete:

### 15.1 Start the Local PostgreSQL Database

```bash
cd backend
docker compose -f docker-compose.dev.yml up -d
```

### 15.2 Apply Schema to Local DB

The Docker Compose file auto-applies `init_postgresql_schema.sql` on first start via the `docker-entrypoint-initdb.d` mount. If you need to re-apply:

```bash
docker exec adk-postgres-dev psql -U adk_dev_user -d adk_agents_db_dev -f /docker-entrypoint-initdb.d/01-schema.sql
```

### 15.3 Sync Corpora to Local DB

```bash
cd backend
export PROJECT_ID="<your-project-id>"
export GOOGLE_CLOUD_LOCATION="<your-region>"
python sync_corpora_from_vertex.py
```

### 15.4 Seed Local Database

```bash
python seed_data.py --env ../environments/<client-name>.yaml --target local
```

### 15.5 Authenticate with Google Cloud (for Vertex AI access)

```bash
gcloud auth application-default login
```

### 15.6 Start the Backend

```bash
cd backend
source .venv/bin/activate
python -m uvicorn src.api.server:app --host 0.0.0.0 --port 8000 --reload
```

### 15.7 Start the Frontend

```bash
cd frontend
npm run dev
```

Open http://localhost:3000 in your browser.

---

## 16. File Reference

### Files You Create or Edit Per Client

| File | Action | Description |
|------|--------|-------------|
| `environments/<client>.yaml` | **CREATE** | Single source of truth for all client config |
| `secrets.env` | **CREATE** | SECRET_KEY (gitignored) |
| `frontend/.env.local` | **CREATE** | NEXT_PUBLIC_BACKEND_URL (gitignored) |
| `backend/config/config_loader.py` | **EDIT** | Add account to `VALID_ACCOUNTS` list |
| `backend/config/agent_instructions/<account>.json` | **CREATE** | Agent behavior and personality |
| `infrastructure/lib/infrastructure.sh` | **EDIT** | Update hardcoded GCS bucket names (~lines 160-178) |

### Files Auto-Generated (Never Edit Directly)

| File | Generated By | Description |
|------|-------------|-------------|
| `deployment.config` | `deploy_env_config.py` | Shell variables for infrastructure scripts |
| `backend/.env.local` | `deploy_env_config.py` | Local dev environment variables |
| `backend/config/<account>/config.py` | `deploy_env_config.py` | Python config (project ID, corpus mapping) |
| `backend/config/<account>/__init__.py` | `deploy_env_config.py` | Python package marker |

### Files That Stay the Same Across Clients

| File | Description |
|------|-------------|
| `backend/Dockerfile` | Backend container (env vars overridden at deploy time) |
| `frontend/Dockerfile` | Frontend container (BACKEND_URL set via build arg) |
| `backend/init_postgresql_schema.sql` | Database schema |
| `backend/src/database/migrations/*.sql` | Schema migrations |
| `backend/sync_corpora_from_vertex.py` | Syncs corpora from Vertex AI |
| `backend/seed_data.py` | Seeds users/groups from YAML |
| `infrastructure/deploy-init.sh` | GCP project initialization |
| `infrastructure/deploy-all.sh` | Master deployment orchestrator |
| `infrastructure/lib/*.sh` | Deployment modules (except `infrastructure.sh` bucket names) |

---

## 17. Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `Invalid ACCOUNT_ENV: acme` | Account not registered | Add to `VALID_ACCOUNTS` in `config_loader.py` |
| `Configuration file not found` | Missing config.py | Run `deploy_env_config.py --only account-config` |
| `No billing accounts found` | Billing not linked | Link billing in GCP Console |
| `FAILED_PRECONDITION` from Vertex AI | Wrong region | Use `us-west1` (confirmed working) |
| `connection refused` on port 5434 | Cloud SQL Proxy not running | Start `cloud-sql-proxy` in separate terminal |
| `password authentication failed` | Wrong DB password | Check Secret Manager or YAML |
| `No active corpora found` in seed_data | Corpora not synced | Run `sync_corpora_from_vertex.py` first |
| Frontend shows blank page | Backend URL not set | Check `frontend/.env.local` or build arg |
| 500 on admin corpora page | Pydantic model issue | Check `tags` type is `Optional[Any]` in models |
| Docker build fails | Old cache | Add `--no-cache` to `gcloud builds submit` |
| IAP returns 403 | User not authorized | Add user email to IAP access list in GCP Console |
| CORS error on login | Backend missing CORS origin | Add IAP domain to `FRONTEND_URL` env var on backend Cloud Run service |

---

## Quick Reference: Complete Command Sequence

```bash
# ── Step 1: Clone & Install ──
git clone https://github.com/xtreamgit/adk-multi-agents.git
cd adk-multi-agents
cd backend && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && cd ..
cd frontend && npm install && cd ..

# ── Step 2: Configure ──
cp environments/client-template.yaml environments/<client>.yaml
# Edit environments/<client>.yaml with ALL client values

cd backend && python deploy_env_config.py --env ../environments/<client>.yaml && cd ..

# Edit backend/config/config_loader.py → add account to VALID_ACCOUNTS
cp backend/config/agent_instructions/develom.json backend/config/agent_instructions/<account>.json
# Edit the agent instructions JSON

# ── Step 3: Secrets ──
python generate_secret_key.py
echo "SECRET_KEY=<generated-key>" > secrets.env
echo "NEXT_PUBLIC_BACKEND_URL=http://localhost:8000" > frontend/.env.local

# ── Step 4: GCP Project ──
gcloud auth login && gcloud auth application-default login
cd infrastructure && ./deploy-init.sh --project-id=<project-id> --region=<region> && cd ..
cd backend && python deploy_env_config.py --env ../environments/<client>.yaml --only deployment && cd ..

# ── Step 5: GCS Buckets ──
gsutil mb -p <project-id> -l <region> gs://<bucket-1>/
gsutil mb -p <project-id> -l <region> gs://<bucket-2>/
gsutil -m cp /path/to/docs/*.pdf gs://<bucket-1>/
# Edit infrastructure/lib/infrastructure.sh → update bucket names (~lines 160-178)

# ── Step 6: Vertex AI Corpora ──
# Create corpora via Python SDK or through the running application
# (See Section 11 for details)

# ── Step 7: Database ──
gcloud sql instances create <instance> \
  --database-version=POSTGRES_15 --tier=db-f1-micro \
  --region=<region> --project=<project-id> \
  --storage-type=SSD --storage-size=10GB
gcloud sql databases create adk_agents_db --instance=<instance> --project=<project-id>
gcloud sql users create adk_app_user --instance=<instance> --project=<project-id> --password=<password>
echo -n "<password>" | gcloud secrets create db-password --data-file=- --project=<project-id>

# Start Cloud SQL Proxy (separate terminal)
cloud-sql-proxy <project-id>:<region>:<instance> --port=5434

# Apply schema + seed
PGPASSWORD=<password> psql -h 127.0.0.1 -p 5434 -U adk_app_user -d adk_agents_db \
  -f backend/init_postgresql_schema.sql
cd backend
python src/database/migrations/run_migrations.py
python add_missing_columns.py
python sync_corpora_from_vertex.py
python seed_data.py --env ../environments/<client>.yaml --target cloud
cd ..

# ── Step 8: Deploy ──
cd infrastructure && ./deploy-all.sh && cd ..

# ── Step 9: Verify ──
gcloud run services list --project=<project-id> --region=<region>
BACKEND_URL=$(gcloud run services describe backend --region=<region> --format='value(status.url)')
curl $BACKEND_URL/api/health
```
