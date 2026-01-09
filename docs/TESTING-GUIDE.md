# Testing Guide - Agent Logging Verification

## 🎯 Goal
Verify that the new agent-context logging is working correctly in the deployed application.

---

## ✅ Pre-Test Status

**Application Status:** ✅ Running  
**Load Balancer:** ✅ Responding (HTTP 302)  
**Errors:** ✅ None detected  
**Services:** ✅ All 4 backend services deployed

---

## 📝 Step-by-Step Testing Instructions

### Step 1: Access the Application

1. Open your browser
2. Navigate to: **https://34.49.46.115.nip.io**
3. You should be redirected to Google login (IAP)
4. Login with: **hector@develom.com**
5. ✅ **Expected:** Application UI loads successfully

---

### Step 2: Test Agent 1 - List Corpora

1. In the sidebar, **select "Agent 1"** from the agent dropdown
2. In the chat input, type: **"List all available corpora"**
3. Press Enter or click Send
4. ✅ **Expected:** Agent responds (even if no corpora exist yet)

---

### Step 3: Verify Logs (Run in Terminal)

Wait ~30 seconds after sending the message, then run:

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents

# Check for agent1 logs
gcloud logging read 'textPayload:"[agent1]"' \
  --project=adk-rag-ma \
  --limit=10 \
  --freshness=5m
```

✅ **Expected output should contain:**
```
[agent1] Listing all corpora
[agent1] Found X corpora
```

---

### Step 4: Test Agent 2 (Multi-Agent Verification)

1. In the sidebar, **switch to "Agent 2"**
2. Send the same message: **"List all available corpora"**
3. Wait ~30 seconds
4. Run this command:

```bash
# Check for agent2 logs
gcloud logging read 'textPayload:"[agent2]"' \
  --project=adk-rag-ma \
  --limit=10 \
  --freshness=5m
```

✅ **Expected:** Logs should show `[agent2]` prefix

---

### Step 5: Test Agent 3

1. Switch to **"Agent 3"**
2. Send: **"List all available corpora"**
3. Check logs:

```bash
gcloud logging read 'textPayload:"[agent3]"' \
  --project=adk-rag-ma \
  --limit=10 \
  --freshness=5m
```

✅ **Expected:** Logs should show `[agent3]` prefix

---

## 🧪 Additional Tests (Optional)

### Test: Create a Corpus

1. From **Agent 1**, send: **"Create a corpus named test-agent-logging"**
2. Check logs should show:

```bash
gcloud logging read 'textPayload:"[agent1]" AND textPayload:"create"' \
  --project=adk-rag-ma --limit=5 --freshness=5m
```

Expected:
```
[agent1] Attempting to create corpus 'test-agent-logging'
[agent1] Successfully created corpus...
```

### Test: Query a Corpus (if test-corpus exists)

1. From **Agent 1**, send: **"Query test-corpus for information about AI"**
2. Check logs:

```bash
gcloud logging read 'textPayload:"[agent1]" AND textPayload:"Query"' \
  --project=adk-rag-ma --limit=5 --freshness=5m
```

Expected:
```
[agent1] Querying corpus 'test-corpus' with query: ...
[agent1] Query successful - found X results
```

---

## 🔍 Verification Commands

### View All Agent Logs (Last 10 Minutes)
```bash
gcloud logging read 'textPayload:"[agent"' \
  --project=adk-rag-ma \
  --limit=20 \
  --freshness=10m \
  --format='table(timestamp,resource.labels.service_name,textPayload)'
```

### View Logs by Service
```bash
# Backend (default agent)
gcloud logging read 'resource.labels.service_name="backend"' \
  --project=adk-rag-ma --limit=10 --freshness=10m

# Backend Agent 1
gcloud logging read 'resource.labels.service_name="backend-agent1"' \
  --project=adk-rag-ma --limit=10 --freshness=10m

# Backend Agent 2
gcloud logging read 'resource.labels.service_name="backend-agent2"' \
  --project=adk-rag-ma --limit=10 --freshness=10m

# Backend Agent 3
gcloud logging read 'resource.labels.service_name="backend-agent3"' \
  --project=adk-rag-ma --limit=10 --freshness=10m
