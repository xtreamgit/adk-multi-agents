# Final Solution - FAILED_PRECONDITION Error Resolution

**Date:** December 8, 2025  
**Issue:** `400 FAILED_PRECONDITION` errors when accessing Vertex AI RAG  
**Status:** ✅ **RESOLVED**

---

## 📋 Executive Summary

The multi-agent RAG application was experiencing `FAILED_PRECONDITION` errors when users tried to interact with it. After extensive investigation, we discovered **two root causes** that both needed to be addressed:

1. **Code Issue:** The `Gemini()` model initialization was not explicitly passing the `location` parameter, causing it to default to `us-west2`
2. **Infrastructure Issue:** The Load Balancer was routing traffic to services in **three regions** (us-west1, us-west2, us-east4), but updates were only being deployed to `us-west1`

The solution required fixing both the code AND deploying to all regions.

> **⚠️ IMPORTANT NOTE:** The multi-region deployment (us-west1, us-west2, us-east4) was a **temporary emergency fix** to resolve the immediate issue. The **proper long-term solution** is to deploy only to `us-west1` and remove the other regions. See the "Future Recommendations" section below for cleanup instructions.

---

## 🐛 The Problem

### User Experience
When users accessed the application at `https://34.49.46.115.nip.io` and tried to:
- List corpora
- Send chat messages
- Query documents

They received this error:
```
Error: API request failed: {"detail":"Error processing request: 400 FAILED_PRECONDITION. 
{'error': {'code': 400, 'message': 'Precondition check failed.', 'status': 'FAILED_PRECONDITION'}}"}
```

### Technical Details
From the logs, we saw:
```
INFO:httpx:HTTP Request: POST https://us-west2-aiplatform.googleapis.com/v1beta1/projects/adk-rag-ma/locations/us-west2/...
google.genai.errors.ClientError: 400 FAILED_PRECONDITION
```

The backend was trying to connect to Vertex AI RAG in `us-west2`, which **is not supported** (requires Google allowlist).

---

## 🔍 Investigation Process

### Step 1: Verified Vertex AI RAG Region Support

Tested directly with Python:
```python
# us-west1 - WORKS
vertexai.init(project="adk-rag-ma", location="us-west1")
corpora = rag.list_corpora()  # ✅ Success: Found 1 corpus

# us-west2 - FAILS
vertexai.init(project="adk-rag-ma", location="us-west2")
corpora = rag.list_corpora()  # ❌ FAILED_PRECONDITION
```

**Confirmed:** Only `us-west1` is supported for Vertex AI RAG (without allowlist).

### Step 2: Checked Environment Variables

Cloud Run service configuration showed:
```yaml
GOOGLE_CLOUD_LOCATION: us-west1  ✅
VERTEXAI_LOCATION: us-west1      ✅
PROJECT_ID: adk-rag-ma           ✅
```

Environment variables were **correct**, so the issue was deeper.

### Step 3: Discovered Code Issue

Found that `Gemini()` model initialization was missing the `location` parameter:

**Before (Wrong):**
```python
vertex_model = Gemini(model="gemini-2.5-flash")  # ❌ Defaults to us-west2
```

**After (Correct):**
```python
vertex_model = Gemini(model="gemini-2.5-flash", location=config.LOCATION)  # ✅ Explicit
```

### Step 4: Fixed Code and Rebuilt

Updated **7 agent files**:
- `backend/src/rag_agent/agent.py`
- `backend/config/agent1/agent.py`
- `backend/config/agent2/agent.py`
- `backend/config/agent3/agent.py`
- `backend/config/develom/agent.py`
- `backend/config/usfs/agent.py`
- `backend/config/tt/agent.py`

Rebuilt with `--no-cache` to ensure changes were included.

### Step 5: Still Failed - Discovered Infrastructure Issue

After deploying to `us-west1`, users **still** got errors. Investigation revealed:

