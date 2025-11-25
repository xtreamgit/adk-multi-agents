# Modular Deployment Architecture

## Overview

The `deploy-all.sh` script has been redesigned with a **modular architecture** that separates concerns into well-organized function modules. This approach eliminates duplicate code, improves maintainability, and makes debugging easier.

## Architecture

```
infrastructure/
├── deploy-all.sh              # Master orchestration script
└── lib/                       # Modular function libraries
    ├── utils.sh               # Common utilities and logging
    ├── prerequisites.sh       # Prerequisites validation & API enablement
    ├── infrastructure.sh      # Artifact Registry & service accounts
    ├── cloudrun.sh           # Cloud Run deployment
    ├── oauth.sh              # OAuth consent screen configuration
    ├── loadbalancer.sh       # External HTTPS Load Balancer setup
    ├── iap.sh                # Identity-Aware Proxy configuration
    └── finalize.sh           # CORS, frontend rebuild, and summary
```

## Key Benefits

### 1. **No Duplicate Code**
- Each function exists in only one place
- No subprocess calls between deployment scripts
- Shared utilities in `utils.sh`

### 2. **Easy to Maintain**
- Each module handles one specific deployment phase
- Clear separation of concerns
- Easy to locate and fix issues

### 3. **Modular Skip Flags**
- `--skip-apis` - Skip API enablement
- `--skip-cloud-run` - Skip Cloud Run deployment
- `--skip-load-balancer` - Skip Load Balancer creation
- `--skip-iap` - Skip IAP configuration
- `--skip-oauth` - Skip OAuth client creation

### 4. **Linear Execution Flow**
- Sequential module execution
- Clear error handling at each stage
- No hidden subprocess calls

### 5. **Debugging Friendly**
- Each module can be tested independently
- Clear section markers in output
- Comprehensive logging

## Usage

### Full Deployment (First Time)
```bash
./infrastructure/deploy-all.sh
```

### Quick Redeployment
```bash
./infrastructure/deploy-all.sh --skip-apis --skip-load-balancer
```

### Testing Without IAP
```bash
./infrastructure/deploy-all.sh --skip-iap
```

### Get Help
```bash
./infrastructure/deploy-all.sh --help
```

## Module Details

### 1. utils.sh - Common Utilities
**Purpose:** Shared functions used across all modules

**Functions:**
- `log_info()` - Blue info messages
- `log_success()` - Green success messages
- `log_warning()` - Yellow warning messages
- `log_error()` - Red error messages
- `log_section()` - Section headers
- `show_banner()` - Display deployment banner
- `resource_exists()` - Check if GCP resource exists
- `wait_for_resource()` - Wait for resource to be ready
- `confirm_action()` - User confirmation prompts

**Color Codes:**
- RED, GREEN, YELLOW, BLUE, CYAN, MAGENTA, NC (No Color)

---

### 2. prerequisites.sh - Prerequisites & APIs
**Purpose:** Validate environment and enable required APIs

**Functions:**
- `validate_prerequisites()` - Check auth, config, secrets
- `enable_apis()` - Enable all required Google Cloud APIs

**What it checks:**
- gcloud authentication
- Application default credentials
- Configuration variables (PROJECT_ID, REGION, etc.)
- secrets.env file with SECRET_KEY
- Calculates image tags (GIT_SHA)

**APIs Enabled:**
- run.googleapis.com
- artifactregistry.googleapis.com
- cloudbuild.googleapis.com
- compute.googleapis.com
- iap.googleapis.com
- dns.googleapis.com
- iam.googleapis.com
- cloudresourcemanager.googleapis.com
- cloudidentity.googleapis.com
- aiplatform.googleapis.com
- storage.googleapis.com
- bigquery.googleapis.com

---

### 3. infrastructure.sh - Infrastructure Setup
**Purpose:** Create Artifact Registry and service accounts

**Functions:**
- `setup_infrastructure()` - Main orchestration
- `setup_artifact_registry()` - Create Docker repository
- `setup_service_accounts()` - Create all service accounts
- `configure_iam_permissions()` - Grant IAM roles

**Service Accounts Created:**
- `backend-sa` - Backend Cloud Run service
- `frontend-sa` - Frontend Cloud Run service
- `adk-rag-agent-sa` - Main RAG operations (Vertex AI permissions)
- `iap-accessor` - IAP-enabled access

**IAM Roles Granted:**
- RAG Agent SA: aiplatform.admin, storage.admin, bigquery.admin
- Backend SA: aiplatform.user, storage.objectViewer
- IAP Accessor SA: iap.httpsResourceAccessor

---

