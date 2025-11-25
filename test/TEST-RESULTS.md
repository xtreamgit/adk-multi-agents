# ADK RAG TT – Test Results Log

This file records evidence for each executed test. For every test run, add a new section using the header template below and attach links to logs, CI job runs, or screenshots as needed.

---

### Integration: Security headers sweep – Run 1
- **Test name**: integration-security-headers
- **Areas tested**: ACAO and credentials headers across multiple endpoints
- **Date**: 2025-11-01
- **Tester**: Cascade
- **Expected result (explanation)**: With `FRONTEND_URL` set, responses include ACAO matching origin and `access-control-allow-credentials: true` when ACAO is present.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_security_headers.py`

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - `/`, `/api/auth/verify`, `/api/sessions` (POST), `/api/corpora` (GET) returned expected headers.
- **Artifacts/Evidence**:
  - Pytest output: `. [100%]`

### Notes & Follow-ups
- None.

---

### Integration: Corpora endpoints – Run 1
- **Test name**: integration-corpora
- **Areas tested**: `GET /api/corpora` listing and `POST /api/corpora` creation request
- **Date**: 2025-11-01
- **Tester**: Cascade
- **Expected result (explanation)**: Listing returns text of available corpora; creation endpoint accepts `corpus_name` and returns initiation message.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_corpora_integration.py`
- Notes: ADK runner stub returns text; no external calls.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - GET returned JSON with `corpora` string containing expected values.
  - POST with `corpus_name=demo` returned a confirmation message.
- **Artifacts/Evidence**:
  - Pytest output: `.. [100%]`

### Notes & Follow-ups
- None.

---

### Integration: Chat burst/resilience – Run 1
- **Test name**: integration-chat-burst
- **Areas tested**: Multiple rapid chat requests, 5xx resilience, history growth
- **Date**: 2025-11-01
- **Tester**: Cascade
- **Expected result (explanation)**: N rapid POSTs to `/api/sessions/{id}/chat` return 200s and history grows by 2 entries per message (user + assistant).

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_chat_burst.py`
- Notes: Runner stub emits one final part; count=5 messages.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - All chat requests returned 200 with non-empty responses.
  - History length = 10, alternating user/assistant.
- **Artifacts/Evidence**:
  - Pytest output: `. [100%]`

### Notes & Follow-ups
- None.

---

### Integration: CORS negative (disallowed origin) – Run 1
- **Test name**: integration-cors-negative
- **Areas tested**: Response headers when Origin is not in allowlist
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: Requests from a disallowed origin should not receive an ACAO header echoing the origin.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_cors_negative.py`
- Notes: FRONTEND_URL set to allowed origin; request sent with a different Origin.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - GET `/` with disallowed Origin returned 200 and did not echo the disallowed origin in ACAO.
- **Artifacts/Evidence**:
  - Pytest output: `. [100%]`

### Notes & Follow-ups
- None.

---

### Integration: Token expiry – Run 1
- **Test name**: integration-token-expiry
- **Areas tested**: Expired JWT handling on protected endpoints
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: Requests with expired `exp` claim should return HTTP 401.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_token_expiry.py`
- Notes: Generated an expired token using server `SECRET_KEY`/`ALGORITHM`.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - `/api/auth/verify` with expired token returned 401 as expected.
- **Artifacts/Evidence**:
  - Pytest output: `. [100%]`

### Notes & Follow-ups
- None.

---

### Integration: Input validation – Run 1
- **Test name**: integration-input-validation
- **Areas tested**: 422/400 validation for login and chat payloads
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: Missing required fields should return 400/422 (login missing password; chat missing message).

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_input_validation.py`

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - Login missing password: 400/422.
  - Chat missing message: 400/422.
- **Artifacts/Evidence**:
  - Pytest output: `.. [100%]`

### Notes & Follow-ups
- None.

---

