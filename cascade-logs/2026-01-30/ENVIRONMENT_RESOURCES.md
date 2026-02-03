# ADK Multi-Agents Environment Resources

**Created:** January 30, 2026  
**Purpose:** Complete inventory of resource names for Local and Cloud deployments

---

## 🏠 LOCAL DEVELOPMENT ENVIRONMENT

### Database (Docker PostgreSQL)

| Resource | Value |
|----------|-------|
| **Container Name** | `adk-postgres-dev` |
| **Docker Image** | `postgres:15` |
| **Database Name** | `adk_agents_db_dev` |
| **Database User** | `adk_dev_user` |
| **Database Password** | `dev_password_123` |
| **Host** | `localhost` |
| **Port** | `5433` |
| **Connection String** | `postgresql://adk_dev_user:dev_password_123@localhost:5433/adk_agents_db_dev` |
| **Docker Volume** | `postgres_dev_data` |
| **Docker Network** | `adk-dev-network` |
| **Schema Init File** | `init_postgresql_schema.sql` |

### Backend Service

| Resource | Value |
|----------|-------|
| **Service Name** | FastAPI Backend |
| **URL** | `http://localhost:8000` |
| **API Docs** | `http://localhost:8000/docs` |
| **Environment File** | `backend/.env.local` |
| **Startup Script** | `backend/start-backend.sh` |
| **Log File** | `backend.log` |
| **Virtual Environment** | `backend/.venv` |

### Frontend Service

| Resource | Value |
|----------|-------|
| **Service Name** | Next.js Frontend |
| **URL** | `http://localhost:3000` |
| **Environment File** | `frontend/.env.local` |
| **Node Modules** | `frontend/node_modules` |

### Local Environment Variables

```bash
# Database
DB_HOST=localhost
DB_PORT=5433
DB_NAME=adk_agents_db_dev
DB_USER=adk_dev_user
DB_PASSWORD=dev_password_123
ENVIRONMENT=local

# Vertex AI (uses cloud resources)
PROJECT_ID=adk-rag-ma
VERTEX_AI_LOCATION=us-west1
GOOGLE_APPLICATION_CREDENTIALS=/path/to/backend/backend-sa-key.json

# API
SECRET_KEY=local-dev-secret-key-change-in-production
LOG_LEVEL=DEBUG

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:8000
```

---

## ☁️ CLOUD PRODUCTION ENVIRONMENT (GCP)

### Project Configuration

| Resource | Value |
|----------|-------|
| **Project ID** | `adk-rag-ma` |
| **Project Number** | `351592762922` |
| **Region** | `us-west1` |
| **Organization Domain** | `develom.com` |
| **Admin User** | `hector@develom.com` |
| **Account Environment** | `agent1` |

### Cloud SQL (PostgreSQL)

| Resource | Value |
|----------|-------|
| **Instance Name** | `adk-multi-agents-db` |
| **Connection Name** | `adk-rag-ma:us-west1:adk-multi-agents-db` |
| **Database Name** | `adk_agents_db` |
| **Database User** | `adk_app_user` |
| **Database Password** | (stored in Secret Manager) |
| **Unix Socket Path** | `/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db` |
| **Database Version** | PostgreSQL 15 |
| **Tier** | `db-f1-micro` |

### Cloud Run Services

| Service | URL | Region |
|---------|-----|--------|
| **Backend** | `https://backend-351592762922.us-west1.run.app` | us-west1 |
| **Frontend** | `https://frontend-351592762922.us-west1.run.app` | us-west1 |
| **IAP URL** | `https://34.49.46.115.nip.io` | us-west1 |

### Artifact Registry

| Resource | Value |
|----------|-------|
| **Repository Name** | `cloud-run-repo1` |
| **Repository URL** | `us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1` |
| **Backend Image** | `us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/backend:<tag>` |
| **Frontend Image** | `us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/frontend:<tag>` |

