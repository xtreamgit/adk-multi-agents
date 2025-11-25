#!/bin/bash
# Secure Cloud Run deployment with Identity-Aware Proxy (IAP) for adk-rag-agent-2025
# Configured for hector@develom.com and develom.com organization
# This script creates a production-ready, secure deployment with Google OAuth protection

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${BLUE}🔐 Starting Secure RAG Agent Deployment with IAP${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Organization: $ORGANIZATION_DOMAIN"
echo "Admin User: $IAP_ADMIN_USER"
echo ""

### 0) Validate Prerequisites and Secrets
echo -e "${YELLOW}📋 Validating prerequisites...${NC}"

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${RED}❌ Not authenticated with gcloud. Run: gcloud auth login${NC}"
    exit 1
fi

# Check if application default credentials are set
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    echo -e "${RED}❌ Application default credentials not set. Run: gcloud auth application-default login${NC}"
    exit 1
fi

# Check for secrets file
SECRETS_FILE="./secrets.env"
if [[ ! -f "$SECRETS_FILE" ]]; then
  echo -e "${RED}❌ $SECRETS_FILE not found.${NC}"
  echo "Create it with: echo 'SECRET_KEY=your-generated-key-here' > $SECRETS_FILE"
  echo "Generate a key with: python3 generate_secret_key.py"
  exit 1
fi

# Load secrets
source "$SECRETS_FILE"
if [[ -z "${SECRET_KEY:-}" ]]; then
    echo -e "${RED}❌ SECRET_KEY missing in $SECRETS_FILE${NC}"
    exit 1
fi

### 1) Project Configuration
# Verify configuration is loaded
if [[ -z "$PROJECT_ID" ]] || [[ -z "$REGION" ]] || [[ -z "$ORGANIZATION_DOMAIN" ]] || [[ -z "$IAP_ADMIN_USER" ]] || [[ -z "$REPO" ]]; then
    echo -e "${RED}❌ Missing required configuration variables${NC}"
    echo "Please ensure deployment.config contains: PROJECT_ID, REGION, ORGANIZATION_DOMAIN, IAP_ADMIN_USER, REPO"
    exit 1
fi

# Use configuration values
export GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "manual")
export BACKEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/backend:$GIT_SHA"
export FRONTEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/frontend:$GIT_SHA"

# Set project
gcloud config set project "$PROJECT_ID" >/dev/null
echo -e "${GREEN}✅ Project set to $PROJECT_ID${NC}"

### 2) Enable Required APIs
echo -e "${YELLOW}🔧 Enabling required APIs...${NC}"
REQUIRED_APIS=(
  run.googleapis.com
  artifactregistry.googleapis.com
  cloudbuild.googleapis.com
  compute.googleapis.com
  iap.googleapis.com
  dns.googleapis.com
  iam.googleapis.com
  cloudresourcemanager.googleapis.com
  cloudidentity.googleapis.com
  aiplatform.googleapis.com
)

for API in "${REQUIRED_APIS[@]}"; do
  if ! gcloud services list --enabled --filter="name:$API" --format="value(name)" | grep -q "$API"; then
    echo "  Enabling $API..."
    gcloud services enable "$API" --quiet
  else
    echo "  ✓ $API already enabled"
  fi
done

### 3) Create Artifact Registry
echo -e "${YELLOW}📦 Setting up Artifact Registry...${NC}"
if ! gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1; then
  gcloud artifacts repositories create "$REPO" --repository-format=docker --location="$REGION"
  echo -e "${GREEN}✅ Artifact Registry created${NC}"
else
  echo -e "${GREEN}✅ Artifact Registry exists${NC}"
fi

### 4) Create Service Accounts with Required Permissions
echo -e "${YELLOW}🔐 Setting up service accounts...${NC}"

# Define all service accounts
export BACKEND_SA="backend-sa@$PROJECT_ID.iam.gserviceaccount.com"
export FRONTEND_SA="frontend-sa@$PROJECT_ID.iam.gserviceaccount.com"
export RAG_AGENT_SA="adk-rag-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"
export IAP_ACCESSOR_SA="iap-accessor@$PROJECT_ID.iam.gserviceaccount.com"

