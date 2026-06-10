#!/bin/bash
#
# pre-deploy-check.sh - Pre-deployment environment audit
#
# DESCRIPTION:
# ============
# Scans the target GCP project for existing resources that the ADK RAG Agent
# deployment scripts would create or modify. Produces a report showing what
# already exists so the operator can decide whether to proceed, skip, or abort.
#
# This script is READ-ONLY. It never creates, modifies, or deletes anything.
#
# USAGE:
# ======
# ./infrastructure/pre-deploy-check.sh [--project-id=ID] [--region=REGION]
#
# If deployment.config exists it will be sourced automatically.
# Command-line flags override config file values.
#

set -uo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ── Counters ────────────────────────────────────────────────────────────────
TOTAL_CHECKS=0
CONFLICTS=0
WARNINGS=0
CLEAN=0

# ── Table tracking ──────────────────────────────────────────────────────────
# Each entry: "CATEGORY|RESOURCE|STATUS|DETAIL"
declare -a TABLE_ROWS=()
CURRENT_CATEGORY=""

add_row() {
    # Usage: add_row "resource_name" "status" "detail"
    TABLE_ROWS+=("${CURRENT_CATEGORY}|${1}|${2}|${3}")
}

# ── Output helpers ──────────────────────────────────────────────────────────
header()  {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    # Extract category name (strip leading number + dot)
    CURRENT_CATEGORY=$(echo "$1" | sed 's/^[0-9]*\. //')
}
ok() {
    echo -e "  ${GREEN}✅ $1${NC}"
    add_row "$1" "CLEAN" "-"
    ((CLEAN++)); ((TOTAL_CHECKS++))
}
conflict() {
    echo -e "  ${RED}⚠️  CONFLICT: $1${NC}"
    add_row "$1" "CONFLICT" "${2:-Exists}"
    ((CONFLICTS++)); ((TOTAL_CHECKS++))
}
warn() {
    echo -e "  ${YELLOW}⚠️  WARNING: $1${NC}"
    add_row "$1" "WARNING" "${2:-Review needed}"
    ((WARNINGS++)); ((TOTAL_CHECKS++))
}
info()    { echo -e "  ${BLUE}ℹ️  $1${NC}"; }
detail()  { echo -e "     $1"; }

# ── Table renderer ──────────────────────────────────────────────────────────
print_summary_table() {
    # Column widths
    local CAT_W=24
    local RES_W=38
    local STA_W=10
    local DET_W=34
    local TOTAL_W=$((CAT_W + RES_W + STA_W + DET_W + 13))  # 13 = separators + padding

    local HLINE=$(printf '─%.0s' $(seq 1 $TOTAL_W))
    local DLINE=$(printf '═%.0s' $(seq 1 $TOTAL_W))

    echo ""
    echo -e "${BOLD}${MAGENTA}╔${DLINE}╗${NC}"
    printf "${BOLD}${MAGENTA}║${NC} ${BOLD}%-${CAT_W}s │ %-${RES_W}s │ %-${STA_W}s │ %-${DET_W}s${NC} ${BOLD}${MAGENTA}║${NC}\n" \
        "CATEGORY" "RESOURCE" "STATUS" "DETAIL"
    echo -e "${BOLD}${MAGENTA}╠${DLINE}╣${NC}"

    local PREV_CAT=""
    for row in "${TABLE_ROWS[@]}"; do
        IFS='|' read -r cat res status det <<< "$row"

        # Truncate fields to column widths
        cat="${cat:0:$CAT_W}"
        res="${res:0:$RES_W}"
        det="${det:0:$DET_W}"

        # Print category separator when category changes
        if [[ "$cat" != "$PREV_CAT" && -n "$PREV_CAT" ]]; then
            echo -e "${MAGENTA}╟${HLINE}╢${NC}"
        fi

        # Show category only on first row of each group
        local DISPLAY_CAT=""
        if [[ "$cat" != "$PREV_CAT" ]]; then
            DISPLAY_CAT="$cat"
        fi
        PREV_CAT="$cat"

        # Color the status
        local STATUS_COLOR=""
        case "$status" in
            CLEAN)    STATUS_COLOR="${GREEN}${status}${NC}"  ;;
            CONFLICT) STATUS_COLOR="${RED}${status}${NC}"    ;;
            WARNING)  STATUS_COLOR="${YELLOW}${status}${NC}"  ;;
            *)        STATUS_COLOR="$status"                 ;;
        esac

        # printf with color requires careful handling — pad status manually
        local STATUS_PAD=$((STA_W - ${#status}))
        local STATUS_PADDED="${STATUS_COLOR}$(printf '%*s' $STATUS_PAD '')"

        printf "${MAGENTA}║${NC} %-${CAT_W}s │ %-${RES_W}s │ %b │ %-${DET_W}s ${MAGENTA}║${NC}\n" \
            "$DISPLAY_CAT" "$res" "$STATUS_PADDED" "$det"
    done

    echo -e "${BOLD}${MAGENTA}╚${DLINE}╝${NC}"
    echo ""
    echo -e "  ${BOLD}Total: $TOTAL_CHECKS${NC}  │  ${GREEN}Clean: $CLEAN${NC}  │  ${RED}Conflicts: $CONFLICTS${NC}  │  ${YELLOW}Warnings: $WARNINGS${NC}"
}

# ── Parse arguments ─────────────────────────────────────────────────────────
CLI_PROJECT_ID=""
CLI_REGION=""
REPORT_FILE=""

for arg in "$@"; do
    case "$arg" in
        --project-id=*) CLI_PROJECT_ID="${arg#*=}" ;;
        --region=*)     CLI_REGION="${arg#*=}" ;;
        --report=*)     REPORT_FILE="${arg#*=}" ;;
        --help|-h)
            echo "Usage: $0 [--project-id=ID] [--region=REGION] [--report=FILE]"
            echo ""
            echo "Scans the target GCP project for existing resources that would"
            echo "conflict with the ADK RAG Agent deployment."
            echo ""
            echo "Options:"
            echo "  --project-id=ID   GCP project to scan (overrides deployment.config)"
            echo "  --region=REGION   GCP region to scan (overrides deployment.config)"
            echo "  --report=FILE     Write plain-text report to FILE"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
    esac
