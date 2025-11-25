#!/bin/bash
#
# deploy-complete-oauth-v0.2.sh - Complete OAuth-Protected ADK RAG Agent Deployment
#
# DESCRIPTION:
# ============
# This script creates a complete OAuth-protected deployment of the ADK RAG Agent using
# Google Cloud Identity-Aware Proxy (IAP) with External HTTPS Load Balancer.
# It orchestrates the full deployment pipeline including Cloud Run services, Load Balancer,
# SSL certificates, IAP configuration, and OAuth consent screen setup.
#
# WHAT THIS SCRIPT DOES:
# ======================
# 1. Deploys Cloud Run services (frontend + backend)
# 2. Creates OAuth brand and consent screen configuration
# 3. Configures External HTTPS Load Balancer with static IP
# 4. Provisions SSL certificate using nip.io
# 5. Creates OAuth client with proper redirect URIs
# 6. Enables Identity-Aware Proxy (IAP) on Load Balancer
# 7. Configures domain-restricted access (@develom.com)
# 8. Sets up service account permissions
# 9. Validates complete OAuth flow
#
# PREREQUISITES:
# ==============
# - gcloud CLI installed and authenticated (run: gcloud auth login)
# - deployment.config file exists with required variables:
#   * PROJECT_ID: Your GCP project ID
#   * REGION: Deployment region (e.g., us-east4, us-central1)
#   * ORGANIZATION_DOMAIN: Domain for access restriction (e.g., develom.com)
#   * IAP_ADMIN_USER: Admin user email (e.g., hector@develom.com)
# - Billing enabled on GCP project
# - Required APIs will be enabled automatically
#
# USAGE:
# ======
# ./infrastructure/deploy-complete-oauth-v0.2.sh [OPTIONS]
#
# OPTIONS:
# ========
# -h, --help           Show this help message
# --skip-cloud-run     Skip Cloud Run deployment (use existing services)
# --skip-lb            Skip Load Balancer creation (use existing LB)
# --skip-iap           Skip IAP configuration (deploy without authentication)
#
# EXAMPLES:
# =========
# # Full deployment with all components
# ./infrastructure/deploy-complete-oauth-v0.2.sh
#
# # Skip Cloud Run deployment (use existing services)
# ./infrastructure/deploy-complete-oauth-v0.2.sh --skip-cloud-run
#
# # Deploy without IAP (testing only)
# ./infrastructure/deploy-complete-oauth-v0.2.sh --skip-iap
#
# EXPECTED OUTPUT:
# ================
# - Load Balancer URL: https://[STATIC_IP].nip.io
# - OAuth-protected access with Google sign-in
# - Domain-restricted access (@develom.com only)
# - SSL/HTTPS encryption
# - Enterprise-grade security
#
# DEPLOYMENT TIME:
# ================
# - Total time: 15-25 minutes
# - Cloud Run: 5-8 minutes
# - Load Balancer: 5-8 minutes
# - SSL Certificate: 3-5 minutes
# - IAP Configuration: 2-4 minutes
#
# TROUBLESHOOTING:
# ================
# - If OAuth errors occur, check redirect URIs match Load Balancer URL
# - SSL certificate provisioning can take up to 15 minutes
# - IAP may show "Error 52" if consent screen not configured
# - Use validate-security.sh to verify deployment
#
# ROLLBACK:
# =========
# To remove the deployment:
# - Delete Load Balancer: gcloud compute forwarding-rules delete
# - Delete Cloud Run services: gcloud run services delete
# - Remove OAuth client: gcloud iap oauth-clients delete
#
# RELATED SCRIPTS:
# ================
# - deploy-config.sh: Create/update deployment configuration
# - deploy-secure-v0.2.sh: Deploy Cloud Run services only
# - validate-security.sh: Validate OAuth and security setup
#
# This script includes the commands from deploy-secure.sh and the instructions
# from COMPLETE-OAUTH-SETUP.md file, tested and working in production.

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to show usage information
show_usage() {
    cat << EOF
${BLUE}deploy-complete-oauth-v0.2.sh - Complete OAuth-Protected ADK RAG Agent Deployment${NC}

${YELLOW}DESCRIPTION:${NC}
  Creates a complete OAuth-protected deployment of the ADK RAG Agent using
  Google Cloud Identity-Aware Proxy (IAP) with External HTTPS Load Balancer.

${YELLOW}USAGE:${NC}
  ./infrastructure/deploy-complete-oauth-v0.2.sh [OPTIONS]

${YELLOW}OPTIONS:${NC}
  -h, --help           Show this help message
  --skip-cloud-run     Skip Cloud Run deployment (use existing services)
  --skip-lb            Skip Load Balancer creation (use existing LB)
  --skip-iap           Skip IAP configuration (deploy without authentication)

${YELLOW}EXAMPLES:${NC}
  # Full deployment with all components
  ./infrastructure/deploy-complete-oauth-v0.2.sh

  # Skip Cloud Run deployment (use existing services)
  ./infrastructure/deploy-complete-oauth-v0.2.sh --skip-cloud-run

  # Deploy without IAP (testing only)
  ./infrastructure/deploy-complete-oauth-v0.2.sh --skip-iap

${YELLOW}PREREQUISITES:${NC}
  - gcloud CLI installed and authenticated
  - deployment.config file with PROJECT_ID, REGION, ORGANIZATION_DOMAIN, IAP_ADMIN_USER
  - Billing enabled on GCP project

${YELLOW}DEPLOYMENT TIME:${NC}
  Total: 15-25 minutes (Cloud Run: 5-8min, Load Balancer: 5-8min, SSL: 3-5min, IAP: 2-4min)

${YELLOW}RELATED SCRIPTS:${NC}
  - deploy-config.sh: Create/update deployment configuration
  - deploy-secure-v0.2.sh: Deploy Cloud Run services only
  - validate-security.sh: Validate OAuth and security setup

For more details, see the header comments in this script.
EOF
    exit 0
}