### Integration: Chat endpoint flow – Run 1
- **Test name**: integration-chat-flow
- **Areas tested**: Chat endpoint response and history append, session linkage
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: A user message to `/api/sessions/{id}/chat` should return a response and append both user and assistant entries to the session history.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_chat_integration.py`
- Notes: Uses temp SQLite DB; ADK runner stub returns a simple async iterator producing one final part.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - POST `/api/sessions/{id}/chat` returned a text response.
  - GET `/api/sessions/{id}/history` contained two entries: user then assistant.
- **Artifacts/Evidence**:
  - Pytest output: `. [100%]`

### Notes & Follow-ups
- None.

---

### Integration: Auth error paths – Run 1
- **Test name**: integration-auth-errors
- **Areas tested**: Duplicate registration, wrong password login, invalid token verification
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: Duplicate registration returns 400/409; wrong password login returns 401; invalid token on verify returns 401.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_auth_errors.py`
- Notes: Uses temp SQLite DB; ADK/GenAI stubbed.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - Duplicate registration: HTTP 400/409 as expected.
  - Wrong password: HTTP 401.
  - Invalid token verify: HTTP 401.
- **Artifacts/Evidence**:
  - Pytest output: `... [100%]`

### Notes & Follow-ups
- None.

---

### Integration: Admin users and stats – Run 1
- **Test name**: integration-admin
- **Areas tested**: Admin endpoints for users listing and statistics (Authorization required)
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: Authorized requests to `/api/admin/users` and `/api/admin/user-stats` return expected structures without exposing sensitive fields.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_admin_endpoints.py`
- Notes: Creates two users, then queries admin endpoints; ADK/GenAI stubbed.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - `/api/admin/users` returned a list with `username`, `full_name`, `email`, `created_at`, `last_login`, and `total_count`.
  - `/api/admin/user-stats` returned integer metrics including `total_users`.
- **Artifacts/Evidence**:
  - Pytest output: `. [100%]`

### Notes & Follow-ups
- Deprecation warnings observed for `datetime.utcnow()` in admin stats; consider timezone-aware datetime.

---

### Integration: Session lifecycle (create/get/profile/history) – Run 1
- **Test name**: integration-sessions
- **Areas tested**: Session creation, retrieval, profile update, history retrieval
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: Authorized user can create a session, retrieve it, update profile successfully, and read empty history initially.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_sessions_integration.py`
- Notes: Uses temp SQLite DB; authorization via JWT from `/api/auth/login`; ADK/GenAI stubbed.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - POST `/api/sessions` created a session and returned `session_id`.
  - GET `/api/sessions/{id}` returned the same `session_id`.
  - PUT `/api/sessions/{id}/profile` responded with success message.
  - GET `/api/sessions/{id}/history` returned an empty list.
- **Artifacts/Evidence**:
  - Pytest output: `. [100%]`

### Notes & Follow-ups
- Deprecation warnings for `datetime.utcnow()` and Pydantic `model.dict()` were observed; consider modernizing to timezone-aware datetimes and `model_dump`.

---

### Integration: Auth register/login/verify – Run 1
- **Test name**: integration-auth-basic
- **Areas tested**: Registration, password hashing + login, JWT issuance/verification
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: Register should create user; login should return bearer token; verify with Authorization header should return user info.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Test: `pytest -q backend/tests/test_auth_integration.py`
- Notes: Uses a temp SQLite DB via `DATABASE_PATH` env var; ADK/GenAI stubbed to avoid external calls.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - POST `/api/auth/register` created user and returned expected fields (sans password).
  - POST `/api/auth/login` returned bearer token and user.
  - GET `/api/auth/verify` returned the correct user when provided Authorization header.
- **Artifacts/Evidence**:
  - Pytest output: `. [100%]`

### Notes & Follow-ups
- Deprecation warnings noted in `backend/src/api/server.py` for `datetime.utcnow()`. Consider switching to timezone-aware UTC.

---