```

### Check for Errors
```bash
gcloud logging read 'severity>=ERROR' \
  --project=adk-rag-ma \
  --limit=20 \
  --freshness=30m
```

### Stream Logs in Real-Time
```bash
# Stream all backend logs
gcloud logging tail 'resource.type="cloud_run_revision"' \
  --project=adk-rag-ma

# Stream logs with agent context only
gcloud logging tail 'textPayload:"[agent"' \
  --project=adk-rag-ma
```

---

## ✅ Success Criteria

The logging is working correctly if you can confirm:

- [ ] Agent 1 logs show `[agent1]` prefix
- [ ] Agent 2 logs show `[agent2]` prefix
- [ ] Agent 3 logs show `[agent3]` prefix
- [ ] Each agent's logs are separate and identifiable
- [ ] Logs include action details (e.g., "Listing corpora", "Querying corpus")
- [ ] No errors in Cloud Logging

---

## ❌ Troubleshooting

### Issue: No Agent Logs Appear

**Possible causes:**
1. Request didn't reach the backend (check IAP/routing)
2. Logs haven't propagated yet (wait 1-2 minutes)
3. Application error preventing logging

**Debug steps:**
```bash
# 1. Check if backend received ANY requests
gcloud logging read 'resource.labels.service_name="backend-agent1"' \
  --project=adk-rag-ma --limit=20 --freshness=10m

# 2. Check for errors
gcloud logging read 'severity>=ERROR' \
  --project=adk-rag-ma --limit=10 --freshness=10m

# 3. Check frontend logs
gcloud logging read 'resource.labels.service_name="frontend"' \
  --project=adk-rag-ma --limit=20 --freshness=10m
```

### Issue: Wrong Agent Logs Appear

If Agent 1 shows `[agent2]` logs or similar:

**Check environment variables:**
```bash
gcloud run services describe backend-agent1 \
  --region=us-west1 --project=adk-rag-ma \
  --format='yaml(spec.template.spec.containers[0].env)'
```

Verify `ACCOUNT_ENV` matches the service name.

### Issue: Application Doesn't Load

**Check Load Balancer:**
```bash
curl -I https://34.49.46.115.nip.io/
```

Should return HTTP 302 (redirect to IAP).

**Check services are running:**
```bash
gcloud run services list --project=adk-rag-ma --region=us-west1
```

All should show as "Running".

---

## 📊 Expected Test Results

After completing all tests, you should see logs like:

```
2025-12-08T... backend-agent1  [agent1] Listing all corpora
2025-12-08T... backend-agent1  [agent1] Found 1 corpora
2025-12-08T... backend-agent2  [agent2] Listing all corpora
2025-12-08T... backend-agent2  [agent2] Found 1 corpora
2025-12-08T... backend-agent3  [agent3] Listing all corpora
2025-12-08T... backend-agent3  [agent3] Found 1 corpora
```

Each agent's logs are clearly tagged and distinguishable!

---

## 🎉 After Testing

Once you've confirmed logging works:

1. **Mark Phase 2 as COMPLETE** ✅
2. **Update documentation** with any findings
3. **Choose next phase:**
   - Phase 9: Fine-Grained IAM
   - Phase 10: Observability Dashboards

---

## 📝 Quick Test Commands (Copy-Paste)

Run these after performing actions in the UI:

```bash
# Check all agent logs
gcloud logging read 'textPayload:"[agent"' --project=adk-rag-ma --limit=20 --freshness=10m

# Check for errors
gcloud logging read 'severity>=ERROR' --project=adk-rag-ma --limit=10 --freshness=30m

# Count logs per agent
echo "Agent 1:" && gcloud logging read 'textPayload:"[agent1]"' --project=adk-rag-ma --limit=100 --freshness=10m --format='value(timestamp)' | wc -l
echo "Agent 2:" && gcloud logging read 'textPayload:"[agent2]"' --project=adk-rag-ma --limit=100 --freshness=10m --format='value(timestamp)' | wc -l
echo "Agent 3:" && gcloud logging read 'textPayload:"[agent3]"' --project=adk-rag-ma --limit=100 --freshness=10m --format='value(timestamp)' | wc -l
```

---

Good luck with testing! 🚀
