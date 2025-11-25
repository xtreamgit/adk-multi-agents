# Environment Config Testing Guide

This guide explains how to test the environment configuration model, including precedence, deployment validation, and frontend build substitution.

## What You Will Validate
- **Env precedence**: Runtime env vars override account defaults; account defaults apply when env unset.
- **Deployment inputs**: Required vars are present; `SECRET_KEY` provided via `secrets.env`.
- **Frontend build substitution**: `_BACKEND_URL` becomes `NEXT_PUBLIC_BACKEND_URL` at build.

## 1) Run Unit Tests (Backend)

```bash
# From repo root
pytest -q
```

What it does:
- `backend/tests/test_env_precedence.py` verifies:
  - Without envs: values come from selected account config (`backend/config/<account>/config.py`)
  - With envs set: env overrides account defaults

## 2) Validate Deployment Inputs (Preflight)

```bash
# Ensure your configs are defined
cat deployment.config
cat secrets.env  # contains SECRET_KEY

# Run validation
./infrastructure/validate-deployment.sh
```

Checks performed:
- Presence of: `PROJECT_ID`, `REGION`, `REPO`, `ACCOUNT_ENV`, `ORGANIZATION_DOMAIN`, and `SECRET_KEY` (from `secrets.env`)
- Exports `GOOGLE_CLOUD_LOCATION="$REGION"`
- Continues with infra checks (SSL/IAP/LB/Cloud Run) if environment is available

## 3) Build Frontend with Backend URL

Frontend build uses Cloud Build substitutions. Local build example (emulating CI):

```bash
# Build frontend image with backend URL
BACKEND_URL="https://your-backend-url.a.run.app"
gcloud builds submit ./frontend \
  --config=frontend/cloudbuild.yaml \
  --substitutions=_IMAGE_NAME="example/frontend:test",_BACKEND_URL="$BACKEND_URL"
```

Validation:
- `NEXT_PUBLIC_BACKEND_URL` is set from `_BACKEND_URL` in `frontend/cloudbuild.yaml`.
- App runtime will fetch API from this URL (see `frontend/src/lib/api.ts`).

## 4) CORS Verification (Runtime)

Backend allows:
- `http://localhost:3000`, `http://127.0.0.1:3000`, and the value of `FRONTEND_URL` if provided.

To test:
```bash
# Start backend locally with explicit envs
export ACCOUNT_ENV=tt
export PROJECT_ID=adk-rag-tt
export GOOGLE_CLOUD_LOCATION=us-east4
export SECRET_KEY="test-secret"
export FRONTEND_URL="https://frontend.example.com"
python backend/src/api/server.py
```

Expected logs contain:
```
CORS Configuration:
  FRONTEND_URL env var: https://frontend.example.com
  Allowed origins: ['http://localhost:3000', 'http://127.0.0.1:3000', 'https://frontend.example.com']
```

## 5) CI Coverage

GitHub Actions workflow in `.github/workflows/ci.yml` runs:
- Backend unit tests (env precedence)
- (Optional) Linters/type checks can be added later

## Troubleshooting
- If `validate-deployment.sh` fails early, ensure `deployment.config` and `secrets.env` exist and are populated.
- If the backend starts with wrong project/region, confirm Cloud Run env vars are set and/or `ACCOUNT_ENV` matches the desired account.
- For IAP or LB issues, see `docs/DEPLOYMENT-CHECKLIST.md` and `docs/TROUBLESHOOT.md`.
