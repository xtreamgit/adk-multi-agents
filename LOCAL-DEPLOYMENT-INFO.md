# Local Deployment Guide - ADK Multi-Agents

**Last Updated:** January 29, 2026  
**Database:** PostgreSQL ONLY (SQLite has been completely removed)

---

## Overview

This guide provides detailed procedures for running the ADK Multi-Agents application locally for development and testing. The application consists of:

- **Backend:** FastAPI server with Vertex AI RAG integration
- **Frontend:** Next.js React application
- **Database:** PostgreSQL (via Docker)

> **IMPORTANT:** This application uses PostgreSQL exclusively. SQLite support was removed on January 28, 2026. See `docs/POSTGRESQL_ONLY.md` for details.

---

## Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| Docker Desktop | Latest | Run PostgreSQL database |
| Python | 3.11+ | Backend runtime |
| Node.js | 18+ | Frontend runtime |
| npm | 9+ | Frontend package manager |
| Git | Latest | Version control |

### Google Cloud Requirements

For full functionality (Vertex AI RAG), you need:

1. **GCP Project:** `adk-rag-ma` (or your project)
2. **Service Account Key:** `backend/backend-sa-key.json`
3. **Enabled APIs:** Vertex AI, Cloud Storage, BigQuery

---

## Quick Start

### One-Command Setup (After Initial Configuration)

```bash
# Terminal 1: Start database
cd backend && ./scripts/start-dev-db.sh

# Terminal 2: Start backend
cd backend && ./start-backend.sh

# Terminal 3: Start frontend
cd frontend && npm run dev
```

Access the application at: **http://localhost:3000**

---

## Detailed Setup Procedures

### Step 1: Clone and Navigate

```bash
git clone https://github.com/xtreamgit/adk-multi-agents.git
cd adk-multi-agents
```

### Step 2: Start PostgreSQL Database

The application uses Docker to run PostgreSQL locally.

```bash
cd backend

# Start PostgreSQL container
./scripts/start-dev-db.sh
```

**What this does:**
- Starts PostgreSQL 15 in Docker
- Creates database: `adk_agents_db_dev`
- Creates user: `adk_dev_user`
- Exposes port: `5433` (to avoid conflicts with local PostgreSQL)
- Initializes schema from `init_postgresql_schema.sql`

**Verify database is running:**
```bash
docker ps | grep adk-postgres-dev
```

**Expected output:**
```
CONTAINER ID   IMAGE         STATUS         PORTS                    NAMES
abc123...      postgres:15   Up (healthy)   0.0.0.0:5433->5432/tcp   adk-postgres-dev
```

**Manual connection test:**
```bash
psql -h localhost -p 5433 -U adk_dev_user -d adk_agents_db_dev
# Password: dev_password_123
```

### Step 3: Configure Backend Environment

The backend uses `.env.local` for configuration.

**File:** `backend/.env.local`

```bash
# Local Development Environment Configuration
# Use with Docker PostgreSQL container

# Database Configuration (PostgreSQL only)
DB_HOST=localhost
DB_PORT=5433
DB_NAME=adk_agents_db_dev
DB_USER=adk_dev_user
DB_PASSWORD=dev_password_123
ENVIRONMENT=local

# Vertex AI Configuration
PROJECT_ID=adk-rag-ma
VERTEX_AI_LOCATION=us-west1
GOOGLE_APPLICATION_CREDENTIALS=/Users/hector/github.com/xtreamgit/adk-multi-agents/backend/backend-sa-key.json

# API Configuration
SECRET_KEY=local-dev-secret-key-change-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Logging
LOG_LEVEL=DEBUG

# CORS (for local frontend development)
CORS_ORIGINS=http://localhost:3000,http://localhost:8000
```

> **Note:** Update `GOOGLE_APPLICATION_CREDENTIALS` to your actual path.

### Step 4: Set Up Backend Python Environment

```bash
cd backend

# Create virtual environment
python -m venv .venv

# Activate virtual environment
source .venv/bin/activate  # macOS/Linux
# or
.venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt
```

### Step 5: Start Backend Server

**Option A: Using startup script (recommended)**
```bash
cd backend
./start-backend.sh
```

**Option B: Manual start**
```bash
cd backend
source .venv/bin/activate
python -m uvicorn src.api.server:app --reload --port 8000
```

**Backend will:**
1. Auto-load `.env.local` via python-dotenv
2. Connect to PostgreSQL on localhost:5433
3. Initialize database schema if needed
4. Load Vertex AI agent configuration
5. Start FastAPI server on http://localhost:8000

**Verify backend is running:**
```bash
curl http://localhost:8000/api/health
```

**Expected response:**
```json
{
  "status": "healthy",
  "database": "connected",
  "agent": "loaded",
  ...
}
```

### Step 6: Set Up Frontend

```bash
cd frontend

# Install dependencies
npm install
```

### Step 7: Configure Frontend Environment

Create `frontend/.env.local`:

```bash
# Backend API URL for local development
NEXT_PUBLIC_BACKEND_URL=http://localhost:8000
```

### Step 8: Start Frontend Server

```bash
cd frontend
npm run dev
```

**Frontend will:**
1. Start Next.js development server with Turbopack
2. Enable hot module replacement
3. Serve on http://localhost:3000

**Access the application:**
- **Main App:** http://localhost:3000
- **Login:** Use test credentials (alice/alice123) or register new user

---

## Database Configuration Details

### PostgreSQL Docker Container

**Configuration file:** `backend/docker-compose.dev.yml`

