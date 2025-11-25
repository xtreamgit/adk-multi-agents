#!/bin/bash
#
# verify-config-migration.sh - Verify Config Migration Implementation
#
# This script verifies that the multi-account config structure is properly
# implemented and all necessary files have been updated.
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Verifying Config Migration Implementation${NC}"
echo "=============================================="
echo ""

ERRORS=0
WARNINGS=0

# 1. Check if config directory exists
echo -e "${YELLOW}1. Checking config directory structure...${NC}"
if [[ -d "backend/config" ]]; then
    echo -e "${GREEN}   ✅ backend/config/ directory exists${NC}"
    
    # Check for config_loader.py
    if [[ -f "backend/config/config_loader.py" ]]; then
        echo -e "${GREEN}   ✅ config_loader.py exists${NC}"
    else
        echo -e "${RED}   ❌ config_loader.py missing${NC}"
        ((ERRORS++))
    fi
    
    # Check account directories
    for account in develom usfs tt; do
        if [[ -d "backend/config/$account" ]]; then
            echo -e "${GREEN}   ✅ $account/ directory exists${NC}"
            
            # Check for agent.py and config.py
            if [[ -f "backend/config/$account/agent.py" ]]; then
                echo -e "${GREEN}      ✅ $account/agent.py exists${NC}"
            else
                echo -e "${RED}      ❌ $account/agent.py missing${NC}"
                ((ERRORS++))
            fi
            
            if [[ -f "backend/config/$account/config.py" ]]; then
                echo -e "${GREEN}      ✅ $account/config.py exists${NC}"
            else
                echo -e "${RED}      ❌ $account/config.py missing${NC}"
                ((ERRORS++))
            fi
        else
            echo -e "${RED}   ❌ $account/ directory missing${NC}"
            ((ERRORS++))
        fi
    done
else
    echo -e "${RED}   ❌ backend/config/ directory missing${NC}"
    ((ERRORS++))
fi
echo ""

# 2. Check server.py uses config_loader
echo -e "${YELLOW}2. Checking server.py implementation...${NC}"
if grep -q "from config_loader import load_agent, load_config" backend/src/api/server.py; then
    echo -e "${GREEN}   ✅ server.py imports config_loader${NC}"
else
    echo -e "${RED}   ❌ server.py does not import config_loader${NC}"
    ((ERRORS++))
fi

if grep -q 'ACCOUNT_ENV' backend/src/api/server.py; then
    echo -e "${GREEN}   ✅ server.py uses ACCOUNT_ENV${NC}"
else
    echo -e "${RED}   ❌ server.py does not use ACCOUNT_ENV${NC}"
    ((ERRORS++))
fi

if grep -q 'agent_module = load_agent' backend/src/api/server.py; then
    echo -e "${GREEN}   ✅ server.py uses load_agent()${NC}"
else
    echo -e "${RED}   ❌ server.py does not use load_agent()${NC}"
    ((ERRORS++))
fi
echo ""

# 3. Check Dockerfile
echo -e "${YELLOW}3. Checking Dockerfile...${NC}"
if grep -q "COPY config/ ./config/" backend/Dockerfile; then
    echo -e "${GREEN}   ✅ Dockerfile copies config directory${NC}"
else
    echo -e "${RED}   ❌ Dockerfile does not copy config directory${NC}"
    ((ERRORS++))
fi

if grep -q "ENV ACCOUNT_ENV=" backend/Dockerfile; then
    echo -e "${GREEN}   ✅ Dockerfile sets ACCOUNT_ENV${NC}"
    ACCOUNT_VALUE=$(grep "ENV ACCOUNT_ENV=" backend/Dockerfile | cut -d'=' -f2)
    echo -e "      Current value: ${BLUE}$ACCOUNT_VALUE${NC}"
else
    echo -e "${RED}   ❌ Dockerfile does not set ACCOUNT_ENV${NC}"
    ((ERRORS++))
