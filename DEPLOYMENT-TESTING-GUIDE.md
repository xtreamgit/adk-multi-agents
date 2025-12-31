# Deployment Testing Guide - ADK Multi-Agents

This guide provides step-by-step procedures to deploy and test the enhanced multi-agent RAG application.

## 🚀 Quick Deployment Testing Procedure

### Prerequisites
- Google Cloud CLI authenticated with `adk-rag-ma` project
- Access to IAP-protected application (hector@develom.com)
- Browser for UI testing

### Step 1: Build and Deploy Backend

```bash
# Build backend with enhanced features
gcloud builds submit ./backend \
  --config=backend/cloudbuild.yaml \
  --substitutions=_BACKEND_IMAGE="us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/backend:$(date +%Y%m%d-%H%M%S)" \
  --project=adk-rag-ma

# Deploy to all backend services
IMAGE_TAG="us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/backend:$(date +%Y%m%d-%H%M%S)"

for service in backend backend-agent1 backend-agent2 backend-agent3; do
  echo "Deploying $service..."
  gcloud run services update $service \
    --image="$IMAGE_TAG" \
    --region=us-west1 \
    --project=adk-rag-ma \
    --update-env-vars="GOOGLE_CLOUD_LOCATION=us-west1,VERTEXAI_LOCATION=us-west1" \
    --quiet
done
```

### Step 2: Verify Deployment Status

```bash
# Check all services are running
gcloud run services list --project=adk-rag-ma --region=us-west1

# Check for recent errors
gcloud logging read 'severity>=ERROR' \
  --project=adk-rag-ma \
  --limit=10 \
  --freshness=10m
```

### Step 3: Test Application Endpoints

#### A. Test Load Balancer Health
```bash
# Test main endpoint (will show IAP redirect)
curl -I https://34.49.46.115.nip.io/
# Expected: HTTP/1.1 302 Found (redirect to IAP)
```

#### B. Test Enhanced Health Endpoints (Browser Required)
Since the application uses IAP, you need to test in a browser:

1. **Open browser and navigate to**: `https://34.49.46.115.nip.io`
2. **Login with**: `hector@develom.com`
3. **Test health endpoints**:
   - Main API: `https://34.49.46.115.nip.io/api/health`
   - Agent 1: `https://34.49.46.115.nip.io/agent1/api/health`
   - Agent 2: `https://34.49.46.115.nip.io/agent2/api/health`
   - Agent 3: `https://34.49.46.115.nip.io/agent3/api/health`

**Expected Health Response Format**:
```json
{
  "status": "healthy",
  "service": "backend",
  "revision": "backend-00018-xyz",
  "service_region": "us-west1",
  "vertexai_region": "us-west1",
  "google_cloud_location": "us-west1",
  "account_env": "develom",
  "root_path": "",
  "project_id": "adk-rag-ma",
  "timestamp": "2025-12-18T23:53:00Z",
  "python_version": "3.12.6",
  "agent_name": "RAG Agent"
}
```

### Step 4: Test Multi-Agent Functionality

#### A. Test Agent Switching
1. **Access application**: `https://34.49.46.115.nip.io`
2. **Use agent selector** in sidebar to switch between:
   - Default Agent
   - Agent 1
   - Agent 2
   - Agent 3

#### B. Test Agent Responses
For each agent, test basic functionality:

1. **List Corpora**: "List all available corpora"
2. **Basic Query**: "What can you help me with?"
3. **Check Logs**: Verify agent-specific logging

```bash
# Check agent-specific logs
gcloud logging read 'textPayload:"[agent1]"' \
  --project=adk-rag-ma \
  --limit=10 \
  --freshness=10m

gcloud logging read 'textPayload:"[agent2]"' \
  --project=adk-rag-ma \
  --limit=10 \
  --freshness=10m

gcloud logging read 'textPayload:"[agent3]"' \
  --project=adk-rag-ma \
  --limit=10 \
  --freshness=10m
```

### Step 5: Test Enhanced Features

#### A. Monitoring Setup
```bash
# Setup monitoring dashboards and alerts
./setup-monitoring.sh

# Verify dashboards created
gcloud monitoring dashboards list --project=adk-rag-ma
```

