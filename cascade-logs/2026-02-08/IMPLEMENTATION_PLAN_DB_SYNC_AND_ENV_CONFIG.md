# Implementation Plan: Database Sync & Environment Configuration Automation

**Date:** 2026-02-08
**Objective:** Automate multi-client deployment with flawless database sync and environment configuration

---

## 1. Problem Statement

The current codebase has:
- A sync script (`backend/sync_database_data.py`) that only covers 3 of ~28 tables
- No migration tracking system (no `schema_migrations` table)
- Hardcoded values scattered across deployment scripts
- No automated way to generate environment configs for new clients
- Cloud Run deploy script missing Cloud SQL connection variables

## 2. Complete Database Table Inventory (28 tables)

### Phase 1 — Parent Tables (no FK dependencies on other custom tables)
1. `users`
2. `groups`
3. `roles`
4. `agents`
5. `corpora`
6. `chatbot_users` (FK: `created_by` → `users`)
7. `chatbot_groups` (FK: `created_by` → `users`)
8. `chatbot_agents`
9. `chatbot_agent_types` (renamed from `chatbot_roles`)
10. `chatbot_tools` (renamed from `chatbot_permissions`)

### Phase 2 — Junction/Child Tables
11. `user_profiles` (FK: `users`)
12. `user_groups` (FK: `users`, `groups`)
13. `group_roles` (FK: `groups`, `roles`)
14. `user_agent_access` (FK: `users`, `agents`)
15. `group_corpus_access` (FK: `groups`, `corpora`)
16. `chatbot_user_groups` (FK: `chatbot_users`, `chatbot_groups`)
17. `chatbot_group_agent_types` (renamed from `chatbot_group_roles`)
18. `chatbot_agent_type_tools` (renamed from `chatbot_role_permissions`)
19. `chatbot_corpus_access` (FK: `chatbot_groups`, `corpora`)
20. `chatbot_agent_access` (FK: `chatbot_groups`, `agents`)
21. `chatbot_tool_access` (FK: `chatbot_groups`, `agents`)
22. `chatbot_group_agents` (FK: `chatbot_groups`, `chatbot_agents`)

### Phase 3 — Metadata/Log Tables
23. `user_sessions` (FK: `users`, `agents`)
24. `session_corpus_selections` (FK: `users`, `corpora`)
25. `corpus_audit_log` (FK: `corpora`, `users`)
26. `corpus_metadata` (FK: `corpora`, `users`)
27. `corpus_sync_schedule` (FK: `corpora`)
28. `document_access_log` (FK: `users`, `corpora`)

## 3. Deliverables

### Tool 1: `backend/db_sync.py` (replaces `sync_database_data.py`)
- Syncs ALL tables in correct FK dependency order
- Dry-run mode
- Verification mode (compare without modifying)
- Pre-sync Cloud SQL backup
- Sequence reset after sync
- Post-sync row count verification
- Reads client config from `environments/<client>.yaml`

### Tool 2: `backend/deploy_env_config.py`
- Reads `environments/<client>.yaml`
- Generates: `deployment.config`, `backend/.env.local`, `backend/config/<account>/config.py`
- Validates all required values before writing
- Backs up existing files before overwriting

### Structure: `environments/` directory
- `environments/client-template.yaml` — template for new clients
- `environments/develom.yaml` — current production config
- `environments/usfs.yaml` — USFS client config
- `environments/tt.yaml` — TechTrend client config

### Fix: `infrastructure/lib/cloudrun.sh`
- Add `DB_NAME`, `DB_USER`, `CLOUD_SQL_CONNECTION_NAME` to Cloud Run env vars
- Add `--add-cloudsql-instances` flag
- Remove stale `DATABASE_PATH` reference

## 4. Sync Algorithm

```
1. Connect to source (local) and target (cloud) databases
2. For each table in FK-dependency order:
   a. Fetch all rows from source
   b. Fetch all rows from target
   c. Compute diff (inserts, updates, deletes)
   d. Apply changes with ON CONFLICT handling
3. Reset all sequences to max(id) + 1
4. Verify row counts match
5. Report summary
```

## 5. Usage Workflow

```bash
# Step 1: Configure environment for client
python backend/deploy_env_config.py --env environments/usfs.yaml

# Step 2: Preview database sync
python backend/db_sync.py --to-cloud --dry-run --env environments/usfs.yaml

# Step 3: Execute sync with backup
python backend/db_sync.py --to-cloud --backup --env environments/usfs.yaml

# Step 4: Verify parity
python backend/db_sync.py --verify --env environments/usfs.yaml

# Step 5: Deploy
./infrastructure/deploy-all.sh
```
