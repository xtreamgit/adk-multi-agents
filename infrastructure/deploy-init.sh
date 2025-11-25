#!/bin/bash
#
# deploy-init.sh - Google Cloud Project Initialization for ADK RAG Agent
#
# DESCRIPTION:
# ============
# This script initializes a new Google Cloud environment for ADK RAG Agent deployment.
# It handles authentication, project creation, billing setup, and initial configuration
# with comprehensive error handling and cleanup capabilities.
#
# FEATURES:
# =========
# - Google Cloud authentication via gcloud init
# - Project creation with validation
# - Billing account association
# - Initial API enablement
# - Region validation and setup
# - Comprehensive error handling with cleanup
# - Support for existing projects
#
# USAGE:
# ======
# ./deploy-init.sh --project-id=my-rag-2025 --region=us-central1 [OPTIONS]
#
# OPTIONS:
# ========
# --project-id=ID       Project ID to create (required)
# --region=REGION       Default region (default: us-central1)
# --billing-account=ID  Billing account ID (optional, will prompt if needed)
# --organization-id=ID  Organization ID (optional)
# --skip-auth          Skip authentication (use existing auth)
# --force              Force project creation even if exists
# --help, -h           Show help message
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

# Default values
DEFAULT_REGION="us-central1"
DEFAULT_REPO="cloud-run-repo1"
SKIP_AUTH=false
FORCE_CREATE=false
CLEANUP_REQUIRED=false
CREATED_RESOURCES=()

# Configuration file path
CONFIG_FILE="./deployment.config"

# Global variables
PROJECT_ID=""
REGION=""
BILLING_ACCOUNT=""
ORGANIZATION_ID=""
ORGANIZATION_DOMAIN=""
IAP_ADMIN_USER=""
REPO=""
PROJECT_CREATED=false

echo -e "${BLUE}🚀 ADK RAG Agent - Google Cloud Project Initialization${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""

