#!/bin/bash
#
# finalize.sh - CORS configuration, frontend rebuild, and deployment summary
#

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

finalize_deployment() {
    log_section "SECTION 7: Finalization & CORS Configuration"
    
    configure_cors
    rebuild_frontend_with_lb
    validate_deployment
    show_deployment_summary
    
    return 0
}

configure_cors() {
    log_info "Updating backend CORS configuration..."
    
    # Set FRONTEND_URL to Load Balancer domain for CORS
    gcloud run services update backend \
        --region="$REGION" \
        --update-env-vars="FRONTEND_URL=$LOAD_BALANCER_URL" \
        --quiet
    
    # Explain security configurations and auto-select posture based on org policy
    echo ""
    echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│ Cloud Run behind External HTTPS LB + IAP: Security Postures             │${NC}"
    echo -e "${YELLOW}│                                                                          │${NC}"
    echo -e "${YELLOW}│ A) Public invoker (allUsers) + ingress=internal-and-cloud-load-balancing │${NC}"
    echo -e "${YELLOW}│    - LB reaches Cloud Run without end-user identity                       │${NC}"
    echo -e "${YELLOW}│    - Safe when ingress is restricted to LB (recommended with serverless   │${NC}"
    echo -e "${YELLOW}│      NEG + IAP)                                                           │${NC}"
    echo -e "${YELLOW}│                                                                          │${NC}"
    echo -e "${YELLOW}│ B) Require authentication (IAP Service Agent only) + same ingress        │${NC}"
    echo -e "${YELLOW}│    - No public principal; LB invokes as IAP Service Agent                 │${NC}"
    echo -e "${YELLOW}│    - Often enforced by org policies restricting public members            │${NC}"
    echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────────────┘${NC}"

    # ASCII architecture diagram (two environments)
    echo -e "${YELLOW}┌──────────────────────────── Architecture Diagram (ASCII) ────────────────────────────┐${NC}"
    echo -e "${YELLOW}  ───────────────────────────────────                   ───────────────────────────────────${NC}"
    echo -e "${YELLOW}  End User (Browser)                                    End User (Browser)${NC}"
    echo -e "${YELLOW}          │ HTTPS                                               │ HTTPS${NC}"
    echo -e "${YELLOW}          ▼                                                     ▼${NC}"
    echo -e "${YELLOW}  External HTTPS LB + IAP                               External HTTPS LB + IAP${NC}"
    echo -e "${YELLOW}          │ (IAP authenticates user)                           │ (IAP authenticates user)${NC}"
    echo -e "${YELLOW}          ▼                                                     ▼${NC}"
    echo -e "${YELLOW}  LB invokes Cloud Run as                                    LB invokes Cloud Run as${NC}"
    echo -e "${YELLOW}  IAP Service Agent                                           IAP Service Agent${NC}"
    echo -e "${YELLOW}  service-<proj#>@gcp-sa-iap.iam.gserviceaccount.com          service-<proj#>@gcp-sa-iap.iam.gserviceaccount.com${NC}"
    echo -e "${YELLOW}          │ (Google internal HTTP)                             │ (Google internal HTTP)${NC}"
    echo -e "${YELLOW}          ▼                                                     ▼${NC}"
    echo -e "${YELLOW}  Cloud Run Service                                           Cloud Run Service${NC}"
    echo -e "${YELLOW}  Auth: Public access                                         Auth: Require authentication${NC}"
    echo -e "${YELLOW}  Ingress: internal-and-cloud-load-balancing                  Ingress: internal-and-cloud-load-balancing${NC}"
    echo -e "${YELLOW}  ${NC}"
    echo -e "${YELLOW}  Cloud Run IAM:                                              Cloud Run IAM:${NC}"
    echo -e "${YELLOW}  - allUsers: roles/run.invoker  [present]                    - allUsers: roles/run.invoker  [absent]${NC}"
    echo -e "${YELLOW}  - IAP SA: roles/run.invoker    [present]                    - IAP SA: roles/run.invoker    [present]${NC}"
    echo -e "${YELLOW}  ${NC}"
    echo -e "${YELLOW}  Effective Org Policy:                                       Effective Org Policy:${NC}"
    echo -e "${YELLOW}  iam.allowedPolicyMemberDomains:                             iam.allowedPolicyMemberDomains:${NC}"
    echo -e "${YELLOW}  - allowAll: true                                            - allowedValues: [C02qxenb7]${NC}"
    echo -e "${YELLOW}  (permits public principals)                                 (blocks public principals)${NC}"
    echo -e "${YELLOW}  ${NC}"
    echo -e "${YELLOW}  Why it works:                                               Why it works:${NC}"
    echo -e "${YELLOW}  - LB calls as IAP Service Agent                             - LB calls as IAP Service Agent${NC}"
    echo -e "${YELLOW}  - IAP SA has invoker → allowed                              - IAP SA has invoker → allowed${NC}"
    echo -e "${YELLOW}  - Ingress restricts to LB only                              - Ingress restricts to LB only${NC}"
    echo -e "${YELLOW}└────────────────────────────────────────────────────────────────────────────────────────┘${NC}"

    read -p "Press Enter to continue... "

    # Detect org policy to auto-select posture (keep this exact echo line)
    DETECTED_MODE="B"
    POL_OUT=$(gcloud org-policies describe constraints/iam.allowedPolicyMemberDomains --project="$PROJECT_ID" --effective --format=json 2>/dev/null || echo "")
    if echo "$POL_OUT" | grep -q '"allowAll"\s*:\s*true'; then
        DETECTED_MODE="A"
    fi
    echo "Detected org policy compatibility: $DETECTED_MODE"

    # Apply posture based on detection
    if [ "$DETECTED_MODE" = "A" ]; then
        echo -e "${YELLOW}▶ Configuration based on policy configuration: Public invoker (allUsers) + ingress restriction${NC}"
        echo -e "${YELLOW}  Applying allUsers:roles/run.invoker on backend for LB routing...${NC}"
        gcloud run services add-iam-policy-binding backend \
            --region="$REGION" \
            --member="allUsers" \
            --role="roles/run.invoker" \
            --quiet 2>/dev/null || ADD_ALLUSERS_RC=$?
        if [ "${ADD_ALLUSERS_RC:-0}" -ne 0 ]; then
            echo -e "${YELLOW}  allUsers binding blocked by org policy; continuing with Require-auth.${NC}"
        else
            echo -e "${YELLOW}  Success: backend now allows LB via public invoker; ingress still restricts to LB.${NC}"
        fi
    else
        echo -e "${YELLOW}▶ Selected: Require authentication (IAP Service Agent only)${NC}"
        echo -e "${YELLOW}  Skipping allUsers binding; LB will invoke as IAP Service Agent.${NC}"
    fi
    
    log_success "CORS configured"
}

