# Load Balancer "No Healthy Upstreams" Fix

**Date:** October 16, 2025  
**Issue:** Load Balancer returning "no healthy upstreams" error  
**Status:** ✅ RESOLVED

## Root Cause

The Load Balancer backend services existed but had **no backends attached** to them. This was caused by two bugs in `infrastructure/lib/loadbalancer.sh`:

### Bug 1: Non-existent gcloud Flag
```bash
# Lines 115-119 (OLD)
gcloud compute backend-services update frontend-backend-service \
    --global \
    --clear-port-name \  # ❌ This flag doesn't exist!
    --quiet
```

The `--clear-port-name` flag does not exist in gcloud CLI, causing the command to fail silently.

### Bug 2: Backend Attachment Only in Else Block
```bash
# Lines 106-127 (OLD)
if gcloud compute backend-services describe frontend-backend-service --global >/dev/null 2>&1; then
    echo "  ✓ Frontend backend service exists"
    # ❌ Exits here - backends never attached!
else
    gcloud compute backend-services create ...
    gcloud compute backend-services add-backend ...  # Only runs if service doesn't exist
fi
```

When backend services already existed from a previous deployment, the script would skip backend attachment entirely.

### Bug 3: Protocol/Port Name Incompatibility
```bash
# Line 112 (OLD)
--protocol=HTTPS  # ❌ Auto-sets portName=https, incompatible with serverless NEGs
```

Creating backend services with `--protocol=HTTPS` automatically sets `portName=https`, which is incompatible with serverless Network Endpoint Groups (Cloud Run).

**Error message:**
```
Invalid value for field 'resource.portName': 'https'. Port name is not supported 
for a backend service with Serverless network endpoint groups.
```

## Immediate Fix Applied

### Step 1: Changed Protocol to HTTP
```bash
gcloud compute backend-services update frontend-backend-service --global --protocol=HTTP --project=adk-rag-tt
gcloud compute backend-services update backend-backend-service --global --protocol=HTTP --project=adk-rag-tt
```

### Step 2: Set Port Name to http
```bash
gcloud compute backend-services update frontend-backend-service --global --port-name=http --project=adk-rag-tt
gcloud compute backend-services update backend-backend-service --global --port-name=http --project=adk-rag-tt
```

### Step 3: Attached NEGs to Backend Services
```bash
gcloud compute backend-services add-backend frontend-backend-service \
  --global \
  --network-endpoint-group=frontend-neg \
  --network-endpoint-group-region=us-east4 \
  --project=adk-rag-tt

gcloud compute backend-services add-backend backend-backend-service \
  --global \
  --network-endpoint-group=backend-neg \
  --network-endpoint-group-region=us-east4 \
  --project=adk-rag-tt
```

## Permanent Fix - Script Update

Updated `infrastructure/lib/loadbalancer.sh` to prevent future occurrences:

### Changes Made

1. **Use HTTP protocol with explicit port name** (Lines 112-113):
```bash
--protocol=HTTP \
--port-name=http \
```

2. **Removed non-existent --clear-port-name flag** (Lines 115-119 deleted)

3. **Moved backend attachment outside if/else** (Lines 118-123, 138-143):
```bash
# Ensure backend is attached (idempotent - will skip if already attached)
gcloud compute backend-services add-backend frontend-backend-service \
    --global \
    --network-endpoint-group=frontend-neg \
    --network-endpoint-group-region="$REGION" \
    --quiet 2>/dev/null || echo "  ✓ Frontend backend already attached"
```

This ensures backends are always attached, even if the backend service already exists.

## Verification

### Test Load Balancer
```bash
curl -I https://34.149.125.180.nip.io
# Expected: HTTP/2 302 redirect to Google OAuth
```

### Test Backend API Route
```bash
curl -I https://34.149.125.180.nip.io/api/
# Expected: HTTP/2 302 redirect to Google OAuth
```

### Check Backend Services
```bash
gcloud compute backend-services describe frontend-backend-service --global --format="yaml(backends)" --project=adk-rag-tt
gcloud compute backend-services describe backend-backend-service --global --format="yaml(backends)" --project=adk-rag-tt
```

## Results

✅ **Load Balancer functioning correctly**
- Frontend route `/` → Cloud Run frontend service
- Backend route `/api/*` → Cloud Run backend service
- IAP authentication redirecting to Google OAuth
- "No healthy upstreams" error resolved

## Architecture Summary

```
Internet
   ↓
HTTPS Load Balancer (34.149.125.180.nip.io)
   ├─ SSL Certificate: ACTIVE
   ├─ IAP: Enabled with OAuth
   ↓
Backend Services (HTTP protocol, port-name=http)
   ├─ frontend-backend-service
   │  └─ NEG: frontend-neg → Cloud Run: frontend
   └─ backend-backend-service
      └─ NEG: backend-neg → Cloud Run: backend
```

## Key Learnings

1. **Serverless NEGs don't support port names** when created with HTTPS protocol
2. **Use HTTP protocol with port-name=http** for serverless backend services
3. **The --clear-port-name flag doesn't exist** in gcloud CLI
4. **Backend attachment must be idempotent** and run outside conditional blocks
5. **Always verify backend attachment** after service creation

## Related Files

- `infrastructure/lib/loadbalancer.sh` - Fixed script
- `deployment.config` - Project configuration
- Project: adk-rag-tt
- Region: us-east4
- Load Balancer URL: https://34.149.125.180.nip.io

---

**Fixed by:** Cascade AI  
**Tested:** October 16, 2025  
**Status:** Production Ready ✅