fi
echo ""

# 4. Check cloudbuild.yaml
echo -e "${YELLOW}4. Checking cloudbuild.yaml...${NC}"
if grep -q "_ACCOUNT_ENV:" backend/cloudbuild.yaml; then
    echo -e "${GREEN}   ✅ cloudbuild.yaml includes _ACCOUNT_ENV substitution${NC}"
    ACCOUNT_VALUE=$(grep "_ACCOUNT_ENV:" backend/cloudbuild.yaml | cut -d"'" -f2)
    echo -e "      Current value: ${BLUE}$ACCOUNT_VALUE${NC}"
else
    echo -e "${YELLOW}   ⚠️  cloudbuild.yaml does not include _ACCOUNT_ENV (optional)${NC}"
    ((WARNINGS++))
fi
echo ""

# 5. Check deployment scripts
echo -e "${YELLOW}5. Checking deployment scripts...${NC}"

if [[ -f "infrastructure/deploy-secure-v0.2.sh" ]]; then
    if grep -q "ACCOUNT_ENV=develom" infrastructure/deploy-secure-v0.2.sh; then
        echo -e "${GREEN}   ✅ deploy-secure-v0.2.sh includes ACCOUNT_ENV${NC}"
    else
        echo -e "${YELLOW}   ⚠️  deploy-secure-v0.2.sh may not include ACCOUNT_ENV${NC}"
        ((WARNINGS++))
    fi
fi

if [[ -f "infrastructure/deploy-complete-oauth-v0.2.sh" ]]; then
    if grep -q "ACCOUNT_ENV=develom" infrastructure/deploy-complete-oauth-v0.2.sh; then
        echo -e "${GREEN}   ✅ deploy-complete-oauth-v0.2.sh includes ACCOUNT_ENV${NC}"
    else
        echo -e "${YELLOW}   ⚠️  deploy-complete-oauth-v0.2.sh may not include ACCOUNT_ENV${NC}"
        ((WARNINGS++))
    fi
fi
echo ""

# 6. Run verify_configs.py if available
echo -e "${YELLOW}6. Testing config loader...${NC}"
if [[ -f "backend/config/verify_configs.py" ]]; then
    echo -e "   Running verify_configs.py..."
    if cd backend && python config/verify_configs.py > /dev/null 2>&1; then
        echo -e "${GREEN}   ✅ All account configurations are valid${NC}"
    else
        echo -e "${RED}   ❌ Configuration validation failed${NC}"
        echo -e "      Run: ${BLUE}cd backend && python config/verify_configs.py${NC}"
        ((ERRORS++))
    fi
    cd ..
else
    echo -e "${YELLOW}   ⚠️  verify_configs.py not found${NC}"
    ((WARNINGS++))
fi
echo ""

# 7. Check for old imports (potential issues)
echo -e "${YELLOW}7. Checking for potential conflicts...${NC}"
if grep -q "from rag_agent.agent import root_agent" backend/src/api/server.py 2>/dev/null; then
    echo -e "${RED}   ❌ server.py still has old import (from rag_agent.agent)${NC}"
    ((ERRORS++))
else
    echo -e "${GREEN}   ✅ No old imports detected in server.py${NC}"
fi
echo ""

# Summary
echo "=============================================="
echo -e "${BLUE}📋 Verification Summary${NC}"
echo "=============================================="
echo ""

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✅ Perfect! All checks passed.${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Test locally: docker build -t rag-backend backend/"
    echo "  2. Deploy to Cloud Run: ./infrastructure/deploy-secure-v0.2.sh"
    echo "  3. Monitor logs for: '🔧 Loading agent for account: develom'"
    echo ""
    exit 0
elif [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Implementation complete with $WARNINGS warning(s).${NC}"
    echo "   Migration should work, but review warnings above."
    echo ""
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    echo "   Please fix the errors above before deploying."
    echo ""
    exit 1
fi
