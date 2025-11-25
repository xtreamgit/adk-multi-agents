#!/bin/bash

#==============================================================================
# INGRESS SECURITY VALIDATION SCRIPT
#==============================================================================
# This script validates that:
# 1. Frontend/Backend services block direct internet access
# 2. Services only accept traffic from Load Balancer
# 3. Load Balancer properly routes traffic to services
# 4. IAP authentication is enforced at Load Balancer
#==============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load configuration
CONFIG_FILE="./deployment.config"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "📄 Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${CYAN}🔒 Ingress Security Validation${NC}"
echo -e "${CYAN}================================${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Display Security Architecture Diagram
echo -e "${CYAN}📐 Complete Security Architecture (With Ingress Control)${NC}"
echo -e "${CYAN}==========================================================${NC}"
echo ""
echo "Untrusted Path (Direct Access - BLOCKED):"
echo "┌─────────────────────────────────────────────────────────┐"
echo "│           Internet User (Untrusted)                      │"
echo "└────────────────────┬────────────────────────────────────┘"
echo "                     │"
echo "                     ▼"
echo "        Tries: https://backend-xyz.run.app"
echo "                     │"
echo "                     ▼"
echo "        ┌────────────────────────────┐"
echo "        │   Cloud Run Backend        │"
echo "        │   Ingress: internal-and-   │"
echo "        │   cloud-load-balancing     │"
echo "        │                            │"
echo "        │   ❌ ACCESS DENIED         │"
echo "        │   (not from Load Balancer) │"
echo "        └────────────────────────────┘"
echo ""
echo ""
echo "Trusted Path (Through Load Balancer - ALLOWED):"
echo "┌─────────────────────────────────────────────────────────┐"
echo "│           Internet User (Trusted Path)                   │"
echo "└────────────────────┬────────────────────────────────────┘"
echo "                     │"
echo "                     ▼"
echo "        https://YOUR-IP.nip.io (Load Balancer)"
echo "                     │"
echo "        ┌────────────▼────────────┐"
echo "        │    IAP Authentication   │"
echo "        │    OAuth Required       │"
echo "        │    @develom.com only    │"
echo "        └────────────┬────────────┘"
echo "                     │ ✅ Authenticated"
echo "                     ▼"
echo "        ┌────────────────────────────┐"
echo "        │   Load Balancer Routes:    │"
echo "        │   /* → Frontend            │"
echo "        │   /api/* → Backend         │"
echo "        └────────┬───────────┬───────┘"
echo "                 │           │"
echo "                 ▼           ▼"
echo "        ┌─────────────┐  ┌──────────────┐"
echo "        │  Frontend   │  │   Backend    │"
echo "        │  Ingress:   │  │   Ingress:   │"
echo "        │  internal-  │  │   internal-  │"
echo "        │  and-lb     │  │   and-lb     │"
echo "        │             │  │              │"
echo "        │  ✅ Accepts │  │   ✅ Accepts │"
echo "        │  from LB    │  │   from LB    │"
echo "        └─────────────┘  └──────────────┘"
echo ""
echo -e "${CYAN}==========================================================${NC}"
echo ""

#==============================================================================
# Test 1: Check Ingress Settings
#==============================================================================
echo -e "${BLUE}📋 Test 1: Checking Cloud Run Ingress Configuration${NC}"
echo "============================================"

# Get backend ingress setting
BACKEND_INGRESS=$(gcloud run services describe backend \
    --region="$REGION" \
    --format="value(metadata.annotations.'run.googleapis.com/ingress')" 2>/dev/null || echo "not-set")

# Get frontend ingress setting
FRONTEND_INGRESS=$(gcloud run services describe frontend \
    --region="$REGION" \
    --format="value(metadata.annotations.'run.googleapis.com/ingress')" 2>/dev/null || echo "not-set")

echo -e "Backend Ingress Setting: ${YELLOW}$BACKEND_INGRESS${NC}"
echo -e "Frontend Ingress Setting: ${YELLOW}$FRONTEND_INGRESS${NC}"
echo ""

