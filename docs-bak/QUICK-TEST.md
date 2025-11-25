# Quick Testing Reference

## 🚀 Quick Start - Run This First

```bash
# Full validation test (takes 10 seconds)
./infrastructure/test-pipeline.sh
```

**Result:** ✅ All 37 tests passed - you're ready to deploy!

---

## 📋 Testing Options (From Fastest to Slowest)

### 1️⃣ Quick Validation (10 seconds) ⚡
**What it tests:** Syntax, permissions, module loading, configuration  
**When to use:** Before every deployment, after editing scripts

```bash
./infrastructure/test-pipeline.sh
```

---

### 2️⃣ Help & Documentation (5 seconds) 📖
**What it tests:** Script structure, help system, argument parsing  
**When to use:** To see available options and understand usage

```bash
./infrastructure/deploy-all.sh --help
```

---

### 3️⃣ Dry Run (2 minutes) 🏃
**What it tests:** Configuration loading, prerequisite checks  
**When to use:** Validate configuration before actual deployment

```bash
# Start the script and cancel at confirmation prompt
./infrastructure/deploy-all.sh
# Press 'N' when asked "Proceed with deployment? [y/N]:"
```

---

### 4️⃣ Infrastructure Only (5-10 minutes) 🏗️
**What it tests:** Artifact Registry, service accounts, IAM permissions  
**When to use:** Test GCP resource creation without deploying containers

```bash
./infrastructure/deploy-all.sh --skip-cloud-run --skip-load-balancer --skip-iap
```

**What gets created:**
- Artifact Registry repository
- 4 service accounts (backend, frontend, RAG agent, IAP accessor)
- IAM role bindings for Vertex AI, Storage, BigQuery

---

### 5️⃣ Cloud Run Only (10-15 minutes) ☁️
**What it tests:** Container builds, Cloud Run deployment  
**When to use:** Test application deployment without Load Balancer

```bash
./infrastructure/deploy-all.sh --skip-load-balancer --skip-iap
```

**What gets deployed:**
- Backend container (built from source)
- Frontend container (built from source)
- Cloud Run services with direct URLs

**Test access:**
```bash
# Get service URLs
BACKEND_URL=$(gcloud run services describe backend --region=us-east4 --format='value(status.url)')
FRONTEND_URL=$(gcloud run services describe frontend --region=us-east4 --format='value(status.url)')

echo "Backend: $BACKEND_URL"
echo "Frontend: $FRONTEND_URL"
```

---

### 6️⃣ Load Balancer Without IAP (20-25 minutes) 🌐
**What it tests:** Load Balancer, SSL, routing, CORS  
**When to use:** Test infrastructure without authentication

```bash
./infrastructure/deploy-all.sh --skip-iap
```

**What gets created:**
- Static IP address
- SSL certificate (takes 10-15 min to provision)
- Network Endpoint Groups
- Backend services
- URL map with path routing
- HTTPS proxy and forwarding rule

**Test access:**
```bash
# Get Load Balancer URL
STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --format="value(address)")
echo "Load Balancer: https://$STATIC_IP.nip.io"

# Test in browser (no authentication required)
open "https://$STATIC_IP.nip.io"
```

---

### 7️⃣ Full Deployment (25-35 minutes) 🎯
**What it tests:** Complete production setup with OAuth and IAP  
**When to use:** Final validation before production use

```bash
./infrastructure/deploy-all.sh
```

**What gets deployed:**
- Everything from previous tests
- OAuth consent screen (manual step)
- OAuth client with redirect URIs (manual step)
- IAP service account
- IAP enabled on backend services
- Domain-restricted access

**Test access:**
```bash
# Get Load Balancer URL
STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --format="value(address)")
echo "Authenticated URL: https://$STATIC_IP.nip.io"

# Test in browser (OAuth required)
open "https://$STATIC_IP.nip.io"
# Expected: Google OAuth login → Consent screen → Application
```

---

## 🎯 Recommended Testing Workflow

For your first deployment:

```bash
# Step 1: Quick validation (10 seconds)
./infrastructure/test-pipeline.sh

# Step 2: Review configuration (5 seconds)
./infrastructure/deploy-all.sh --help

# Step 3: Incremental testing (10 minutes total)
./infrastructure/deploy-all.sh --skip-cloud-run --skip-load-balancer --skip-iap
# Review in GCP Console, then continue...

./infrastructure/deploy-all.sh --skip-load-balancer --skip-iap
# Test Cloud Run URLs, then continue...

./infrastructure/deploy-all.sh --skip-iap
# Test Load Balancer (no auth), then continue...

# Step 4: Full deployment (25-35 minutes)
./infrastructure/deploy-all.sh
```

---

## 🔍 What Each Test Validates