rebuild_frontend_with_lb() {
    log_info "Rebuilding frontend with Load Balancer URL..."
    echo "Building with NEXT_PUBLIC_BACKEND_URL=$LOAD_BALANCER_URL"
    
    # Build frontend with Load Balancer URL
    gcloud builds submit ./frontend \
        --config=frontend/cloudbuild.yaml \
        --substitutions=_IMAGE_NAME="$FRONTEND_IMAGE_LB",_BACKEND_URL="$LOAD_BALANCER_URL" \
        --quiet
    
    # Redeploy frontend
    log_info "Redeploying frontend with Load Balancer URL..."
    gcloud run deploy frontend \
        --image="$FRONTEND_IMAGE_LB" \
        --region="$REGION" \
        --service-account="$FRONTEND_SA" \
        --ingress=internal-and-cloud-load-balancing \
        --allow-unauthenticated \
        --cpu=1 \
        --memory=512Mi \
        --concurrency=80 \
        --min-instances=0 \
        --max-instances=5 \
        --labels=app=adk-rag-agent,role=frontend,security=iap-protected \
        --quiet
    
    log_success "Frontend rebuilt and redeployed"
}

validate_deployment() {
    log_info "Validating deployment..."
    
    # Check SSL certificate status
    SSL_STATUS=$(gcloud compute ssl-certificates describe rag-agent-ssl-cert --global --format="value(managed.status)" 2>/dev/null || echo "UNKNOWN")
    echo "  SSL Certificate: $SSL_STATUS"
    
    # Check IAP status
    FRONTEND_IAP=$(gcloud compute backend-services describe frontend-backend-service --global --format="value(iap.enabled)" 2>/dev/null || echo "false")
    BACKEND_IAP=$(gcloud compute backend-services describe backend-backend-service --global --format="value(iap.enabled)" 2>/dev/null || echo "false")
    echo "  Frontend IAP: $FRONTEND_IAP"
    echo "  Backend IAP: $BACKEND_IAP"
    
    log_success "Validation complete"
}