done

# ── Load config (safe parse — NO sourcing) ───────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/deployment.config"

# Extract only simple export VAR="value" lines — never execute gcloud or echo
CONFIG_PROJECT_ID=""
CONFIG_REGION=""
CONFIG_REPO=""
CONFIG_ORG_DOMAIN=""
CONFIG_IAP_ADMIN=""
CONFIG_ACCOUNT_ENV=""

if [[ -f "$CONFIG_FILE" ]]; then
    # Read uncommented lines with simple string values (with or without 'export')
    CONFIG_PROJECT_ID=$(grep -E '^\s*(export\s+)?PROJECT_ID=' "$CONFIG_FILE" | grep -v '^\s*#' | tail -1 | sed 's/.*="\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
    CONFIG_REGION=$(grep -E '^\s*(export\s+)?REGION=' "$CONFIG_FILE" | grep -v '^\s*#' | tail -1 | sed 's/.*="\{0,1\}\([^"]*\)"\{0,1\}/\1/' | sed 's/#.*//' | xargs)
    CONFIG_REPO=$(grep -E '^\s*(export\s+)?REPO=' "$CONFIG_FILE" | grep -v '^\s*#' | tail -1 | sed 's/.*="\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
    CONFIG_ORG_DOMAIN=$(grep -E '^\s*(export\s+)?ORGANIZATION_DOMAIN=' "$CONFIG_FILE" | grep -v '^\s*#' | tail -1 | sed 's/.*="\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
    CONFIG_IAP_ADMIN=$(grep -E '^\s*(export\s+)?IAP_ADMIN_USER=' "$CONFIG_FILE" | grep -v '^\s*#' | tail -1 | sed 's/.*="\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
    CONFIG_ACCOUNT_ENV=$(grep -E '^\s*(export\s+)?ACCOUNT_ENV=' "$CONFIG_FILE" | grep -v '^\s*#' | tail -1 | sed 's/.*="\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
    echo -e "${BOLD}Values from deployment.config:${NC}"
    echo -e "  PROJECT_ID : ${CONFIG_PROJECT_ID:-<not set>}"
    echo -e "  REGION     : ${CONFIG_REGION:-<not set>}"
    echo -e "  REPO       : ${CONFIG_REPO:-<not set>}"
    echo -e "  ACCOUNT_ENV: ${CONFIG_ACCOUNT_ENV:-<not set>}"
else
    echo -e "${YELLOW}⚠️  deployment.config not found — will use gcloud config or CLI flags${NC}"
fi

# Start with config values (may be overridden below)
PROJECT_ID="${CONFIG_PROJECT_ID:-}"
REGION="${CONFIG_REGION:-}"
REPO="${CONFIG_REPO:-cloud-run-repo1}"

# CLI overrides take priority over deployment.config
[[ -n "$CLI_PROJECT_ID" ]] && PROJECT_ID="$CLI_PROJECT_ID"
[[ -n "$CLI_REGION" ]]     && REGION="$CLI_REGION"

# ── Verify gcloud config vs deployment.config ────────────────────────────────
GCLOUD_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
GCLOUD_ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "")
GCLOUD_REGION=$(gcloud config get-value compute/region 2>/dev/null || echo "(not set)")

echo ""
echo -e "${BOLD}Current gcloud configuration:${NC}"
echo -e "  Account  : ${CYAN}${GCLOUD_ACCOUNT:-<none>}${NC}"
echo -e "  Project  : ${CYAN}${GCLOUD_PROJECT:-<none>}${NC}"
echo -e "  Region   : ${CYAN}${GCLOUD_REGION}${NC}"
echo ""

if [[ -z "$GCLOUD_ACCOUNT" ]]; then
    echo -e "${RED}❌ Not authenticated with gcloud. Run: gcloud auth login${NC}"
    exit 1
fi

CONFIG_PROJECT="${PROJECT_ID:-}"

if [[ -n "$CLI_PROJECT_ID" ]]; then
    # CLI flag takes highest priority — no prompt needed
    echo -e "${GREEN}✅ Using CLI-provided project: ${PROJECT_ID}${NC}"
    gcloud config set project "$PROJECT_ID" --quiet 2>/dev/null
elif [[ -n "$CONFIG_PROJECT" && "$GCLOUD_PROJECT" != "$CONFIG_PROJECT" ]]; then
    echo -e "${YELLOW}⚠️  Mismatch detected:${NC}"
    echo -e "     gcloud project      : ${CYAN}${GCLOUD_PROJECT:-<none>}${NC}"
    echo -e "     deployment.config   : ${CYAN}${CONFIG_PROJECT}${NC}"
    echo ""
    echo -e "  ${YELLOW}This usually means deployment.config has values from a previous${NC}"
    echo -e "  ${YELLOW}environment and needs to be regenerated for the new project.${NC}"
    echo -e "  ${YELLOW}Run: python backend/deploy_env_config.py <new-client>.yaml${NC}"
    echo ""
    echo -e "  ${BOLD}Which project should this scan target?${NC}"
    echo -e "  ${BOLD}[1]${NC} Use gcloud project '${GCLOUD_PROJECT}' (current environment)"
    echo -e "  ${BOLD}[2]${NC} Use deployment.config project '${CONFIG_PROJECT}' (previous environment)"
    echo -e "  ${BOLD}[3]${NC} Enter a different project ID"
    echo -e "  ${BOLD}[4]${NC} Abort"
    echo ""
    read -rp "  Choose [1/2/3/4]: " CHOICE
    case "$CHOICE" in
        1)
            PROJECT_ID="$GCLOUD_PROJECT"
            echo -e "  ${GREEN}✅ Scanning gcloud project: '$PROJECT_ID'${NC}"
            ;;
        2)
            PROJECT_ID="$CONFIG_PROJECT"
            gcloud config set project "$PROJECT_ID" --quiet 2>/dev/null
            echo -e "  ${GREEN}✅ Scanning deployment.config project: '$PROJECT_ID'${NC}"
            ;;
        3)
            read -rp "  Enter project ID: " NEW_PROJECT
            if [[ -z "$NEW_PROJECT" ]]; then
                echo -e "  ${RED}No project entered. Aborting.${NC}"
                exit 1
            fi
            PROJECT_ID="$NEW_PROJECT"
            gcloud config set project "$PROJECT_ID" --quiet 2>/dev/null
            echo -e "  ${GREEN}✅ Scanning project: '$PROJECT_ID'${NC}"
            ;;
        4|*)
            echo -e "  ${YELLOW}Aborted by user.${NC}"
            exit 0
            ;;
    esac
    echo ""