**The Load Balancer had backends in THREE regions:**
```bash
gcloud compute backend-services describe backend-backend-service --global

backends:
- group: us-east4/networkEndpointGroups/backend-neg  ❌ Old code
- group: us-west2/networkEndpointGroups/backend-neg  ❌ Old code  
- group: us-west1/networkEndpointGroups/backend-neg  ✅ New code
```

**All Cloud Run services existed in 3 regions:**
```
SERVICE         REGION    STATUS
backend         us-east4  ❌ Old revision with us-west2
backend         us-west1  ✅ New revision with us-west1
backend         us-west2  ❌ Old revision with us-west2
backend-agent1  us-east4  ❌ Old revision
backend-agent1  us-west1  ✅ New revision
backend-agent1  us-west2  ❌ Old revision
(and so on...)
```

The Load Balancer was **randomly routing** traffic to all three regions. When requests hit `us-west2` or `us-east4` services, they used old code that tried to connect to Vertex AI in the wrong region.

---

## ✅ The Final Solution

### Fix #1: Code Changes

Added explicit `location` parameter to all `Gemini()` initializations:

**File: `backend/src/rag_agent/agent.py`**
```python
from . import config

# Set environment variables
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
os.environ["VERTEXAI_PROJECT"] = config.PROJECT_ID
os.environ["VERTEXAI_LOCATION"] = config.LOCATION

print(f"DEBUG agent.py: Using PROJECT_ID={config.PROJECT_ID}, LOCATION={config.LOCATION}")

# Configure Vertex AI model - explicitly pass location
vertex_model = Gemini(model="gemini-2.5-flash", location=config.LOCATION)
```

Applied the same pattern to all 7 agent files.

### Fix #2: Multi-Region Deployment

Deployed updated code to **ALL regions** where services exist:

```bash
source ./deployment.config

# Deploy to ALL regions
for region in us-west1 us-west2 us-east4; do
  for service in backend backend-agent1 backend-agent2 backend-agent3; do
    gcloud run services update $service \
      --image="$BACKEND_IMAGE" \
      --region=$region \
      --project=adk-rag-ma \
      --update-env-vars="GOOGLE_CLOUD_LOCATION=us-west1,VERTEXAI_LOCATION=us-west1" \
      --quiet
  done
done
```

**Critical:** Even services in `us-west2` and `us-east4` now use `GOOGLE_CLOUD_LOCATION=us-west1`, so they connect to Vertex AI RAG in the supported `us-west1` region.

### Fix #3: Docker Build Configuration

Updated `cloudbuild.yaml` to use `--no-cache` to ensure code changes are always picked up:

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '--no-cache', '-t', '${_BACKEND_IMAGE}', '.']
    dir: '.'
images:
  - '${_BACKEND_IMAGE}'
```

---

## 🧪 Verification

### Test 1: Application Works
✅ Users can now:
- List corpora successfully
- Send chat messages without errors
- Query documents normally

### Test 2: Correct Region Usage
Check logs to confirm all services use `us-west1`:

```bash
gcloud logging read 'textPayload:"Initializing Vertex AI"' \
  --project=adk-rag-ma --limit=10 --freshness=10m

# Expected output:
Initializing Vertex AI with project=adk-rag-ma, location=us-west1 ✅
```

### Test 3: No More FAILED_PRECONDITION Errors
```bash
gcloud logging read 'textPayload:"FAILED_PRECONDITION"' \
  --project=adk-rag-ma --limit=5 --freshness=10m

# Expected: No results (or only old errors)
```

### Test 4: API Calls Use us-west1
```bash
gcloud logging read 'textPayload:"us-west1-aiplatform.googleapis.com"' \
  --project=adk-rag-ma --limit=5 --freshness=10m