### CI Precheck: Local lightweight secret scan – Run 1
- **Test name**: local-secret-scan
- **Areas tested**: Potential hardcoded secrets in repo (files: py, sh, md, yml/yaml, json, env, txt)
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: No private keys, API keys, JWTs, or tokens should exist in the repository.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Targeted searches (read-only):
  - Literal: `BEGIN PRIVATE KEY`, `ghp_`, JSON `"private_key": "-----BEGIN`
  - Regex: `AKIA[0-9A-Z]{16}` (AWS Access Key ID)
  - Regex: `AIza[0-9A-Za-z_-]{35}` (Google API key)
  - Regex: `[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}` (JWT-like)

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - No matches for private keys, GitHub PATs, AWS or Google API keys.
  - JWT-like regex matched only in `temp-to-delete/*.txt` build logs referencing package metadata (false positives, not secrets).
- **Artifacts/Evidence**:
  - Grep outputs from workspace; no sensitive values surfaced.

### Notes & Follow-ups
- CI workflows added for Gitleaks and TruffleHog will provide stronger scanning on pushes/PRs.

---

## Header Template (copy for each test)

- **Test name**: <short, unique name>
- **Areas tested**: <e.g., API integration, IAP/LB, Org policy, Security scan>
- **Date**: <YYYY-MM-DD>
- **Tester**: <Person's name>
- **Expected result (explanation)**: <What should happen and why>

### Environment
- **Project**: <e.g., adk-rag-tt>
- **Region**: <e.g., us-east4>
- **Branch/Commit**: <branch @ SHA>
- **URL(s)**: <LB URL, API paths>

### Inputs & Procedure
- <Commands, datasets, endpoints called, CI job URLs>

### Outcome
- **Result**: <PASS | FAIL>
- **Observed behavior**: <Concise summary>
- **Artifacts/Evidence**:
  - <Link to CI run / logs>
  - <Screenshots / terminal output>
  - <gcloud describe outputs>

### Notes & Follow-ups
- <Anomalies, issues, remediation items>

---

## Example Entries (replace with real runs)

### Unit: Env precedence (backend)
- **Test name**: unit-env-precedence
- **Areas tested**: Backend config resolution
- **Date**: 2025-10-31
- **Tester**: Hector De Jesus
- **Expected result (explanation)**: When env vars are unset, account defaults are used; when set, env vars override account defaults.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ <sha>
- **URL(s)**: n/a

### Inputs & Procedure
- `pytest -q backend/tests/test_env_precedence.py`

### Outcome
- **Result**: PASS
- **Observed behavior**: Tests passed; overrides respected.
- **Artifacts/Evidence**: <CI run link or local log excerpt>

### Notes & Follow-ups
- None.

---

### Integration: API health & CORS – Run 1
- **Test name**: integration-api-health-cors
- **Areas tested**: API availability, CORS configuration
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: Health endpoint should return 200; when `FRONTEND_URL` is set, it must be present in server `allowed_origins` and responses should succeed with optional ACAO header matching the origin.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Commands:
  - `pytest -q backend/tests/test_api_health_and_cors.py`
- Notes:
  - Tests stubbed ADK and GenAI modules to avoid external dependencies.
  - Set `FRONTEND_URL=https://frontend.example.com` during import.

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - Health: 200 OK with message `RAG Agent API is running`.
  - CORS: `https://frontend.example.com` present in `server.allowed_origins`; GET with Origin succeeded.
- **Artifacts/Evidence**:
  - Local pytest output: `.. [100%]`

### Notes & Follow-ups
- Consider adding explicit preflight handling tests if app exposes custom methods/headers.

---

### Infra & Policy: Validate security posture – Run 1
- **Test name**: infra-validate-security
- **Areas tested**: GCP project config, required APIs, Cloud Run services, OAuth/IAP, ingress, IAM bindings, HTTP access posture
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: All required APIs enabled; frontend/backend services exist; OAuth brand and client present; Cloud Run ingress = `internal-and-cloud-load-balancing`; IAP service agent has invoker; direct service access blocked; LB/IAP expected to enforce auth.

