# Show Inactive Corpora by Default

**Date:** January 20, 2026  
**Status:** ✅ Implemented

---

## Issue

In the admin corpus management panel (`/admin/corpora`), the "Show inactive" checkbox is unchecked by default. This means inactive corpora are hidden when the page first loads.

**User Experience:**
- Admin must manually check "Show inactive" every time they visit the page
- Inactive corpora are hidden initially
- Extra click required to see all corpora

---

## Solution

Changed the default state of the `includeInactive` toggle to `true`.

**File:** `frontend/src/app/admin/corpora/page.tsx` (Line 33)

**Change:**
```typescript
// Before:
const [includeInactive, setIncludeInactive] = useState(false);

// After:
const [includeInactive, setIncludeInactive] = useState(true);
```

---

## Result

**New Behavior:**
- "Show inactive" checkbox is **checked by default**
- Both active and inactive corpora are visible when page loads
- Admin can still uncheck to hide inactive corpora if desired

**Why This Makes Sense:**
- Admins typically need to see all corpora (active and inactive)
- Easier to audit and manage all corpus records
- No data hidden by default
- One less click for most admin workflows

---

## Testing

1. Navigate to `/admin/corpora`
2. Verify "Show inactive" checkbox is checked on page load
3. Verify both active and inactive corpora are displayed
4. Uncheck "Show inactive" - only active corpora should show
5. Refresh page - checkbox should be checked again (default state)

---

## Summary

**Changed:** Default state of "Show inactive" toggle  
**From:** Unchecked (hide inactive)  
**To:** Checked (show all corpora)  
**Impact:** Better admin UX - all corpora visible by default  

No backend changes required - frontend-only update.