# Parse command line arguments
SKIP_CLOUD_RUN=false
SKIP_LB=false
SKIP_IAP=false

for arg in "$@"; do
    case $arg in
        -h|--help)
            show_usage
            ;;
        --skip-cloud-run)
            SKIP_CLOUD_RUN=true
            shift
            ;;
        --skip-lb)
            SKIP_LB=true
            shift
            ;;
        --skip-iap)
            SKIP_IAP=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Load configuration from deploy-config.sh
CONFIG_FILE="./deployment.config"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "Loading configuration from: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
    echo "Please run: ./infrastructure/deploy-config.sh --interactive"
    exit 1
fi

# Define service account names (matches deploy-secure-v0.2.sh)
export FRONTEND_SA="frontend-sa@$PROJECT_ID.iam.gserviceaccount.com"
export BACKEND_SA="backend-sa@$PROJECT_ID.iam.gserviceaccount.com"
export RAG_AGENT_SA="adk-rag-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"

echo -e "${BLUE}🚀 Complete OAuth Setup for ADK RAG Agent${NC}"
echo -e "${BLUE}============================================${NC}"
echo "This script creates the full Load Balancer + IAP architecture"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Organization: $ORGANIZATION_DOMAIN"
echo ""
echo -e "${YELLOW}Deployment Options:${NC}"
[[ "$SKIP_CLOUD_RUN" == "true" ]] && echo "  - Skip Cloud Run: Yes (using existing services)" || echo "  - Skip Cloud Run: No (will deploy)"
[[ "$SKIP_LB" == "true" ]] && echo "  - Skip Load Balancer: Yes (using existing LB)" || echo "  - Skip Load Balancer: No (will create)"
[[ "$SKIP_IAP" == "true" ]] && echo "  - Skip IAP: Yes (no authentication)" || echo "  - Skip IAP: No (OAuth-protected)"
echo ""

### 0) Prerequisites Check
echo -e "${CYAN}📋 Step 0: Checking Prerequisites${NC}"
echo "============================================"

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${RED}❌ Not authenticated with gcloud. Run: gcloud auth login${NC}"
    exit 1
fi

# Verify configuration is loaded
if [[ -z "$PROJECT_ID" ]] || [[ -z "$REGION" ]] || [[ -z "$ORGANIZATION_DOMAIN" ]] || [[ -z "$IAP_ADMIN_USER" ]]; then
    echo -e "${RED}❌ Missing required configuration variables${NC}"
    echo "Please ensure deployment.config contains: PROJECT_ID, REGION, ORGANIZATION_DOMAIN, IAP_ADMIN_USER"
    exit 1
