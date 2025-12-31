#!/bin/bash

# Secrets Management Automation Script
# Automates secrets management via Google Secret Manager

set -e

PROJECT_ID="adk-rag-ma"
REGION="us-west1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Enable Secret Manager API
enable_secret_manager_api() {
    log "Enabling Secret Manager API..."
    gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID
    success "Secret Manager API enabled"
}

# Create secrets in Secret Manager
create_secrets() {
    log "Creating secrets in Secret Manager..."
    
    # List of secrets to create
    declare -A secrets=(
        ["jwt-secret-key"]="JWT signing key for authentication"
        ["database-url"]="Database connection URL"
        ["google-cloud-credentials"]="Service account credentials JSON"
        ["frontend-backend-url"]="Backend URL for frontend configuration"
        ["cors-allowed-origins"]="Allowed CORS origins"
        ["iap-audience"]="IAP audience for authentication"
    )
    
    for secret_name in "${!secrets[@]}"; do
        description="${secrets[$secret_name]}"
        
        # Check if secret already exists
        if gcloud secrets describe "$secret_name" --project=$PROJECT_ID >/dev/null 2>&1; then
            warning "Secret '$secret_name' already exists, skipping creation"
        else
            log "Creating secret: $secret_name"
            gcloud secrets create "$secret_name" \
                --description="$description" \
                --project=$PROJECT_ID
            success "Created secret: $secret_name"
        fi
    done
}

# Generate and store JWT secret key
setup_jwt_secret() {
    log "Setting up JWT secret key..."
    
    # Generate a secure random key
    JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    
    # Store in Secret Manager
    echo -n "$JWT_SECRET" | gcloud secrets versions add jwt-secret-key \
        --data-file=- \
        --project=$PROJECT_ID
    
    success "JWT secret key generated and stored"
}

