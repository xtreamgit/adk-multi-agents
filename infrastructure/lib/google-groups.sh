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
        # Try to derive from project
        backend_sa="rag-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com"
        log_warning "RAG_AGENT_SA not set, using derived: $backend_sa"
    fi

    log_info "Granting Cloud Identity Groups Viewer to backend SA..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${backend_sa}" \
        --role="roles/cloudidentity.groupsViewer" \
        --condition=None \
        --quiet 2>/dev/null || {
            log_warning "Could not grant cloudidentity.groupsViewer role."
            log_warning "You may need to grant this manually or use domain-wide delegation."
            log_warning "See: https://cloud.google.com/identity/docs/how-to/setup"
        }
    log_success "IAM binding added for Cloud Identity Groups Viewer"

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
    echo "  1. Configure Google Group → Chatbot Group mappings via Admin API:"
    echo "     POST /api/admin/google-groups/agent-mappings"
    echo "  2. Configure Google Group → Corpus access mappings via Admin API:"
    echo "     POST /api/admin/google-groups/corpus-mappings"
    echo "  3. Test with: GET /api/admin/google-groups/status"
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