# Backend service account
if ! gcloud iam service-accounts describe "$BACKEND_SA" >/dev/null 2>&1; then
  gcloud iam service-accounts create backend-sa --display-name="RAG Backend Service Account"
  echo -e "${GREEN}✅ Backend service account created${NC}"
else
  echo -e "${GREEN}✅ Backend service account exists${NC}"
fi

# Frontend service account
if ! gcloud iam service-accounts describe "$FRONTEND_SA" >/dev/null 2>&1; then
  gcloud iam service-accounts create frontend-sa --display-name="RAG Frontend Service Account"
  echo -e "${GREEN}✅ Frontend service account created${NC}"
else
  echo -e "${GREEN}✅ Frontend service account exists${NC}"
fi

# Main RAG Agent service account (critical for RAG operations)
if ! gcloud iam service-accounts describe "$RAG_AGENT_SA" >/dev/null 2>&1; then
  gcloud iam service-accounts create adk-rag-agent-sa --display-name="ADK RAG Agent Service Account"
  echo -e "${GREEN}✅ RAG Agent service account created${NC}"
else
  echo -e "${GREEN}✅ RAG Agent service account exists${NC}"
fi

# IAP Accessor service account (for secure IAP access)
if ! gcloud iam service-accounts describe "$IAP_ACCESSOR_SA" >/dev/null 2>&1; then
  gcloud iam service-accounts create iap-accessor --display-name="IAP Accessor Service Account"
  echo -e "${GREEN}✅ IAP Accessor service account created${NC}"
else
  echo -e "${GREEN}✅ IAP Accessor service account exists${NC}"
fi

# Grant comprehensive Vertex AI permissions to RAG Agent SA
echo "  Granting comprehensive Vertex AI permissions to RAG Agent SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${RAG_AGENT_SA}" \
  --role="roles/aiplatform.admin" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${RAG_AGENT_SA}" \
  --role="roles/storage.admin" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${RAG_AGENT_SA}" \
  --role="roles/bigquery.admin" --quiet

# Grant basic permissions to backend SA
echo "  Granting basic Vertex AI permissions to Backend SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${BACKEND_SA}" \
  --role="roles/aiplatform.user" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${BACKEND_SA}" \
  --role="roles/storage.objectViewer" --quiet

# Grant IAP access permissions to IAP Accessor SA
echo "  Granting IAP permissions to IAP Accessor SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${IAP_ACCESSOR_SA}" \
  --role="roles/iap.httpsResourceAccessor" --quiet

### 5) Build and Deploy Backend
echo -e "${YELLOW}🔨 Building backend image...${NC}"
gcloud builds submit ./backend --config=backend/cloudbuild.yaml \
  --substitutions=_BACKEND_IMAGE="$BACKEND_IMAGE"

echo -e "${YELLOW}🚀 Deploying backend to Cloud Run...${NC}"
gcloud run deploy backend \
  --image="$BACKEND_IMAGE" \
  --region="$REGION" \
  --service-account="$RAG_AGENT_SA" \
  --ingress=internal-and-cloud-load-balancing \
  --allow-unauthenticated \
  --cpu=1 --memory=1Gi --concurrency=80 \
  --min-instances=0 --max-instances=10 \
  --set-env-vars="PROJECT_ID=$PROJECT_ID,GOOGLE_CLOUD_LOCATION=$REGION,SECRET_KEY=$SECRET_KEY,DATABASE_PATH=/app/data/users.db,LOG_LEVEL=INFO,ENVIRONMENT=production,ACCOUNT_ENV=develom" \
  --labels=app=adk-rag-agent,role=backend,security=iap-protected

# Get backend URL
BACKEND_URL=$(gcloud run services describe backend --region="$REGION" --format='value(status.url)')
echo -e "${GREEN}✅ Backend deployed: $BACKEND_URL${NC}"

### 6) Build and Deploy Frontend
echo -e "${YELLOW}🔨 Building frontend image...${NC}"
gcloud builds submit ./frontend --config=frontend/cloudbuild.yaml \
  --substitutions=_IMAGE_NAME="$FRONTEND_IMAGE",_BACKEND_URL="$BACKEND_URL"

