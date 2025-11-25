#!/bin/bash
# Security validation script for ADK RAG Agent deployment
# Tests IAP configuration, OAuth setup, and application security
#
# USAGE:
# ======
# ./validate-security.sh [PROJECT_ID] [REGION]
#
# EXAMPLES:
# =========
# # Use deployment.config (recommended)
# ./validate-security.sh
#
# # Override project ID
# ./validate-security.sh adk-rag-hdtest6
#
# # Override both project ID and region
# ./validate-security.sh adk-rag-hdtest6 us-east4
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo -e "${BLUE}Usage: $0 PROJECT_ID [REGION]${NC}"
    echo ""
    echo -e "${YELLOW}Description:${NC}"
    echo "  Security validation script for ADK RAG Agent deployment"
    echo "  Tests IAP configuration, OAuth setup, and application security"
    echo ""
    echo -e "${YELLOW}Parameters:${NC}"
    echo "  PROJECT_ID    Optional. Google Cloud project ID (reads from deployment.config if not provided)"
    echo "  REGION        Optional. Google Cloud region (reads from deployment.config or defaults to us-central1)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  # Use deployment.config (recommended)"
    echo "  $0"
    echo ""
    echo "  # Override project ID"
    echo "  $0 adk-rag-hdtest6"
    echo ""
    echo "  # Override both project ID and region"
    echo "  $0 adk-rag-hdtest6 us-east4"
    echo ""
}