elif [[ -z "$CONFIG_PROJECT" && -n "$GCLOUD_PROJECT" ]]; then
    # No deployment.config — use gcloud project
    PROJECT_ID="$GCLOUD_PROJECT"
    echo -e "${GREEN}✅ No deployment.config found. Using gcloud project: ${PROJECT_ID}${NC}"
elif [[ -z "$CONFIG_PROJECT" && -z "$GCLOUD_PROJECT" ]]; then
    echo -e "${RED}❌ No project configured. Set via gcloud or --project-id=ID${NC}"
    exit 1
else
    echo -e "${GREEN}✅ gcloud and deployment.config agree: ${PROJECT_ID}${NC}"
fi

# ── Validate REGION ──────────────────────────────────────────────────────────
if [[ -z "${REGION:-}" ]]; then
    # Try gcloud compute/region as fallback
    if [[ "$GCLOUD_REGION" != "(not set)" && -n "$GCLOUD_REGION" ]]; then
        REGION="$GCLOUD_REGION"
        echo -e "${GREEN}✅ Using gcloud region: ${REGION}${NC}"
    else
        read -rp "  Enter target region (e.g. us-west1): " REGION
        if [[ -z "$REGION" ]]; then
            echo -e "${RED}❌ REGION is required. Aborting.${NC}"
            exit 1
        fi
    fi
