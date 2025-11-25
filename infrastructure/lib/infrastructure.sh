#!/bin/bash
#
# infrastructure.sh - Setup infrastructure (Artifact Registry, Service Accounts, IAM)
#

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

setup_infrastructure() {
    log_section "SECTION 2: Infrastructure Setup"
    
    # Create Artifact Registry
    setup_artifact_registry
    
    # Create and configure service accounts
    setup_service_accounts
    
    # Grant IAM permissions
    configure_iam_permissions
    
    return 0
}

setup_artifact_registry() {
    log_info "Setting up Artifact Registry..."
    if ! gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1; then
        gcloud artifacts repositories create "$REPO" \
            --repository-format=docker \
            --location="$REGION" \
            --description="ADK RAG Agent Docker images" \
            --quiet
        log_success "Artifact Registry created"
    else
        log_success "Artifact Registry already exists"
    fi
}

setup_service_accounts() {
    log_info "Creating service accounts..."
    
    # Define service accounts
    export BACKEND_SA="backend-sa@$PROJECT_ID.iam.gserviceaccount.com"
    export FRONTEND_SA="frontend-sa@$PROJECT_ID.iam.gserviceaccount.com"
    export RAG_AGENT_SA="adk-rag-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"
    export IAP_ACCESSOR_SA="iap-accessor@$PROJECT_ID.iam.gserviceaccount.com"
    # Per-agent RAG service accounts for multi-agent architecture
    export RAG_AGENT1_SA="adk-rag-agent1-sa@$PROJECT_ID.iam.gserviceaccount.com"
    export RAG_AGENT2_SA="adk-rag-agent2-sa@$PROJECT_ID.iam.gserviceaccount.com"
    export RAG_AGENT3_SA="adk-rag-agent3-sa@$PROJECT_ID.iam.gserviceaccount.com"
    
    # Backend service account
    if ! gcloud iam service-accounts describe "$BACKEND_SA" >/dev/null 2>&1; then
        gcloud iam service-accounts create backend-sa \
            --display-name="RAG Backend Service Account" \
            --description="Service account for backend Cloud Run service" \
            --quiet
        log_success "Backend service account created"
    else
        echo "  ✓ Backend service account exists"
    fi
    
    # Frontend service account
    if ! gcloud iam service-accounts describe "$FRONTEND_SA" >/dev/null 2>&1; then
        gcloud iam service-accounts create frontend-sa \
            --display-name="RAG Frontend Service Account" \
            --description="Service account for frontend Cloud Run service" \
            --quiet
        log_success "Frontend service account created"
    else
        echo "  ✓ Frontend service account exists"
    fi
    
    # RAG Agent service account (critical for RAG operations)
    if ! gcloud iam service-accounts describe "$RAG_AGENT_SA" >/dev/null 2>&1; then
        gcloud iam service-accounts create adk-rag-agent-sa \
            --display-name="ADK RAG Agent Service Account" \
            --description="Main service account with Vertex AI and RAG permissions" \
            --quiet
        log_success "RAG Agent service account created"
    else
        echo "  ✓ RAG Agent service account exists"
    fi

    # Per-agent RAG service accounts (agent1, agent2, agent3)
    if ! gcloud iam service-accounts describe "$RAG_AGENT1_SA" >/dev/null 2>&1; then
        gcloud iam service-accounts create adk-rag-agent1-sa \
            --display-name="ADK RAG Agent1 Service Account" \
            --description="Service account for RAG Agent1 backend" \
            --quiet
        log_success "RAG Agent1 service account created"
    else
        echo "  ✓ RAG Agent1 service account exists"
    fi

    if ! gcloud iam service-accounts describe "$RAG_AGENT2_SA" >/dev/null 2>&1; then
        gcloud iam service-accounts create adk-rag-agent2-sa \
            --display-name="ADK RAG Agent2 Service Account" \
            --description="Service account for RAG Agent2 backend" \
            --quiet
        log_success "RAG Agent2 service account created"
    else
        echo "  ✓ RAG Agent2 service account exists"
    fi

    if ! gcloud iam service-accounts describe "$RAG_AGENT3_SA" >/dev/null 2>&1; then
        gcloud iam service-accounts create adk-rag-agent3-sa \
            --display-name="ADK RAG Agent3 Service Account" \
            --description="Service account for RAG Agent3 backend" \
            --quiet
        log_success "RAG Agent3 service account created"
    else
        echo "  ✓ RAG Agent3 service account exists"
    fi
    
    # IAP Accessor service account
    if ! gcloud iam service-accounts describe "$IAP_ACCESSOR_SA" >/dev/null 2>&1; then
        gcloud iam service-accounts create iap-accessor \
            --display-name="IAP Accessor Service Account" \
            --description="Service account for IAP-enabled access" \
            --quiet
        log_success "IAP Accessor service account created"
    else
        echo "  ✓ IAP Accessor service account exists"
    fi
}