```yaml
version: '3.8'

services:
  postgres-dev:
    image: postgres:15
    container_name: adk-postgres-dev
    environment:
      POSTGRES_DB: adk_agents_db_dev
      POSTGRES_USER: adk_dev_user
      POSTGRES_PASSWORD: dev_password_123
    ports:
      - "5433:5432"
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
      - ./init_postgresql_schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U adk_dev_user -d adk_agents_db_dev"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - adk-dev-network

volumes:
  postgres_dev_data:
    driver: local

networks:
  adk-dev-network:
    driver: bridge
```

### Database Schema

Schema is defined in `backend/init_postgresql_schema.sql` and includes:

| Table | Purpose |
|-------|---------|
| `users` | User accounts (local and IAP) |
| `user_profiles` | User preferences and settings |
| `groups` | User groups for access control |
| `user_groups` | User-group membership |
| `roles` | Permission roles |
| `group_roles` | Group-role assignments |
| `agents` | AI agent configurations |
| `corpora` | RAG corpus definitions |
| `group_corpus_access` | Corpus access permissions |
| `user_sessions` | Active user sessions |
| `chat_sessions` | Chat history sessions |
| `user_stats` | User statistics |

### Database Management Commands

```bash
# Start database
cd backend && docker-compose -f docker-compose.dev.yml up -d

# Stop database
cd backend && docker-compose -f docker-compose.dev.yml down

# View logs
docker logs adk-postgres-dev

# Connect to database
psql -h localhost -p 5433 -U adk_dev_user -d adk_agents_db_dev

# Reset database (delete all data)
cd backend && docker-compose -f docker-compose.dev.yml down -v
cd backend && docker-compose -f docker-compose.dev.yml up -d
```

---

## Service Architecture

### Local Development Ports

| Service | Port | URL |
|---------|------|-----|
| Frontend | 3000 | http://localhost:3000 |
| Backend | 8000 | http://localhost:8000 |
| PostgreSQL | 5433 | localhost:5433 |

### API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Health check |
| `POST /api/auth/login` | User login |
| `POST /api/auth/register` | User registration |
| `GET /api/auth/verify` | Token verification |
| `POST /api/sessions` | Create chat session |
| `POST /api/sessions/{id}/chat` | Send message |
| `GET /api/corpora` | List corpora |
| `GET /api/admin/*` | Admin endpoints |

---

## Test Credentials

Default test users (seeded on startup):

| Username | Password | Role |
|----------|----------|------|
| alice | alice123 | Standard user |
| bob | bob123 | Standard user |
| hector | (IAP user) | Admin |

---

## Troubleshooting

### Database Connection Failed

**Symptoms:** Backend fails to start with PostgreSQL connection error

**Solutions:**
1. Verify Docker is running: `docker ps`
2. Check PostgreSQL container: `docker ps | grep adk-postgres-dev`
3. Restart database: `docker-compose -f docker-compose.dev.yml restart`
4. Check logs: `docker logs adk-postgres-dev`

### Backend Won't Start

**Symptoms:** Python errors on startup

**Solutions:**
1. Ensure virtual environment is activated: `source .venv/bin/activate`
2. Verify dependencies: `pip install -r requirements.txt`
3. Check `.env.local` exists and has correct values
4. Verify service account key path

### Frontend API Errors

**Symptoms:** "Failed to fetch" or CORS errors

**Solutions:**
1. Verify backend is running: `curl http://localhost:8000/api/health`
2. Check `frontend/.env.local` has correct `NEXT_PUBLIC_BACKEND_URL`
3. Restart frontend after env changes
4. Clear browser cache

### Vertex AI Errors

**Symptoms:** RAG queries fail with authentication errors

**Solutions:**
1. Verify service account key exists and path is correct
2. Check GCP project ID matches
3. Ensure Vertex AI API is enabled
4. Verify service account has required permissions

---

## Comparison: Local vs Production

| Aspect | Local Development | Cloud Production |
|--------|-------------------|------------------|
| Database | Docker PostgreSQL (port 5433) | Cloud SQL PostgreSQL |
| Auth | Username/password | IAP + Username/password |
| Backend URL | http://localhost:8000 | https://34.49.46.115.nip.io |
| Frontend URL | http://localhost:3000 | https://34.49.46.115.nip.io |
| SSL | None | Managed certificates |
| Scaling | Single instance | Auto-scaling |

---

## File Reference

### Key Configuration Files

| File | Purpose |
|------|---------|
| `backend/.env.local` | Backend environment variables |
| `backend/docker-compose.dev.yml` | PostgreSQL Docker config |
| `backend/init_postgresql_schema.sql` | Database schema |
| `frontend/.env.local` | Frontend environment variables |

### Startup Scripts

| Script | Purpose |
|--------|---------|
| `backend/scripts/start-dev-db.sh` | Start PostgreSQL |
| `backend/start-backend.sh` | Start backend server |

### Database Files

| File | Purpose |
|------|---------|
| `backend/src/database/connection.py` | PostgreSQL connection management |
| `backend/src/database/schema_init.py` | Schema initialization |
| `backend/src/database/migrations/*.sql` | Migration files |

---

## Summary

✅ **PostgreSQL Only:** No SQLite support  
✅ **Docker Database:** Easy setup with docker-compose  
✅ **Auto-Configuration:** `.env.local` loaded automatically  
✅ **Schema Initialization:** Automatic on startup  
✅ **Hot Reload:** Both backend and frontend support hot reload

For production deployment, see `README.md` and `docs/` folder.
