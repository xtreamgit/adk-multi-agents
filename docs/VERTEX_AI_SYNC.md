# Vertex AI RAG Corpus Synchronization

**Status:** ✅ Implemented (Phase 1 Complete)  
**Last Updated:** February 11, 2026

---

## Overview

The application automatically synchronizes RAG corpora from Vertex AI to the PostgreSQL database on backend startup. This ensures that the UI always displays accurate, up-to-date corpus information without manual intervention.

**Key Features:**
- ✅ Automatic sync on backend startup
- ✅ Manual sync via admin API endpoint
- ✅ Standalone sync script for maintenance
- ✅ Intelligent GCS bucket detection from Vertex AI files
- ✅ Graceful error handling (doesn't crash backend if Vertex AI unavailable)

---

## How It Works

### Data Flow

```
Vertex AI RAG (Source of Truth)
         ↓
  [Automatic Sync on Startup]
         ↓
PostgreSQL Database (corpora table)
         ↓
Backend API (/api/corpora)
         ↓
Frontend UI (Corpus Selection)
```

### Sync Logic

1. **Fetch from Vertex AI:** Lists all RAG corpora using `rag.list_corpora()`
2. **Compare with Database:** Identifies differences between Vertex AI and database
3. **Add New Corpora:** Creates database entries for corpora found in Vertex AI
4. **Update Existing:** Reactivates and updates `vertex_corpus_id` for matching corpora
5. **Deactivate Missing:** Marks database corpora as inactive if not in Vertex AI
6. **Grant Access:** Automatically grants 'default' group read access to new corpora

---

## Usage

### Automatic Sync (Default)

The backend automatically syncs on startup. No action required.

**Logs to watch for:**
```
======================================================================
Starting Vertex AI corpus synchronization on startup...
======================================================================
✅ Corpus sync completed successfully
   Vertex AI corpora: 7
   Database active corpora: 7
   Added: 0, Updated: 0, Deactivated: 0
======================================================================
```

### Manual Sync (Admin API)

Trigger sync manually via the admin API endpoint:

**Endpoint:** `POST /api/admin/corpora/sync`  
**Authentication:** Requires admin privileges  
**Response:**
```json
{
  "success": true,
  "total_corpora": 7,
  "added_count": 0,
  "updated_count": 0,
  "deactivated_count": 0,
  "errors": [],
  "message": "Sync complete: 0 added, 0 updated, 0 deactivated"
}
```

**Example using curl:**
```bash
curl -X POST https://backend-url/api/admin/corpora/sync \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### Standalone Script

Run the sync script manually for maintenance or troubleshooting:

```bash
cd backend
python sync_corpora_from_vertex.py
```

**Output:**
```
======================================================================
Vertex AI Corpus Synchronization Tool
======================================================================
Project: adk-rag-ma
Location: us-west1

✅ Vertex AI initialized
📚 Found 7 corpora in Vertex AI
💾 Found 7 corpora in database
📊 Sync analysis: add=0, deactivate=0, update=0

======================================================================
Sync Results:
======================================================================
Status: SUCCESS
Vertex AI corpora: 7
Database active corpora: 7
Added: 0
Updated: 0
Deactivated: 0
======================================================================
```

---

## Implementation Details

### Files Modified/Created

**New Files:**
- `backend/src/services/corpus_sync_service.py` - Core sync service
- `backend/test_corpus_sync.py` - Test script
- `docs/VERTEX_AI_SYNC.md` - This documentation

**Modified Files:**
- `backend/src/api/server.py` - Added startup sync call
- `backend/sync_corpora_from_vertex.py` - Refactored to use service
- `backend/src/api/routes/admin.py` - Updated sync endpoint

### CorpusSyncService API

**Main Methods:**

```python
from services.corpus_sync_service import CorpusSyncService

# Sync corpora (returns detailed result dict)
result = CorpusSyncService.sync_from_vertex(project_id, location)

# Sync on startup (logs but doesn't crash on error)
CorpusSyncService.sync_on_startup(project_id, location)
```

**Result Structure:**
```python
{
    'status': 'success' | 'partial' | 'error',
    'added': 0,           # Number of corpora added
    'updated': 0,         # Number of corpora updated
    'deactivated': 0,     # Number of corpora deactivated
    'errors': [],         # List of error messages
    'vertex_count': 7,    # Total corpora in Vertex AI
    'db_active_count': 7  # Total active corpora in DB
}
```

---

## GCS Bucket Detection

The service intelligently detects GCS buckets from Vertex AI corpus files:

1. **Primary Method:** Extracts bucket from first file in corpus
   - Queries `rag.list_files(corpus_name)`
   - Parses URI: `gs://bucket-name/path/to/file.pdf` → `gs://bucket-name`

2. **Fallback Method:** Uses project-based naming convention
   - Format: `gs://{project_id}-{corpus_name}`
   - Example: `gs://adk-rag-ma-ai-books`

This eliminates hardcoded bucket names and works across different environments.

---

## Error Handling

### Startup Sync Errors

If sync fails on startup, the backend **continues to run** with existing database data:

```
⚠️  Corpus sync on startup failed (non-critical): [error message]
   Application will continue with existing database data
```

This prevents deployment failures due to temporary Vertex AI issues.

### Partial Sync

If some operations fail but others succeed, status is `partial`:

```
⚠️  Corpus sync completed with errors
   Added: 2, Updated: 3, Deactivated: 0
   Errors: 1
     - Failed to add corpus 'new-corpus': [error details]
```

### Complete Failure

If Vertex AI is completely unavailable:

```
❌ Corpus sync failed
   - Failed to initialize Vertex AI: [error details]
   Application will continue with existing database data
```

---

## Deployment Workflow

### New Environment Deployment

1. **Deploy Database Schema**
   ```bash
   python backend/src/database/migrations/run_migrations.py
   ```

2. **Deploy Backend** (sync happens automatically on startup)
   ```bash
   ./infrastructure/deploy-all.sh
   ```

3. **Verify Sync** (check backend logs)
   ```bash
   gcloud run services logs read backend --region=us-west1 --limit=50
   ```

4. **Access UI** - Corpora appear automatically!

### Existing Environment Update

1. **Pull Latest Code**
   ```bash
   git pull origin vertex-sync
   ```

2. **Redeploy Backend**
   ```bash
   ./infrastructure/deploy-all.sh
   ```

3. **Sync Runs Automatically** on startup

---

## Troubleshooting

### Corpora Not Appearing in UI

**Check 1: Backend Logs**
```bash
gcloud run services logs read backend --region=us-west1 --limit=100 | grep -i "corpus sync"
```

**Check 2: Database State**
```sql
SELECT id, name, display_name, is_active, vertex_corpus_id 
FROM corpora 
ORDER BY created_at DESC;
```

**Check 3: Manual Sync**
```bash
cd backend
python sync_corpora_from_vertex.py
```

### Sync Fails with "Failed to initialize Vertex AI"

**Cause:** Missing or invalid GCP credentials

**Solution:**
```bash
# Authenticate locally
gcloud auth application-default login

# For Cloud Run, verify service account has Vertex AI permissions
gcloud projects get-iam-policy adk-rag-ma \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:*@*.iam.gserviceaccount.com"
```

### Sync Adds Duplicate Corpora

**Cause:** Corpus name mismatch between Vertex AI `display_name` and DB `name`

**Solution:** The service matches on `display_name` (Vertex AI) = `name` (DB). Ensure consistency.

### GCS Bucket Shows Wrong Value

**Cause:** Corpus has no files yet, fallback naming used

**Solution:** 
1. Upload files to corpus in Vertex AI
2. Run manual sync to update bucket path
3. Or manually update: `UPDATE corpora SET gcs_bucket='gs://correct-bucket' WHERE id=X;`

---

## Testing

### Unit Test

```bash
cd backend
python test_corpus_sync.py
```

### Integration Test

1. **Create a test corpus in Vertex AI**
   ```bash
   # Use Vertex AI console or gcloud
   ```

2. **Run sync**
   ```bash
   python sync_corpora_from_vertex.py
   ```

3. **Verify in database**
   ```sql
   SELECT * FROM corpora WHERE name='test-corpus';
   ```

4. **Check UI** - New corpus should appear

5. **Delete corpus from Vertex AI**

6. **Run sync again**
   ```bash
   python sync_corpora_from_vertex.py
   ```

7. **Verify deactivation**
   ```sql
   SELECT * FROM corpora WHERE name='test-corpus';
   -- is_active should be FALSE
   ```

---

## Future Enhancements

### Phase 2 (Optional)

- [ ] **Scheduled Background Sync** - Periodic sync every N minutes
- [ ] **Webhook Integration** - Sync on Vertex AI corpus events
- [ ] **Sync Metrics** - Track sync performance and failures
- [ ] **Corpus Metadata Sync** - Sync descriptions, tags from Vertex AI
- [ ] **File Count Caching** - Cache document counts to reduce API calls

### Phase 3 (Optional)

- [ ] **Multi-Region Support** - Sync corpora from multiple regions
- [ ] **Conflict Resolution** - Handle manual DB changes vs Vertex AI state
- [ ] **Rollback Support** - Undo sync operations
- [ ] **Sync Notifications** - Alert admins of sync failures

---

## Related Documentation

- `VERTEX_AI_SYNC_ANALYSIS.md` - Detailed analysis and design decisions
- `backend/src/services/corpus_sync_service.py` - Service implementation
- `backend/sync_corpora_from_vertex.py` - Standalone script
- `DEPLOYMENT_STATE.md` - Current deployment configuration

---

## Support

For issues or questions:
1. Check backend logs for sync errors
2. Run manual sync script for detailed output
3. Verify Vertex AI credentials and permissions
4. Check database state for corpus entries

**Last Sync Status:** Check `/api/admin/corpora` endpoint for `last_synced` timestamps
