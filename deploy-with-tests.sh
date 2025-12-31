#!/bin/bash

# Enhanced Deployment Script with CI/CD Best Practices
# Based on recommendations from FINAL-SOLUTION.md

set -e  # Exit on any error

# Configuration
PROJECT_ID="adk-rag-ma"
REGION="us-west1"
BACKEND_IMAGE="us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/backend"
FRONTEND_IMAGE="us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/frontend"
LOAD_BALANCER_URL="https://34.49.46.115.nip.io"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Function to run tests
run_backend_tests() {
    log "Running backend tests..."
    cd backend
    
    if ! python -m pytest tests/ -v --cov=src --cov-report=term-missing; then
        error "Backend tests failed! Deployment aborted."
    fi
    
    success "Backend tests passed"
    cd ..
}

# Function to run security scan
run_security_scan() {
    log "Running security scan..."
    cd backend
    
    pip install bandit[toml] > /dev/null 2>&1
    if bandit -r src -f json -o bandit-report.json; then
        success "Security scan passed"
    else
        warning "Security scan found issues. Check bandit-report.json"
        cat bandit-report.json
    fi
    
    cd ..
}

# Function to build images
build_images() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local git_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local image_tag="${timestamp}-${git_sha}"
    
    log "Building backend image with tag: $image_tag"
    gcloud builds submit ./backend \
        --config=backend/cloudbuild.yaml \
        --substitutions=_BACKEND_IMAGE="${BACKEND_IMAGE}:${image_tag}" \
        --project=$PROJECT_ID
    
    log "Building frontend image with tag: $image_tag"
    gcloud builds submit ./frontend \
        --config=frontend/cloudbuild.yaml \
        --substitutions=_IMAGE_NAME="${FRONTEND_IMAGE}:${image_tag}",_BACKEND_URL="$LOAD_BALANCER_URL" \
        --project=$PROJECT_ID
    
    echo "$image_tag" > .last_deployment_tag
    success "Images built successfully with tag: $image_tag"
}

# Function to deploy services
deploy_services() {
    local image_tag=$(cat .last_deployment_tag)
    
    log "Deploying backend services with image tag: $image_tag"
    
    # Deploy all backend services to us-west1 only
    for service in backend backend-agent1 backend-agent2 backend-agent3; do
        log "Updating service: $service"
        gcloud run services update $service \
            --image="${BACKEND_IMAGE}:${image_tag}" \
            --region=$REGION \
            --project=$PROJECT_ID \
            --update-env-vars="GOOGLE_CLOUD_LOCATION=$REGION,VERTEXAI_LOCATION=$REGION" \
            --quiet
    done
    
    log "Deploying frontend service"
    gcloud run services update frontend \
        --image="${FRONTEND_IMAGE}:${image_tag}" \
        --region=$REGION \
        --project=$PROJECT_ID \
        --quiet
    
    success "All services deployed successfully"
}

# Function to run smoke tests
run_smoke_tests() {
    log "Waiting for services to be ready..."
    sleep 60
    
    log "Running smoke tests..."
    
    # Test main health endpoint
    if curl -f -s "$LOAD_BALANCER_URL/api/health" > /dev/null; then
        success "Main API health check passed"
    else
        error "Main API health check failed"
    fi
    
    # Test each agent endpoint
    for agent in agent1 agent2 agent3; do
        if curl -f -s "$LOAD_BALANCER_URL/$agent/api/health" > /dev/null; then
            success "Agent $agent health check passed"
        else
            error "Agent $agent health check failed"
        fi
    done
    
    success "All smoke tests passed"
}

# Function to verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check service status
    log "Checking service status..."
    gcloud run services list --project=$PROJECT_ID --region=$REGION --format='table(SERVICE,REGION,URL,LAST_MODIFIER_EMAIL,LAST_MODIFIED_DATE)'
    
    # Check for recent errors
    log "Checking for recent errors..."
    local error_count=$(gcloud logging read 'severity>=ERROR' \
        --project=$PROJECT_ID \
        --limit=10 \
        --freshness=10m \
        --format='value(timestamp)' | wc -l)
    
    if [ "$error_count" -gt 0 ]; then
        warning "Found $error_count recent errors. Check logs:"
        gcloud logging read 'severity>=ERROR' \
            --project=$PROJECT_ID \
            --limit=5 \
            --freshness=10m
    else
        success "No recent errors found"
    fi
    
    # Check Vertex AI connectivity
    log "Verifying Vertex AI connectivity..."
    local vertex_logs=$(gcloud logging read 'textPayload:"us-west1-aiplatform.googleapis.com"' \
        --project=$PROJECT_ID \
        --limit=5 \
        --freshness=10m \
        --format='value(timestamp)' | wc -l)
    
    if [ "$vertex_logs" -gt 0 ]; then
        success "Vertex AI connectivity verified (found $vertex_logs recent API calls)"
    else
        warning "No recent Vertex AI API calls found"
    fi
}