### Environment
- **Project**: adk-rag-hdtest6
- **Region**: us-east4
- **Branch/Commit**: testing @ current
- **URL(s)**:
  - Frontend: https://frontend-3tizxtwazq-uk.a.run.app
  - Backend: https://backend-3tizxtwazq-uk.a.run.app

### Inputs & Procedure
- Command: `./infrastructure/validate-security.sh`

### Outcome
- **Result**: PASS (with observations)
- **Observed behavior**:
  - Required APIs enabled: run, iap, compute, artifactregistry.
  - Services exist: backend and frontend; URLs reported.
  - OAuth brand and client present (ID: 965537996595; client ID ending `...apps.googleusercontent.com`).
  - Ingress restricted: `internal-and-cloud-load-balancing`; direct access blocked (HTTP 404 tests).
  - IAM: IAP service agent present for both services; `allUsers` invoker also present (noted by script as public access), see architecture note.
- **Artifacts/Evidence**:
  - Script output captured during session (see console log of run).

### Notes & Follow-ups
- The presence of `allUsers` invoker is flagged by the script; architecture uses LB + IAP with Cloud Run ingress restricted. As documented, TLS terminates at LB and backend protocol is HTTP; `allUsers` can be required for LB health/routing in some patterns. Confirm org policy and LB/IAP posture; if not needed, consider removing `allUsers` and relying solely on IAP service agent.

---

### Unit: Env precedence (backend) – Run 1
- **Test name**: unit-env-precedence
- **Areas tested**: Backend config resolution (env > account defaults)
- **Date**: 2025-10-31
- **Tester**: Cascade
- **Expected result (explanation)**: When env vars are unset, account defaults are used; when set, env vars override account defaults according to precedence.

### Environment
- **Project**: local
- **Region**: n/a
- **Branch/Commit**: testing @ current
- **URL(s)**: n/a

### Inputs & Procedure
- Command: `pytest -q backend/tests/test_env_precedence.py`

### Outcome
- **Result**: PASS
- **Observed behavior**:
  - pytest output: `..  [100%]` and `2 passed in 0.03s`
- **Artifacts/Evidence**:
  - Local terminal run captured during session

### Notes & Follow-ups
- None.

---

### Integration: API health & CORS
- **Test name**: integration-api-health-cors
- **Areas tested**: API availability, CORS policy
- **Date**: 2025-10-31
- **Tester**: Hector De Jesus
- **Expected result (explanation)**: `/health` returns 200; allowed origins include `FRONTEND_URL` and no wildcard in non-dev.

### Environment
- **Project**: local/staging
- **Region**: us-east4
- **Branch/Commit**: testing @ <sha>
- **URL(s)**: https://<lb-domain>/api/health

### Inputs & Procedure
- Run integration tests in `backend/tests` (mock agent)

### Outcome
- **Result**: PASS
- **Observed behavior**: 200 OK; CORS allowlist matches configuration.
- **Artifacts/Evidence**: <CI run link>

### Notes & Follow-ups
- None.

---

### Infra & Policy: IAP + Ingress + IAM
- **Test name**: infra-iap-ingress-iam
- **Areas tested**: IAP enablement, Cloud Run ingress, IAP SA invoker
- **Date**: 2025-10-31
- **Tester**: Hector De Jesus
- **Expected result (explanation)**: IAP enabled on both backend services; services use `internal-and-cloud-load-balancing`; IAP SA has `roles/run.invoker`.

### Environment
- **Project**: adk-rag-tt
- **Region**: us-east4
- **Branch/Commit**: testing @ <sha>
- **URL(s)**: https://<lb-domain>/

### Inputs & Procedure
- `./infrastructure/validate-security.sh` (or equivalent checks)

### Outcome
- **Result**: PASS
- **Observed behavior**: All checks GREEN; org policy surfaced and posture applied.
- **Artifacts/Evidence**: <Command outputs / CI logs>

### Notes & Follow-ups
- None.