### Cloud Storage Buckets

| Bucket Name | Purpose |
|-------------|---------|
| `ipad-book-collection` | Document storage for RAG |
| `develom-documents` | Document storage for RAG |

### Vertex AI RAG

| Resource | Value |
|----------|-------|
| **Location** | `us-west1` |
| **Corpora** | (Managed via Vertex AI RAG Engine) |
| **API Endpoint** | `us-west1-aiplatform.googleapis.com` |

### Service Accounts

| Service Account | Purpose |
|-----------------|---------|
| `backend-sa@adk-rag-ma.iam.gserviceaccount.com` | Backend service identity |
| `frontend-sa@adk-rag-ma.iam.gserviceaccount.com` | Frontend service identity |
| Cloud Run default SA | Default Cloud Run execution |
| Cloud SQL client | Database connections |

### Secret Manager Secrets

| Secret Name | Purpose |
|-------------|---------|
| `db-password` | Cloud SQL database password |
| `jwt-secret-key` | JWT token signing |

### IAP / OAuth Configuration

| Resource | Value |
|----------|-------|
| **OAuth Client** | Configured in Cloud Console |
| **IAP Backend** | Enabled on Load Balancer |
| **Protected URL** | `https://34.49.46.115.nip.io` |
| **Authorized Domain** | `develom.com` |

### Cloud Environment Variables

```bash
# Database
DB_HOST=/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db
DB_NAME=adk_agents_db
DB_USER=adk_app_user
DB_PASSWORD=<from-secret-manager>
CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db

# Vertex AI
PROJECT_ID=adk-rag-ma
GOOGLE_CLOUD_LOCATION=us-west1
VERTEXAI_LOCATION=us-west1

# Application
ENVIRONMENT=production
ACCOUNT_ENV=agent1
FRONTEND_URL=https://34.49.46.115.nip.io
```

---

## 📊 Comparison Table

| Resource | Local | Cloud |
|----------|-------|-------|
| **Database Type** | Docker PostgreSQL | Cloud SQL PostgreSQL |
| **DB Instance** | `adk-postgres-dev` | `adk-multi-agents-db` |
| **DB Name** | `adk_agents_db_dev` | `adk_agents_db` |
| **DB User** | `adk_dev_user` | `adk_app_user` |
| **DB Port** | `5433` | Unix socket |
| **Backend URL** | `http://localhost:8000` | `https://backend-351592762922.us-west1.run.app` |
| **Frontend URL** | `http://localhost:3000` | `https://34.49.46.115.nip.io` |
| **Auth** | Username/Password | IAP + Username/Password |
| **SSL** | None | Managed Certificates |
| **Scaling** | Single instance | Auto-scaling |
| **Logs** | `backend.log` / console | Cloud Logging |

---

## 📁 Configuration Files Reference

| File | Environment | Purpose |
|------|-------------|---------|
| `backend/.env.local` | Local | Backend environment variables |
| `backend/docker-compose.dev.yml` | Local | PostgreSQL Docker config |
| `deployment.config` | Cloud | Deployment configuration |
| `infrastructure/deploy-config.sh` | Cloud | Configuration management |
| `infrastructure/deploy-init.sh` | Cloud | Initial deployment script |

---

## 🔑 Test Credentials

### Local Development

| Username | Password | Role |
|----------|----------|------|
| alice | alice123 | Standard |
| bob | bob123 | Standard |

### Cloud Production

| Authentication | Method |
|----------------|--------|
| IAP Users | Google OAuth via `develom.com` |
| Local Users | Username/password (alice/alice123) |

---

## 📝 Notes

1. **No SQLite**: Both environments use PostgreSQL exclusively
2. **Vertex AI**: Local development uses cloud Vertex AI resources (requires service account key)
3. **GCS Buckets**: Document storage is always in cloud, even for local development
4. **Service Account Key**: Required for local development to access Vertex AI
