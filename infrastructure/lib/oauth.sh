#!/bin/bash
#
# oauth.sh - Configure OAuth consent screen and brand
#

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

configure_oauth() {
    log_section "SECTION 4: OAuth Configuration"
    
    # Get project number
    export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
    log_info "Project Number: $PROJECT_NUMBER"
    
    # Check for OAuth brand
    check_oauth_brand
    
    return 0
}

check_oauth_brand() {
    log_info "Checking OAuth consent screen configuration..."
    BRAND_LIST=$(gcloud iap oauth-brands list --format="value(name)" 2>/dev/null || echo "")
    
    if [[ -n "$BRAND_LIST" ]]; then
        export BRAND_ID=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f4)
        export BRAND_PATH="projects/$PROJECT_NUMBER/brands/$BRAND_ID"
        log_success "OAuth brand exists: $BRAND_ID"
    else
        prompt_oauth_setup
    fi
}

prompt_oauth_setup() {
    log_warning "OAuth consent screen not configured"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  MANUAL STEP REQUIRED: OAuth Consent Screen Setup${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}📋 Setup Instructions:${NC}"
    echo "1. Open: https://console.cloud.google.com/apis/credentials/consent?project=$PROJECT_ID"
    echo "2. Select 'Internal' for organization users (@$ORGANIZATION_DOMAIN)"
    echo "3. Fill in required fields:"
    echo "   • App name: ADK RAG Agent"
    echo "   • User support email: $IAP_ADMIN_USER"
    echo "   • Developer contact: $IAP_ADMIN_USER"
    echo "   • Authorized domains: $ORGANIZATION_DOMAIN"
    echo "4. Add scopes: openid, email, profile"
    echo "5. Click 'SAVE AND CONTINUE' through all steps"
    echo "6. IMPORTANT: PUBLISH the consent screen"
    echo ""
    read -p "$(echo -e ${YELLOW}Press Enter after completing OAuth consent screen setup...${NC})"
    
    # Check again
    BRAND_LIST=$(gcloud iap oauth-brands list --format="value(name)" 2>/dev/null || echo "")
    if [[ -n "$BRAND_LIST" ]]; then
        export BRAND_ID=$(echo "$BRAND_LIST" | head -1 | cut -d'/' -f4)
        export BRAND_PATH="projects/$PROJECT_NUMBER/brands/$BRAND_ID"
        log_success "OAuth brand found: $BRAND_ID"
    else
        log_error "OAuth brand still not found. Please complete setup."
        return 1
    fi
}
