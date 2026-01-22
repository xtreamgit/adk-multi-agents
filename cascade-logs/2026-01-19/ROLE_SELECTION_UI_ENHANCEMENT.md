# Role Selection UI Enhancement

**Date:** January 19, 2026  
**Status:** ✅ Complete

---

## Enhancement Summary

Enhanced the "Manage Roles" dialog in the Groups admin page to display permissions for each role, making it clear what access is being granted when assigning roles to groups.

---

## Changes Made

**File:** `frontend/src/app/admin/groups/page.tsx`

### Before
Role selection dialog showed only:
- Role name
- Assign/Remove button

**Problem:** Admins couldn't see what permissions a role had without checking the Roles table first.

### After
Role selection dialog now shows:
- **Role name** (bold)
- **Permission count** (e.g., "7 permissions")
- **Permission badges** (first 3-4 permissions displayed)
- **"+X more" indicator** for roles with many permissions
- **Better visual hierarchy** with cards and borders

---

## UI Improvements

### 1. **Dialog Width**
- Changed from `max-w-2xl` to `max-w-4xl`
- Provides more space for permission badges

### 2. **Role Cards**
Each role is now displayed in a card with:
- Rounded border (`rounded-lg border border-gray-200`)
- Padding (`p-3`)
- Hover effect on available roles (`hover:border-blue-300`)

### 3. **Permission Display**

#### Current Roles (Left Column):
- Shows up to **3 permissions** as purple badges
- **"+X more"** badge if role has more than 3 permissions
- Purple color scheme (`bg-purple-100 text-purple-800`)

#### Available Roles (Right Column):
- Shows up to **4 permissions** as blue badges
- **"+X more"** badge if role has more than 4 permissions
- Blue color scheme (`bg-blue-100 text-blue-800`)
- Scrollable if many roles (`max-h-96 overflow-y-auto`)

### 4. **Permission Count**
Added small gray text showing total permissions:
```
user-manager
7 permissions
```

### 5. **Enhanced Assign Button**
- Changed from plain text link to button-style
- Added border (`border border-blue-600`)
- Hover effect (`hover:bg-blue-50`)

---

## Example Display

### Available Roles Column:
```
┌─────────────────────────────────────────────┐
│ user-manager                      [ Assign ]│
│ 7 permissions                               │
│                                             │
│ [read:users] [create:user] [update:user]   │
│ [delete:user] +3 more                       │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ corpus-viewer                     [ Assign ]│
│ 3 permissions                               │
│                                             │
│ [read:corpora] [read:documents]             │
│ [query:corpora]                             │
└─────────────────────────────────────────────┘
```

### Current Roles Column:
```
┌─────────────────────────────────────────────┐
│ admin-role                        [ Remove ]│
│ 1 permission                                │
│                                             │
│ [admin:all]                                 │
└─────────────────────────────────────────────┘
```

---

## Benefits

### 1. **Informed Decision Making**
Admins can see exactly what permissions they're granting without leaving the dialog.

### 2. **Reduced Errors**
Less chance of assigning the wrong role because permissions are visible upfront.

### 3. **Better UX**
- Clear visual hierarchy
- Permission badges use consistent styling from Roles table
- Color-coded (blue for available, purple for assigned)

### 4. **Scalability**
- Handles roles with many permissions gracefully ("+X more" indicator)
- Scrollable available roles list if there are many roles

---

## Technical Details

### Permission Badge Styling
```tsx
<span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
  {perm}
</span>
```

### Truncation Logic
```tsx
// Show first 4 permissions
{role.permissions.slice(0, 4).map((perm, idx) => (
  <span key={idx}>...</span>
))}

// Show "+X more" if total > 4
{role.permissions.length > 4 && (
  <span>+{role.permissions.length - 4} more</span>
)}
```

### Responsive Grid
```tsx
<div className="grid grid-cols-2 gap-6">
  {/* Current Roles */}
  <div>...</div>
  
  {/* Available Roles */}
  <div>...</div>
</div>
```

---

## Future Enhancements

### Expandable Permissions
Add a "Show all" option to expand and see all permissions for roles with many permissions.

### Tooltips
Hover over "+X more" to show all remaining permissions in a tooltip.

### Permission Filtering
Add a search/filter box to find roles by specific permissions.

### Role Description
Add role descriptions below the permission count (currently only in Roles table).

---

## Testing Checklist

- [x] Permissions display correctly for all roles
- [x] Permission count is accurate
- [x] "+X more" indicator calculates correctly
- [x] Assign button works
- [x] Remove button works
- [x] Dialog is properly sized (max-w-4xl)
- [x] Available roles are scrollable if many
- [ ] Test with screen reader (accessibility)
- [ ] Test on mobile (responsive design)

---

## Related Files

- **Frontend:** `frontend/src/app/admin/groups/page.tsx`
- **API:** `backend/src/api/routes/groups.py` (no changes needed)
- **Types:** Role interface includes `permissions: string[]`

---

## Summary

Enhanced the role selection dialog to display permissions, making it easier for admins to understand what access they're granting when assigning roles to groups. The UI now shows permission badges with smart truncation for roles with many permissions.

**Impact:** Better informed admin decisions, reduced errors, improved UX
