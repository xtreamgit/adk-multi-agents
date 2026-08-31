# Cloud Deploy Instructions & Session Record — ADK RAG (TechTrend / tt)

> **Purpose:** A complete, reviewable record of everything we did to validate the
> TechTrend (`tt`) environment locally and to prepare (but **not** execute) a
> cloud deploy — including the exact commands, the safety decisions, and the
> deploy procedure for when you are ready.
>
> **Date of session:** 2026-06-24
> **Environment:** TechTrend (`tt`)
> **Audience:** Future you, reviewing what happened and how to deploy safely.

---

## 0. Key facts / coordinates

| Item | Value |
|------|-------|
| GCP Project ID | `adk-rag-tt-488718` |
| GCP Project Number | `980453997632` |
| Region | `us-west1` |
| Org domain (assumed) | `techtrend.us` |
| Admin user | `hdejesus@techtrend.us` |
| Account env | `tt` |
| Cloud SQL instance | `tt-multi-agents-db` (PostgreSQL 15, **private IP only** `10.53.16.3` on `tt-vpc`) |
| Cloud DB / user | `adk_agents_db` / `adk_app_user` |
| Secrets | `tt-db-password`, `tt-app-secret-key` |
| Corpus buckets | `techtrend-articles`, `techtrend-product-documentation`, `techtrend-research` |
| Live backend URL | `https://backend-ajrko7p6bq-uw.a.run.app` (image was `tt-v1.0.27`) |
| Cloud Run services | `backend`, `backend-agent1/2/3`, `frontend` |

**Git / safety state at end of session:**

| Item | Value |
|------|-------|
| `main` baseline (unchanged) | `978c468` |
| Working branch | `feature/local-dev-tt-fixes` (commits `3031c19`, `74a1072`) |
| Pull request | **#6** (open, not merged) |
| Cloud SQL backup (restore point) | `1782316732213` (ON_DEMAND, SUCCESSFUL) |
| CI/CD Pipeline workflow | **disabled_manually** (id `219941645`) |

---

## 1. The single most important concept

**What is committed to git does NOT decide which environment runs or gets deployed.**
There are three independent "planes":

1. **Code & config** — lives in **git**, baked into a Docker **image**, deployed to Cloud Run.
   (App code, migration `.sql`, `tt.yaml`, `tt.json`, `config/tt/config.py`.)
2. **Database DATA** — lives in **each environment's own database** (local Docker Postgres
   vs. cloud Cloud SQL). Moved only by running scripts *against that database*
   (`seed_data.py`, migrations, bootstrap) — never by a git push.
3. **Vertex AI corpora** — live in the **shared** Vertex project `adk-rag-tt-488718`.
   Both local and cloud **sync FROM Vertex** on startup.

**Deploy target is decided by `deployment.config`** (for `deploy-all.sh`), or is
**hardcoded** (CI and some scripts target develom). A `git push` does not deploy to TT.

---

## 2. What we did this session (chronological)

### 2.1 Git safety check (before any work)
- Discovered local `main` was **behind** remote by one commit and fast-forwarded:
  ```bash
  git pull --ff-only origin main      # c3ce378 -> 978c468, clean fast-forward
  ```
- Confirmed nothing of ours could overwrite remote (we were 0 ahead).

### 2.2 Completed the TechTrend (`tt`) configuration
- Filled `environments/tt.yaml` with real project values + a full `seed_data` block.
- Generated config files from the YAML:
  ```bash
  cd backend && python deploy_env_config.py --env ../environments/tt.yaml
  # -> deployment.config, backend/.env.local, backend/config/tt/config.py
  ```
- Appended local-dev-only settings to `backend/.env.local`:
  ```
  IAP_DEV_MODE=true
  IAP_DEV_USER_EMAIL=hdejesus@techtrend.us
  SECRET_KEY=local-dev-secret-key
  GOOGLE_GROUPS_ENABLED=false
  ```
- Created `backend/config/agent_instructions/tt.json` (the agent fallback that loads).

### 2.3 Brought up the local stack
- Started local PostgreSQL (Docker, port 5433):
  ```bash
  cd backend && docker compose -f docker-compose.dev.yml up -d
  ```
  (We wiped the old 3-month-old dev volume for a clean slate, with confirmation.)
- Applied schema + all numbered migrations in order (the `run_migrations.py` stub is a
  no-op; migrations live in `src/database/migrations/*.sql`):
  ```bash
  for f in $(ls src/database/migrations/*.sql | sort); do
    docker exec -i adk-postgres-dev psql -U adk_dev_user -d adk_agents_db_dev < "$f"
  done
  ```
  (Two benign errors are expected: `006` can't drop `users`; `008` sample data
  references a renamed column.)
- Seeded the database:
  ```bash
  python seed_data.py --env ../environments/tt.yaml --target local
  ```

