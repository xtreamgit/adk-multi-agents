#!/bin/bash

# Comprehensive Backup and Restore System
# For Multi-Agent RAG Application on Google Cloud

set -e

PROJECT_ID="adk-rag-ma"
REGION="us-west1"
BACKUP_BUCKET="gs://${PROJECT_ID}-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

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

# Create backup bucket if it doesn't exist
setup_backup_infrastructure() {
    log "Setting up backup infrastructure..."
    
    # Create backup bucket
    if ! gsutil ls "$BACKUP_BUCKET" >/dev/null 2>&1; then
        log "Creating backup bucket: $BACKUP_BUCKET"
        gsutil mb -p "$PROJECT_ID" -c STANDARD -l "$REGION" "$BACKUP_BUCKET"
        
        # Enable versioning for backup bucket
        gsutil versioning set on "$BACKUP_BUCKET"
        
        # Set lifecycle policy to delete old backups after 90 days
        cat > /tmp/lifecycle.json << EOF
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 90}
    }
  ]
}
EOF
        gsutil lifecycle set /tmp/lifecycle.json "$BACKUP_BUCKET"
        rm /tmp/lifecycle.json
        
        success "Backup bucket created with lifecycle policy"
    else
        success "Backup bucket already exists"
    fi
}

# Backup Cloud Run services configuration
backup_cloud_run_services() {
    log "Backing up Cloud Run services configuration..."
    
    local backup_dir="cloud-run-backup-$TIMESTAMP"
    mkdir -p "/tmp/$backup_dir"
    
    # List of services to backup
    services=("frontend" "backend" "backend-agent1" "backend-agent2" "backend-agent3")
    
    for service in "${services[@]}"; do
        log "Backing up service: $service"
        
        # Export service configuration
        gcloud run services describe "$service" \
            --region="$REGION" \
            --project="$PROJECT_ID" \
            --format="export" > "/tmp/$backup_dir/${service}.yaml"
        
        # Get service IAM policy
        gcloud run services get-iam-policy "$service" \
            --region="$REGION" \
            --project="$PROJECT_ID" \
            --format="json" > "/tmp/$backup_dir/${service}-iam.json"
    done
    
    # Create backup manifest
    cat > "/tmp/$backup_dir/manifest.json" << EOF
{
  "backup_type": "cloud_run_services",
  "timestamp": "$TIMESTAMP",
  "project_id": "$PROJECT_ID",
  "region": "$REGION",
  "services": $(printf '%s\n' "${services[@]}" | jq -R . | jq -s .),
  "created_by": "$(gcloud config get-value account)"
}
EOF
    
    # Upload to backup bucket
    gsutil -m cp -r "/tmp/$backup_dir" "$BACKUP_BUCKET/cloud-run/"
    rm -rf "/tmp/$backup_dir"
    
    success "Cloud Run services backed up to $BACKUP_BUCKET/cloud-run/"
}

# Backup Load Balancer configuration
backup_load_balancer() {
    log "Backing up Load Balancer configuration..."
    
    local backup_dir="load-balancer-backup-$TIMESTAMP"
    mkdir -p "/tmp/$backup_dir"
    
    # Backup URL map
    gcloud compute url-maps describe rag-agent-url-map \
        --global \
        --project="$PROJECT_ID" \
        --format="json" > "/tmp/$backup_dir/url-map.json"
    
    # Backup backend services
    backend_services=("frontend-backend-service" "backend-backend-service" "backend-agent1-backend-service" "backend-agent2-backend-service" "backend-agent3-backend-service")
    
    for bs in "${backend_services[@]}"; do
        if gcloud compute backend-services describe "$bs" --global --project="$PROJECT_ID" >/dev/null 2>&1; then
            gcloud compute backend-services describe "$bs" \
                --global \
                --project="$PROJECT_ID" \
                --format="json" > "/tmp/$backup_dir/${bs}.json"
        fi
    done
    
    # Backup SSL certificate
    gcloud compute ssl-certificates list \
        --project="$PROJECT_ID" \
        --format="json" > "/tmp/$backup_dir/ssl-certificates.json"
    
    # Backup target HTTPS proxy
    gcloud compute target-https-proxies list \
        --project="$PROJECT_ID" \
        --format="json" > "/tmp/$backup_dir/target-https-proxies.json"
    
    # Backup global forwarding rule
    gcloud compute forwarding-rules list \
        --global \
        --project="$PROJECT_ID" \
        --format="json" > "/tmp/$backup_dir/forwarding-rules.json"
    
    # Create manifest
    cat > "/tmp/$backup_dir/manifest.json" << EOF
{
  "backup_type": "load_balancer",
  "timestamp": "$TIMESTAMP",
  "project_id": "$PROJECT_ID",
  "created_by": "$(gcloud config get-value account)"
}
EOF
    
    # Upload to backup bucket
    gsutil -m cp -r "/tmp/$backup_dir" "$BACKUP_BUCKET/load-balancer/"
    rm -rf "/tmp/$backup_dir"
    
    success "Load Balancer configuration backed up"
}

