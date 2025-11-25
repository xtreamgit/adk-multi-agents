# Testing Guide for Modular Deployment Pipeline

## Quick Start: Testing Options

### Option 1: Syntax Validation (Fastest - 10 seconds)
Check for shell script syntax errors:
```bash
# Test master script
bash -n infrastructure/deploy-all.sh

# Test all modules
for script in infrastructure/lib/*.sh; do
    echo "Checking $script..."
    bash -n "$script"
done
```

### Option 2: Dry Run Validation (Fast - 1 minute)
Run help and validate script loading:
```bash
# Show help (validates script structure)
./infrastructure/deploy-all.sh --help

# Validate all modules load correctly
bash -c "
source infrastructure/lib/utils.sh
source infrastructure/lib/prerequisites.sh
source infrastructure/lib/infrastructure.sh
source infrastructure/lib/cloudrun.sh
source infrastructure/lib/oauth.sh
source infrastructure/lib/loadbalancer.sh
source infrastructure/lib/iap.sh
source infrastructure/lib/finalize.sh
echo '✅ All modules loaded successfully'
"
```

### Option 3: Prerequisites Only (Medium - 2-3 minutes)
Test authentication and configuration:
```bash
# Test just prerequisites module
./infrastructure/deploy-all.sh --skip-cloud-run --skip-load-balancer --skip-iap
# Cancel after prerequisites validation completes
```

### Option 4: Incremental Testing (Medium - 5-10 minutes)
Test each phase incrementally with skip flags:
```bash
# Phase 1: Prerequisites + Infrastructure only
./infrastructure/deploy-all.sh --skip-cloud-run --skip-load-balancer --skip-iap
# Review output, then Ctrl+C

# Phase 2: Add Cloud Run deployment
./infrastructure/deploy-all.sh --skip-load-balancer --skip-iap
# Review output, then Ctrl+C

# Phase 3: Full deployment
./infrastructure/deploy-all.sh
```

### Option 5: Full Test Deployment (Slow - 20-30 minutes)
Complete end-to-end deployment test:
```bash
# Full deployment with all components
./infrastructure/deploy-all.sh
```

---

## Detailed Testing Procedures

### Level 1: Static Analysis (No GCP calls)

#### Test 1.1: Bash Syntax Check
```bash
cd /Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent

echo "Testing deploy-all.sh..."
bash -n infrastructure/deploy-all.sh && echo "✅ Syntax OK" || echo "❌ Syntax Error"

echo "Testing modules..."
for script in infrastructure/lib/*.sh; do
    echo -n "  $(basename $script): "
    bash -n "$script" && echo "✅" || echo "❌"
done
```

#### Test 1.2: ShellCheck (Optional - requires shellcheck)
```bash
# Install shellcheck first: brew install shellcheck

shellcheck infrastructure/deploy-all.sh
shellcheck infrastructure/lib/*.sh
```

---

### Level 2: Module Loading Test (No GCP calls)

#### Test 2.1: Module Import Test
```bash
# Create a test script
cat > /tmp/test-modules.sh << 'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="/Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent/infrastructure"
LIB_DIR="$SCRIPT_DIR/lib"

echo "Loading modules..."

source "$LIB_DIR/utils.sh"
echo "✅ utils.sh loaded"

source "$LIB_DIR/prerequisites.sh"
echo "✅ prerequisites.sh loaded"

source "$LIB_DIR/infrastructure.sh"
echo "✅ infrastructure.sh loaded"

source "$LIB_DIR/cloudrun.sh"
echo "✅ cloudrun.sh loaded"

source "$LIB_DIR/oauth.sh"
echo "✅ oauth.sh loaded"

source "$LIB_DIR/loadbalancer.sh"
echo "✅ loadbalancer.sh loaded"

source "$LIB_DIR/iap.sh"
echo "✅ iap.sh loaded"

source "$LIB_DIR/finalize.sh"
echo "✅ finalize.sh loaded"

echo ""
echo "Testing utility functions..."
log_info "Info test"
log_success "Success test"
log_warning "Warning test"
log_error "Error test"

echo ""
echo "✅ All modules loaded and functions work!"
EOF

chmod +x /tmp/test-modules.sh
/tmp/test-modules.sh
```

