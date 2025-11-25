# Deployment Fix Summary

## Issue Identified

After updating `deploy-secure-v0.2.sh` to use `--ingress=internal-and-cloud-load-balancing`, the frontend was unable to reach the backend, resulting in:

```
Error: Preflight response is not successful. Status code: 404
Fetch API cannot load https://backend-xxx.run.app/api/auth/register
```

## Root Cause

The problem had two components:

### 1. **Frontend Built with Wrong URL**
`deploy-secure-v0.2.sh` builds the frontend with the **direct backend Cloud Run URL**:
```bash
gcloud builds submit ./frontend --config=frontend/cloudbuild.yaml \
  --substitutions=_IMAGE_NAME="$FRONTEND_IMAGE",_BACKEND_URL="$BACKEND_URL"
```

This bakes the direct backend URL into the JavaScript bundle at **build time**.

### 2. **Ingress Restriction Blocks Direct Access**
With `--ingress=internal-and-cloud-load-balancing`, the backend correctly rejects direct access:
- ✅ Load Balancer can access backend
- ❌ Frontend trying to access `backend-xxx.run.app` directly → **BLOCKED**

### 3. **Ineffective Environment Variable Update**
`deploy-complete-oauth-v0.2.sh` tried to set `NEXT_PUBLIC_BACKEND_URL` as a Cloud Run environment variable, but **Next.js `NEXT_PUBLIC_*` variables are baked at BUILD time, not RUN time**.

## Solution Implemented

### Changes to `deploy-complete-oauth-v0.2.sh`

#### **1. Added Service Account Definitions (Line 191-194)**
```bash
# Define service account names (matches deploy-secure-v0.2.sh)
export FRONTEND_SA="frontend-sa@$PROJECT_ID.iam.gserviceaccount.com"
export BACKEND_SA="backend-sa@$PROJECT_ID.iam.gserviceaccount.com"
export RAG_AGENT_SA="adk-rag-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"
```

#### **2. Replaced Ineffective Env Var Update with Frontend Rebuild (Line 644-664)**

**Old Code (Removed):**
```bash
echo -e "${YELLOW}🔧 Updating frontend backend URL...${NC}"
gcloud run services update frontend \
    --region="$REGION" \
    --set-env-vars="NEXT_PUBLIC_BACKEND_URL=$LOAD_BALANCER_URL"
```

**New Code (Added):**
```bash
echo -e "${YELLOW}🔨 Rebuilding frontend with Load Balancer URL...${NC}"
# CRITICAL: Next.js NEXT_PUBLIC_* variables are baked at BUILD time, not RUN time
# Must rebuild frontend with Load Balancer URL to support --ingress=internal-and-cloud-load-balancing
echo "Building frontend with NEXT_PUBLIC_BACKEND_URL=$LOAD_BALANCER_URL"

# Create new frontend image tag with LB URL
FRONTEND_IMAGE_LB="${FRONTEND_IMAGE}-lb"

gcloud builds submit ./frontend --config=frontend/cloudbuild.yaml \
  --substitutions=_IMAGE_NAME="$FRONTEND_IMAGE_LB",_BACKEND_URL="$LOAD_BALANCER_URL"

echo -e "${YELLOW}🚀 Redeploying frontend with Load Balancer URL...${NC}"
gcloud run deploy frontend \
  --image="$FRONTEND_IMAGE_LB" \
  --region="$REGION" \
  --service-account="$FRONTEND_SA" \
  --ingress=internal-and-cloud-load-balancing \
  --allow-unauthenticated \
  --cpu=1 --memory=512Mi --concurrency=80 \
  --min-instances=0 --max-instances=5 \
  --labels=app=adk-rag-agent,role=frontend,security=iap-protected
```

## How It Works Now

### **Complete Deployment Flow:**