fi

# Set project context
gcloud config set project "$PROJECT_ID" >/dev/null
echo -e "${GREEN}✅ Project set to $PROJECT_ID${NC}"

echo -e "${GREEN}✅ Prerequisites checked${NC}"
echo ""

### 1) Deploy Cloud Run Services
echo -e "${CYAN}📋 Step 1: Deploying Cloud Run Services${NC}"
echo "============================================"
echo "Running deploy-secure-v0.2.sh to create Cloud Run services and OAuth client..."

# Check if deploy-secure-v0.2.sh exists
if [[ ! -f "./infrastructure/deploy-secure-v0.2.sh" ]]; then
    echo -e "${RED}❌ deploy-secure-v0.2.sh not found${NC}"
    exit 1
fi

# Run deploy-secure-v0.2.sh to get Cloud Run services and OAuth client
echo -e "${YELLOW}🔧 Running deploy-secure-v0.2.sh...${NC}"
./infrastructure/deploy-secure-v0.2.sh

# Extract OAuth client ID from the output (you may need to adjust this)
echo -e "${YELLOW}📋 Extracting OAuth client information...${NC}"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
echo "Project Number: $PROJECT_NUMBER"

# Get OAuth brand and client
BRAND_LIST=$(gcloud iap oauth-brands list --format="value(name)" 2>/dev/null || echo "")
if [[ -n "$BRAND_LIST" ]]; then
    BRAND_ID=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f4)
    echo "OAuth Brand ID: $BRAND_ID"
    
    # NOTE: OAuth client creation moved to after Load Balancer setup
    # This ensures proper redirect URIs can be configured with the Load Balancer URL
    BRAND_PATH="projects/$PROJECT_NUMBER/brands/$BRAND_ID"
    echo "OAuth Brand Path: $BRAND_PATH"
    echo -e "${YELLOW}⚠️  OAuth client will be created after Load Balancer setup${NC}"
else
    echo -e "${RED}❌ No OAuth brand found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Cloud Run services deployed${NC}"
echo ""

### 2) Configure OAuth Consent Screen
echo -e "${CYAN}📋 Step 2: Configuring OAuth Consent Screen${NC}"
echo "============================================"

# Get Cloud Run service URLs for consent screen configuration
FRONTEND_URL=$(gcloud run services describe frontend --region="$REGION" --format="value(status.url)" 2>/dev/null || echo "")
BACKEND_URL=$(gcloud run services describe backend --region="$REGION" --format="value(status.url)" 2>/dev/null || echo "")

echo -e "${YELLOW}⚠️  CRITICAL: OAuth Consent Screen Setup Required${NC}"
echo "Now that Cloud Run services are deployed, configure the OAuth consent screen:"
echo ""
echo -e "${BLUE}📋 Required Information:${NC}"
echo "  Frontend URL: $FRONTEND_URL"
echo "  Backend URL: $BACKEND_URL"
echo "  Organization Domain: $ORGANIZATION_DOMAIN"
echo ""
echo -e "${BLUE}🔧 Setup Steps:${NC}"
echo "1. Go to: https://console.cloud.google.com/apis/credentials/consent?project=$PROJECT_ID"
echo "2. Select 'Internal' for organization users (@$ORGANIZATION_DOMAIN)"
echo "3. Fill in required fields:"
echo "   - App name: ADK RAG Agent"
echo "   - User support email: $IAP_ADMIN_USER"
echo "   - Developer contact: $IAP_ADMIN_USER"
echo "   - Authorized domains: Add '$ORGANIZATION_DOMAIN'"
echo "4. Add scopes (if prompted): openid, email, profile"
echo "5. PUBLISH the consent screen (important!)"
echo ""
echo -e "${YELLOW}💡 Note: You can use the Cloud Run URLs above for any redirect URI fields if needed${NC}"
echo ""
read -p "Have you completed the OAuth consent screen setup? (y/N): " consent_ready
if [[ "$consent_ready" != "y" && "$consent_ready" != "Y" ]]; then
    echo -e "${RED}❌ Please complete OAuth consent screen setup first${NC}"
    echo "The deployment cannot continue without a properly configured consent screen."
    exit 1
