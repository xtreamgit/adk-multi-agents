#!/bin/bash
#
# test-pipeline.sh - Quick validation of deployment pipeline
#
# This script performs rapid validation tests without deploying to GCP
# Run this before attempting a full deployment to catch issues early

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}║     DEPLOYMENT PIPELINE VALIDATION TESTS                      ║${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing: $test_name ... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo -e "${YELLOW}📋 Test Suite 1: Syntax Validation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "deploy-all.sh syntax" "bash -n infrastructure/deploy-all.sh"
run_test "utils.sh syntax" "bash -n infrastructure/lib/utils.sh"
run_test "prerequisites.sh syntax" "bash -n infrastructure/lib/prerequisites.sh"
run_test "infrastructure.sh syntax" "bash -n infrastructure/lib/infrastructure.sh"
run_test "cloudrun.sh syntax" "bash -n infrastructure/lib/cloudrun.sh"
run_test "oauth.sh syntax" "bash -n infrastructure/lib/oauth.sh"
run_test "loadbalancer.sh syntax" "bash -n infrastructure/lib/loadbalancer.sh"
run_test "iap.sh syntax" "bash -n infrastructure/lib/iap.sh"
run_test "finalize.sh syntax" "bash -n infrastructure/lib/finalize.sh"

echo ""
echo -e "${YELLOW}📋 Test Suite 2: File Permissions${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "deploy-all.sh executable" "test -x infrastructure/deploy-all.sh"
run_test "utils.sh executable" "test -x infrastructure/lib/utils.sh"
run_test "prerequisites.sh executable" "test -x infrastructure/lib/prerequisites.sh"
run_test "infrastructure.sh executable" "test -x infrastructure/lib/infrastructure.sh"
run_test "cloudrun.sh executable" "test -x infrastructure/lib/cloudrun.sh"
run_test "oauth.sh executable" "test -x infrastructure/lib/oauth.sh"
run_test "loadbalancer.sh executable" "test -x infrastructure/lib/loadbalancer.sh"
run_test "iap.sh executable" "test -x infrastructure/lib/iap.sh"
run_test "finalize.sh executable" "test -x infrastructure/lib/finalize.sh"

echo ""
echo -e "${YELLOW}📋 Test Suite 3: Module Loading${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Load utils.sh" "source infrastructure/lib/utils.sh"
run_test "Load prerequisites.sh" "source infrastructure/lib/utils.sh && source infrastructure/lib/prerequisites.sh"
run_test "Load infrastructure.sh" "source infrastructure/lib/utils.sh && source infrastructure/lib/infrastructure.sh"
run_test "Load cloudrun.sh" "source infrastructure/lib/utils.sh && source infrastructure/lib/cloudrun.sh"
run_test "Load oauth.sh" "source infrastructure/lib/utils.sh && source infrastructure/lib/oauth.sh"
run_test "Load loadbalancer.sh" "source infrastructure/lib/utils.sh && source infrastructure/lib/loadbalancer.sh"
run_test "Load iap.sh" "source infrastructure/lib/utils.sh && source infrastructure/lib/iap.sh"
run_test "Load finalize.sh" "source infrastructure/lib/utils.sh && source infrastructure/lib/finalize.sh"

echo ""
echo -e "${YELLOW}📋 Test Suite 4: Configuration Files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "deployment.config exists" "test -f deployment.config"
run_test "secrets.env exists" "test -f secrets.env"

if [[ -f deployment.config ]]; then
    source deployment.config
    run_test "PROJECT_ID defined" "test -n '$PROJECT_ID'"
    run_test "REGION defined" "test -n '$REGION'"
    run_test "REPO defined" "test -n '$REPO'"
    run_test "ORGANIZATION_DOMAIN defined" "test -n '$ORGANIZATION_DOMAIN'"
    run_test "IAP_ADMIN_USER defined" "test -n '$IAP_ADMIN_USER'"
fi

if [[ -f secrets.env ]]; then
    source secrets.env
    run_test "SECRET_KEY defined" "test -n '$SECRET_KEY'"
fi

echo ""
echo -e "${YELLOW}📋 Test Suite 5: GCP Environment${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "gcloud command available" "command -v gcloud"
run_test "gcloud authenticated" "gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q '@'"
run_test "Application default credentials" "gcloud auth application-default print-access-token"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Test Results Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "  Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed! Ready for deployment.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Run: ./infrastructure/deploy-all.sh --help"
    echo "  2. Start deployment: ./infrastructure/deploy-all.sh"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please fix issues before deploying.${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting tips:${NC}"
    echo "  • Syntax errors: Review the specific script file"
    echo "  • Permission errors: Run 'chmod +x infrastructure/deploy-all.sh infrastructure/lib/*.sh'"
    echo "  • Missing config: Run './infrastructure/deploy-config.sh --interactive'"
    echo "  • Missing secrets: Create secrets.env with SECRET_KEY"
    echo "  • Auth errors: Run 'gcloud auth login' and 'gcloud auth application-default login'"
    echo ""
    exit 1
fi
