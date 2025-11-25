#!/bin/bash

# Script to remove excessive IAM permissions from backend service account
# Run this script to remove aiplatform.admin and storage.admin roles

set -e

# Set environment variables (update PROJECT_ID if different)
export PROJECT_ID="adk-rag-agent-2025"
export BACKEND_SA="backend-sa@$PROJECT_ID.iam.gserviceaccount.com"

echo "🔐 Removing excessive IAM permissions from backend service account..."

# Remove aiplatform.admin role
echo "Removing roles/aiplatform.admin..."
gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$BACKEND_SA" \
  --role="roles/aiplatform.admin"

# Remove storage.admin role  
echo "Removing roles/storage.admin..."
gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$BACKEND_SA" \
  --role="roles/storage.admin"

echo "✅ Excessive permissions removed successfully!"
echo ""
echo "Current minimal permissions for $BACKEND_SA:"
echo "- roles/aiplatform.user (for Vertex AI access)"
echo "- roles/storage.objectViewer (for reading corpus data)"
echo ""
echo "To verify current permissions, run:"
echo "gcloud projects get-iam-policy $PROJECT_ID --flatten=\"bindings[].members\" --format=\"table(bindings.role)\" --filter=\"bindings.members:$BACKEND_SA\""
