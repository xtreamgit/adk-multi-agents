# Cloud Deployment Plan - usfs-cio-adkrag-dev
**Date**: January 27, 2026  
**Target Project**: `usfs-cio-adkrag-dev`  
**Region**: `us-west1`  
**Status**: Ready to Deploy

---

## Overview

This deployment will provision a new multi-agent RAG system on Google Cloud Platform using Terraform. The infrastructure includes:

- **GCP Project**: `usfs-cio-adkrag-dev` (new project creation)
- **Artifact Registry**: Docker repository for container images
- **Cloud Run Services**: Backend + Frontend (with optional multi-agent backends)
- **Load Balancer**: HTTPS with SSL certificate
- **Cloud SQL**: PostgreSQL database (to be added)
- **IAM**: Service accounts and role bindings
- **VPC**: Private networking with Google API access

---

## Current State Analysis

### ✅ What's Ready
1. **Terraform Configuration**: 
   - Variables defined in `terraform.tfvars`
   - Project structure exists in `terraform/google-cloud-admin-nonprod/projects/cio-adk-rag-dev/`
   - Modules created for Cloud Run, Artifact Registry, Load Balancer

2. **Application Code**:
   - Backend and Frontend code committed to `develop` branch
   - Recent fixes for document preview and authentication
   - Local development tested and working

3. **Container Images Specified**:
   - Backend: `us-west1-docker.pkg.dev/usfs-cio-adkrag-dev/cloud-run-repo1/backend:latest`
   - Frontend: `us-west1-docker.pkg.dev/usfs-cio-adkrag-dev/cloud-run-repo1/frontend:latest`

### ⚠️ What's Missing

1. **Module Calls in main.tf**:
   - Cloud Run module not called
   - Artifact Registry module not called
   - Load Balancer module not called
   - Cloud SQL module doesn't exist yet

2. **Container Images**:
   - Images need to be built and pushed to Artifact Registry
   - Artifact Registry repository needs to be created first

3. **Environment Variables**:
   - Backend needs DB connection details
   - Vertex AI configuration
   - Secret management setup

4. **Cloud SQL**:
   - PostgreSQL instance needs to be provisioned
   - Database and user creation
   - Connection configuration

---

## Deployment Steps

### Phase 1: Terraform Infrastructure Setup (REQUIRED FIRST)

#### Step 1.1: Update main.tf to Include Missing Modules

Add these module calls to `main.tf`:

```hcl
# Artifact Registry module
# Creates Docker repository for container images
module "artifact_registry" {
  depends_on    = [google_project.project, module.project-services]
  source        = "./modules/artifact-registry"
  project_id    = var.project_id
  region        = var.region
  repository_id = var.artifact_registry_name
}

# Cloud Run module
# Deploys backend and frontend services
module "cloud_run" {
  depends_on = [
    google_project.project,
    module.project-services,
    module.artifact_registry,
    module.service_account
  ]
  source = "./modules/cloud-run"
  
  project_id                = var.project_id
  region                    = var.region
  backend_image             = var.backend_image
  frontend_image            = var.frontend_image
  backend_service_account   = module.service_account.backend_sa_email
  frontend_service_account  = module.service_account.frontend_sa_email
  agent_service_accounts    = module.service_account.agent_sa_emails
  enable_multi_agent        = var.enable_multi_agent
  backend_cpu               = var.backend_cpu
  backend_memory            = var.backend_memory
  backend_min_instances     = var.backend_min_instances
  backend_max_instances     = var.backend_max_instances
  frontend_cpu              = var.frontend_cpu
  frontend_memory           = var.frontend_memory
  frontend_min_instances    = var.frontend_min_instances
  frontend_max_instances    = var.frontend_max_instances
  backend_env_vars          = {
    DB_TYPE                    = "postgresql"
    PROJECT_ID                 = var.project_id
    LOCATION                   = var.region
    ENVIRONMENT                = var.environment
    LOG_LEVEL                  = var.log_level
    # Add Cloud SQL connection after database is created
  }
}

# Load Balancer module
# Creates HTTPS load balancer with SSL
module "load_balancer" {
  depends_on = [
    google_project.project,
    module.project-services,
    module.cloud_run
  ]
  source = "./modules/load-balancer"
  
  project_id           = var.project_id
  region               = var.region
  static_ip_name       = var.static_ip_name
  ssl_certificate_name = var.ssl_certificate_name
  backend_service_name = module.cloud_run.backend_service_name
  frontend_service_name = module.cloud_run.frontend_service_name
  enable_multi_agent   = var.enable_multi_agent
  agent_backend_services = var.enable_multi_agent ? {
    agent1 = module.cloud_run.backend_agent1_service_name
    agent2 = module.cloud_run.backend_agent2_service_name
    agent3 = module.cloud_run.backend_agent3_service_name
  } : {}
}
```