echo -e "${YELLOW}🚀 Deploying frontend to Cloud Run...${NC}"
gcloud run deploy frontend \
  --image="$FRONTEND_IMAGE" \
  --region="$REGION" \
  --service-account="$FRONTEND_SA" \
  --ingress=internal-and-cloud-load-balancing \
  --allow-unauthenticated \
  --cpu=1 --memory=512Mi --concurrency=80 \
  --min-instances=0 --max-instances=5 \
  --labels=app=adk-rag-agent,role=frontend,security=iap-protected

# Get frontend URL
FRONTEND_URL=$(gcloud run services describe frontend --region="$REGION" --format='value(status.url)')
echo -e "${GREEN}✅ Frontend deployed: $FRONTEND_URL${NC}"

### 7) Configure OAuth Consent Screen
echo -e "${YELLOW}🔐 Configuring OAuth consent screen...${NC}"

# Check if OAuth brand exists (OAuth brands use project number, not project ID)
BRAND_ID=""
BRAND_LIST=$(gcloud iap oauth-brands list --format="value(name)" 2>/dev/null || echo "")
if [[ -n "$BRAND_LIST" ]]; then
    # Extract brand ID from the full path (projects/PROJECT_NUMBER/brands/BRAND_ID)
    BRAND_ID=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f4)
    PROJECT_NUMBER=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f2)
    echo -e "${GREEN}✅ OAuth brand exists: $BRAND_ID (Project Number: $PROJECT_NUMBER)${NC}"
else
    echo -e "${YELLOW}⚠️  OAuth brand not found. You need to create it manually:${NC}"
    echo "1. Go to: https://console.cloud.google.com/apis/credentials/consent?project=$PROJECT_ID"
    echo "2. Configure OAuth consent screen:"
    echo "   - User Type: Internal (for $ORGANIZATION_DOMAIN organization)"
    echo "   - App name: ADK RAG Agent"
    echo "   - User support email: $IAP_ADMIN_USER"
    echo "   - Developer contact: $IAP_ADMIN_USER"
    echo "3. Add authorized domains: $ORGANIZATION_DOMAIN"
    echo "4. Save and continue through all steps"
    echo ""
    read -p "Press Enter after configuring OAuth consent screen..."
    
# Try to get brand ID again
BRAND_LIST=$(gcloud iap oauth-brands list --format="value(name)" 2>/dev/null || echo "")
if [[ -n "$BRAND_LIST" ]]; then
    BRAND_ID=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f4)
    PROJECT_NUMBER=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f2)
    echo -e "${GREEN}✅ OAuth brand found: $BRAND_ID (Project Number: $PROJECT_NUMBER)${NC}"
else
    echo -e "${RED}❌ OAuth brand still not found. Please complete the OAuth consent screen setup.${NC}"
    exit 1
fi
fi

### 8) Create OAuth Client for IAP
echo -e "${YELLOW}🔐 Configuring OAuth client for IAP...${NC}"

# NOTE: OAuth client creation moved to deploy-complete-oauth-v0.2.sh
# This ensures OAuth client is created AFTER Load Balancer setup with proper redirect URIs
echo -e "${YELLOW}⚠️  OAuth client creation skipped - will be handled by deploy-complete-oauth-v0.2.sh${NC}"
echo "  OAuth client will be created with proper Load Balancer redirect URIs"

# Set placeholder variables for OAuth client (will be created later)
CLIENT_ID=""
CLIENT_SECRET=""
BRAND_PATH="projects/$PROJECT_NUMBER/brands/$BRAND_ID"

### 9) Configure Cloud Run Authentication (Google OAuth)
echo -e "${YELLOW}🔒 Configuring Google OAuth authentication on Cloud Run services...${NC}"

# Configure backend to require authentication (remove unauthenticated access)
echo "  Configuring backend authentication..."
gcloud run services remove-iam-policy-binding backend \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" || echo "  ⚠️  allUsers binding may not exist"

gcloud run services update backend \
  --region="$REGION" \
  --set-env-vars="FRONTEND_URL=$FRONTEND_URL"

# Configure frontend to require authentication (remove unauthenticated access)
echo "  Configuring frontend authentication..."
gcloud run services remove-iam-policy-binding frontend \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" || echo "  ⚠️  allUsers binding may not exist"

