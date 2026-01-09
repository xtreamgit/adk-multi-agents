# Deployment Checklist - Multi-Account Config Migration

**Date**: 2025-10-10  
**Project**: adk-rag-hdtest6  
**Region**: us-east4  
**Account**: develom

---

## ✅ Pre-Deployment Verification

### 1. Verify Migration Implementation
```bash
./verify-config-migration.sh
```
**Expected Result**: All checks pass ✅

### 2. Verify Account Configurations
```bash
cd backend
python config/verify_configs.py
```
**Expected Output**:
- ✅ Valid configurations: 3/3
- ✅ All account configurations are valid!

### 3. Check File Updates

- [x] `backend/src/api/server.py` - Uses config_loader
- [x] `backend/Dockerfile` - Copies config/, sets ACCOUNT_ENV
- [x] `backend/cloudbuild.yaml` - Includes _ACCOUNT_ENV
- [x] `infrastructure/deploy-secure-v0.2.sh` - Sets ACCOUNT_ENV
- [x] `infrastructure/deploy-complete-oauth-v0.2.sh` - Sets ACCOUNT_ENV

### 4. Environment Variables Ready

Ensure `.env` file has:
```bash
PROJECT_ID=adk-rag-hdtest6
GOOGLE_CLOUD_LOCATION=us-east4
```

---

## 🚀 Deployment Steps

### Option A: Deploy with IAP (Recommended for Production)

```bash
# 1. Configure deployment settings
./infrastructure/deploy-config.sh --interactive

# 2. Deploy complete OAuth setup
./infrastructure/deploy-complete-oauth-v0.2.sh
```

### Option B: Deploy without IAP (Testing/Development)

```bash
# 1. Configure deployment settings
./infrastructure/deploy-config.sh --interactive

# 2. Deploy secure services
./infrastructure/deploy-secure-v0.2.sh
```

---

## 🔍 Post-Deployment Verification

### 1. Check Cloud Run Services

```bash
# List services
gcloud run services list --region=us-east4

# Check backend service
gcloud run services describe backend --region=us-east4
```

### 2. Verify Environment Variables

```bash
# Check ACCOUNT_ENV is set
gcloud run services describe backend \
  --region=us-east4 \
  --format="value(spec.template.spec.containers[0].env[?(@.name=='ACCOUNT_ENV')].value)"
```

**Expected Output**: `develom`

### 3. Check Application Logs

```bash
# View recent logs
gcloud run logs read backend --region=us-east4 --limit=50

# Look for agent loading messages
gcloud run logs read backend --region=us-east4 --limit=100 | grep "Loading agent"
```

**Expected Log Entries**:
```
🔧 Loading agent for account: develom
✅ Loaded agent: RagAgent with 7 tools
```

### 4. Test API Endpoints

```bash
# Get backend URL
BACKEND_URL=$(gcloud run services describe backend --region=us-east4 --format='value(status.url)')

# Test health endpoint
curl $BACKEND_URL/

# Test with authentication (if IAP enabled)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" $BACKEND_URL/
```

**Expected Response**: `{"message":"RAG Agent API is running"}`

### 5. Test Corpus Operations

```bash
# List corpora (requires authentication)
curl -X GET "$BACKEND_URL/api/corpora" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 🐛 Troubleshooting

### Issue: "Module config_loader not found"

**Cause**: Config directory not copied to container  
**Fix**: Verify Dockerfile line 24: `COPY config/ ./config/`

```bash
# Rebuild container
cd backend
docker build -t rag-backend .
```

### Issue: "Invalid ACCOUNT_ENV: ..."

**Cause**: ACCOUNT_ENV set to non-existent account  
**Fix**: Check valid accounts in `backend/config/config_loader.py`

```bash
# Valid accounts: develom, usfs, tt
export ACCOUNT_ENV=develom
```

### Issue: Agent not loading

**Check**:
1. Cloud Run environment variables
2. Container logs for errors
3. Config file syntax

```bash
# Check container locally
docker run -e ACCOUNT_ENV=develom -p 8080:8080 rag-backend

# View startup logs
docker logs <container-id>
```

### Issue: "Missing key inputs argument" error

**Cause**: PROJECT_ID or GOOGLE_CLOUD_LOCATION not set  
**Fix**: Ensure environment variables are set in deployment

```bash
gcloud run services update backend \
  --region=us-east4 \
  --set-env-vars="PROJECT_ID=adk-rag-hdtest6,GOOGLE_CLOUD_LOCATION=us-east4,ACCOUNT_ENV=develom"
```

---

## 🔄 Switching Accounts After Deployment

### Change to USFS Account

```bash
gcloud run services update backend \
  --region=us-east4 \
  --set-env-vars="ACCOUNT_ENV=usfs"

# Wait for new revision
gcloud run services describe backend --region=us-east4

# Verify logs
gcloud run logs read backend --region=us-east4 --limit=20 | grep "Loading agent"
```

### Change to TechTrend Account

```bash
gcloud run services update backend \
  --region=us-east4 \
  --set-env-vars="ACCOUNT_ENV=tt"
```

---

## 📊 Monitoring

### Key Metrics to Watch

1. **Service Status**: All revisions healthy
2. **Error Rate**: < 1%
3. **Cold Start Time**: < 5 seconds
4. **Memory Usage**: < 1GB

```bash
# View Cloud Run metrics
gcloud run services describe backend \
  --region=us-east4 \
  --format="yaml(status)"
```

### Log Queries

```bash
# Find errors
gcloud logging read "resource.type=cloud_run_revision \
  AND resource.labels.service_name=backend \
  AND severity>=ERROR" \
  --limit=50 \
  --format=json

# Find account loading events
gcloud logging read "resource.type=cloud_run_revision \
  AND resource.labels.service_name=backend \
  AND textPayload=~'Loading agent'" \
  --limit=10
```

---

## 🎯 Success Criteria

- [✓] Verification script passes all checks
- [✓] Backend service deploys successfully
- [✓] Cloud Run logs show correct account loading
- [✓] API health check returns 200 OK
- [✓] Corpus operations work correctly
- [✓] No critical errors in logs

---

## 📝 Rollback Plan

If issues occur:

### 1. Quick Rollback to Previous Revision

```bash
# List revisions
gcloud run revisions list --service=backend --region=us-east4

# Rollback to previous revision
gcloud run services update-traffic backend \
  --region=us-east4 \
  --to-revisions=PREVIOUS_REVISION=100
```

### 2. Full Rollback (Revert Code Changes)

See `CONFIG-MIGRATION-SUMMARY.md` section "🔙 Rollback (if needed)"

---

## 📚 Additional Resources

- **Migration Details**: `CONFIG-MIGRATION-SUMMARY.md`
- **Account Switching**: `ACCOUNT-SWITCHING-GUIDE.md`
- **Verification Script**: `verify-config-migration.sh`
- **Config Validator**: `backend/config/verify_configs.py`

---

## ✅ Sign-off

| Role | Name | Date | Status |
|------|------|------|--------|
| Developer | | 2025-10-10 | ✅ Implemented |
| Testing | | | ⏳ Pending |
| Deployment | | | ⏳ Pending |

---

**Deployment Ready**: ✅ YES  
**Date Prepared**: 2025-10-10  
**Next Action**: Run deployment script