### Cleanup Function
cleanup_on_failure() {
    if [[ "$CLEANUP_REQUIRED" == "true" ]]; then
        echo -e "${YELLOW}🧹 Cleaning up on failure...${NC}"
        
        # Delete created project if we created it
        if [[ "$PROJECT_CREATED" == "true" && -n "$PROJECT_ID" ]]; then
            echo "  Deleting created project: $PROJECT_ID"
            gcloud projects delete "$PROJECT_ID" --quiet 2>/dev/null || echo "    Failed to delete project (may need manual cleanup)"
            CREATED_RESOURCES+=("Project: $PROJECT_ID")
        fi
        
        # List resources that may need manual cleanup
        if [[ ${#CREATED_RESOURCES[@]} -gt 0 ]]; then
            echo -e "${YELLOW}⚠️  Resources that may need manual cleanup:${NC}"
            for resource in "${CREATED_RESOURCES[@]}"; do
                echo "    - $resource"
            done
        fi
        
        echo -e "${GREEN}✅ Cleanup completed${NC}"
    fi
}

# Set trap for cleanup on error
trap cleanup_on_failure ERR EXIT

### Configuration File Functions
load_deployment_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${CYAN}📄 Loading existing deployment configuration${NC}"
        echo "============================================"
        echo "Found configuration file: $CONFIG_FILE"
        echo ""
        
        # Source the config file to load variables
        # shellcheck disable=SC1090
        source "$CONFIG_FILE" 2>/dev/null || true
        
        # Display loaded values
        if [[ -n "$PROJECT_ID" ]]; then
            echo "  Project ID: $PROJECT_ID"
        fi
        if [[ -n "$REGION" ]]; then
            echo "  Region: $REGION"
        fi
        if [[ -n "$ORGANIZATION_DOMAIN" ]]; then
            echo "  Organization Domain: $ORGANIZATION_DOMAIN"
        fi
        if [[ -n "$IAP_ADMIN_USER" ]]; then
            echo "  IAP Admin User: $IAP_ADMIN_USER"
        fi
        if [[ -n "$REPO" ]]; then
            echo "  Repository: $REPO"
        fi
        
        echo -e "${GREEN}✅ Configuration loaded from file${NC}"
        echo ""
        return 0
    else
        echo -e "${YELLOW}⚠️  No existing configuration file found${NC}"
        echo "A new configuration will be created after initialization"
        echo ""
        return 1
    fi
}

get_organization_domain_from_email() {
    local email="$1"
    
    # Extract domain from email (everything after @)
    local domain="${email##*@}"
    
    echo "$domain"
}

save_deployment_config() {
    echo -e "${CYAN}💾 Saving Deployment Configuration${NC}"
    echo "============================================"
    
    # Get the authenticated user for IAP_ADMIN_USER
    local active_account
    active_account=$(gcloud auth list --filter=status=ACTIVE --format="value(account)" | head -1)
    IAP_ADMIN_USER="$active_account"
    
    # Extract organization domain from user email
    ORGANIZATION_DOMAIN=$(get_organization_domain_from_email "$active_account")
    
    # Set default repository if not set
    REPO="${REPO:-$DEFAULT_REPO}"
    
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
    echo ""
    echo "Configuration details:"
    echo "  Project ID: $PROJECT_ID"
    echo "  Region: $REGION"
    echo "  Organization Domain: $ORGANIZATION_DOMAIN"
    echo "  IAP Admin User: $IAP_ADMIN_USER"
    echo "  Repository: $REPO"
    echo ""
    echo -e "${GREEN}✅ Configuration file created${NC}"
}

### Validation Functions
validate_project_id() {
    local project_id="$1"
    
    # Check format (6-30 characters, lowercase, numbers, hyphens)
    if [[ ! "$project_id" =~ ^[a-z0-9-]{6,30}$ ]]; then
        echo -e "${RED}❌ Invalid project ID format: $project_id${NC}"
        echo "Project ID must be:"
        echo "  - 6-30 characters long"
        echo "  - Lowercase letters, numbers, and hyphens only"
        echo "  - Cannot start or end with hyphen"
        return 1
    fi
    
    # Check if project ID starts or ends with hyphen
    if [[ "$project_id" =~ ^- ]] || [[ "$project_id" =~ -$ ]]; then
        echo -e "${RED}❌ Project ID cannot start or end with hyphen${NC}"
        return 1
    fi
    
    echo -e "${GREEN}  ✅ Project ID format validated${NC}"
    return 0
}

validate_region() {
    local region="$1"
    
    echo "  Validating region: $region"
    
    # Use a simple list of common regions for validation without project context
    local valid_regions=(
        "us-central1" "us-east4"
    )
    
    # Check if region is in the valid list
    local region_found=false
    for valid_region in "${valid_regions[@]}"; do
        if [[ "$region" == "$valid_region" ]]; then
            region_found=true
            break
        fi
    done
    
    if [[ "$region_found" == "false" ]]; then
        echo -e "${RED}❌ Invalid region: $region${NC}"
        echo "Common valid regions:"
        printf "  %s\n" "${valid_regions[@]:0:10}"
        echo "  ... and more"
        echo ""
        echo "For a complete list, see: https://cloud.google.com/compute/docs/regions-zones"
        return 1
    fi
    
    echo -e "${GREEN}  ✅ Region validated${NC}"
    return 0
}

validate_billing_account() {
    local billing_account="$1"
    
    if [[ -z "$billing_account" ]]; then
        return 0  # Optional parameter
    fi
    
    echo "  Validating billing account: $billing_account"
    if ! gcloud billing accounts describe "$billing_account" >/dev/null 2>&1; then
        echo -e "${RED}❌ Cannot access billing account: $billing_account${NC}"
        echo "Available billing accounts:"
        gcloud billing accounts list --format="table(name,displayName,open)" 2>/dev/null || echo "No billing accounts accessible"
        return 1
    fi
    
    echo -e "${GREEN}  ✅ Billing account validated${NC}"
    return 0
}

### Authentication Functions
check_gcloud_auth() {
    echo -e "${CYAN}🔐 Checking Google Cloud Authentication${NC}"
    echo "============================================"
    
    # Check if gcloud is installed
    if ! command -v gcloud >/dev/null 2>&1; then
        echo -e "${RED}❌ gcloud CLI not found${NC}"
        echo "Please install Google Cloud SDK:"
        echo "https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check if authenticated
    if ! gcloud auth list --filter=status=ACTIVE --format="value(account)" | grep -q "@"; then
        echo -e "${YELLOW}⚠️  Not authenticated with gcloud${NC}"
        return 1
    fi
    
    local active_account
    active_account=$(gcloud auth list --filter=status=ACTIVE --format="value(account)" | head -1)
    echo "Active account: $active_account"
    echo -e "${GREEN}✅ Already authenticated${NC}"
    return 0
}

check_application_default_credentials() {
    echo -e "${CYAN}🔑 Checking Application Default Credentials (ADC)${NC}"
    echo "============================================"
    
    # Try to get ADC info
    local adc_account=""
    if adc_account=$(gcloud auth application-default print-access-token 2>/dev/null); then
        # ADC is configured, get the account email
        local adc_info
        adc_info=$(gcloud auth application-default print-access-token --format=json 2>/dev/null | grep -o '"email":"[^"]*"' | cut -d'"' -f4 || echo "")
        
        # If we can't get email from token, check the credentials file
        if [[ -z "$adc_info" ]]; then
            local cred_file="$HOME/.config/gcloud/application_default_credentials.json"
            if [[ -f "$cred_file" ]]; then
                adc_info=$(grep -o '"client_email":"[^"]*"' "$cred_file" | cut -d'"' -f4 || echo "Configured")
                if [[ -z "$adc_info" ]]; then
                    adc_info=$(grep -o '"quota_project_id":"[^"]*"' "$cred_file" | cut -d'"' -f4 || echo "Configured")
                fi
            fi
        fi
        
        echo -e "${GREEN}✅ Application Default Credentials are configured${NC}"
        if [[ -n "$adc_info" ]]; then
            echo "  Account: $adc_info"
        fi
        return 0
    else
        echo -e "${YELLOW}⚠️  Application Default Credentials not configured${NC}"
        return 1
    fi
}

confirm_current_account() {
    local account="$1"
    
    echo ""
    echo -e "${BOLD}Current authenticated account:${NC}"
    echo -e "  ${CYAN}$account${NC}"
    echo ""
    echo -e "${YELLOW}This account will be used for:${NC}"
    echo "  • Creating and managing the Google Cloud project"
    echo "  • Deploying Cloud Run services"
    echo "  • Configuring IAP and Load Balancer"
    echo "  • All API calls during deployment"
    echo ""
    
    read -p "Is this the correct account? (y/n): " -r confirm
    echo ""
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

perform_application_default_login() {
    echo -e "${CYAN}🔑 Setting up Application Default Credentials${NC}"
    echo "============================================"
    echo ""
    echo "Application Default Credentials (ADC) are required for:"
    echo "  • Cloud Run deployments"
    echo "  • API authentication during builds"
    echo "  • Service-to-service authentication"
    echo ""
    echo "This will open a browser window for authentication..."
    echo ""
    
    read -p "Press Enter to continue..."
    
    # Run gcloud auth application-default login
    if gcloud auth application-default login; then
        echo ""
        echo -e "${GREEN}✅ Application Default Credentials configured successfully${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}❌ Failed to configure Application Default Credentials${NC}"
        echo "Please try again or check your authentication settings"
        return 1
    fi
}

perform_gcloud_init() {
    echo -e "${CYAN}🔐 Initializing Google Cloud Authentication${NC}"
    echo "============================================"
    
    echo "Starting gcloud init process..."
    echo "This will:"
    echo "  1. Authenticate with your Google account"
    echo "  2. Set up default configuration"
    echo "  3. Select or create a project"
    echo ""
    
    # Run gcloud init
    if ! gcloud init --console-only; then
        echo -e "${RED}❌ gcloud init failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Authentication completed${NC}"
}

### Project Management Functions
check_project_exists() {
    local project_id="$1"
    
    echo "  Checking if project exists: $project_id"
    if gcloud projects describe "$project_id" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Project already exists: $project_id${NC}"
        return 0
    else
        echo "  Project does not exist"
        return 1
    fi
}

create_project() {
    local project_id="$1"
    local organization_id="$2"
    
    echo -e "${CYAN}📋 Creating Google Cloud Project${NC}"
    echo "============================================"
    
    # Check if project already exists
    if check_project_exists "$project_id"; then
        if [[ "$FORCE_CREATE" == "false" ]]; then
            echo ""
            echo "The project '$project_id' already exists."
            echo "You cannot create a new project with the same ID."
            echo ""
            read -p "Do you want to continue with the existing project? (y/n): " continue_existing
            echo ""
            
            if [[ "$continue_existing" != "y" && "$continue_existing" != "Y" ]]; then
                # User doesn't want to use existing project - offer to create new one
                echo -e "${YELLOW}You chose not to use the existing project.${NC}"
                echo ""
                read -p "Would you like to create a new project now? (y/n): " create_new
                echo ""
                
                if [[ "$create_new" =~ ^[Yy]$ ]]; then
                    # Prompt for new project ID
                    echo -e "${CYAN}Let's create a new project...${NC}"
                    echo ""
                    
                    local new_project_id=""
                    while true; do
                        read -p "Enter new Project ID (6-30 chars, lowercase, numbers, hyphens): " new_project_id
                        
                        # Validate the new project ID
                        if validate_project_id "$new_project_id" 2>/dev/null; then
                            # Check if this new ID also exists
                            if gcloud projects describe "$new_project_id" >/dev/null 2>&1; then
                                echo -e "${RED}❌ Project '$new_project_id' also exists. Please choose a different ID.${NC}"
                                echo ""
                            else
                                break
                            fi
                        else
                            echo ""
                        fi
                    done
                    
                    # Prompt for region
                    echo ""
                    read -p "Enter Region [default: $DEFAULT_REGION]: " new_region
                    new_region="${new_region:-$DEFAULT_REGION}"
                    
                    # Validate region
                    if ! validate_region "$new_region" 2>/dev/null; then
                        echo -e "${YELLOW}⚠️  Using default region: $DEFAULT_REGION${NC}"
                        new_region="$DEFAULT_REGION"
                    fi
                    
                    echo ""
                    echo -e "${GREEN}Creating new project with:${NC}"
                    echo "  Project ID: $new_project_id"
                    echo "  Region: $new_region"
                    echo ""
                    
                    # Update global variables
                    PROJECT_ID="$new_project_id"
                    REGION="$new_region"
                    
                    # Recursively call create_project with new values
                    create_project "$new_project_id" "$organization_id"
                    return $?
                else
                    # User doesn't want to create a new project - exit
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${YELLOW}Deployment Initialization Cancelled${NC}"
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                    echo "You can run the script again later with a different project ID:"
                    echo -e "${CYAN}  ./infrastructure/deploy-init.sh --project-id=your-new-project-name${NC}"
                    echo ""
                    exit 0
                fi
            fi
        fi
        echo "Using existing project: $project_id"
        return 0
    fi
    
    # Create project command
    local create_cmd="gcloud projects create $project_id --name=\"$project_id\""
    
    # Add organization if specified
    if [[ -n "$organization_id" ]]; then
        create_cmd="$create_cmd --organization=$organization_id"
        echo "Creating project in organization: $organization_id"
    fi
    
    echo "Creating project: $project_id"
    if eval "$create_cmd"; then
        PROJECT_CREATED=true
        CLEANUP_REQUIRED=true
        CREATED_RESOURCES+=("Project: $project_id")
        echo -e "${GREEN}✅ Project created successfully${NC}"
    else
        echo -e "${RED}❌ Failed to create project${NC}"
        exit 1
    fi
}

setup_billing() {
    local project_id="$1"
    local billing_account="$2"
    
    echo -e "${CYAN}💳 Setting up Billing${NC}"
    echo "============================================"
    
    # Check if billing is already enabled
    if gcloud billing projects describe "$project_id" >/dev/null 2>&1; then
        local current_billing
        current_billing=$(gcloud billing projects describe "$project_id" --format="value(billingAccountName)" 2>/dev/null || echo "")
        if [[ -n "$current_billing" ]]; then
            echo "Billing already configured: $current_billing"
            echo -e "${GREEN}✅ Billing already set up${NC}"
            return 0
        fi
    fi
    
    # If no billing account specified, try to find one
    if [[ -z "$billing_account" ]]; then
        echo "No billing account specified. Checking available accounts..."
        local available_accounts
        available_accounts=$(gcloud billing accounts list --filter="open=true" --format="value(name)" 2>/dev/null || echo "")
        
        if [[ -z "$available_accounts" ]]; then
            echo -e "${YELLOW}⚠️  No billing accounts found${NC}"
            echo "Please set up billing manually in the Google Cloud Console:"
            echo "https://console.cloud.google.com/billing/linkedaccount?project=$project_id"
            return 0
        fi
        
        # Use first available billing account
        billing_account=$(echo "$available_accounts" | head -1)
        echo "Using billing account: $billing_account"
    fi
    
    # Link billing account to project
    echo "Linking billing account to project..."
    if gcloud billing projects link "$project_id" --billing-account="$billing_account"; then
        echo -e "${GREEN}✅ Billing configured successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Failed to configure billing automatically${NC}"
        echo "Please set up billing manually in the Google Cloud Console:"
        echo "https://console.cloud.google.com/billing/linkedaccount?project=$project_id"
    fi
}

enable_essential_apis() {
    local project_id="$1"
    
    echo -e "${CYAN}🔧 Enabling Required APIs for ADK RAG Agent${NC}"
    echo "============================================"
    
    # Set the project for gcloud commands
    gcloud config set project "$project_id"
    
    # All required APIs for ADK RAG Agent deployment
    local required_apis=(
        "cloudresourcemanager.googleapis.com"
        "serviceusage.googleapis.com"
        "iam.googleapis.com"
        "cloudbilling.googleapis.com"
        "run.googleapis.com"
        "artifactregistry.googleapis.com"
        "cloudbuild.googleapis.com"
        "compute.googleapis.com"
        "iap.googleapis.com"
    )
    
    echo "Checking and enabling required APIs for deployment..."
    echo "This may take a few minutes..."
    echo ""
    
    local failed_apis=()
    local enabled_count=0
    local already_enabled_count=0
    
    for api in "${required_apis[@]}"; do
        echo "  Checking $api..."
        
        # Check if API is already enabled
        if gcloud services list --enabled --format="value(name)" --quiet 2>/dev/null | grep -q "^${api}$"; then
            echo -e "    ${GREEN}✅ $api already enabled${NC}"
            ((already_enabled_count++))
            ((enabled_count++))
        else
            echo "    Enabling $api..."
            # Try to enable the API with better error handling
            if gcloud services enable "$api" --quiet 2>/dev/null; then
                echo -e "    ${GREEN}✅ $api enabled successfully${NC}"
                ((enabled_count++))
            else
                # Get more detailed error information
                local error_output
                error_output=$(gcloud services enable "$api" 2>&1 || true)
                echo -e "    ${RED}❌ Failed to enable $api${NC}"
                
                # Check for common error patterns
                if echo "$error_output" | grep -q "billing"; then
                    echo -e "    ${YELLOW}    → Billing may not be enabled${NC}"
                elif echo "$error_output" | grep -q "permission"; then
                    echo -e "    ${YELLOW}    → Insufficient permissions${NC}"
                elif echo "$error_output" | grep -q "quota"; then
                    echo -e "    ${YELLOW}    → Quota exceeded${NC}"
                else
                    echo -e "    ${YELLOW}    → Check project permissions and billing${NC}"
                fi
                
                failed_apis+=("$api")
            fi
        fi
    done
    
    echo ""
    echo "API Enablement Summary:"
    echo "  Already enabled: $already_enabled_count/${#required_apis[@]} APIs"
    echo "  Successfully enabled: $enabled_count/${#required_apis[@]} APIs"
    
    if [[ ${#failed_apis[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Failed to enable ${#failed_apis[@]} APIs:${NC}"
        for api in "${failed_apis[@]}"; do
            echo "    - $api"
        done
        echo ""
        echo -e "${YELLOW}Common causes and solutions:${NC}"
        echo "  1. Billing not enabled - Enable billing in Google Cloud Console"
        echo "  2. Insufficient permissions - Ensure you have Project Editor/Owner role"
        echo "  3. Organization policies - Check with your organization admin"
        echo ""
        echo "Manual enablement options:"
        echo "  Google Cloud Console: https://console.cloud.google.com/apis/dashboard?project=$project_id"
        echo "  Command line (run individually):"
        for api in "${failed_apis[@]}"; do
            echo "    gcloud services enable $api --project=$project_id"
        done
        echo ""
        echo -e "${YELLOW}Note: Some APIs may still work for deployment even if enablement failed${NC}"
    else
        echo -e "${GREEN}✅ All required APIs are enabled${NC}"
    fi
    
    echo ""
}

set_default_region() {
    local region="$1"
    
    echo -e "${CYAN}🌍 Setting Default Region${NC}"
    echo "============================================"
    
    echo "Setting default region to: $region"
    
    # Set region without validation (since APIs may not be fully ready)
    gcloud config set compute/region "$region" --quiet
    gcloud config set compute/zone "$region-a" --quiet
    
    # Verify the configuration was set
    local configured_region
    configured_region=$(gcloud config get-value compute/region 2>/dev/null)
    
    if [[ "$configured_region" == "$region" ]]; then
        echo -e "${GREEN}✅ Default region configured: $region${NC}"
        echo -e "${GREEN}✅ Default zone configured: $region-a${NC}"
    else
        echo -e "${YELLOW}⚠️  Region configuration may need manual verification${NC}"
        echo "You can verify with: gcloud config list"
    fi
}

### Argument Parsing
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-id=*)
                PROJECT_ID="${1#*=}"
                shift
                ;;
            --region=*)
                REGION="${1#*=}"
                shift
                ;;
            --billing-account=*)
                BILLING_ACCOUNT="${1#*=}"
                shift
                ;;
            --organization-id=*)
                ORGANIZATION_ID="${1#*=}"
                shift
                ;;
            --skip-auth)
                SKIP_AUTH=true
                shift
                ;;
            --force)
                FORCE_CREATE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown argument: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    echo "ADK RAG Agent - Google Cloud Project Initialization"
    echo ""
    echo "USAGE:"
    echo "  $0 [--project-id=PROJECT_ID] [OPTIONS]"
    echo ""
    echo "NOTE:"
    echo "  If deployment.config exists, values will be loaded from it."
    echo "  Command-line arguments override config file values."
    echo ""
    echo "OPTIONS:"
    echo "  --project-id=ID           Project ID to create (6-30 chars, lowercase, numbers, hyphens)"
    echo "  --region=REGION           Default region (default: us-central1)"
    echo "  --billing-account=ID      Billing account ID (will prompt if not specified)"
    echo "  --organization-id=ID      Organization ID for project creation"
    echo "  --skip-auth              Skip authentication (use existing gcloud auth)"
    echo "  --force                  Force creation even if project exists"
    echo "  --help, -h               Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  # Basic project creation"
    echo "  $0 --project-id=my-rag-agent-2025"
    echo ""
    echo "  # Use existing deployment.config (if exists)"
    echo "  $0"
    echo ""
    echo "  # With specific region and billing"
    echo "  $0 --project-id=my-rag-2025 --region=us-west1 --billing-account=ABCDEF-123456-GHIJKL"
    echo ""
    echo "  # Skip authentication (use existing)"
    echo "  $0 --project-id=my-rag-2025 --skip-auth"
    echo ""
    echo "  # Force creation with existing project"
    echo "  $0 --project-id=existing-project --force"
    echo ""
}

