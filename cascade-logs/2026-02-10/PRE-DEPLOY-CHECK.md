# Pre-Deployment Environment Check

Run this **before** any deployment to a new or existing GCP project. The script audits the target environment for existing resources that the ADK RAG Agent deployment would create or modify, so you can decide whether to proceed, skip, or abort.

---

## Quick Start

```bash
# From project root
./infrastructure/pre-deploy-check.sh
```

The script is **read-only** — it never creates, modifies, or deletes anything.

---

## Usage

```bash
./infrastructure/pre-deploy-check.sh [OPTIONS]

Options:
  --project-id=ID     GCP project to scan (overrides deployment.config)
  --region=REGION      GCP region to scan (overrides deployment.config)
  --report=FILE        Write plain-text report to a file
  --help, -h           Show help
```

If `deployment.config` exists in the project root, it is sourced automatically. Command-line flags override config values.

### Examples

```bash
# Use deployment.config values
./infrastructure/pre-deploy-check.sh

# Scan a specific project
./infrastructure/pre-deploy-check.sh --project-id=acme-rag-agent --region=us-west1

# Save report to file
./infrastructure/pre-deploy-check.sh --report=pre-deploy-report.txt
```

---

## What It Checks

The script inspects **12 resource categories** — every type of resource that `deploy-all.sh` and its sub-modules create or modify:

| # | Category | Resources Checked |
|---|----------|-------------------|
| 0 | **Authentication** | gcloud auth, project access |
| 1 | **Enabled APIs** | 14 required APIs (Cloud Run, Vertex AI, IAP, etc.) |
| 2 | **Artifact Registry** | Repository `$REPO` in `$REGION` + existing images |
| 3 | **Service Accounts** | `backend-sa`, `frontend-sa`, `adk-rag-agent-sa`, `iap-accessor`, `adk-rag-agent1-sa`, `adk-rag-agent2-sa`, `adk-rag-agent3-sa` |
| 4 | **Cloud Run Services** | `backend`, `backend-agent1`, `backend-agent2`, `backend-agent3`, `frontend` + any other services in the region |
| 5 | **Cloud SQL Instances** | All instances in the project + check for `adk_agents_db` database |
| 6 | **Secret Manager** | `db-password` + other secrets |
| 7 | **GCS Buckets** | All buckets in the project with locations |
| 8 | **Vertex AI RAG Corpora** | All corpora in `$REGION` |
| 9 | **Load Balancer** | Static IP (`rag-agent-ip`), SSL cert (`rag-agent-ssl-cert`), 5 NEGs, 5 backend services, URL map, HTTPS proxy, forwarding rule + other forwarding rules |
| 10 | **OAuth & IAP** | OAuth brand, OAuth clients (⚠️ deploy-all.sh deletes and recreates these) |
| 11 | **Cloud Build** | Recent build history, presence of `cloudbuild.yaml` files |
| 12 | **IAM Policy** | Broad roles (`aiplatform.admin`, `storage.admin`, `bigquery.admin`) |

---

## Understanding the Output

Each resource check produces one of three results:

| Symbol | Meaning |
|--------|---------|
| ✅ **Clean** | Resource does not exist — safe to create |
| ⚠️ **CONFLICT** | Resource already exists with the **same name** our scripts use |
| ⚠️ **WARNING** | Something exists that isn't a direct conflict but needs attention |

### Summary Outcomes

| Result | What It Means |
|--------|---------------|
| **CLEAN ENVIRONMENT** | No conflicts or warnings. Safe to proceed with `deploy-all.sh`. |
| **WARNINGS FOUND** | Existing resources detected (e.g., other Cloud Run services, GCS buckets) but no direct naming conflicts. Review before proceeding. |
| **CONFLICTS FOUND** | Resources with the same names already exist. See recommendations below. |

---

## Conflict Resolution

### Scenario 1: Re-deploying the Same App

If you're re-deploying to the same project (e.g., updating code), conflicts are expected and safe. The deployment scripts already check for existing resources and skip creation.

**Action:** Proceed with `deploy-all.sh`.

### Scenario 2: New App in a Shared Project

If the GCP project already has other applications, review each conflict:

- **Service accounts** — Our scripts skip creation if they exist, but will **add IAM bindings** to them
- **Cloud Run services** — Will be **overwritten** with our application code
- **OAuth clients** — `iap.sh` **deletes all existing OAuth clients** and creates a new one
- **Load balancer components** — Will be reused if they exist (names match)

**Action:** Use a dedicated GCP project for this application.

### Scenario 3: Fresh Project

No conflicts expected. If the project doesn't exist yet, the script reports it immediately and exits.

**Action:** Run `deploy-init.sh` first, then `deploy-all.sh`.

---

## Critical Warning: OAuth Client Deletion

The `iap.sh` module **deletes all existing OAuth clients** under the project's OAuth brand before creating a new one. If the project has other applications using OAuth, this will break them.

```bash
# From infrastructure/lib/iap.sh (lines 42-53)
EXISTING_CLIENTS=$(gcloud iap oauth-clients list "$BRAND_PATH" ...)
while IFS= read -r client_name; do
    gcloud iap oauth-clients delete "$client_name" --quiet
done <<< "$EXISTING_CLIENTS"
```

**If the pre-deploy check shows existing OAuth clients, confirm they are not used by other applications before proceeding.**

---

## When to Run This

| Situation | Run Pre-Deploy Check? |
|-----------|----------------------|
| First deployment to a new project | ✅ Yes |
| Re-deployment after code changes | Optional (safe to skip) |
| Deploying to a client's existing project | ✅ **Mandatory** |
| After changing `deployment.config` | ✅ Yes |
| After changing the environment YAML | ✅ Yes |

---

## Integration with START-HERE.md

This check should be run **after Step 4** (Generate Configuration Files) and **before Step 9** (Initialize the GCP Project) in the [START-HERE.md](../START-HERE.md) guide:

```
Step 3: Create Environment YAML
Step 4: Generate Configuration Files
       ↓
  ★ Run pre-deploy-check.sh ★
       ↓
Step 9: Initialize GCP Project
Step 13: Deploy to Cloud Run
```
