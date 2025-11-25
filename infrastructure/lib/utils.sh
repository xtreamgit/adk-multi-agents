#!/bin/bash
#
# utils.sh - Common utilities and helper functions
#

# Color codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Display banner
show_banner() {
    clear
    echo -e "${MAGENTA}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     ADK RAG AGENT - COMPLETE DEPLOYMENT PIPELINE              ║
║                                                               ║
║     Modular Cloud Run + Load Balancer + IAP                   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if resource exists (returns 0 if exists, 1 if not)
resource_exists() {
    local check_command="$1"
    if eval "$check_command" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Wait for resource to be ready
wait_for_resource() {
    local check_command="$1"
    local resource_name="$2"
    local timeout="${3:-300}" # default 5 minutes
    local interval=10
    local elapsed=0
    
    log_info "Waiting for $resource_name to be ready..."
    while [ $elapsed -lt $timeout ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            log_success "$resource_name is ready"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    log_error "$resource_name not ready after ${timeout}s"
    return 1
}

# Confirm action
confirm_action() {
    local message="$1"
    read -p "$(echo -e ${YELLOW}${message} [y/N]:${NC} )" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Export functions for use in other scripts
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_section
export -f resource_exists
export -f wait_for_resource