configure_iam_permissions() {
    log_info "Configuring IAM permissions..."
    
    # Vertex AI and data admin permissions for RAG Agent SA (bootstrap/admin)
    echo "  Granting admin-level Vertex AI and data permissions to RAG Agent SA..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${RAG_AGENT_SA}" \
        --role="roles/aiplatform.admin" \
        --condition=None \
        --quiet 2>/dev/null || true
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${RAG_AGENT_SA}" \
        --role="roles/storage.admin" \
        --condition=None \
        --quiet 2>/dev/null || true
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${RAG_AGENT_SA}" \
        --role="roles/bigquery.admin" \
        --condition=None \
        --quiet 2>/dev/null || true

    # Vertex AI permissions for per-agent RAG SAs (agent1, agent2, agent3)
    # Project-level: allow using Vertex AI, but not administering it.
    for sa in "$RAG_AGENT1_SA" "$RAG_AGENT2_SA" "$RAG_AGENT3_SA"; do
        echo "  Granting restricted Vertex AI permissions to $sa..."
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:${sa}" \
            --role="roles/aiplatform.user" \
            --condition=None \
            --quiet 2>/dev/null || true
    done

    # Bucket-level IAM for ai-books corpus (bucket: ipad-book-collection)
    # Shared across: default agent (RAG_AGENT_SA) and agents 1–3.
    for sa in "$RAG_AGENT_SA" "$RAG_AGENT1_SA" "$RAG_AGENT2_SA" "$RAG_AGENT3_SA"; do
        echo "  Granting storage.objectViewer on gs://ipad-book-collection to $sa..."
        gcloud storage buckets add-iam-policy-binding "gs://ipad-book-collection" \
            --member="serviceAccount:${sa}" \
            --role="roles/storage.objectViewer" \
            --quiet 2>/dev/null || true
    done

    # Bucket-level IAM for general-docs corpus (bucket: develom-documents)
    # Shared across: default agent (RAG_AGENT_SA) and agents 1–3.
    for sa in "$RAG_AGENT_SA" "$RAG_AGENT1_SA" "$RAG_AGENT2_SA" "$RAG_AGENT3_SA"; do
        echo "  Granting storage.objectViewer on gs://develom-documents to $sa..."
        gcloud storage buckets add-iam-policy-binding "gs://develom-documents" \
            --member="serviceAccount:${sa}" \
            --role="roles/storage.objectViewer" \
            --quiet 2>/dev/null || true
    done
    
    # Basic permissions for Backend SA
    echo "  Granting basic permissions to Backend SA..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${BACKEND_SA}" \
        --role="roles/aiplatform.user" \
        --condition=None \
        --quiet 2>/dev/null || true
    
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${BACKEND_SA}" \
        --role="roles/storage.objectViewer" \
        --condition=None \
        --quiet 2>/dev/null || true
    
    # IAP permissions for IAP Accessor SA
    echo "  Granting IAP permissions to IAP Accessor SA..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${IAP_ACCESSOR_SA}" \
        --role="roles/iap.httpsResourceAccessor" \
        --condition=None \
        --quiet 2>/dev/null || true
    
    log_success "IAM permissions configured"
}
