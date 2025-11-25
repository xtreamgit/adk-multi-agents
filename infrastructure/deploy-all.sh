#!/bin/bash
#
# deploy-all.sh - Master Deployment Script for ADK RAG Agent
#
# DESCRIPTION:
# ============
# Modular deployment pipeline that orchestrates Cloud Run services, Load Balancer,
# OAuth configuration, and IAP enablement. Uses well-organized function modules
# from ./lib/ directory for maintainability and clarity.
#
# ARCHITECTURE:
# =============
# Internet → HTTPS Load Balancer (SSL + IAP) → Cloud Run Services
#   ├── "/" → Frontend (Next.js)
#   └── "/api/*" → Backend (FastAPI + RAG Agent)
#
# MODULES:
# ========
# - lib/utils.sh: Common utilities and logging functions
# - lib/prerequisites.sh: Validate auth and enable APIs
# - lib/infrastructure.sh: Setup Artifact Registry and service accounts
# - lib/cloudrun.sh: Deploy Cloud Run services
# - lib/oauth.sh: Configure OAuth consent screen
# - lib/loadbalancer.sh: Setup External HTTPS Load Balancer
# - lib/iap.sh: Configure Identity-Aware Proxy
# - lib/finalize.sh: CORS, frontend rebuild, and summary
#
# USAGE:
# ======
# ./infrastructure/deploy-all.sh [OPTIONS]
#
# OPTIONS:
# ========
# -h, --help              Show help message
# --skip-apis             Skip API enablement
# --skip-cloud-run        Skip Cloud Run deployment
# --skip-load-balancer    Skip Load Balancer creation
# --skip-iap              Skip IAP configuration
# --skip-oauth            Skip OAuth client creation
#
# EXAMPLES:
# =========
# # Full deployment
# ./infrastructure/deploy-all.sh
#
# # Quick redeployment
# ./infrastructure/deploy-all.sh --skip-apis --skip-load-balancer
#
# # Deploy without IAP (testing)
# ./infrastructure/deploy-all.sh --skip-iap
#
# PREREQUISITES:
# ==============
# - gcloud CLI authenticated
# - deployment.config file exists
# - secrets.env file with SECRET_KEY
# - Billing enabled
#
# AUTHOR: ADK RAG Agent Team
# DATE: 2025-10-10

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source utilities first
source "$LIB_DIR/utils.sh"

################################################################################
# COMMAND LINE ARGUMENT PARSING
################################################################################

# Show usage
show_usage() {
    cat << EOF
${BLUE}deploy-all.sh - Master ADK RAG Agent Deployment Pipeline${NC}

${YELLOW}DESCRIPTION:${NC}
  Modular deployment script that orchestrates all deployment phases using
  organized function modules. Combines Cloud Run, Load Balancer, OAuth, and IAP.

${YELLOW}USAGE:${NC}
  ./infrastructure/deploy-all.sh [OPTIONS]

${YELLOW}OPTIONS:${NC}
  -h, --help              Show this help message
  --skip-apis             Skip API enablement (if already enabled)
  --skip-cloud-run        Skip Cloud Run deployment (use existing services)
  --skip-load-balancer    Skip Load Balancer creation (use existing LB)
  --skip-iap              Skip IAP configuration (no authentication)
  --skip-oauth            Skip OAuth client creation (manual setup)

${YELLOW}EXAMPLES:${NC}
  # Full deployment (first time)
  ./infrastructure/deploy-all.sh

  # Quick redeployment (skip infrastructure)
  ./infrastructure/deploy-all.sh --skip-apis --skip-load-balancer

  # Deploy without IAP (testing only)
  ./infrastructure/deploy-all.sh --skip-iap

${YELLOW}DEPLOYMENT MODULES:${NC}
  1. Prerequisites & API Enablement  (lib/prerequisites.sh)
  2. Infrastructure Setup             (lib/infrastructure.sh)
  3. Cloud Run Deployment             (lib/cloudrun.sh)
  4. OAuth Configuration              (lib/oauth.sh)
  5. Load Balancer Setup              (lib/loadbalancer.sh)
  6. IAP Configuration                (lib/iap.sh)
  7. Finalization & Summary           (lib/finalize.sh)

${YELLOW}PREREQUISITES:${NC}
  - gcloud CLI authenticated (gcloud auth login)
  - deployment.config with required variables
  - secrets.env with SECRET_KEY
  - Billing enabled on GCP project

${YELLOW}DEPLOYMENT TIME:${NC}
  Full: 20-30 minutes | With skip flags: 10-15 minutes

For detailed module information, see files in infrastructure/lib/
EOF
    exit 0
}