#### Step 1.2: Verify Service Account Module

Check that `modules/service_account/main.tf` creates:
- `backend_sa_email` output
- `frontend_sa_email` output
- `agent_sa_emails` output (map for agent1, agent2, agent3)

#### Step 1.3: Verify Module Variables

Ensure each module has proper `variables.tf` files with all required inputs.

### Phase 2: Build and Push Container Images

**IMPORTANT**: Images must exist before Terraform can deploy Cloud Run services.

#### Step 2.1: Authenticate with GCP

```bash
gcloud auth login
gcloud config set project usfs-cio-adkrag-dev
gcloud auth configure-docker us-west1-docker.pkg.dev
```

#### Step 2.2: Build Backend Image

```bash
cd backend
docker build -t us-west1-docker.pkg.dev/usfs-cio-adkrag-dev/cloud-run-repo1/backend:latest .
docker push us-west1-docker.pkg.dev/usfs-cio-adkrag-dev/cloud-run-repo1/backend:latest
```

#### Step 2.3: Build Frontend Image

```bash
cd frontend
docker build -t us-west1-docker.pkg.dev/usfs-cio-adkrag-dev/cloud-run-repo1/frontend:latest \
  --build-arg NEXT_PUBLIC_BACKEND_URL="" .
docker push us-west1-docker.pkg.dev/usfs-cio-adkrag-dev/cloud-run-repo1/frontend:latest
```

### Phase 3: Terraform Deployment

#### Step 3.1: Initialize Terraform

```bash
cd terraform/google-cloud-admin-nonprod/projects/cio-adk-rag-dev
terraform init
```

#### Step 3.2: Plan Deployment

```bash
terraform plan -var-file=terraform.tfvars -out=tfplan
```

Review the plan carefully:
- Check resource counts
- Verify service accounts
- Confirm IAM bindings
- Review Cloud Run configurations

#### Step 3.3: Apply Infrastructure

```bash
terraform apply tfplan
```

This will create:
- GCP Project `usfs-cio-adkrag-dev`
- Artifact Registry repository
- VPC and networking
- Service accounts
- Cloud Run services (backend, frontend)
- Load balancer with SSL
- IAM bindings

### Phase 4: Cloud SQL Setup (Manual or Separate Terraform)

#### Option A: Manual Setup

```bash
# Create Cloud SQL instance
gcloud sql instances create adk-multi-agents-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-west1 \
  --project=usfs-cio-adkrag-dev

# Create database
gcloud sql databases create adk_agents_db \
  --instance=adk-multi-agents-db \
  --project=usfs-cio-adkrag-dev

# Create user
gcloud sql users create adk_app_user \
  --instance=adk-multi-agents-db \
  --password=<SECURE_PASSWORD> \
  --project=usfs-cio-adkrag-dev
```

#### Option B: Add Cloud SQL Terraform Module

Create `modules/cloud-sql/main.tf` and add to main deployment.

#### Step 4.1: Update Cloud Run with DB Connection

After Cloud SQL is created, update backend environment variables:

```bash
gcloud run services update backend \
  --add-cloudsql-instances=usfs-cio-adkrag-dev:us-west1:adk-multi-agents-db \
  --update-env-vars="DB_HOST=/cloudsql/usfs-cio-adkrag-dev:us-west1:adk-multi-agents-db,DB_NAME=adk_agents_db,DB_USER=adk_app_user" \
  --update-secrets="DB_PASSWORD=db-password:latest" \
  --region=us-west1 \
  --project=usfs-cio-adkrag-dev
```