show_deployment_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}📋 Deployment Details:${NC}"
    echo "  Project ID: $PROJECT_ID"
    echo "  Region: $REGION"
    echo "  Static IP: ${STATIC_IP:-N/A}"
    echo "  Load Balancer URL: ${LOAD_BALANCER_URL:-N/A}"
    echo "  OAuth Client ID: ${CLIENT_ID:-N/A}"
    echo "  IAP Service Account: ${IAP_SA:-N/A}"
    echo ""
    echo -e "${BLUE}🏗️  Architecture:${NC}"
    echo "  Internet → HTTPS Load Balancer (SSL + IAP) → Cloud Run Services"
    echo "  ├── \"/\" → Frontend service"
    echo "  └── \"/api/*\" → Backend service"
    echo ""
    echo -e "${BLUE}🔐 Security Features:${NC}"
    echo "  ✅ External HTTPS Load Balancer with SSL"
    echo "  ✅ Identity-Aware Proxy (IAP) with Google OAuth"
    echo "  ✅ OAuth consent screen flow"
    echo "  ✅ Domain-restricted access (@$ORGANIZATION_DOMAIN)"
    echo "  ✅ CORS configured"
    echo "  ✅ Two-layer authentication (IAP + Application JWT)"
    echo ""
    echo -e "${BLUE}🌐 Access Instructions:${NC}"
    echo "1. Wait 2-3 minutes for configuration propagation"
    echo "2. Clear browser cache"
    echo "3. Open: ${LOAD_BALANCER_URL:-N/A}"
    echo "4. Expected flow:"
    echo "   → Google OAuth login"
    echo "   → Sign in with @$ORGANIZATION_DOMAIN account"
    echo "   → OAuth consent (if first time)"
    echo "   → RAG application"
    echo ""
    
    if [[ "${SSL_STATUS:-}" != "ACTIVE" ]]; then
        echo -e "${YELLOW}⚠️  SSL Certificate Status: ${SSL_STATUS}${NC}"
        echo "Wait 10-15 minutes for certificate to become ACTIVE"
        echo "Check: gcloud compute ssl-certificates describe rag-agent-ssl-cert --global"
        echo ""
    fi
    
    echo -e "${BLUE}🔧 Useful Commands:${NC}"
    echo "# Check SSL status"
    echo "gcloud compute ssl-certificates describe rag-agent-ssl-cert --global"
    echo ""
    echo "# Check IAP status"
    echo "gcloud compute backend-services describe frontend-backend-service --global"
    echo ""
    echo "# View logs"
    echo "gcloud logs read --service=backend --region=$REGION --limit=50"
    echo ""
    echo "# Run validation"
    echo "./infrastructure/validate-security.sh"
    echo ""
    echo -e "${GREEN}✨ Your ADK RAG Agent is now deployed and secured!${NC}"
    echo ""
}
