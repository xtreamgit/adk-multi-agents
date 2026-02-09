# Corpus Metadata Save Fix

**Date:** January 20, 2026  
**Status:** ✅ Fixed

---

## Issue

When editing corpus keywords and notes in the admin corpus management panel (`/admin/corpora`), saving the metadata failed with the error:

```
Failed to save metadata: Failed to update metadata: Internal Server Error
```

**Backend Error Log:**
```
ERROR:api.routes.admin:Failed to update metadata: Object of type datetime is not JSON serializable
```

---

## Root Cause

The `CorpusMetadataRepository.get_by_corpus_id()` method was returning datetime objects directly from PostgreSQL, which cannot be serialized to JSON when the API returns the response.

**Problem Code:**
```python
@staticmethod
def get_by_corpus_id(corpus_id: int) -> Optional[Dict[str, Any]]:
    query = """..."""
    results = execute_query(query, (corpus_id,))
    return results[0] if results else None  # ❌ datetime objects not converted
```

When the metadata was returned to the client, FastAPI tried to serialize it to JSON, causing:
```
TypeError: Object of type datetime is not JSON serializable
```

---

## Solution

Convert all datetime objects to ISO format strings before returning from the repository.

**Fixed Code:**
```python
@staticmethod
def get_by_corpus_id(corpus_id: int) -> Optional[Dict[str, Any]]:
    """
    Get metadata for a specific corpus.
    
    Returns:
        Metadata dictionary or None (with datetime objects converted to ISO strings)
    """
    query = """
        SELECT 
            cm.*,
            u1.username as created_by_name,
            u2.username as last_synced_by_name
        FROM corpus_metadata cm
        LEFT JOIN users u1 ON cm.created_by = u1.id
        LEFT JOIN users u2 ON cm.last_synced_by = u2.id
        WHERE cm.corpus_id = %s
    """
    
    results = execute_query(query, (corpus_id,))
    if not results:
        return None
    
    # Convert datetime objects to ISO strings for JSON serialization
    result = results[0]
    for key, value in result.items():
        if isinstance(value, datetime):
            result[key] = value.isoformat()
    
    return result
```

---

## Files Changed

**File:** `backend/src/database/repositories/corpus_metadata_repository.py`

**Methods Fixed:**
1. `get_by_corpus_id(corpus_id)` - Lines 50-81
2. `get_all_with_status(status)` - Lines 203-251

Both methods now convert datetime objects to ISO strings before returning.

---

## Testing

### Before Fix:
```python
>>> result = CorpusMetadataRepository.get_by_corpus_id(1)
>>> result['created_at']
datetime.datetime(2026, 1, 18, 23, 53, 30, 544567)

>>> json.dumps(result)
TypeError: Object of type datetime is not JSON serializable
```

### After Fix:
```python
>>> result = CorpusMetadataRepository.get_by_corpus_id(1)
>>> result['created_at']
'2026-01-18T23:53:30.544567'

>>> json.dumps(result)
'{"id": 1, "corpus_id": 1, "created_at": "2026-01-18T23:53:30.544567", ...}'
✅ SUCCESS
```

---

## Impact

### Fixed Operations:
- ✅ Save corpus keywords/tags
- ✅ Save corpus notes
- ✅ Update sync status
- ✅ All metadata update operations via `/api/admin/corpora/{id}/metadata`

### Affected Endpoints:
- `PUT /api/admin/corpora/{corpus_id}/metadata` - Now works correctly
- Any endpoint returning `CorpusMetadataRepository` data

---

## Related Context

### Why This Happened:
PostgreSQL returns datetime columns as Python `datetime` objects via psycopg2. When using JSONB for permissions, we learned psycopg2 auto-converts to Python types. The same applies to datetime/timestamp columns.

### Pattern for Future:
When returning data from repositories that will be serialized to JSON:
1. Convert `datetime` objects to `.isoformat()` strings
2. Convert other non-JSON-serializable types as needed
3. Do this conversion in the repository layer, not at API level

### Consistency Note:
Other repositories may have similar issues. Consider auditing:
- `UserRepository` - likely has datetime fields
- `AuditRepository` - has timestamp fields
- `SessionRepository` - has datetime fields

---

## Prevention

### Best Practice:
Add a utility function for converting repository results:

```python
def serialize_for_json(data: Dict[str, Any]) -> Dict[str, Any]:
    """Convert non-JSON-serializable types to JSON-safe types."""
    result = {}
    for key, value in data.items():
        if isinstance(value, datetime):
            result[key] = value.isoformat()
        elif isinstance(value, date):
            result[key] = value.isoformat()
        elif isinstance(value, Decimal):
            result[key] = float(value)
        else:
            result[key] = value
    return result
```

This could be applied consistently across all repositories.

---

## Summary

**Issue:** Datetime objects not JSON serializable  
**Root Cause:** PostgreSQL datetime columns returned as Python datetime objects  
**Fix:** Convert datetime to ISO strings in repository methods  
**Result:** Corpus metadata can now be saved successfully  
**Backend Restarted:** Process ID 55869 on port 8000

Corpus management admin panel is now fully functional for editing metadata.