# Expected: Should see API calls to us-west1 ✅
```

---

## 📊 Architecture After Fix

```
┌─────────────────────────────────────────────────────────────┐
│                     Load Balancer                            │
│              https://34.49.46.115.nip.io                    │
└────────────┬──────────────┬──────────────┬─────────────────┘
             │              │              │
    ┌────────▼─────┐ ┌─────▼──────┐ ┌────▼─────────┐
    │ us-west1     │ │ us-west2   │ │ us-east4     │
    │ backend      │ │ backend    │ │ backend      │
    │ (new code)   │ │ (new code) │ │ (new code)   │
    └──────┬───────┘ └──────┬─────┘ └──────┬───────┘
           │                │                │
           │  All services use env var:     │
           │  GOOGLE_CLOUD_LOCATION=us-west1│
           │                │                │
           └────────────────┼────────────────┘
                            │
                  ┌─────────▼────────────┐
                  │   Vertex AI RAG      │
                  │   (us-west1 only)    │
                  │   ✅ Supported       │
                  └──────────────────────┘
```

**Key Point:** All backend services in all regions now connect to Vertex AI in `us-west1`, regardless of where the service itself is deployed.

---

## 📝 Lessons Learned

### 1. **Avoid Unnecessary Multi-Region Deployments**
Multi-region deployments add significant complexity and should only be used when necessary (e.g., for geographic redundancy, disaster recovery).

**Problem:** Services were deployed to 3 regions during testing and never cleaned up, causing:
- 3x the infrastructure costs
- 3x the deployment complexity
- Higher chance of inconsistencies

**Lesson:** Clean up test/development resources immediately. Don't leave services running in multiple regions unless there's a business requirement.

**If you DO need multi-region:** When using a global Load Balancer with backends in multiple regions, **all regions must be updated** when deploying new code:
```bash
# Only if multi-region is actually needed
for region in us-west1 us-west2 us-east4; do
  # deploy to each region
done
```

### 2. **Explicit Configuration is Better Than Implicit**
Even when environment variables are set correctly, SDK calls should explicitly pass parameters:

**❌ Bad:**
```python
vertex_model = Gemini(model="gemini-2.5-flash")  # Relies on defaults
```

**✅ Good:**
```python
vertex_model = Gemini(model="gemini-2.5-flash", location=config.LOCATION)
```

### 3. **Verify Full Request Path**
The error appeared to be in the application code, but the root cause was in the infrastructure (Load Balancer routing). Always check:
- ✅ Code configuration
- ✅ Container environment variables
- ✅ Service deployment status
- ✅ Load Balancer routing
- ✅ Which service revision is actually serving traffic

### 4. **Regional Service Restrictions**
Not all Google Cloud services are available in all regions. When encountering `FAILED_PRECONDITION` errors:
1. Check service availability in the region
2. Use supported regions even if app is deployed elsewhere
3. Set environment variables to point to supported regions

### 5. **Docker Cache Can Hide Issues**
Using `--no-cache` during builds ensures code changes are always picked up, preventing confusion when old cached layers are reused.

---

## 🔧 Deployment Commands Reference

### Full Deployment to All Regions

```bash
#!/bin/bash
# Complete deployment script

source ./deployment.config

# 1. Build backend image with no cache
gcloud builds submit ./backend \
  --config=backend/cloudbuild.yaml \
  --substitutions=_BACKEND_IMAGE="$BACKEND_IMAGE" \
  --project=adk-rag-ma

# 2. Deploy to ALL regions
for region in us-west1 us-west2 us-east4; do
  echo "Deploying to region: $region"
  
  for service in backend backend-agent1 backend-agent2 backend-agent3; do
    echo "  Updating service: $service"
    gcloud run services update $service \
      --image="$BACKEND_IMAGE" \
      --region=$region \
      --project=adk-rag-ma \
      --update-env-vars="GOOGLE_CLOUD_LOCATION=us-west1,VERTEXAI_LOCATION=us-west1" \
      --quiet
  done
done

echo "✅ Deployment complete!"
```

### Verification Commands

```bash
# Check which regions have services
gcloud run services list --project=adk-rag-ma \
  --format='table(SERVICE,REGION,URL)'

# Check traffic routing for each region
for region in us-west1 us-west2 us-east4; do
  echo "Region: $region"
  gcloud run services describe backend \
    --region=$region \
    --project=adk-rag-ma \
    --format='value(status.latestReadyRevisionName)'
done

