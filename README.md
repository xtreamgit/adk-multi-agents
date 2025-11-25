# ADK RAG Agent - Google Cloud Deployment

<sub>
**Author:** Hector DeJesus  
**Purpose:** Enterprise RAG (Retrieval Augmented Generation) Agent with OAuth-protected deployment on Google Cloud Platform  
**Date:** October 14, 2025  
**Repository:** https://github.com/xtreamgit/adk-rag-agent  
**Version:** 1.0.0  
**Status:** Production Ready ✅  
**Branch:** main | develop
</sub>

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Deployment Guide](#deployment-guide)
- [Configuration Management](#configuration-management)
- [Security Features](#security-features)
- [Version Management](#version-management)
- [Troubleshooting](#troubleshooting)
- [Agent Capabilities](#agent-capabilities)
- [Maintenance & Updates](#maintenance--updates)
- [Additional Resources](#additional-resources)

---

## Overview

This repository contains a production-ready Google Agent Development Kit (ADK) implementation of a RAG agent using Google Cloud Vertex AI. The application features:

- **Modern Web Interface**: React-based frontend with authentication and chat interface
- **Secure OAuth Access**: Identity-Aware Proxy (IAP) with Google OAuth consent screen
- **Enterprise Security**: Two-layer protection (IAP + Cloud Run IAM) with Cloud Armor
- **Document Management**: Query multiple corpora, create/delete corpora, manage documents
- **User Authentication**: JWT-based session management with persistent storage
- **Load Balancer Architecture**: SSL/HTTPS with managed certificates

### Key Features

✅ **OAuth-Protected Access** - Organization-restricted access via Google IAP  
✅ **RAG Capabilities** - Query documents using Vertex AI RAG Engine  
✅ **Corpus Management** - Create, list, update, and delete document corpora  
✅ **Cloud Armor Security** - SQL injection, XSS, and DDoS protection  
✅ **Automated Deployment** - One-command deployment with comprehensive error handling  
✅ **Session Persistence** - User sessions maintained across browser refreshes  

---

## Architecture

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer                            │
│                https://YOUR-IP.nip.io                       │
│                   (SSL + IAP + OAuth)                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
              ┌───────┴────────┐
              │                │
              ▼                ▼
    ┌─────────────────┐  ┌─────────────────┐
    │    Frontend     │  │    Backend      │
    │   (Next.js)     │  │   (FastAPI)     │
    │                 │  │                 │
    │ Cloud Run       │  │ Cloud Run       │
    │ Service         │  │ Service         │
    └─────────────────┘  └─────────────────┘
              │                │
              └────────┬───────┘
                       │
              ┌────────▼────────┐
              │   Vertex AI     │
              │   RAG Engine    │
              │                 │
              │ • Gemini Models │
              │ • Corpora       │
              │ • GCS Storage   │
              └─────────────────┘
```

### Security Layers

1. **Load Balancer Level**: SSL/HTTPS encryption
2. **IAP Level**: Google OAuth authentication with organization restrictions
3. **Application Level**: JWT-based session management
4. **Cloud Armor**: DDoS, SQL injection, and XSS protection
5. **IAM Level**: Service account permissions with principle of least privilege

---

## Prerequisites

### Required Tools

- **Google Cloud Account** with billing enabled
- **Google Cloud CLI** (`gcloud`) installed and configured
- **Git** for cloning the repository
- **Python 3.11+** (for local development)
- **Node.js 18+** (for local development)
- **Docker** (optional, for local testing)

### Required Permissions

Your Google Cloud account must have:
- `Project Editor` or `Owner` role
- Ability to create projects (if deploying to new project)
- Billing account access

### Google Cloud APIs

The following APIs will be automatically enabled during deployment:
- Cloud Resource Manager API
- Identity-Aware Proxy API
- Cloud Run API
- Artifact Registry API
- Cloud Build API
- Compute Engine API
- Vertex AI API
- Cloud Storage API
- BigQuery API

---

## Deployment Guide

### Step 0: Clone Repository

```bash
git clone https://github.com/xtreamgit/adk-rag-agent.git
```

### Step 1: Configure Deployment Settings

Run the configuration script to set up your deployment parameters:

```bash
./infrastructure/deploy-config.sh --interactive
```

**You will be prompted for:**
- **Project ID**: Unique Google Cloud project identifier (e.g., `my-rag-agent-2025`)
- **Region**: Google Cloud region (e.g., `us-central1`, `us-east4`)
- **Organization Domain**: Your organization domain for IAP access (e.g., `mycompany.com`)
- **IAP Admin User**: Admin email address (e.g., `admin@mycompany.com`)
- **Repository**: Artifact Registry repository name (default: `cloud-run-repo1`)

**Output:** Creates `deployment.config` file with your settings.

**Alternative - Non-Interactive:**
```bash
./infrastructure/deploy-config.sh \
  --project=my-rag-2025 \
  --region=us-east4 \
  --domain=mycompany.com \
  --admin=admin@mycompany.com
```

---

### Step 2: Initialize Google Cloud Project

Run the initialization script log into the Google Cloud Console to create and configure your GCP project:

```bash
./infrastructure/deploy-init.sh
```

**This script will:**

1. ✅ **Load Configuration** - Reads from `deployment.config`
2. ✅ **Authenticate User** - Verifies `gcloud auth` and prompts for account confirmation
3. ✅ **Setup Application Default Credentials** - Runs `gcloud auth application-default login`
4. ✅ **Create Project** - Creates new GCP project or uses existing one
5. ✅ **Configure Billing** - Links billing account to project
6. ✅ **Enable APIs** - Enables all required Google Cloud APIs
7. ✅ **Set Default Region** - Configures default region and zone
8. ✅ **Update Configuration** - Updates `deployment.config` with project details

**Interactive Prompts:**
```
Is this the correct account? (y/n): y
Use these Application Default Credentials? (y/n): y

# If project exists:
Do you want to continue with the existing project? (y/n): n
Would you like to create a new project now? (y/n): y
Enter new Project ID: my-new-rag-project
Enter Region [default: us-central1]: us-east4
```

**Important Notes:**
- The script automatically sets `IAP_ADMIN_USER` to your authenticated Google account
- Organization domain is extracted from your email (e.g., `user@mycompany.com` → `mycompany.com`)
- Run without arguments to use `deployment.config` values
- Use `--project-id=NEW_ID` to override configuration

---

### Step 3: Update Backend Files

Update hardcoded project IDs and regions in backend source files:

```bash
./infrastructure/deploy-new-project-id.sh
```

**This script will:**

1. ✅ **Load Configuration** - Reads PROJECT_ID and REGION from `deployment.config`
2. ✅ **Scan Files** - Finds current project IDs and regions in backend files
3. ✅ **Create Backup** - Backs up files before modification
4. ✅ **Update Files** - Replaces old values with new configuration:
   - `backend/src/rag_agent/agent.py`
   - `backend/src/rag_agent/config.py`
   - `backend/Dockerfile`
   - `backend/cloudbuild.yaml`
5. ✅ **Verify Changes** - Confirms all updates were successful

**Files Updated:**
- Project ID references (e.g., `adk-rag-agent-2025` → `your-project-id`)
- Region references (e.g., `us-central1` → `your-region`)
- Docker registry URLs (e.g., `us-central1-docker.pkg.dev/old-project/...`)

**Manual Override (Optional):**
```bash
./infrastructure/deploy-new-project-id.sh my-custom-project us-west1
```

---

### Step 4: Configure OAuth Consent Screen

**⚠️ MANUAL STEP REQUIRED**

Before running the deployment script, configure the OAuth consent screen:

1. Go to: https://console.cloud.google.com/apis/credentials/consent
2. Select your project
3. Click **"Configure Consent Screen"**
4. Choose **"Internal"** (for organization users) or **"External"**
5. Fill in required fields:
   - **App name**: ADK RAG Agent
   - **User support email**: Your email
   - **Developer contact**: Your email
6. Click **"Save and Continue"**
7. Skip scopes (click **"Save and Continue"**)
8. Review and click **"Back to Dashboard"**

**Why This is Required:**
- IAP requires an OAuth consent screen to authenticate users
- Must be configured before OAuth clients can be created
- Cannot be automated via gcloud CLI

---

### Step 5: Generate Application Secret Key

**⚠️ MANUAL STEP REQUIRED**

Generate a secure secret key for JWT authentication:

```bash
python3 generate_secret_key.py
```

**Example Output:**
```
Generated SECRET_KEY: Xp8Qk********

To use this key, update your .env.yaml file:
SECRET_KEY: Xp8Qk********
```

**Create the secrets.env file:**

```bash
echo "SECRET_KEY=your-generated-key-from-above" > secrets.env
```

**Example:**
```bash
echo "SECRET_KEY=Xp8Qk********" > secrets.env
```

**Verify the file:**
```bash
cat secrets.env
# Output: SECRET_KEY=Xp8Qk********
```

**Important Notes:**
- The `secrets.env` file is required by `deploy-secure-v0.2.sh`
- This file is already in `.gitignore` and will not be committed
- Keep this key secure - it's used for JWT token generation
- If using `deploy-complete-oauth-v0.2.sh`, this step is **optional** but recommended

**Why This is Required:**
- Secures user authentication with JWT tokens
- Prevents token forgery and unauthorized access
- Required for session management in the application

---

### Step 6: Deploy Complete Application

Run the complete deployment script:

```bash
./infrastructure/deploy-complete-oauth-v0.2.sh
```

**Alternative - Using JWT Authentication with secrets.env:**

If you completed Step 5 and created `secrets.env`, you can use the secure deployment script:

```bash
./infrastructure/deploy-secure-v0.2.sh
```

This variant requires the `SECRET_KEY` from `secrets.env` and provides additional JWT token authentication.

---

**This comprehensive script performs:**

#### Phase 1: Infrastructure Setup
1. ✅ Loads configuration from `deployment.config`
2. ✅ Validates Google Cloud authentication
3. ✅ Verifies project and APIs are enabled
4. ✅ Creates Artifact Registry repository
5. ✅ Reserves static IP address
6. ✅ Provisions SSL certificate (domain: `YOUR-IP.nip.io`)

#### Phase 2: Service Deployment
7. ✅ Builds backend Docker image (FastAPI + Vertex AI)
8. ✅ Pushes backend to Artifact Registry
9. ✅ Deploys backend to Cloud Run
10. ✅ Builds frontend Docker image (Next.js)
11. ✅ Pushes frontend to Artifact Registry
12. ✅ Deploys frontend to Cloud Run

#### Phase 3: IAM Configuration
13. ✅ Creates service accounts for frontend and backend
14. ✅ Grants required IAM roles:
    - `roles/aiplatform.admin` - Vertex AI access
    - `roles/storage.admin` - GCS bucket access
    - `roles/bigquery.admin` - BigQuery access
15. ✅ Configures Cloud Run with service accounts

#### Phase 4: OAuth and IAP Setup
16. ✅ Creates OAuth client for IAP
17. ✅ Configures redirect URIs for Load Balancer
18. ✅ Enables IAP on backend services
19. ✅ Grants IAP access to admin user

#### Phase 5: Load Balancer Configuration
20. ✅ Creates health checks
21. ✅ Creates backend services (frontend + backend)
22. ✅ Configures URL routing (`/api/*` → backend, `/*` → frontend)
23. ✅ Attaches SSL certificate
24. ✅ Creates forwarding rules

#### Phase 6: CORS and Security Fix
25. ✅ Grants `allUsers` access to backend for Load Balancer routing
26. ✅ Sets `FRONTEND_URL` environment variable for CORS
27. ✅ Restarts services with new configuration

#### Phase 7: Validation
28. ✅ Waits for SSL certificate provisioning (10-15 minutes)
29. ✅ Tests HTTPS endpoint
30. ✅ Verifies IAP configuration
31. ✅ Checks CORS headers

**Deployment Time:** Approximately 15-20 minutes

**Output:**
```
🎉 Deployment completed successfully!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Deployment Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔗 Application URL:     https://##.##.##.##.nip.io
📦 Project ID:          your-project-id
🌍 Region:              us-east4
🔐 IAP Admin:           admin@yourcompany.com
🏢 Organization:        yourcompany.com

🔐 Security Configuration:
✅ IAP Enabled:         Yes
✅ OAuth Client:        123456789-abcdefgh.apps.googleusercontent.com
✅ SSL Certificate:     ACTIVE
✅ Access Control:      @yourcompany.com only

🚀 Next Steps:
1. Visit: https://YOUR-IP.nip.io
2. Authenticate with your Google account
3. Complete OAuth consent
4. Start using the RAG agent!
```

---

## Configuration Management

### deployment.config File

The `deployment.config` file is the single source of truth for your deployment:

```bash
#!/bin/bash
# ADK RAG Agent Deployment Configuration
# Generated on: Tue Oct  8 08:54:30 PDT 2025

# Core Configuration
export PROJECT_ID="adk-rag-hdtest6"
export REGION="us-east4"
export ORGANIZATION_DOMAIN="develom.com"
export IAP_ADMIN_USER="hector@develom.com"
export REPO="cloud-run-repo1"

# Derived Configuration
export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
export BACKEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/backend:$(git rev-parse --short HEAD 2>/dev/null || echo 'manual')"
export FRONTEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/frontend:$(git rev-parse --short HEAD 2>/dev/null || echo 'manual')"
```

**Location:** `./deployment.config` (root of repository)

**Usage in Scripts:**
```bash
# Load configuration
source ./deployment.config

# Use variables
echo "Deploying to: $PROJECT_ID"
echo "Region: $REGION"
```

### Updating Configuration

To update deployment settings:

```bash
# Interactive update
./infrastructure/deploy-config.sh --interactive

# Command-line update
./infrastructure/deploy-config.sh \
  --project=new-project-id \
  --region=us-west1 \
  --domain=newcompany.com \
  --admin=admin@newcompany.com
```

After updating configuration:
1. Run `deploy-init.sh` (if project changed)
2. Run `deploy-new-project-id.sh` (to update backend files)
3. Run `deploy-complete-oauth-v0.2.sh` (to redeploy)

---

## Security Features

### Two-Layer Authentication

**Layer 1: Identity-Aware Proxy (IAP)**
- Google OAuth authentication at Load Balancer level
- Organization domain restrictions
- Consent screen approval required
- No direct access to Cloud Run services

**Layer 2: Application JWT Tokens**
- JWT-based session management
- Persistent user authentication
- Secure session storage
- Token validation on each request

### Cloud Armor Protection (Optional)

Deploy Cloud Armor for additional security:

```bash
./infrastructure/deploy-cloud-armor.sh
```

**Protection Rules:**
- SQL Injection (Rule 100, deny-403)
- XSS Attacks (Rule 200, deny-403)
- File Inclusion (Rules 300-400, deny-403)
- Rate Limiting (Rule 500, throttle, 100 req/min)
- DDoS Protection at Load Balancer level

### IAM Permissions

**Backend Service Account Roles:**
- `roles/aiplatform.admin` - Full Vertex AI access for RAG operations
- `roles/storage.admin` - GCS bucket access for corpus data
- `roles/bigquery.admin` - BigQuery access for data operations

**IAP Service Account:**
- `service-{PROJECT_NUMBER}@gcp-sa-iap.iam.gserviceaccount.com`
- `roles/run.invoker` on frontend and backend services

**Frontend/Backend Services:**
- `allUsers` granted `roles/run.invoker` for Load Balancer routing
- **Ingress restriction:** `internal-and-cloud-load-balancing` blocks direct internet access
- IAP protection prevents direct public access

### Network-Level Ingress Control

**Critical Security Layer:**
```bash
--ingress=internal-and-cloud-load-balancing
```

**What This Does:**
- ✅ Blocks direct internet access to Cloud Run service URLs
- ✅ Only allows traffic from Google Cloud Load Balancer
- ✅ Prevents bypass attacks on backend/frontend URLs
- ✅ Enforces all traffic through IAP-protected Load Balancer

**Attack Prevention:**
```bash
# Attempted direct access - BLOCKED
curl https://backend-xyz-uc.a.run.app/api/sessions
# Error: Forbidden - ingress policy blocks non-Load Balancer traffic

# Legitimate access - ALLOWED (after IAP authentication)
curl https://YOUR-IP.nip.io/api/sessions
# Success: Request routed through Load Balancer with IAP protection
```

### CORS Configuration

**Critical Security Fix:**
- Backend environment variable: `FRONTEND_URL=https://YOUR-IP.nip.io`
- Backend CORS middleware allows Load Balancer domain
- Same-domain requests avoid OAuth redirect loops

---

## Version Management

This project uses **Git tags + branch workflow** for version control.

### Current Version: v1.0.0

- ✅ Production stable release
- ✅ OAuth + IAP + Cloud Armor working
- ✅ Simplified deployment with `deploy-all.sh`
- ✅ Comprehensive validation scripts

### Branch Structure

```
main        → Production-ready code (tagged releases)
develop     → Active development (CI/CD improvements)
feature/*   → Short-lived feature branches
```

### Quick Commands

```bash
# View all versions
git tag -l

# Rollback to v1.0.0
git checkout v1.0.0
./infrastructure/deploy-all.sh

# Return to latest
git checkout main

# Create new release
git checkout main
git merge develop --no-ff
git tag -a v1.1.0 -m "Description"
git push origin main v1.1.0
```

### Documentation

- **VERSION-MANAGEMENT.md** - Complete branching strategy and workflows
- **CHANGELOG.md** - Detailed version history
- **GIT-QUICK-REFERENCE.md** - Quick command reference

### Setup Version Management

If starting fresh, run the setup script:

```bash
chmod +x setup-version-management.sh
./setup-version-management.sh
```

---

## Troubleshooting

### Common IAP Errors

#### Error Code 9: "Failed OAuth redirect"
**Cause:** Load Balancer path routing or OAuth client misconfiguration

**Solution:**
1. Verify OAuth redirect URIs in Console:
   - `https://YOUR-IP.nip.io`
   - `https://YOUR-IP.nip.io/_gcp_gatekeeper/authenticate`
2. Check Load Balancer URL map configuration
3. Ensure SSL certificate is ACTIVE

#### Error Code 11: "Authentication failed"
**Cause:** Missing or incorrect OAuth redirect URIs

**Solution:**
1. Go to: https://console.cloud.google.com/apis/credentials
2. Find your OAuth client ID
3. Add redirect URIs:
   - `https://YOUR-IP.nip.io`
   - `https://YOUR-IP.nip.io/_gcp_gatekeeper/authenticate`
4. Save and wait 2-3 minutes
5. Clear browser cache and retry

#### Error Code 52: "OAuth not configured"
**Cause:** OAuth consent screen not configured or OAuth client missing

**Solution:**
1. Configure OAuth consent screen (see Step 4 above)
2. Verify OAuth client exists
3. Recreate OAuth client if necessary:
   ```bash
   gcloud iap oauth-clients create \
     projects/$PROJECT_NUMBER/brands/$PROJECT_NUMBER \
     --display_name="IAP Backend Client"
   ```

### HTTP 403 Forbidden Errors

**Cause:** CORS blocking or missing `allUsers` permission

**Solution 1: Grant allUsers Access**
```bash
gcloud run services add-iam-policy-binding backend \
  --region=$REGION \
  --member="allUsers" \
  --role="roles/run.invoker"
```

**Solution 2: Set FRONTEND_URL**
```bash
gcloud run services update backend \
  --set-env-vars FRONTEND_URL="https://YOUR-IP.nip.io" \
  --region=$REGION
```

### "Failed to fetch" Errors

**Cause:** CORS not configured or backend not accessible

**Diagnosis:**
```bash
# Test CORS headers
curl -s -I -H "Origin: https://YOUR-IP.nip.io" "https://backend-url/"

# Should show: access-control-allow-origin: https://YOUR-IP.nip.io
```

**Solution:**
1. Verify `FRONTEND_URL` is set on backend
2. Check backend CORS middleware in `backend/src/api/server.py`
3. Restart backend service

### SSL Certificate Issues

**Cause:** Certificate provisioning can take 10-15 minutes

**Check Status:**
```bash
gcloud compute ssl-certificates describe adk-rag-ssl-cert \
  --global \
  --format="value(managed.status)"
```

**Expected:** `ACTIVE`

**If FAILED:**
1. Delete and recreate certificate
2. Check domain ownership
3. Verify IP address is correct

### Build Failures

**Cause:** Missing APIs, authentication, or Docker issues

**Common Fixes:**
```bash
# Re-authenticate
gcloud auth application-default login

# Enable Cloud Build API
gcloud services enable cloudbuild.googleapis.com

# Check build logs
gcloud builds list --region=$REGION

# View specific build
gcloud builds describe BUILD_ID --region=$REGION
```

### Service Restart Issues

**Cause:** Configuration changes not applied

**Force Restart:**
```bash
# Backend
gcloud run services update backend \
  --region=$REGION \
  --update-env-vars=RESTART=$(date +%s)

# Frontend
gcloud run services update frontend \
  --region=$REGION \
  --update-env-vars=RESTART=$(date +%s)
```

---

## Agent Capabilities

### RAG Operations

**Query Documents:**
```
User: What are the main features of product X from corpus my_product_docs?
Agent: [Returns relevant information from the corpus]
```

**List Corpora:**
```
User: list corpora
Agent: Available corpora:
  • my_product_docs
  • technical_manuals
  • user_guides
```

**Create Corpus:**
```
User: create a new corpus named customer_feedback
Agent: Successfully created corpus: customer_feedback
```

**Add Documents:**
```
User: add data from gs://my-bucket/feedback.pdf to corpus customer_feedback
Agent: Successfully imported document to customer_feedback
```

**Get Corpus Information:**
```
User: get information for corpus customer_feedback
Agent: Corpus: customer_feedback
  • Display Name: customer_feedback
  • Document Count: 15
  • Created: 2025-10-08
```

**Delete Corpus:**
```
User: delete corpus customer_feedback
Agent: Successfully deleted corpus: customer_feedback
```

### Supported Document Types

- PDF documents
- Text files (.txt)
- Word documents (.docx)
- Google Docs (via GCS)
- HTML files

### GCS Path Format

When adding documents, use full GCS paths:
```
gs://bucket-name/path/to/document.pdf
gs://my-bucket/folder/*.pdf  (wildcard supported)
```

---

## Maintenance & Updates

### Redeploying After Changes

**Full Redeploy:**
```bash
./infrastructure/deploy-complete-oauth-v0.2.sh
```

**Backend Only:**
```bash
cd backend
gcloud builds submit --region=$REGION \
  --config=cloudbuild.yaml

gcloud run services update backend \
  --region=$REGION \
  --image=$BACKEND_IMAGE
```

**Frontend Only:**
```bash
cd frontend
gcloud builds submit --region=$REGION \
  --config=cloudbuild.yaml

gcloud run services update frontend \
  --region=$REGION \
  --image=$FRONTEND_IMAGE
```

### Updating Environment Variables

```bash
# Backend
gcloud run services update backend \
  --region=$REGION \
  --set-env-vars="LOG_LEVEL=DEBUG,CUSTOM_VAR=value"

# Frontend
gcloud run services update frontend \
  --region=$REGION \
  --set-env-vars="NEXT_PUBLIC_BACKEND_URL=https://YOUR-IP.nip.io"
```

### Viewing Logs

**Cloud Run Logs:**
```bash
# Backend logs
gcloud logs read --service=backend --region=$REGION --limit=50

# Frontend logs
gcloud logs read --service=frontend --region=$REGION --limit=50

# Follow logs (real-time)
gcloud logs tail --service=backend --region=$REGION
```

**Build Logs:**
```bash
# List recent builds
gcloud builds list --region=$REGION --limit=10

# View specific build
gcloud builds log BUILD_ID --region=$REGION
```

### Monitoring

**Check Service Status:**
```bash
gcloud run services list --region=$REGION
```

**View IAP Configuration:**
```bash
gcloud compute backend-services describe frontend-backend-service \
  --global \
  --format="yaml(iap)"
```

**Check Load Balancer:**
```bash
gcloud compute forwarding-rules list --global
gcloud compute url-maps describe adk-rag-url-map --global
```

### Scaling Configuration

**Auto-scaling Settings:**
```bash
gcloud run services update backend \
  --region=$REGION \
  --min-instances=1 \
  --max-instances=10 \
  --concurrency=80
```

---

## Additional Resources

### Official Documentation

- [Vertex AI RAG Documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/rag-overview)
- [Google Agent Development Kit (ADK)](https://github.com/google/agents-framework)
- [Identity-Aware Proxy (IAP)](https://cloud.google.com/iap/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Load Balancing](https://cloud.google.com/load-balancing/docs)
- [OAuth 2.0 for Google APIs](https://developers.google.com/identity/protocols/oauth2)

### Project Structure

```
adk-rag-agent/
├── backend/
│   ├── src/
│   │   ├── api/
│   │   │   └── server.py          # FastAPI server
│   │   └── rag_agent/
│   │       ├── agent.py            # ADK Agent implementation
│   │       └── config.py           # Configuration
│   ├── Dockerfile                  # Backend container
│   ├── cloudbuild.yaml            # Build configuration
│   └── requirements.txt            # Python dependencies
├── frontend/
│   ├── src/
│   │   ├── app/                   # Next.js app
│   │   ├── components/            # React components
│   │   └── lib/                   # Utilities
│   ├── Dockerfile                  # Frontend container
│   ├── cloudbuild.yaml            # Build configuration
│   └── package.json                # Node dependencies
├── infrastructure/
│   ├── deploy-config.sh           # Step 1: Configuration
│   ├── deploy-init.sh             # Step 2: Project initialization
│   ├── deploy-new-project-id.sh   # Step 3: Update backend files
│   ├── deploy-complete-oauth-v0.2.sh  # Step 6: Complete deployment (OAuth)
│   ├── deploy-secure-v0.2.sh      # Step 6: Complete deployment (with secrets.env)
│   ├── deploy-cloud-armor.sh      # Optional: Cloud Armor
│   └── validate-security.sh       # Security validation
├── deployment.config               # Configuration file
└── README.md                       # This file
```

### Deployment Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `deploy-config.sh` | Create/update configuration | Initial setup, config changes |
| `deploy-init.sh` | Initialize GCP project | New project, first deployment |
| `deploy-new-project-id.sh` | Update backend files | After config changes |
| `generate_secret_key.py` | Generate JWT secret key | Before deployment (Step 5) |
| `deploy-complete-oauth-v0.2.sh` | Full deployment with OAuth | Initial deploy, major updates |
| `deploy-secure-v0.2.sh` | Full deployment with secrets.env | When using JWT authentication |
| `deploy-cloud-armor.sh` | Add security rules | Optional security enhancement |
| `validate-security.sh` | Test security | After deployment, troubleshooting |

### Support and Contributions

For issues, questions, or contributions:
- **Repository Issues**: https://github.com/xtreamgit/adk-rag-agent/issues
- **Documentation**: Check `docs/` folder for additional guides
- **Memories**: Review `docs/BREAKTHROUGH.md` for detailed troubleshooting

---

## License

Copyright © 2025 Hector. All rights reserved.

---

**Last Updated:** October 8, 2025  
**Version:** 2.0  
**Status:** Production Ready ✅
