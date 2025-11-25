#!/bin/bash
#
# deploy-config.sh - Configuration Management for ADK RAG Agent Deployment
#
# DESCRIPTION:
# ============
# This script manages deployment configuration for the ADK RAG Agent across different
# Google Cloud environments. It provides multiple input methods, validation, and
# cleanup capabilities for reliable multi-environment deployments.
#
# CONFIGURATION VARIABLES:
# =======================
# - PROJECT_ID: Google Cloud Project ID (e.g., "my-rag-agent-2025")
# - REGION: Google Cloud Region (e.g., "us-central1")
# - ORGANIZATION_DOMAIN: OAuth organization domain (e.g., "mycompany.com")
# - IAP_ADMIN_USER: Admin user email (e.g., "admin@mycompany.com")
# - REPO: Artifact Registry repository name (e.g., "cloud-run-repo1")
#
# INPUT METHODS:
# ==============
# 1. Interactive Mode: ./deploy-config.sh --interactive
# 2. Command Line Args: ./deploy-config.sh --project=my-project --region=us-west1
# 3. Environment Variables: Export variables before running
# 4. Configuration File: Use existing deployment.config file
#
# OUTPUT:
# =======
# Creates deployment.config file with validated configuration values
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration file path
CONFIG_FILE="./deployment.config"
BACKUP_CONFIG_FILE="./deployment.config.backup"

# Default values
DEFAULT_REGION="us-central1"
DEFAULT_REPO="cloud-run-repo1"

# Cleanup flag for error handling
CLEANUP_REQUIRED=false
CREATED_RESOURCES=()

echo -e "${BLUE}🔧 ADK RAG Agent - Deployment Configuration${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

### Cleanup Function
cleanup_on_failure() {
    if [[ "$CLEANUP_REQUIRED" == "true" ]]; then
        echo -e "${YELLOW}🧹 Cleaning up on failure...${NC}"
        
        # Restore backup config if it exists
        if [[ -f "$BACKUP_CONFIG_FILE" ]]; then
            echo "  Restoring configuration backup..."
            mv "$BACKUP_CONFIG_FILE" "$CONFIG_FILE"
        fi
        
        # Clean up any created resources
        for resource in "${CREATED_RESOURCES[@]}"; do
            echo "  Cleaning up: $resource"
            # Add specific cleanup commands here if needed
        done
        
        echo -e "${GREEN}✅ Cleanup completed${NC}"
    fi
}

# Set trap for cleanup on error
trap cleanup_on_failure ERR EXIT

### Validation Functions
validate_project_id() {
    local project_id="$1"
    
    # Check format (6-30 characters, lowercase, numbers, hyphens)
    if [[ ! "$project_id" =~ ^[a-z0-9-]{6,30}$ ]]; then
        echo -e "${RED}❌ Invalid project ID format${NC}"
        echo "Project ID must be 6-30 characters, lowercase letters, numbers, and hyphens only"
        return 1
    fi
    
    # Check if project exists and is accessible
    echo "  Validating project access..."
    if ! gcloud projects describe "$project_id" >/dev/null 2>&1; then
        echo -e "${RED}❌ Cannot access project: $project_id${NC}"
        echo "Please ensure:"
        echo "  1. Project exists"
        echo "  2. You have appropriate permissions"
        echo "  3. You are authenticated with gcloud"
        return 1
    fi
    
    echo -e "${GREEN}  ✅ Project validated${NC}"
    return 0
}

validate_region() {
    local region="$1"
    
    # Check if region exists
    echo "  Validating region..."
    if ! gcloud compute regions describe "$region" >/dev/null 2>&1; then
        echo -e "${RED}❌ Invalid region: $region${NC}"
        echo "Available regions:"
        gcloud compute regions list --format="value(name)" | head -10
        return 1
    fi
    
    echo -e "${GREEN}  ✅ Region validated${NC}"
    return 0
}

validate_email() {
    local email="$1"
    
    # Basic email format validation
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}❌ Invalid email format: $email${NC}"
        return 1
    fi
    
    echo -e "${GREEN}  ✅ Email format validated${NC}"
    return 0
}

validate_domain() {
    local domain="$1"
    
    # Basic domain format validation
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}❌ Invalid domain format: $domain${NC}"
        echo "Domain should be in format: company.com"
        return 1
    fi
    
    echo -e "${GREEN}  ✅ Domain format validated${NC}"
    return 0
}