# Check Load Balancer backends
gcloud compute backend-services describe backend-backend-service \
  --global --project=adk-rag-ma \
  --format='yaml(backends)'

# Check for errors in logs
gcloud logging read 'textPayload:"FAILED_PRECONDITION"' \
  --project=adk-rag-ma --limit=10 --freshness=10m
```

---

## 🎯 Future Recommendations

### 1. Simplify Architecture (HIGHLY RECOMMENDED)
**Action Required:** The current multi-region deployment is unnecessary and wasteful. You should deploy only to `us-west1` and remove other regions from Load Balancer.

**Why this happened:** Services were deployed to multiple regions during testing/development phases and were never cleaned up. This is NOT the intended architecture.

**To clean up, run:**
```bash
./cleanup-regions.sh
```

This will remove services from `us-west2` and `us-east4`, keeping only `us-west1`.

**Original recommendation:** Deploy only to `us-west1` and remove other regions from Load Balancer:

```bash
# Remove us-west2 and us-east4 backends from Load Balancer
gcloud compute backend-services remove-backend backend-backend-service \
  --network-endpoint-group=backend-neg \
  --network-endpoint-group-region=us-west2 \
  --global

# Then delete unused services
gcloud run services delete backend --region=us-west2
gcloud run services delete backend --region=us-east4
```

**Pros:**
- Simpler deployment (only one region)
- No risk of stale code in other regions
- Lower costs (fewer service instances)

**Cons:**
- Less geographic redundancy
- Higher latency for users far from us-west1

### 2. Implement Deployment Pipeline
Create a CI/CD pipeline that:
- ✅ Runs tests before deploying
- ✅ Builds with `--no-cache`
- ✅ Deploys to ALL regions automatically
- ✅ Verifies deployment success
- ✅ Runs smoke tests after deployment

### 3. Add Health Checks with Region Info
Update health check endpoint to return:
```json
{
  "status": "healthy",
  "service_region": "us-west1",
  "vertexai_region": "us-west1",
  "revision": "backend-00018-824"
}
```

This makes debugging multi-region issues easier.

### 4. Monitor Region-Specific Metrics
Set up alerts for:
- FAILED_PRECONDITION errors by region
- API latency to Vertex AI by service region
- Traffic distribution across regions

---

## 📚 Related Documentation

- **`DEPLOYMENT-STATUS.md`** - Current deployment status and health check
- **`RESOLVED-VERTEX-AI-ISSUES.md`** - Previous Vertex AI issues and solutions
- **`REGION-FIX-SUMMARY.md`** - Initial attempt to fix region issue (partial solution)
- **`MULTI-AGENT-RUNBOOK.md`** - Operational runbook for multi-agent system
- **`TROUBLESHOOTING-VERTEX-AI.md`** - Vertex AI troubleshooting guide

---

## ✅ Resolution Confirmation

**Problem:** `FAILED_PRECONDITION` errors when accessing Vertex AI RAG  
**Root Causes:**  
1. ❌ Gemini model not explicitly configured with location parameter
2. ❌ Load Balancer routing to services in multiple regions with inconsistent code

**Solution:**  
1. ✅ Added `location=config.LOCATION` to all Gemini() initializations
2. ✅ Deployed updated code to ALL regions (us-west1, us-west2, us-east4)
3. ✅ Set explicit environment variable `GOOGLE_CLOUD_LOCATION=us-west1` in all regions

**Status:** ✅ **RESOLVED - Application fully functional**

**Verified By:**
- ✅ User confirmed application works without errors
- ✅ Logs show all services using `us-west1` for Vertex AI
- ✅ No FAILED_PRECONDITION errors in recent logs
- ✅ All backend services successfully deployed

**Date Resolved:** December 8, 2025, 11:37 PM PST

---

## 🙏 Acknowledgments

This issue required systematic investigation through multiple layers of the stack (code, containers, services, infrastructure). The resolution demonstrates the importance of:
- Thorough log analysis
- Understanding the full deployment architecture
- Testing at each layer
- Not assuming the first fix will be complete

**Thank you for your patience through the debugging process!** 🎉