### 4. cloudrun.sh - Cloud Run Deployment
**Purpose:** Build and deploy backend and frontend services

**Functions:**
- `deploy_cloud_run()` - Main orchestration (with skip logic)
- `deploy_backend()` - Build and deploy backend
- `deploy_frontend()` - Build and deploy frontend

**Backend Configuration:**
- Image: Backend container with RAG agent
- Service Account: adk-rag-agent-sa (Vertex AI permissions)
- Resources: 1 CPU, 1Gi memory
- Scaling: 0-10 instances
- Ingress: internal-and-cloud-load-balancing

**Frontend Configuration:**
- Image: Next.js frontend
- Service Account: frontend-sa
- Resources: 1 CPU, 512Mi memory
- Scaling: 0-5 instances
- Ingress: internal-and-cloud-load-balancing

**Environment Variables:**
- Backend: PROJECT_ID, GOOGLE_CLOUD_LOCATION, SECRET_KEY, DATABASE_PATH, LOG_LEVEL, ENVIRONMENT, ACCOUNT_ENV
- Frontend: NEXT_PUBLIC_BACKEND_URL (build-time)

---

### 5. oauth.sh - OAuth Configuration
**Purpose:** Configure OAuth consent screen and brand

**Functions:**
- `configure_oauth()` - Main orchestration
- `check_oauth_brand()` - Check if OAuth brand exists
- `prompt_oauth_setup()` - Guide user through manual setup

**What it does:**
- Gets project number
- Checks for existing OAuth brand
- Prompts user to configure consent screen if missing
- Stores BRAND_ID and BRAND_PATH for later use

**Manual Steps Required:**
- Navigate to OAuth consent screen in Console
- Configure as Internal (for organization)
- Set app name, support email, authorized domains
- Add scopes: openid, email, profile
- Publish consent screen

---

### 6. loadbalancer.sh - Load Balancer Setup
**Purpose:** Create External HTTPS Load Balancer with SSL

**Functions:**
- `setup_load_balancer()` - Main orchestration (with skip logic)
- `create_static_ip()` - Reserve global static IP
- `create_ssl_certificate()` - Provision managed SSL cert
- `create_network_endpoint_groups()` - Create serverless NEGs
- `create_backend_services()` - Create LB backend services
- `create_url_map()` - Configure path-based routing
- `create_https_proxy()` - Create HTTPS proxy
- `create_forwarding_rule()` - Create forwarding rule

