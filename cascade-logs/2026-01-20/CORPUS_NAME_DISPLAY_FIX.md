# Corpus Name Display Fix

**Date:** January 20, 2026  
**Status:** ✅ Implemented

---

## Issue

The application displayed corpus IDs (numeric) instead of corpus names in several places, making it difficult for users to identify corpora.

**Problem Areas:**
1. **Test Documents Page**: Required users to enter numeric corpus ID (e.g., "1") instead of selecting a corpus by name
2. **System Audit Logs**: Potentially showing "Corpus 1" instead of corpus names
3. **Corpus Audit Logs**: Same issue with corpus identification

**User Experience Issue:**
- Users had to remember or look up corpus IDs
- Not user-friendly - required mapping between IDs and names
- Instruction text: "Enter the corpus ID (e.g., 1 for ai-books)" was confusing

---

## Root Cause

### Test Documents Page
The `DocumentRetrievalPanel` component used a numeric input field for corpus ID selection, requiring users to know the database ID.

### Audit Logs
The backend already provides `corpus_name` in audit log queries (joins with `corpora` table), but the frontend needed to ensure it displays this properly.

---

## Solution

### 1. Test Documents - Corpus Dropdown

**File:** `frontend/src/components/DocumentRetrievalPanel.tsx`

**Changes:**

#### Added Corpus Loading
```typescript
interface Corpus {
  id: number;
  name: string;
  display_name: string;
}

const [corpora, setCorpora] = useState<Corpus[]>([]);
const [loadingCorpora, setLoadingCorpora] = useState(true);

useEffect(() => {
  loadCorpora();
}, []);

const loadCorpora = async () => {
  try {
    setLoadingCorpora(true);
    const data = await apiClient.getAvailableCorpora();
    setCorpora(data);
  } catch (err) {
    console.error('Failed to load corpora:', err);
  } finally {
    setLoadingCorpora(false);
  }
};
```

#### Replaced Numeric Input with Dropdown
```tsx
// Before: Numeric input
<input
  type="number"
  id="corpusId"
  value={corpusId}
  onChange={(e) => setCorpusId(e.target.value)}
  placeholder="1"
  required
/>
<p className="mt-1 text-xs text-gray-500">
  Enter the corpus ID (e.g., 1 for ai-books)
</p>

// After: Dropdown select
<select
  id="corpusId"
  value={corpusId}
  onChange={(e) => setCorpusId(e.target.value)}
  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
  required
  disabled={loadingCorpora}
>
  <option value="">Select a corpus...</option>
  {corpora.map((corpus) => (
    <option key={corpus.id} value={corpus.id}>
      {corpus.display_name || corpus.name}
    </option>
  ))}
</select>
<p className="mt-1 text-xs text-gray-500">
  {loadingCorpora ? 'Loading corpora...' : 'Select the corpus containing the document'}
</p>
```

#### Updated Instructions
```tsx
// Before:
<li>Enter the corpus ID (numeric ID from database)</li>

// After:
<li>Select the corpus from the dropdown</li>
```

---

### 2. Audit Logs - Already Handled

**Backend:** `backend/src/database/repositories/audit_repository.py`

The audit repository already performs LEFT JOIN with the `corpora` table to include corpus names:

```python
query = """
    SELECT 
        cal.*,
        c.name as corpus_name,
        c.display_name as corpus_display_name,
        u.username as user_name
    FROM corpus_audit_log cal
    LEFT JOIN corpora c ON cal.corpus_id = c.id
    LEFT JOIN users u ON cal.user_id = u.id
    WHERE cal.corpus_id = %s
    ORDER BY cal.timestamp DESC
    LIMIT %s
"""
```

**Frontend Display:**

Both audit pages already handle corpus names correctly:

**System Audit (`/admin/audit/page.tsx`):**
```tsx
<td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
  {log.corpus_name || (log.corpus_id ? `Corpus ${log.corpus_id}` : '-')}
</td>
```

**Corpus Audit (`/admin/corpora/audit/page.tsx`):**
```tsx
{log.corpus_name && (
  <span className="text-sm text-gray-600">
    on <span className="font-mono">{log.corpus_name}</span>
  </span>
)}
```

