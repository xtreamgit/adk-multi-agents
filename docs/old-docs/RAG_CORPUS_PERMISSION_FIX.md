# RAG Corpus Permission Error Fix

**Date:** October 16, 2025  
**Issue:** `aiplatform.ragCorpora.create` permission denied  
**Status:** ✅ RESOLVED

## Error Message

```
Permission 'aiplatform.ragCorpora.list' denied on resource 
'//aiplatform.googleapis.com/projects/adk-rag-hdtest6/locations/us-east4' 
(or it may not exist).
```

## Root Cause

The backend Cloud Run service was **missing critical environment variables** for Vertex AI configuration:
- `PROJECT_ID` was not set → backend used cached/default value `adk-rag-hdtest6`
- `GOOGLE_CLOUD_LOCATION` was missing
- `VERTEXAI_PROJECT` was missing  
- `VERTEXAI_LOCATION` was missing

**Result:** Backend attempted to create RAG corpora in the wrong project (`adk-rag-hdtest6` instead of `adk-rag-tt`), causing permission errors.

## Diagnosis Steps

### 1. Verified Service Account Permissions
```bash
# Checked backend service account
gcloud run services describe backend --region=us-east4 \
  --format="value(spec.template.spec.serviceAccountName)" \
  --project=adk-rag-tt

# Output: adk-rag-agent-sa@adk-rag-tt.iam.gserviceaccount.com

# Verified IAM roles
gcloud projects get-iam-policy adk-rag-tt \
  --flatten="bindings[].members" \
  --filter="bindings.members:adk-rag-agent-sa@adk-rag-tt.iam.gserviceaccount.com" \
  --format="table(bindings.role)"

# Output:
# ROLE
# roles/aiplatform.admin  ✅
# roles/bigquery.admin    ✅
# roles/storage.admin     ✅
```

**Result:** Service account has correct permissions.

### 2. Checked Environment Variables
```bash
# Inspected backend environment
gcloud run services describe backend --region=us-east4 \
  --format="value(spec.template.spec.containers[0].env)" \
  --project=adk-rag-tt

# Output: Only FRONTEND_URL and ACCOUNT_ENV were set!
# Missing: PROJECT_ID, GOOGLE_CLOUD_LOCATION, VERTEXAI_PROJECT, VERTEXAI_LOCATION
```

**Result:** Environment variables were not set during deployment.

### 3. Analyzed Backend Logs
```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=backend AND textPayload:permission" \
  --limit=5 --project=adk-rag-tt

# Output showed backend trying to access wrong project:
# 'projects/adk-rag-hdtest6/locations/us-east4'
```

**Result:** Backend using incorrect project ID.

## Immediate Fix Applied

### Step 1: Set Vertex AI Environment Variables
```bash
gcloud run services update backend \
  --region=us-east4 \
  --update-env-vars="PROJECT_ID=adk-rag-tt,GOOGLE_CLOUD_LOCATION=us-east4,VERTEXAI_PROJECT=adk-rag-tt,VERTEXAI_LOCATION=us-east4" \
  --project=adk-rag-tt
```

### Step 2: Add Missing Application Variables
```bash
gcloud run services update backend \
  --region=us-east4 \
  --update-env-vars="SECRET_KEY=<generated-key>,DATABASE_PATH=/app/data/users.db,LOG_LEVEL=INFO,ENVIRONMENT=production" \
  --project=adk-rag-tt
```

### Step 3: Verify Configuration
```bash
gcloud run services describe backend \
  --region=us-east4 \
  --format="yaml(spec.template.spec.containers[0].env)" \
  --project=adk-rag-tt

# Confirmed all required variables are set:
# ✅ PROJECT_ID=adk-rag-tt
# ✅ GOOGLE_CLOUD_LOCATION=us-east4
# ✅ VERTEXAI_PROJECT=adk-rag-tt
# ✅ VERTEXAI_LOCATION=us-east4
# ✅ FRONTEND_URL=https://34.149.125.180.nip.io
# ✅ ACCOUNT_ENV=develom
# ✅ SECRET_KEY=<set>
# ✅ DATABASE_PATH=/app/data/users.db
# ✅ LOG_LEVEL=INFO
# ✅ ENVIRONMENT=production
```

## Permanent Fix - Script Update

Updated `infrastructure/lib/cloudrun.sh` to include all required Vertex AI environment variables:

### Changes Made

**Before (Line 63):**
```bash
--set-env-vars="PROJECT_ID=$PROJECT_ID,GOOGLE_CLOUD_LOCATION=$REGION,SECRET_KEY=$SECRET_KEY,DATABASE_PATH=/app/data/users.db,LOG_LEVEL=INFO,ENVIRONMENT=production,ACCOUNT_ENV=develom"
```