# Parse arguments
export SKIP_APIS=false
export SKIP_CLOUD_RUN=false
export SKIP_LOAD_BALANCER=false
export SKIP_IAP=false
export SKIP_OAUTH=false

for arg in "$@"; do
    case $arg in
        -h|--help)
            show_usage
            ;;
        --skip-apis)
            SKIP_APIS=true
            shift
            ;;
        --skip-cloud-run)
            SKIP_CLOUD_RUN=true
            shift
            ;;
        --skip-load-balancer)
            SKIP_LOAD_BALANCER=true
            shift
            ;;
        --skip-iap)
            SKIP_IAP=true
            shift
            ;;
        --skip-oauth)
            SKIP_OAUTH=true
            shift
            ;;
        *)
            log_error "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

################################################################################
# CONFIGURATION LOADING
################################################################################

# Display banner
show_banner

# Load configuration
CONFIG_FILE="./deployment.config"
if [[ -f "$CONFIG_FILE" ]]; then
    log_info "Loading configuration from: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    log_error "Configuration file not found: $CONFIG_FILE"
    echo "Please run: ./infrastructure/deploy-config.sh --interactive"
    exit 1
fi

# Set secrets file path
export SECRETS_FILE="./secrets.env"

# Source secrets and validate SECRET_KEY
if [[ -f "$SECRETS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SECRETS_FILE"
    if [[ -z "${SECRET_KEY:-}" ]]; then
        log_error "SECRET_KEY not set in $SECRETS_FILE"
        exit 1
    fi
    export SECRET_KEY
else
    log_error "Secrets file not found: $SECRETS_FILE"
    exit 1
fi

# Standardize Google Cloud location env for backend
export GOOGLE_CLOUD_LOCATION="$REGION"

# Display configuration
echo -e "${BLUE}📋 Deployment Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Repository: $REPO"
echo "  Organization: $ORGANIZATION_DOMAIN"
echo "  Admin User: $IAP_ADMIN_USER"
echo ""
echo -e "${YELLOW}⚙️  Deployment Options:${NC}"
[[ "$SKIP_APIS" == "true" ]] && echo "  • Skip APIs: Yes" || echo "  • Skip APIs: No"
[[ "$SKIP_CLOUD_RUN" == "true" ]] && echo "  • Skip Cloud Run: Yes" || echo "  • Skip Cloud Run: No"
[[ "$SKIP_LOAD_BALANCER" == "true" ]] && echo "  • Skip Load Balancer: Yes" || echo "  • Skip Load Balancer: No"
[[ "$SKIP_IAP" == "true" ]] && echo "  • Skip IAP: Yes" || echo "  • Skip IAP: No"
[[ "$SKIP_OAUTH" == "true" ]] && echo "  • Skip OAuth: Yes" || echo "  • Skip OAuth: No"
echo ""

# Confirm to proceed
if ! confirm_action "Proceed with deployment?"; then
    log_warning "Deployment cancelled by user"
    exit 0
fi

################################################################################
# DEPLOYMENT PIPELINE
################################################################################

# Track deployment start time
DEPLOYMENT_START=$(date +%s)

# Source and execute modules in sequence
log_info "Starting deployment pipeline..."
echo ""

# Module 1: Prerequisites & API Enablement
source "$LIB_DIR/prerequisites.sh"
if ! validate_prerequisites; then
    log_error "Prerequisites validation failed"
    exit 1
fi
if ! enable_apis; then
    log_error "API enablement failed"
    exit 1
fi

# Module 2: Infrastructure Setup
source "$LIB_DIR/infrastructure.sh"
if ! setup_infrastructure; then
    log_error "Infrastructure setup failed"
    exit 1
fi

# Module 3: Cloud Run Deployment
source "$LIB_DIR/cloudrun.sh"
if ! deploy_cloud_run; then
    log_error "Cloud Run deployment failed"
    exit 1
fi

# Module 4: OAuth Configuration
source "$LIB_DIR/oauth.sh"
if ! configure_oauth; then
    log_error "OAuth configuration failed"
    exit 1
fi

# Module 5: Load Balancer Setup
source "$LIB_DIR/loadbalancer.sh"
if ! setup_load_balancer; then
    log_error "Load Balancer setup failed"
    exit 1
fi

# Module 6: IAP Configuration
source "$LIB_DIR/iap.sh"
if ! configure_iap; then
    log_error "IAP configuration failed"
    exit 1
fi

# Module 7: Finalization & Summary
source "$LIB_DIR/finalize.sh"
if ! finalize_deployment; then
    log_error "Finalization failed"
    exit 1
fi

################################################################################
# DEPLOYMENT COMPLETE
################################################################################

# Calculate deployment duration
DEPLOYMENT_END=$(date +%s)
DEPLOYMENT_DURATION=$((DEPLOYMENT_END - DEPLOYMENT_START))
DEPLOYMENT_MINUTES=$((DEPLOYMENT_DURATION / 60))
DEPLOYMENT_SECONDS=$((DEPLOYMENT_DURATION % 60))

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 Deployment completed successfully in ${DEPLOYMENT_MINUTES}m ${DEPLOYMENT_SECONDS}s${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

################################################################################
# ENVIRONMENT VARIABLES SUMMARY
################################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 FINAL ENVIRONMENT VARIABLES USED IN DEPLOYMENT${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}Core Configuration:${NC}"
echo "  PROJECT_ID                = ${PROJECT_ID:-<not set>}"
echo "  PROJECT_NUMBER            = ${PROJECT_NUMBER:-<not set>}"
echo "  REGION                    = ${REGION:-<not set>}"
echo "  ORGANIZATION_DOMAIN       = ${ORGANIZATION_DOMAIN:-<not set>}"
echo "  IAP_ADMIN_USER            = ${IAP_ADMIN_USER:-<not set>}"
echo "  REPO                      = ${REPO:-<not set>}"
echo ""

echo -e "${YELLOW}Container Images:${NC}"
echo "  BACKEND_IMAGE             = ${BACKEND_IMAGE:-<not set>}"
echo "  FRONTEND_IMAGE            = ${FRONTEND_IMAGE:-<not set>}"
echo ""

echo -e "${YELLOW}Service Accounts:${NC}"
echo "  BACKEND_SA                = ${BACKEND_SA:-<not set>}"
echo "  FRONTEND_SA               = ${FRONTEND_SA:-<not set>}"
echo "  RAG_AGENT_SA              = ${RAG_AGENT_SA:-<not set>}"
echo "  IAP_ACCESSOR_SA           = ${IAP_ACCESSOR_SA:-<not set>}"
echo ""

echo -e "${YELLOW}Service URLs:${NC}"
echo "  BACKEND_URL               = ${BACKEND_URL:-<not set>}"
echo "  FRONTEND_URL              = ${FRONTEND_URL:-<not set>}"
echo "  LOAD_BALANCER_URL         = ${LOAD_BALANCER_URL:-<not set>}"
echo ""

echo -e "${YELLOW}Infrastructure:${NC}"
echo "  STATIC_IP                 = ${STATIC_IP:-<not set>}"
echo "  SSL_STATUS                = ${SSL_STATUS:-<not set>}"
echo ""

echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

################################################################################
# VERIFY BACKEND ACCOUNT_ENV
################################################################################

echo -e "${YELLOW}🔍 Verifying Backend Configuration:${NC}"
DEPLOYED_ACCOUNT_ENV=$(gcloud run services describe backend \
  --region="$REGION" \
  --format="yaml(spec.template.spec.containers[0].env)" \
  --project="$PROJECT_ID" 2>/dev/null | \
  grep -A1 "name: ACCOUNT_ENV" | \
  grep "value:" | \
  awk '{print $2}')

if [[ -n "$DEPLOYED_ACCOUNT_ENV" ]]; then
    echo "  ACCOUNT_ENV               = ${DEPLOYED_ACCOUNT_ENV}"
else
    echo -e "  ${RED}ACCOUNT_ENV               = <not set or unable to fetch>${NC}"
fi
echo ""
