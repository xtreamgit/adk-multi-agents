# Google Groups Bridge — Implementation Plan

**Date:** February 15, 2026  
**Goal:** Automatically assign users to chatbot groups and corpora based on their Google Group memberships, eliminating per-user manual setup.

---

## Architecture Overview

```
User logs in via IAP
        │
        ▼
hybrid_auth_middleware.py
        │
        ├─ Verify IAP JWT (existing)
        ├─ Get/create user in DB (existing)
        │
        ▼  ← NEW
google_groups_bridge.py
        │
        ├─ Query Cloud Identity API for user's Google Groups
        ├─ Look up google_group_mappings table
        ├─ Sync user → chatbot_user_groups (agent type dimension)
        ├─ Sync user → chatbot_corpus_access (corpus dimension)
        └─ Return user with updated permissions
```

## Design Decision: Option B (Map Existing Org Groups Directly)

We map the customer's **existing** Google Groups (e.g., `develom-developers@develom.com`) directly to agent types and corpora. No new Google Groups need to be created.

**Two-dimensional model:**
- **Dimension 1 — Agent type:** Which Google Group → which agent type (viewer, contributor, content-manager, admin)
- **Dimension 2 — Corpus access:** Which Google Group → which corpora (with permission level)

A user in multiple groups gets the **highest** agent type and the **union** of all corpus access.

---

## Current System Summary (What Exists)

### Database Tables (Chatbot System)
| Table | Purpose |
|---|---|
| `chatbot_users` | Chatbot user accounts (separate from `users` table) |
| `chatbot_groups` | Chatbot groups (e.g., viewer-group, admin-group) |
| `chatbot_user_groups` | User ↔ Group membership (M:M) |
| `chatbot_group_agent_types` | Group ↔ Agent Type mapping (M:M) |
| `chatbot_agent_types` | Agent types (viewer, contributor, content-manager, admin) |
| `chatbot_corpus_access` | Group ↔ Corpus access with permission level |
| `chatbot_agents` | Agent definitions with tool configs (JSONB) |
| `chatbot_group_agents` | Group ↔ Agent assignment |

### Auth Flow (Current)
1. `hybrid_auth_middleware.py` — verifies IAP JWT or Bearer token
2. `iap_service.py` — decodes IAP JWT, extracts email/google_id
3. `user_service.py` — get/create user in `users` table
4. `tool_permission_middleware.py` — looks up user's agent type via `chatbot_users` → `chatbot_user_groups` → `chatbot_group_agent_types`

### Key Gap
The `chatbot_users` table is **separate** from the `users` table. IAP creates users in `users`, but tool permissions look up `chatbot_users`. The bridge must ensure both tables are in sync.

---

## Phase 1: Database Migration

**File:** `backend/src/database/migrations/011_google_group_mappings.sql`

### New Table: `google_group_agent_mappings`
Maps a Google Group email → chatbot agent type.

```sql
CREATE TABLE IF NOT EXISTS google_group_agent_mappings (
    id SERIAL PRIMARY KEY,
    google_group_email VARCHAR(255) NOT NULL,
    agent_type VARCHAR(100) NOT NULL,  -- 'viewer', 'contributor', 'content-manager', 'admin'
    priority INTEGER DEFAULT 0,        -- Higher = takes precedence if conflicts
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    UNIQUE(google_group_email)
);
```

### New Table: `google_group_corpus_mappings`
Maps a Google Group email → corpus access with permission level.

```sql
CREATE TABLE IF NOT EXISTS google_group_corpus_mappings (
    id SERIAL PRIMARY KEY,
    google_group_email VARCHAR(255) NOT NULL,
    corpus_id INTEGER NOT NULL REFERENCES corpora(id) ON DELETE CASCADE,
    permission VARCHAR(50) NOT NULL DEFAULT 'query',  -- 'query', 'read', 'upload', 'delete', 'admin'
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    UNIQUE(google_group_email, corpus_id)
);
```

### New Table: `user_google_group_sync`
Tracks the last sync state per user to avoid redundant API calls.

```sql
CREATE TABLE IF NOT EXISTS user_google_group_sync (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    google_groups JSONB,              -- Cached list of group emails
    last_synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sync_source VARCHAR(50) DEFAULT 'login',  -- 'login', 'manual', 'scheduled'
    UNIQUE(user_id)
);
```

---

## Phase 2: Google Groups Service