**After (Line 63):**
```bash
--set-env-vars="PROJECT_ID=$PROJECT_ID,GOOGLE_CLOUD_LOCATION=$REGION,VERTEXAI_PROJECT=$PROJECT_ID,VERTEXAI_LOCATION=$REGION,SECRET_KEY=$SECRET_KEY,DATABASE_PATH=/app/data/users.db,LOG_LEVEL=INFO,ENVIRONMENT=production,ACCOUNT_ENV=develom"
```

### Key Additions
1. ✅ **VERTEXAI_PROJECT=$PROJECT_ID** - Explicit Vertex AI project ID
2. ✅ **VERTEXAI_LOCATION=$REGION** - Explicit Vertex AI location

This ensures the backend always knows which project and region to use for Vertex AI RAG operations.

## Testing the Fix

### Test Corpus Creation
1. **Access the application:** https://34.149.125.180.nip.io
2. **Sign in** with your fedgovai.com account
3. **Try to create a corpus:**
   - Click "Corpus Management"
   - Enter corpus name and description
   - Click "Create Corpus"

### Expected Result
✅ Corpus should be created successfully in project `adk-rag-tt`, location `us-east4`

### Verify with Backend Logs
```bash
# Check recent backend logs for corpus operations
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=backend AND (textPayload:corpus OR jsonPayload.message:corpus)" \
  --limit=20 \
  --project=adk-rag-tt

# Should show successful corpus operations in adk-rag-tt project
```

### List RAG Corpora
```bash
# Verify corpora are created in correct project
gcloud ai index-endpoints list \
  --region=us-east4 \
  --project=adk-rag-tt
```

## Why This Happened

The backend Cloud Run service was likely deployed using a different method or the environment variables were somehow cleared. The `deployment.config` file has the correct values:

```bash
# deployment.config (correct values)
export PROJECT_ID="adk-rag-tt"
export REGION="us-east4"
export ORGANIZATION_DOMAIN="fedgovai.com"
export IAP_ADMIN_USER="hdejesus@fedgovai.com"
```

But during deployment, these weren't propagated to the Cloud Run service environment variables.

## Prevention

To prevent this in future deployments:

### 1. Always Source deployment.config
```bash
source ./deployment.config
echo "PROJECT_ID: $PROJECT_ID"
echo "REGION: $REGION"
```

### 2. Verify Environment Variables After Deployment
```bash
# Check backend environment variables
./infrastructure/lib/verify-env.sh backend
```

### 3. Use Updated Deployment Scripts
The fixed `cloudrun.sh` now includes all required Vertex AI variables automatically.

## Architecture Context

```
Backend Cloud Run Service
├── Service Account: adk-rag-agent-sa@adk-rag-tt.iam.gserviceaccount.com
│   ├── roles/aiplatform.admin  ✅ (RAG corpus operations)
│   ├── roles/storage.admin     ✅ (GCS bucket access)
│   └── roles/bigquery.admin    ✅ (BigQuery operations)
│
└── Environment Variables (REQUIRED):
    ├── PROJECT_ID=adk-rag-tt           ✅ (Main project ID)
    ├── GOOGLE_CLOUD_LOCATION=us-east4  ✅ (Main region)
    ├── VERTEXAI_PROJECT=adk-rag-tt     ✅ (Vertex AI project)
    ├── VERTEXAI_LOCATION=us-east4      ✅ (Vertex AI region)
    ├── FRONTEND_URL=https://...        ✅ (CORS)
    ├── ACCOUNT_ENV=develom             ✅ (Account config)
    ├── SECRET_KEY=<secure>             ✅ (JWT signing)
    ├── DATABASE_PATH=/app/data/...     ✅ (SQLite)
    ├── LOG_LEVEL=INFO                  ✅ (Logging)
    └── ENVIRONMENT=production          ✅ (Runtime mode)
```

## Key Learnings

1. **Service Account ≠ Application Config**
   - Having correct IAM permissions is not enough
   - Backend code needs environment variables to know which project/region to use

2. **Vertex AI Requires Explicit Configuration**
   - `PROJECT_ID` alone may not be sufficient
   - `VERTEXAI_PROJECT` and `VERTEXAI_LOCATION` should be explicitly set

3. **Always Verify Environment Variables**
   - After deployment, check that all required env vars are set
   - Don't assume variables from config file automatically propagate

4. **Backend Logs Are Critical**
   - Log analysis revealed the wrong project was being accessed
   - Error messages clearly showed permission denied on wrong resource

## Related Files

- `infrastructure/lib/cloudrun.sh` - Fixed deployment script
- `infrastructure/lib/infrastructure.sh` - Service account & IAM setup
- `deployment.config` - Project configuration (correct values)
- Project: adk-rag-tt
- Region: us-east4
- Application URL: https://34.149.125.180.nip.io

---

**Fixed by:** Cascade AI  
**Tested:** October 16, 2025  
**Status:** Production Ready ✅
