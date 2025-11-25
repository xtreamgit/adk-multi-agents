# Multi-Agent RAG Runbook

Project: `adk-rag-ma`
Region: `us-east4`

This runbook summarizes how to operate and debug the multi-agent RAG deployment.

---

## 1. Architecture Overview

- **Frontend**: Cloud Run service `frontend`
- **Backends** (Cloud Run):
  - `backend` → default agent (ACCOUNT_ENV=`develom`, ROOT_PATH="")
  - `backend-agent1` → Agent 1 (ACCOUNT_ENV=`agent1`, ROOT_PATH=`/agent1`)
  - `backend-agent2` → Agent 2 (ACCOUNT_ENV=`agent2`, ROOT_PATH=`/agent2`)
  - `backend-agent3` → Agent 3 (ACCOUNT_ENV=`agent3`, ROOT_PATH=`/agent3`)
- **Load Balancer (External HTTPS)**
  - URL: `https://<STATIC_IP>.nip.io` (e.g. `https://34.49.46.115.nip.io`)
  - Path routing:
    - `/` → `frontend-backend-service` → `frontend`
    - `/api/*` → `backend-backend-service` → `backend`
    - `/agent1/api/*` → `backend-agent1-backend-service` → `backend-agent1`
    - `/agent2/api/*` → `backend-agent2-backend-service` → `backend-agent2`
    - `/agent3/api/*` → `backend-agent3-backend-service` → `backend-agent3`
- **IAP**: Enabled on all backend services using the IAP service account.

---

## 2. How to Access the App

1. Ensure deployment is up to date:

   ```bash
   export PROJECT_ID=adk-rag-ma
   export REGION=us-east4

   ./infrastructure/deploy-all.sh
   ```

2. Wait a couple of minutes for LB/IAP propagation.
3. Open the Load Balancer URL in a browser:

   ```text
   https://<STATIC_IP>.nip.io
   ```

4. Sign in via Google (IAP) using an allowed account (e.g. `@develom.com`).
5. Use the **Agent selector** in the sidebar to switch between Default, Agent 1, Agent 2, and Agent 3.

---

## 3. Checking Service Health

### 3.1 List Cloud Run services

```bash
gcloud run services list --region=us-east4 --project=adk-rag-ma
```

You should see: `frontend`, `backend`, `backend-agent1`, `backend-agent2`, `backend-agent3`.

### 3.2 Describe a specific service

```bash
gcloud run services describe backend-agent1 \
  --region=us-east4 --project=adk-rag-ma \
  --format="value(status.url)"
```

To inspect environment variables:

```bash
gcloud run services describe backend-agent1 \
  --region=us-east4 --project=adk-rag-ma \
  --format='value(spec.template.spec.containers[0].env)'
```

Verify for each agent:

- `ACCOUNT_ENV` = `develom` / `agent1` / `agent2` / `agent3`
- `ROOT_PATH` = `""` for `backend`, `/agent1` for `backend-agent1`, etc.

### 3.3 Check Load Balancer URL map

```bash
gcloud compute url-maps describe rag-agent-url-map \
  --global --project=adk-rag-ma \
  --format='yaml(pathMatchers)'
```

Confirm there is a matcher with path rules for:

- `/api/*=backend-backend-service`
- `/agent1/api/*=backend-agent1-backend-service`
- `/agent2/api/*=backend-agent2-backend-service`
- `/agent3/api/*=backend-agent3-backend-service`

---

## 4. Logs and Troubleshooting

### 4.1 Viewing logs per agent

Tail recent logs for a specific backend service:

```bash
# Default agent
gcloud logs read --project=adk-rag-ma --region=us-east4 \
  --service=backend --limit=50

# Agent 1
gcloud logs read --project=adk-rag-ma --region=us-east4 \
  --service=backend-agent1 --limit=50

# Agent 2
gcloud logs read --project=adk-rag-ma --region=us-east4 \
  --service=backend-agent2 --limit=50

# Agent 3
gcloud logs read --project=adk-rag-ma --region=us-east4 \
  --service=backend-agent3 --limit=50
```

At startup each backend logs its effective configuration (account, project, location, ROOT_PATH). Use this to verify the correct agent is loaded.

### 4.2 Common issues

- **404 on `/agentX/api/...`**
  - Check that `ROOT_PATH` is set correctly for the corresponding backend service (see 3.2).
  - Confirm URL map has `/agentX/api/*` rules (see 3.3).

- **`{"detail":"Not Found"}` from backend**
  - Indicates FastAPI did not match the route.
  - Ensure the request path is `/agentX/api/...` (for agents) or `/api/...` (default) and that the service has the correct `ROOT_PATH`.

- **Session creation failures / `Failed to create session`**
  - Check backend logs for permission or corpus errors.
  - Verify service account IAM for the agent:

    ```bash
    gcloud projects get-iam-policy adk-rag-ma \
      --flatten="bindings[].members" \
      --filter="bindings.members:adk-rag-agent1-sa@adk-rag-ma.iam.gserviceaccount.com" \
      --format="table(bindings.role)"
    ```

  - Confirm storage access to corpus buckets (e.g. `ipad-book-collection`, `develom-documents`) via bucket IAM:

    ```bash
    gcloud storage buckets get-iam-policy gs://ipad-book-collection \
      --project=adk-rag-ma --format='json(bindings)'
    ```