# Function to create deployment report
create_deployment_report() {
    local image_tag=$(cat .last_deployment_tag)
    local report_file="deployment-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Deployment Report

**Date:** $(date)
**Image Tag:** $image_tag
**Project:** $PROJECT_ID
**Region:** $REGION

## Services Deployed

- backend: ${BACKEND_IMAGE}:${image_tag}
- backend-agent1: ${BACKEND_IMAGE}:${image_tag}
- backend-agent2: ${BACKEND_IMAGE}:${image_tag}
- backend-agent3: ${BACKEND_IMAGE}:${image_tag}
- frontend: ${FRONTEND_IMAGE}:${image_tag}

## Test Results

- ✅ Backend tests: PASSED
- ✅ Security scan: COMPLETED
- ✅ Smoke tests: PASSED
- ✅ Deployment verification: COMPLETED

## URLs

- Application: $LOAD_BALANCER_URL
- Health Check: $LOAD_BALANCER_URL/api/health

## Next Steps

1. Monitor application logs for any issues
2. Run integration tests if needed
3. Update monitoring dashboards with new deployment info

EOF

    success "Deployment report created: $report_file"
}

# Main deployment flow
main() {
    log "Starting enhanced deployment process..."
    
    # Pre-deployment checks
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI not found. Please install Google Cloud SDK."
    fi
    
    if ! command -v python &> /dev/null; then
        error "Python not found. Please install Python 3.12+."
    fi
    
    # Authenticate and set project
    gcloud config set project $PROJECT_ID
    
    # Run pre-deployment tests
    run_backend_tests
    run_security_scan
    
    # Build and deploy
    build_images
    deploy_services
    
    # Post-deployment verification
    run_smoke_tests
    verify_deployment
    create_deployment_report
    
    success "Deployment completed successfully!"
    log "Application URL: $LOAD_BALANCER_URL"
}

# Rollback function
rollback() {
    log "Starting rollback process..."
    
    # Get previous image tag
    if [ ! -f .previous_deployment_tag ]; then
        error "No previous deployment tag found. Cannot rollback."
    fi
    
    local previous_tag=$(cat .previous_deployment_tag)
    log "Rolling back to previous deployment: $previous_tag"
    
    # Rollback all services
    for service in backend backend-agent1 backend-agent2 backend-agent3 frontend; do
        log "Rolling back service: $service"
        
        # Get the previous revision
        local previous_revision=$(gcloud run revisions list \
            --service=$service \
            --region=$REGION \
            --project=$PROJECT_ID \
            --format="value(metadata.name)" \
            --limit=2 | tail -n 1)
            
        if [ ! -z "$previous_revision" ]; then
            gcloud run services update-traffic $service \
                --to-revisions=$previous_revision=100 \
                --region=$REGION \
                --project=$PROJECT_ID \
                --quiet
            success "Rolled back $service to $previous_revision"
        else
            warning "No previous revision found for $service"
        fi
    done
    
    success "Rollback completed"
}

# Command line argument handling
case "${1:-deploy}" in
    "deploy")
        # Save current tag as previous before deploying
        if [ -f .last_deployment_tag ]; then
            cp .last_deployment_tag .previous_deployment_tag
        fi
        main
        ;;
    "rollback")
        rollback
        ;;
    "test-only")
        run_backend_tests
        run_security_scan
        ;;
    "smoke-test")
        run_smoke_tests
        ;;
    *)
        echo "Usage: $0 [deploy|rollback|test-only|smoke-test]"
        echo "  deploy     - Run full deployment with tests (default)"
        echo "  rollback   - Rollback to previous deployment"
        echo "  test-only  - Run tests and security scan only"
        echo "  smoke-test - Run smoke tests only"
        exit 1
        ;;
esac
