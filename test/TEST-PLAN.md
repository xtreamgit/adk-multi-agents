<!-- Testing Approach Header -->
- **Title**: Testing Approach & Execution
- **Approach**: Layered strategy (unit → integration → contract → E2E → infra/policy → security) to validate correctness, security, and configuration across environments.
- **How It’s Conducted**:
  - Local: unit/integration/contract with pytest and Node tests.
  - CI (testing/main): run unit/integration, lint/type/security checks, repo policy guards.
  - Post-deploy (staging): run infra/policy validation and optional smoke E2E through the load balancer and IAP.
  - Reporting: CI job summaries and artifacts; fail-fast on policy/security violations.

# ADK RAG TT – Test Plan

## 1. Scope & Objectives

Validate application correctness, security posture, and configuration across environments using layered tests (unit → integration → contract → E2E → infra/policy → security).

## 2. Test Types

### 2.1 Unit Tests (Backend)
- **Targets**:
  - `backend/config/config_loader.py`: account detection/validation.
  - `backend/src/rag_agent/config.py`: env resolution precedence.
  - `backend/src/rag_agent/agent.py`: tool wiring (mock Vertex AI calls).
- **Run**:
```bash
pytest -q backend/tests -k unit or markers
```

### 2.2 Integration Tests (API)
- **Targets**:
  - FastAPI endpoints in `backend/src/api/server.py`: `/health`, `/api/chat` (mock agent), streaming.
  - CORS: `FRONTEND_URL` must be honored; no wildcard in non-dev.
  - IAP context headers: enforce expected behavior when headers missing.
- **Run**:
```bash
pytest -q backend/tests -k integration
```

### 2.3 Contract Tests (Frontend ↔ Backend)
- **Targets**:
  - Build substitution: `_BACKEND_URL` → `NEXT_PUBLIC_BACKEND_URL` in `frontend/cloudbuild.yaml`.
  - API schema/shape for `/api/chat` and error payloads.
- **Approach**:
  - Node tests (`vitest`/`jest`) to assert env usage.
  - Optional OpenAPI schema check from FastAPI if exposed.

### 2.4 End-to-End (Post-Deploy Smoke)
- **Targets**:
  - HTTPS LB reachable, SSL ACTIVE.
  - IAP redirect works; access granted for allowed principals.
  - Routing: `/` → frontend, `/api/*` → backend.
- **Run (staging)**:
```bash
./infrastructure/validate-security.sh
# Optionally: playwright/k6 minimal smoke (non-credentialed IAP is hard; prefer manual or signed JWT pattern if required)
```

### 2.5 Infrastructure & Policy Checks
- **Targets**:
  - Org policy `constraints/iam.allowedPolicyMemberDomains` effective value.
  - Cloud Run ingress: `internal-and-cloud-load-balancing` on services.
  - IAP enabled on `frontend-backend-service` and `backend-backend-service` with correct OAuth client.
  - IAP Service Agent has `roles/run.invoker` on `frontend` and `backend`.
  - Optional: confirm `allUsers` posture matches expectation and explain if blocked by policy.
- **Run**:
```bash
./infrastructure/validate-security.sh
```

### 2.6 Data/Permission Checks (Vertex AI RAG)
- **Targets**:
  - RAG service agent `service-${PROJECT_NUMBER}@gcp-sa-vertex-rag.iam.gserviceaccount.com` has `roles/storage.objectViewer` on buckets.
  - Backend SA has `roles/aiplatform.admin` and `roles/storage.admin` as designed.
- **Run**:
```bash
gcloud storage buckets get-iam-policy gs://${RAG_BUCKET}
# plus lightweight mocked tool-call tests to ensure wiring without hitting live RAG
```

### 2.7 Static Analysis & Security
- **Targets**:
  - Lint/format: `flake8`, `black --check`, `isort --check`.
  - Types: `mypy`.
  - Security: `bandit`.
  - Dependencies: `safety`/`pip-audit`.
  - Shell: `shellcheck` for `infrastructure/**/*.sh`.
