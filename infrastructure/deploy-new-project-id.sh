#!/bin/bash
#
# deploy-new-project-id.sh - Update Project IDs and Regions in ADK RAG Agent Files
#
# DESCRIPTION:
# ============
# This script efficiently updates hardcoded project IDs and regions in critical ADK RAG Agent files.
# It reads values from deployment.config file (created by deploy-init.sh) or accepts command-line
# arguments to override.
#
# USAGE:
# ======
# ./deploy-new-project-id.sh [NEW_PROJECT_ID] [NEW_REGION]
#
# EXAMPLES:
# =========
# # Use values from deployment.config (recommended)
# ./deploy-new-project-id.sh
#
# # Override with command-line arguments
# ./deploy-new-project-id.sh my-new-rag-project-2025
# ./deploy-new-project-id.sh my-new-rag-project-2025 us-east4
#
# FILES UPDATED:
# ==============
# - backend/src/rag_agent/agent.py (project ID + region)
# - backend/Dockerfile (project ID + region)
# - backend/src/rag_agent/config.py (project ID + region)
# - backend/cloudbuild.yaml (project ID + region)
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

# Function to load configuration from deployment.config
load_deployment_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${CYAN}📄 Loading configuration from $CONFIG_FILE${NC}"
        echo ""
        
        # Source the config file to load variables
        # shellcheck disable=SC1090
        source "$CONFIG_FILE" 2>/dev/null || true
        
        # Display loaded values
        if [[ -n "${PROJECT_ID:-}" ]]; then
            echo "  Project ID: $PROJECT_ID"
        fi
        if [[ -n "${REGION:-}" ]]; then
            echo "  Region: $REGION"
        fi
        
        echo -e "${GREEN}✅ Configuration loaded from file${NC}"
        echo ""
        return 0
    else
        echo -e "${YELLOW}⚠️  No deployment.config file found${NC}"
        echo "Run ./infrastructure/deploy-init.sh first to create configuration"
        echo ""
        return 1
    fi
}

# Function to display usage
show_usage() {
    echo -e "${BLUE}Usage: $0 [NEW_PROJECT_ID] [NEW_REGION]${NC}"
    echo ""
    echo -e "${YELLOW}Description:${NC}"
    echo "  Updates hardcoded project IDs and regions in ADK RAG Agent backend files"
    echo "  Reads from deployment.config by default, or accepts command-line overrides"
    echo ""
    echo -e "${YELLOW}Parameters:${NC}"
    echo "  NEW_PROJECT_ID    Optional. New Google Cloud project ID (overrides config file)"
    echo "  NEW_REGION        Optional. New Google Cloud region (overrides config file)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  # Use values from deployment.config (recommended)"
    echo "  $0"
    echo ""
    echo "  # Override project ID only"
    echo "  $0 my-new-rag-project-2025"
    echo ""
    echo "  # Override both project ID and region"
    echo "  $0 my-new-rag-project-2025 us-east4"
    echo ""
    echo -e "${YELLOW}Files that will be updated:${NC}"
    echo "  • backend/src/rag_agent/agent.py (project ID + region)"
    echo "  • backend/Dockerfile (project ID + region)"
    echo "  • backend/src/rag_agent/config.py (project ID + region)" 
    echo "  • backend/cloudbuild.yaml (project ID + region)"
    echo ""
}