**Components Created:**
- Static IP: rag-agent-ip (global)
- SSL Certificate: rag-agent-ssl-cert (for *.nip.io)
- NEGs: frontend-neg, backend-neg (serverless)
- Backend Services: frontend-backend-service, backend-backend-service
- URL Map: rag-agent-url-map (/ → frontend, /api/* → backend)
- HTTPS Proxy: rag-agent-https-proxy
- Forwarding Rule: rag-agent-forwarding-rule (port 443)

**Load Balancer URL:** `https://{STATIC_IP}.nip.io`

---

### 7. iap.sh - IAP Configuration
**Purpose:** Enable Identity-Aware Proxy with OAuth

**Functions:**
- `configure_iap()` - Main orchestration (with skip logic)
- `create_oauth_client()` - Create OAuth client with redirect URIs
- `create_iap_service_account()` - Create IAP service account
- `enable_iap_on_backends()` - Enable IAP on backend services
- `configure_iap_access()` - Grant IAP access permissions

**What it does:**
1. Creates OAuth client for Load Balancer
2. **Manual Step:** User adds redirect URIs in Console
   - `https://{STATIC_IP}.nip.io`
   - `https://{STATIC_IP}.nip.io/_gcp_gatekeeper/authenticate`
3. Creates official IAP service account
4. Grants Cloud Run Invoker role to IAP SA
5. Enables IAP on frontend and backend services
6. Grants IAP access to admin user and organization domain

**Security:**
- Two-layer authentication (IAP + Application JWT)
- Domain-restricted access (@develom.com)
- OAuth consent screen flow

---

### 8. finalize.sh - Finalization & Summary
**Purpose:** CORS configuration, frontend rebuild, and deployment summary

**Functions:**
- `finalize_deployment()` - Main orchestration
- `configure_cors()` - Update backend CORS settings
- `rebuild_frontend_with_lb()` - Rebuild frontend with LB URL
- `validate_deployment()` - Check SSL and IAP status
- `show_deployment_summary()` - Display deployment details

**What it does:**
1. Updates backend with FRONTEND_URL = Load Balancer URL
2. Applies CORS breakthrough fix (allUsers access for LB routing)
3. Rebuilds frontend with NEXT_PUBLIC_BACKEND_URL = LB URL
4. Redeploys frontend with new image
5. Validates SSL certificate and IAP status
6. Displays comprehensive deployment summary

**Key Insight:** Next.js NEXT_PUBLIC_* variables are baked at BUILD time, not runtime. Frontend must be rebuilt with Load Balancer URL after LB is created.

---

## Deployment Flow

```
┌─────────────────────────────────────────┐
│  1. Prerequisites & API Enablement      │
│  - Validate gcloud auth                 │
│  - Check configuration                  │
│  - Enable APIs                          │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  2. Infrastructure Setup                │
│  - Create Artifact Registry             │
│  - Create service accounts              │
│  - Grant IAM permissions                │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  3. Cloud Run Deployment                │
│  - Build backend image                  │
│  - Deploy backend service               │
│  - Build frontend image                 │
│  - Deploy frontend service              │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  4. OAuth Configuration                 │
│  - Check OAuth brand                    │
│  - Prompt consent screen setup          │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  5. Load Balancer Setup                 │
│  - Create static IP                     │
│  - Create SSL certificate               │
│  - Create NEGs                          │
│  - Create backend services              │
│  - Create URL map                       │
│  - Create HTTPS proxy                   │
│  - Create forwarding rule               │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  6. IAP Configuration                   │
│  - Create OAuth client                  │
│  - Manual: Add redirect URIs            │
│  - Create IAP service account           │
│  - Enable IAP on backends               │
│  - Configure IAP access                 │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  7. Finalization                        │
│  - Configure CORS                       │
│  - Rebuild frontend with LB URL         │
│  - Validate deployment                  │
│  - Show summary                         │
└─────────────────────────────────────────┘
```

## Error Handling

Each module returns success (0) or failure (1):
- If any module fails, deployment stops immediately
- Clear error messages indicate which module failed
- No partial deployments that leave system in inconsistent state

## Testing Individual Modules

You can test modules independently by sourcing them:

```bash
# Test prerequisites
source infrastructure/lib/utils.sh
source infrastructure/lib/prerequisites.sh
validate_prerequisites

# Test infrastructure setup
source infrastructure/lib/infrastructure.sh
setup_infrastructure
```

## Comparison with Previous Scripts

### Before (deploy-secure-v0.2.sh + deploy-complete-oauth-v0.2.sh)
- 2 scripts, 1,144 total lines
- Subprocess call from oauth script to secure script
- Duplicate prerequisite checks
- Duplicate OAuth consent prompts
- Hard to debug failures

### After (deploy-all.sh + 8 modules)
- 1 master script + 8 focused modules
- Linear execution, no subprocesses
- Each function exists once
- Clear module boundaries
- Easy to debug, maintain, and extend

## Deployment Time

- **Full deployment:** 20-30 minutes
- **With skip flags:** 10-15 minutes
- **SSL provisioning:** 10-15 minutes (longest component)

## Troubleshooting

### Module fails to source
- Check file permissions: `chmod +x infrastructure/lib/*.sh`
- Verify lib directory exists: `ls -la infrastructure/lib/`

### OAuth consent screen not found
- Must be configured manually in Google Cloud Console
- Script will prompt with instructions
- Cannot proceed without it

### SSL certificate not ACTIVE
- SSL provisioning takes 10-15 minutes
- Check status: `gcloud compute ssl-certificates describe rag-agent-ssl-cert --global`
- Application works but shows certificate warning until ACTIVE

### IAP errors
- Verify redirect URIs are added in Console
- Check OAuth client ID matches what's configured on backend services
- Ensure IAP service account has Cloud Run Invoker role

## Future Enhancements

Potential additions to modular architecture:
- `lib/monitoring.sh` - Setup Cloud Monitoring and alerts
- `lib/cloudarmor.sh` - Deploy Cloud Armor security policies
- `lib/backup.sh` - Configure backup and disaster recovery
- `lib/rollback.sh` - Rollback to previous deployment

## Maintenance

To update a specific deployment phase:
1. Edit the relevant module in `infrastructure/lib/`
2. Test the module independently
3. Run full deployment or use skip flags to avoid rebuilding everything

## Related Documentation

- `COMPLETE-OAUTH-SETUP.md` - Detailed OAuth setup guide
- `TROUBLESHOOT.md` - Common issues and solutions
- `validate-security.sh` - Security validation script

## Support

For issues or questions:
1. Check module-specific error messages
2. Review TROUBLESHOOT.md
3. Run with verbose logging: `set -x` at top of script
4. Check GCP Console for resource status