# Validate ingress settings
if [[ "$BACKEND_INGRESS" == "internal-and-cloud-load-balancing" ]]; then
    echo -e "✅ Backend ingress: ${GREEN}Correctly configured${NC}"
    echo "   → Blocks direct internet access"
    echo "   → Only accepts Load Balancer traffic"
elif [[ "$BACKEND_INGRESS" == "all" ]]; then
    echo -e "⚠️  Backend ingress: ${YELLOW}NOT SECURE${NC}"
    echo "   → Accepts direct internet access"
    echo "   → Should be: internal-and-cloud-load-balancing"
else
    echo -e "❌ Backend ingress: ${RED}Unknown setting: $BACKEND_INGRESS${NC}"
fi

if [[ "$FRONTEND_INGRESS" == "internal-and-cloud-load-balancing" ]]; then
    echo -e "✅ Frontend ingress: ${GREEN}Correctly configured${NC}"
    echo "   → Blocks direct internet access"
    echo "   → Only accepts Load Balancer traffic"
elif [[ "$FRONTEND_INGRESS" == "all" ]]; then
    echo -e "⚠️  Frontend ingress: ${YELLOW}NOT SECURE${NC}"
    echo "   → Accepts direct internet access"
    echo "   → Should be: internal-and-cloud-load-balancing"
else
    echo -e "❌ Frontend ingress: ${RED}Unknown setting: $FRONTEND_INGRESS${NC}"
fi

echo ""

#==============================================================================
# Test 2: Get Service URLs
#==============================================================================
echo -e "${BLUE}📋 Test 2: Getting Service URLs${NC}"
echo "============================================"

BACKEND_URL=$(gcloud run services describe backend \
    --region="$REGION" \
    --format="value(status.url)" 2>/dev/null || echo "")

FRONTEND_URL=$(gcloud run services describe frontend \
    --region="$REGION" \
    --format="value(status.url)" 2>/dev/null || echo "")

if [[ -z "$BACKEND_URL" ]]; then
    echo -e "${RED}❌ Backend service not found${NC}"
    exit 1
fi

if [[ -z "$FRONTEND_URL" ]]; then
    echo -e "${RED}❌ Frontend service not found${NC}"
    exit 1
fi

echo -e "Backend Direct URL:  ${YELLOW}$BACKEND_URL${NC}"
echo -e "Frontend Direct URL: ${YELLOW}$FRONTEND_URL${NC}"
echo ""

#==============================================================================
# Test 3: Check Load Balancer
#==============================================================================
echo -e "${BLUE}📋 Test 3: Checking Load Balancer Configuration${NC}"
echo "============================================"

# Try multiple possible static IP names
LB_IP=""
LB_IP_NAME=""

# Try common static IP names
for IP_NAME in "rag-agent-static-ip" "rag-agent-ip" "adk-rag-agent-ip"; do
    IP_ADDR=$(gcloud compute addresses describe "$IP_NAME" \
        --global \
        --format="value(address)" 2>/dev/null || echo "")
    if [[ -n "$IP_ADDR" ]]; then
        LB_IP="$IP_ADDR"
        LB_IP_NAME="$IP_NAME"
        break
    fi
done

# If still not found, try to find any global address
if [[ -z "$LB_IP" ]]; then
    LB_IP=$(gcloud compute addresses list --global --format="value(address)" --limit=1 2>/dev/null || echo "")
    if [[ -n "$LB_IP" ]]; then
        LB_IP_NAME=$(gcloud compute addresses list --global --format="value(name)" --limit=1 2>/dev/null || echo "unknown")
    fi
fi

if [[ -z "$LB_IP" ]]; then
    echo -e "${YELLOW}⚠️  Load Balancer not deployed yet${NC}"
    echo "   This validation requires a deployed Load Balancer"
    echo "   Run: ./infrastructure/deploy-complete-oauth-v0.2.sh"
    LB_DEPLOYED=false