### Phase 5: Database Migration

```bash
# Connect via Cloud SQL Proxy
cloud-sql-proxy usfs-cio-adkrag-dev:us-west1:adk-multi-agents-db &

# Run migrations
cd backend
python src/database/migrations/run_migrations.py
```

### Phase 6: Verification

#### Step 6.1: Check Cloud Run Services

```bash
gcloud run services list --project=usfs-cio-adkrag-dev --region=us-west1
```

#### Step 6.2: Test Backend Health

```bash
BACKEND_URL=$(gcloud run services describe backend --region=us-west1 --project=usfs-cio-adkrag-dev --format='value(status.url)')
curl $BACKEND_URL/api/health
```

#### Step 6.3: Test Frontend

```bash
FRONTEND_URL=$(gcloud run services describe frontend --region=us-west1 --project=usfs-cio-adkrag-dev --format='value(status.url)')
curl $FRONTEND_URL
```

#### Step 6.4: Check Load Balancer

```bash
# Get static IP
gcloud compute addresses describe app-static-ip --global --project=usfs-cio-adkrag-dev

# Test via load balancer (after DNS/SSL setup)
curl https://<STATIC_IP>.nip.io/api/health
```

---

## Post-Deployment Configuration

### 1. IAP Setup (Optional but Recommended)

```bash
# Enable IAP on load balancer backend services
gcloud iap web enable --resource-type=backend-services \
  --service=<BACKEND_SERVICE_NAME> \
  --project=usfs-cio-adkrag-dev
```

### 2. Secrets Management

Store sensitive values in Secret Manager:

```bash
# Database password
echo -n "<DB_PASSWORD>" | gcloud secrets create db-password \
  --data-file=- \
  --project=usfs-cio-adkrag-dev

# Grant Cloud Run access
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:<BACKEND_SA_EMAIL>" \
  --role="roles/secretmanager.secretAccessor" \
  --project=usfs-cio-adkrag-dev
```

### 3. Vertex AI Configuration

Ensure service accounts have Vertex AI permissions:

```bash
gcloud projects add-iam-policy-binding usfs-cio-adkrag-dev \
  --member="serviceAccount:<BACKEND_SA_EMAIL>" \
  --role="roles/aiplatform.user"
```

### 4. Sync Corpora from Vertex AI

```bash
# After deployment, sync database with Vertex AI
python backend/sync_corpora_from_vertex.py
```

---

## Rollback Plan

If deployment fails:

```bash
# Destroy Terraform resources
terraform destroy -var-file=terraform.tfvars

# Or destroy specific resources
terraform destroy -target=module.cloud_run -var-file=terraform.tfvars
```

---

## Known Issues & Considerations

1. **Container Images**: Must be built and pushed BEFORE Terraform apply
2. **Cloud SQL**: Not included in initial Terraform - needs separate setup
3. **IAP**: Requires OAuth consent screen configuration
4. **SSL Certificate**: May take 10-15 minutes to provision
5. **Multi-Agent**: Currently disabled (`enable_multi_agent = false`)
6. **Database Migration**: Must run after Cloud SQL is created

---

## Next Steps Summary

**IMMEDIATE ACTIONS REQUIRED:**

1. ✅ Update `main.tf` to add module calls for:
   - Artifact Registry
   - Cloud Run
   - Load Balancer

2. ✅ Verify service account module outputs

3. ✅ Build and push container images to Artifact Registry

4. ✅ Run `terraform init` and `terraform plan`

5. ✅ Review plan and apply

6. ✅ Set up Cloud SQL (manual or Terraform)

7. ✅ Run database migrations

8. ✅ Test deployment

---

## Success Criteria

- [ ] GCP project created successfully
- [ ] Artifact Registry repository exists
- [ ] Container images pushed
- [ ] Cloud Run services deployed and running
- [ ] Load balancer accessible via HTTPS
- [ ] Cloud SQL instance created
- [ ] Database migrations completed
- [ ] Backend health check returns 200
- [ ] Frontend loads successfully
- [ ] Authentication working (local or IAP)
- [ ] Document retrieval functional
- [ ] Vertex AI integration working

---

**Status**: Ready to begin Phase 1 - Update Terraform configuration