**File:** `backend/src/services/google_groups_service.py`

Queries the Google Cloud Identity API (or Admin SDK Directory API) for a user's group memberships.

### API Choice
- **Cloud Identity Groups API** (`cloudidentity.googleapis.com`) — preferred, works with Cloud Identity Free
- Method: `groups.memberships.searchDirectGroups` or `groups.memberships.list`
- Alternative: **Admin SDK Directory API** (`admin.googleapis.com`) — requires domain-wide delegation

### Implementation
```python
class GoogleGroupsService:
    @staticmethod
    async def get_user_groups(user_email: str) -> List[str]:
        """
        Query Google Cloud Identity API for user's direct group memberships.
        Returns list of group email addresses.
        """
        # Uses Application Default Credentials (service account)
        # Requires: roles/cloudidentity.groupsViewer on the SA
        pass

    @staticmethod
    async def is_available() -> bool:
        """Check if Google Groups integration is enabled and configured."""
        pass
```

### Configuration
- Environment variable: `GOOGLE_GROUPS_ENABLED=true/false`
- Environment variable: `GOOGLE_GROUPS_CACHE_TTL=300` (seconds, default 5 min)
- Service account needs: `roles/cloudidentity.groupsViewer` or equivalent

### Caching Strategy
- Cache user group memberships for `GOOGLE_GROUPS_CACHE_TTL` seconds
- Store in `user_google_group_sync` table
- On login: check if cache is fresh; if so, skip API call

---

## Phase 3: Bridge Sync Service

**File:** `backend/src/services/google_groups_bridge.py`

The core logic that maps Google Groups → chatbot groups + corpus access.

### Implementation
```python
class GoogleGroupsBridge:
    @staticmethod
    async def sync_user_access(user: User, google_groups: List[str]) -> dict:
        """
        Sync a user's chatbot group memberships and corpus access
        based on their Google Group memberships.
        
        Steps:
        1. Ensure user exists in chatbot_users table
        2. Look up google_group_agent_mappings for matching groups
        3. Determine highest agent type
        4. Find/create the corresponding chatbot_group
        5. Update chatbot_user_groups (remove old, add new)
        6. Look up google_group_corpus_mappings for matching groups
        7. Update chatbot_corpus_access
        8. Update user_google_group_sync cache
        
        Returns:
            dict with agent_type, corpora, and sync status
        """
        pass

    @staticmethod
    async def ensure_chatbot_user(user: User) -> int:
        """
        Ensure the app user has a corresponding chatbot_users record.
        Creates one if it doesn't exist, matched by username/email.
        Returns chatbot_user_id.
        """
        pass
```

### Sync Logic Detail

**Agent Type Resolution:**
1. Get all `google_group_agent_mappings` where `google_group_email` is in user's groups
2. Pick the one with highest priority (admin=4 > content-manager=3 > contributor=2 > viewer=1)
3. Find the corresponding `chatbot_group` (e.g., "admin-group")
4. Ensure user is in that group via `chatbot_user_groups`
5. Remove user from other agent-type groups (to avoid stale assignments)

**Corpus Access Resolution:**
1. Get all `google_group_corpus_mappings` where `google_group_email` is in user's groups
2. For each corpus, take the highest permission level across all matching groups
3. Upsert into `chatbot_corpus_access` for the user's chatbot group
4. Remove corpus access entries that are no longer mapped

---

## Phase 4: Middleware Integration

**File:** `backend/src/middleware/hybrid_auth_middleware.py` (modify existing)

Add bridge sync call after successful IAP authentication.

### Changes
In `get_current_user_hybrid()`, after the IAP user is created/found:

```python
# After: user = UserService.get_user_by_email(email) or create_user_from_iap(...)
# Add:
if GoogleGroupsBridge.is_enabled():
    try:
        google_groups = await GoogleGroupsService.get_user_groups(email)
        await GoogleGroupsBridge.sync_user_access(user, google_groups)
    except Exception as e:
        logger.warning(f"Google Groups sync failed for {email}: {e}")
        # Non-fatal: user can still access app with existing permissions
```

### Key Design Decisions
- **Non-blocking on failure:** If the Cloud Identity API is down, the user still logs in with their last-synced permissions
- **Cache-aware:** Skip API call if sync happened within `GOOGLE_GROUPS_CACHE_TTL`
- **IAP-only:** Bridge only runs on IAP login path, not Bearer token path (local users managed manually)

