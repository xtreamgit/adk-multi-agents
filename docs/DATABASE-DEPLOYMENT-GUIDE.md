# Database Deployment Guide

Complete procedure to create and deploy the PostgreSQL database for a new environment after cloning the repository.

---

## Overview

The database deployment has **5 phases**, run in this exact order:

```
Phase 1: Create Cloud SQL Instance          (one-time, via gcloud)
Phase 2: Apply Schema                       (init_postgresql_schema.sql + migrations)
Phase 3: Sync Corpora from Vertex AI        (sync_corpora_from_vertex.py)
Phase 4: Seed Users, Groups & Permissions   (seed_data.py)
Phase 5: Verify                             (queries + app health check)
```

**Key Principle:** Corpora come from **Vertex AI** (the source of truth), not from a local database copy. Users, groups, and permissions come from the **environment YAML** config.

---

## Prerequisites

Before starting, ensure you have:

- [ ] Google Cloud SDK (`gcloud`) installed and authenticated
- [ ] Cloud SQL Proxy installed (`cloud-sql-proxy`)
- [ ] Python 3.12+ with `pip`
- [ ] The repository cloned: `git clone https://github.com/xtreamgit/adk-multi-agents.git`
- [ ] An environment YAML file configured: `environments/<client>.yaml`
- [ ] Backend Python dependencies installed:
  ```bash
  cd backend
  pip install -r requirements.txt
  ```

---

## Phase 1: Create Cloud SQL Instance

> **Run once per new GCP project.** Skip if the Cloud SQL instance already exists.

### 1.1 Set Variables

```bash
# Adjust these for your client
PROJECT_ID="adk-rag-ma"
REGION="us-west1"
INSTANCE_NAME="adk-multi-agents-db"
DB_NAME="adk_agents_db"
DB_USER="adk_app_user"
DB_PASSWORD="<generate-a-strong-password>"
```

### 1.2 Create the Cloud SQL Instance

```bash
gcloud sql instances create $INSTANCE_NAME \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=$REGION \
  --project=$PROJECT_ID \
  --storage-type=SSD \
  --storage-size=10GB \
  --database-flags=max_connections=100
```

> **Note:** `db-f1-micro` is the smallest (cheapest) tier. For production, consider `db-custom-1-3840` or higher.

### 1.3 Create the Database

```bash
gcloud sql databases create $DB_NAME \
  --instance=$INSTANCE_NAME \
  --project=$PROJECT_ID
```

### 1.4 Create the Application User

```bash
gcloud sql users create $DB_USER \
  --instance=$INSTANCE_NAME \
  --project=$PROJECT_ID \
  --password=$DB_PASSWORD
```

### 1.5 Store Password in Secret Manager

```bash
echo -n "$DB_PASSWORD" | gcloud secrets create db-password \
  --data-file=- \
  --project=$PROJECT_ID

# Grant Cloud Run access to the secret
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=$PROJECT_ID
```

### 1.6 Update Environment YAML

Edit `environments/<client>.yaml` with the database details:

```yaml
database:
  cloud_sql_instance: "adk-multi-agents-db"
  cloud_sql_connection: "adk-rag-ma:us-west1:adk-multi-agents-db"
  name: "adk_agents_db"
  user: "adk_app_user"
  password: ""  # Leave empty if using password_secret_name
  password_secret_name: "db-password"
```

---

## Phase 2: Apply Schema

### 2.1 Start Cloud SQL Proxy

Open a **separate terminal** and keep it running:

```bash
cloud-sql-proxy $PROJECT_ID:$REGION:$INSTANCE_NAME --port=5434
```

### 2.2 Apply the Base Schema

```bash
PGPASSWORD=$DB_PASSWORD psql \
  -h 127.0.0.1 \
  -p 5434 \
  -U $DB_USER \
  -d $DB_NAME \
  -f backend/init_postgresql_schema.sql
```

This creates all ~27 tables:

| Category | Tables |
|----------|--------|
| **Core** | `users`, `user_profiles`, `user_sessions`, `user_stats` |
| **Groups** | `groups`, `user_groups`, `group_roles` |
| **Corpora** | `corpora`, `corpus_metadata`, `corpus_audit_log`, `group_corpus_access`, `group_corpora` |
| **Chat** | `chat_sessions`, `chat_messages`, `session_corpus_selections` |
| **Documents** | `document_access_log` |
| **Agents** | `user_agent_access` |
| **Chatbot** | `chatbot_groups`, `chatbot_users`, `chatbot_agent_types`, `chatbot_group_agents`, `chatbot_corpus_access`, `chatbot_agent_access`, `chatbot_tool_access` |

