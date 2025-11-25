# Config Migration to Multi-Account Structure

**Date**: 2025-10-10  
**Migration**: Single config → Multi-account config loader

---

## ✅ Changes Implemented

### 1. **Backend API Server** (`backend/src/api/server.py`)
- **Changed**: Import mechanism to use new config loader
- **Before**: Direct import from `rag_agent.agent`
- **After**: Uses `config_loader.load_agent()` with `ACCOUNT_ENV` support

```python
# New import structure
from config_loader import load_agent, load_config

account_env = os.environ.get("ACCOUNT_ENV", "develom")
agent_module = load_agent(account_env)
root_agent = agent_module.root_agent
```

### 2. **Dockerfile** (`backend/Dockerfile`)
- **Added**: `COPY config/ ./config/` to include config directory
- **Added**: `ENV ACCOUNT_ENV=develom` environment variable

### 3. **Cloud Build Config** (`backend/cloudbuild.yaml`)
- **Added**: `_ACCOUNT_ENV: 'develom'` substitution variable

### 4. **Deployment Scripts**
Updated the following scripts to include `ACCOUNT_ENV=develom`:

- `infrastructure/deploy-secure-v0.2.sh`
  - Line 199: Added to initial deployment env vars
  - Line 333: Added to final configuration update

- `infrastructure/deploy-complete-oauth-v0.2.sh`
  - Line 642: Added to CORS configuration update

---

## 📁 New Config Structure

```
backend/
├── config/
│   ├── config_loader.py       # Multi-account config loader
│   ├── develom/
│   │   ├── agent.py           # Develom agent config
│   │   └── config.py          # Develom project config
│   ├── usfs/
│   │   ├── agent.py           # USFS agent config
│   │   └── config.py          # USFS project config
│   └── tt/
│       ├── agent.py           # TechTrend agent config
│       └── config.py          # TechTrend project config
└── src/
    ├── api/
    │   └── server.py          # Now uses config_loader
    └── rag_agent/
        ├── agent.py           # Legacy (not used)
        └── config.py          # Legacy (not used)
```

---

## 🔄 New Call Chain

```
Docker Container Start
    ↓
ENV ACCOUNT_ENV=develom (from Dockerfile or Cloud Run)
    ↓
server.py imports config_loader
    ↓
load_agent("develom")
    ↓
backend/config/develom/agent.py
    ↓
backend/config/develom/config.py (PROJECT_ID, LOCATION)
    ↓
root_agent initialized with account-specific settings
    ↓
FastAPI app ready with correct agent
```

---

## 🎯 Current Configuration

All accounts currently configured for:
- **PROJECT_ID**: `adk-rag-hdtest6`
- **LOCATION**: `us-east4`
- **ACCOUNT_ENV**: `develom` (default)

### Account Details:

#### Develom Account
- **Account Name**: develom
- **Description**: Develom Root Repository Account
- **Organization**: develom.com
- **Default Corpus**: develom-general
- **Agent**: RagAgent

#### USFS Account
- **Account Name**: usfs
- **Description**: U.S. Forest Service Account
- **Organization**: usda.gov
- **Default Corpus**: usfs-forest-service
- **Agent**: USFSRagAgent

#### TechTrend Account
- **Account Name**: tt
- **Description**: TechTrend Account
- **Organization**: techtrend.com
- **Default Corpus**: techtrend-general
- **Agent**: TechTrendRAGAgent

---

## 🧪 Testing

### Verify Configuration
```bash
cd backend
python config/verify_configs.py
```

### Test Local Deployment
```bash
# Set account environment
export ACCOUNT_ENV=develom

# Build and run
cd backend
docker build -t rag-backend .
docker run -p 8080:8080 -e ACCOUNT_ENV=develom rag-backend
```

### Switch Accounts
To deploy with a different account:

```bash
# Update Dockerfile
ENV ACCOUNT_ENV=usfs  # or tt

# Or set in Cloud Run deployment
gcloud run deploy backend \
  --image=... \
  --set-env-vars="ACCOUNT_ENV=usfs,PROJECT_ID=...,..."
```

---

## 🚀 Deployment Notes

1. **Dockerfile includes config directory**: The `COPY config/ ./config/` ensures all account configs are available
2. **Default account is develom**: If `ACCOUNT_ENV` is not set, defaults to `develom`
3. **Easy switching**: Change `ACCOUNT_ENV` to switch between accounts
4. **Legacy files remain**: Old `backend/src/rag_agent/agent.py` and `config.py` are not deleted but no longer used

---

## ⚠️ Important

- The `ACCOUNT_ENV` variable must match one of: `develom`, `usfs`, `tt`
- Each account config must have matching `PROJECT_ID` and `GOOGLE_CLOUD_LOCATION` in its config.py
- Deployment scripts now automatically include `ACCOUNT_ENV` in environment variables

---

## 📋 Next Steps

1. ✅ **Verified**: All configs validated with `verify_configs.py`
2. **Deploy**: Run deployment script with new configuration
3. **Monitor**: Check Cloud Run logs for successful agent loading:
   - Look for: `🔧 Loading agent for account: develom`
   - Look for: `✅ Loaded agent: RagAgent with 7 tools`
4. **Test**: Verify API endpoints work correctly
5. **Optional**: Configure other accounts (usfs, tt) when ready

---

## 🔙 Rollback (if needed)

To rollback to the old structure:

1. Revert `backend/src/api/server.py` changes
2. Remove `ENV ACCOUNT_ENV=develom` from Dockerfile
3. Remove `COPY config/ ./config/` from Dockerfile
4. Remove `ACCOUNT_ENV` from deployment scripts
5. Redeploy services

---

**Migration Status**: ✅ Complete  
**Testing Status**: ⏳ Pending deployment verification
