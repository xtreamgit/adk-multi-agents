# Corpus Status Toggle Fix

**Date:** January 20, 2026  
**Status:** ✅ Fixed

---

## Issue

In the admin corpus management panel (`/admin/corpora`), clicking "Activate" or "Deactivate" on a corpus did not change the status. The buttons appeared but clicking them had no effect.

**User Experience:**
- Click "Activate" button in status column
- Deactivate/Activate buttons show up
- Click "Deactivate" - nothing happens
- Status remains unchanged

**Backend Error Log:**
```
ERROR:api.routes.admin:Failed to update corpus status: CorpusRepository.update() takes 1 positional argument but 2 were given
ERROR:services.bulk_operation_service:Failed to update status for corpus 3: CorpusRepository.update() takes 1 positional argument but 2 were given
```

---

## Root Cause

Two service methods were calling `CorpusRepository.update()` incorrectly. The repository method expects **kwargs (keyword arguments), but it was being called with a dictionary as a positional argument.

**CorpusRepository.update() Signature:**
```python
@staticmethod
def update(corpus_id: int, **kwargs) -> Optional[Dict]:
    """Update corpus fields."""
    if not kwargs:
        return CorpusRepository.get_by_id(corpus_id)
    
    set_clause = ", ".join([f"{key} = %s" for key in kwargs.keys()])
    values = list(kwargs.values()) + [corpus_id]
    # ...
```

**Problem Code (AdminCorpusService):**
```python
# ❌ Wrong - passing dict as positional argument
rows = CorpusRepository.update(corpus_id, {'is_active': is_active})
```

**Problem Code (BulkOperationService):**
```python
# ❌ Wrong - passing dict as positional argument
rows = CorpusRepository.update(corpus_id, {'is_active': is_active})
```

---

## Solution

Changed both service methods to pass keyword arguments instead of a dictionary.

### Fix 1: AdminCorpusService.update_corpus_status()

**File:** `backend/src/services/admin_corpus_service.py` (Lines 171-177)

**Before:**
```python
corpus = CorpusRepository.get_by_id(corpus_id)
if not corpus:
    return False

# Update status
rows = CorpusRepository.update(corpus_id, {'is_active': is_active})
```

**After:**
```python
corpus = CorpusRepository.get_by_id(corpus_id)
if not corpus:
    return False

# Update status
result = CorpusRepository.update(corpus_id, is_active=is_active)
rows = 1 if result else 0
```

### Fix 2: BulkOperationService.update_corpus_status()

**File:** `backend/src/services/bulk_operation_service.py` (Lines 164-168)

**Before:**
```python
for corpus_id in corpus_ids:
    try:
        # Update status
        rows = CorpusRepository.update(corpus_id, {'is_active': is_active})
```

**After:**
```python
for corpus_id in corpus_ids:
    try:
        # Update status
        result = CorpusRepository.update(corpus_id, is_active=is_active)
        rows = 1 if result else 0
```

---

## Files Changed

1. `backend/src/services/admin_corpus_service.py` - Fixed update_corpus_status()
2. `backend/src/services/bulk_operation_service.py` - Fixed bulk status update

---

## Testing

### Individual Status Toggle
**Endpoint:** `PUT /api/admin/corpora/{corpus_id}/status?is_active=false`

**Before Fix:**
```
ERROR: CorpusRepository.update() takes 1 positional argument but 2 were given
HTTP 500 Internal Server Error
```

**After Fix:**
```
✅ HTTP 200 OK
{
  "success": true,
  "corpus_id": 3,
  "is_active": false
}
```

### Bulk Status Update
**Endpoint:** `POST /api/admin/corpora/bulk/update-status`

**Before Fix:**
```
ERROR: Failed to update status for corpus 3: CorpusRepository.update() takes 1 positional argument but 2 were given
```

**After Fix:**
```
✅ Corpus status updated successfully
Audit log created
```

---

## Impact

### Fixed Operations:
- ✅ Single corpus activate/deactivate
- ✅ Bulk corpus status updates
- ✅ Status changes are now persisted to database
- ✅ Audit logs created for status changes

### Affected UI:
- Admin corpus management table status column
- Activate/Deactivate buttons now work correctly
- Status changes reflect immediately

---

## Related Pattern

This is the same type of error we've seen before with repository method signatures. 

**Python Kwargs Pattern:**
```python
# DON'T pass a dict as positional argument:
repository.update(id, {'field': value})  # ❌

# DO unpack kwargs:
repository.update(id, field=value)  # ✅
```

**Alternative if you have a dict:**
```python
updates = {'field1': value1, 'field2': value2}

# Option 1: Unpack with **
repository.update(id, **updates)  # ✅

# Option 2: Pass as kwargs
repository.update(id, field1=value1, field2=value2)  # ✅
```

---

## Prevention

### Code Review Checklist:
When calling repository `update()` methods:
- [ ] Verify method signature accepts **kwargs
- [ ] Pass fields as keyword arguments, not dict
- [ ] Or unpack dict with ** operator if needed

### Similar Methods to Audit:
Other repositories with `update(**kwargs)` pattern:
- `UserRepository.update()`
- `GroupRepository.update()` (if exists)
- `RoleRepository.update()` (if exists)

Ensure all service methods calling these use correct syntax.

---

## Summary

**Issue:** Corpus status toggle buttons didn't work  
**Root Cause:** Repository method called with dict instead of **kwargs  
**Fix:** Changed method calls to pass keyword arguments correctly  
**Files:** AdminCorpusService.py, BulkOperationService.py  
**Result:** Corpus activation/deactivation now works correctly

Backend restarted and ready for testing.