- **Vertex AI permission errors**
  - Ensure per-agent SAs have `roles/aiplatform.user` at project level.
  - The bootstrap SA `adk-rag-agent-sa` retains admin roles for maintenance.

---

## 5. IAM and Corpus Sharing (Summary)

- Service accounts:
  - `adk-rag-agent-sa` (bootstrap/admin)
  - `adk-rag-agent1-sa`, `adk-rag-agent2-sa`, `adk-rag-agent3-sa` (per-agent)
- Project-level roles:
  - Bootstrap SA: `roles/aiplatform.admin`, `roles/storage.admin`, `roles/bigquery.admin`.
  - Per-agent SAs: `roles/aiplatform.user`.
- Bucket-level roles (example):
  - `gs://ipad-book-collection` and `gs://develom-documents` grant `roles/storage.objectViewer` to:
    - `adk-rag-agent-sa`
    - `adk-rag-agent1-sa`
    - `adk-rag-agent2-sa`
    - `adk-rag-agent3-sa`

When adding a new corpus/bucket, update `infrastructure/lib/infrastructure.sh` to grant `storage.objectViewer` to the appropriate SAs, then rerun the infrastructure script.

---

## 6. Redeploying Safely

- **Full pipeline (APIs, IAM, Cloud Run, LB, IAP)**:

  ```bash
  export PROJECT_ID=adk-rag-ma
  export REGION=us-east4

  ./infrastructure/deploy-all.sh
  ```

- **Only IAM changes**:

  ```bash
  ./infrastructure/lib/infrastructure.sh
  ```

- **Only backend + agent services (Cloud Run)**:

  ```bash
  ./infrastructure/lib/cloudrun.sh
  ```


Keep these scripts as the single source of truth for deployment; avoid manual changes in the console when possible.

---

## 7. Observability & Dashboards

This section provides ready-to-use log queries and how to turn them into basic dashboards.

### 7.1 Cloud Logging queries

**Errors per agent (last 24 hours)**

Use this query in Cloud Logging → Logs Explorer, adjusting the service name as needed:

```text
resource.type="cloud_run_revision"
resource.labels.location="us-east4"
resource.labels.service_name="backend-agent1"
severity>="ERROR"
timestamp>="-24h"
```

Repeat for `backend`, `backend-agent2`, `backend-agent3` to compare error volumes.

**Session creations per agent**

The backend logs `session_created` with `account_env` and `session_id`. To see recent session creations:

```text
resource.type="cloud_run_revision"
resource.labels.location="us-east4"
resource.labels.service_name="backend-agent1"
jsonPayload.message="session_created"
timestamp>="-24h"
```

You can change `backend-agent1` to other backends to see per-agent traffic.

**Startup configuration per agent**

At startup the backend logs `backend_startup` with resolved env:

```text
resource.type="cloud_run_revision"
resource.labels.location="us-east4"
jsonPayload.message="backend_startup"
timestamp>="-24h"
```

Use the log entry details to confirm `account_env`, `project_id`, `location`, and `root_path` for each service.

### 7.2 Creating basic Cloud Monitoring charts

To turn the above queries into charts:

1. In **Logs Explorer**, run a query (e.g. `severity>="ERROR"` for `backend-agent1`).
2. Click **Create metric** → define a **log-based metric** (e.g. `agent1_error_count`).
3. In **Cloud Monitoring → Metrics Explorer**:
   - Choose the new metric, group by `resource.labels.service_name` if desired.
   - Configure the aggregation window (e.g. 1 min) and alignment (sum/count).
4. Save the chart to a dashboard named something like `Multi-Agent RAG Overview`.

Suggested log-based metrics:

- `agent_error_count` – count of logs with `severity>="ERROR"` per agent service.
- `agent_session_created_count` – count of logs with `message="session_created"` per agent.

With these you can build a simple dashboard:

- **Chart 1**: Errors by agent over time.
- **Chart 2**: Sessions created by agent over time.

### 7.3 Splunk integration (high-level)

If Splunk is used as the central logging platform, you can forward logs from Cloud Logging using a Log Router sink:

1. In Cloud Logging, create a **log sink** with a filter targeting backend services, for example:

   ```text
   resource.type="cloud_run_revision" AND
   resource.labels.service_name:("backend" OR "backend-agent1" OR "backend-agent2" OR "backend-agent3")
   ```

2. Configure the sink destination as **Pub/Sub**.
3. On the Splunk side, configure a **HEC (HTTP Event Collector)** endpoint and a connector (e.g. Splunk Add-on for Google Cloud Platform) to pull from Pub/Sub into Splunk.
4. In Splunk, index logs and build searches/dashboards using fields such as:
   - `resource.labels.service_name`
   - `jsonPayload.message` (`backend_startup`, `session_created`, `session_creation_failed`)
   - `jsonPayload.account_env`, `jsonPayload.session_id`, `jsonPayload.username` (if present).

This allows centralized dashboards for:

- Error rate by agent.
- Session volume by agent.
- Correlating specific sessions (`session_id`) across logs.