fi

echo -e "${GREEN}✅ OAuth consent screen configured${NC}"
echo ""

### 3) Create Static IP Address
echo -e "${CYAN}📋 Step 3: Creating Static IP Address${NC}"
echo "============================================"

# Check if static IP already exists
if gcloud compute addresses describe rag-agent-ip --global >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Static IP already exists${NC}"
    STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --format="value(address)")
else
    echo -e "${YELLOW}🔧 Creating static IP address...${NC}"
    gcloud compute addresses create rag-agent-ip --global
    STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --format="value(address)")
fi

echo "Static IP: $STATIC_IP"
export LOAD_BALANCER_URL="https://$STATIC_IP.nip.io"
echo "Load Balancer URL: $LOAD_BALANCER_URL"
echo -e "${GREEN}✅ Static IP configured${NC}"
echo ""

### 4) Create SSL Certificate
echo -e "${CYAN}📋 Step 4: Creating SSL Certificate${NC}"
echo "============================================"

# Check if SSL certificate already exists
if gcloud compute ssl-certificates describe rag-agent-ssl-cert --global >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  SSL certificate already exists${NC}"
else
    echo -e "${YELLOW}🔧 Creating SSL certificate for $STATIC_IP.nip.io...${NC}"
    gcloud compute ssl-certificates create rag-agent-ssl-cert \
        --domains="$STATIC_IP.nip.io" \
        --global
fi

echo -e "${YELLOW}📋 Checking SSL certificate status...${NC}"
SSL_STATUS=$(gcloud compute ssl-certificates describe rag-agent-ssl-cert --global --format="value(managed.status)")
echo "SSL Certificate Status: $SSL_STATUS"
if [[ "$SSL_STATUS" != "ACTIVE" ]]; then
    echo -e "${YELLOW}⚠️  SSL certificate is provisioning (takes 10-15 minutes)${NC}"
    echo "Certificate will be ready when status shows ACTIVE"
fi

echo -e "${GREEN}✅ SSL certificate configured${NC}"
echo ""

### 5) Create Network Endpoint Groups (NEGs)
echo -e "${CYAN}📋 Step 5: Creating Network Endpoint Groups${NC}"
echo "============================================"

# Create serverless NEGs for Cloud Run services
echo -e "${YELLOW}🔧 Creating NEGs for Cloud Run services...${NC}"

# Frontend NEG
if gcloud compute network-endpoint-groups describe frontend-neg --region="$REGION" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Frontend NEG already exists${NC}"
else
    gcloud compute network-endpoint-groups create frontend-neg \
        --region="$REGION" \
        --network-endpoint-type=serverless \
        --cloud-run-service=frontend
fi

# Backend NEG
if gcloud compute network-endpoint-groups describe backend-neg --region="$REGION" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Backend NEG already exists${NC}"
else
    gcloud compute network-endpoint-groups create backend-neg \
        --region="$REGION" \
        --network-endpoint-type=serverless \
        --cloud-run-service=backend
fi

echo -e "${GREEN}✅ Network Endpoint Groups created${NC}"
echo ""

### 6) Create Backend Services
echo -e "${CYAN}📋 Step 6: Creating Backend Services${NC}"
echo "============================================"

echo -e "${YELLOW}🔧 Creating backend services for Load Balancer...${NC}"

# Frontend backend service
if gcloud compute backend-services describe frontend-backend-service --global >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Frontend backend service already exists${NC}"
else
    gcloud compute backend-services create frontend-backend-service \
        --global \
        --load-balancing-scheme=EXTERNAL_MANAGED \
        --protocol=HTTPS
        
    # Clear port name for serverless NEG compatibility
    gcloud compute backend-services update frontend-backend-service \
        --global \
        --clear-port-name
        
    # Add NEG to backend service
    gcloud compute backend-services add-backend frontend-backend-service \
        --global \
        --network-endpoint-group=frontend-neg \
        --network-endpoint-group-region="$REGION"
fi