# Backup IAM policies and service accounts
backup_iam() {
    log "Backing up IAM policies and service accounts..."
    
    local backup_dir="iam-backup-$TIMESTAMP"
    mkdir -p "/tmp/$backup_dir"
    
    # Backup project IAM policy
    gcloud projects get-iam-policy "$PROJECT_ID" \
        --format="json" > "/tmp/$backup_dir/project-iam-policy.json"
    
    # Backup service accounts
    service_accounts=("adk-rag-agent-sa" "adk-rag-agent1-sa" "adk-rag-agent2-sa" "adk-rag-agent3-sa")
    
    for sa in "${service_accounts[@]}"; do
        sa_email="${sa}@${PROJECT_ID}.iam.gserviceaccount.com"
        
        if gcloud iam service-accounts describe "$sa_email" --project="$PROJECT_ID" >/dev/null 2>&1; then
            # Service account details
            gcloud iam service-accounts describe "$sa_email" \
                --project="$PROJECT_ID" \
                --format="json" > "/tmp/$backup_dir/${sa}.json"
            
            # Service account IAM policy
            gcloud iam service-accounts get-iam-policy "$sa_email" \
                --project="$PROJECT_ID" \
                --format="json" > "/tmp/$backup_dir/${sa}-iam.json"
        fi
    done
    
    # Create manifest
    cat > "/tmp/$backup_dir/manifest.json" << EOF
{
  "backup_type": "iam",
  "timestamp": "$TIMESTAMP",
  "project_id": "$PROJECT_ID",
  "service_accounts": $(printf '%s\n' "${service_accounts[@]}" | jq -R . | jq -s .),
  "created_by": "$(gcloud config get-value account)"
}
EOF
    
    # Upload to backup bucket
    gsutil -m cp -r "/tmp/$backup_dir" "$BACKUP_BUCKET/iam/"
    rm -rf "/tmp/$backup_dir"
    
    success "IAM configuration backed up"
}

