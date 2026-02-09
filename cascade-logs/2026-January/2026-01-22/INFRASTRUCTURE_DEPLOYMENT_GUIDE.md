# Infrastructure Deployment Process - Complete Guide

**Author:** Cascade AI  
**Date:** January 22, 2026  
**Purpose:** Comprehensive guide to replicate the infrastructure deployment process in any repository

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Required Files and Structure](#required-files-and-structure)
4. [Step-by-Step Deployment Process](#step-by-step-deployment-process)
5. [Configuration Reference](#configuration-reference)
6. [Deployment Scripts Explained](#deployment-scripts-explained)
7. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Google Cloud Platform                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │        External HTTPS Load Balancer                  │   │
│  │  - Static IP Address                                 │   │
│  │  - SSL Certificate (nip.io domain)                  │   │
│  │  - Path-based routing                                │   │
│  └───────┬──────────────────────────────┬───────────────┘   │
│          │                               │                    │
│          │ /api/*                        │ / (root)          │
│          │ /agent1/api/*                 │                    │
│          │ /agent2/api/*                 │                    │
│          │ /agent3/api/*                 │                    │
│          ↓                               ↓                    │
│  ┌──────────────────┐          ┌──────────────────┐         │
│  │   Cloud Run      │          │   Cloud Run      │         │
│  │   Backend        │          │   Frontend       │         │
│  │                  │          │                  │         │
│  │  - backend       │          │  - frontend      │         │
│  │  - backend-agent1│          │                  │         │
│  │  - backend-agent2│          │  (Next.js app)   │         │
│  │  - backend-agent3│          │                  │         │
│  │                  │          │                  │         │
│  │  (FastAPI apps)  │          └──────────────────┘         │
│  └──────────────────┘                                        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │        Supporting Infrastructure                      │  │
│  │                                                       │  │
│  │  - Cloud Build (image building)                     │  │
│  │  - Artifact Registry (container images)             │  │
│  │  - Secret Manager (secrets)                         │  │
│  │  - Cloud SQL (PostgreSQL database)                  │  │
│  │  - Vertex AI (RAG/LLM services)                     │  │
│  │  - IAP (Identity-Aware Proxy) - Optional           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Traffic Flow

1. **User Request** → `https://34.49.46.115.nip.io/`
2. **Load Balancer** receives request on port 443 (HTTPS)
3. **SSL Termination** at load balancer
4. **Path-based routing:**
   - `/` → Frontend Cloud Run service
   - `/api/*` → Backend Cloud Run service
   - `/agent1/api/*` → Backend-agent1 Cloud Run service
   - `/agent2/api/*` → Backend-agent2 Cloud Run service
   - `/agent3/api/*` → Backend-agent3 Cloud Run service
5. **Cloud Run** processes request and returns response
6. **Load Balancer** returns response to user

---

## Prerequisites

### 1. Google Cloud Account Setup

```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Authenticate
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR-PROJECT-ID
```

### 2. Required Tools

- **gcloud CLI** (version 400.0.0+)
- **Docker** (for local testing)
- **git** (for version tracking)
- **Python 3.12+** (for backend)
- **Node.js 18+** (for frontend)

### 3. Google Cloud APIs to Enable

```bash
PROJECT_ID="your-project-id"

gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  compute.googleapis.com \
  iap.googleapis.com \
  secretmanager.googleapis.com \
  sqladmin.googleapis.com \
  aiplatform.googleapis.com \
  --project=$PROJECT_ID
```

### 4. IAM Permissions Required

Your deployment user needs these roles:
- `roles/run.admin` - Cloud Run administration
- `roles/compute.admin` - Load balancer management
- `roles/cloudbuild.builds.editor` - Build image permissions
- `roles/artifactregistry.admin` - Container registry access
- `roles/iam.serviceAccountUser` - Service account usage
- `roles/secretmanager.admin` - Secrets management

---

## Required Files and Structure

### Repository Structure

```
your-repo/
├── backend/
│   ├── src/
│   │   └── (your backend code)
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   └── (your frontend code)
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   ├── package.json
│   └── next.config.js
├── infrastructure/
│   ├── lib/
│   │   ├── cloudrun.sh
│   │   ├── loadbalancer.sh
│   │   ├── infrastructure.sh
│   │   └── utils.sh
│   ├── deploy-init.sh
│   ├── deploy-config.sh
│   └── deploy-all.sh
├── deploy-with-tests.sh
├── deployment.config
└── README.md
```

---

## Step-by-Step Deployment Process

### Phase 1: Initial Setup (One-Time)

#### Step 1.1: Create Deployment Configuration

Create `deployment.config` file:

```bash
#!/bin/bash
# Deployment Configuration

# Core Configuration
export PROJECT_ID="your-project-id"
export REGION="us-west1"
export ORGANIZATION_DOMAIN="yourdomain.com"
export IAP_ADMIN_USER="admin@yourdomain.com"
export REPO="cloud-run-repo1"

# Derived Configuration
export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
export BACKEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/backend:$(git rev-parse --short HEAD 2>/dev/null || echo 'manual')"
export FRONTEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/frontend:$(git rev-parse --short HEAD 2>/dev/null || echo 'manual')"
```

#### Step 1.2: Run Infrastructure Initialization

```bash
./infrastructure/deploy-init.sh \
  --project-id=your-project-id \
  --region=us-west1
```

**This script does:**
1. Authenticates with Google Cloud
2. Creates/verifies project exists
3. Links billing account
4. Enables required APIs
5. Creates service accounts
6. Sets up initial IAM permissions
7. Saves configuration to `deployment.config`

#### Step 1.3: Create Artifact Registry

```bash
source ./deployment.config

gcloud artifacts repositories create $REPO \
  --repository-format=docker \
  --location=$REGION \
  --description="Container registry for application images" \
  --project=$PROJECT_ID
```

#### Step 1.4: Set Up Secrets (Optional but Recommended)

```bash
./setup-secrets.sh
```

**Creates:**
- Database connection strings
- API keys
- JWT secrets
- Service account keys

---

### Phase 2: Container Image Configuration

#### Step 2.1: Backend Dockerfile

Create `backend/Dockerfile`:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Run application
CMD ["uvicorn", "src.api.server:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### Step 2.2: Backend Cloud Build Configuration

Create `backend/cloudbuild.yaml`:

```yaml
steps:
  # Security scan
  - name: 'python:3.12-slim'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        pip install bandit[toml]
        bandit -r src -f json -o bandit-report.json || true
        cat bandit-report.json
    dir: '.'
    
  # Build Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '--no-cache', '-t', '${_BACKEND_IMAGE}', '.']
    dir: '.'
  # Required for vulnerability scan 
  # SonarQube OWASP
  # 508 Compliance
  # USDA - provided
  # Vulnerability scan
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        gcloud container images scan ${_BACKEND_IMAGE} --format='value(discovery.analysisKind)' || true
        
images:
  - '${_BACKEND_IMAGE}'
  
substitutions:
  _BACKEND_IMAGE: 'us-west1-docker.pkg.dev/PROJECT_ID/REPO/backend:latest'
  
options:
  logging: CLOUD_LOGGING_ONLY
  machineType: 'E2_HIGHCPU_8'
```

#### Step 2.3: Frontend Dockerfile

Create `frontend/Dockerfile`:

```dockerfile
FROM node:18-alpine AS base

# Install dependencies
FROM base AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

# Build application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build args for runtime configuration
ARG NEXT_PUBLIC_BACKEND_URL
ENV NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL

RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

# Copy built application
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
ENV PORT 3000

CMD ["node", "server.js"]
```

#### Step 2.4: Frontend Cloud Build Configuration

Create `frontend/cloudbuild.yaml`:

```yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: 
  - 'build'
  - '--build-arg'
  - 'NEXT_PUBLIC_BACKEND_URL=${_BACKEND_URL}'
  - '-t'
  - '${_IMAGE_NAME}'
  - '.'
- name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${_IMAGE_NAME}']
images:
- '${_IMAGE_NAME}'
```

---

### Phase 3: Cloud Run Deployment

#### Step 3.1: Deploy Backend Services

Create `infrastructure/lib/cloudrun.sh`:

```bash
#!/bin/bash

deploy_backend() {
    log_info "Building backend container image..."
    gcloud builds submit ./backend \
        --config=backend/cloudbuild.yaml \
        --substitutions=_BACKEND_IMAGE="$BACKEND_IMAGE" \
        --quiet

    log_success "Backend image built: $BACKEND_IMAGE"

    log_info "Deploying backend to Cloud Run..."
    gcloud run deploy backend \
        --image="$BACKEND_IMAGE" \
        --region="$REGION" \
        --service-account="$RAG_AGENT_SA" \
        --ingress=internal-and-cloud-load-balancing \
        --allow-unauthenticated \
        --cpu=1 \
        --memory=1Gi \
        --concurrency=80 \
        --min-instances=0 \
        --max-instances=10 \
        --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=$REGION" \
        --labels=app=your-app,role=backend \
        --quiet

    export BACKEND_URL=$(gcloud run services describe backend --region="$REGION" --format='value(status.url)')
    log_success "Backend deployed: $BACKEND_URL"
}

deploy_frontend() {
    log_info "Building frontend container image..."
    gcloud builds submit ./frontend \
        --config=frontend/cloudbuild.yaml \
        --substitutions=_IMAGE_NAME="$FRONTEND_IMAGE",_BACKEND_URL="$LOAD_BALANCER_URL" \
        --quiet
    
    log_success "Frontend image built: $FRONTEND_IMAGE"
    
    log_info "Deploying frontend to Cloud Run..."
    gcloud run deploy frontend \
        --image="$FRONTEND_IMAGE" \
        --region="$REGION" \
        --service-account="$FRONTEND_SA" \
        --ingress=internal-and-cloud-load-balancing \
        --allow-unauthenticated \
        --cpu=1 \
        --memory=512Mi \
        --concurrency=80 \
        --min-instances=0 \
        --max-instances=5 \
        --labels=app=your-app,role=frontend \
        --quiet
    
    export FRONTEND_URL=$(gcloud run services describe frontend --region="$REGION" --format='value(status.url)')
    log_success "Frontend deployed: $FRONTEND_URL"
}
```

**Key Cloud Run Configuration Options:**

- `--ingress=internal-and-cloud-load-balancing`: Only accessible via load balancer (not public internet)
- `--allow-unauthenticated`: Allow unauthenticated requests (IAP handles auth at load balancer level)
- `--cpu=1`: 1 vCPU per instance
- `--memory=1Gi`: Memory allocation
- `--concurrency=80`: Max concurrent requests per instance
- `--min-instances=0`: Scale to zero when idle
- `--max-instances=10`: Maximum scale out

---

### Phase 4: Load Balancer Setup

#### Step 4.1: Create Static IP Address

```bash
# Create global static IP
gcloud compute addresses create your-app-ip --global --quiet

# Get the IP address
STATIC_IP=$(gcloud compute addresses describe your-app-ip --global --format="value(address)")
export LOAD_BALANCER_URL="https://$STATIC_IP.nip.io"

echo "Load Balancer URL: $LOAD_BALANCER_URL"
```

#### Step 4.2: Create SSL Certificate

```bash
# Create managed SSL certificate for nip.io domain
gcloud compute ssl-certificates create your-app-ssl-cert \
    --domains="$STATIC_IP.nip.io" \
    --global \
    --quiet

# Note: Provisioning takes 10-15 minutes
```

**Why nip.io?**
- Free wildcard DNS service
- `34.49.46.115.nip.io` resolves to `34.49.46.115`
- Google automatically provisions SSL certificate
- No domain purchase required

#### Step 4.3: Create Network Endpoint Groups (NEGs)

NEGs connect Cloud Run services to the load balancer:

```bash
# Frontend NEG
gcloud compute network-endpoint-groups create frontend-neg \
    --region="$REGION" \
    --network-endpoint-type=serverless \
    --cloud-run-service=frontend \
    --quiet

# Backend NEG
gcloud compute network-endpoint-groups create backend-neg \
    --region="$REGION" \
    --network-endpoint-type=serverless \
    --cloud-run-service=backend \
    --quiet

# Additional backend services (if multi-agent)
gcloud compute network-endpoint-groups create backend-agent1-neg \
    --region="$REGION" \
    --network-endpoint-type=serverless \
    --cloud-run-service=backend-agent1 \
    --quiet
```

#### Step 4.4: Create Backend Services

Backend services define how traffic is routed to NEGs:

```bash
# Frontend backend service
gcloud compute backend-services create frontend-backend-service \
    --global \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --protocol=HTTP \
    --port-name=http \
    --quiet

# Attach NEG to backend service
gcloud compute backend-services add-backend frontend-backend-service \
    --global \
    --network-endpoint-group=frontend-neg \
    --network-endpoint-group-region="$REGION" \
    --quiet

# Backend backend service
gcloud compute backend-services create backend-backend-service \
    --global \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --protocol=HTTP \
    --port-name=http \
    --quiet

gcloud compute backend-services add-backend backend-backend-service \
    --global \
    --network-endpoint-group=backend-neg \
    --network-endpoint-group-region="$REGION" \
    --quiet
```

#### Step 4.5: Create URL Map (Path-based Routing)

```bash
# Create URL map with default service
gcloud compute url-maps create your-app-url-map \
    --default-service=frontend-backend-service \
    --global \
    --quiet

# Add path-based routing
gcloud compute url-maps add-path-matcher your-app-url-map \
    --path-matcher-name=api-matcher \
    --default-service=frontend-backend-service \
    --path-rules="/api/*=backend-backend-service,/agent1/api/*=backend-agent1-backend-service" \
    --global \
    --quiet
```

**Routing Rules:**
- `/` → Frontend (default)
- `/api/*` → Backend
- `/agent1/api/*` → Backend-agent1
- Everything else → Frontend

#### Step 4.6: Create HTTPS Proxy

```bash
gcloud compute target-https-proxies create your-app-https-proxy \
    --ssl-certificates=your-app-ssl-cert \
    --url-map=your-app-url-map \
    --global \
    --quiet
```

#### Step 4.7: Create Forwarding Rule

```bash
gcloud compute forwarding-rules create your-app-forwarding-rule \
    --address=your-app-ip \
    --target-https-proxy=your-app-https-proxy \
    --global \
    --ports=443 \
    --quiet
```

**This is the final step that makes your load balancer live!**

---

### Phase 5: Deployment Automation

#### Step 5.1: Create Comprehensive Deployment Script

Create `deploy-with-tests.sh`:

```bash
#!/bin/bash

set -e

# Configuration
PROJECT_ID="your-project-id"
REGION="us-west1"
BACKEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/cloud-run-repo1/backend"
FRONTEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/cloud-run-repo1/frontend"
LOAD_BALANCER_URL="https://YOUR-IP.nip.io"

# Build images with timestamp tag
build_images() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local git_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local image_tag="${timestamp}-${git_sha}"
    
    echo "Building backend image with tag: $image_tag"
    gcloud builds submit ./backend \
        --config=backend/cloudbuild.yaml \
        --substitutions=_BACKEND_IMAGE="${BACKEND_IMAGE}:${image_tag}" \
        --project=$PROJECT_ID
    
    echo "Building frontend image with tag: $image_tag"
    gcloud builds submit ./frontend \
        --config=frontend/cloudbuild.yaml \
        --substitutions=_IMAGE_NAME="${FRONTEND_IMAGE}:${image_tag}",_BACKEND_URL="$LOAD_BALANCER_URL" \
        --project=$PROJECT_ID
    
    echo "$image_tag" > .last_deployment_tag
    echo "Images built successfully with tag: $image_tag"
}

# Deploy services
deploy_services() {
    local image_tag=$(cat .last_deployment_tag)
    
    echo "Deploying backend services with image tag: $image_tag"
    
    gcloud run services update backend \
        --image="${BACKEND_IMAGE}:${image_tag}" \
        --region=$REGION \
        --project=$PROJECT_ID \
        --quiet
    
    echo "Deploying frontend service"
    gcloud run services update frontend \
        --image="${FRONTEND_IMAGE}:${image_tag}" \
        --region=$REGION \
        --project=$PROJECT_ID \
        --quiet
    
    echo "All services deployed successfully"
}

# Run smoke tests
run_smoke_tests() {
    echo "Waiting for services to be ready..."
    sleep 60
    
    echo "Running smoke tests..."
    
    if curl -f -s "$LOAD_BALANCER_URL/api/health" > /dev/null; then
        echo "✅ API health check passed"
    else
        echo "❌ API health check failed"
        exit 1
    fi
}

# Main execution
main() {
    echo "Starting deployment process..."
    
    build_images
    deploy_services
    run_smoke_tests
    
    echo "Deployment completed successfully!"
    echo "Application URL: $LOAD_BALANCER_URL"
}

main
```

Make it executable:
```bash
chmod +x deploy-with-tests.sh
```

---

## Configuration Reference

### Environment Variables Required

**Backend Environment Variables:**
```bash
PROJECT_ID=your-project-id
GOOGLE_CLOUD_LOCATION=us-west1
VERTEXAI_PROJECT=your-project-id
VERTEXAI_LOCATION=us-west1
SECRET_KEY=your-secret-key
DATABASE_PATH=/app/data/users.db
LOG_LEVEL=INFO
ENVIRONMENT=production
ROOT_PATH=""  # or /agent1, /agent2, etc.
```

**Frontend Environment Variables:**
```bash
NEXT_PUBLIC_BACKEND_URL=https://YOUR-IP.nip.io
NODE_ENV=production
PORT=3000
```

### Service Account Configuration

**Backend Service Account Permissions:**
- `roles/aiplatform.user` - Vertex AI access
- `roles/cloudsql.client` - Cloud SQL access
- `roles/secretmanager.secretAccessor` - Secret Manager access

**Frontend Service Account Permissions:**
- Minimal permissions (only needs to serve static content)

---

## Deployment Scripts Explained

### Script Hierarchy

```
deploy-with-tests.sh (Main deployment script)
├── Runs: build_images()
│   └── Calls: gcloud builds submit (backend & frontend)
├── Runs: deploy_services()
│   └── Calls: gcloud run services update
└── Runs: run_smoke_tests()
    └── Calls: curl health checks
```

### Key Functions

**1. build_images()**
- Creates unique image tags (timestamp + git SHA)
- Submits builds to Cloud Build
- Stores tag for deployment tracking

**2. deploy_services()**
- Updates Cloud Run services with new images
- Maintains zero-downtime deployment
- Automatically rolls traffic to new revision

**3. run_smoke_tests()**
- Verifies deployment health
- Tests each endpoint
- Fails deployment if tests fail

---

## Troubleshooting

### Common Issues and Solutions

#### 1. SSL Certificate Not Provisioning

**Symptom:** Certificate shows "PROVISIONING" status for >30 minutes

**Solution:**
```bash
# Check certificate status
gcloud compute ssl-certificates describe your-app-ssl-cert --global

# Wait up to 60 minutes for Google to provision
# nip.io domains are validated automatically
```

#### 2. Cloud Run Service Not Accessible via Load Balancer

**Symptom:** 502 Bad Gateway or 404 errors

**Check:**
```bash
# Verify NEG is healthy
gcloud compute network-endpoint-groups list --filter="name~backend"

# Check backend service health
gcloud compute backend-services get-health backend-backend-service --global

# Verify Cloud Run service is running
gcloud run services describe backend --region=us-west1 --format="value(status.url)"
```

**Solution:**
- Ensure `--ingress=internal-and-cloud-load-balancing` is set
- Verify NEG is attached to backend service
- Check Cloud Run logs for errors

#### 3. Image Build Failures

**Symptom:** Cloud Build fails with permissions error

**Solution:**
```bash
# Grant Cloud Build service account permissions
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"
```

#### 4. Environment Variables Not Set

**Symptom:** Application crashes or features don't work

**Solution:**
```bash
# Update Cloud Run service with correct env vars
gcloud run services update backend \
    --region=us-west1 \
    --update-env-vars="PROJECT_ID=$PROJECT_ID,REGION=$REGION" \
    --quiet
```

---

## Quick Deployment Commands

### Full Deployment (First Time)

```bash
# 1. Initialize infrastructure
./infrastructure/deploy-init.sh --project-id=your-project-id --region=us-west1

# 2. Set up load balancer and Cloud Run
./infrastructure/deploy-all.sh

# 3. Done! Check your LOAD_BALANCER_URL
```

### Update Deployment (After Changes)

```bash
# Deploy with tests
./deploy-with-tests.sh

# Or quick deploy without tests
./deploy-with-tests.sh deploy
```

### Rollback to Previous Version

```bash
./deploy-with-tests.sh rollback
```

---

## Summary

### The Complete Flow

1. **Initial Setup** (Once)
   - Create project and enable APIs
   - Create Artifact Registry
   - Set up service accounts

2. **Build Images**
   - Backend: Python FastAPI app → Docker image
   - Frontend: Next.js app → Docker image
   - Push to Artifact Registry

3. **Deploy to Cloud Run**
   - Backend services (can have multiple)
   - Frontend service
   - All behind load balancer

4. **Configure Load Balancer**
   - Create static IP
   - Create SSL certificate
   - Set up NEGs (connect Cloud Run to LB)
   - Create backend services
   - Configure URL map (path routing)
   - Create HTTPS proxy
   - Create forwarding rule

5. **Access Application**
   - `https://YOUR-IP.nip.io` → Ready!

### Key Benefits of This Architecture

✅ **Scalable:** Auto-scales from 0 to max instances  
✅ **Secure:** HTTPS with auto-provisioned SSL  
✅ **Cost-effective:** Pay only for what you use  
✅ **Zero-downtime:** Rolling updates  
✅ **Path-based routing:** Multiple backends on one domain  
✅ **Production-ready:** Load balancer handles traffic distribution  

---

**End of Guide**
