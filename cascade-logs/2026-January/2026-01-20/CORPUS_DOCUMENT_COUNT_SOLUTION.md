# Corpus Document Count Solution

**Date:** January 20, 2026  
**Status:** ✅ Implemented

---

## Issue

In the admin corpus management panel (`/admin/corpora`), the "Documents" column shows 0 for all corpora, even though documents exist in Vertex AI.

**User Experience:**
- All corpora show "Documents: 0"
- This is incorrect - corpora have documents in Vertex AI
- No way to see actual document counts

**Database State:**
```sql
SELECT corpus_id, corpus_name, document_count 
FROM corpus_metadata;

Result: All document_count = 0
```

---

## Root Cause

The `corpus_metadata.document_count` field was never being populated. While there was existing code to fetch document counts from Vertex AI (`CorpusService._get_document_count()`), it was only used in specific API endpoints, not in the admin panel or sync operations.

**Why Count is 0:**
1. When corpus metadata is created, `document_count` defaults to 0
2. When sync runs, it only updated timestamps, not document counts
3. No automatic mechanism to keep counts up-to-date

---

## Solution Overview

Enhanced the corpus sync operation to fetch and update document counts from Vertex AI in real-time.

**How It Works:**
1. User clicks "Sync with Vertex AI" button
2. For each corpus that exists in both DB and Vertex AI:
   - Fetch list of files from Vertex AI using `rag.list_files(corpus_resource_name)`
   - Count the number of files
   - Update `corpus_metadata.document_count` with actual count
   - Update `last_document_count_update` timestamp
3. Display updated counts in admin UI

---

## Implementation

**File:** `backend/src/api/routes/admin.py` (Lines 386-426)

### Enhanced Sync Logic

```python
# Update sync timestamp and document count for existing corpora that are still in Vertex AI
for db_corpus in db_corpora:
    if db_corpus['name'] in vertex_corpus_names:
        try:
            # Get vertex_corpus_id for this corpus
            vertex_corpus = next(
                (vc for vc in vertex_corpora if vc['display_name'] == db_corpus['name']),
                None
            )
            vertex_corpus_id = vertex_corpus['resource_name'] if vertex_corpus else None
            
            # Fetch document count from Vertex AI
            try:
                if vertex_corpus_id:
                    from vertexai import rag
                    files = list(rag.list_files(vertex_corpus_id))
                    doc_count = len(files)
                else:
                    doc_count = 0
            except Exception as doc_err:
                logger.warning(f"Failed to fetch document count for {db_corpus['name']}: {doc_err}")
                doc_count = None  # Don't update if fetch fails
            
            # Update last synced timestamp
            CorpusMetadataRepository.update_sync_status(
                corpus_id=db_corpus['id'],
                status='active',
                user_id=current_user.id
            )
            
            # Update document count if we successfully fetched it
            if doc_count is not None:
                CorpusMetadataRepository.update_document_count(
                    corpus_id=db_corpus['id'],
                    count=doc_count
                )
            
            updated_count += 1
        except Exception as e:
            logger.error(f"Failed to update sync data for corpus {db_corpus['name']}: {e}")
            errors.append(str(e))
```

---

## How Document Counts Are Fetched

### From Vertex AI RAG

**Method:** `rag.list_files(corpus_resource_name)`

```python
from vertexai import rag

# List all files in a corpus
files = list(rag.list_files(
    "projects/adk-rag-ma/locations/us-west1/ragCorpora/1234567890"
))

# Count them
document_count = len(files)
```

**What This Counts:**
- PDFs uploaded to the corpus
- Text files in the corpus
- Any document indexed by Vertex AI RAG
- Individual files (not chunks)

**Performance:**
- Fast for small corpora (<100 docs)
- May take a few seconds for large corpora (>1000 docs)
- Only runs during manual sync (not on every page load)

---

## Database Updates

### corpus_metadata Table

**Fields Updated:**
```sql
UPDATE corpus_metadata
SET document_count = <fetched_count>,
    last_document_count_update = NOW()
WHERE corpus_id = <corpus_id>;
```

**Repository Method:**
```python
CorpusMetadataRepository.update_document_count(
    corpus_id=1,
    count=42
)
```

This method (already existed):
- Updates `document_count` field
- Sets `last_document_count_update` to current timestamp
- Tracks when count was last refreshed

---

## Usage Instructions

### For Admins

**To Update Document Counts:**

1. Navigate to `/admin/corpora`
2. Click **"Sync with Vertex AI"** button
3. Wait for sync to complete (progress indicator shows)
4. Document counts will refresh automatically

**What Gets Updated:**
- ✅ Last Sync timestamps
- ✅ Document counts
- ✅ Active/inactive status
- ✅ New corpora from Vertex AI

**Frequency:**
- Manual sync whenever needed
- Recommended: After uploading documents to Vertex AI
- Recommended: Daily or weekly for active environments

---

## Benefits

### Accurate Counts
- Real-time data from Vertex AI
- Counts actual files, not database records
- Source of truth is Vertex AI

### Minimal Performance Impact
- Only runs during manual sync
- Not on every page load
- Cached in database between syncs

### Graceful Failure
- If count fetch fails, timestamp still updates
- Error logged but sync continues
- Previous count preserved if new fetch fails

