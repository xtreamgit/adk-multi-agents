# Multiple Agent Architecture Plan

**Project:** ADK Multi-Agents / RAG Multi-Agents  
**Date:** 2025-11-20  
**Goal:** Evolve the current single-agent backend into a multi-agent architecture where:

- Multiple Cloud Run backend services run in the same GCP project
- Each backend service uses its own service account (IAM isolation)
- Multiple service accounts can access the same Vertex AI RAG corpora and underlying data
- Frontend(s) can target one or more agents as needed

This document lays out a **10-phase, incremental plan** to get there with controlled scope at each step.

---

## Phase 0 – Baseline Verification (Pre‑work)

**Objective:** Confirm current single-agent deployment and infra are healthy before introducing multi-agent complexity.

- **Verify runtime:**
  - Backend Cloud Run service `backend` is deployed and reachable.
  - Frontend Cloud Run service `frontend` can successfully chat with the agent.
- **Verify config:**
  - `ACCOUNT_ENV` is set to `develom` for the existing backend service.
  - `backend/config/develom/agent.py` and `backend/config/develom/config.py` are the active account config.
- **Verify IAM:**
  - `adk-rag-agent-sa` (or equivalent) has the expected roles (Vertex AI, Storage, BigQuery).
- **Verify corpora:**
  - List at least one working corpus from the UI or via `list_corpora` endpoint.

> **Exit criteria:** Single-agent stack is stable and documented (URLs, project, region, service account names).

---

## Phase 1 – Define New Agent Configs (Logical Accounts)

**Objective:** Introduce additional *logical* agents via new `ACCOUNT_ENV` configurations, without changing infra yet.

**Code changes (no infra yet):**

1. **Add new account identifiers** in `backend/config/config_loader.py`:
   - Extend `VALID_ACCOUNTS` to include new agents, e.g. `"internal"`, `"fedgov"`.
2. **Create new config directories:**
   - `backend/config/internal/config.py`, `backend/config/internal/agent.py`, `backend/config/internal/__init__.py`
   - `backend/config/fedgov/config.py`, `backend/config/fedgov/agent.py`, `backend/config/fedgov/__init__.py`
3. **Agent definitions:**
   - In each `agent.py`, define a `root_agent` with:
     - Agent name and description
     - Tool set (initially reuse existing `src.rag_agent.tools.*`)
     - Instructions tailored per agent (e.g., internal vs. external scope, tone, guardrails).
4. **Config definitions:**
   - In each `config.py`, define:
     - `PROJECT_ID`, `LOCATION`, `ACCOUNT_NAME`, `ACCOUNT_DESCRIPTION`
     - Optional `ORGANIZATION_DOMAIN`, `DEFAULT_CORPUS_NAME`.

**Testing (local):**

- From a local run (Docker or `uvicorn`), manually set `ACCOUNT_ENV` and verify:
  - `ACCOUNT_ENV=internal`: `load_agent("internal")` and `load_config("internal")` succeed.
  - `ACCOUNT_ENV=fedgov`: same.

> **Exit criteria:** All new accounts pass `validate_account_config()` and have valid `root_agent` + config.

---

## Phase 2 – Refine Shared Tools and Corpus Usage

**Objective:** Ensure the shared tool layer under `backend/src/rag_agent/tools` can safely be reused by multiple agents and supports corpus sharing.

**Code review & adjustments:**

- Review `backend/src/rag_agent/tools/*.py` to:
  - Confirm they use **environment variables and config** (PROJECT_ID, LOCATION) correctly.
  - Confirm they do **not** hard-code corpus names tied to a single agent.
  - Identify any assumptions about bucket names or corpus naming (ensure they are configuration-driven).
- If necessary, introduce a small configuration helper layer that:
  - Reads default corpus names from `config.<account>.config`.
  - Provides a clean way for each agent to suggest its default corpora while still allowing shared corpora.

> **Exit criteria:** All tools are safe to call from any agent config and do not assume a single global account.

---

## Phase 3 – Introduce Per-Agent Service Accounts (IAM Layer Only)

**Objective:** Define separate service accounts for each agent, with IAM roles granting access to shared corpora where appropriate.

**Infra changes (no new services yet):**