### Input Functions
get_interactive_input() {
    echo -e "${CYAN}📝 Interactive Configuration Mode${NC}"
    echo "============================================"
    echo ""
    
    # Project ID
    while true; do
        read -p "Enter Google Cloud Project ID: " PROJECT_ID
        if validate_project_id "$PROJECT_ID"; then
            break
        fi
        echo ""
    done
    
    # Region
    echo ""
    echo "Regions that support Vertex AI RAG Engine are: us-central1, us-east4"
    read -p "Enter Google Cloud Region [$DEFAULT_REGION]: " REGION
    REGION="${REGION:-$DEFAULT_REGION}"
    if ! validate_region "$REGION"; then
        exit 1
    fi
    
    # Organization Domain
    echo ""
    read -p "Enter Organization Domain (e.g., mycompany.com): " ORGANIZATION_DOMAIN
    if ! validate_domain "$ORGANIZATION_DOMAIN"; then
        exit 1
    fi
    
    # Admin User
    echo ""
    read -p "Enter IAP Admin User Email: " IAP_ADMIN_USER
    if ! validate_email "$IAP_ADMIN_USER"; then
        exit 1
    fi
    
    # Repository Name
    echo ""
    read -p "Enter Artifact Registry Repository Name [$DEFAULT_REPO]: " REPO
    REPO="${REPO:-$DEFAULT_REPO}"
    
    echo ""
    echo -e "${GREEN}✅ Interactive input completed${NC}"
}

parse_command_line_args() {
    echo -e "${CYAN}📝 Command Line Arguments Mode${NC}"
    echo "============================================"
    
    for arg in "$@"; do
        case $arg in
            --project=*)
                PROJECT_ID="${arg#*=}"
                ;;
            --region=*)
                REGION="${arg#*=}"
                ;;
            --domain=*)
                ORGANIZATION_DOMAIN="${arg#*=}"
                ;;
            --admin=*)
                IAP_ADMIN_USER="${arg#*=}"
                ;;
            --repo=*)
                REPO="${arg#*=}"
                ;;
            --interactive)
                INTERACTIVE_MODE=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown argument: $arg${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

load_from_config_file() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${CYAN}📝 Loading from Configuration File${NC}"
        echo "============================================"
        echo "Loading configuration from: $CONFIG_FILE"
        
        # Create backup
        cp "$CONFIG_FILE" "$BACKUP_CONFIG_FILE"
        CLEANUP_REQUIRED=true
        
        # Source the config file
        source "$CONFIG_FILE"
        
        echo -e "${GREEN}✅ Configuration loaded from file${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  No configuration file found${NC}"
        return 1
    fi
}

load_from_environment() {
    echo -e "${CYAN}📝 Checking Environment Variables${NC}"
    echo "============================================"
    
    local found_vars=0
    
    if [[ -n "${PROJECT_ID:-}" ]]; then
        echo "  Found PROJECT_ID: $PROJECT_ID"
        ((found_vars++))
    fi
    
    if [[ -n "${REGION:-}" ]]; then
        echo "  Found REGION: $REGION"
        ((found_vars++))
    fi
    
    if [[ -n "${ORGANIZATION_DOMAIN:-}" ]]; then
        echo "  Found ORGANIZATION_DOMAIN: $ORGANIZATION_DOMAIN"
        ((found_vars++))
    fi
    
    if [[ -n "${IAP_ADMIN_USER:-}" ]]; then
        echo "  Found IAP_ADMIN_USER: $IAP_ADMIN_USER"
        ((found_vars++))
    fi
    
    if [[ -n "${REPO:-}" ]]; then
        echo "  Found REPO: $REPO"
        ((found_vars++))
    fi
    
    if [[ $found_vars -gt 0 ]]; then
        echo -e "${GREEN}✅ Found $found_vars environment variables${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  No environment variables found${NC}"
        return 1
    fi
}

validate_all_configuration() {
    echo -e "${CYAN}🔍 Validating Configuration${NC}"
    echo "============================================"
    
    local validation_errors=0
    
    # Check required variables
    if [[ -z "${PROJECT_ID:-}" ]]; then
        echo -e "${RED}❌ PROJECT_ID is required${NC}"
        ((validation_errors++))
    else
        if ! validate_project_id "$PROJECT_ID"; then
            ((validation_errors++))
        fi
    fi
    
    if [[ -z "${REGION:-}" ]]; then
        echo -e "${RED}❌ REGION is required${NC}"
        ((validation_errors++))
    else
        if ! validate_region "$REGION"; then
            ((validation_errors++))
        fi
    fi
    
    if [[ -z "${ORGANIZATION_DOMAIN:-}" ]]; then
        echo -e "${RED}❌ ORGANIZATION_DOMAIN is required${NC}"
        ((validation_errors++))
    else
        if ! validate_domain "$ORGANIZATION_DOMAIN"; then
            ((validation_errors++))
        fi
    fi
    
    if [[ -z "${IAP_ADMIN_USER:-}" ]]; then
        echo -e "${RED}❌ IAP_ADMIN_USER is required${NC}"
        ((validation_errors++))
    else
        if ! validate_email "$IAP_ADMIN_USER"; then
            ((validation_errors++))
        fi
    fi
    
    # Set defaults for optional variables
    REPO="${REPO:-$DEFAULT_REPO}"
    
    if [[ $validation_errors -gt 0 ]]; then
        echo -e "${RED}❌ Configuration validation failed with $validation_errors errors${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ All configuration validated successfully${NC}"
    return 0
}