else
    LB_URL="https://$LB_IP.nip.io"
    echo -e "Static IP Name:    ${GREEN}$LB_IP_NAME${NC}"
    echo -e "Load Balancer IP:  ${GREEN}$LB_IP${NC}"
    echo -e "Load Balancer URL: ${GREEN}$LB_URL${NC}"
    LB_DEPLOYED=true
    
    # Check SSL certificate status
    SSL_STATUS=$(gcloud compute ssl-certificates describe rag-agent-ssl-cert \
        --global \
        --format="value(managed.status)" 2>/dev/null || echo "not-found")
    echo -e "SSL Certificate:   ${YELLOW}$SSL_STATUS${NC}"
    
    # Check forwarding rule
    FWD_RULE=$(gcloud compute forwarding-rules list --global \
        --format="value(name)" --limit=1 2>/dev/null || echo "not-found")
    if [[ "$FWD_RULE" != "not-found" ]]; then
        echo -e "Forwarding Rule:   ${GREEN}$FWD_RULE${NC}"
    fi
fi

echo ""

#==============================================================================
# Test 4: Test Direct Backend Access (Should Fail)
#==============================================================================
echo -e "${BLUE}📋 Test 4: Testing Direct Backend Access${NC}"
echo "============================================"
echo "Testing: curl $BACKEND_URL/api/sessions"
echo ""

# Test direct access to backend
BACKEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BACKEND_URL/api/sessions" 2>/dev/null || echo "000")

echo -e "HTTP Response Code: ${YELLOW}$BACKEND_RESPONSE${NC}"
echo ""

if [[ "$BACKEND_INGRESS" == "internal-and-cloud-load-balancing" ]]; then
    if [[ "$BACKEND_RESPONSE" == "403" ]] || [[ "$BACKEND_RESPONSE" == "404" ]]; then
        echo -e "✅ ${GREEN}SECURITY VERIFIED: Direct backend access blocked${NC}"
        echo "   → HTTP $BACKEND_RESPONSE indicates ingress restriction working"
        echo "   → Backend only accepts Load Balancer traffic"
    elif [[ "$BACKEND_RESPONSE" == "200" ]]; then
        echo -e "❌ ${RED}SECURITY RISK: Direct backend access allowed!${NC}"
        echo "   → Backend is accepting direct internet traffic"
        echo "   → Ingress setting may not be applied correctly"
    elif [[ "$BACKEND_RESPONSE" == "302" ]] || [[ "$BACKEND_RESPONSE" == "401" ]]; then
        echo -e "⚠️  ${YELLOW}Authentication redirect detected${NC}"
        echo "   → Backend requires authentication but is reachable"
    else
        echo -e "⚠️  ${YELLOW}Unexpected response: $BACKEND_RESPONSE${NC}"
        echo "   → May indicate network issues or service problems"
    fi
else
    echo -e "⚠️  Backend ingress allows direct access (ingress=$BACKEND_INGRESS)"
fi

echo ""

#==============================================================================
# Test 5: Test Direct Frontend Access (Should Fail)
#==============================================================================
echo -e "${BLUE}📋 Test 5: Testing Direct Frontend Access${NC}"
echo "============================================"
echo "Testing: curl $FRONTEND_URL"
echo ""

# Test direct access to frontend
FRONTEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$FRONTEND_URL" 2>/dev/null || echo "000")

echo -e "HTTP Response Code: ${YELLOW}$FRONTEND_RESPONSE${NC}"
echo ""

