#!/bin/bash
#
# google-groups.sh - Configure Google Groups Bridge for ADK RAG Agent
#
# DESCRIPTION:
# Enables the Cloud Identity API and configures the backend service account
# with the necessary permissions to query Google Group memberships.
#
# PREREQUISITES:
# - gcloud CLI authenticated
# - deployment.config sourced
# - Backend service account exists (RAG_AGENT_SA)
#

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

setup_google_groups_bridge() {
    log_section "Google Groups Bridge Configuration"

    # Step 1: Enable Cloud Identity API
    log_info "Enabling Cloud Identity API..."
    gcloud services enable cloudidentity.googleapis.com \
        --project="$PROJECT_ID" \
        --quiet 2>/dev/null || true
    log_success "Cloud Identity API enabled"

    # Step 2: Grant service account permission to read group memberships
    # The backend service account needs to be able to query group memberships
    local backend_sa="${RAG_AGENT_SA:-}"
    if [[ -z "$backend_sa" ]]; then
        # Query the actual service account from the Cloud Run backend service
        backend_sa=$(gcloud run services describe backend \
            --region="$REGION" --project="$PROJECT_ID" \
            --format="value(spec.template.spec.serviceAccountName)" 2>/dev/null)
        if [[ -z "$backend_sa" ]]; then
            backend_sa="adk-rag-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com"
            log_warning "Could not query backend SA, using default: $backend_sa"
        else
            log_info "Detected backend service account: $backend_sa"
        fi
    fi

    log_warning "Cloud Identity Groups API requires a manual step:"
    log_warning "  1. Go to https://admin.google.com → Account → Admin roles"
    log_warning "  2. Click 'Groups Admin' (or 'Groups Reader')"
    log_warning "  3. Click 'Assign service accounts'"
    log_warning "  4. Enter: $backend_sa"
    log_warning "  5. Click 'Assign role'"
    log_info "(gcloud IAM bindings do NOT work for Cloud Identity roles)"

    # Step 3: Update backend Cloud Run service with Google Groups env vars
    log_info "Updating backend Cloud Run service with Google Groups configuration..."
    
    # Get current env vars and append new ones
    gcloud run services update backend \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --update-env-vars="GOOGLE_GROUPS_ENABLED=true,GOOGLE_GROUPS_CACHE_TTL=300" \
        --quiet 2>/dev/null || {
            log_warning "Could not update backend env vars. You may need to redeploy."
        }

    # Also update agent-specific backend services if they exist
    for agent_service in backend-agent1 backend-agent2 backend-agent3; do
        if gcloud run services describe "$agent_service" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
            log_info "Updating $agent_service with Google Groups configuration..."
            gcloud run services update "$agent_service" \
                --region="$REGION" \
                --project="$PROJECT_ID" \
                --update-env-vars="GOOGLE_GROUPS_ENABLED=true,GOOGLE_GROUPS_CACHE_TTL=300" \
                --quiet 2>/dev/null || true
        fi
    done

    log_success "Google Groups Bridge configuration complete"

    echo ""
    echo -e "${BLUE}📋 Google Groups Bridge Summary:${NC}"
    echo "  Cloud Identity API: Enabled"
    echo "  Backend SA: $backend_sa"
    echo "  IAM Role: roles/cloudidentity.groupsViewer"
    echo "  Env Vars: GOOGLE_GROUPS_ENABLED=true, GOOGLE_GROUPS_CACHE_TTL=300"
    echo ""
    echo -e "${YELLOW}⚠️  Next Steps:${NC}"
    echo "  1. Configure mappings via Admin UI: https://<your-domain>/admin/google-groups"
    echo "  2. Or via API:"
    echo "     curl -s https://<your-domain>/api/admin/google-groups/agent-mappings"
    echo "     curl -s https://<your-domain>/api/admin/google-groups/corpus-mappings"
    echo "  3. Test status:"
    echo "     curl -s https://<your-domain>/api/admin/google-groups/status | python3 -m json.tool"
    echo ""

    return 0
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Source deployment config
    CONFIG_FILE="./deployment.config"
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo "Error: deployment.config not found"
        exit 1
    fi
    setup_google_groups_bridge
fi
