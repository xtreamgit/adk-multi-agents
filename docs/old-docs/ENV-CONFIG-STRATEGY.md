# Environment Configuration Strategy

This document defines a single source of truth and a predictable precedence model for environment configuration across the ADK RAG TT codebase.

## Goals
- **Single source of truth** for runtime/build-time variables
- **Predictable precedence** across environments and accounts
- **Minimize hidden defaults** in code and Dockerfiles
- **Testable rollout** with easy rollback

## Variable Classes and Owners
- **Backend runtime (Cloud Run env vars) – Owner: deployment scripts**
  - `ACCOUNT_ENV` (selects account: `develom`, `usfs`, `tt`)
  - `PROJECT_ID` (Vertex AI project)
  - `GOOGLE_CLOUD_LOCATION` (Vertex AI region)
  - `FRONTEND_URL` (CORS allowlist origin)
  - `SECRET_KEY` (JWT signing key)
  - `LOG_LEVEL` (logging verbosity)
- **Frontend build-time (Cloud Build substitutions) – Owner: deployment scripts**
  - `_BACKEND_URL` → `NEXT_PUBLIC_BACKEND_URL` (API base URL)
- **Library toggles (stable defaults)**
  - `GOOGLE_GENAI_USE_VERTEXAI=true` (forces ADK to Vertex AI)

## Precedence Model
1. **Runtime/Build inputs**
   - Backend: Cloud Run env vars from `deployment.config` + scripts
   - Frontend: Cloud Build substitutions (`_BACKEND_URL`)
2. **Account defaults**
   - `backend/config/<account>/config.py` provides defaults for `PROJECT_ID`, `LOCATION`, corpora mappings, domain
3. **Last-resort hardcoded defaults**
   - Avoid when possible; only safe, non-environmental defaults remain

## File/Variable Mapping
- **Backend**
  - `backend/src/api/server.py`
    - Reads: `FRONTEND_URL`, `LOG_LEVEL`, `SECRET_KEY`
    - Uses `ACCOUNT_ENV` to load account modules via `config_loader`
    - Should NOT mutate `os.environ` for `PROJECT_ID`/`GOOGLE_CLOUD_LOCATION`
  - `backend/src/rag_agent/config.py`
    - Reads `PROJECT_ID`, `GOOGLE_CLOUD_LOCATION` (with fallbacks)
  - `backend/src/rag_agent/__init__.py`
    - Initializes Vertex AI using resolved project/location
  - `backend/src/rag_agent/agent.py`
    - Ensures ADK uses Vertex AI via `GOOGLE_GENAI_USE_VERTEXAI`, mirrors project/location
- **Account Configs**
  - `backend/config/<account>/config.py` – account defaults (no side effects)
  - `backend/config/config_loader.py` – dynamic import & validation
- **Frontend**
  - `frontend/src/lib/api.ts` – uses `NEXT_PUBLIC_BACKEND_URL`
  - `frontend/Dockerfile` – passes `NEXT_PUBLIC_BACKEND_URL` ARG/ENV at build
  - `frontend/cloudbuild.yaml` – sets build arg from `${_BACKEND_URL}`
- **Infrastructure**
  - `deployment.config` – single source of truth for runtime + build inputs
  - `infrastructure/deploy-all.sh` and `infrastructure/lib/*.sh` – apply envs
  - `infrastructure/validate-deployment.sh` – validates required inputs

## Rollout Plan (Summary)
1. Document strategy (this file)
2. Refactor server to **read** env first, fallback to account defaults; remove env mutation
3. Trim Dockerfile to remove project/region/account defaults
4. Standardize `deployment.config` and validation to inject all runtime/build inputs
5. Enforce via CI and add testing docs

## Rollback Plan
- Each step is reversible:
  - Revert commits for server refactor or Dockerfile trims
  - Temporarily reintroduce Dockerfile env defaults if needed
  - Disable validation script in pipelines

## Validation Checklist
- Backend starts with only Cloud Run envs set (no Dockerfile project/region defaults)
- Changing `ACCOUNT_ENV` at runtime switches to the correct account config
- `PROJECT_ID`/`GOOGLE_CLOUD_LOCATION` from runtime env override account defaults
- `FRONTEND_URL` correctly whitelisted in CORS
- `SECRET_KEY` never uses example/default in non-dev
- Frontend `NEXT_PUBLIC_BACKEND_URL` is set via `_BACKEND_URL` substitution

## Non-Goals
- Managing Google credentials in env (Cloud Run SA handles auth)
- Storing secrets in the repo

## Notes
- Keep `GOOGLE_GENAI_USE_VERTEXAI=true` across environments to avoid API mismatches
- Use Secret Manager for `SECRET_KEY` in production environments