if [[ "$FRONTEND_INGRESS" == "internal-and-cloud-load-balancing" ]]; then
    if [[ "$FRONTEND_RESPONSE" == "403" ]] || [[ "$FRONTEND_RESPONSE" == "404" ]]; then
        echo -e "✅ ${GREEN}SECURITY VERIFIED: Direct frontend access blocked${NC}"
        echo "   → HTTP $FRONTEND_RESPONSE indicates ingress restriction working"
        echo "   → Frontend only accepts Load Balancer traffic"
    elif [[ "$FRONTEND_RESPONSE" == "200" ]]; then
        echo -e "❌ ${RED}SECURITY RISK: Direct frontend access allowed!${NC}"
        echo "   → Frontend is accepting direct internet traffic"
        echo "   → Ingress setting may not be applied correctly"
    elif [[ "$FRONTEND_RESPONSE" == "302" ]] || [[ "$FRONTEND_RESPONSE" == "401" ]]; then
        echo -e "⚠️  ${YELLOW}Authentication redirect detected${NC}"
        echo "   → Frontend requires authentication but is reachable"
    else
        echo -e "⚠️  ${YELLOW}Unexpected response: $FRONTEND_RESPONSE${NC}"
        echo "   → May indicate network issues or service problems"
    fi
else
    echo -e "⚠️  Frontend ingress allows direct access (ingress=$FRONTEND_INGRESS)"
fi

echo ""

#==============================================================================
# Test 6: Test Load Balancer Access (Should Work with IAP)
#==============================================================================
if [[ "$LB_DEPLOYED" == true ]]; then
    echo -e "${BLUE}📋 Test 6: Testing Load Balancer Access${NC}"
    echo "============================================"
    echo "Testing: curl $LB_URL"
    echo ""
    
    # Test Load Balancer (will redirect to IAP if configured)
    LB_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$LB_URL" 2>/dev/null || echo "000")
    
    echo -e "HTTP Response Code: ${YELLOW}$LB_RESPONSE${NC}"
    echo ""
    
    if [[ "$LB_RESPONSE" == "302" ]]; then
        echo -e "✅ ${GREEN}IAP AUTHENTICATION ACTIVE${NC}"
        echo "   → Load Balancer redirects to OAuth (HTTP 302)"
        echo "   → Authentication required to access application"
        
        # Get redirect location
        REDIRECT=$(curl -s -I --max-time 10 "$LB_URL" 2>/dev/null | grep -i "^location:" | awk '{print $2}' | tr -d '\r')
        if [[ "$REDIRECT" == *"accounts.google.com"* ]]; then
            echo -e "   → Redirect to: ${CYAN}Google OAuth${NC}"
        elif [[ -n "$REDIRECT" ]]; then
            echo -e "   → Redirect to: ${CYAN}${REDIRECT:0:60}...${NC}"
        fi
    elif [[ "$LB_RESPONSE" == "200" ]]; then
        echo -e "⚠️  ${YELLOW}Load Balancer accessible without authentication${NC}"
        echo "   → HTTP 200 indicates IAP may not be enabled"
        echo "   → Check IAP configuration on backend services"
    elif [[ "$LB_RESPONSE" == "403" ]]; then
        echo -e "⚠️  ${YELLOW}Access forbidden${NC}"
        echo "   → IAP may be blocking access"
        echo "   → Check IAP access policy for your user"
    elif [[ "$LB_RESPONSE" == "000" ]]; then
        echo -e "⚠️  ${YELLOW}Cannot reach Load Balancer${NC}"
        echo "   → SSL certificate may still be provisioning"
        echo "   → Check: gcloud compute ssl-certificates list --global"
    else
        echo -e "⚠️  ${YELLOW}Unexpected response: $LB_RESPONSE${NC}"
    fi
    
    echo ""
    
    #==========================================================================
    # Test 7: Test API Endpoint Through Load Balancer
    #==========================================================================
    echo -e "${BLUE}📋 Test 7: Testing API Routing Through Load Balancer${NC}"
    echo "============================================"
    echo "Testing: curl $LB_URL/api/sessions"
    echo ""
    
    API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$LB_URL/api/sessions" 2>/dev/null || echo "000")
    
    echo -e "HTTP Response Code: ${YELLOW}$API_RESPONSE${NC}"
    echo ""
    
    if [[ "$API_RESPONSE" == "302" ]]; then
        echo -e "✅ ${GREEN}API routing with IAP protection${NC}"
        echo "   → /api/* paths redirect to OAuth"
        echo "   → Backend protected by IAP"
    elif [[ "$API_RESPONSE" == "200" ]] || [[ "$API_RESPONSE" == "405" ]]; then
        echo -e "✅ ${GREEN}API endpoint reachable${NC}"
        echo "   → Load Balancer routing to backend"
        echo "   → Backend responding to requests"
    elif [[ "$API_RESPONSE" == "403" ]]; then
        echo -e "⚠️  ${YELLOW}Access forbidden${NC}"
        echo "   → IAP may be blocking access"
    else
        echo -e "⚠️  ${YELLOW}Unexpected response: $API_RESPONSE${NC}"
    fi
    
    echo ""
