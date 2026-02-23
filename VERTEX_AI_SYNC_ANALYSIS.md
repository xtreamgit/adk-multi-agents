# Vertex AI RAG Corpora Synchronization Analysis
**Date:** February 11, 2026  
**Branch:** vertex-sync  
**Issue:** Database data doesn't reflect actual Vertex AI RAG corpora

---

## Problem Statement

The chatbot UI displays corpus data from the PostgreSQL database, which may not reflect the actual corpora in Vertex AI. When deploying to a new environment:

1. Database is seeded with sample/old corpus data
2. Vertex AI has different corpora (different names, IDs, counts)
3. UI shows incorrect corpus information
4. Users see corpora that don't exist or miss corpora that do exist

**Goal:** Deploy to a new environment and immediately show accurate Vertex AI data without manual intervention.

---

## Current Architecture

### Data Flow

```
Vertex AI RAG (Source of Truth)
         ↓
    [Manual Sync]
         ↓
PostgreSQL Database (corpora table)
         ↓
Backend API (/api/corpora)
         ↓
Frontend UI (Corpus Selection)
```

### Database Schema

**`corpora` table** (from `003_add_agents_corpora.sql`):
```sql
CREATE TABLE corpora (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,           -- Display name (e.g., "ai-books")
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    gcs_bucket VARCHAR(500) NOT NULL,
    vertex_corpus_id VARCHAR(500),               -- Vertex AI resource ID
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Related tables:**
- `group_corpus_access` - Which groups can access which corpora
- `session_corpus_selections` - User's last selected corpora
- `corpus_metadata` - Additional metadata (tags, notes, sync status)
- `corpus_audit_log` - Audit trail for corpus changes

---

## Current Sync Mechanism

### Manual Script: `sync_corpora_from_vertex.py`

**Location:** `/backend/sync_corpora_from_vertex.py`

**What it does:**
1. Fetches all corpora from Vertex AI using `rag.list_corpora()`
2. Fetches all corpora from database
3. Compares by `display_name` (Vertex AI) vs `name` (DB)
4. **Adds** new corpora from Vertex AI to DB
5. **Deactivates** corpora in DB that don't exist in Vertex AI
6. **Reactivates/Updates** corpora that exist in both
7. Grants 'default' group access to new corpora

**Limitations:**
- ❌ **Manual execution required** - Must run `python backend/sync_corpora_from_vertex.py`
- ❌ **Not part of deployment** - Not integrated into deploy scripts
- ❌ **Not automatic on startup** - Backend doesn't sync on initialization
- ❌ **Hardcoded bucket names** - Creates `gs://adk-rag-ma-{corpus_name}` (wrong for new environments)
- ❌ **No validation** - Doesn't verify corpora actually exist before showing them

---

## API Endpoints Analysis

### 1. `/api/corpora/` (GET)
**File:** `backend/src/api/routes/corpora.py:37-44`

```python
@router.get("/", response_model=List[CorpusWithAccess])
async def list_my_corpora(current_user: User = Depends(get_current_user)):
    return CorpusService.get_user_corpora(current_user.id, active_only=True)
```

**Calls:** `CorpusService.get_user_corpora()`

### 2. `CorpusService.get_user_corpora()`
**File:** `backend/src/services/corpus_service.py:177-235`

**Key behavior:**
```python
def get_user_corpora(user_id: int, active_only: bool = True, 
                    active_in_session: Optional[List[int]] = None,
                    validate_with_vertex: bool = True) -> List[CorpusWithAccess]:
    
    # 1. Fetch from database
    corpora_dict = CorpusRepository.get_user_corpora(user_id, active_only=active_only)
    
    # 2. Validate against Vertex AI (if enabled)
    if validate_with_vertex and VERTEX_AI_AVAILABLE:
        vertex_corpora = list(rag.list_corpora())
        vertex_corpus_names = {corpus.display_name for corpus in vertex_corpora}
        
        # Filter out corpora that don't exist in Vertex AI
        corpora_dict = [
            c for c in corpora_dict 
            if c['name'] in vertex_corpus_names
        ]
    
    # 3. Fetch document count from Vertex AI for each corpus
    for corpus_data in corpora_dict:
        doc_count = CorpusService._get_document_count(
            corpus_data.get('name', ''),
            corpus_data.get('vertex_corpus_id')
        )
```