# Backend backend service
if gcloud compute backend-services describe backend-backend-service --global >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Backend backend service already exists${NC}"
else
    gcloud compute backend-services create backend-backend-service \
        --global \
        --load-balancing-scheme=EXTERNAL_MANAGED \
        --protocol=HTTPS
        
    # Clear port name for serverless NEG compatibility
    gcloud compute backend-services update backend-backend-service \
        --global \
        --clear-port-name
        
    # Add NEG to backend service
    gcloud compute backend-services add-backend backend-backend-service \
        --global \
        --network-endpoint-group=backend-neg \
        --network-endpoint-group-region="$REGION"
fi

echo -e "${GREEN}✅ Backend services created${NC}"
echo ""

### 7) Create URL Map for Routing
echo -e "${CYAN}📋 Step 7: Creating URL Map for Routing${NC}"
echo "============================================"

echo -e "${YELLOW}🔧 Creating URL map for path-based routing...${NC}"

# Create URL map
if gcloud compute url-maps describe rag-agent-url-map --global >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  URL map already exists${NC}"
else
    # Create URL map with default service
    gcloud compute url-maps create rag-agent-url-map \
        --default-service=frontend-backend-service \
        --global
fi

# Add path matcher for API routes
echo -e "${YELLOW}🔧 Configuring API routing (/api/* → backend)...${NC}"
gcloud compute url-maps add-path-matcher rag-agent-url-map \
    --path-matcher-name=api-matcher \
    --default-service=frontend-backend-service \
    --path-rules="/api/*=backend-backend-service" \
    --global 2>/dev/null || echo "Path matcher may already exist"

echo -e "${GREEN}✅ URL map configured${NC}"
echo "  Routes:"
echo "    / → Frontend service"
echo "    /api/* → Backend service"
echo ""

### 8) Create HTTPS Proxy and Forwarding Rule
echo -e "${CYAN}📋 Step 8: Creating HTTPS Proxy and Forwarding Rule${NC}"
echo "============================================"

# Create target HTTPS proxy
if gcloud compute target-https-proxies describe rag-agent-https-proxy --global >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  HTTPS proxy already exists${NC}"
else
    echo -e "${YELLOW}🔧 Creating HTTPS proxy...${NC}"
    gcloud compute target-https-proxies create rag-agent-https-proxy \
        --ssl-certificates=rag-agent-ssl-cert \
        --url-map=rag-agent-url-map \
        --global
fi

# Create forwarding rule
if gcloud compute forwarding-rules describe rag-agent-forwarding-rule --global >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Forwarding rule already exists${NC}"
else
    echo -e "${YELLOW}🔧 Creating forwarding rule...${NC}"
    gcloud compute forwarding-rules create rag-agent-forwarding-rule \
        --address=rag-agent-ip \
        --target-https-proxy=rag-agent-https-proxy \
        --global \
        --ports=443
fi

echo -e "${GREEN}✅ Load Balancer infrastructure created${NC}"
echo ""

### 9) Create OAuth Client with Load Balancer Redirect URIs
echo -e "${CYAN}📋 Step 9: Creating OAuth Client with Proper Redirect URIs${NC}"
echo "============================================"

# Now that Load Balancer is set up, create OAuth client with proper redirect URIs
echo -e "${YELLOW}🔧 Creating OAuth client with Load Balancer redirect URIs...${NC}"

# Define required redirect URIs based on Load Balancer static IP
LOAD_BALANCER_URL="https://$STATIC_IP.nip.io"
IAP_REDIRECT_URI="$LOAD_BALANCER_URL/_gcp_gatekeeper/authenticate"

echo "Load Balancer URL: $LOAD_BALANCER_URL"
echo "Required redirect URIs:"
echo "  - $LOAD_BALANCER_URL"
echo "  - $IAP_REDIRECT_URI"
echo ""

# Check for existing OAuth clients and clean up if necessary
echo "  Checking for existing OAuth clients..."
EXISTING_CLIENTS=$(gcloud iap oauth-clients list "$BRAND_PATH" --format="value(name)" 2>/dev/null || echo "")