fi

# ── Lock in the resolved project ─────────────────────────────────────────────
# From this point forward, PROJECT_ID and REGION are the confirmed targets.
# Set gcloud config so any implicit gcloud calls also use the right project.
gcloud config set project "$PROJECT_ID" --quiet 2>/dev/null

echo ""
echo -e "${BOLD}${CYAN}┌──────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}${CYAN}│  SCAN TARGET (confirmed)                             │${NC}"
echo -e "${BOLD}${CYAN}│  Project : ${PROJECT_ID}$(printf '%*s' $((38 - ${#PROJECT_ID})) '')│${NC}"
echo -e "${BOLD}${CYAN}│  Region  : ${REGION}$(printf '%*s' $((38 - ${#REGION})) '')│${NC}"
echo -e "${BOLD}${CYAN}│  Repo    : ${REPO}$(printf '%*s' $((38 - ${#REPO})) '')│${NC}"
echo -e "${BOLD}${CYAN}└──────────────────────────────────────────────────────┘${NC}"
echo ""

# ── Start report (optionally tee to file) ──────────────────────────────────────
if [[ -n "$REPORT_FILE" ]]; then
    # Tee to file, stripping ANSI color codes from the file copy
    exec > >(tee >(sed 's/\x1b\[[0-9;]*m//g' > "$REPORT_FILE")) 2>&1
fi

echo -e "${MAGENTA}"
cat << "BANNER"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     ADK RAG AGENT — PRE-DEPLOYMENT ENVIRONMENT CHECK          ║
║                                                               ║
║     Read-only scan · No resources will be modified            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${BOLD}Target environment:${NC}"
echo "  Project ID : $PROJECT_ID"
echo "  Region     : $REGION"
echo "  Repo       : $REPO"
echo "  Scan time  : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# ── Verify project access ─────────────────────────────────────────────────
header "0. Project Access"

info "Authenticated as: $GCLOUD_ACCOUNT"
info "Target project: $PROJECT_ID"

# Check project exists and is accessible
if gcloud projects describe "$PROJECT_ID" --format="value(projectId)" >/dev/null 2>&1; then
    PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)" 2>/dev/null)
    info "Project exists — number: $PROJECT_NUMBER"