1. **Create agent-specific service accounts** in `infrastructure/lib/infrastructure.sh`:
   - Add e.g.:
     - `adk-rag-internal-sa@$PROJECT_ID.iam.gserviceaccount.com`
     - `adk-rag-fedgov-sa@$PROJECT_ID.iam.gserviceaccount.com`
2. **Grant IAM roles** to these new SAs:
   - Vertex AI: `roles/aiplatform.user` or `roles/aiplatform.admin` (as required).
   - Storage: `roles/storage.objectViewer` or `roles/storage.admin`.
   - BigQuery: `roles/bigquery.dataViewer` or `roles/bigquery.admin`.
3. **Shared corpora access:**
   - Ensure all SAs that should share a corpus have the relevant permissions on:
     - Project, corpus resources, and associated buckets/datasets.

> **Exit criteria:** New SAs exist and have verified permissions (using `gcloud auth impersonate-service-account` tests or simple dry-run checks) but are not yet used by any Cloud Run service.

---

## Phase 4 – Parameterize Cloud Run Backend Deployment for Multiple Agents

**Objective:** Extend `cloudrun.sh` so we can deploy multiple backend services, each with its own `ACCOUNT_ENV` and service account.

**Code changes:**

1. **Refactor `deploy_backend`** in `infrastructure/lib/cloudrun.sh` into a parameterized form, e.g.:
   - `deploy_backend_service SERVICE_NAME IMAGE ACCOUNT_ENV SERVICE_ACCOUNT`
2. **Use the parameterized function** to deploy the current `backend` service (backwards compatible):
   - `deploy_backend_service "backend" "$BACKEND_IMAGE" "$ACCOUNT_ENV" "$RAG_AGENT_SA"`
3. **Prepare additional deployment calls** (without enabling yet) for:
   - `backend-internal` → `ACCOUNT_ENV=internal` → `SERVICE_ACCOUNT=adk-rag-internal-sa`
   - `backend-fedgov` → `ACCOUNT_ENV=fedgov` → `SERVICE_ACCOUNT=adk-rag-fedgov-sa`

> **Exit criteria:** `deploy_cloud_run` can *theoretically* deploy multiple backend services, but in practice still only deploys the original `backend` until Phase 5.

---

## Phase 5 – Deploy Second Backend Agent (Internal)

**Objective:** Stand up the first additional Cloud Run backend (`backend-internal`) with its own service account and account config.

**Infra changes:**

1. **Enable second backend deployment** in `deploy_cloud_run`:
   - Call `deploy_backend_service` for `backend-internal`.
2. **Set env vars** for `backend-internal`:
   - `ACCOUNT_ENV=internal`
   - `PROJECT_ID`, `GOOGLE_CLOUD_LOCATION`, `VERTEXAI_PROJECT`, `VERTEXAI_LOCATION` as appropriate.
3. **Use `adk-rag-internal-sa`** as the service account.

**Validation:**

- Describe the new Cloud Run service:
  - Confirm env vars and service account.
- Hit its `/` health endpoint and chat endpoint directly (or via curl / temporary frontend configuration).

> **Exit criteria:** `backend-internal` is running, loads the `internal` agent config, and can query corpora successfully.

---

## Phase 6 – Deploy Third Backend Agent (FedGov / External)

**Objective:** Repeat the process for a second additional backend service, validating that we can run *three* backends concurrently (original + two new).

**Infra changes:**

1. **Enable `backend-fedgov` deployment** in `deploy_cloud_run`.
2. **Set env vars**:
   - `ACCOUNT_ENV=fedgov`
3. **Use `adk-rag-fedgov-sa`** as the service account.

**Validation:**

- Confirm `backend-fedgov` service details.
- Validate it can list/query corpora where it has access.

> **Exit criteria:** Three parallel backend services are running with distinct service accounts and configs, all able to operate on shared corpora where permitted.

---

## Phase 7 – IAP, Load Balancer, and Routing for Multiple Backends

**Objective:** Integrate the new backend services into the existing IAP + Load Balancer setup, so users can reach different agents through secure, user-friendly URLs.

**Infra/code changes:**

1. **Update load balancer configuration** (`infrastructure/lib/loadbalancer.sh`):
   - Add new backend services (Cloud Run NEGs) for `backend-internal`, `backend-fedgov`.
   - Configure host/path routing (e.g., `/internal/*`, `/fedgov/*`, or different hostnames).