fi

#==============================================================================
# Test 8: Verify IAP Configuration on Backend Services
#==============================================================================
if [[ "$LB_DEPLOYED" == true ]]; then
    echo -e "${BLUE}📋 Test 8: Checking IAP Configuration${NC}"
    echo "============================================"
    
    # Check IAP on frontend backend service
    FRONTEND_IAP=$(gcloud compute backend-services describe frontend-backend-service \
        --global \
        --format="value(iap.enabled)" 2>/dev/null || echo "false")
    
    # Check IAP on backend backend service
    BACKEND_IAP=$(gcloud compute backend-services describe backend-backend-service \
        --global \
        --format="value(iap.enabled)" 2>/dev/null || echo "false")
    
    echo -e "Frontend Backend Service IAP: ${YELLOW}$FRONTEND_IAP${NC}"
    echo -e "Backend Backend Service IAP:  ${YELLOW}$BACKEND_IAP${NC}"
    echo ""
    
    if [[ "$FRONTEND_IAP" == "True" ]]; then
        echo -e "✅ ${GREEN}Frontend protected by IAP${NC}"
    else
        echo -e "⚠️  ${YELLOW}Frontend IAP not enabled${NC}"
    fi
    
    if [[ "$BACKEND_IAP" == "True" ]]; then
        echo -e "✅ ${GREEN}Backend protected by IAP${NC}"
    else
        echo -e "⚠️  ${YELLOW}Backend IAP not enabled${NC}"
    fi
    
    echo ""
fi

#==============================================================================
# Test 9: Check Frontend Backend URL Configuration
#==============================================================================
if [[ "$LB_DEPLOYED" == true ]]; then
    echo -e "${BLUE}📋 Test 9: Checking Frontend Configuration${NC}"
    echo "============================================"
    
    # Get frontend image
    FRONTEND_IMAGE=$(gcloud run services describe frontend \
        --region="$REGION" \
        --format="value(spec.template.spec.containers[0].image)" 2>/dev/null || echo "")
    
    echo -e "Frontend Image: ${YELLOW}${FRONTEND_IMAGE##*/}${NC}"
    
    if [[ "$FRONTEND_IMAGE" == *"-lb"* ]]; then
        echo -e "✅ ${GREEN}Frontend rebuilt with Load Balancer URL${NC}"
        echo "   → Image tag contains '-lb' suffix"
        echo "   → Frontend should call Load Balancer, not direct backend"
    else
        echo -e "⚠️  ${YELLOW}Frontend may still use direct backend URL${NC}"
        echo "   → Image does not contain '-lb' suffix"
        echo "   → Frontend may need rebuild with Load Balancer URL"
    fi
    
    echo ""
fi

#==============================================================================
# Test 10: Check OAuth Configuration
#==============================================================================
echo -e "${BLUE}📋 Test 10: Checking OAuth Configuration${NC}"
echo "============================================"