**Current validation:**
- ✅ **Filters out non-existent corpora** - Won't show DB corpora that aren't in Vertex AI
- ✅ **Fetches live document counts** - Gets actual file counts from Vertex AI
- ❌ **Doesn't add new corpora** - Won't show Vertex AI corpora not in DB
- ❌ **Requires DB entries** - Can't discover new corpora automatically

---

## The Gap: What's Missing

### Scenario: New Environment Deployment

**Current State:**
1. Deploy database schema → Creates empty `corpora` table
2. Run migrations → May seed sample data (old corpus names)
3. Start backend → Connects to Vertex AI (has different corpora)
4. User logs in → Sees old/wrong corpus list from DB

**What Happens:**
- ❌ New Vertex AI corpora are invisible (not in DB)
- ❌ Old DB corpora show up (filtered out by validation, but confusing)
- ❌ No automatic sync on startup
- ❌ Admin must manually run `sync_corpora_from_vertex.py`

### Root Cause

**Database is treated as source of truth, but Vertex AI is the actual source of truth.**

The system has a **runtime validation** (`validate_with_vertex=True`) but no **automatic synchronization**.

---

## Proposed Solution

### Option 1: Automatic Sync on Backend Startup ⭐ RECOMMENDED

**Implementation:**
1. Add startup event handler in `server.py`
2. Run sync logic on application initialization
3. Sync corpora from Vertex AI to database
4. Log sync results

**Pros:**
- ✅ Zero manual intervention
- ✅ Always up-to-date on deployment
- ✅ Works for new environments automatically
- ✅ Existing sync logic can be reused

**Cons:**
- ⚠️ Adds ~2-5 seconds to startup time
- ⚠️ Requires Vertex AI credentials at startup
- ⚠️ May fail if Vertex AI is unreachable

**Code Location:**
- `backend/src/server.py` - Add `@app.on_event("startup")`
- Reuse `sync_corpora_from_vertex.py` logic

---

### Option 2: Lazy Sync on First API Call

**Implementation:**
1. Add sync check in `CorpusService.get_user_corpora()`
2. If DB is empty or stale, trigger sync
3. Cache sync timestamp to avoid repeated syncs

**Pros:**
- ✅ No startup delay
- ✅ Only syncs when needed
- ✅ Graceful degradation if Vertex AI unavailable

**Cons:**
- ⚠️ First API call is slow
- ⚠️ More complex caching logic
- ⚠️ Potential race conditions with concurrent requests

---

### Option 3: Scheduled Background Sync

**Implementation:**
1. Add background task scheduler (APScheduler)
2. Sync every N minutes (e.g., 5 minutes)
3. Keep database continuously updated

**Pros:**
- ✅ Always fresh data
- ✅ No user-facing delays
- ✅ Handles Vertex AI changes during runtime

**Cons:**
- ⚠️ Adds complexity (scheduler dependency)
- ⚠️ Unnecessary for static corpora
- ⚠️ More resource usage

---

### Option 4: Hybrid - Startup Sync + Runtime Validation

**Implementation:**
1. Sync on startup (Option 1)
2. Keep runtime validation (already exists)
3. Add manual sync endpoint for admins

**Pros:**
- ✅ Best of both worlds
- ✅ Startup sync ensures fresh data
- ✅ Runtime validation catches changes
- ✅ Admin can force sync if needed

**Cons:**
- ⚠️ Slightly more complex
- ⚠️ Startup delay still exists

---

## Recommended Implementation Plan

### Phase 1: Fix Immediate Issue (Startup Sync)