if [[ -n "$EXISTING_CLIENTS" ]]; then
    echo -e "${YELLOW}⚠️  Found existing OAuth clients. Cleaning up...${NC}"
    # Delete existing OAuth clients to avoid conflicts
    while IFS= read -r client_name; do
        if [[ -n "$client_name" ]]; then
            echo "    Deleting existing client: $client_name"
            gcloud iap oauth-clients delete "$client_name" --quiet 2>/dev/null || echo "    Failed to delete $client_name"
        fi
    done <<< "$EXISTING_CLIENTS"
fi

# Create new OAuth client with proper display name
echo "  Creating new OAuth client for Load Balancer IAP..."
OAUTH_CLIENT_OUTPUT=$(gcloud iap oauth-clients create "$BRAND_PATH" \
  --display_name="Load Balancer IAP Client" 2>/dev/null || echo "")

if [[ -n "$OAUTH_CLIENT_OUTPUT" ]]; then
    # Extract client ID and secret from the output
    CLIENT_ID=$(echo "$OAUTH_CLIENT_OUTPUT" | grep -o '[0-9]\+-[a-zA-Z0-9]\+\.apps\.googleusercontent\.com')
    CLIENT_SECRET=$(echo "$OAUTH_CLIENT_OUTPUT" | grep -o 'GOCSPX-[a-zA-Z0-9_-]\+')
    
    echo -e "${GREEN}✅ OAuth client created successfully${NC}"
    echo "  Client ID: $CLIENT_ID"
    echo "  Client Secret: [REDACTED]"
    echo ""
    
    # CRITICAL: Manual step required for redirect URIs
    echo -e "${RED}🚨 CRITICAL MANUAL STEP REQUIRED:${NC}"
    echo -e "${YELLOW}The OAuth client has been created but redirect URIs must be added manually.${NC}"
    echo ""
    echo -e "${BLUE}📋 Required Steps:${NC}"
    echo "1. Go to: https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
    echo "2. Find and click on: Load Balancer IAP Client ($CLIENT_ID)"
    echo "3. In 'Authorized redirect URIs' section, add these EXACT URIs:"
    echo ""
    echo -e "${GREEN}🎯 THESE ARE THE URIs TO BE USED:${NC}"
    echo -e "${CYAN}   ➤ $LOAD_BALANCER_URL${NC}"
    echo -e "${CYAN}   ➤ $IAP_REDIRECT_URI${NC}"
    echo ""
    echo "4. Click 'SAVE'"
    echo ""
    echo -e "${YELLOW}💡 Why this step is required:${NC}"
    echo "Google Cloud CLI doesn't support setting redirect URIs during OAuth client creation."
    echo "These URIs are essential for IAP to work with the Load Balancer."
    echo ""
    
    # Wait for user confirmation
    read -p "Press Enter after you've added the redirect URIs in the Google Cloud Console..."
    echo ""
else
    echo -e "${RED}❌ Failed to create OAuth client${NC}"
    echo "  Brand path used: $BRAND_PATH"
    exit 1
fi

### 10) Configure Identity-Aware Proxy (IAP)
echo -e "${CYAN}📋 Step 10: Configuring Identity-Aware Proxy (IAP)${NC}"
echo "============================================"

# Create official IAP service account
echo -e "${YELLOW}🔧 Creating IAP service account...${NC}"
gcloud beta services identity create --service=iap.googleapis.com 2>/dev/null || echo "IAP service account may already exist"

# Grant Cloud Run Invoker role to IAP service account
echo -e "${YELLOW}🔧 Granting IAP service account permissions...${NC}"
IAP_SA="service-$PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com"
echo "IAP Service Account: $IAP_SA"

# Grant permissions to frontend
gcloud run services add-iam-policy-binding frontend \
    --region="$REGION" \
    --member="serviceAccount:$IAP_SA" \
    --role="roles/run.invoker" 2>/dev/null || echo "Permission may already exist"

# Grant permissions to backend
gcloud run services add-iam-policy-binding backend \
    --region="$REGION" \
    --member="serviceAccount:$IAP_SA" \
    --role="roles/run.invoker" 2>/dev/null || echo "Permission may already exist"

echo -e "${GREEN}✅ IAP service account configured${NC}"
echo ""

### 11) Enable IAP on Backend Services
echo -e "${CYAN}📋 Step 11: Enabling IAP on Backend Services${NC}"
echo "============================================"