### 2.3 Run Migrations

Migrations add columns and tables that were added after the initial schema:

```bash
PGPASSWORD=$DB_PASSWORD psql \
  -h 127.0.0.1 \
  -p 5434 \
  -U $DB_USER \
  -d $DB_NAME \
  -f backend/src/database/migrations/001_initial_schema.sql

# Continue with each migration in order...
# Or use the migration runner (requires backend env vars):
cd backend
python src/database/migrations/run_migrations.py
```

### 2.4 Add Missing Columns

```bash
cd backend
python add_missing_columns.py
```

> **Note:** The Cloud Run `entrypoint.sh` runs both `run_migrations.py` and `add_missing_columns.py` automatically on every container startup. For manual deployment, run them explicitly.

### 2.5 Verify Schema

```bash
PGPASSWORD=$DB_PASSWORD psql \
  -h 127.0.0.1 -p 5434 -U $DB_USER -d $DB_NAME \
  -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;"
```

Expected: ~27 tables.

---

## Phase 3: Sync Corpora from Vertex AI

> **This is the source of truth for corpora.** Do NOT manually insert corpora.

### 3.1 Authenticate with Google Cloud

```bash
gcloud auth application-default login
```

### 3.2 Set Environment Variables

The sync script needs to know which GCP project and region to query:

```bash
export PROJECT_ID="adk-rag-ma"
export GOOGLE_CLOUD_LOCATION="us-west1"
export VERTEXAI_PROJECT="adk-rag-ma"
export VERTEXAI_LOCATION="us-west1"

# Database connection (point to cloud via proxy)
export DB_HOST="127.0.0.1"
export DB_PORT="5434"
export DB_NAME="adk_agents_db"
export DB_USER="adk_app_user"
export DB_PASSWORD="<your-password>"
```

### 3.3 Run the Sync

```bash
cd backend
python sync_corpora_from_vertex.py
```

**What this does:**
1. Calls `rag.list_corpora()` to fetch all corpora from Vertex AI
2. Compares with the (empty) `corpora` table
3. Inserts new corpora with their `vertex_corpus_id`
4. Deactivates any DB corpora not found in Vertex AI
5. Grants `read` access to the `default` group (if it exists)

### 3.4 Verify Corpora

```bash
PGPASSWORD=$DB_PASSWORD psql \
  -h 127.0.0.1 -p 5434 -U $DB_USER -d $DB_NAME \
  -c "SELECT id, name, display_name, is_active, vertex_corpus_id IS NOT NULL as has_vertex_id FROM corpora ORDER BY id;"
```

---

## Phase 4: Seed Users, Groups & Permissions

### 4.1 Review Seed Data

The seed data is defined in `environments/<client>.yaml` under the `seed_data` section:

```yaml
seed_data:
  users:        # Username, email, password, auth_provider
  groups:       # Group name, description
  memberships:  # Which users belong to which groups
  group_corpus_access:  # Which groups can access which corpora (by name)
```

### 4.2 Dry Run (Preview)

```bash
cd backend
python seed_data.py \
  --env ../environments/develom.yaml \
  --target cloud \
  --dry-run \
  --verbose
```

### 4.3 Execute Seeding

```bash
python seed_data.py \
  --env ../environments/develom.yaml \
  --target cloud
```

**What this does (in order):**
1. Creates **groups** (admin-users, users, viewers, etc.)
2. Creates **users** with bcrypt-hashed passwords
3. Creates **user-group memberships** (who belongs to which group)
4. Creates **group-corpus access** (which groups can access which corpora, with permission level)

### 4.4 Verify

```bash
PGPASSWORD=$DB_PASSWORD psql \
  -h 127.0.0.1 -p 5434 -U $DB_USER -d $DB_NAME \
  -c "SELECT id, username, email, is_active FROM users ORDER BY id;" \
  -c "SELECT id, name, is_active FROM groups ORDER BY id;" \
  -c "SELECT u.username, g.name as group_name FROM user_groups ug JOIN users u ON ug.user_id=u.id JOIN groups g ON ug.group_id=g.id ORDER BY u.username;" \
  -c "SELECT g.name as group_name, c.name as corpus_name, gca.permission FROM group_corpus_access gca JOIN groups g ON gca.group_id=g.id JOIN corpora c ON gca.corpus_id=c.id ORDER BY g.name, c.name;"
```