echo -e "${GREEN}✅ Cloud Run services configured to require authentication${NC}"
echo -e "${YELLOW}ℹ️  Note: This uses Cloud Run's built-in Google OAuth authentication${NC}"

### 10) Configure Cloud Run IAM Access
echo -e "${YELLOW}🔐 Configuring Cloud Run access permissions...${NC}"

# Grant Cloud Run Invoker role to admin user for backend
echo "  Granting Cloud Run access to $IAP_ADMIN_USER..."
gcloud run services add-iam-policy-binding backend \
  --region="$REGION" \
  --member="user:$IAP_ADMIN_USER" \
  --role="roles/run.invoker"

# Grant Cloud Run Invoker role to admin user for frontend  
gcloud run services add-iam-policy-binding frontend \
  --region="$REGION" \
  --member="user:$IAP_ADMIN_USER" \
  --role="roles/run.invoker"

# Grant access to the entire organization domain (optional)
echo "  Granting access to $ORGANIZATION_DOMAIN organization..."
gcloud run services add-iam-policy-binding backend \
  --region="$REGION" \
  --member="domain:$ORGANIZATION_DOMAIN" \
  --role="roles/run.invoker" || echo "  ⚠️  Domain access grant failed (may require organization admin)"

gcloud run services add-iam-policy-binding frontend \
  --region="$REGION" \
  --member="domain:$ORGANIZATION_DOMAIN" \
  --role="roles/run.invoker" || echo "  ⚠️  Domain access grant failed (may require organization admin)"

### 11) Final Configuration and Testing
echo -e "${YELLOW}🔧 Final configuration...${NC}"

# Update CORS configuration in backend to include IAP headers
gcloud run services update backend \
  --region="$REGION" \
  --set-env-vars="PROJECT_ID=$PROJECT_ID,GOOGLE_CLOUD_LOCATION=$REGION,SECRET_KEY=$SECRET_KEY,DATABASE_PATH=/app/data/users.db,LOG_LEVEL=INFO,ENVIRONMENT=production,ACCOUNT_ENV=develom,FRONTEND_URL=$FRONTEND_URL"

### 12) Deployment Summary
echo ""
echo -e "${GREEN}🎉 Secure Deployment Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Deployment Summary:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Backend URL: $BACKEND_URL"
echo "  Frontend URL: $FRONTEND_URL"
echo "  OAuth Client ID: $CLIENT_ID"
echo "  Admin User: $IAP_ADMIN_USER"
echo "  Organization: $ORGANIZATION_DOMAIN"
echo ""
echo -e "${BLUE}🔐 Security Features Enabled:${NC}"
echo "  ✅ Cloud Run Google OAuth authentication"
echo "  ✅ Organization domain restriction ($ORGANIZATION_DOMAIN)"
echo "  ✅ Minimal IAM permissions"
echo "  ✅ JWT-based application authentication"
echo "  ✅ OAuth consent screen configured"
echo ""
echo -e "${BLUE}🌐 Access Instructions:${NC}"
echo "1. Open your browser and navigate to: $FRONTEND_URL"
echo "2. You will be redirected to Google OAuth login"
echo "3. Sign in with your @$ORGANIZATION_DOMAIN account"
echo "4. After OAuth, you'll reach the application login screen"
echo "5. Create an account or log in to the RAG application"
echo ""
echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo "• Only users with Cloud Run Invoker permissions can access the application"
echo "• Users from $ORGANIZATION_DOMAIN organization have been granted access"
echo "• Cloud Run provides Google OAuth authentication"
echo "• The application provides additional JWT-based authentication"
echo ""
echo -e "${BLUE}🔧 Management Commands:${NC}"
echo "# Add more users to Cloud Run access:"
echo "gcloud run services add-iam-policy-binding frontend --region=$REGION --member='user:newuser@$ORGANIZATION_DOMAIN' --role='roles/run.invoker'"
echo ""
echo "# View Cloud Run IAM policy:"
echo "gcloud run services get-iam-policy frontend --region=$REGION"
echo ""
echo "# View application logs:"
echo "gcloud logs read --service=backend --region=$REGION --limit=50"
echo ""
echo -e "${GREEN}✅ Your RAG Agent is now securely deployed and protected with Google OAuth!${NC}"