else
    ok "Project '$PROJECT_ID' does not exist yet (clean slate)"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  RESULT: Project does not exist. Safe to proceed with deploy-init.sh${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
fi

###############################################################################
# 1. ENABLED APIs
###############################################################################
header "1. Enabled APIs"

REQUIRED_APIS=(
    run.googleapis.com
    artifactregistry.googleapis.com
    cloudbuild.googleapis.com
    compute.googleapis.com
    iap.googleapis.com
    dns.googleapis.com
    iam.googleapis.com
    cloudresourcemanager.googleapis.com
    cloudidentity.googleapis.com
    aiplatform.googleapis.com
    storage.googleapis.com
    bigquery.googleapis.com
    sqladmin.googleapis.com
    secretmanager.googleapis.com
)

ENABLED_APIS=$(gcloud services list --enabled --project="$PROJECT_ID" --format="value(name)" 2>/dev/null || echo "")

for api in "${REQUIRED_APIS[@]}"; do
    # Shorten API name for table: strip .googleapis.com suffix
    api_short=$(echo "$api" | sed 's/\.googleapis\.com$//')
    # Match API name in the full path format: projects/NUMBER/services/API_NAME
    if echo "$ENABLED_APIS" | grep -q "/${api}$"; then
        ok "API '$api_short' — already enabled"
    else
        conflict "API '$api_short' NOT enabled" "Will be enabled by deploy-init.sh"
    fi
done

###############################################################################
# 2. ARTIFACT REGISTRY
###############################################################################
header "2. Artifact Registry"

if gcloud artifacts repositories describe "$REPO" --project="$PROJECT_ID" --location="$REGION" --format="value(name)" >/dev/null 2>&1; then
    conflict "Repo '$REPO' exists in $REGION" "Has images"
    # List images inside
    IMAGES=$(gcloud artifacts docker images list "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO" --project="$PROJECT_ID" --format="value(package)" 2>/dev/null || echo "")
    if [[ -n "$IMAGES" ]]; then
        detail "Existing images:"
        echo "$IMAGES" | while read -r img; do detail "  - $img"; done
    fi
else
    ok "Repo '$REPO' — not found"
fi

###############################################################################
# 3. SERVICE ACCOUNTS
###############################################################################
header "3. Service Accounts"

SA_NAMES=(
    "backend-sa"
    "frontend-sa"
    "adk-rag-agent-sa"
    "iap-accessor"
    "adk-rag-agent1-sa"
    "adk-rag-agent2-sa"
    "adk-rag-agent3-sa"
)

for sa_short in "${SA_NAMES[@]}"; do
    sa_full="${sa_short}@${PROJECT_ID}.iam.gserviceaccount.com"
    if gcloud iam service-accounts describe "$sa_full" --project="$PROJECT_ID" --format="value(email)" >/dev/null 2>&1; then
        conflict "SA '$sa_short' exists" "$sa_full"
    else
        ok "SA '$sa_short' — not found"
    fi
done

###############################################################################
# 4. CLOUD RUN SERVICES
###############################################################################
header "4. Cloud Run Services"

CR_SERVICES=(
    "backend"
    "backend-agent1"
    "backend-agent2"
    "backend-agent3"
    "frontend"
)

EXISTING_CR=$(gcloud run services list --project="$PROJECT_ID" --region="$REGION" --format="value(metadata.name)" 2>/dev/null || echo "")

for svc in "${CR_SERVICES[@]}"; do
    if echo "$EXISTING_CR" | grep -q "^${svc}$"; then
        conflict "Service '$svc' exists" "Deployed in $REGION"
        URL=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(status.url)" 2>/dev/null || echo "unknown")
        detail "URL: $URL"
    else
        ok "Service '$svc' — not found"
    fi
done

# Check for OTHER Cloud Run services that are NOT ours
OTHER_CR=$(echo "$EXISTING_CR" | grep -v -E "^(backend|backend-agent1|backend-agent2|backend-agent3|frontend)$" || true)
if [[ -n "$OTHER_CR" ]]; then
    warn "Other services in $REGION (not ours)" "Not managed by this app"
    echo "$OTHER_CR" | while read -r svc; do
        detail "  - $svc"
    done
fi

###############################################################################
# 5. CLOUD SQL INSTANCES
###############################################################################
header "5. Cloud SQL Instances"

EXISTING_SQL=$(gcloud sql instances list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null || echo "")

if [[ -n "$EXISTING_SQL" ]]; then
    warn "Cloud SQL instances found" "Review instances below"
    echo "$EXISTING_SQL" | while read -r inst; do
        INST_REGION=$(gcloud sql instances describe "$inst" --project="$PROJECT_ID" --format="value(region)" 2>/dev/null || echo "unknown")
        INST_VERSION=$(gcloud sql instances describe "$inst" --project="$PROJECT_ID" --format="value(databaseVersion)" 2>/dev/null || echo "unknown")
        INST_STATE=$(gcloud sql instances describe "$inst" --project="$PROJECT_ID" --format="value(state)" 2>/dev/null || echo "unknown")
        detail "  - $inst  (region=$INST_REGION, version=$INST_VERSION, state=$INST_STATE)"
    done
    
    # Check for databases inside each instance
    echo "$EXISTING_SQL" | while read -r inst; do
        DBS=$(gcloud sql databases list --instance="$inst" --project="$PROJECT_ID" --format="value(name)" 2>/dev/null || echo "")
        if echo "$DBS" | grep -q "adk_agents_db"; then
            detail "  ⚠️  Instance '$inst' already has database 'adk_agents_db'"
        fi
    done
else
    ok "No Cloud SQL instances"
fi

###############################################################################
# 6. SECRET MANAGER
###############################################################################
header "6. Secret Manager"

EXISTING_SECRETS=$(gcloud secrets list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null || echo "")

EXPECTED_SECRETS=("db-password")

for secret in "${EXPECTED_SECRETS[@]}"; do
    if echo "$EXISTING_SECRETS" | grep -q "^${secret}$"; then
        conflict "Secret '$secret' exists" "In Secret Manager"
    else
        ok "Secret '$secret' — not found"
    fi
done

if [[ -n "$EXISTING_SECRETS" ]]; then
    OTHER_SECRETS=$(echo "$EXISTING_SECRETS" | grep -v -E "^(db-password)$" || true)
    if [[ -n "$OTHER_SECRETS" ]]; then
        info "Other secrets in project (not managed by this app):"
        echo "$OTHER_SECRETS" | while read -r s; do detail "  - $s"; done
    fi
fi

###############################################################################
# 7. GCS BUCKETS
###############################################################################
header "7. GCS Buckets"

EXISTING_BUCKETS=$(gsutil ls -p "$PROJECT_ID" 2>/dev/null | sed 's|gs://||;s|/||' || echo "")

if [[ -n "$EXISTING_BUCKETS" ]]; then
    warn "GCS buckets found in project" "See bucket list below"
    echo "$EXISTING_BUCKETS" | while read -r bucket; do
        # Get bucket location
        BUCKET_LOC=$(gsutil ls -L -b "gs://$bucket/" 2>/dev/null | grep "Location constraint:" | awk '{print $NF}' || echo "unknown")
        
        # Sample bucket contents to identify type (check first 20 files)
        BUCKET_SAMPLE=$(gsutil ls "gs://$bucket/**" 2>/dev/null | head -20)
        
        if [[ -z "$BUCKET_SAMPLE" ]]; then
            # Empty bucket or only directories
            detail "  - gs://$bucket/  (location: $BUCKET_LOC, type: Empty or directories only)"
        else
            # Count file types
            TOTAL_SAMPLE=$(echo "$BUCKET_SAMPLE" | wc -l | xargs)
            PDF_MATCHES=$(echo "$BUCKET_SAMPLE" | grep '\.pdf$' 2>/dev/null || true)
            SQL_MATCHES=$(echo "$BUCKET_SAMPLE" | grep '\.sql$' 2>/dev/null || true)
            
            # Count matches (empty string = 0, otherwise count lines)
            if [[ -z "$PDF_MATCHES" ]]; then
                PDF_COUNT=0
            else
                PDF_COUNT=$(echo "$PDF_MATCHES" | wc -l | xargs)
            fi
            
            if [[ -z "$SQL_MATCHES" ]]; then
                SQL_COUNT=0
            else
                SQL_COUNT=$(echo "$SQL_MATCHES" | wc -l | xargs)
            fi
            
            # Get total object count (more accurate but slower)
            TOTAL_OBJECTS=$(gsutil ls -r "gs://$bucket/**" 2>/dev/null | grep -v ':$' | wc -l | xargs)
            
            # Determine bucket type
            BUCKET_TYPE="Mixed content"
            if [[ $PDF_COUNT -gt 0 ]] && [[ $PDF_COUNT -eq $TOTAL_SAMPLE ]]; then
                BUCKET_TYPE="📚 PDF Collection (RAG corpus candidate)"
            elif [[ $PDF_COUNT -gt 0 ]] && [[ $PDF_COUNT -ge $((TOTAL_SAMPLE * 70 / 100)) ]]; then
                BUCKET_TYPE="📚 Mostly PDFs (${PDF_COUNT}/${TOTAL_SAMPLE} sampled)"
            elif echo "$bucket" | grep -q "cloudbuild"; then
                BUCKET_TYPE="🔧 Cloud Build artifacts"
            elif echo "$bucket" | grep -q "migration"; then
                BUCKET_TYPE="🗄️  Database migrations"
            elif echo "$bucket" | grep -q "run-sources"; then
                BUCKET_TYPE="🚀 Cloud Run sources"
            elif [[ "$SQL_COUNT" -gt 0 ]]; then
                BUCKET_TYPE="🗄️  SQL files"
            fi
            
            detail "  - gs://$bucket/  (location: $BUCKET_LOC)"
            detail "    Type: $BUCKET_TYPE"
            detail "    Objects: $TOTAL_OBJECTS total, sampled $TOTAL_SAMPLE (PDFs: $PDF_COUNT)"
        fi
    done
else
    ok "No GCS buckets found"
fi

###############################################################################
# 8. VERTEX AI CORPORA (RAG)
###############################################################################
header "8. Vertex AI RAG Corpora"

# Use REST API to list RAG corpora (gcloud CLI doesn't support this yet)
ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null)
if [[ -z "$ACCESS_TOKEN" ]]; then
    info "Could not get access token for Vertex AI API"
