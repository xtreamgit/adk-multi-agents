# ✅ Vertex AI Issues - RESOLVED

**Date:** 2025-11-26  
**Status:** All blocking issues resolved. Ready to deploy.

---

## Issues Identified and Fixed

### 1. ✅ Region Configuration Issues
- **Original problem:** Changed to `us-west2` which doesn't support RAG at all
- **Discovery:** `us-east4` (original region) now requires Google allowlist
- **Solution:** Switched to `us-west1` which supports RAG without restrictions

### 2. ✅ No RAG Corpora
- **Original problem:** Project had 0 RAG corpora
- **Solution:** Created test corpus `test-corpus` in `us-west1`
- **Verification:** Confirmed corpus exists and is accessible

---

## Current Configuration

```bash
PROJECT_ID="adk-rag-ma"
REGION="us-west1"  # Oregon - RAG available without restrictions
```

**Corpus Created:**
- Name: `test-corpus`
- Location: `us-west1`
- Created: 2025-11-26 17:41 UTC
- Status: Ready to use

---

## Next Steps: Deploy and Test

### 1. Load Configuration
```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents
source ./deployment.config
```

### 2. Verify Configuration
```bash
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
```

Expected output:
```
Project: adk-rag-ma
Region: us-west1
```

### 3. Deploy All Services
```bash
./infrastructure/deploy-all.sh
```

This will:
- ✅ Enable required APIs
- ✅ Create/configure IAM service accounts
- ✅ Build and deploy backend services (backend, backend-agent1, backend-agent2, backend-agent3)
- ✅ Build and deploy frontend
- ✅ Configure load balancer with path routing
- ✅ Enable IAP for secure access

**Expected deployment time:** 10-15 minutes

### 4. Access the Application

After deployment completes:

1. **Get the Load Balancer URL** from the deployment output or:
   ```bash
   gcloud compute addresses describe rag-agent-ip --global --format="value(address)"
   ```

2. **Open in browser:**
   ```
   https://<STATIC_IP>.nip.io
   ```

3. **Sign in via IAP** using `hector@develom.com`

4. **Test multi-agent functionality:**
   - Use the sidebar agent selector
   - Switch between: Default, Agent 1, Agent 2, Agent 3
   - Each agent should respond independently

### 5. Test RAG Corpus Access

Once logged in, try these queries:

```
"List all available corpora"
```

Expected: Should show `test-corpus`

```
"What corpora do I have access to?"
```

Expected: Agent should list the test corpus

---

## Verified Regional Information

### ✅ Regions Supporting RAG (No Allowlist Required)
- **us-west1** (Oregon) - ⭐ Currently using
- **us-west4** (Las Vegas)
- **europe-west1** (Belgium)
- **europe-west4** (Netherlands)
- **asia-southeast1** (Singapore)

### 🔒 Restricted Regions (Allowlist Required)
- **us-central1** - Restricted due to capacity
- **us-east4** - Restricted due to capacity

To request allowlist access for restricted regions:
- Email: vertex-ai-rag-engine-support@google.com
- Include: Project ID, preferred region, use case

### ❌ Unsupported Regions
- **us-west2** - RAG service not available
- **Most other regions** - RAG service not available

---

## Adding More Corpora (Optional)

### Via Application UI (Recommended)
Once deployed, you can create additional corpora through the chat interface:

```
"Create a new corpus named 'my-documents'"
```

### Via Python Script
```python
import vertexai
from vertexai import rag
import google.auth

credentials, _ = google.auth.default()
vertexai.init(project='adk-rag-ma', location='us-west1', credentials=credentials)

embedding_config = rag.RagEmbeddingModelConfig(
    vertex_prediction_endpoint=rag.VertexPredictionEndpoint(
        publisher_model="publishers/google/models/text-embedding-005"
    )
)

corpus = rag.create_corpus(
    display_name="my-documents",
    backend_config=rag.RagVectorDbConfig(
        rag_embedding_model_config=embedding_config
    )
)

print(f"Created corpus: {corpus.name}")
```

### Via gcloud CLI
```bash
# First, enable the Vertex AI RAG API
gcloud services enable aiplatform.googleapis.com --project=adk-rag-ma

# Create corpus via API (requires additional setup)
# Recommended to use UI or Python methods above instead
```

---

## Importing Documents into Corpus

After creating a corpus, you can import documents:

### Option 1: Via Application Chat
```
"Import files from gs://my-bucket/documents/ into corpus 'my-documents'"
```

### Option 2: Via Python
```python
from vertexai import rag

# Import from GCS bucket
rag.import_files(
    corpus_name="projects/adk-rag-ma/locations/us-west1/ragCorpora/YOUR_CORPUS_ID",
    paths=["gs://your-bucket/path/to/documents/"],
    chunk_size=512,
    chunk_overlap=100
)
```

---

## Monitoring and Logs

### View Backend Logs
```bash
# Default backend
gcloud logs read --project=adk-rag-ma --limit=50 \
  --filter='resource.type="cloud_run_revision" AND resource.labels.service_name="backend"'

# Agent 1 backend
gcloud logs read --project=adk-rag-ma --limit=50 \
  --filter='resource.type="cloud_run_revision" AND resource.labels.service_name="backend-agent1"'
```

### Check Service Status
```bash
gcloud run services list --region=us-west1 --project=adk-rag-ma
```

### Verify Load Balancer
```bash
gcloud compute url-maps describe rag-agent-url-map --global --project=adk-rag-ma
```

---

## Troubleshooting

If you encounter issues during deployment:

1. **Check deployment logs** in the console output
2. **Verify APIs are enabled:**
   ```bash
   gcloud services list --enabled --project=adk-rag-ma
   ```
3. **Check service account permissions:**
   ```bash
   gcloud projects get-iam-policy adk-rag-ma
   ```
4. **View detailed troubleshooting guide:**
   - See `docs/TROUBLESHOOTING-VERTEX-AI.md`
   - See `docs/MULTI-AGENT-RUNBOOK.md`

---

## Summary

✅ **Region:** Changed to `us-west1` (supports RAG without allowlist)  
✅ **Corpus:** Created `test-corpus` in `us-west1`  
✅ **Configuration:** Updated `deployment.config` with correct settings  
✅ **Ready:** All prerequisites met for deployment

**You can now deploy the application using:**
```bash
./infrastructure/deploy-all.sh
```

---

## Documentation References

- **Multi-Agent Runbook:** `docs/MULTI-AGENT-RUNBOOK.md`
- **Architecture Plan:** `docs/MULTIPLE-AGENT-PLAN.md`
- **Troubleshooting Guide:** `docs/TROUBLESHOOTING-VERTEX-AI.md`
- **Main README:** `README.md`