show_summary() {
    echo ""
    echo -e "${BLUE}📋 Initialization Summary${NC}"
    echo "============================================"
    echo -e "${BOLD}Project ID:${NC} $PROJECT_ID"
    echo -e "${BOLD}Region:${NC} $REGION"
    echo -e "${BOLD}Project Status:${NC} $(if [[ "$PROJECT_CREATED" == "true" ]]; then echo "Created"; else echo "Using Existing"; fi)"
    echo -e "${BOLD}IAP Admin User:${NC} $IAP_ADMIN_USER"
    echo -e "${BOLD}Organization Domain:${NC} $ORGANIZATION_DOMAIN"
    echo -e "${BOLD}Repository:${NC} $REPO"
    
    if [[ -n "$BILLING_ACCOUNT" ]]; then
        echo -e "${BOLD}Billing Account:${NC} $BILLING_ACCOUNT"
    fi
    
    if [[ -n "$ORGANIZATION_ID" ]]; then
        echo -e "${BOLD}Organization ID:${NC} $ORGANIZATION_ID"
    fi
    
    echo ""
    echo -e "${BLUE}📄 Configuration File:${NC}"
    echo "  Location: $CONFIG_FILE"
    echo "  Status: Created/Updated"
    echo ""
    echo -e "${BLUE}🔗 Useful Links:${NC}"
    echo "  Project Console: https://console.cloud.google.com/home/dashboard?project=$PROJECT_ID"
    echo "  Billing: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
    echo "  APIs: https://console.cloud.google.com/apis/dashboard?project=$PROJECT_ID"
    echo ""
}