| Test | Validates | GCP Resources Created | Safe to Run Multiple Times |
|------|-----------|----------------------|---------------------------|
| **test-pipeline.sh** | Scripts only | None | ✅ Yes |
| **--help** | Documentation | None | ✅ Yes |
| **Dry run** | Config + Auth | None | ✅ Yes |
| **Infrastructure only** | Registry + SA + IAM | Yes (idempotent) | ✅ Yes |
| **Cloud Run only** | Containers + Deploy | Yes | ✅ Yes |
| **LB without IAP** | Networking + SSL | Yes (idempotent) | ✅ Yes |
| **Full deployment** | Complete system | Yes | ✅ Yes |

All deployment commands are **idempotent** - safe to run multiple times.

---

## 🐛 Troubleshooting Failed Tests

### Test Pipeline Failures

**Syntax errors:**
```bash
# Check specific file
bash -n infrastructure/lib/cloudrun.sh
```

**Permission errors:**
```bash
# Fix permissions
chmod +x infrastructure/deploy-all.sh infrastructure/lib/*.sh
```

**Configuration missing:**
```bash
# Create configuration
./infrastructure/deploy-config.sh --interactive
```

**Authentication errors:**
```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

---

## 📊 Test Output Explained

### Successful Test Output
```
Testing: deploy-all.sh syntax ... ✅ PASS
Tests Passed: 37
Tests Failed: 0
✅ All tests passed! Ready for deployment.
```

### Failed Test Output
```
Testing: deploy-all.sh syntax ... ❌ FAIL
Tests Passed: 35
Tests Failed: 2
❌ Some tests failed. Please fix issues before deploying.
```

---

## 🎨 Visual Testing Checklist

Use this checklist for comprehensive testing:

```
Pre-Deployment Validation:
□ Run test-pipeline.sh - all tests pass
□ Review configuration with --help
□ Dry run confirmation prompt works

Infrastructure Testing:
□ Artifact Registry created
□ Service accounts created
□ IAM roles granted
□ Verify in GCP Console

Cloud Run Testing:
□ Backend builds successfully
□ Frontend builds successfully
□ Services deploy without errors
□ Direct URLs accessible

Load Balancer Testing:
□ Static IP reserved
□ SSL certificate provisioning started
□ NEGs created
□ Backend services configured
□ URL map routing works
□ Frontend loads via LB URL
□ API calls work (/api/* routes to backend)

IAP Testing:
□ OAuth consent screen configured
□ OAuth client created
□ Redirect URIs added
□ IAP enabled on backend services
□ OAuth redirect works
□ Can authenticate with org account
□ Application accessible after login

Post-Deployment Validation:
□ SSL certificate is ACTIVE
□ No CORS errors in browser console
□ RAG queries work
□ Session persistence works
□ Logout works
```

---

## 💡 Pro Tips

1. **Start Simple:** Use skip flags to test incrementally
2. **Check GCP Console:** Verify resources after each phase
3. **Save Outputs:** Keep logs from test runs for debugging
4. **Test CORS Early:** Use browser DevTools Network tab
5. **SSL Takes Time:** Certificate provisioning is 10-15 minutes
6. **OAuth is Manual:** Two manual steps required (consent screen + redirect URIs)
7. **Idempotent Design:** Safe to re-run scripts anytime

---

## 🚨 Common Test Scenarios

### Scenario 1: Code Changes Only
```bash
# After updating backend/frontend code
./infrastructure/test-pipeline.sh
./infrastructure/deploy-all.sh --skip-apis --skip-load-balancer --skip-iap
```

### Scenario 2: Configuration Changes
```bash
# After updating deployment.config
./infrastructure/test-pipeline.sh  # Validates new config
./infrastructure/deploy-all.sh     # Full redeployment
```

### Scenario 3: Fresh Environment
```bash
# Brand new GCP project
./infrastructure/test-pipeline.sh
./infrastructure/deploy-all.sh  # No skip flags - full setup
```

### Scenario 4: Debugging CORS
```bash
# Test without authentication to isolate CORS issues
./infrastructure/deploy-all.sh --skip-iap
# Check browser console for CORS errors
```

### Scenario 5: SSL Certificate Issues
```bash
# Check certificate status
gcloud compute ssl-certificates describe rag-agent-ssl-cert --global

# Wait and retry if provisioning
watch -n 60 'gcloud compute ssl-certificates describe rag-agent-ssl-cert --global --format="value(managed.status)"'
```

---

## 📞 Support Resources

- **Testing Guide:** `infrastructure/TESTING-GUIDE.md` (comprehensive)
- **Deployment Guide:** `infrastructure/README-MODULAR-DEPLOYMENT.md`
- **Troubleshooting:** `TROUBLESHOOT.md`
- **Validation Script:** `infrastructure/validate-security.sh` (post-deployment)

---

## ✅ You're Ready!

Your test pipeline passed all 37 checks. You can now:

1. **Test incrementally:**
   ```bash
   ./infrastructure/deploy-all.sh --skip-load-balancer --skip-iap
   ```

2. **Deploy fully:**
   ```bash
   ./infrastructure/deploy-all.sh
   ```

3. **Get help anytime:**
   ```bash
   ./infrastructure/deploy-all.sh --help
   ```

Happy deploying! 🚀