save_configuration() {
    echo -e "${CYAN}💾 Saving Configuration${NC}"
    echo "============================================"
    
    # Create configuration file
    cat > "$CONFIG_FILE" << EOF
#!/bin/bash
# ADK RAG Agent Deployment Configuration
# Generated on: $(date)

# Core Configuration
export PROJECT_ID="$PROJECT_ID"
export REGION="$REGION"
export ORGANIZATION_DOMAIN="$ORGANIZATION_DOMAIN"
export IAP_ADMIN_USER="$IAP_ADMIN_USER"
export REPO="$REPO"

# Derived Configuration
export PROJECT_NUMBER=\$(gcloud projects describe "\$PROJECT_ID" --format="value(projectNumber)")
export BACKEND_IMAGE="\$REGION-docker.pkg.dev/\$PROJECT_ID/\$REPO/backend:\$(git rev-parse --short HEAD 2>/dev/null || echo 'manual')"
export FRONTEND_IMAGE="\$REGION-docker.pkg.dev/\$PROJECT_ID/\$REPO/frontend:\$(git rev-parse --short HEAD 2>/dev/null || echo 'manual')"

# Display current configuration
echo "Configuration loaded:"
echo "  Project ID: \$PROJECT_ID"
echo "  Region: \$REGION"
echo "  Organization: \$ORGANIZATION_DOMAIN"
echo "  Admin User: \$IAP_ADMIN_USER"
echo "  Repository: \$REPO"
EOF

    chmod +x "$CONFIG_FILE"
    echo "Configuration saved to: $CONFIG_FILE"
    echo -e "${GREEN}✅ Configuration file created${NC}"
}

show_configuration_summary() {
    echo ""
    echo -e "${BLUE}📋 Configuration Summary${NC}"
    echo "============================================"
    echo -e "${BOLD}Project ID:${NC} $PROJECT_ID"
    echo -e "${BOLD}Region:${NC} $REGION"
    echo -e "${BOLD}Organization Domain:${NC} $ORGANIZATION_DOMAIN"
    echo -e "${BOLD}IAP Admin User:${NC} $IAP_ADMIN_USER"
    echo -e "${BOLD}Repository:${NC} $REPO"
    echo ""
}

show_help() {
    echo "ADK RAG Agent - Deployment Configuration"
    echo ""
    echo "USAGE:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --interactive              Interactive configuration mode"
    echo "  --project=PROJECT_ID       Set Google Cloud Project ID"
    echo "  --region=REGION           Set Google Cloud Region"
    echo "  --domain=DOMAIN           Set Organization Domain"
    echo "  --admin=EMAIL             Set IAP Admin User Email"
    echo "  --repo=REPO_NAME          Set Artifact Registry Repository"
    echo "  --help, -h                Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  # Interactive mode"
    echo "  $0 --interactive"
    echo ""
    echo "  # Command line configuration"
    echo "  $0 --project=my-rag-2025 --region=us-west1 --domain=mycompany.com --admin=admin@mycompany.com"
    echo ""
    echo "  # Use environment variables"
    echo "  export PROJECT_ID=my-rag-2025"
    echo "  export REGION=us-west1"
    echo "  $0"
    echo ""
}

### Main Execution
main() {
    # Parse command line arguments
    INTERACTIVE_MODE=false
    parse_command_line_args "$@"
    
    # Try different input methods in order of preference
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        get_interactive_input
    elif ! load_from_config_file && ! load_from_environment; then
        echo -e "${YELLOW}⚠️  No configuration found. Switching to interactive mode...${NC}"
        echo ""
        get_interactive_input
    fi
    
    # Validate all configuration
    if ! validate_all_configuration; then
        echo -e "${RED}❌ Configuration validation failed${NC}"
        exit 1
    fi
    
    # Show summary and confirm
    show_configuration_summary
    
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo ""
        read -p "Save this configuration? (y/N): " save_config
        if [[ "$save_config" != "y" && "$save_config" != "Y" ]]; then
            echo "Configuration not saved."
            exit 0
        fi
    fi
    
    # Save configuration
    save_configuration
    
    # Success - disable cleanup
    CLEANUP_REQUIRED=false
    
    echo ""
    echo -e "${GREEN}🎉 Configuration completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo "1. Review the configuration in: $CONFIG_FILE"
    echo "2. Update the project ID in the backend files with: ./infrastructure/deploy-new-project-id.sh"
    echo "2. Run the deployment: ./infrastructure/deploy-complete-oauth-v0.2.sh"
    echo "3. The deployment will automatically load this configuration"
    echo ""
}

# Run main function with all arguments
main "$@"