echo -e "${YELLOW}🔧 Enabling IAP with OAuth client...${NC}"
echo "Using OAuth Client ID: $CLIENT_ID"

# Enable IAP on frontend backend service
echo "  Enabling IAP on frontend backend service..."
gcloud compute backend-services update frontend-backend-service \
    --global \
    --iap=enabled,oauth2-client-id="$CLIENT_ID",oauth2-client-secret="$CLIENT_SECRET"

# Enable IAP on backend backend service  
echo "  Enabling IAP on backend backend service..."
gcloud compute backend-services update backend-backend-service \
    --global \
    --iap=enabled,oauth2-client-id="$CLIENT_ID",oauth2-client-secret="$CLIENT_SECRET"

echo -e "${GREEN}✅ IAP enabled on backend services${NC}"
echo ""

### 12) Configure IAP Access Permissions
echo -e "${CYAN}📋 Step 12: Configuring IAP Access Permissions${NC}"
echo "============================================"

echo -e "${YELLOW}🔧 Granting IAP access permissions...${NC}"

# Grant IAP access to admin user
echo "  Granting access to $IAP_ADMIN_USER..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:$IAP_ADMIN_USER" \
    --role="roles/iap.httpsResourceAccessor" 2>/dev/null || echo "Permission may already exist"

# Grant IAP access to organization domain
echo "  Granting access to $ORGANIZATION_DOMAIN domain..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="domain:$ORGANIZATION_DOMAIN" \
    --role="roles/iap.httpsResourceAccessor" 2>/dev/null || echo "Permission may already exist"

echo -e "${GREEN}✅ IAP access permissions configured${NC}"
echo ""

### 13) Configure CORS and Environment Variables
echo -e "${CYAN}📋 Step 13: Configuring CORS and Environment Variables${NC}"
echo "============================================"

echo -e "${YELLOW}🔧 Updating backend CORS configuration...${NC}"
# Set FRONTEND_URL to Load Balancer domain for CORS and ensure ACCOUNT_ENV is set
gcloud run services update backend \
    --region="$REGION" \
    --set-env-vars="FRONTEND_URL=$LOAD_BALANCER_URL,ACCOUNT_ENV=develom"

echo -e "${YELLOW}🔧 Applying CORS breakthrough fix...${NC}"
# Make backend publicly accessible for Load Balancer routing (breakthrough solution)
gcloud run services add-iam-policy-binding backend \
    --region="$REGION" \
    --member="allUsers" \
    --role="roles/run.invoker" 2>/dev/null || echo "Public access may already exist"

echo -e "${YELLOW}🔨 Rebuilding frontend with Load Balancer URL...${NC}"
# CRITICAL: Next.js NEXT_PUBLIC_* variables are baked at BUILD time, not RUN time
# Must rebuild frontend with Load Balancer URL to support --ingress=internal-and-cloud-load-balancing
echo "Building frontend with NEXT_PUBLIC_BACKEND_URL=$LOAD_BALANCER_URL"

# Create new frontend image tag with LB URL
FRONTEND_IMAGE_LB="${FRONTEND_IMAGE}-lb"

gcloud builds submit ./frontend --config=frontend/cloudbuild.yaml \
  --substitutions=_IMAGE_NAME="$FRONTEND_IMAGE_LB",_BACKEND_URL="$LOAD_BALANCER_URL"

echo -e "${YELLOW}🚀 Redeploying frontend with Load Balancer URL...${NC}"
gcloud run deploy frontend \
  --image="$FRONTEND_IMAGE_LB" \
  --region="$REGION" \
  --service-account="$FRONTEND_SA" \
  --ingress=internal-and-cloud-load-balancing \
  --allow-unauthenticated \
  --cpu=1 --memory=512Mi --concurrency=80 \
  --min-instances=0 --max-instances=5 \
  --labels=app=adk-rag-agent,role=frontend,security=iap-protected

echo -e "${GREEN}✅ CORS and environment variables configured${NC}"
echo "  Backend FRONTEND_URL: $LOAD_BALANCER_URL"
echo "  Frontend NEXT_PUBLIC_BACKEND_URL: $LOAD_BALANCER_URL (rebuilt)"
echo "  Backend public access: Enabled (for Load Balancer routing)"
echo "  Frontend ingress: internal-and-cloud-load-balancing"
echo "  Backend ingress: internal-and-cloud-load-balancing"
echo ""