- **Run**:
```bash
flake8
black --check .
isort --check-only .
mypy backend
bandit -r backend
safety check || pip-audit
shellcheck infrastructure/lib/*.sh
```

### 2.8 CI Policy Checks (Repository Guards)
- **Already present**: `.github/workflows/env-config.yml`
  - No wildcard CORS in `backend/src/api/server.py`.
  - No hardcoded `SECRET_KEY` defaults.

### 2.9 Performance/Load (Optional)
- **Targets**: `/api/chat` latency/error rate under light load.
- **Tooling**: k6 scenario at low RPS against non-prod.

### 2.10 SonarQube Code Quality & Security Gate
- **Purpose**: Continuous static analysis for code smells, bugs, security hotspots, and coverage trends.
- **Analyzed**: Python backend, shell scripts (via external plugins), and optional frontend when added.
- **Local Run** (requires `sonar-scanner` and a SonarQube/SonarCloud token):
```bash
# Example local analysis (adjust values or use sonar-project.properties)
sonar-scanner \
  -Dsonar.projectKey=adk-rag-tt \
  -Dsonar.projectName="ADK RAG TT" \
  -Dsonar.sources=backend,infrastructure \
  -Dsonar.exclusions=**/__pycache__/**,**/*.md,**/tests/** \
  -Dsonar.python.version=3.12 \
  -Dsonar.host.url=${SONAR_HOST_URL} \
  -Dsonar.login=${SONAR_TOKEN}
```
- **CI Step** (suggested):
  - Add a dedicated job after tests and linters that runs `sonar-scanner` with organization/project settings.
  - Export `SONAR_HOST_URL` and `SONAR_TOKEN` as CI secrets.
- **Gate Criteria (example)**:
  - No new blocker/critical issues on new code.
  - Coverage on new code ≥ 70% (configurable).
  - Maintainability rating ≤ A; Security rating ≤ A.
 - **Config file**: Add `sonar-project.properties` at repo root to centralize configuration (example keys: `sonar.projectKey`, `sonar.sources`, `sonar.python.version`, `sonar.exclusions`).

## 3. Environments
- **Local**: Unit/integration/contract.
- **Staging/Testing**: E2E & infra checks (IAP + LB).
- **Production**: Post-deploy smoke (non-destructive).

## 4. CI Layout (Suggested)
- **Workflow: Env/Policy/Config**
  - Unit + Integration: `pytest -q`.
  - Lint/Type/Security: as above.
  - Repo policy checks: `.github/workflows/env-config.yml`.
  - Shell: `shellcheck`.
  - SonarQube: Run `sonar-scanner` using `SONAR_HOST_URL` and `SONAR_TOKEN` secrets.
  - Secret Scanning: Run `gitleaks` and/or `trufflehog` with strict mode and baseline as needed.
- **Workflow: Post-Deploy Validation (env-gated)**
  - `./infrastructure/validate-security.sh`
  - Optional k6 smoke.

## 5. Test Data & Mocks
- Use fixtures to mock Vertex AI agent calls.
- Provide sample payloads for `/api/chat` and error cases.
- Avoid real GCS/Vertex calls in CI; restrict live calls to staging pipeline steps.

## 6. Entry Points & Commands
```bash
# Python deps
python -m pip install -r backend/requirements.txt
pip install -r test/requirements-dev.txt  # to be added (lint/type/security)

# Run tests
pytest -q

# Static & security checks
flake8 && black --check . && isort --check-only . && mypy backend && bandit -r backend
```

## 7. Exit Criteria
- Unit/integration pass rate: 100% required.
- Lint/type/security checks: no errors.
- Infra/policy validation: all mandatory checks GREEN (IAP enabled, ingress restricted, SA bindings correct).
- E2E smoke: LB reachable, IAP login succeeds, routes correct.

## 8. Risks & Mitigations
- IAP automation: use manual validation or signed JWT approach for automated runs.
- Org policy variance: surface effective policy and branch logic in deploy scripts (already added).
- Flaky network tests: set retries and timeouts in E2E.