#### Test 2.2: Help System Test
```bash
# Test help output
./infrastructure/deploy-all.sh --help

# Should display full help without errors
```

---

### Level 3: Configuration Test (Minimal GCP calls)

#### Test 3.1: Prerequisites Check Only
```bash
# Run up to prerequisites validation
# This will check:
# - gcloud authentication
# - deployment.config file
# - secrets.env file
# - Project configuration

./infrastructure/deploy-all.sh

# When prompted "Proceed with deployment? [y/N]:", press 'N' to cancel
# This validates everything up to the deployment start
```

#### Test 3.2: Configuration Validation Script
Create a standalone validator:
```bash
cat > /tmp/validate-config.sh << 'EOF'
#!/bin/bash
set -e

cd /Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent

echo "Validating deployment configuration..."
echo ""

# Check deployment.config
if [[ -f "./deployment.config" ]]; then
    echo "✅ deployment.config exists"
    source ./deployment.config
    
    # Check required variables
    [[ -n "$PROJECT_ID" ]] && echo "  ✅ PROJECT_ID: $PROJECT_ID" || echo "  ❌ PROJECT_ID missing"
    [[ -n "$REGION" ]] && echo "  ✅ REGION: $REGION" || echo "  ❌ REGION missing"
    [[ -n "$REPO" ]] && echo "  ✅ REPO: $REPO" || echo "  ❌ REPO missing"
    [[ -n "$ORGANIZATION_DOMAIN" ]] && echo "  ✅ ORGANIZATION_DOMAIN: $ORGANIZATION_DOMAIN" || echo "  ❌ ORGANIZATION_DOMAIN missing"
    [[ -n "$IAP_ADMIN_USER" ]] && echo "  ✅ IAP_ADMIN_USER: $IAP_ADMIN_USER" || echo "  ❌ IAP_ADMIN_USER missing"
else
    echo "❌ deployment.config not found"
fi

echo ""

# Check secrets.env
if [[ -f "./secrets.env" ]]; then
    echo "✅ secrets.env exists"
    source ./secrets.env
    [[ -n "$SECRET_KEY" ]] && echo "  ✅ SECRET_KEY present" || echo "  ❌ SECRET_KEY missing"
else
    echo "❌ secrets.env not found"
fi

echo ""

# Check gcloud authentication
if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo "✅ gcloud authenticated as: $ACCOUNT"
else
    echo "❌ Not authenticated with gcloud"
fi

echo ""

# Check application default credentials
if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    echo "✅ Application default credentials configured"
else
    echo "❌ Application default credentials not set"
fi

echo ""
echo "Configuration validation complete!"
EOF

chmod +x /tmp/validate-config.sh
/tmp/validate-config.sh
```

---

### Level 4: Incremental Deployment Test (Progressive GCP calls)

#### Test 4.1: Infrastructure Only
```bash
# Test infrastructure setup without deploying Cloud Run
# This creates:
# - Artifact Registry
# - Service Accounts
# - IAM Permissions

./infrastructure/deploy-all.sh --skip-cloud-run --skip-load-balancer --skip-iap

# This will stop after infrastructure setup
# You can verify in GCP Console:
# - Artifact Registry repository exists
# - Service accounts were created
# - IAM roles were granted
```

#### Test 4.2: Cloud Run Only
```bash
# Test Cloud Run deployment without Load Balancer or IAP
# This builds and deploys:
# - Backend service
# - Frontend service

./infrastructure/deploy-all.sh --skip-load-balancer --skip-iap

# After completion, verify:
# - Cloud Run services are running
# - Can access backend/frontend URLs directly
```

#### Test 4.3: Load Balancer Only (Skip IAP)
```bash
# Test Load Balancer without IAP (no authentication)
# Useful for testing routing and CORS

./infrastructure/deploy-all.sh --skip-iap

# After completion, verify:
# - Load Balancer URL works (may take 10-15 min for SSL)
# - Can access application without OAuth
# - Path routing works (/ → frontend, /api/* → backend)
```