# Setup service account permissions for secrets
setup_secret_permissions() {
    log "Setting up service account permissions for secrets..."
    
    # Service accounts that need access to secrets
    service_accounts=(
        "adk-rag-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com"
        "adk-rag-agent1-sa@${PROJECT_ID}.iam.gserviceaccount.com"
        "adk-rag-agent2-sa@${PROJECT_ID}.iam.gserviceaccount.com"
        "adk-rag-agent3-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    )
    
    # Grant Secret Manager accessor role to each service account
    for sa in "${service_accounts[@]}"; do
        log "Granting Secret Manager access to: $sa"
        
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$sa" \
            --role="roles/secretmanager.secretAccessor" \
            --quiet || warning "Failed to grant access to $sa (may not exist)"
    done
    
    success "Service account permissions configured"
}

# Create secret management utility script
create_secret_utility() {
    log "Creating secret management utility..."
    
    cat > manage-secrets.py << 'EOF'
#!/usr/bin/env python3
"""
Secret Management Utility for Multi-Agent RAG System
Provides easy interface to manage secrets in Google Secret Manager
"""

import argparse
import json
import os
import sys
from typing import Optional, Dict, Any

try:
    from google.cloud import secretmanager
except ImportError:
    print("Error: google-cloud-secret-manager not installed")
    print("Install with: pip install google-cloud-secret-manager")
    sys.exit(1)


class SecretManager:
    def __init__(self, project_id: str):
        self.project_id = project_id
        self.client = secretmanager.SecretManagerServiceClient()
        
    def create_secret(self, secret_id: str, description: str = "") -> bool:
        """Create a new secret."""
        try:
            parent = f"projects/{self.project_id}"
            secret = {"description": description}
            
            response = self.client.create_secret(
                request={
                    "parent": parent,
                    "secret_id": secret_id,
                    "secret": secret
                }
            )
            print(f"✅ Created secret: {response.name}")
            return True
        except Exception as e:
            print(f"❌ Failed to create secret {secret_id}: {e}")
            return False
    
    def add_secret_version(self, secret_id: str, payload: str) -> bool:
        """Add a new version to an existing secret."""
        try:
            parent = f"projects/{self.project_id}/secrets/{secret_id}"
            
            response = self.client.add_secret_version(
                request={
                    "parent": parent,
                    "payload": {"data": payload.encode("UTF-8")}
                }
            )
            print(f"✅ Added version to secret: {response.name}")
            return True
        except Exception as e:
            print(f"❌ Failed to add version to secret {secret_id}: {e}")
            return False
    
    def get_secret(self, secret_id: str, version: str = "latest") -> Optional[str]:
        """Retrieve a secret value."""
        try:
            name = f"projects/{self.project_id}/secrets/{secret_id}/versions/{version}"
            
            response = self.client.access_secret_version(request={"name": name})
            return response.payload.data.decode("UTF-8")
        except Exception as e:
            print(f"❌ Failed to get secret {secret_id}: {e}")
            return None
    
    def list_secrets(self) -> Dict[str, Any]:
        """List all secrets in the project."""
        try:
            parent = f"projects/{self.project_id}"
            secrets = {}
            
            for secret in self.client.list_secrets(request={"parent": parent}):
                secret_id = secret.name.split("/")[-1]
                secrets[secret_id] = {
                    "name": secret.name,
                    "description": getattr(secret, 'description', ''),
                    "created": secret.create_time.isoformat() if secret.create_time else None
                }
            
            return secrets
        except Exception as e:
            print(f"❌ Failed to list secrets: {e}")
            return {}
    
    def delete_secret(self, secret_id: str) -> bool:
        """Delete a secret."""
        try:
            name = f"projects/{self.project_id}/secrets/{secret_id}"
            self.client.delete_secret(request={"name": name})
            print(f"✅ Deleted secret: {secret_id}")
            return True
        except Exception as e:
            print(f"❌ Failed to delete secret {secret_id}: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(description="Manage secrets for Multi-Agent RAG system")
    parser.add_argument("--project-id", default="adk-rag-ma", help="Google Cloud project ID")
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Create secret command
    create_parser = subparsers.add_parser("create", help="Create a new secret")
    create_parser.add_argument("secret_id", help="Secret ID")
    create_parser.add_argument("--description", default="", help="Secret description")
    
    # Set secret command
    set_parser = subparsers.add_parser("set", help="Set secret value")
    set_parser.add_argument("secret_id", help="Secret ID")
    set_parser.add_argument("--value", help="Secret value (if not provided, will read from stdin)")
    set_parser.add_argument("--file", help="Read secret value from file")
    
    # Get secret command
    get_parser = subparsers.add_parser("get", help="Get secret value")
    get_parser.add_argument("secret_id", help="Secret ID")
    get_parser.add_argument("--version", default="latest", help="Secret version")
    
    # List secrets command
    list_parser = subparsers.add_parser("list", help="List all secrets")
    list_parser.add_argument("--json", action="store_true", help="Output in JSON format")
    
    # Delete secret command
    delete_parser = subparsers.add_parser("delete", help="Delete a secret")
    delete_parser.add_argument("secret_id", help="Secret ID")
    delete_parser.add_argument("--confirm", action="store_true", help="Skip confirmation")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Initialize Secret Manager
    sm = SecretManager(args.project_id)
    
    if args.command == "create":
        sm.create_secret(args.secret_id, args.description)
    
    elif args.command == "set":
        if args.file:
            with open(args.file, 'r') as f:
                value = f.read().strip()
        elif args.value:
            value = args.value
        else:
            value = input("Enter secret value: ").strip()
        
        sm.add_secret_version(args.secret_id, value)
    
    elif args.command == "get":
        value = sm.get_secret(args.secret_id, args.version)
        if value:
            print(value)
    
    elif args.command == "list":
        secrets = sm.list_secrets()
        if args.json:
            print(json.dumps(secrets, indent=2))
        else:
            print(f"Found {len(secrets)} secrets:")
            for secret_id, info in secrets.items():
                print(f"  {secret_id}: {info.get('description', 'No description')}")
    
    elif args.command == "delete":
        if not args.confirm:
            confirm = input(f"Are you sure you want to delete secret '{args.secret_id}'? (y/N): ")
            if confirm.lower() != 'y':
                print("Cancelled")
                return
        
        sm.delete_secret(args.secret_id)


if __name__ == "__main__":
    main()
EOF

    chmod +x manage-secrets.py
    success "Secret management utility created: manage-secrets.py"
}

# Create Cloud Run deployment configuration with secrets
create_deployment_with_secrets() {
    log "Creating deployment configuration with secrets..."
    
    cat > deploy-with-secrets.yaml << EOF
# Cloud Run deployment configuration with Secret Manager integration
# Use this template to deploy services with secrets from Secret Manager

apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: backend
  annotations:
    run.googleapis.com/ingress: all
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/maxScale: "10"
        run.googleapis.com/execution-environment: gen2
    spec:
      serviceAccountName: adk-rag-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com
      containers:
      - image: us-west1-docker.pkg.dev/${PROJECT_ID}/cloud-run-repo1/backend:latest
        ports:
        - containerPort: 8080
        env:
        - name: PROJECT_ID
          value: "${PROJECT_ID}"
        - name: GOOGLE_CLOUD_LOCATION
          value: "${REGION}"
        - name: VERTEXAI_LOCATION
          value: "${REGION}"
        - name: ACCOUNT_ENV
          value: "develom"
        - name: ROOT_PATH
          value: ""
        # Secrets from Secret Manager
        - name: JWT_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: jwt-secret-key
              key: latest
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-url
              key: latest
        resources:
          limits:
            cpu: 2000m
            memory: 4Gi
          requests:
            cpu: 1000m
            memory: 2Gi
EOF

    success "Deployment configuration with secrets created: deploy-with-secrets.yaml"
}

# Update existing deployment scripts to use secrets
update_deployment_scripts() {
    log "Updating deployment scripts to use secrets..."
    
    # Create a secrets-aware deployment function
    cat >> deploy-with-tests.sh << 'EOF'

# Function to deploy with secrets from Secret Manager
deploy_with_secrets() {
    local image_tag=$(cat .last_deployment_tag)
    
    log "Deploying services with secrets from Secret Manager..."
    
    # Deploy all backend services with secrets
    for service in backend backend-agent1 backend-agent2 backend-agent3; do
        local account_env="develom"
        local root_path=""
        
        case $service in
            "backend-agent1")
                account_env="agent1"
                root_path="/agent1"
                ;;
            "backend-agent2")
                account_env="agent2"
                root_path="/agent2"
                ;;
            "backend-agent3")
                account_env="agent3"
                root_path="/agent3"
                ;;
        esac
        
        log "Updating service: $service with secrets"
        gcloud run services update $service \
            --image="${BACKEND_IMAGE}:${image_tag}" \
            --region=$REGION \
            --project=$PROJECT_ID \
            --update-env-vars="GOOGLE_CLOUD_LOCATION=$REGION,VERTEXAI_LOCATION=$REGION,ACCOUNT_ENV=$account_env,ROOT_PATH=$root_path" \
            --update-secrets="JWT_SECRET_KEY=jwt-secret-key:latest,DATABASE_URL=database-url:latest" \
            --service-account="adk-rag-${account_env}-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
            --quiet
    done
    
    success "All services deployed with secrets"
}
EOF

    success "Deployment scripts updated with secrets support"
}