# Function to validate project ID format
validate_project_id() {
    local project_id="$1"
    
    # Check format (6-30 characters, lowercase, numbers, hyphens)
    if [[ ! "$project_id" =~ ^[a-z0-9-]{6,30}$ ]]; then
        echo -e "${RED}❌ Invalid project ID format: $project_id${NC}"
        echo "Project ID must be:"
        echo "  • 6-30 characters long"
        echo "  • Lowercase letters, numbers, and hyphens only"
        echo "  • Cannot start or end with a hyphen"
        return 1
    fi
    
    # Check for consecutive hyphens
    if [[ "$project_id" =~ -- ]]; then
        echo -e "${RED}❌ Project ID cannot contain consecutive hyphens${NC}"
        return 1
    fi
    
    # Check start/end characters
    if [[ "$project_id" =~ ^- ]] || [[ "$project_id" =~ -$ ]]; then
        echo -e "${RED}❌ Project ID cannot start or end with a hyphen${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate region format
validate_region() {
    local region="$1"
    
    # Check basic region format (e.g., us-central1, us-east4, europe-west1)
    if [[ ! "$region" =~ ^[a-z]+-[a-z]+[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid region format: $region${NC}"
        echo "Region must be in format like: us-central1, us-east4, europe-west1"
        return 1
    fi
    
    return 0
}

# Check for help flag first
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
fi

# Try to load configuration from deployment.config
CONFIG_FILE="./deployment.config"
if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${CYAN}📄 Loading configuration from $CONFIG_FILE${NC}"
    # shellcheck disable=SC1090
    source "$CONFIG_FILE" 2>/dev/null || true
    echo ""
fi

# Parse arguments (command-line args override config file)
PROJECT_ID="${1:-${PROJECT_ID:-}}"
REGION="${2:-${REGION:-us-central1}}"

# Validate we have required values
if [[ -z "$PROJECT_ID" ]]; then
    echo -e "${RED}❌ Error: No project ID found${NC}"
    echo "Either:"
    echo "  1. Run ./infrastructure/deploy-init.sh first to create deployment.config"
    echo "  2. Provide project ID as argument: $0 PROJECT_ID [REGION]"
    echo ""
    show_usage
    exit 1
fi

# Validate arguments
if ! validate_project_id "$PROJECT_ID"; then
    exit 1
fi

if ! validate_region "$REGION"; then
    exit 1
fi

echo -e "${BLUE}🔍 Security Validation for ADK RAG Agent${NC}"
echo -e "${CYAN}Project: ${BOLD}$PROJECT_ID${NC}"
echo -e "${CYAN}Region: ${BOLD}$REGION${NC}"
echo ""

# Function to check if a command succeeded
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        return 1
    fi
}

# Function to test HTTP response
test_http_response() {
    local url=$1
    local expected_status=$2
    local description=$3
    
    echo -n "  Testing $description... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✅ (HTTP $response)${NC}"
        return 0
    else
        echo -e "${RED}❌ (HTTP $response, expected $expected_status)${NC}"
        return 1
    fi
}

echo -e "${YELLOW}📋 1. Checking GCP Project Configuration${NC}"

# Check if project is set correctly
current_project=$(gcloud config get-value project 2>/dev/null)
if [ "$current_project" = "$PROJECT_ID" ]; then
    check_result "Project configuration"
else
    echo -e "${RED}❌ Project not set correctly. Current: $current_project, Expected: $PROJECT_ID${NC}"
    exit 1
fi

# Check authentication
gcloud auth list --filter=status=ACTIVE --format="value(account)" > /dev/null 2>&1
check_result "GCloud authentication"

echo ""
echo -e "${YELLOW}📋 2. Checking Required APIs${NC}"

required_apis=(
    "run.googleapis.com"
    "iap.googleapis.com" 
    "compute.googleapis.com"
    "artifactregistry.googleapis.com"
)

for api in "${required_apis[@]}"; do
    if gcloud services list --enabled --format="value(name)" | grep -q "^${api}$"; then
        check_result "$api enabled"
    else
        echo -e "${RED}❌ $api not enabled${NC}"
    fi
done

echo ""
echo -e "${YELLOW}📋 3. Checking Cloud Run Services${NC}"

# Check backend service
if gcloud run services describe backend --region="$REGION" >/dev/null 2>&1; then
    check_result "Backend service exists"
    BACKEND_URL=$(gcloud run services describe backend --region="$REGION" --format='value(status.url)')
    echo "  Backend URL: $BACKEND_URL"
else
    echo -e "${RED}❌ Backend service not found${NC}"
    BACKEND_URL=""
fi

# Check frontend service
if gcloud run services describe frontend --region="$REGION" >/dev/null 2>&1; then
    check_result "Frontend service exists"
    FRONTEND_URL=$(gcloud run services describe frontend --region="$REGION" --format='value(status.url)')
    echo "  Frontend URL: $FRONTEND_URL"
else
    echo -e "${RED}❌ Frontend service not found${NC}"
    FRONTEND_URL=""
fi

echo ""
echo -e "${YELLOW}📋 4. Checking OAuth Configuration${NC}"

# Check OAuth brands (OAuth brands use project number, not project ID)
BRAND_ID=""
PROJECT_NUMBER=""
BRAND_LIST=$(gcloud iap oauth-brands list --format="value(name)" 2>/dev/null || echo "")
if [[ -n "$BRAND_LIST" ]]; then
    BRAND_ID=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f4)
    PROJECT_NUMBER=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f2)
    check_result "OAuth brand exists (ID: $BRAND_ID, Project Number: $PROJECT_NUMBER)"
    
    # Check OAuth clients only if brand exists
    BRAND_PATH="projects/$PROJECT_NUMBER/brands/$BRAND_ID"
    OAUTH_CLIENTS=$(gcloud iap oauth-clients list "$BRAND_PATH" --format="value(name)" 2>/dev/null || echo "")
    if [[ -n "$OAUTH_CLIENTS" ]]; then
        check_result "OAuth client exists"
        CLIENT_ID=$(echo "$OAUTH_CLIENTS" | head -1 | grep -o '[0-9]\+-[a-zA-Z0-9]\+\.apps\.googleusercontent\.com')
        echo "  Client ID: $CLIENT_ID"
        CLIENT_COUNT=$(echo "$OAUTH_CLIENTS" | wc -l)
        echo "  Total OAuth clients: $CLIENT_COUNT"
    else
        echo -e "${RED}❌ OAuth client not found${NC}"
    fi
else
    echo -e "${RED}❌ OAuth brand not found${NC}"
    echo "  Please complete OAuth consent screen configuration"
    echo -e "${YELLOW}  Next steps:${NC}"
    echo "  1. Complete the OAuth consent screen setup in Google Cloud Console"
    echo "  2. Click 'Save and Continue' through all steps"
    echo "  3. Publish the app (if required)"
fi

echo ""
echo -e "${YELLOW}📋 5. Checking Cloud Run Authentication Configuration${NC}"

# Only check IAM policies if services exist
if [ -z "$BACKEND_URL" ] && [ -z "$FRONTEND_URL" ]; then
    echo -e "${YELLOW}⚠️  Cannot check authentication - services not deployed${NC}"
else
    # Get ingress settings (new security architecture)
    BACKEND_INGRESS=$(gcloud run services describe backend --region="$REGION" --format="value(metadata.annotations.'run.googleapis.com/ingress')" 2>/dev/null || echo "not-set")
    FRONTEND_INGRESS=$(gcloud run services describe frontend --region="$REGION" --format="value(metadata.annotations.'run.googleapis.com/ingress')" 2>/dev/null || echo "not-set")
    
    # Check if allUsers has access
    if [ -n "$BACKEND_URL" ]; then
        backend_policy=$(gcloud run services get-iam-policy backend --region="$REGION" --format="value(bindings.members)" 2>/dev/null || echo "")
        if echo "$backend_policy" | grep -q "allUsers"; then
            # Check if ingress restriction provides network-level security
            if [ "$BACKEND_INGRESS" = "internal-and-cloud-load-balancing" ]; then
                echo -e "${GREEN}✅ Backend: allUsers + ingress restriction (SECURE - Load Balancer only)${NC}"
                echo -e "   → Ingress: internal-and-cloud-load-balancing blocks direct access"
            else
                echo -e "${RED}❌ Backend allows unauthenticated access (security risk)${NC}"
                echo -e "   → Ingress: $BACKEND_INGRESS allows direct internet access"
            fi
        else
            echo -e "${GREEN}✅ Backend requires authentication (no allUsers access)${NC}"
        fi
    else
        backend_policy=""
    fi

    if [ -n "$FRONTEND_URL" ]; then
        frontend_policy=$(gcloud run services get-iam-policy frontend --region="$REGION" --format="value(bindings.members)" 2>/dev/null || echo "")
        if echo "$frontend_policy" | grep -q "allUsers"; then
            # Check if ingress restriction provides network-level security
            if [ "$FRONTEND_INGRESS" = "internal-and-cloud-load-balancing" ]; then
                echo -e "${GREEN}✅ Frontend: allUsers + ingress restriction (SECURE - Load Balancer only)${NC}"
                echo -e "   → Ingress: internal-and-cloud-load-balancing blocks direct access"
            else
                echo -e "${RED}❌ Frontend allows unauthenticated access (security risk)${NC}"
                echo -e "   → Ingress: $FRONTEND_INGRESS allows direct internet access"
            fi
        else
            echo -e "${GREEN}✅ Frontend requires authentication (no allUsers access)${NC}"
        fi
    else
        frontend_policy=""
    fi
fi

echo ""
echo -e "${YELLOW}📋 6. Checking Cloud Run Access Permissions${NC}"

if [ -z "$BACKEND_URL" ] && [ -z "$FRONTEND_URL" ]; then
    echo -e "${YELLOW}⚠️  Cannot check permissions - services not deployed${NC}"
else
    # Determine IAP service agent
    if [ -z "${PROJECT_NUMBER:-}" ]; then
        PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)" 2>/dev/null || echo "")
    fi
    IAP_SA="service-${PROJECT_NUMBER}@gcp-sa-iap.iam.gserviceaccount.com"

    # Helper to evaluate a policy blob
    evaluate_policy() {
        local svc_name="$1"; shift
        local policy_blob="$1"; shift

        if [ -z "$policy_blob" ]; then
            echo -e "${YELLOW}⚠️  $svc_name: No IAM bindings found${NC}"
            return
        fi

        # IAP SA presence
        if echo "$policy_blob" | grep -q "$IAP_SA"; then
            echo -e "${GREEN}✅ $svc_name: IAP service agent present (${IAP_SA})${NC}"
        else
            echo -e "${RED}❌ $svc_name: IAP service agent MISSING (${IAP_SA})${NC}"
        fi

        # Public principals
        if echo "$policy_blob" | grep -q "allUsers"; then
            echo -e "${RED}❌ $svc_name: allUsers has roles/run.invoker (public access)${NC}"
        else
            echo -e "${GREEN}✅ $svc_name: No allUsers binding${NC}"
        fi

        if echo "$policy_blob" | grep -q "allAuthenticatedUsers"; then
            echo -e "${RED}❌ $svc_name: allAuthenticatedUsers has roles/run.invoker (broad access)${NC}"
        else
            echo -e "${GREEN}✅ $svc_name: No allAuthenticatedUsers binding${NC}"
        fi

        # Domain bindings
        domain_bindings=$(echo "$policy_blob" | tr ',' '\n' | grep -o "domain:[^']\+" || true)
        if [ -n "$domain_bindings" ]; then
            echo -e "${YELLOW}⚠️  $svc_name: Domain bindings detected:${NC}"
            echo "$domain_bindings" | sed 's/^/    - /'
        else
            echo -e "${GREEN}✅ $svc_name: No domain bindings${NC}"
        fi

        # Summary of other principals (users/service accounts), excluding IAP SA
        other_principals=$(echo "$policy_blob" | tr ',' '\n' | grep -E "^(user:|serviceAccount:)" | grep -v "$IAP_SA" || true)
        if [ -n "$other_principals" ]; then
            echo "  Other principals:"
            echo "$other_principals" | sed 's/^/    - /'
        fi
    }

    # Evaluate backend policy
    if [ -n "$BACKEND_URL" ]; then
        evaluate_policy "Backend" "$backend_policy"
    fi

    # Evaluate frontend policy
    if [ -n "$FRONTEND_URL" ]; then
        evaluate_policy "Frontend" "$frontend_policy"
    fi