---

## Phase 5: Verify Deployment

### 5.1 Test Database Connection from Cloud Run

Deploy the backend (if not already deployed):

```bash
cd infrastructure
./deploy-all.sh
```

### 5.2 Check Health Endpoint

```bash
curl https://backend-<PROJECT_NUMBER>.<REGION>.run.app/api/health
```

### 5.3 Check Cloud Run Logs

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --project=$PROJECT_ID \
  --limit=10 \
  --freshness=30m
```

### 5.4 Test Admin Corpora Page

```bash
# Get a token first (login as admin user)
TOKEN=$(curl -s -X POST https://backend-<URL>/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"hector","password":"hector123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Fetch corpora
curl -s https://backend-<URL>/api/admin/corpora \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

---

## Quick Reference: Complete Command Sequence

```bash
# ── Phase 1: Create Cloud SQL (one-time) ──
gcloud sql instances create adk-multi-agents-db --database-version=POSTGRES_15 --tier=db-f1-micro --region=us-west1 --project=adk-rag-ma --storage-type=SSD --storage-size=10GB
gcloud sql databases create adk_agents_db --instance=adk-multi-agents-db --project=adk-rag-ma
gcloud sql users create adk_app_user --instance=adk-multi-agents-db --project=adk-rag-ma --password=YOUR_PASSWORD
echo -n "YOUR_PASSWORD" | gcloud secrets create db-password --data-file=- --project=adk-rag-ma

# ── Phase 2: Apply Schema ──
# Terminal 1: Start proxy
cloud-sql-proxy adk-rag-ma:us-west1:adk-multi-agents-db --port=5434

# Terminal 2: Apply schema + migrations
PGPASSWORD=YOUR_PASSWORD psql -h 127.0.0.1 -p 5434 -U adk_app_user -d adk_agents_db -f backend/init_postgresql_schema.sql
cd backend && python src/database/migrations/run_migrations.py && python add_missing_columns.py

# ── Phase 3: Sync Corpora from Vertex AI ──
gcloud auth application-default login
python sync_corpora_from_vertex.py

# ── Phase 4: Seed Users & Groups ──
python seed_data.py --env ../environments/develom.yaml --target cloud

# ── Phase 5: Deploy & Verify ──
cd ../infrastructure && ./deploy-all.sh
curl https://backend-XXXXX.run.app/api/health
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `connection refused` on port 5434 | Cloud SQL Proxy not running | Start `cloud-sql-proxy` in separate terminal |
| `password authentication failed` | Wrong password | Check Secret Manager or YAML config |
| `relation "users" does not exist` | Schema not applied | Run `init_postgresql_schema.sql` |
| `No active corpora found` in seed_data.py | Corpora not synced yet | Run `sync_corpora_from_vertex.py` first |
| `FAILED_PRECONDITION` from Vertex AI | Wrong region | Ensure `VERTEXAI_LOCATION=us-west1` |
| 500 error on admin corpora page | Pydantic model mismatch | Check `tags` type in `models/admin.py` (should be `Optional[Any]`) |

---

## Files Reference

| File | Purpose |
|------|---------|
| `environments/<client>.yaml` | All config including seed data |
| `backend/init_postgresql_schema.sql` | Base schema (all ~27 tables) |
| `backend/src/database/migrations/*.sql` | Incremental schema changes |
| `backend/src/database/migrations/run_migrations.py` | Migration runner |
| `backend/add_missing_columns.py` | Adds missing columns to corpus_metadata |
| `backend/sync_corpora_from_vertex.py` | Syncs corpora from Vertex AI → DB |
| `backend/seed_data.py` | Seeds users, groups, memberships, corpus access |
| `backend/db_sync.py` | Full table-level sync between local ↔ cloud (for data migration) |
| `backend/entrypoint.sh` | Cloud Run startup (runs migrations automatically) |
| `backend/scripts/prepare_cloudsql.sh` | Drop & recreate database (destructive) |