#### B. Secrets Management
```bash
# Setup secrets management
./setup-secrets.sh

# Test secrets utility
python3 manage-secrets.py list
```

#### C. Backup System
```bash
# Test backup system
./backup-restore-system.sh setup

# Create a test backup
./backup-restore-system.sh backup

# List available backups
./backup-restore-system.sh list
```

#### D. Cost and Compliance
```bash
# Setup cost budgets and compliance
./setup-cost-compliance.sh

# Check cost recommendations
./check-cost-recommendations.sh
```

### Step 6: Performance and Load Testing

#### A. Basic Load Test
```bash
# Test concurrent requests to health endpoint
for i in {1..10}; do
  curl -s -w "%{http_code} %{time_total}s\n" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    https://34.49.46.115.nip.io/api/health &
done
wait
```

#### B. Monitor Resource Usage
```bash
# Check Cloud Run metrics
gcloud monitoring metrics list \
  --filter="metric.type:run.googleapis.com" \
  --project=adk-rag-ma
```

### Step 7: Rollback Testing

#### A. Test Rollback Capability
```bash
# Deploy with rollback script
./deploy-with-tests.sh rollback
```

#### B. Verify Rollback Success
```bash
# Check service revisions
for service in backend backend-agent1 backend-agent2 backend-agent3; do
  echo "=== $service ==="
  gcloud run revisions list \
    --service=$service \
    --region=us-west1 \
    --project=adk-rag-ma \
    --limit=3
done
```

## 🧪 Comprehensive Testing Checklist

### ✅ Deployment Verification
- [ ] All 5 services deployed successfully
- [ ] No deployment errors in logs
- [ ] Services show "Ready" status
- [ ] Load balancer responding with 302 (IAP redirect)

### ✅ Enhanced Health Checks
- [ ] `/api/health` returns comprehensive info
- [ ] Agent-specific health endpoints working
- [ ] Region information correctly displayed
- [ ] Service revision info present

### ✅ Multi-Agent Functionality
- [ ] Agent selector working in UI
- [ ] Each agent responds to queries
- [ ] Agent-specific logging visible
- [ ] No cross-agent contamination

### ✅ Enhanced Features
- [ ] Monitoring dashboards created
- [ ] Secrets management operational
- [ ] Backup system functional
- [ ] Cost budgets configured

### ✅ Performance & Reliability
- [ ] Response times < 2 seconds
- [ ] No 5xx errors under load
- [ ] Rollback procedures working
- [ ] Error monitoring active

## 🔧 Troubleshooting Common Issues

### Issue: IAP Authentication Errors
**Solution**: Ensure you're logged in with `hector@develom.com` and have proper IAP permissions.

### Issue: Health Endpoints Return 404
**Solution**: Verify the enhanced backend is deployed with the new health check code.

### Issue: Agent Switching Not Working
**Solution**: Check that each backend service has correct `ACCOUNT_ENV` and `ROOT_PATH` variables.

### Issue: Vertex AI FAILED_PRECONDITION Errors
**Solution**: Verify all services are using `VERTEXAI_LOCATION=us-west1`.

## 📊 Success Criteria

The deployment is successful when:

1. **All services healthy**: 5/5 Cloud Run services running
2. **Enhanced health checks**: Comprehensive health info available
3. **Multi-agent functionality**: All 4 agents responding correctly
4. **Enhanced features**: Monitoring, secrets, backup systems operational
5. **Performance**: Sub-2-second response times, no errors
6. **Rollback capability**: Tested and functional

## 🎯 Next Steps After Successful Testing

1. **Setup Monitoring**: Configure alerts and dashboards
2. **Implement Secrets**: Migrate sensitive config to Secret Manager
3. **Schedule Backups**: Setup automated backup procedures
4. **Cost Optimization**: Review and optimize resource allocation
5. **Documentation**: Update operational runbooks

---

**Note**: This testing procedure assumes the enhanced features have been deployed. If you encounter issues with the enhanced health endpoints, the basic application functionality should still work with the original endpoints.