**Tasks:**
1. ✅ Extract sync logic from `sync_corpora_from_vertex.py` into reusable function
2. ✅ Add startup event handler in `server.py`
3. ✅ Call sync function on startup
4. ✅ Add error handling (don't crash if Vertex AI unavailable)
5. ✅ Log sync results

**Files to Modify:**
- `backend/src/server.py` - Add `@app.on_event("startup")`
- `backend/src/services/corpus_sync_service.py` - New service for sync logic
- `backend/sync_corpora_from_vertex.py` - Refactor to use new service

**Estimated Time:** 2-3 hours

---

### Phase 2: Fix GCS Bucket Hardcoding

**Current Issue:**
```python
gcs_bucket=f"gs://adk-rag-ma-{corpus_name}"  # Hardcoded project!
```

**Solution:**
1. Fetch actual GCS bucket from Vertex AI corpus metadata
2. Use `corpus.rag_file_chunking_config` or query corpus files
3. Infer bucket from file paths

**Files to Modify:**
- `backend/src/services/corpus_sync_service.py`

**Estimated Time:** 1 hour

---

### Phase 3: Add Admin Sync Endpoint

**Implementation:**
```python
@router.post("/admin/corpora/sync")
async def sync_corpora_from_vertex(current_user: User = Depends(require_admin)):
    """Manually trigger corpus sync from Vertex AI"""
    result = await CorpusSyncService.sync_from_vertex()
    return result
```

**Files to Modify:**
- `backend/src/api/routes/admin.py`

**Estimated Time:** 30 minutes

---

### Phase 4: Update Deployment Documentation

**Files to Update:**
- `START-HERE.md` - Note that sync happens automatically
- `PRE-DEPLOY-CHECK.md` - Verify Vertex AI corpora before deployment
- `environments/client-template.yaml` - Remove corpus seeding if any

**Estimated Time:** 30 minutes

---

## Testing Strategy

### Test Cases

1. **Fresh Deployment**
   - Deploy to new environment
   - Verify corpora auto-sync on startup
   - Check UI shows correct corpora

2. **Corpus Added in Vertex AI**
   - Create new corpus in Vertex AI
   - Restart backend
   - Verify new corpus appears in UI

3. **Corpus Deleted in Vertex AI**
   - Delete corpus from Vertex AI
   - Restart backend
   - Verify corpus is deactivated in DB
   - Verify corpus doesn't appear in UI

4. **Vertex AI Unavailable**
   - Simulate Vertex AI failure
   - Verify backend starts anyway
   - Verify error is logged
   - Verify fallback to DB data

5. **Manual Sync**
   - Call admin sync endpoint
   - Verify sync executes
   - Verify changes reflected immediately

---

## Migration Path for Existing Deployments

### For `adk-rag-ma` (Current Production)

1. Run manual sync once: `python backend/sync_corpora_from_vertex.py`
2. Deploy new code with startup sync
3. Restart backend
4. Verify sync runs on startup

### For New Client Deployments

1. Deploy schema (no sample corpus data)
2. Backend starts and auto-syncs from Vertex AI
3. Corpora appear automatically
4. No manual intervention needed

---

## Code Structure

### New File: `backend/src/services/corpus_sync_service.py`

```python
"""
Corpus synchronization service for Vertex AI RAG.
Keeps database in sync with Vertex AI as source of truth.
"""

class CorpusSyncService:
    @staticmethod
    async def sync_from_vertex() -> Dict[str, Any]:
        """
        Sync corpora from Vertex AI to database.
        Returns sync results (added, updated, deactivated counts).
        """
        pass
    
    @staticmethod
    async def sync_on_startup() -> None:
        """
        Run sync on application startup.
        Logs errors but doesn't crash the app.
        """
        pass
```

### Modified File: `backend/src/server.py`

```python
@app.on_event("startup")
async def startup_event():
    """Run initialization tasks on startup"""
    logger.info("Starting application initialization...")
    
    # Sync corpora from Vertex AI
    try:
        await CorpusSyncService.sync_on_startup()
    except Exception as e:
        logger.error(f"Failed to sync corpora on startup: {e}")
        # Don't crash - continue with existing DB data
    
    logger.info("Application initialization complete")
```

---

## Success Criteria

✅ **New deployment shows correct corpora immediately**  
✅ **No manual sync script execution required**  
✅ **Database reflects Vertex AI reality**  
✅ **Graceful handling of Vertex AI unavailability**  
✅ **Admin can trigger manual sync if needed**  
✅ **Existing deployments continue to work**  

---

## Next Steps

1. **Review this analysis with user**
2. **Confirm recommended approach (Option 4: Hybrid)**
3. **Implement Phase 1: Startup Sync**
4. **Test in development environment**
5. **Deploy to production**
6. **Update documentation**

---

## Related Files

- `backend/sync_corpora_from_vertex.py` - Current manual sync script
- `backend/src/services/corpus_service.py` - Corpus business logic
- `backend/src/database/repositories/corpus_repository.py` - Database operations
- `backend/src/api/routes/corpora.py` - API endpoints
- `backend/src/server.py` - FastAPI application
- `backend/src/database/migrations/003_add_agents_corpora.sql` - Schema

---

**Status:** Analysis Complete - Ready for Implementation  
**Recommended Approach:** Option 4 (Hybrid - Startup Sync + Runtime Validation)  
**Estimated Total Time:** 4-5 hours
