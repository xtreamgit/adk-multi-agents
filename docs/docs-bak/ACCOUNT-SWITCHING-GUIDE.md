# Multi-Account Configuration Quick Reference

**Date**: 2025-10-10  
**Current Setup**: Multi-account support enabled

---

## 📋 Available Accounts

| Account | Name | Organization | Default Corpus | Agent Name |
|---------|------|--------------|----------------|------------|
| `develom` | Develom Root | develom.com | develom-general | RagAgent |
| `usfs` | U.S. Forest Service | usda.gov | usfs-forest-service | USFSRagAgent |
| `tt` | TechTrend | techtrend.com | techtrend-general | TechTrendRAGAgent |

---

## 🔄 How to Switch Accounts

### Method 1: Update Dockerfile (Recommended for Production)

Edit `backend/Dockerfile` line 39:

```dockerfile
# For Develom (default)
ENV ACCOUNT_ENV=develom

# For USFS
ENV ACCOUNT_ENV=usfs

# For TechTrend
ENV ACCOUNT_ENV=tt
```

Then rebuild and deploy:
```bash
docker build -t rag-backend backend/
```

### Method 2: Override at Deployment (Recommended for Testing)

When deploying to Cloud Run:

```bash
# Deploy with Develom account
gcloud run deploy backend \
  --image=... \
  --set-env-vars="ACCOUNT_ENV=develom,PROJECT_ID=adk-rag-hdtest6,..."

# Deploy with USFS account
gcloud run deploy backend \
  --image=... \
  --set-env-vars="ACCOUNT_ENV=usfs,PROJECT_ID=adk-rag-hdtest6,..."

# Deploy with TechTrend account
gcloud run deploy backend \
  --image=... \
  --set-env-vars="ACCOUNT_ENV=tt,PROJECT_ID=adk-rag-hdtest6,..."
```

### Method 3: Environment Variable (Local Development)

```bash
# Run locally with specific account
export ACCOUNT_ENV=usfs
python backend/src/api/server.py

# Or with Docker
docker run -e ACCOUNT_ENV=usfs -p 8080:8080 rag-backend
```

---

## 🔧 Configuring a New Account

### Step 1: Create Account Directory

```bash
cd backend/config
mkdir myaccount
```

### Step 2: Create config.py

Create `backend/config/myaccount/config.py`:

```python
"""Configuration for MyAccount"""
import os

# Account Information
ACCOUNT_NAME = "myaccount"
ACCOUNT_DESCRIPTION = "My Custom Account"
ORGANIZATION_DOMAIN = "mycompany.com"

# Google Cloud Configuration
PROJECT_ID = os.environ.get("PROJECT_ID", "my-project-id")
LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")

# RAG Configuration
DEFAULT_CORPUS_NAME = "myaccount-general"

# Corpus to GCS Bucket Mapping
CORPUS_TO_BUCKET_MAPPING = {
    "my-corpus": "my-gcs-bucket",
    "documents": "my-documents-bucket",
}
```

### Step 3: Create agent.py

Create `backend/config/myaccount/agent.py`:

```python
from google.adk.agents import Agent
from google.adk.models import Gemini
import os

# Import tools from parent directory
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / 'src'))

from rag_agent.tools.add_data import add_data
from rag_agent.tools.create_corpus import create_corpus
from rag_agent.tools.delete_corpus import delete_corpus
from rag_agent.tools.delete_document import delete_document
from rag_agent.tools.get_corpus_info import get_corpus_info
from rag_agent.tools.list_corpora import list_corpora
from rag_agent.tools.rag_query import rag_query

# Set environment variables to force ADK to use Vertex AI
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
os.environ["VERTEXAI_PROJECT"] = os.environ.get("PROJECT_ID", "my-project-id")
os.environ["VERTEXAI_LOCATION"] = os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")

# Configure Vertex AI model
vertex_model = Gemini(model="gemini-2.5-flash")

root_agent = Agent(
    name="MyAccountRagAgent",
    model=vertex_model,
    description="My Custom RAG Agent",
    tools=[
        rag_query,
        list_corpora,
        create_corpus,
        add_data,
        get_corpus_info,
        delete_corpus,
        delete_document,
    ],
    instruction="""
    # My Custom RAG Agent
    
    You are a helpful RAG agent for MyAccount...
    [Add your custom instructions here]
    """,
)
```

### Step 4: Update config_loader.py

Edit `backend/config/config_loader.py` and add your account to `VALID_ACCOUNTS`:

```python
VALID_ACCOUNTS = ["develom", "usfs", "tt", "myaccount"]  # Add your account
```

### Step 5: Verify Configuration

```bash
cd backend
python config/verify_configs.py
```

### Step 6: Deploy

```bash
# Update Dockerfile or deploy with env var
gcloud run deploy backend \
  --image=... \
  --set-env-vars="ACCOUNT_ENV=myaccount,PROJECT_ID=...,..."
```

---

## 🧪 Testing Account Configuration

### Quick Test Script

```bash
#!/bin/bash
# test-account.sh

ACCOUNT=${1:-develom}

echo "Testing account: $ACCOUNT"

cd backend
export ACCOUNT_ENV=$ACCOUNT

python -c "
import sys
sys.path.insert(0, 'config')
from config_loader import load_agent, load_config

config = load_config('$ACCOUNT')
print(f'Project: {config.PROJECT_ID}')
print(f'Location: {config.LOCATION}')

agent_module = load_agent('$ACCOUNT')
print(f'Agent: {agent_module.root_agent.name}')
print(f'Tools: {len(agent_module.root_agent.tools)}')
"
```

Usage:
```bash
./test-account.sh develom
./test-account.sh usfs
./test-account.sh tt
```

---

## 📊 Current Configuration Status

Run verification at any time:

```bash
./verify-config-migration.sh
```

Or detailed config check:

```bash
cd backend
python config/verify_configs.py
```

---

## 🔍 Debugging

### Check Active Account in Cloud Run

```bash
# View environment variables
gcloud run services describe backend \
  --region=us-east4 \
  --format="yaml(spec.template.spec.containers[0].env)"

# Check logs for account loading
gcloud run logs read backend \
  --region=us-east4 \
  --limit=50 \
  | grep "Loading agent for account"
```

### View Account Details

```bash
# From backend directory
python -c "
from config.config_loader import get_account_info
import json

for account in ['develom', 'usfs', 'tt']:
    info = get_account_info(account)
    print(f'\n{account.upper()}:')
    print(json.dumps(info, indent=2))
"
```

---

## ⚠️ Important Notes

1. **Build-time vs Runtime**: 
   - `ACCOUNT_ENV` is read at runtime when the server starts
   - You can change it without rebuilding the container

2. **Config Files**:
   - Each account must have both `config.py` and `agent.py`
   - Config files are validated on import

3. **Default Account**:
   - If `ACCOUNT_ENV` is not set, defaults to `develom`
   - Override in Dockerfile for production deployments

4. **Project Settings**:
   - Each account config can have its own `PROJECT_ID` and `LOCATION`
   - Currently all accounts use: `adk-rag-hdtest6` / `us-east4`

---

## 📚 Related Files

- `CONFIG-MIGRATION-SUMMARY.md` - Migration details and architecture
- `verify-config-migration.sh` - Verification script
- `backend/config/verify_configs.py` - Detailed config validator
- `backend/config/config_loader.py` - Multi-account loader implementation

---

**Last Updated**: 2025-10-10  
**Migration Status**: ✅ Complete and Verified