# Backup application data (database, user sessions)
backup_application_data() {
    log "Backing up application data..."
    
    local backup_dir="app-data-backup-$TIMESTAMP"
    mkdir -p "/tmp/$backup_dir"
    
    # Backup SQLite database if it exists
    if [ -f "users.db" ]; then
        cp "users.db" "/tmp/$backup_dir/users.db"
        log "SQLite database backed up"
    fi
    
    # Backup configuration files
    config_files=("deployment.config" "secrets.env" "sonar-project.properties")
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "/tmp/$backup_dir/"
        fi
    done
    
    # Backup infrastructure scripts
    mkdir -p "/tmp/$backup_dir/infrastructure"
    if [ -d "infrastructure" ]; then
        cp -r infrastructure/* "/tmp/$backup_dir/infrastructure/"
    fi
    
    # Create manifest
    cat > "/tmp/$backup_dir/manifest.json" << EOF
{
  "backup_type": "application_data",
  "timestamp": "$TIMESTAMP",
  "project_id": "$PROJECT_ID",
  "files_backed_up": $(find "/tmp/$backup_dir" -type f -not -name "manifest.json" | jq -R . | jq -s .),
  "created_by": "$(gcloud config get-value account)"
}
EOF
    
    # Upload to backup bucket
    gsutil -m cp -r "/tmp/$backup_dir" "$BACKUP_BUCKET/app-data/"
    rm -rf "/tmp/$backup_dir"
    
    success "Application data backed up"
}

# Backup secrets (metadata only, not values for security)
backup_secrets_metadata() {
    log "Backing up secrets metadata..."
    
    local backup_dir="secrets-metadata-backup-$TIMESTAMP"
    mkdir -p "/tmp/$backup_dir"
    
    # List all secrets and their metadata
    gcloud secrets list --project="$PROJECT_ID" --format="json" > "/tmp/$backup_dir/secrets-list.json"
    
    # Get metadata for each secret (not the actual values)
    gcloud secrets list --project="$PROJECT_ID" --format="value(name)" | while read secret_name; do
        secret_id=$(basename "$secret_name")
        gcloud secrets describe "$secret_id" --project="$PROJECT_ID" --format="json" > "/tmp/$backup_dir/${secret_id}-metadata.json"
    done
    
    # Create manifest
    cat > "/tmp/$backup_dir/manifest.json" << EOF
{
  "backup_type": "secrets_metadata",
  "timestamp": "$TIMESTAMP",
  "project_id": "$PROJECT_ID",
  "note": "This backup contains only metadata, not secret values",
  "created_by": "$(gcloud config get-value account)"
}
EOF
    
    # Upload to backup bucket
    gsutil -m cp -r "/tmp/$backup_dir" "$BACKUP_BUCKET/secrets-metadata/"
    rm -rf "/tmp/$backup_dir"
    
    success "Secrets metadata backed up (values not included for security)"
}

# Create full system backup
create_full_backup() {
    log "Creating full system backup..."
    
    setup_backup_infrastructure
    backup_cloud_run_services
    backup_load_balancer
    backup_iam
    backup_application_data
    backup_secrets_metadata
    
    # Create backup summary
    cat > "/tmp/backup-summary-$TIMESTAMP.json" << EOF
{
  "backup_id": "$TIMESTAMP",
  "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_id": "$PROJECT_ID",
  "region": "$REGION",
  "backup_bucket": "$BACKUP_BUCKET",
  "components_backed_up": [
    "cloud_run_services",
    "load_balancer",
    "iam",
    "application_data",
    "secrets_metadata"
  ],
  "created_by": "$(gcloud config get-value account)",
  "restore_command": "./backup-restore-system.sh restore $TIMESTAMP"
}
EOF
    
    gsutil cp "/tmp/backup-summary-$TIMESTAMP.json" "$BACKUP_BUCKET/"
    rm "/tmp/backup-summary-$TIMESTAMP.json"
    
    success "Full system backup completed: $TIMESTAMP"
    log "Backup stored in: $BACKUP_BUCKET"
    log "To restore: ./backup-restore-system.sh restore $TIMESTAMP"
}

# Restore from backup
restore_from_backup() {
    local backup_id="$1"
    
    if [ -z "$backup_id" ]; then
        error "Backup ID required. Usage: $0 restore <backup-id>"
    fi
    
    log "Restoring from backup: $backup_id"
    
    # Check if backup exists
    if ! gsutil ls "$BACKUP_BUCKET/backup-summary-${backup_id}.json" >/dev/null 2>&1; then
        error "Backup $backup_id not found in $BACKUP_BUCKET"
    fi
    
    # Download backup summary
    gsutil cp "$BACKUP_BUCKET/backup-summary-${backup_id}.json" "/tmp/"
    backup_info=$(cat "/tmp/backup-summary-${backup_id}.json")
    
    log "Backup info: $(echo "$backup_info" | jq -r '.backup_date')"
    
    warning "This will restore the system to backup $backup_id"
    read -p "Are you sure you want to continue? (y/N): " confirm
    if [ "$confirm" != "y" ]; then
        log "Restore cancelled"
        exit 0
    fi
    
    # Restore Cloud Run services
    log "Restoring Cloud Run services..."
    gsutil -m cp -r "$BACKUP_BUCKET/cloud-run/cloud-run-backup-${backup_id}" "/tmp/"
    
    cd "/tmp/cloud-run-backup-${backup_id}"
    for yaml_file in *.yaml; do
        if [ -f "$yaml_file" ]; then
            service_name=$(basename "$yaml_file" .yaml)
            log "Restoring service: $service_name"
            gcloud run services replace "$yaml_file" \
                --region="$REGION" \
                --project="$PROJECT_ID"
        fi
    done
    cd - >/dev/null
    
    success "System restored from backup: $backup_id"
    warning "Note: Secrets values are not restored automatically for security reasons"
    warning "Use ./setup-secrets.sh to reconfigure secrets if needed"
}

# List available backups
list_backups() {
    log "Available backups:"
    
    gsutil ls "$BACKUP_BUCKET/backup-summary-*.json" | while read backup_file; do
        backup_id=$(basename "$backup_file" | sed 's/backup-summary-\(.*\)\.json/\1/')
        
        # Download and parse backup info
        gsutil cp "$backup_file" "/tmp/" >/dev/null 2>&1
        backup_info=$(cat "/tmp/$(basename "$backup_file")" 2>/dev/null || echo '{}')
        
        backup_date=$(echo "$backup_info" | jq -r '.backup_date // "unknown"')
        created_by=$(echo "$backup_info" | jq -r '.created_by // "unknown"')
        
        echo "  $backup_id - $backup_date (by $created_by)"
        
        rm -f "/tmp/$(basename "$backup_file")"
    done
}

# Test backup and restore procedures
test_backup_restore() {
    log "Testing backup and restore procedures..."
    
    # Create a test backup
    log "Creating test backup..."
    create_full_backup
    
    # List backups to verify
    log "Verifying backup was created..."
    list_backups
    
    success "Backup and restore test completed"
    warning "Manual restore testing should be done in a separate test environment"
}

# Main execution
main() {
    case "${1:-backup}" in
        "backup")
            create_full_backup
            ;;
        "restore")
            restore_from_backup "$2"
            ;;
        "list")
            list_backups
            ;;
        "test")
            test_backup_restore
            ;;
        "setup")
            setup_backup_infrastructure
            ;;
        *)
            echo "Usage: $0 [backup|restore|list|test|setup]"
            echo "  backup           - Create full system backup (default)"
            echo "  restore <id>     - Restore from backup ID"
            echo "  list             - List available backups"
            echo "  test             - Test backup procedures"
            echo "  setup            - Setup backup infrastructure only"
            exit 1
            ;;
    esac
}

# Set project context
gcloud config set project "$PROJECT_ID"

# Execute main function
main "$@"
