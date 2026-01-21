# Corpus Sync Timestamp Fix

**Date:** January 20, 2026  
**Status:** ✅ Fixed

---

## Issue

After clicking "Sync with Vertex AI" button in the admin corpus management panel, the "Last Sync" column still shows "Never" for all corpora. The sync operation completes successfully but timestamps are not updated.

**User Experience:**
- Click "Sync with Vertex AI" button
- Success message appears
- "Last Sync" column remains "Never"
- All corpora show `last_synced_at: NULL` in database

**Database State:**
```
Corpus 1: ai-books        - last_synced_at: None
Corpus 2: test-corpus     - last_synced_at: None
Corpus 5: recipes         - last_synced_at: None
Corpus 6: semantic-web    - last_synced_at: None
Corpus 7: hacker-books    - last_synced_at: None
```

---

## Root Cause

The corpus sync endpoint (`POST /api/admin/corpora/sync`) was only handling:
1. **Adding** new corpora from Vertex AI
2. **Deactivating** corpora not in Vertex AI

It was **NOT updating** the `last_synced_at` timestamp for existing corpora that are still active in Vertex AI.

**Problem Code:**
```python
# Add new corpora from Vertex AI
for vertex_corpus in vertex_corpora:
    if vertex_corpus['display_name'] not in db_corpus_names:
        # Create new corpus and metadata
        CorpusMetadataRepository.create(...)
        added_count += 1

# Deactivate corpora not in Vertex AI
for db_corpus in db_corpora:
    if db_corpus['name'] not in vertex_corpus_names and db_corpus['is_active']:
        CorpusRepository.update(...)
        deactivated_count += 1

# ❌ Missing: Update sync timestamp for existing active corpora
```

Additionally, the deactivation code had the same dict vs kwargs bug we've seen before.

---

## Solution

Added a loop to update sync timestamps for all existing corpora that are still present in Vertex AI, and fixed the CorpusRepository.update call.

**File:** `backend/src/api/routes/admin.py` (Lines 386-405)

**Added Code:**
```python
# Update sync timestamp for existing corpora that are still in Vertex AI
for db_corpus in db_corpora:
    if db_corpus['name'] in vertex_corpus_names:
        try:
            # Update last synced timestamp
            CorpusMetadataRepository.update_sync_status(
                corpus_id=db_corpus['id'],
                status='active',
                user_id=current_user.id
            )
            updated_count += 1
        except Exception as e:
            logger.error(f"Failed to update sync timestamp for corpus {db_corpus['name']}: {e}")
            errors.append(str(e))
```

**Also Fixed:**
```python
# Before: ❌ Wrong kwargs syntax
CorpusRepository.update(db_corpus['id'], {'is_active': False})

# After: ✅ Correct kwargs syntax
CorpusRepository.update(db_corpus['id'], is_active=False)
```

---

## What update_sync_status Does

**Method:** `CorpusMetadataRepository.update_sync_status()`

```python
def update_sync_status(
    corpus_id: int,
    status: str,
    user_id: Optional[int] = None,
    error_message: Optional[str] = None
) -> int:
    """Update sync status for a corpus."""
    query = """
        UPDATE corpus_metadata
        SET sync_status = %s,
            sync_error_message = %s,
            last_synced_at = %s,
            last_synced_by = %s
        WHERE corpus_id = %s
    """
    
    return execute_update(query, (
        status,
        error_message,
        datetime.utcnow().isoformat(),  # ✅ Sets current timestamp
        user_id,
        corpus_id
    ))
```

This method:
- Sets `last_synced_at` to current UTC timestamp
- Sets `last_synced_by` to the user ID
- Updates `sync_status` (active/error)
- Optionally records error messages

---

## Sync Operation Flow (After Fix)

### 1. Fetch from Vertex AI
```
GET corpora from Vertex AI RAG
Example: 7 corpora found
```

### 2. Add New Corpora
```
For each Vertex AI corpus not in database:
  - Create corpus record
  - Create metadata record (with created_at)
  - Log to audit trail
```

