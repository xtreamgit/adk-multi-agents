#!/bin/bash
# Single-Region Deployment Script
# Deploys all backend services to us-west1 only

set -e

# Load configuration — deployment.config is the single source of truth for the
# target environment (PROJECT_ID, REGION, BACKEND_IMAGE, ...). Do NOT hardcode
# the project here; that previously pinned every deploy to develom (adk-rag-ma).
source ./deployment.config

# Fail loudly if the config didn't provide a target, instead of silently
# defaulting to the wrong project.
: "${PROJECT_ID:?PROJECT_ID not set — regenerate deployment.config from your environment YAML}"
: "${REGION:?REGION not set — regenerate deployment.config from your environment YAML}"
: "${BACKEND_IMAGE:?BACKEND_IMAGE not set — regenerate deployment.config from your environment YAML}"
SERVICES=("backend" "backend-agent1" "backend-agent2" "backend-agent3")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Single-Region Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Project:  $PROJECT_ID"
echo "Region:   $REGION"
echo "Services: ${SERVICES[*]}"
echo "Image:    $BACKEND_IMAGE"
echo ""

# Step 1: Build backend image
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Building backend image"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

gcloud builds submit ./backend \
  --config=backend/cloudbuild.yaml \
  --substitutions=_BACKEND_IMAGE="$BACKEND_IMAGE" \
  --project=$PROJECT_ID

echo ""
echo "✅ Build complete: $BACKEND_IMAGE"

# Step 2: Deploy to us-west1
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Deploying to $REGION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for service in "${SERVICES[@]}"; do
    echo "Deploying $service..."
    gcloud run services update $service \
        --image="$BACKEND_IMAGE" \
        --region=$REGION \
        --project=$PROJECT_ID \
        --update-env-vars="GOOGLE_CLOUD_LOCATION=us-west1,VERTEXAI_LOCATION=us-west1" \
        --quiet &
done

# Wait for all deployments to complete
wait

echo ""
echo "✅ All services deployed to $REGION"

# Step 3: Verify deployment
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Service Status:"
for service in "${SERVICES[@]}"; do
    REVISION=$(gcloud run services describe $service \
        --region=$REGION \
        --project=$PROJECT_ID \
        --format='value(status.latestReadyRevisionName)' 2>/dev/null)
    echo "  ✅ $service: $REVISION"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Application URL: https://34.49.46.115.nip.io"
echo ""
echo "📋 Next steps:"
echo "  1. Test the application in your browser"
echo "  2. Check logs: gcloud logging read 'resource.labels.service_name=\"backend\"' --limit=20"
echo "  3. Monitor health: gcloud run services describe backend --region=$REGION"
echo ""