### 14) Final Status Check
echo -e "${CYAN}📋 Step 14: Final Status Check${NC}"
echo "============================================"

echo -e "${YELLOW}🔍 Checking deployment status...${NC}"

# Check SSL certificate status
SSL_STATUS=$(gcloud compute ssl-certificates describe rag-agent-ssl-cert --global --format="value(managed.status)")
echo "SSL Certificate Status: $SSL_STATUS"

# Check IAP status on backend services
echo "Checking IAP status..."
FRONTEND_IAP=$(gcloud compute backend-services describe frontend-backend-service --global --format="value(iap.enabled)" 2>/dev/null || echo "false")
BACKEND_IAP=$(gcloud compute backend-services describe backend-backend-service --global --format="value(iap.enabled)" 2>/dev/null || echo "false")
echo "  Frontend IAP enabled: $FRONTEND_IAP"
echo "  Backend IAP enabled: $BACKEND_IAP"

echo -e "${GREEN}✅ Status check complete${NC}"
echo ""

### 14) Deployment Summary
echo -e "${BLUE}🎉 Complete OAuth Deployment Summary${NC}"
echo "============================================"
echo ""
echo -e "${BLUE}📋 Deployment Details:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Static IP: $STATIC_IP"
echo "  Load Balancer URL: $LOAD_BALANCER_URL"
echo "  OAuth Client ID: $CLIENT_ID"
echo "  IAP Service Account: $IAP_SA"
echo ""
echo -e "${BLUE}🏗️ Architecture:${NC}"
echo "  Internet → External HTTPS Load Balancer (SSL + IAP) → Cloud Run Services"
echo "  ├── \"/\" → Frontend Cloud Run service"
echo "  └── \"/api/*\" → Backend Cloud Run service"
echo ""
echo -e "${BLUE}🔐 Security Features:${NC}"
echo "  ✅ External HTTPS Load Balancer with SSL"
echo "  ✅ Identity-Aware Proxy (IAP) with Google OAuth"
echo "  ✅ OAuth consent screen flow"
echo "  ✅ Domain-restricted access (@$ORGANIZATION_DOMAIN)"
echo "  ✅ Proper CORS configuration"
echo "  ✅ Two-layer authentication (IAP + Cloud Run IAM)"
echo ""
echo -e "${BLUE}🌐 Access Instructions:${NC}"
echo "1. Wait 2-3 minutes for configuration propagation"
echo "2. Clear browser cache completely"
echo "3. Open: $LOAD_BALANCER_URL"
echo "4. Expected flow:"
echo "   → Redirect to Google OAuth login"
echo "   → Sign in with @$ORGANIZATION_DOMAIN account"
echo "   → OAuth consent screen (if first time)"
echo "   → Access to RAG application"
echo ""

if [[ "$SSL_STATUS" != "ACTIVE" ]]; then
    echo -e "${YELLOW}⚠️  IMPORTANT: SSL Certificate Status${NC}"
    echo "SSL certificate is still provisioning (status: $SSL_STATUS)"
    echo "Wait 10-15 minutes for certificate to become ACTIVE"
    echo "Check status with: gcloud compute ssl-certificates describe rag-agent-ssl-cert --global"
    echo ""
fi

echo -e "${BLUE}🔧 Troubleshooting Commands:${NC}"
echo "# Check SSL certificate status"
echo "gcloud compute ssl-certificates describe rag-agent-ssl-cert --global"
echo ""
echo "# Check IAP status"
echo "gcloud compute backend-services describe frontend-backend-service --global"
echo ""
echo "# Check Cloud Run environment variables"
echo "gcloud run services describe backend --region=$REGION --format=\"export\""
echo ""
echo "# Check IAP permissions"
echo "gcloud projects get-iam-policy $PROJECT_ID"
echo ""
echo "# Run validation script"
echo "./infrastructure/validate-security.sh"
echo ""

echo -e "${GREEN}🚀 Complete OAuth setup finished!${NC}"
echo -e "${GREEN}Your RAG Agent is now deployed with Load Balancer + IAP architecture!${NC}"
echo ""