### Main Execution
main() {
    # Try to load existing configuration first
    load_deployment_config || true
    
    # Parse command line arguments (these will override config file values)
    parse_arguments "$@"
    
    # Validate required parameters
    if [[ -z "$PROJECT_ID" ]]; then
        echo -e "${RED}❌ Project ID is required${NC}"
        echo "Provide it via --project-id argument or deployment.config file"
        echo ""
        show_help
        exit 1
    fi
    
    # Set defaults
    REGION="${REGION:-$DEFAULT_REGION}"
    REPO="${REPO:-$DEFAULT_REPO}"
    
    # Validate inputs
    echo -e "${CYAN}🔍 Validating Input Parameters${NC}"
    echo "============================================"
    validate_project_id "$PROJECT_ID"
    validate_region "$REGION"
    validate_billing_account "$BILLING_ACCOUNT"
    echo -e "${GREEN}✅ Input validation completed${NC}"
    echo ""
    
    # Handle authentication
    if [[ "$SKIP_AUTH" == "false" ]]; then
        # Step 1: Check user authentication
        if ! check_gcloud_auth; then
            echo "User authentication required..."
            perform_gcloud_init
        else
            # Get active account and confirm
            local active_account
            active_account=$(gcloud auth list --filter=status=ACTIVE --format="value(account)" | head -1)
            
            if ! confirm_current_account "$active_account"; then
                echo -e "${YELLOW}Please authenticate with the correct account...${NC}"
                echo ""
                perform_gcloud_init
            fi
        fi
        echo ""
        
        # Step 2: Check Application Default Credentials
        if ! check_application_default_credentials; then
            echo ""
            echo -e "${YELLOW}Application Default Credentials are required for deployment.${NC}"
            echo ""
            
            if ! perform_application_default_login; then
                echo -e "${RED}❌ Cannot proceed without Application Default Credentials${NC}"
                exit 1
            fi
        else
            # ADC exists, confirm it's the right account
            echo ""
            read -p "Use these Application Default Credentials? (y/n): " -r use_adc
            echo ""
            
            if [[ "$use_adc" =~ ^[Nn]$ ]]; then
                echo -e "${YELLOW}Reconfiguring Application Default Credentials...${NC}"
                echo ""
                
                if ! perform_application_default_login; then
                    echo -e "${RED}❌ Cannot proceed without Application Default Credentials${NC}"
                    exit 1
                fi
            else
                echo -e "${GREEN}✅ Using existing Application Default Credentials${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Skipping authentication (using existing)${NC}"
        
        # Still verify authentication exists
        if ! check_gcloud_auth; then
            echo -e "${RED}❌ No active user authentication found${NC}"
            exit 1
        fi
        
        if ! check_application_default_credentials; then
            echo -e "${RED}❌ No Application Default Credentials found${NC}"
            echo "Run without --skip-auth to configure authentication"
            exit 1
        fi
    fi
    echo ""
    
    # Create project
    create_project "$PROJECT_ID" "$ORGANIZATION_ID"
    echo ""
    
    # Set up billing
    setup_billing "$PROJECT_ID" "$BILLING_ACCOUNT"
    echo ""
    
    # Enable essential APIs
    enable_essential_apis "$PROJECT_ID"
    echo ""
    
    # Set default region
    set_default_region "$REGION"
    echo ""
    
    # Save deployment configuration
    save_deployment_config
    echo ""
    
    # Success - disable cleanup
    CLEANUP_REQUIRED=false
    
    # Show summary
    show_summary
    
    echo -e "${GREEN}🎉 Google Cloud project initialization completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Update the project_id and region in the appropriate files: ./infrastructure/deploy-new-project-id.sh"
    echo "2. Run the complete deployment: ./infrastructure/deploy-complete-oauth-v0.2.sh"
    echo ""
}

# Run main function with all arguments
main "$@"
