#!/bin/bash
#
# prerequisites.sh - Validate prerequisites and enable APIs
#

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

validate_prerequisites() {
    log_section "SECTION 1: Prerequisites & API Enablement"
    
    # Check gcloud authentication
    log_info "Checking gcloud authentication..."
    if ! gcloud auth list --filter=status=ACTIVE --format="value(account)" | grep -q "@"; then
        log_error "Not authenticated with gcloud"
        echo "Run: gcloud auth login"
        return 1
    fi
    log_success "gcloud authenticated"
    
    # Check application default credentials
    log_info "Checking application default credentials..."
    if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
        log_error "Application default credentials not set"
        echo "Run: gcloud auth application-default login"
        return 1
    fi
    log_success "Application default credentials configured"
    
    # Verify configuration variables
    log_info "Validating configuration..."
    if [[ -z "$PROJECT_ID" ]] || [[ -z "$REGION" ]] || [[ -z "$ORGANIZATION_DOMAIN" ]] || [[ -z "$IAP_ADMIN_USER" ]] || [[ -z "$REPO" ]]; then
        log_error "Missing required configuration variables"
        echo "Required: PROJECT_ID, REGION, ORGANIZATION_DOMAIN, IAP_ADMIN_USER, REPO"
        return 1
    fi
    log_success "Configuration validated"
    
    # Check for secrets file
    log_info "Checking secrets file..."
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_error "$SECRETS_FILE not found"
        echo "Create it with: echo 'SECRET_KEY=your-generated-key-here' > $SECRETS_FILE"
        echo "Generate a key with: python3 generate_secret_key.py"
        return 1
    fi
    
    # Load secrets
    source "$SECRETS_FILE"
    if [[ -z "${SECRET_KEY:-}" ]]; then
        log_error "SECRET_KEY missing in $SECRETS_FILE"
        return 1
    fi
    log_success "Secrets loaded"
    
    # Set project context
    log_info "Setting project context..."
    gcloud config set project "$PROJECT_ID" >/dev/null
    log_success "Project set to $PROJECT_ID"
    
    # Calculate image tags
    export GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "manual")
    export BACKEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/backend:$GIT_SHA"
    export FRONTEND_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/frontend:$GIT_SHA"
    export FRONTEND_IMAGE_LB="${FRONTEND_IMAGE}-lb"
    
    log_info "Image tags configured: $GIT_SHA"
    
    return 0
}

enable_apis() {
    if [[ "$SKIP_APIS" == "true" ]]; then
        log_warning "Skipping API enablement (--skip-apis flag)"
        return 0
    fi
    
    log_info "Enabling required Google Cloud APIs..."
    
    local REQUIRED_APIS=(
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
        storage.googleapis.com
        bigquery.googleapis.com
    )
    
    for API in "${REQUIRED_APIS[@]}"; do
        if ! gcloud services list --enabled --format="value(name)" | grep -q "^${API}$"; then
            echo "  Enabling $API..."
            gcloud services enable "$API" --quiet
        else
            echo "  ✓ $API already enabled"
        fi
    done
    
    log_success "All required APIs enabled"
    return 0
}
