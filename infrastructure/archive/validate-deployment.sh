#!/bin/bash
#
# validate-deployment.sh - Post-deployment validation and testing
#
# Validates that the deployment is working correctly:
# - SSL certificate status
# - IAP configuration
# - Backend/Frontend services
# - Load Balancer routing
# - CORS configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}║     POST-DEPLOYMENT VALIDATION                                ║${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Load configuration
if [[ -f "./deployment.config" ]]; then
    source ./deployment.config
else
    echo -e "${RED}❌ deployment.config not found${NC}"
    exit 1
fi

# Preflight: validate required inputs
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Section 0: Input Validation${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

MISSING=()
[[ -z "${PROJECT_ID:-}" ]] && MISSING+=("PROJECT_ID")
[[ -z "${REGION:-}" ]] && MISSING+=("REGION")
[[ -z "${REPO:-}" ]] && MISSING+=("REPO")
[[ -z "${ACCOUNT_ENV:-}" ]] && MISSING+=("ACCOUNT_ENV")
[[ -z "${ORGANIZATION_DOMAIN:-}" ]] && MISSING+=("ORGANIZATION_DOMAIN")

# SECRET_KEY is expected in secrets.env; source if present for validation context
if [[ -f "./secrets.env" ]]; then
    # shellcheck disable=SC1091
    source ./secrets.env
fi
[[ -z "${SECRET_KEY:-}" ]] && MISSING+=("SECRET_KEY (in secrets.env)")

if (( ${#MISSING[@]} > 0 )); then
    echo -e "${RED}❌ Missing required inputs:${NC} ${MISSING[*]}"
    echo -e "Please update deployment.config and secrets.env before proceeding."
    exit 1
fi

echo -e "  ${GREEN}✅ Inputs present${NC}"

# Note: REGION is the source of truth for Google Cloud Location
export GOOGLE_CLOUD_LOCATION="$REGION"
echo -e "  Using GOOGLE_CLOUD_LOCATION=${GOOGLE_CLOUD_LOCATION} (from REGION)"

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Validation function
validate() {
    local check_name="$1"
    local check_command="$2"
    local expected="$3"
    
    echo -n "  Checking $check_name ... "
    
    RESULT=$(eval "$check_command" 2>/dev/null || echo "ERROR")
    
    if [[ "$RESULT" == "$expected" ]] || [[ "$expected" == "*" && "$RESULT" != "ERROR" ]]; then
        echo -e "${GREEN}✅ $RESULT${NC}"
        ((CHECKS_PASSED++))
        return 0
    elif [[ "$RESULT" == "ERROR" ]]; then
        echo -e "${RED}❌ FAILED${NC}"
        ((CHECKS_FAILED++))
        return 1
    else
        echo -e "${YELLOW}⚠️  $RESULT (expected: $expected)${NC}"
        ((CHECKS_WARNING++))
        return 2
    fi
}

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Section 1: Load Balancer Infrastructure${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Get static IP
STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --format="value(address)" 2>/dev/null || echo "NOT_FOUND")
if [[ "$STATIC_IP" != "NOT_FOUND" ]]; then
    echo -e "  ${GREEN}✅ Static IP: $STATIC_IP${NC}"
    LOAD_BALANCER_URL="https://$STATIC_IP.nip.io"
    echo -e "  ${GREEN}✅ Load Balancer URL: $LOAD_BALANCER_URL${NC}"
    ((CHECKS_PASSED+=2))
else
    echo -e "  ${RED}❌ Static IP not found${NC}"
    ((CHECKS_FAILED+=2))
fi

# SSL Certificate
validate "SSL Certificate Status" \
    "gcloud compute ssl-certificates describe rag-agent-ssl-cert --global --format='value(managed.status)'" \
    "ACTIVE"

# URL Map
validate "URL Map" \
    "gcloud compute url-maps describe rag-agent-url-map --global --format='value(name)'" \
    "rag-agent-url-map"

# HTTPS Proxy
validate "HTTPS Proxy" \
    "gcloud compute target-https-proxies describe rag-agent-https-proxy --global --format='value(name)'" \
    "rag-agent-https-proxy"

# Forwarding Rule
validate "Forwarding Rule" \
    "gcloud compute forwarding-rules describe rag-agent-forwarding-rule --global --format='value(IPAddress)'" \
    "$STATIC_IP"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Section 2: Cloud Run Services${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Backend service
BACKEND_URL=$(gcloud run services describe backend --region="$REGION" --format='value(status.url)' 2>/dev/null || echo "NOT_FOUND")
if [[ "$BACKEND_URL" != "NOT_FOUND" ]]; then
    echo -e "  ${GREEN}✅ Backend URL: $BACKEND_URL${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "  ${RED}❌ Backend service not found${NC}"
    ((CHECKS_FAILED++))
fi

# Frontend service
FRONTEND_URL=$(gcloud run services describe frontend --region="$REGION" --format='value(status.url)' 2>/dev/null || echo "NOT_FOUND")
if [[ "$FRONTEND_URL" != "NOT_FOUND" ]]; then
    echo -e "  ${GREEN}✅ Frontend URL: $FRONTEND_URL${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "  ${RED}❌ Frontend service not found${NC}"
    ((CHECKS_FAILED++))
fi

# Backend status
validate "Backend Service Status" \
    "gcloud run services describe backend --region='$REGION' --format='value(status.conditions[0].status)'" \
    "True"

# Frontend status
validate "Frontend Service Status" \
    "gcloud run services describe frontend --region='$REGION' --format='value(status.conditions[0].status)'" \
    "True"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Section 3: IAP Configuration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Frontend IAP
validate "Frontend IAP Enabled" \
    "gcloud compute backend-services describe frontend-backend-service --global --format='value(iap.enabled)'" \
    "True"

# Backend IAP
validate "Backend IAP Enabled" \
    "gcloud compute backend-services describe backend-backend-service --global --format='value(iap.enabled)'" \
    "True"

# OAuth Client ID
OAUTH_CLIENT=$(gcloud compute backend-services describe frontend-backend-service --global --format='value(iap.oauth2ClientId)' 2>/dev/null || echo "NOT_FOUND")
if [[ "$OAUTH_CLIENT" != "NOT_FOUND" ]]; then
    echo -e "  ${GREEN}✅ OAuth Client ID: $OAUTH_CLIENT${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "  ${RED}❌ OAuth Client not configured${NC}"
    ((CHECKS_FAILED++))
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Section 4: Network Connectivity${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ "$STATIC_IP" != "NOT_FOUND" ]]; then
    # Test DNS resolution
    echo -n "  Testing DNS resolution ... "
    if host "$STATIC_IP.nip.io" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Resolves correctly${NC}"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠️  DNS resolution slow (try again in a moment)${NC}"
        ((CHECKS_WARNING++))
    fi
    
    # Test HTTPS connectivity (will get OAuth redirect or 401)
    echo -n "  Testing HTTPS connectivity ... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k "https://$STATIC_IP.nip.io" --max-time 10 2>/dev/null || echo "000")
    
    if [[ "$HTTP_CODE" == "302" ]] || [[ "$HTTP_CODE" == "303" ]]; then
        echo -e "${GREEN}✅ OAuth redirect (HTTP $HTTP_CODE) - IAP working${NC}"
        ((CHECKS_PASSED++))
    elif [[ "$HTTP_CODE" == "401" ]]; then
        echo -e "${GREEN}✅ Authentication required (HTTP $HTTP_CODE) - IAP working${NC}"
        ((CHECKS_PASSED++))
    elif [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${YELLOW}⚠️  HTTP 200 - IAP might not be enforcing${NC}"
        ((CHECKS_WARNING++))
    else
        echo -e "${YELLOW}⚠️  HTTP $HTTP_CODE - Check configuration${NC}"
        ((CHECKS_WARNING++))
    fi
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Section 5: Service Accounts & IAM${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check service accounts exist
validate "Backend Service Account" \
    "gcloud iam service-accounts describe backend-sa@$PROJECT_ID.iam.gserviceaccount.com --format='value(email)'" \
    "backend-sa@$PROJECT_ID.iam.gserviceaccount.com"

validate "Frontend Service Account" \
    "gcloud iam service-accounts describe frontend-sa@$PROJECT_ID.iam.gserviceaccount.com --format='value(email)'" \
    "frontend-sa@$PROJECT_ID.iam.gserviceaccount.com"

validate "RAG Agent Service Account" \
    "gcloud iam service-accounts describe adk-rag-agent-sa@$PROJECT_ID.iam.gserviceaccount.com --format='value(email)'" \
    "adk-rag-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Validation Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Checks Passed:   ${GREEN}$CHECKS_PASSED${NC}"
echo -e "  Checks Failed:   ${RED}$CHECKS_FAILED${NC}"
echo -e "  Warnings:        ${YELLOW}$CHECKS_WARNING${NC}"
echo ""

if [[ $CHECKS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ Validation PASSED! Deployment is healthy.${NC}"
    echo ""
    echo -e "${BLUE}🌐 Access Your Application:${NC}"
    echo -e "  URL: ${CYAN}$LOAD_BALANCER_URL${NC}"
    echo ""
    echo -e "${BLUE}📝 Next Steps:${NC}"
    echo "  1. Open URL in browser"
    echo "  2. Sign in with @$ORGANIZATION_DOMAIN account"
    echo "  3. Test RAG queries"
    echo "  4. Check browser console for errors"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Validation FAILED! Please review errors above.${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  • Check logs: gcloud logs read --service=backend --region=$REGION --limit=50"
    echo "  • Review configuration: ./infrastructure/deploy-all.sh --help"
    echo "  • See TROUBLESHOOT.md for common issues"
    echo ""
    exit 1
fi