```
1. deploy-secure-v0.2.sh runs:
   - Builds backend → backend-xxx.run.app (ingress: internal-and-cloud-load-balancing)
   - Builds frontend → with direct backend URL (temporary, will be rebuilt)
   - Deploys frontend (ingress: internal-and-cloud-load-balancing)

2. deploy-complete-oauth-v0.2.sh continues:
   - Creates Load Balancer → https://34.xx.xx.xx.nip.io
   - Provisions SSL certificate
   - Configures IAP
   
3. **NEW STEP: Frontend Rebuild**
   - Rebuilds frontend with NEXT_PUBLIC_BACKEND_URL=https://34.xx.xx.xx.nip.io
   - Redeploys frontend with correct URL baked into JavaScript

4. Updates backend CORS:
   - Sets FRONTEND_URL=https://34.xx.xx.xx.nip.io

5. Applies CORS breakthrough:
   - Grants allUsers to backend (for Load Balancer routing)
```

### **Expected Traffic Flow:**

```
User Browser
    ↓
https://34.xx.xx.xx.nip.io (Load Balancer)
    ↓
IAP Authentication ✅
    ↓
Frontend JavaScript calls: https://34.xx.xx.xx.nip.io/api/auth/register
    ↓
Load Balancer routes /api/* → Backend Cloud Run ✅
    ↓
Backend accepts (traffic from Load Balancer) ✅
    ↓
Backend CORS check: Origin matches FRONTEND_URL ✅
    ↓
Response sent back through Load Balancer ✅
```

## Security Architecture Preserved

The fix maintains all security layers:

### **Layer 1: Network Ingress Control**
- ✅ Both frontend and backend use `--ingress=internal-and-cloud-load-balancing`
- ✅ Direct internet access blocked
- ✅ Only Load Balancer can reach services

### **Layer 2: IAP Authentication**
- ✅ OAuth required at Load Balancer
- ✅ Organization domain restriction (@develom.com)
- ✅ No unauthenticated access

### **Layer 3: CORS Protection**
- ✅ Backend CORS only allows Load Balancer domain
- ✅ Prevents cross-origin attacks
- ✅ Browser-level security enforcement

### **Layer 4: IAM Configuration**
- ✅ Backend has `allUsers` (for Load Balancer routing)
- ✅ Combined with ingress restriction = secure
- ✅ Service accounts with least-privilege roles

## Testing the Fix

### **Run Complete Deployment:**
```bash
./infrastructure/deploy-complete-oauth-v0.2.sh
```

### **Expected Outcome:**
1. ✅ Frontend builds twice (once with backend URL, once with LB URL)
2. ✅ Frontend calls `https://34.xx.xx.xx.nip.io/api/*`
3. ✅ Load Balancer routes to backend
4. ✅ Backend processes requests
5. ✅ No CORS errors
6. ✅ No 404 preflight errors

### **Verification:**
```bash
# Check frontend environment
gcloud run services describe frontend --region=us-east4 --format="yaml(spec.template.spec.containers[0].image)"

# Should show: ...frontend:...-lb (new image with LB URL)

# Test the application
open https://34.xx.xx.xx.nip.io
```

## Key Lessons

1. **Next.js Build-Time Variables**: `NEXT_PUBLIC_*` environment variables must be present at build time, not runtime
2. **Ingress Restrictions Require Load Balancer**: Can't use `internal-and-cloud-load-balancing` with direct service URLs
3. **Frontend Must Target Load Balancer**: When using ingress restrictions, frontend must call Load Balancer URL
4. **Rebuild After Infrastructure**: Frontend needs to be rebuilt after Load Balancer URL is known

## Files Modified

- `infrastructure/deploy-complete-oauth-v0.2.sh`
  - Added service account definitions
  - Added frontend rebuild step with Load Balancer URL
  - Removed ineffective environment variable update
  - Added detailed logging

## Next Steps

1. Run the updated deployment script
2. Verify frontend builds with Load Balancer URL
3. Test authentication and API calls
4. Update SECURITY-ARCHITECTURE.md with deployment workflow