# Create secrets backup and restore functionality
create_backup_restore() {
    log "Creating secrets backup and restore functionality..."
    
    cat > backup-secrets.sh << 'EOF'
#!/bin/bash

# Backup secrets from Secret Manager
# Usage: ./backup-secrets.sh [backup-directory]

PROJECT_ID="adk-rag-ma"
BACKUP_DIR="${1:-secrets-backup-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$BACKUP_DIR"

echo "Backing up secrets to: $BACKUP_DIR"

# List all secrets and backup their latest versions
gcloud secrets list --project=$PROJECT_ID --format="value(name)" | while read secret_name; do
    secret_id=$(basename "$secret_name")
    echo "Backing up secret: $secret_id"
    
    # Get secret metadata
    gcloud secrets describe "$secret_id" --project=$PROJECT_ID --format=json > "$BACKUP_DIR/${secret_id}.metadata.json"
    
    # Get secret value (be careful with this in production!)
    gcloud secrets versions access latest --secret="$secret_id" --project=$PROJECT_ID > "$BACKUP_DIR/${secret_id}.value"
done

echo "✅ Backup completed: $BACKUP_DIR"
echo "⚠️  WARNING: Backup contains sensitive data. Store securely and delete when no longer needed."
EOF

    cat > restore-secrets.sh << 'EOF'
#!/bin/bash

# Restore secrets to Secret Manager
# Usage: ./restore-secrets.sh <backup-directory>

PROJECT_ID="adk-rag-ma"
BACKUP_DIR="$1"

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Usage: $0 <backup-directory>"
    exit 1
fi

echo "Restoring secrets from: $BACKUP_DIR"

for metadata_file in "$BACKUP_DIR"/*.metadata.json; do
    if [ ! -f "$metadata_file" ]; then
        continue
    fi
    
    secret_id=$(basename "$metadata_file" .metadata.json)
    value_file="$BACKUP_DIR/${secret_id}.value"
    
    if [ ! -f "$value_file" ]; then
        echo "⚠️  Skipping $secret_id: value file not found"
        continue
    fi
    
    echo "Restoring secret: $secret_id"
    
    # Extract description from metadata
    description=$(jq -r '.description // ""' "$metadata_file")
    
    # Create secret if it doesn't exist
    if ! gcloud secrets describe "$secret_id" --project=$PROJECT_ID >/dev/null 2>&1; then
        gcloud secrets create "$secret_id" --description="$description" --project=$PROJECT_ID
    fi
    
    # Add secret version
    gcloud secrets versions add "$secret_id" --data-file="$value_file" --project=$PROJECT_ID
done

echo "✅ Restore completed"
EOF

    chmod +x backup-secrets.sh restore-secrets.sh
    success "Backup and restore scripts created"
}

# Generate secrets management documentation
generate_documentation() {
    log "Generating secrets management documentation..."
    
    cat > SECRETS-MANAGEMENT.md << EOF
# Secrets Management Guide

This guide covers the automated secrets management system using Google Secret Manager for the Multi-Agent RAG system.

## Overview

The system uses Google Secret Manager to securely store and manage sensitive configuration data such as:
- JWT signing keys
- Database connection strings
- API keys and credentials
- Service account keys

## Setup

1. **Enable Secret Manager API and create secrets:**
   \`\`\`bash
   ./setup-secrets.sh
   \`\`\`

2. **Set secret values using the utility:**
   \`\`\`bash
   # Set JWT secret (auto-generated)
   python3 manage-secrets.py set jwt-secret-key --value "your-jwt-secret"
   
   # Set database URL
   python3 manage-secrets.py set database-url --value "postgresql://user:pass@host:5432/db"
   
   # Set from file
   python3 manage-secrets.py set google-cloud-credentials --file service-account.json
   \`\`\`

## Usage

### Managing Secrets

\`\`\`bash
# List all secrets
python3 manage-secrets.py list

# Get a secret value
python3 manage-secrets.py get jwt-secret-key

# Create a new secret
python3 manage-secrets.py create my-secret --description "My secret description"

# Delete a secret
python3 manage-secrets.py delete my-secret --confirm
\`\`\`

### Deployment with Secrets

The deployment scripts automatically configure Cloud Run services to use secrets:

\`\`\`bash
# Deploy with secrets integration
./deploy-with-tests.sh
\`\`\`

### Backup and Restore

\`\`\`bash
# Backup all secrets
./backup-secrets.sh

# Restore from backup
./restore-secrets.sh secrets-backup-20231218-143022
\`\`\`

## Security Best Practices

1. **Least Privilege Access**: Service accounts only have access to secrets they need
2. **Version Control**: Never commit secrets to version control
3. **Rotation**: Regularly rotate secrets, especially JWT keys
4. **Monitoring**: Monitor secret access via Cloud Audit Logs
5. **Backup**: Regular backups stored securely offline

## Service Account Permissions

Each agent service account has \`roles/secretmanager.secretAccessor\` permission to read secrets:
- \`adk-rag-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com\`
- \`adk-rag-agent1-sa@${PROJECT_ID}.iam.gserviceaccount.com\`
- \`adk-rag-agent2-sa@${PROJECT_ID}.iam.gserviceaccount.com\`
- \`adk-rag-agent3-sa@${PROJECT_ID}.iam.gserviceaccount.com\`

## Environment Variables vs Secrets

| Type | Use Case | Example |
|------|----------|---------|
| Environment Variables | Non-sensitive config | \`PROJECT_ID\`, \`REGION\` |
| Secrets | Sensitive data | \`JWT_SECRET_KEY\`, \`DATABASE_URL\` |

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure service account has \`secretmanager.secretAccessor\` role
2. **Secret Not Found**: Verify secret exists and version is correct
3. **Deployment Fails**: Check secret names match in deployment configuration

### Debugging Commands

\`\`\`bash
# Check secret exists
gcloud secrets describe jwt-secret-key --project=$PROJECT_ID

# List secret versions
gcloud secrets versions list jwt-secret-key --project=$PROJECT_ID

# Check service account permissions
gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:adk-rag-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com"
\`\`\`

## Integration with CI/CD

The CI/CD pipeline automatically uses secrets during deployment. To add new secrets:

1. Create the secret in Secret Manager
2. Update deployment configuration to reference the secret
3. Update service account permissions if needed

## Monitoring

Monitor secret access via Cloud Audit Logs:

\`\`\`bash
gcloud logging read 'protoPayload.serviceName="secretmanager.googleapis.com"' --project=$PROJECT_ID --limit=20
\`\`\`

EOF

    success "Secrets management documentation created: SECRETS-MANAGEMENT.md"
}

# Main execution
main() {
    log "Setting up secrets management automation..."
    
    # Set project
    gcloud config set project $PROJECT_ID
    
    # Setup Secret Manager
    enable_secret_manager_api
    create_secrets
    setup_jwt_secret
    setup_secret_permissions
    
    # Create utilities and documentation
    create_secret_utility
    create_deployment_with_secrets
    update_deployment_scripts
    create_backup_restore
    generate_documentation
    
    success "Secrets management setup completed successfully!"
    log "Next steps:"
    log "1. Set secret values: python3 manage-secrets.py set <secret-id> --value <value>"
    log "2. Deploy with secrets: ./deploy-with-tests.sh"
    log "3. Read documentation: SECRETS-MANAGEMENT.md"
}

# Command line options
case "${1:-setup}" in
    "setup")
        main
        ;;
    "test")
        log "Testing secrets access..."
        python3 manage-secrets.py list
        ;;
    *)
        echo "Usage: $0 [setup|test]"
        echo "  setup - Setup secrets management (default)"
        echo "  test  - Test secrets access"
        exit 1
        ;;
esac