fi

echo ""
echo -e "${YELLOW}📋 7. Testing HTTP Security${NC}"

if [ -n "$FRONTEND_URL" ]; then
    # Test frontend requires authentication
    echo -n "  Testing Frontend authentication requirement... "
    response=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" 2>/dev/null || echo "000")
    
    # Interpret response based on ingress configuration
    if [ "$FRONTEND_INGRESS" = "internal-and-cloud-load-balancing" ]; then
        # With ingress restriction, HTTP 404 = blocked (GOOD)
        if [ "$response" = "404" ] || [ "$response" = "403" ]; then
            echo -e "${GREEN}✅ (HTTP $response - ingress restriction blocking direct access)${NC}"
        elif [ "$response" = "302" ] || [ "$response" = "401" ]; then
            echo -e "${GREEN}✅ (HTTP $response - authentication required)${NC}"
        else
            echo -e "${YELLOW}⚠️  (HTTP $response - unexpected response with ingress restriction)${NC}"
        fi
    else
        # Without ingress restriction, need auth redirect
        if [ "$response" = "403" ] || [ "$response" = "401" ] || [ "$response" = "302" ]; then
            echo -e "${GREEN}✅ (HTTP $response - authentication required)${NC}"
        else
            echo -e "${RED}❌ (HTTP $response - may allow unauthenticated access)${NC}"
        fi
    fi
    
    # Test that direct API access is also protected
    if [ -n "$BACKEND_URL" ]; then
        echo -n "  Testing Backend API authentication requirement... "
        api_response=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/api/sessions" 2>/dev/null || echo "000")
        
        # Interpret response based on ingress configuration
        if [ "$BACKEND_INGRESS" = "internal-and-cloud-load-balancing" ]; then
            # With ingress restriction, HTTP 404 = blocked (GOOD)
            if [ "$api_response" = "404" ] || [ "$api_response" = "403" ]; then
                echo -e "${GREEN}✅ (HTTP $api_response - ingress restriction blocking direct access)${NC}"
            elif [ "$api_response" = "302" ] || [ "$api_response" = "401" ]; then
                echo -e "${GREEN}✅ (HTTP $api_response - authentication required)${NC}"
            else
                echo -e "${YELLOW}⚠️  (HTTP $api_response - unexpected response with ingress restriction)${NC}"
            fi
        else
            # Without ingress restriction, need auth redirect
            if [ "$api_response" = "403" ] || [ "$api_response" = "401" ] || [ "$api_response" = "302" ]; then
                echo -e "${GREEN}✅ (HTTP $api_response - authentication required)${NC}"
            else
                echo -e "${RED}❌ (HTTP $api_response - may allow unauthenticated access)${NC}"
            fi
        fi
    fi