else
    CORPORA_JSON=$(curl -s "https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/ragCorpora" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" 2>/dev/null)
    
    # Check if API returned an error
    if echo "$CORPORA_JSON" | grep -q '"error"'; then
        ERROR_MSG=$(echo "$CORPORA_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error',{}).get('message','Unknown error'))" 2>/dev/null || echo "API error")
        info "Could not list RAG corpora: $ERROR_MSG"
    else
        # Parse corpora count
        CORPUS_COUNT=$(echo "$CORPORA_JSON" | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data.get('ragCorpora',[])))" 2>/dev/null || echo "0")
        
        if [[ "$CORPUS_COUNT" -eq 0 ]]; then
            ok "No RAG corpora in $REGION"
        else
            warn "RAG corpora found in $REGION" "$CORPUS_COUNT corpora exist"
            
            # Extract and display corpus details
            echo "$CORPORA_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for corpus in data.get('ragCorpora', []):
    name = corpus.get('name', '')
    corpus_id = name.split('/')[-1] if name else 'unknown'
    display_name = corpus.get('displayName', 'unnamed')
    status = corpus.get('corpusStatus', {}).get('state', 'UNKNOWN')
    created = corpus.get('createTime', 'unknown')[:10]  # Just date part
    print(f'{display_name}|{corpus_id}|{status}|{created}')