2. **Update IAP configuration** (`infrastructure/lib/iap.sh`):
   - Enable IAP for each new backend.
   - Bind appropriate user/group IAM for each (e.g., `internal` vs `fedgov` access).
3. **Verify OAuth clients / redirect URIs** as needed for each LB backend.

**Validation:**

- Access each agent via LB URLs:
  - Confirm OAuth / IAP login.
  - Ensure user gets routed to the correct backend and sees the correct agent behavior.

> **Exit criteria:** Multiple backend agents are reachable via LB + IAP with correct access control per agent.

---

## Phase 8 – Frontend Integration and Agent Selection UX

**Objective:** Allow the frontend application(s) to target different agents cleanly.

**Code changes (frontend side, high-level):**

1. **Decide routing strategy:**
   - Separate frontends per agent (simpler for strict isolation), or
   - Single frontend with agent selector (better UX, more shared code).
2. **If single frontend:**
   - Introduce an "Agent" selector in the UI (e.g., sidebar dropdown).
   - Map each choice to a backend base URL or path.
   - Propagate the chosen agent to all API calls (different base URL, or path prefix like `/internal/api/…`).
3. **If multiple frontends:**
   - Deploy separate `frontend-*` services, each pointed at a specific backend.

**Validation:**

- User can choose an agent and get responses from the correct backend.
- Switching agents routes to different Cloud Run backends as expected.

> **Exit criteria:** Frontend(s) can reliably talk to each of the backend agents with clear UX.

---

## Phase 9 – Fine-Grained IAM and Corpus Sharing Policies

**Objective:** Tighten IAM so each agent has exactly the access it needs—shared corpora where intended, isolated where required.

**IAM work:**

1. **Classify corpora:**
   - Shared corpora (accessible to multiple SAs).
   - Private corpora per agent (internal-only, fedgov-only, etc.).
2. **Adjust IAM bindings:**
   - For shared corpora: ensure all relevant SAs have required roles.
   - For private corpora: restrict roles to the owning agent SA.
3. **Optionally, encode defaults in config:**
   - `DEFAULT_CORPUS_NAME` or a mapping per account in `config.py`.

**Validation:**

- Each agent can access the corpora it should, and cannot access corpora it should not.
- Negative tests: calls from the wrong agent to a restricted corpus fail cleanly.

> **Exit criteria:** IAM is principle-of-least-privilege while still enabling intentional corpus sharing.

---

## Phase 10 – Observability, Runbooks, and Cleanup

**Objective:** Ensure the multi-agent, multi-SA setup is maintainable and well-documented.

**Operational work:**

1. **Logging & metrics:**
   - Tag logs with `agent`/`ACCOUNT_ENV` where possible.
   - Create Cloud Monitoring dashboards per backend service.
2. **Runbooks:**
   - Add troubleshooting sections for each agent (common errors, IAM issues, corpus access problems).
   - Document how to:
     - Add a new agent (steps through Phases 1–6 for a new account).
     - Rotate or update service accounts.
3. **Cleanup & consistency:**
   - Remove any legacy single-agent assumptions in comments/config.
   - Ensure deployment scripts (`deploy-all.sh`, etc.) reflect the new reality.

> **Exit criteria:** Multi-agent architecture is fully operational, observable, and documented; adding future agents is a repeatable procedure.

---

## Implementation Tracking

As we implement this plan, we should track progress (e.g., via todos or issues) by marking each phase as:

- **Not started**
- **In progress**
- **Complete**

Initial status:

1. Phase 0 – Baseline Verification: **In progress / assumed partially complete**
2. Phase 1 – Define New Agent Configs: **Not started**
3. Phase 2 – Refine Shared Tools and Corpus Usage: **Not started**
4. Phase 3 – Per-Agent Service Accounts: **Not started**
5. Phase 4 – Parameterize Cloud Run Backend Deployment: **Not started**
6. Phase 5 – Deploy Second Backend Agent (Internal): **Not started**
7. Phase 6 – Deploy Third Backend Agent (FedGov): **Not started**
8. Phase 7 – IAP, LB, and Routing: **Not started**
9. Phase 8 – Frontend Integration: **Not started**
10. Phase 9 – IAM & Corpus Policies: **Not started**
11. Phase 10 – Observability & Runbooks: **Not started**