else
    echo -e "${RED}❌ Cannot test HTTP security - services not deployed${NC}"
fi

echo ""
echo -e "${YELLOW}📋 8. Checking Service Account Permissions${NC}"

# Check backend service account
BACKEND_SA="backend-sa@$PROJECT_ID.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$BACKEND_SA" >/dev/null 2>&1; then
    check_result "Backend service account exists"
    
    # Check Vertex AI permissions
    if gcloud projects get-iam-policy "$PROJECT_ID" --format="value(bindings.members)" | grep -q "$BACKEND_SA"; then
        check_result "Backend service account has IAM bindings"
    else
        echo -e "${RED}❌ Backend service account missing IAM permissions${NC}"
    fi
else
    echo -e "${RED}❌ Backend service account not found${NC}"
fi

echo ""
echo -e "${YELLOW}📋 9. Security Configuration Summary${NC}"

echo "Current Cloud Run Access List:"
echo "Backend Service:"
if [ -n "$backend_policy" ]; then
    echo "$backend_policy" | tr ',' '\n' | sed 's/^/  - /'
else
    echo "  - No permissions found"
fi

echo "Frontend Service:"
if [ -n "$frontend_policy" ]; then
    echo "$frontend_policy" | tr ',' '\n' | sed 's/^/  - /'