# Check OAuth brands (OAuth brands use project number, not project ID)
BRAND_ID=""
PROJECT_NUMBER=""
BRAND_LIST=$(gcloud iap oauth-brands list --format="value(name)" 2>/dev/null || echo "")
if [[ -n "$BRAND_LIST" ]]; then
    BRAND_ID=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f4)
    PROJECT_NUMBER=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f2)
    echo -e "✅ ${GREEN}OAuth brand exists${NC}"
    echo -e "   Brand ID: ${YELLOW}$BRAND_ID${NC}"
    echo -e "   Project Number: ${YELLOW}$PROJECT_NUMBER${NC}"
    
    # Check OAuth clients only if brand exists
    BRAND_PATH="projects/$PROJECT_NUMBER/brands/$BRAND_ID"
    OAUTH_CLIENTS=$(gcloud iap oauth-clients list "$BRAND_PATH" --format="value(name)" 2>/dev/null || echo "")
    if [[ -n "$OAUTH_CLIENTS" ]]; then
        echo -e "✅ ${GREEN}OAuth client exists${NC}"
        CLIENT_ID=$(echo "$OAUTH_CLIENTS" | head -1 | grep -o '[0-9]\+-[a-zA-Z0-9]\+\.apps\.googleusercontent\.com')
        echo -e "   Client ID: ${YELLOW}$CLIENT_ID${NC}"
        CLIENT_COUNT=$(echo "$OAUTH_CLIENTS" | wc -l | tr -d ' ')
        echo -e "   Total OAuth clients: ${YELLOW}$CLIENT_COUNT${NC}"
    else
        echo -e "❌ ${RED}OAuth client not found${NC}"
        echo "   OAuth client is required for IAP authentication"
    fi
else
    echo -e "❌ ${RED}OAuth brand not found${NC}"
    echo "   Please complete OAuth consent screen configuration"
    echo -e "${YELLOW}   Next steps:${NC}"
    echo "   1. Configure OAuth consent screen in Google Cloud Console"
    echo "   2. Create IAP OAuth client"
    echo "   3. Re-run deployment script"
fi

echo ""

#==============================================================================
# Summary
#==============================================================================
echo -e "${CYAN}📊 Security Validation Summary${NC}"
echo "================================"
echo ""

# Ingress Summary
echo "🔒 Ingress Configuration:"
if [[ "$BACKEND_INGRESS" == "internal-and-cloud-load-balancing" ]]; then
    echo -e "  ✅ Backend: ${GREEN}Secure${NC} (blocks direct access)"
else
    echo -e "  ⚠️  Backend: ${YELLOW}Insecure${NC} (allows direct access)"
fi

if [[ "$FRONTEND_INGRESS" == "internal-and-cloud-load-balancing" ]]; then
    echo -e "  ✅ Frontend: ${GREEN}Secure${NC} (blocks direct access)"
else
    echo -e "  ⚠️  Frontend: ${YELLOW}Insecure${NC} (allows direct access)"
fi

echo ""

# Direct Access Summary
echo "🌐 Direct Access Tests:"
if [[ "$BACKEND_RESPONSE" == "403" ]] || [[ "$BACKEND_RESPONSE" == "404" ]]; then
    echo -e "  ✅ Backend: ${GREEN}Blocked${NC} (HTTP $BACKEND_RESPONSE)"
elif [[ "$BACKEND_RESPONSE" == "200" ]]; then
    echo -e "  ❌ Backend: ${RED}Accessible${NC} (HTTP $BACKEND_RESPONSE)"
else
    echo -e "  ⚠️  Backend: ${YELLOW}Unknown${NC} (HTTP $BACKEND_RESPONSE)"
fi

if [[ "$FRONTEND_RESPONSE" == "403" ]] || [[ "$FRONTEND_RESPONSE" == "404" ]]; then
    echo -e "  ✅ Frontend: ${GREEN}Blocked${NC} (HTTP $FRONTEND_RESPONSE)"
elif [[ "$FRONTEND_RESPONSE" == "200" ]]; then
    echo -e "  ❌ Frontend: ${RED}Accessible${NC} (HTTP $FRONTEND_RESPONSE)"