### 2.4 Fixed three local-only data gaps (the `bootstrap_local_tt.sh` script)
The standard seed leaves gaps the cloud already has. We wrote an idempotent helper:
```bash
./backend/scripts/bootstrap_local_tt.sh
```
It does:
1. Seeds the **legacy `agents` table** (`tt-agent`, `config_path=tt`) + grants the admin
   `user_agent_access` + sets default → fixes **"No agent assigned"**.
2. Grants **`admin-group` → all corpora** in `chatbot_corpus_access` → fixes
   **"You do not have access to corpus"** (the Google Groups Bridge does this in cloud,
   but it's disabled locally).
3. Runs `sync_corpus_document_counts.py` → fixes **"0 documents"** in the UI.

### 2.5 Fixed the Vertex AI ADC (Application Default Credentials)
The app reads Vertex through ADC, which is separate from the gcloud CLI account. It was
pointed at develom; we re-pointed it to TechTrend:
```bash
gcloud auth application-default login --account=hdejesus@techtrend.us
gcloud auth application-default set-quota-project adk-rag-tt-488718
```
After this, corpus sync succeeded and live RAG chat worked.

### 2.6 Ran the local app
```bash
# Backend (loads .env.local via dotenv)
cd backend && python -m uvicorn src.api.server:app --host 0.0.0.0 --port 8000

# Frontend
cd frontend && npm run dev      # http://localhost:3000
```
Validated: health, IAP-dev auth as the admin, agent load, and end-to-end RAG queries
against `adk-rag-span-corp1` (70 docs).

### 2.7 Code fixes made
- **Document browser** — `DocumentService.stream_blob()` + proxy/retrieve fallback so
  PDFs view/download locally (signed URLs need a service account; local ADC is a user).
  Files: `backend/src/services/document_service.py`, `backend/src/api/routes/documents.py`.
- **Default corpus** — frontend auto-selects the first accessible corpus with documents
  when none is saved (the `DEFAULT_CORPUS_NAME` config was dead). File:
  `frontend/src/app/page.tsx`.

### 2.8 Made the deploy scripts config-driven (de-trapped)
- `deploy-single-region.sh` was sourcing `deployment.config` then **overwriting**
  `PROJECT_ID="adk-rag-ma"` — removed the override.
- `deploy-with-tests.sh` never sourced it — now sources `deployment.config` and derives
  image bases from `PROJECT_ID`/`REPO`.
- `.windsurf/workflows/deploy-to-cloud.md` — added a **DEVELOM-ONLY** warning banner.

### 2.9 Cloud verification (read-only) + backup
- Created an on-demand Cloud SQL backup (restore point `1782316732213`):
  ```bash
  gcloud sql backups create --instance=tt-multi-agents-db --project=adk-rag-tt-488718
  ```
- The cloud DB is **private-IP only**, so it cannot be reached from a laptop via the proxy.
  We inspected it read-only via **Cloud SQL Studio** (console) instead.
- **Result:** the cloud database is complete and self-sufficient — it has its own agents,
  groups, mappings, admin user, and corpus access. **Corpora are in sync with local**
  (both mirror Vertex). **No data migration from local to cloud is needed.**

### 2.10 Captured work in version control (no deploy)
```bash
git switch -c feature/local-dev-tt-fixes
# staged only the intended files (NOT .env.local / deployment.config / *.bak / data/)
git commit ...        # 3031c19, then 74a1072
git push -u origin feature/local-dev-tt-fixes
gh pr create ...      # PR #6
```

### 2.11 Locked off accidental develom deploys
```bash
gh workflow disable "CI/CD Pipeline"     # id 219941645 -> disabled_manually
```

---

## 3. How a deploy actually reaches each environment

There are **5 deploy mechanisms**. Only `deploy-all.sh` reads `deployment.config`.

| Mechanism | Target | Notes |
|-----------|--------|-------|
| `infrastructure/deploy-all.sh` | **`deployment.config`** (currently TT) | Full 7-phase deploy. The only env-aware path. |
| `deploy-single-region.sh` | `deployment.config` *(after our fix)* | Backend services only; surgical image update. |
| `deploy-with-tests.sh` | `deployment.config` *(after our fix)* | Builds + tests + deploys. |
| `/deploy-to-cloud` (windsurf) | **develom (hardcoded)** | Do not use for TT. |
| GitHub Actions CI | **develom (hardcoded)** | Triggers on push to `main`; **now disabled**. |

> ⚠️ The fixed versions of `deploy-single-region.sh` / `deploy-with-tests.sh` live on the
> `feature/local-dev-tt-fixes` branch / PR #6. On `main` they are still the old
> develom-hardcoded versions until the PR is merged.

---

## 4. How NOT to accidentally deploy to develom

- ✅ CI/CD Pipeline workflow is **disabled** — no push/merge can auto-deploy.
- 🚫 Do **not** merge PR #6 expecting a TT deploy — merging to `main` is wired to develom CI
  (currently disabled, but don't rely on that).
- 🚫 Do **not** run `/deploy-to-cloud` (develom-hardcoded).
- 🚫 Do **not** run `deploy-with-tests.sh` / `deploy-single-region.sh` from a `main`
  checkout (develom-hardcoded there).
- ✅ Your local `deployment.config` = TT, so `deploy-all.sh` and the fixed scripts target TT.

---

## 5. Deploying to the TechTrend cloud (Step 2 — when ready)

> **This was intentionally NOT executed this session.** The cloud already works; this is
> the safe procedure for shipping the code fixes when you decide to.

### 5.1 Pre-flight
```bash
# Confirm the target is TT
grep -E '^(PROJECT_ID|REGION|ACCOUNT_ENV)' deployment.config
#   PROJECT_ID="adk-rag-tt-488718"  REGION="us-west1"  ACCOUNT_ENV="tt"

# Confirm gcloud + ADC are the TT account
gcloud config get-value account     # hdejesus@techtrend.us
gcloud config get-value project     # adk-rag-tt-488718

# Read-only resource scan
./infrastructure/pre-deploy-check.sh --project-id=adk-rag-tt-488718 --region=us-west1
```

### 5.2 Pre-deploy check findings to respect (from this session)
- 🔴 **OAuth clients exist → DELETED on full redeploy** (`iap.sh`). A full `deploy-all.sh`
  would break the working TT login. **Skip OAuth/IAP phases.**
- 🔴 **No Load Balancer** in TT — a full deploy would create new LB/IP/SSL you don't use.
  **Skip the load-balancer phase.**
- 🔴 **Named service accounts not found** — the (un-skippable) infrastructure phase would
  create SAs and rebind IAM, changing the services' runtime identity.

### 5.3 Recommended: surgical backend redeploy (lowest risk)
`deploy-single-region.sh` only swaps the image on the 4 backend services and **preserves**
their existing service account and env (`ACCOUNT_ENV=tt`, etc.):
```bash
# Always back up first
gcloud sql backups create --instance=tt-multi-agents-db --project=adk-rag-tt-488718

./deploy-single-region.sh        # builds backend image to TT, updates backend services
```
> Note: this deploys **backend only**. The **frontend** default-corpus fix needs a separate
> frontend deploy to ship.

### 5.4 Verify after deploy
```bash
gcloud run services list --project=adk-rag-tt-488718 --region=us-west1
gcloud run services describe backend --project=adk-rag-tt-488718 --region=us-west1 \
  --format='value(spec.template.spec.containers[0].env)' | tr ',' '\n' | grep ACCOUNT_ENV
# Expect: ACCOUNT_ENV=tt
```

### 5.5 Rollback if needed
- Cloud Run keeps revisions — roll traffic back:
  ```bash
  gcloud run revisions list --service=backend --region=us-west1 --project=adk-rag-tt-488718
  gcloud run services update-traffic backend --to-revisions=<PREVIOUS>=100 \
    --region=us-west1 --project=adk-rag-tt-488718
  ```
- Database: restore from backup `1782316732213` (or a fresh one taken pre-deploy).

---

## 6. Managing corpora (shared Vertex — affects BOTH local and cloud)

> Corpora live in the shared Vertex project. Creating/deleting a corpus affects local
> **and** the live cloud. There is no local-only corpus add/remove.

**Add (via SDK):**
```python
import vertexai; from vertexai import rag
vertexai.init(project='adk-rag-tt-488718', location='us-west1')
corpus = rag.create_corpus(display_name='research-papers')
rag.import_files(corpus_name=corpus.name, paths=['gs://techtrend-research/'],
                 chunk_size=512, chunk_overlap=100)
```
**Remove (via agent chat):** `"Delete the corpus research-papers"` (asks confirmation),
or `rag.delete_corpus('<full resource name>')`.

**After either, refresh the DB:**
```bash
cd backend
python sync_corpora_from_vertex.py        # add/deactivate to match Vertex
python sync_corpus_document_counts.py      # refresh UI document counts
```

---

## 7. Re-enable CI later (if you want it back)
```bash
gh workflow enable "CI/CD Pipeline"        # id 219941645
```
> The CI tests currently fail due to a deprecated GitHub Action
> (`actions/upload-artifact@v3`), unrelated to our code. Fixing that (bump to `@v4`) is a
> small, separate housekeeping change.

---

## 8. Outstanding / follow-ups (not done this session)
- [ ] Decide whether to deploy the **frontend** default-corpus fix to TT (backend-only won't ship it).
- [ ] Optionally add the 3 cloud `google_group_corpus_mappings` to `tt.yaml` for parity.
- [ ] Optionally fix the CI workflow's deprecated actions and/or make it environment-aware
      (currently hardcoded to develom).
- [ ] PR #6 review/merge decision (remember: merge → `main` → develom CI path).

---

*Generated as a session record. Local-only files (`backend/.env.local`, `deployment.config`)
are environment-specific and intentionally not committed.*