" 2>/dev/null | while IFS='|' read -r display_name corpus_id status created; do
                detail "  - $display_name (ID: $corpus_id, Status: $status, Created: $created)"
                
                # Fetch additional details for each corpus
                CORPUS_DETAIL=$(curl -s "https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/ragCorpora/${corpus_id}" \
                    -H "Authorization: Bearer ${ACCESS_TOKEN}" 2>/dev/null)
                
                # Extract embedding model
                EMBEDDING_MODEL=$(echo "$CORPUS_DETAIL" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    endpoint = data.get('vectorDbConfig', {}).get('ragEmbeddingModelConfig', {}).get('vertexPredictionEndpoint', {}).get('endpoint', '')
    model = endpoint.split('/')[-1] if endpoint else 'unknown'
    print(model)
except:
    print('unknown')
" 2>/dev/null)
                detail "    Embedding model: $EMBEDDING_MODEL"
            done
        fi
    fi
fi

###############################################################################
# 9. LOAD BALANCER COMPONENTS
###############################################################################
header "9. Load Balancer"

# Static IP
if gcloud compute addresses describe rag-agent-ip --global --project="$PROJECT_ID" --format="value(address)" >/dev/null 2>&1; then
    STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --project="$PROJECT_ID" --format="value(address)" 2>/dev/null)
    conflict "Static IP 'rag-agent-ip' exists" "$STATIC_IP"
else
    ok "Static IP 'rag-agent-ip' — not found"
fi

# SSL Certificate
if gcloud compute ssl-certificates describe rag-agent-ssl-cert --global --project="$PROJECT_ID" >/dev/null 2>&1; then
    SSL_STATUS=$(gcloud compute ssl-certificates describe rag-agent-ssl-cert --global --project="$PROJECT_ID" --format="value(managed.status)" 2>/dev/null || echo "unknown")
    conflict "SSL cert 'rag-agent-ssl-cert' exists" "Status: $SSL_STATUS"
else
    ok "SSL cert 'rag-agent-ssl-cert' — not found"
fi

# Network Endpoint Groups
NEGS=("frontend-neg" "backend-neg" "backend-agent1-neg" "backend-agent2-neg" "backend-agent3-neg")
for neg in "${NEGS[@]}"; do
    if gcloud compute network-endpoint-groups describe "$neg" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        conflict "NEG '$neg' exists" "In $REGION"
    else
        ok "NEG '$neg' — not found"
    fi
done

# Backend Services (LB)
LB_BACKENDS=("frontend-backend-service" "backend-backend-service" "backend-agent1-backend-service" "backend-agent2-backend-service" "backend-agent3-backend-service")
for bs in "${LB_BACKENDS[@]}"; do
    # Shorten name for display: remove "-backend-service" suffix
    bs_short=$(echo "$bs" | sed 's/-backend-service$//')
    if gcloud compute backend-services describe "$bs" --global --project="$PROJECT_ID" >/dev/null 2>&1; then
        conflict "LB backend '$bs_short' exists" "Global LB backend service"
    else
        ok "LB backend '$bs_short' — not found"
    fi
done

# URL Map
if gcloud compute url-maps describe rag-agent-url-map --global --project="$PROJECT_ID" >/dev/null 2>&1; then
    conflict "URL map 'rag-agent-url-map' exists" "Global"
else
    ok "URL map 'rag-agent-url-map' — not found"
fi

# HTTPS Proxy
if gcloud compute target-https-proxies describe rag-agent-https-proxy --global --project="$PROJECT_ID" >/dev/null 2>&1; then
    conflict "HTTPS proxy exists" "rag-agent-https-proxy"
else
    ok "HTTPS proxy — not found"
fi

# Forwarding Rule
if gcloud compute forwarding-rules describe rag-agent-forwarding-rule --global --project="$PROJECT_ID" >/dev/null 2>&1; then
    conflict "Forwarding rule exists" "rag-agent-forwarding-rule"
else
    ok "Forwarding rule — not found"
fi

# Check for OTHER load balancer resources not managed by us
OTHER_FORWARDING=$(gcloud compute forwarding-rules list --global --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | grep -v "rag-agent-forwarding-rule" || true)
if [[ -n "$OTHER_FORWARDING" ]]; then
    warn "Other forwarding rules found" "Not managed by this app"
    echo "$OTHER_FORWARDING" | while read -r fr; do detail "  - $fr"; done
fi

###############################################################################
# 10. OAUTH & IAP
###############################################################################
header "10. OAuth Brand & IAP"

