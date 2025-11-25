#!/bin/bash
#
# iap.sh - Configure Identity-Aware Proxy (IAP) and OAuth client
#

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

configure_iap() {
    if [[ "$SKIP_IAP" == "true" ]]; then
        log_section "SECTION 6: IAP Configuration"
        log_warning "Skipping IAP configuration (--skip-iap flag)"
        return 0
    fi
    
    log_section "SECTION 6: IAP Configuration"
    
    create_oauth_client
    create_iap_service_account
    enable_iap_on_backends
    configure_iap_access
    
    return 0
}

create_oauth_client() {
    if [[ "$SKIP_OAUTH" == "true" ]]; then
        log_warning "Skipping OAuth client creation (--skip-oauth flag)"
        return 0
    fi
    
    log_info "Creating OAuth client with Load Balancer redirect URIs..."
    
    # Define redirect URIs
    IAP_REDIRECT_URI="$LOAD_BALANCER_URL/_gcp_gatekeeper/authenticate"
    
    echo "Load Balancer URL: $LOAD_BALANCER_URL"
    echo "Required redirect URIs:"
    echo "  - $LOAD_BALANCER_URL"
    echo "  - $IAP_REDIRECT_URI"
    echo ""
    
    # Clean up existing OAuth clients
    log_info "Checking for existing OAuth clients..."
    EXISTING_CLIENTS=$(gcloud iap oauth-clients list "$BRAND_PATH" --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -n "$EXISTING_CLIENTS" ]]; then
        log_warning "Found existing OAuth clients. Cleaning up..."
        while IFS= read -r client_name; do
            if [[ -n "$client_name" ]]; then
                echo "  Deleting: $client_name"
                gcloud iap oauth-clients delete "$client_name" --quiet 2>/dev/null || true
            fi
        done <<< "$EXISTING_CLIENTS"
    fi
    
    # Create new OAuth client
    log_info "Creating new OAuth client..."
    OAUTH_CLIENT_OUTPUT=$(gcloud iap oauth-clients create "$BRAND_PATH" \
        --display_name="Load Balancer IAP Client" 2>/dev/null || echo "")
    
    if [[ -n "$OAUTH_CLIENT_OUTPUT" ]]; then
        export CLIENT_ID=$(echo "$OAUTH_CLIENT_OUTPUT" | grep -o '[0-9]\+-[a-zA-Z0-9]\+\.apps\.googleusercontent\.com')
        export CLIENT_SECRET=$(echo "$OAUTH_CLIENT_OUTPUT" | grep -o 'GOCSPX-[a-zA-Z0-9_-]\+')
        
        log_success "OAuth client created"
        echo "  Client ID: $CLIENT_ID"
        
        # Manual step for redirect URIs
        echo ""
        echo -e "${RED}🚨 MANUAL STEP REQUIRED:${NC}"
        echo -e "${YELLOW}Add redirect URIs in Google Cloud Console:${NC}"
        echo ""
        echo "1. Go to: https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
        echo "2. Click on: Load Balancer IAP Client ($CLIENT_ID)"
        echo "3. Add these redirect URIs:"
        echo -e "${CYAN}   ➤ $LOAD_BALANCER_URL${NC}"
        echo -e "${CYAN}   ➤ $IAP_REDIRECT_URI${NC}"
        echo "4. Click SAVE"
        echo ""
        read -p "$(echo -e ${YELLOW}Press Enter after adding redirect URIs...${NC})"
    else
        log_error "Failed to create OAuth client"
        return 1
    fi
}

create_iap_service_account() {
    log_info "Creating IAP service account..."
    gcloud beta services identity create --service=iap.googleapis.com --quiet 2>/dev/null || true
    
    export IAP_SA="service-$PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com"
    log_info "IAP Service Account: $IAP_SA"
    
    # Grant Cloud Run Invoker permissions
    log_info "Granting IAP service account permissions..."
    
    # Frontend service
    gcloud run services add-iam-policy-binding frontend \
        --region="$REGION" \
        --member="serviceAccount:$IAP_SA" \
        --role="roles/run.invoker" \
        --quiet 2>/dev/null || true
    
    # Primary backend service
    gcloud run services add-iam-policy-binding backend \
        --region="$REGION" \
        --member="serviceAccount:$IAP_SA" \
        --role="roles/run.invoker" \
        --quiet 2>/dev/null || true

    # Additional backend agent services (agent1, agent2, agent3)
    for svc in backend-agent1 backend-agent2 backend-agent3; do
        gcloud run services add-iam-policy-binding "$svc" \
            --region="$REGION" \
            --member="serviceAccount:$IAP_SA" \
            --role="roles/run.invoker" \
            --quiet 2>/dev/null || true
    done
    
    log_success "IAP service account configured"
}

enable_iap_on_backends() {
    log_info "Enabling IAP on backend services..."
    echo "Using OAuth Client ID: $CLIENT_ID"
    
    # Enable IAP on frontend backend service
    echo "  Enabling IAP on frontend backend service..."
    gcloud compute backend-services update frontend-backend-service \
        --global \
        --iap=enabled,oauth2-client-id="$CLIENT_ID",oauth2-client-secret="$CLIENT_SECRET" \
        --quiet
    
    # Enable IAP on backend backend service
    echo "  Enabling IAP on backend backend service..."
    gcloud compute backend-services update backend-backend-service \
        --global \
        --iap=enabled,oauth2-client-id="$CLIENT_ID",oauth2-client-secret="$CLIENT_SECRET" \
        --quiet

    # Enable IAP on additional backend agent services (agent1, agent2, agent3)
    for svc in backend-agent1-backend-service backend-agent2-backend-service backend-agent3-backend-service; do
        echo "  Enabling IAP on $svc..."
        gcloud compute backend-services update "$svc" \
            --global \
            --iap=enabled,oauth2-client-id="$CLIENT_ID",oauth2-client-secret="$CLIENT_SECRET" \
            --quiet 2>/dev/null || echo "  ⚠️ Skipped enabling IAP on $svc (may not exist yet)"
    done
    
    log_success "IAP enabled on backend services"
}

configure_iap_access() {
    log_info "Configuring IAP access permissions..."
    
    # Grant IAP access to admin user
    echo "  Granting access to $IAP_ADMIN_USER..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="user:$IAP_ADMIN_USER" \
        --role="roles/iap.httpsResourceAccessor" \
        --quiet 2>/dev/null || true
    
    # Grant IAP access to organization domain
    echo "  Granting access to $ORGANIZATION_DOMAIN domain..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="domain:$ORGANIZATION_DOMAIN" \
        --role="roles/iap.httpsResourceAccessor" \
        --quiet 2>/dev/null || true
    
    log_success "IAP access permissions configured"
}
