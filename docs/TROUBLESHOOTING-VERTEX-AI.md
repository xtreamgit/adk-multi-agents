# Vertex AI RAG Troubleshooting Guide

**Date:** 2025-11-26  
**Issue:** FAILED_PRECONDITION errors when connecting to Vertex AI RAG

---

## Root Cause Analysis

### Issue 1: Region Access Restricted ✅ FIXED
**Error:** `400 FAILED_PRECONDITION` and allowlist requirement

**Cause:** As of Nov 2025, Vertex AI RAG Engine has the following regional restrictions:

**Restricted (Requires Allowlist):**
- 🔒 **us-central1** - Allowlist required
- 🔒 **us-east4** - Allowlist required

**Available (No Restrictions):**
- ✅ **us-west1** (Oregon) - **RECOMMENDED**
- ✅ **us-west4** (Las Vegas)
- ✅ **europe-west1** (Belgium)
- ✅ **europe-west4** (Netherlands)
- ✅ **asia-southeast1** (Singapore)

**Not Supported:**
- ❌ **us-west2** - RAG not available at all

**Fix Applied:** Changed `deployment.config` to use `REGION="us-west1"` which is available without restrictions

### Issue 2: No RAG Corpora Exist ✅ FIXED
**Initial Status:** Project had 0 RAG corpora

**Fix Applied:** Created initial test corpus in `us-west1`:
- Corpus name: `test-corpus`
- Display name: `test-corpus`
- Created: 2025-11-26

**Note:** You can create additional corpora through the application UI or via the agent's tools once deployed.

---

## Next Steps to Resolve

### Step 1: Verify Configuration
```bash
# Source the fixed configuration
source ./deployment.config

# Should output: us-east4
echo "Region: $REGION"
echo "Project: $PROJECT_ID"
```

### Step 2: Verify Vertex AI API is Enabled
```bash
gcloud services list --enabled --filter="aiplatform" --project=adk-rag-ma
```

Expected output:
```
NAME                       TITLE
aiplatform.googleapis.com  Vertex AI API
```

### Step 3: Create Your First RAG Corpus

You have two options:

#### Option A: Create corpus via the UI (once deployed)
1. Deploy the application: `./infrastructure/deploy-all.sh`
2. Access the app via load balancer URL
3. Use the agent's built-in `create_corpus` tool through chat
4. Example prompt: "Please create a corpus named 'my-test-corpus'"

#### Option B: Create corpus via Python script
```bash
cd backend

# Create a test corpus
python3 << 'EOF'
import vertexai
from vertexai import rag
import google.auth

credentials, _ = google.auth.default()
vertexai.init(project='adk-rag-ma', location='us-east4', credentials=credentials)

# Create corpus
embedding_config = rag.RagEmbeddingModelConfig(
    vertex_prediction_endpoint=rag.VertexPredictionEndpoint(
        publisher_model="publishers/google/models/text-embedding-005"
    )
)

corpus = rag.create_corpus(
    display_name="test-corpus",
    backend_config=rag.RagVectorDbConfig(
        rag_embedding_model_config=embedding_config
    )
)

print(f"✅ Created corpus: {corpus.name}")
print(f"   Display name: {corpus.display_name}")
EOF
```

### Step 4: Verify Corpus Creation
```bash
python3 << 'EOF'
import vertexai
from vertexai import rag
import google.auth

credentials, _ = google.auth.default()
vertexai.init(project='adk-rag-ma', location='us-east4', credentials=credentials)

corpora = list(rag.list_corpora())
print(f"Found {len(corpora)} corpora:")
for corpus in corpora:
    print(f"  - {corpus.name}")
    print(f"    Display: {corpus.display_name}")
EOF
```

### Step 5: Add Data to Corpus (Optional)

Once you have a corpus, you can add documents to it. The application provides tools for this:
- `add_data` - Import files from GCS bucket
- `import_files` - Import specific files

Example via UI:
```
"Please import files from gs://my-bucket/documents/ into corpus 'test-corpus'"
```

### Step 6: Redeploy Application
```bash
# From repo root
source ./deployment.config
./infrastructure/deploy-all.sh
```

---

## Common Errors Reference

### Error: "Vertex AI Rag Service is not supported in region X"
**Solution:** Only use `us-central1` or `us-east4` for `REGION` in `deployment.config`

### Error: "Failed to list corpora" or "No corpora found"
**Solution:** Create at least one corpus (see Step 3 above)

### Error: "Permission denied" when accessing corpus
**Solution:** Verify service account IAM permissions:
```bash
# Check service account has aiplatform.user role
gcloud projects get-iam-policy adk-rag-ma \
  --flatten="bindings[].members" \
  --filter="bindings.members:adk-rag-agent-sa@adk-rag-ma.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

### Error: "Corpus not found" in specific agent
**Cause:** Agent configuration might reference a non-existent corpus
**Solution:** Check `backend/config/{agent}/config.py` for `DEFAULT_CORPUS_NAME`

---

## Verification Checklist

- [ ] Region is set to `us-east4` in `deployment.config`
- [ ] Vertex AI API is enabled in project
- [ ] At least one RAG corpus exists
- [ ] Corpus has data imported (documents/files)
- [ ] Service accounts have proper IAM permissions
- [ ] Application deployed successfully
- [ ] Can access app via load balancer URL
- [ ] Can query corpus and get responses

---

## Additional Resources

- **Vertex AI RAG Documentation:** https://cloud.google.com/vertex-ai/generative-ai/docs/rag-overview
- **Supported Regions:** https://cloud.google.com/vertex-ai/generative-ai/docs/locations
- **Multi-Agent Runbook:** `docs/MULTI-AGENT-RUNBOOK.md`
- **Architecture Plan:** `docs/MULTIPLE-AGENT-PLAN.md`

---

## Quick Recovery Commands

```bash
# 1. Check current config
source ./deployment.config
echo "Region: $REGION (should be us-east4)"

# 2. List corpora
python3 -c "
import vertexai
from vertexai import rag
import google.auth
credentials, _ = google.auth.default()
vertexai.init(project='adk-rag-ma', location='us-east4', credentials=credentials)
corpora = list(rag.list_corpora())
print(f'{len(corpora)} corpora found')
"

# 3. Create test corpus if needed
python3 backend/src/rag_agent/tools/create_corpus.py

# 4. Redeploy
./infrastructure/deploy-all.sh
```