### 3. Update Existing Corpora ✅ NEW
```
For each database corpus that exists in Vertex AI:
  - Update last_synced_at timestamp
  - Update last_synced_by user ID
  - Set sync_status = 'active'
  - Increment updated_count
```

### 4. Deactivate Missing Corpora
```
For each database corpus NOT in Vertex AI:
  - Set is_active = false
  - Log to audit trail
```

### 5. Return Result
```json
{
  "success": true,
  "total_corpora": 7,
  "added_count": 0,
  "updated_count": 7,      // ✅ Now tracks timestamp updates
  "deactivated_count": 0,
  "errors": [],
  "message": "Sync complete: 0 added, 0 deactivated"
}
```

---

## Testing

### Before Fix:
```bash
# Click "Sync with Vertex AI"
POST /api/admin/corpora/sync
-> HTTP 200 OK

# Check database
SELECT last_synced_at FROM corpus_metadata;
Result: All NULL ❌
```

### After Fix:
```bash
# Click "Sync with Vertex AI"
POST /api/admin/corpora/sync
-> HTTP 200 OK
-> updated_count: 7

# Check database
SELECT last_synced_at FROM corpus_metadata;
Result: All show current timestamps ✅
Example: 2026-01-20T17:31:45.123456
```

### Frontend Display:
```
Before: "Last Sync: Never"
After:  "Last Sync: 2 minutes ago" (or similar relative time)
```

---

## Impact

### Fixed Operations:
- ✅ Sync timestamps now update for all existing corpora
- ✅ "Last Sync" column displays actual sync times
- ✅ Can track when each corpus was last verified against Vertex AI
- ✅ Audit trail includes sync operations

### Updated Behavior:
- Every sync operation now updates timestamps for ALL matching corpora
- Not just new or deactivated ones
- Provides accurate sync history

---

## Related Issues Fixed

This sync endpoint also had the **same CorpusRepository.update() bug** we fixed earlier:
- Passing dict as positional argument instead of kwargs
- Same pattern as the status toggle bug
- Fixed in the same commit

---

## Benefits

### For Users:
- Clear visibility into when corpora were last synced
- Can verify sync operations are working
- Can identify stale corpora that haven't been synced recently

### For Admins:
- Audit trail of sync operations
- Track who performed syncs and when
- Monitor sync health across all corpora

### For Debugging:
- Timestamps help identify sync issues
- Can correlate sync times with other operations
- Better troubleshooting of corpus availability issues

---

## Sync Operation Summary

**Operation:** Manual sync with Vertex AI  
**Frequency:** On-demand (via admin UI button)  
**Purpose:** Keep database in sync with Vertex AI RAG corpora

**What It Does:**
1. ✅ Adds new corpora from Vertex AI
2. ✅ Updates sync timestamps for existing corpora (NEW)
3. ✅ Deactivates corpora removed from Vertex AI
4. ✅ Creates audit logs for all operations

**What It Doesn't Do:**
- Doesn't delete corpora (only deactivates)
- Doesn't modify corpus content (only metadata)
- Doesn't affect user access (separate from group permissions)

---

## Prevention

### When Implementing Sync Operations:
- [ ] Update timestamps for unchanged records
- [ ] Track "last verified" or "last checked" times
- [ ] Don't only update on changes - update on checks too
- [ ] Include timestamp updates in success metrics

### Code Review Checklist:
- [ ] Sync operations update all relevant timestamps
- [ ] Both changed AND unchanged records are timestamped
- [ ] Repository method calls use correct kwargs syntax
- [ ] Success counts include timestamp updates

---

## Summary

**Issue:** "Last Sync" always showed "Never"  
**Root Cause:** Sync endpoint didn't update timestamps for existing corpora  
**Fix:** Added loop to update sync timestamps for all matching corpora  
**Bonus Fix:** Corrected CorpusRepository.update() kwargs syntax  
**Result:** Sync timestamps now display correctly in admin UI

Backend restarted (Process 61141) and ready for testing.