else
    echo "  - No permissions found"
fi

echo ""
echo -e "${BLUE}📋 10. Manual Testing Checklist${NC}"
echo ""
echo "To complete validation, manually test the following:"
echo ""
echo "1. 🌐 Open Frontend URL in incognito browser:"
echo "   $FRONTEND_URL"
echo ""
echo "2. 🔐 Verify Google OAuth redirect occurs"
echo "   - Should redirect to accounts.google.com"
echo "   - Should show 'Sign in with Google' page"
echo ""
echo "3. 👤 Test with @${ORGANIZATION_DOMAIN:-<org-domain>} account:"
echo "   - Sign in with ${IAP_ADMIN_USER:-<admin@org-domain>}"
echo "   - Should successfully authenticate"
echo "   - Should reach RAG application"
echo ""
echo "4. 🚫 Test with non-${ORGANIZATION_DOMAIN:-<org-domain>} account:"
echo "   - Try signing in with personal Gmail"
echo "   - Should be denied access"
echo ""
echo "5. 💬 Test Application Features:"
echo "   - Create account in RAG application"
echo "   - Send test message to RAG agent"
echo "   - Verify corpus listing works"
echo ""
echo "6. 🔒 Test Direct API Access:"
echo "   - Try accessing: $BACKEND_URL/api/sessions"
echo "   - Should redirect to OAuth (not show JSON)"
echo ""

echo -e "${GREEN}✅ Security validation complete!${NC}"
echo ""
echo -e "${BLUE}🔧 Quick Fix Commands:${NC}"
echo ""
echo "# Add user to IAP access:"
echo "gcloud iap web add-iam-policy-binding --resource-type=cloud-run --service=frontend --region=$REGION --member='user:newuser@develom.com' --role='roles/iap.httpsResourceAccessor'"
echo ""
echo "# Check IAP settings:"
echo "gcloud iap web get-iam-policy --resource-type=cloud-run --service=frontend --region=$REGION --format=json"
echo ""
echo "# View service logs:"
echo "gcloud logging read 'resource.type=cloud_run_service AND resource.labels.service_name=backend AND resource.labels.region=$REGION' --limit=20 --format=json"