#### Test 4.4: Full Deployment
```bash
# Complete deployment with all components
./infrastructure/deploy-all.sh

# After completion, verify:
# - OAuth redirect works
# - IAP authentication required
# - Application accessible after OAuth
```

---

### Level 5: Individual Module Testing (Advanced)

Test individual modules in isolation:

#### Test Module: utils.sh
```bash
source infrastructure/lib/utils.sh

# Test logging
log_info "Testing info"
log_success "Testing success"
log_warning "Testing warning"
log_error "Testing error"
log_section "Testing section"

# Test banner
show_banner

# Test confirmation
confirm_action "Continue with test?" && echo "User confirmed" || echo "User declined"
```

#### Test Module: prerequisites.sh
```bash
# Set up environment
export PROJECT_ID="test-project"
export REGION="us-central1"
export REPO="test-repo"
export ORGANIZATION_DOMAIN="test.com"
export IAP_ADMIN_USER="user@test.com"
export SECRETS_FILE="./secrets.env"
export SKIP_APIS=true

source infrastructure/lib/utils.sh
source infrastructure/lib/prerequisites.sh

# Test prerequisites validation
validate_prerequisites
```

#### Test Module: infrastructure.sh
```bash
source infrastructure/lib/utils.sh
source infrastructure/lib/infrastructure.sh

# Test individual functions
setup_artifact_registry
setup_service_accounts
configure_iam_permissions
```

---

## Testing Checklist

Use this checklist to verify your testing:

### Pre-Deployment Tests
- [ ] Bash syntax check passes for all scripts
- [ ] All modules load without errors
- [ ] Help system displays correctly
- [ ] Configuration files exist and have required variables
- [ ] gcloud authentication is active
- [ ] Application default credentials are set

### Deployment Phase Tests
- [ ] Prerequisites validation succeeds
- [ ] APIs enable successfully
- [ ] Artifact Registry is created
- [ ] Service accounts are created
- [ ] IAM permissions are granted
- [ ] Backend builds and deploys
- [ ] Frontend builds and deploys
- [ ] OAuth consent screen is configured
- [ ] Static IP is reserved
- [ ] SSL certificate is provisioned
- [ ] Load Balancer is created
- [ ] URL map routes correctly
- [ ] OAuth client is created
- [ ] Redirect URIs are added (manual step)
- [ ] IAP is enabled
- [ ] CORS is configured
- [ ] Frontend is rebuilt with LB URL

### Post-Deployment Tests
- [ ] Load Balancer URL resolves
- [ ] SSL certificate is ACTIVE (may take 10-15 min)
- [ ] OAuth redirect works
- [ ] Can sign in with organization account
- [ ] Application loads after authentication
- [ ] API calls work (check browser console)
- [ ] CORS errors are absent

---

## Recommended Testing Workflow

For first-time testing, follow this workflow:

### Step 1: Static Validation (5 minutes)
```bash
# Run syntax checks
bash -n infrastructure/deploy-all.sh
for script in infrastructure/lib/*.sh; do bash -n "$script"; done

# Test help
./infrastructure/deploy-all.sh --help
```

### Step 2: Configuration Validation (2 minutes)
```bash
# Run the validation script from Test 3.2
/tmp/validate-config.sh
```

### Step 3: Module Loading Test (1 minute)
```bash
# Run the module loading test from Test 2.1
/tmp/test-modules.sh
```

### Step 4: Incremental Deployment (30 minutes)
```bash
# Phase 1: Infrastructure only
./infrastructure/deploy-all.sh --skip-cloud-run --skip-load-balancer --skip-iap

# Phase 2: Add Cloud Run
./infrastructure/deploy-all.sh --skip-load-balancer --skip-iap

# Phase 3: Add Load Balancer (no IAP for testing)
./infrastructure/deploy-all.sh --skip-iap

# Phase 4: Full deployment with IAP
./infrastructure/deploy-all.sh
```

### Step 5: Validation Script
```bash
# Run security validation after deployment
./infrastructure/validate-security.sh
```

---

## Quick Test Commands

Copy and paste these for quick testing:

### Test 1: Syntax Only (10 seconds)
```bash
cd /Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent && \
bash -n infrastructure/deploy-all.sh && \
for script in infrastructure/lib/*.sh; do bash -n "$script" && echo "✅ $(basename $script)"; done
```

### Test 2: Configuration Check (30 seconds)
```bash
cd /Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent && \
[[ -f deployment.config ]] && echo "✅ deployment.config" || echo "❌ deployment.config" && \
[[ -f secrets.env ]] && echo "✅ secrets.env" || echo "❌ secrets.env" && \
gcloud auth list --filter=status:ACTIVE && echo "✅ gcloud auth" || echo "❌ gcloud auth"
```

### Test 3: Help Display (5 seconds)
```bash
./infrastructure/deploy-all.sh --help
```

### Test 4: Dry Run (1 minute)
```bash
# Start deployment and cancel at confirmation prompt
./infrastructure/deploy-all.sh
# Press 'N' when asked to proceed
```

---

## Troubleshooting Test Failures

### Syntax Errors
**Problem:** `bash -n` shows syntax errors  
**Solution:** Review the specific line mentioned, check for:
- Missing quotes
- Unmatched brackets
- Incorrect variable expansion

### Module Loading Errors
**Problem:** Module fails to source  
**Solution:** 
- Check file permissions: `chmod +x infrastructure/lib/*.sh`
- Verify file paths are correct
- Ensure no circular dependencies

### Configuration Errors
**Problem:** Missing configuration variables  
**Solution:**
- Run: `./infrastructure/deploy-config.sh --interactive`
- Create secrets.env: `echo "SECRET_KEY=$(openssl rand -hex 32)" > secrets.env`

### Authentication Errors
**Problem:** gcloud authentication fails  
**Solution:**
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### Deployment Failures
**Problem:** Deployment fails at specific module  
**Solution:**
- Check error message carefully
- Review module-specific troubleshooting in README-MODULAR-DEPLOYMENT.md
- Test that specific module in isolation
- Check GCP Console for resource status

---

## Continuous Testing

For ongoing development, create a test script:

```bash
cat > infrastructure/test-pipeline.sh << 'EOF'
#!/bin/bash
# Continuous testing script

set -e

echo "🧪 Running deployment pipeline tests..."
echo ""

echo "Test 1: Syntax validation..."
bash -n infrastructure/deploy-all.sh
for script in infrastructure/lib/*.sh; do
    bash -n "$script"
done
echo "✅ Syntax validation passed"
echo ""

echo "Test 2: Module loading..."
source infrastructure/lib/utils.sh
source infrastructure/lib/prerequisites.sh
source infrastructure/lib/infrastructure.sh
source infrastructure/lib/cloudrun.sh
source infrastructure/lib/oauth.sh
source infrastructure/lib/loadbalancer.sh
source infrastructure/lib/iap.sh
source infrastructure/lib/finalize.sh
echo "✅ Module loading passed"
echo ""

echo "Test 3: Configuration check..."
[[ -f deployment.config ]] || { echo "❌ deployment.config missing"; exit 1; }
[[ -f secrets.env ]] || { echo "❌ secrets.env missing"; exit 1; }
echo "✅ Configuration check passed"
echo ""

echo "✅ All tests passed!"
EOF

chmod +x infrastructure/test-pipeline.sh
```

Then run: `./infrastructure/test-pipeline.sh`

---

## Success Criteria

Your testing is successful when:

1. ✅ All syntax checks pass
2. ✅ All modules load without errors
3. ✅ Configuration validation succeeds
4. ✅ Prerequisites check passes
5. ✅ Incremental deployments work
6. ✅ Full deployment completes
7. ✅ Application is accessible via Load Balancer
8. ✅ OAuth authentication works
9. ✅ No CORS errors in browser console
10. ✅ RAG agent responds to queries

---

## Next Steps After Testing

Once testing is complete:
1. Document any issues encountered
2. Update TROUBLESHOOT.md with solutions
3. Create a deployment runbook for your team
4. Set up monitoring and alerts
5. Schedule regular test deployments

Happy testing! 🚀
