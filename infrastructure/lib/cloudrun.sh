#!/bin/bash
#
# cloudrun.sh - Deploy Cloud Run services (frontend and backend)
#

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

deploy_cloud_run() {
    if [[ "$SKIP_CLOUD_RUN" == "true" ]]; then
        log_section "SECTION 3: Cloud Run Deployment"
        log_warning "Skipping Cloud Run deployment (--skip-cloud-run flag)"

        # Get existing service URLs
        BACKEND_URL=$(gcloud run services describe backend --region="$REGION" --format='value(status.url)' 2>/dev/null || echo "")
        FRONTEND_URL=$(gcloud run services describe frontend --region="$REGION" --format='value(status.url)' 2>/dev/null || echo "")

        if [[ -z "$BACKEND_URL" ]] || [[ -z "$FRONTEND_URL" ]]; then
            log_error "Cloud Run services not found. Cannot skip deployment."
            return 1
        fi

        log_info "Using existing Cloud Run services:"
        echo "  Backend: $BACKEND_URL"
        echo "  Frontend: $FRONTEND_URL"

        export BACKEND_URL
        export FRONTEND_URL
        return 0
    fi

    log_section "SECTION 3: Cloud Run Deployment"

    # Deploy primary backend service (current behavior)
    deploy_backend

    # Deploy secondary backend service for agent1 (multi-agent architecture)
    # Uses dedicated service account and ACCOUNT_ENV=agent1
    if [[ -n "$RAG_AGENT1_SA" ]]; then
        deploy_backend_service "backend-agent1" "$BACKEND_IMAGE" "$RAG_AGENT1_SA" "agent1"
    else
        log_warning "RAG_AGENT1_SA is not set; skipping backend-agent1 deployment"
    fi

    # Deploy additional backend services for agent2 and agent3
    # Each uses its own service account and ACCOUNT_ENV value
    if [[ -n "$RAG_AGENT2_SA" ]]; then
        deploy_backend_service "backend-agent2" "$BACKEND_IMAGE" "$RAG_AGENT2_SA" "agent2"
    else
        log_warning "RAG_AGENT2_SA is not set; skipping backend-agent2 deployment"
    fi

    if [[ -n "$RAG_AGENT3_SA" ]]; then
        deploy_backend_service "backend-agent3" "$BACKEND_IMAGE" "$RAG_AGENT3_SA" "agent3"
    else
        log_warning "RAG_AGENT3_SA is not set; skipping backend-agent3 deployment"
    fi

    # Deploy frontend
    deploy_frontend

    return 0
}

deploy_backend_service() {
    local service_name="$1"      # e.g., backend, backend-agent1
    local image="$2"             # e.g., $BACKEND_IMAGE
    local service_account="$3"   # e.g., $RAG_AGENT_SA or $RAG_AGENT1_SA
    local account_env="$4"       # e.g., develom, agent1, agent2

    if [[ -z "$service_name" || -z "$image" || -z "$service_account" || -z "$account_env" ]]; then
        log_error "deploy_backend_service requires service_name, image, service_account, and account_env"
        return 1
    fi

    log_info "Deploying backend service '$service_name' with ACCOUNT_ENV='$account_env'..."

    # Derive ROOT_PATH for FastAPI based on service name (for multi-agent routing)
    local root_path=""
    case "$service_name" in
        backend-agent1)
            root_path="/agent1"
            ;;
        backend-agent2)
            root_path="/agent2"
            ;;
        backend-agent3)
            root_path="/agent3"
            ;;
        *)
            root_path=""
            ;;
    esac

    gcloud run deploy "$service_name" \
        --image="$image" \
        --region="$REGION" \
        --service-account="$service_account" \
        --ingress=internal-and-cloud-load-balancing \
        --allow-unauthenticated \
        --cpu=1 \
        --memory=1Gi \
        --concurrency=80 \
        --min-instances=0 \
        --max-instances=10 \
        --set-env-vars="PROJECT_ID=$PROJECT_ID,GOOGLE_CLOUD_LOCATION=$REGION,VERTEXAI_PROJECT=$PROJECT_ID,VERTEXAI_LOCATION=$REGION,SECRET_KEY=$SECRET_KEY,DATABASE_PATH=/app/data/users.db,LOG_LEVEL=INFO,ENVIRONMENT=production,ACCOUNT_ENV=${account_env},ROOT_PATH=${root_path}" \
        --labels=app=adk-rag-agent,role=backend,security=iap-protected,agent=${account_env} \
        --quiet

    # Only export BACKEND_URL for the primary backend service
    if [[ "$service_name" == "backend" ]]; then
        export BACKEND_URL=$(gcloud run services describe backend --region="$REGION" --format='value(status.url)')
        log_success "Backend deployed: $BACKEND_URL"
    else
        local url
        url=$(gcloud run services describe "$service_name" --region="$REGION" --format='value(status.url)')
        log_success "Backend service '$service_name' deployed: $url"
    fi
}

deploy_backend() {
    log_info "Building backend container image..."
    gcloud builds submit ./backend \
        --config=backend/cloudbuild.yaml \
        --substitutions=_BACKEND_IMAGE="$BACKEND_IMAGE" \
        --quiet

    log_success "Backend image built: $BACKEND_IMAGE"

    # Deploy the primary backend service using the generic helper
    # Uses RAG_AGENT_SA and the current ACCOUNT_ENV (typically 'develom')
    deploy_backend_service "backend" "$BACKEND_IMAGE" "$RAG_AGENT_SA" "${ACCOUNT_ENV}"
}

deploy_frontend() {
    log_info "Building frontend container image (initial)..."
    gcloud builds submit ./frontend \
        --config=frontend/cloudbuild.yaml \
        --substitutions=_IMAGE_NAME="$FRONTEND_IMAGE",_BACKEND_URL="$BACKEND_URL" \
        --quiet
    
    log_success "Frontend image built: $FRONTEND_IMAGE"
    
    log_info "Deploying frontend to Cloud Run..."
    gcloud run deploy frontend \
        --image="$FRONTEND_IMAGE" \
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
    
    export FRONTEND_URL=$(gcloud run services describe frontend --region="$REGION" --format='value(status.url)')
    log_success "Frontend deployed: $FRONTEND_URL"
}