else
    echo -e "  ⚠️  Frontend: ${YELLOW}Unknown${NC} (HTTP $FRONTEND_RESPONSE)"
fi

echo ""

# Load Balancer Summary
if [[ "$LB_DEPLOYED" == true ]]; then
    echo "⚡ Load Balancer Access:"
    if [[ "$LB_RESPONSE" == "302" ]]; then
        echo -e "  ✅ IAP: ${GREEN}Active${NC} (redirects to OAuth)"
    elif [[ "$LB_RESPONSE" == "200" ]]; then
        echo -e "  ⚠️  IAP: ${YELLOW}Not configured${NC} (direct access)"
    else
        echo -e "  ⚠️  IAP: ${YELLOW}Unknown status${NC} (HTTP $LB_RESPONSE)"
    fi
    
    if [[ "$FRONTEND_IAP" == "True" ]] && [[ "$BACKEND_IAP" == "True" ]]; then
        echo -e "  ✅ Backend Services: ${GREEN}IAP enabled${NC}"
    else
        echo -e "  ⚠️  Backend Services: ${YELLOW}IAP not fully enabled${NC}"
    fi
else
    echo "⚡ Load Balancer: Not deployed"
fi

echo ""

# OAuth Summary
echo "🔐 OAuth Configuration:"
if [[ -n "$BRAND_LIST" ]] && [[ -n "$OAUTH_CLIENTS" ]]; then
    echo -e "  ✅ OAuth: ${GREEN}Configured${NC} (brand + client)"
elif [[ -n "$BRAND_LIST" ]]; then
    echo -e "  ⚠️  OAuth: ${YELLOW}Incomplete${NC} (brand exists, client missing)"
else
    echo -e "  ❌ OAuth: ${RED}Not configured${NC} (brand missing)"
fi

echo ""
echo -e "${CYAN}================================${NC}"

# Final verdict
echo ""
if [[ "$BACKEND_INGRESS" == "internal-and-cloud-load-balancing" ]] && \
   [[ "$FRONTEND_INGRESS" == "internal-and-cloud-load-balancing" ]] && \
   ([[ "$BACKEND_RESPONSE" == "403" ]] || [[ "$BACKEND_RESPONSE" == "404" ]]) && \
   ([[ "$FRONTEND_RESPONSE" == "403" ]] || [[ "$FRONTEND_RESPONSE" == "404" ]]); then
    echo -e "${GREEN}✅ INGRESS SECURITY VERIFIED${NC}"
    echo "   All services properly configured with ingress restrictions"
    echo "   Direct internet access successfully blocked"
    echo "   Traffic can only flow through Load Balancer"
else
    echo -e "${YELLOW}⚠️  INGRESS SECURITY INCOMPLETE${NC}"
    echo "   Some services may allow direct internet access"
    echo "   Review configuration and redeploy if necessary"
fi

echo ""

# Recommendations
if [[ "$LB_DEPLOYED" == false ]]; then
    echo -e "${YELLOW}💡 Recommendation:${NC}"
    echo "   Deploy Load Balancer for complete security:"
    echo "   ./infrastructure/deploy-complete-oauth-v0.2.sh"
    echo ""
fi

if [[ "$BACKEND_INGRESS" != "internal-and-cloud-load-balancing" ]] || \
   [[ "$FRONTEND_INGRESS" != "internal-and-cloud-load-balancing" ]]; then
    echo -e "${YELLOW}💡 Fix Ingress Settings:${NC}"
    echo "   Update services to use secure ingress:"
    echo ""
    echo "   gcloud run services update backend \\"
    echo "     --region=$REGION \\"
    echo "     --ingress=internal-and-cloud-load-balancing"
    echo ""
    echo "   gcloud run services update frontend \\"
    echo "     --region=$REGION \\"
    echo "     --ingress=internal-and-cloud-load-balancing"
    echo ""
fi