BRAND_LIST=$(gcloud iap oauth-brands list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null || echo "")
if [[ -n "$BRAND_LIST" ]]; then
    warn "OAuth brand configured" "Already exists"
    echo "$BRAND_LIST" | while read -r brand; do detail "  - $brand"; done
    
    # Check for existing OAuth clients
    BRAND_PATH=$(echo "$BRAND_LIST" | head -1)
    OAUTH_CLIENTS=$(gcloud iap oauth-clients list "$BRAND_PATH" --project="$PROJECT_ID" --format="value(name,displayName)" 2>/dev/null || echo "")
    if [[ -n "$OAUTH_CLIENTS" ]]; then
        warn "OAuth clients exist" "DELETED on redeploy!"
        echo "$OAUTH_CLIENTS" | while read -r client; do detail "  - $client"; done
    fi
else
    ok "No OAuth brand configured"
fi

###############################################################################
# 11. CLOUD BUILD
###############################################################################
header "11. Cloud Build"

RECENT_BUILDS=$(gcloud builds list --project="$PROJECT_ID" --limit=5 --format="table(id,status,createTime,source.storageSource.bucket)" 2>/dev/null || echo "")
if [[ -n "$RECENT_BUILDS" ]] && ! echo "$RECENT_BUILDS" | grep -q "Listed 0 items"; then
    info "Recent Cloud Build history (last 5):"
    echo "$RECENT_BUILDS" | while read -r line; do detail "  $line"; done
else
    ok "No Cloud Build history"
fi

# Check for cloudbuild.yaml files
if [[ -f "$PROJECT_ROOT/backend/cloudbuild.yaml" ]]; then
    info "backend/cloudbuild.yaml exists"
else
    warn "backend/cloudbuild.yaml MISSING" "Required for deploy"
fi

if [[ -f "$PROJECT_ROOT/frontend/cloudbuild.yaml" ]]; then
    info "frontend/cloudbuild.yaml exists"
else
    warn "frontend/cloudbuild.yaml MISSING" "Required for deploy"
fi

###############################################################################
# 12. IAM POLICY BINDINGS (check for broad roles)
###############################################################################
header "12. IAM Policy (broad role check)"

# Check if any of our expected roles are already bound
IAM_POLICY=$(gcloud projects get-iam-policy "$PROJECT_ID" --project="$PROJECT_ID" --format=json 2>/dev/null || echo "{}")

BROAD_ROLES=("roles/aiplatform.admin" "roles/storage.admin" "roles/bigquery.admin")
for role in "${BROAD_ROLES[@]}"; do
    MEMBERS=$(echo "$IAM_POLICY" | python3 -c "
import json, sys
try:
    policy = json.load(sys.stdin)
    for b in policy.get('bindings', []):
        if b.get('role') == '$role':
            for m in b.get('members', []):
                print(m)
except: pass
" 2>/dev/null || echo "")
    if [[ -n "$MEMBERS" ]]; then
        info "Role '$role' is already bound to:"
        echo "$MEMBERS" | while read -r m; do detail "  - $m"; done
    fi
done

###############################################################################
# SUMMARY TABLE
###############################################################################
echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}  PRE-DEPLOYMENT CHECK — RESULTS TABLE${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Project:${NC} $PROJECT_ID    ${BOLD}Region:${NC} $REGION    ${BOLD}Scan:${NC} $(date -u '+%Y-%m-%d %H:%M UTC')"

# Print the formatted summary table
print_summary_table

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}  VERDICT${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ $CONFLICTS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✅ CLEAN ENVIRONMENT — Safe to proceed with deployment${NC}"
elif [[ $CONFLICTS -eq 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}⚠️  WARNINGS FOUND — Review table above before proceeding${NC}"
    echo -e "  ${YELLOW}   Existing resources detected but no direct naming conflicts.${NC}"
else
    echo -e "  ${RED}${BOLD}🚨 CONFLICTS FOUND — Existing resources would be affected${NC}"
    echo -e "  ${RED}   Review each CONFLICT row in the table above.${NC}"
    echo -e "  ${RED}   Deployment scripts skip existing resources, but IAM bindings${NC}"
    echo -e "  ${RED}   and OAuth clients WILL be modified.${NC}"
    echo ""
    echo -e "  ${YELLOW}Recommendations:${NC}"
    echo -e "  ${YELLOW}  1. If this is a RE-DEPLOYMENT of the same app → safe to proceed${NC}"
    echo -e "  ${YELLOW}  2. If this is a NEW app in a shared project → review conflicts carefully${NC}"
    echo -e "  ${YELLOW}  3. If unsure → use a fresh GCP project${NC}"
fi

echo ""
echo -e "${BLUE}Report generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')${NC}"
echo ""