### Admin Visibility
- See document counts at a glance
- Identify empty or populated corpora
- Verify document uploads succeeded

---

## When Document Counts Update

### Automatic Updates:
- **Manual Sync:** Click "Sync with Vertex AI" button
- **Backend Sync:** If sync script runs on schedule (not yet implemented)

### Counts DO NOT Update:
- On page load (too slow)
- When viewing corpus details (use cached count)
- When querying documents (separate operation)

**To Get Fresh Counts:** Run sync operation

---

## Alternative Approaches Considered

### ❌ Update on Every Page Load
**Problem:** Too slow - would require Vertex AI API call on every admin page load

### ❌ Track Document Uploads in Database
**Problem:** Doesn't catch documents uploaded directly to Vertex AI (bypassing our app)

### ❌ Background Job to Update Counts
**Pros:** Automatic, always up-to-date  
**Cons:** Requires job scheduler, more complex  
**Status:** Could implement later if needed

### ✅ Update During Sync (Chosen Approach)
**Pros:** 
- Piggybacks on existing sync operation
- Minimal code changes
- Accurate when needed
- User-controlled timing

---

## Monitoring

### Check Last Update Time

```sql
SELECT 
    corpus_id,
    corpus_name,
    document_count,
    last_document_count_update,
    EXTRACT(EPOCH FROM (NOW() - last_document_count_update)) / 3600 AS hours_since_update
FROM corpus_metadata
ORDER BY last_document_count_update DESC;
```

### Identify Stale Counts

```sql
-- Corpora not updated in over 7 days
SELECT corpus_name, document_count, last_document_count_update
FROM corpus_metadata
WHERE last_document_count_update < NOW() - INTERVAL '7 days'
   OR last_document_count_update IS NULL;
```

---

## Future Enhancements

### Possible Improvements:

1. **Scheduled Background Sync**
   - Cron job to run sync daily
   - Keep counts automatically fresh
   - Requires deployment infrastructure

2. **Per-Corpus Refresh**
   - "Refresh" button next to each corpus
   - Update single corpus without full sync
   - Faster for targeted updates

3. **Document Count History**
   - Track count changes over time
   - Show growth/shrinkage trends
   - Useful for monitoring data ingestion

4. **Real-time Webhook**
   - Vertex AI notifies on document changes
   - Update count immediately
   - Requires webhook infrastructure

---

## Troubleshooting

### Document Count Still Shows 0

**Possible Causes:**

1. **Sync Not Run Yet**
   - Solution: Click "Sync with Vertex AI"

2. **Corpus Has No Documents**
   - Verify in Vertex AI Console
   - Upload documents if needed

3. **Vertex AI API Error**
   - Check backend logs for errors
   - Verify service account permissions
   - Check `list_files` permission

4. **Wrong Corpus Resource Name**
   - Verify `vertex_corpus_id` in database
   - May need to resync from Vertex AI

### Count Seems Wrong

1. **Check Vertex AI Directly**
   ```bash
   # Use gcloud to verify
   gcloud ai indexes list
   ```

2. **Re-run Sync**
   - Force fresh fetch from Vertex AI

3. **Check Logs**
   ```bash
   tail -f backend/backend.log | grep "document count"
   ```

---

## API Endpoints

### Trigger Sync (Updates Counts)

```bash
POST /api/admin/corpora/sync
Authorization: Bearer <admin_token>

Response:
{
  "success": true,
  "total_corpora": 7,
  "added_count": 0,
  "updated_count": 7,      // Includes document count updates
  "deactivated_count": 0,
  "errors": [],
  "message": "Sync complete: 0 added, 0 deactivated"
}
```

### Get Corpus Details (With Count)

```bash
GET /api/admin/corpora?include_inactive=false

Response:
[
  {
    "id": 1,
    "name": "ai-books",
    "display_name": "ai-books",
    "document_count": 42,    // From last sync
    "metadata": {
      "last_document_count_update": "2026-01-20T17:45:30.123456"
    },
    ...
  }
]
```

---

## Testing

### Manual Test

1. **Before Sync:**
   ```sql
   SELECT document_count FROM corpus_metadata WHERE corpus_id = 1;
   -- Result: 0
   ```

2. **Run Sync:**
   - Click "Sync with Vertex AI" in admin panel
   - OR: `POST /api/admin/corpora/sync`

3. **After Sync:**
   ```sql
   SELECT document_count, last_document_count_update 
   FROM corpus_metadata 
   WHERE corpus_id = 1;
   -- Result: Actual count, current timestamp
   ```

4. **Verify in UI:**
   - Refresh admin corpora page
   - Document counts should show actual numbers

---

## Summary

**Problem:** Document counts always showed 0  
**Solution:** Fetch counts from Vertex AI during sync operation  
**Method:** Use `rag.list_files()` to get actual file count  
**Trigger:** Manual "Sync with Vertex AI" button  
**Frequency:** On-demand (user-initiated)  
**Storage:** Cached in `corpus_metadata.document_count`  

**To Get Accurate Counts:**
1. Click "Sync with Vertex AI" in `/admin/corpora`
2. Wait for sync to complete
3. Counts will update automatically

**Backend Restarted:** Process 64668 on port 8000  
**Ready to test!**