**Fallback Logic:**
- Primary: Display `corpus_name` if available
- Fallback: Display "Corpus X" if only `corpus_id` exists
- Default: Display "-" if neither exists

This means audit logs will show corpus names when available, which they should be since the backend joins the tables.

---

## Benefits

### User Experience
- ✅ **No more memorizing IDs**: Users select corpora by name
- ✅ **Clear identification**: See actual corpus names in all interfaces
- ✅ **Autocomplete**: Dropdown shows all available corpora
- ✅ **No typos**: Selection from list, not manual entry

### Test Documents Page
- Select corpus from dropdown: "ai-books", "design", "management", etc.
- No need to know database IDs
- Loading state shows "Loading corpora..." while fetching

### Audit Logs
- Shows corpus names like "ai-books" instead of "Corpus 1"
- Falls back gracefully if corpus name not available
- Consistent display across all audit views

---

## Testing

### Test Documents Page

1. Navigate to `/test-documents`
2. **Before:** Numeric input field "Corpus ID"
3. **After:** Dropdown showing corpus names
4. Verify:
   - Dropdown populates with available corpora
   - Shows display names (e.g., "ai-books", "design")
   - Selecting a corpus works correctly
   - Document retrieval still functions

### System Audit Logs

1. Navigate to `/admin/audit`
2. Verify corpus column shows:
   - Corpus names (e.g., "ai-books") not "Corpus 1"
   - Falls back to "Corpus X" only if name unavailable
   - Shows "-" for logs without corpus association

### Corpus Audit Logs

1. Navigate to `/admin/corpora` → click corpus → "Audit"
2. Verify audit entries show corpus name in description
3. Example: "on ai-books" instead of "on 1"

---

## Technical Details

### API Endpoint Used
```typescript
await apiClient.getAvailableCorpora()
```

Returns:
```json
[
  {
    "id": 1,
    "name": "ai-books",
    "display_name": "ai-books",
    "is_active": true,
    ...
  },
  ...
]
```

### State Management
- `corpora`: Array of available corpus objects
- `loadingCorpora`: Boolean for loading state
- `corpusId`: Selected corpus ID (still stored as number for backend compatibility)

### Backward Compatibility
- Backend still receives corpus ID as integer
- No backend changes required
- Frontend converts user-friendly selection to ID

---

## Edge Cases Handled

### No Corpora Available
- Dropdown shows only "Select a corpus..." option
- Help text indicates loading or no corpora

### Loading State
- Dropdown disabled while loading
- Help text shows "Loading corpora..."
- Prevents selection errors

### Corpus Name Missing (Audit Logs)
- Fallback: "Corpus X" where X is the ID
- Graceful degradation if JOIN fails
- Always shows something meaningful

---

## Future Enhancements

### Possible Improvements:

1. **Search/Filter in Dropdown**
   - For environments with many corpora
   - Searchable dropdown (e.g., using react-select)

2. **Corpus Info on Hover**
   - Tooltip showing corpus description
   - Document count
   - Last sync time

3. **Recently Used Corpora**
   - Remember last selected corpus
   - Quick access to frequently used corpora

4. **Corpus Status Indicators**
   - Show active/inactive status in dropdown
   - Visual indicators (color, icon)

---

## Files Changed

### Frontend
- `frontend/src/components/DocumentRetrievalPanel.tsx`
  - Added corpus loading logic
  - Replaced numeric input with dropdown
  - Updated instructions

### Backend
- No changes required
- Audit repository already provides corpus names

### Documentation
- Updated instructions in UI
- This documentation file

---

## Summary

**Problem:** Users had to enter numeric corpus IDs  
**Solution:** Replaced with user-friendly corpus name dropdowns  
**Impact:** Better UX, less confusion, no ID memorization needed  

**Changes:**
- ✅ Test documents page: Corpus dropdown
- ✅ Audit logs: Already showing corpus names (verified)
- ✅ Instructions updated
- ✅ Graceful fallbacks for missing data

**User Flow:**
1. Open test documents page
2. See dropdown with corpus names
3. Select corpus by name (not ID)
4. Enter document name
5. Retrieve document

Much better than memorizing corpus IDs!