# Function to validate project ID format
validate_project_id() {
    local project_id="$1"
    
    # Check format (6-30 characters, lowercase, numbers, hyphens)
    if [[ ! "$project_id" =~ ^[a-z0-9-]{6,30}$ ]]; then
        echo -e "${RED}❌ Invalid project ID format: $project_id${NC}"
        echo "Project ID must be:"
        echo "  • 6-30 characters long"
        echo "  • Lowercase letters, numbers, and hyphens only"
        echo "  • Cannot start or end with a hyphen"
        return 1
    fi
    
    # Check for consecutive hyphens
    if [[ "$project_id" =~ -- ]]; then
        echo -e "${RED}❌ Project ID cannot contain consecutive hyphens${NC}"
        return 1
    fi
    
    # Check start/end characters
    if [[ "$project_id" =~ ^- ]] || [[ "$project_id" =~ -$ ]]; then
        echo -e "${RED}❌ Project ID cannot start or end with a hyphen${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate region format
validate_region() {
    local region="$1"
    
    # Check basic region format (e.g., us-central1, us-east4, europe-west1)
    if [[ ! "$region" =~ ^[a-z]+-[a-z]+[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid region format: $region${NC}"
        echo "Region must be in format like: us-central1, us-east4, europe-west1"
        return 1
    fi
    
    return 0
}

# Function to backup files
backup_files() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="./backups/project_id_update_$timestamp"
    
    echo -e "${YELLOW}📦 Creating backup of files...${NC}"
    mkdir -p "$backup_dir"
    
    # Backup each file
    cp backend/src/rag_agent/agent.py "$backup_dir/agent.py.bak" 2>/dev/null || echo "  ⚠️  agent.py not found"
    cp backend/Dockerfile "$backup_dir/Dockerfile.bak" 2>/dev/null || echo "  ⚠️  Dockerfile not found"
    cp backend/src/rag_agent/config.py "$backup_dir/config.py.bak" 2>/dev/null || echo "  ⚠️  config.py not found"
    cp backend/cloudbuild.yaml "$backup_dir/cloudbuild.yaml.bak" 2>/dev/null || echo "  ⚠️  cloudbuild.yaml not found"
    
    echo -e "${GREEN}✅ Backup created in: $backup_dir${NC}"
    echo ""
}

# Function to find and display current project IDs and regions
find_current_project_ids() {
    echo -e "${CYAN}🔍 Scanning for current project IDs and regions...${NC}"
    echo ""
    
    local files=(
        "backend/src/rag_agent/agent.py"
        "backend/Dockerfile"
        "backend/src/rag_agent/config.py"
        "backend/cloudbuild.yaml"
    )
    
    local found_project_patterns=()
    local found_region_patterns=()
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            echo -e "${BLUE}📁 $file:${NC}"
            
            # Search for project ID patterns
            local project_patterns=(
                "adk-rag-[a-z0-9-]*"
                "[a-z0-9-]*-rag-[a-z0-9-]*"
                "PROJECT_ID.*[\"'][a-z0-9-]*[\"']"
                "VERTEXAI_PROJECT.*[\"'][a-z0-9-]*[\"']"
                "docker\.pkg\.dev/[a-z0-9-]*/"
            )
            
            # Search for region patterns
            local region_patterns=(
                "us-[a-z]+[0-9]+"
                "europe-[a-z]+[0-9]+"
                "asia-[a-z]+[0-9]+"
                "GOOGLE_CLOUD_LOCATION.*[\"'][a-z0-9-]*[\"']"
                "VERTEXAI_LOCATION.*[\"'][a-z0-9-]*[\"']"
                "[a-z0-9-]+-docker\.pkg\.dev"
            )
            
            # Find project ID matches
            for pattern in "${project_patterns[@]}"; do
                local matches=$(grep -oE "$pattern" "$file" 2>/dev/null || true)
                if [[ -n "$matches" ]]; then
                    while IFS= read -r match; do
                        echo "  → [PROJECT] $match"
                        found_project_patterns+=("$match")
                    done <<< "$matches"
                fi
            done
            
            # Find region matches
            for pattern in "${region_patterns[@]}"; do
                local matches=$(grep -oE "$pattern" "$file" 2>/dev/null || true)
                if [[ -n "$matches" ]]; then
                    while IFS= read -r match; do
                        echo "  → [REGION] $match"
                        found_region_patterns+=("$match")
                    done <<< "$matches"
                fi
            done
            echo ""
        else
            echo -e "${YELLOW}⚠️  File not found: $file${NC}"
        fi
    done
    
    # Show unique project patterns found
    if [[ ${#found_project_patterns[@]} -gt 0 ]]; then
        echo -e "${YELLOW}📋 Unique project ID patterns found:${NC}"
        printf '%s\n' "${found_project_patterns[@]}" | sort -u | while read -r pattern; do
            echo "  • $pattern"
        done
        echo ""
    fi
    
    # Show unique region patterns found
    if [[ ${#found_region_patterns[@]} -gt 0 ]]; then
        echo -e "${YELLOW}📋 Unique region patterns found:${NC}"
        printf '%s\n' "${found_region_patterns[@]}" | sort -u | while read -r pattern; do
            echo "  • $pattern"
        done
        echo ""
    fi
}

# Function to update project IDs and regions in files
update_project_ids() {
    local new_project_id="$1"
    local new_region="$2"
    
    echo -e "${CYAN}🔄 Updating project IDs to: ${BOLD}$new_project_id${NC}"
    echo -e "${CYAN}🔄 Updating regions to: ${BOLD}$new_region${NC}"
    echo ""
    
    # Define files to update
    local files=(
        "backend/src/rag_agent/agent.py"
        "backend/Dockerfile"
        "backend/src/rag_agent/config.py"
        "backend/cloudbuild.yaml"
    )
    
    # Also do a general replacement for common patterns
    local common_patterns=(
        "adk-rag-agent-2025"
        "adk-rag-hdtest4" 
        "adk-rag-hdtest3"
        "adk-rag-hdtest2"
        "adk-rag-hdtest1"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            echo -e "${BLUE}📝 Updating $file...${NC}"
            
            # Apply file-specific patterns
            case "$file" in
                "backend/src/rag_agent/agent.py")
                    # Update project ID patterns
                    sed -i.tmp 's/"PROJECT_ID",[[:space:]]*"[^"]*"/"PROJECT_ID", "'$new_project_id'"/g' "$file"
                    # Update region patterns
                    sed -i.tmp 's/"GOOGLE_CLOUD_LOCATION",[[:space:]]*"[^"]*"/"GOOGLE_CLOUD_LOCATION", "'$new_region'"/g' "$file"
                    ;;
                "backend/Dockerfile")
                    # Update project ID patterns
                    sed -i.tmp 's/ENV PROJECT_ID=.*/ENV PROJECT_ID='$new_project_id'/g' "$file"
                    sed -i.tmp 's/ENV VERTEXAI_PROJECT=.*/ENV VERTEXAI_PROJECT='$new_project_id'/g' "$file"
                    # Update region patterns
                    sed -i.tmp 's/ENV GOOGLE_CLOUD_LOCATION=.*/ENV GOOGLE_CLOUD_LOCATION='$new_region'/g' "$file"
                    sed -i.tmp 's/ENV VERTEXAI_LOCATION=.*/ENV VERTEXAI_LOCATION='$new_region'/g' "$file"
                    ;;
                "backend/src/rag_agent/config.py")
                    # Update project ID patterns
                    sed -i.tmp 's/"PROJECT_ID",[[:space:]]*"[^"]*"/"PROJECT_ID", "'$new_project_id'"/g' "$file"
                    # Update region patterns
                    sed -i.tmp 's/"GOOGLE_CLOUD_LOCATION",[[:space:]]*"[^"]*"/"GOOGLE_CLOUD_LOCATION", "'$new_region'"/g' "$file"
                    ;;
                "backend/cloudbuild.yaml")
                    # Update both project ID and region in docker registry URL
                    sed -i.tmp 's|[a-z0-9-]*-docker\.pkg\.dev/[^/]*/|'$new_region'-docker.pkg.dev/'$new_project_id'/|g' "$file"
                    ;;
            esac
            
            # Apply common pattern replacements
            for pattern in "${common_patterns[@]}"; do
                sed -i.tmp "s/$pattern/$new_project_id/g" "$file"
            done
            
            # Remove temporary file
            rm -f "$file.tmp"
            
            echo -e "${GREEN}  ✅ Updated successfully${NC}"
        else
            echo -e "${YELLOW}  ⚠️  File not found: $file${NC}"
        fi
    done
    
    echo ""
}

# Function to verify updates
verify_updates() {
    local new_project_id="$1"
    
    echo -e "${CYAN}🔍 Verifying updates...${NC}"
    echo ""
    
    local files=(
        "backend/src/rag_agent/agent.py"
        "backend/Dockerfile"
        "backend/src/rag_agent/config.py"
        "backend/cloudbuild.yaml"
    )
    
    local all_good=true
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            echo -e "${BLUE}📁 $file:${NC}"
            
            # Check if new project ID is present
            if grep -q "$new_project_id" "$file"; then
                echo -e "${GREEN}  ✅ Contains new project ID: $new_project_id${NC}"
            else
                echo -e "${RED}  ❌ New project ID not found${NC}"
                all_good=false
            fi
            
            # Check for old patterns that might remain (avoid false positives)
            # Skip this check if new project ID matches old patterns
            if [[ ! "$new_project_id" =~ adk-rag-hdtest ]]; then
                local old_patterns=("adk-rag-agent-2025" "adk-rag-hdtest[0-5]")
                for pattern in "${old_patterns[@]}"; do
                    if grep -qE "$pattern" "$file"; then
                        echo -e "${YELLOW}  ⚠️  Old pattern still found: $pattern${NC}"
                        all_good=false
                    fi
                done
            fi
            echo ""
        fi
    done
    
    if [[ "$all_good" == "true" ]]; then
        echo -e "${GREEN}🎉 All files updated successfully!${NC}"
    else
        echo -e "${YELLOW}⚠️  Some issues detected. Please review the files manually.${NC}"
    fi
}

# Main function
main() {
    echo -e "${BLUE}🔧 ADK RAG Agent - Project ID & Region Updater${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
    
    # Check for help flag first
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Try to load from config file first
    local config_loaded=false
    if load_deployment_config; then
        config_loaded=true
    fi
    
    # Get values from arguments or config file
    local new_project_id="${1:-${PROJECT_ID:-}}"
    local new_region="${2:-${REGION:-us-central1}}"
    
    # Validate we have required values
    if [[ -z "$new_project_id" ]]; then
        echo -e "${RED}❌ Error: No project ID found${NC}"
        echo "Either:"
        echo "  1. Run ./infrastructure/deploy-init.sh first to create deployment.config"
        echo "  2. Provide project ID as argument: $0 PROJECT_ID [REGION]"
        echo ""
        show_usage
        exit 1
    fi
    
    # Show source of values
    if [[ $# -gt 0 ]]; then
        echo -e "${YELLOW}Using command-line arguments (overriding config file)${NC}"
        echo ""
    elif [[ "$config_loaded" == "true" ]]; then
        echo -e "${GREEN}Using values from deployment.config${NC}"
        echo ""
    fi
    
    # Validate project ID
    if ! validate_project_id "$new_project_id"; then
        exit 1
    fi
    
    # Validate region
    if ! validate_region "$new_region"; then
        exit 1
    fi
    
    echo -e "${GREEN}✅ Project ID format is valid: $new_project_id${NC}"
    echo -e "${GREEN}✅ Region format is valid: $new_region${NC}"
    echo ""
    
    # Check if we're in the right directory
    if [[ ! -d "backend" ]] || [[ ! -d "infrastructure" ]]; then
        echo -e "${RED}❌ Error: Please run this script from the project root directory${NC}"
        echo "Expected directory structure:"
        echo "  • backend/"
        echo "  • infrastructure/"
        exit 1
    fi
    
    # Show current project IDs
    find_current_project_ids
    
    # Confirm with user
    echo -e "${YELLOW}❓ Do you want to update all values to:${NC}"
    echo -e "${YELLOW}   Project ID: ${BOLD}$new_project_id${NC}"
    echo -e "${YELLOW}   Region: ${BOLD}$new_region${NC}${YELLOW}?${NC}"
    read -p "Enter 'yes' to continue or 'no' to cancel: " confirm
    
    case $confirm in
        [Yy]es|[Yy])
            echo -e "${GREEN}✅ Proceeding with update...${NC}"
            echo ""
            ;;
        *)
            echo -e "${YELLOW}❌ Update cancelled${NC}"
            exit 0
            ;;
    esac
    
    # Create backup
    backup_files
    
    # Update project IDs and regions
    update_project_ids "$new_project_id" "$new_region"
    
    # Verify updates
    verify_updates "$new_project_id"
    
    echo ""
    echo -e "${GREEN}🎯 Project ID update completed!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Review the updated files to ensure correctness"
    echo "2. Run: ./infrastructure/deploy-complete-oauth-v0.2.sh"
    echo ""
}

# Run main function with all arguments
main "$@"