---

## Phase 5: Admin API Endpoints

**File:** `backend/src/api/routes/google_groups_admin.py` (new)

### Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/admin/google-groups/agent-mappings` | List all agent mappings |
| `POST` | `/api/admin/google-groups/agent-mappings` | Create agent mapping |
| `PUT` | `/api/admin/google-groups/agent-mappings/{id}` | Update agent mapping |
| `DELETE` | `/api/admin/google-groups/agent-mappings/{id}` | Delete agent mapping |
| `GET` | `/api/admin/google-groups/corpus-mappings` | List all corpus mappings |
| `POST` | `/api/admin/google-groups/corpus-mappings` | Create corpus mapping |
| `PUT` | `/api/admin/google-groups/corpus-mappings/{id}` | Update corpus mapping |
| `DELETE` | `/api/admin/google-groups/corpus-mappings/{id}` | Delete corpus mapping |
| `GET` | `/api/admin/google-groups/status` | Bridge status (enabled, last sync, stats) |
| `POST` | `/api/admin/google-groups/sync/{user_id}` | Force re-sync a specific user |
| `POST` | `/api/admin/google-groups/sync-all` | Force re-sync all users |

---

## Phase 6: Admin UI

**File:** `frontend/src/app/admin/google-groups/page.tsx` (new)

### UI Components
1. **Agent Mappings Table** — CRUD for Google Group → Agent Type
2. **Corpus Mappings Table** — CRUD for Google Group → Corpus + Permission
3. **Sync Status Panel** — Shows last sync time, user count, errors
4. **Manual Sync Button** — Force re-sync for a user or all users

### Navigation
Add "Google Groups" menu item under "Chatbot Access" section in `frontend/src/app/admin/layout.tsx`.

---

## Phase 7: Deployment Updates

**File:** `infrastructure/lib/iap.sh` or new `infrastructure/lib/google-groups.sh`

### Required GCP Setup
1. Enable Cloud Identity API:
   ```bash
   gcloud services enable cloudidentity.googleapis.com --project=$PROJECT_ID
   ```

2. Grant service account permission to read group memberships:
   ```bash
   # The backend service account needs group viewer access
   gcloud projects add-iam-policy-binding $PROJECT_ID \
       --member="serviceAccount:${BACKEND_SA}" \
       --role="roles/cloudidentity.groupsViewer"
   ```

3. Add environment variables to backend Cloud Run service:
   ```bash
   gcloud run services update backend \
       --region=$REGION \
       --update-env-vars="GOOGLE_GROUPS_ENABLED=true,GOOGLE_GROUPS_CACHE_TTL=300"
   ```

---

## Implementation Order

| Phase | Priority | Dependencies | Estimated Effort |
|---|---|---|---|
| **Phase 1:** DB Migration | HIGH | None | Small |
| **Phase 2:** Google Groups Service | HIGH | Phase 1 | Medium |
| **Phase 3:** Bridge Sync Service | HIGH | Phase 1, 2 | Medium |
| **Phase 4:** Middleware Integration | HIGH | Phase 3 | Small |
| **Phase 5:** Admin API | MEDIUM | Phase 1 | Medium |
| **Phase 6:** Admin UI | MEDIUM | Phase 5 | Medium |
| **Phase 7:** Deploy Updates | MEDIUM | Phase 2 | Small |

**Phases 1-4** are the core bridge. Once complete, the bridge works — admins configure mappings via SQL or API.  
**Phases 5-6** add the UI for managing mappings without SQL.  
**Phase 7** is the GCP configuration needed before the bridge can call the Cloud Identity API.

---

## Testing Strategy

1. **Unit tests:** Mock Cloud Identity API responses, verify sync logic
2. **Integration test:** Use a real Google Group in `develom.com`, verify end-to-end
3. **Fallback test:** Disable Cloud Identity API, verify user still logs in with cached permissions
4. **Multi-group test:** User in multiple groups gets highest agent type + union of corpora

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Cloud Identity API rate limits | Cache group memberships; sync only on login, not every request |
| API unavailable | Non-fatal; fall back to cached/existing permissions |
| Service account lacks permissions | Clear error message in logs; bridge reports status via admin API |
| User not in any mapped group | Assign default "viewer" agent type with no corpus access (configurable) |
| Stale cache | TTL-based expiration; manual sync button in admin UI |
