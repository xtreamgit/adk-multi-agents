---
description: Manual deploy from local repo to Google Cloud Run (backend + frontend)
---

# Deploy to Cloud (Manual Hotfix Path)

> ⚠️ **DEVELOM ONLY.** Every command in this runbook is hardcoded to the develom
> project `adk-rag-ma`. It does **NOT** read `deployment.config` and will **NOT**
> deploy to TechTrend (`adk-rag-tt-488718`) or any other environment. To deploy a
> different environment, use `infrastructure/deploy-all.sh` (which sources
> `deployment.config`) or `deploy-single-region.sh` / `deploy-with-tests.sh`
> (now config-driven). Do not use this runbook for TechTrend.

Deploys the current local code to Cloud Run without going through the CI/CD pipeline.
Use this for hotfixes or quick iterations. For production releases, prefer merging to `main` and letting GitHub Actions handle it.

## Prerequisites

- `gcloud` CLI authenticated: `gcloud auth list`
- Project set: `gcloud config set project adk-rag-ma`
- Docker configured: `gcloud auth configure-docker us-west1-docker.pkg.dev`

## Configuration

| Key | Value |
|-----|-------|
| Project | `adk-rag-ma` |
| Region | `us-west1` |
| Artifact Registry | `us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1` |
| Backend service | `backend` |
| Frontend service | `frontend` |
| IAP URL | `https://34.49.46.115.nip.io` |

## Steps

### 1. Set the image tag (use current git short SHA)

```bash
export TAG=$(git rev-parse --short HEAD)
echo "Deploying tag: $TAG"
```

### 2. Build backend image via Cloud Build

// turbo
```bash
cd backend && gcloud builds submit . \
  --config=cloudbuild.yaml \
  --substitutions=_BACKEND_IMAGE="us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/backend:$TAG" \
  --project=adk-rag-ma
```

### 3. Deploy backend to Cloud Run

```bash
gcloud run services update backend \
  --image="us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/backend:$TAG" \
  --region=us-west1 --project=adk-rag-ma --quiet
```

### 4. Build frontend image via Cloud Build

// turbo
```bash
cd frontend && gcloud builds submit . \
  --config=cloudbuild.yaml \
  --substitutions=_IMAGE_NAME="us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/frontend:$TAG",_BACKEND_URL="https://34.49.46.115.nip.io" \
  --project=adk-rag-ma
```

### 5. Deploy frontend to Cloud Run

```bash
gcloud run services update frontend \
  --image="us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/frontend:$TAG" \
  --region=us-west1 --project=adk-rag-ma --quiet
```

### 6. Smoke test

// turbo
```bash
curl -s --max-time 10 -o /dev/null -w "LB: %{http_code}\n" https://34.49.46.115.nip.io/api/health
```

A **302** means IAP is redirecting (services are live, auth required).
A **200** means health check passed (if authenticated).

### 7. Push branch to GitHub

```bash
git push origin $(git branch --show-current)
```

## Rollback

To roll back a service to its previous revision:

```bash
PREVIOUS=$(gcloud run revisions list --service=backend --region=us-west1 --project=adk-rag-ma --format="value(metadata.name)" --limit=2 | tail -n 1)
gcloud run services update-traffic backend --to-revisions=$PREVIOUS=100 --region=us-west1 --project=adk-rag-ma --quiet
```

## CI/CD Pipeline (Alternative)

For production releases, merge to `main` and GitHub Actions handles everything:

1. `git push origin <branch>`
2. Create PR → `main`
3. CI runs: backend tests, frontend lint/type-check/build, security scan
4. Merge triggers: Cloud Build → Cloud Run deploy → smoke tests → auto-rollback on failure

See `.github/workflows/ci-cd.yml` for details.
