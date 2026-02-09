# Implementation Plan: Corpus Selector Persistence & Visibility

**Date:** January 8, 2026  
**Status:** ✅ **COMPLETED** - All phases implemented and committed  
**Issue:** Corpus selector disappears after starting chat; user corpus preferences not persisted

---

## 🎯 **Objectives**

1. **Keep CorpusSelector visible** in sidebar during chat sessions
2. **Persist user's corpus selection** to backend database
3. **Auto-save** corpus selection changes to user profile
4. **Auto-load** saved corpus preferences on login
5. **Display selected corpora** in chat interface header (already works)

---

## 📋 **Current State Analysis**

### **Problem Identified**
- **Landing Page** (`page.tsx` lines 449+): CorpusSelector visible ✅
- **Chat Interface** (`page.tsx` lines 317-445): CorpusSelector missing ❌
- No backend persistence of corpus selection
- Selections lost on page refresh/logout

### **Existing Infrastructure**
- ✅ `selectedCorpora` state in `page.tsx` (line 26)
- ✅ `CorpusSelector` component functional
- ✅ `UserProfile` table exists in database
- ✅ User preferences API endpoints (`/api/users/me/preferences`)
- ✅ `preferences` JSON field in user_profiles table

---

## 🗄️ **Phase 1: Database Schema Enhancement**

### **Option A: Use Existing JSON Field (Recommended)**
Store in `user_profiles.preferences` JSON field:

```json
{
  "selected_corpora": ["ai-books", "design", "management"]
}
```

**Pros:**
- No migration needed
- Flexible for future preferences
- Already have API endpoints

**Cons:**
- Less structured than dedicated column

### **Option B: Add Dedicated Column**
Add new column to `user_profiles` table:

```sql
-- Migration: 00X_add_corpus_preferences.sql
ALTER TABLE user_profiles 
ADD COLUMN selected_corpora TEXT; -- JSON array of corpus names

-- Example value: '["ai-books", "design"]'
```

**Decision:** Use **Option A** (existing JSON field) for faster implementation.

---

## 🔧 **Phase 2: Backend API Updates**

### **2.1 Update User Service**
File: `backend/src/services/user_service.py`

Add methods:
```python
def save_corpus_selection(user_id: int, corpus_names: List[str]) -> UserProfile:
    """Save user's selected corpora to preferences."""
    
def get_corpus_selection(user_id: int) -> List[str]:
    """Get user's saved corpus selection."""
```

### **2.2 Create/Update API Endpoint**
File: `backend/src/api/routes/users.py`

**New Endpoint:**
```python
@router.put("/me/corpora", response_model=dict)
async def update_selected_corpora(
    corpus_names: List[str],
    current_user: User = Depends(get_current_user)
):
    """Update user's selected corpora preferences."""
```

**Or use existing endpoint:**
- `PUT /api/users/me/preferences` with payload:
  ```json
  {
    "preferences": {
      "selected_corpora": ["ai-books", "design"]
    }
  }
  ```

---

## 🎨 **Phase 3: Frontend Updates**

### **3.1 Fix Sidebar Visibility in Chat Mode**
File: `frontend/src/app/page.tsx`

**Location:** Lines 317-445 (Chat Interface layout)

**Change:**
Add CorpusSelector component to chat interface sidebar (similar to landing page sidebar).

**Before (Chat Mode - No Selector):**
```tsx
{/* Chat Interface */}
<div className="flex-1">
  {/* Sidebar */}
  <div className="w-64">
    {/* Only: New Chat, Search, List Docs, Chats, Profile, Logout */}
  </div>
</div>
```

**After (Chat Mode - With Selector):**
```tsx
{/* Chat Interface */}
<div className="flex-1">
  {/* Sidebar */}
  <div className="w-64">
    {/* New Chat, Search, List Docs */}
    
    {/* ADD: Corpus Selector */}
    <div className="p-4 border-t border-gray-200 flex-1 overflow-y-auto">
      <CorpusSelector 
        selectedCorpora={selectedCorpora}
        onCorporaChange={handleCorporaChange} {/* New handler */}
      />
    </div>
    
    {/* Chats, Profile, Logout */}
  </div>
</div>
```

### **3.2 Implement Auto-Save Handler**
File: `frontend/src/app/page.tsx`

```tsx
// Add handler to save to backend
const handleCorporaChange = async (newCorpora: string[]) => {
  setSelectedCorpora(newCorpora);
  
  // Auto-save to backend
  if (user && user.username !== 'guest') {
    try {
      await apiClient.updateUserPreferences({
        preferences: {
          selected_corpora: newCorpora
        }
      });
      console.log('Corpus selection saved to profile');
    } catch (error) {
      console.error('Failed to save corpus selection:', error);
    }
  }
};
```

### **3.3 Load Preferences on Login**
File: `frontend/src/app/page.tsx`

**Update `handleLoginSuccess` function:**

```tsx
const handleLoginSuccess = async (userData: any) => {
  setUser(userData);
  setShowLogin(false);
  
  // NEW: Load saved corpus preferences
  try {
    const profile = await apiClient.getUserProfile();
    if (profile.preferences?.selected_corpora) {
      setSelectedCorpora(profile.preferences.selected_corpora);
      console.log('Loaded saved corpus selection:', profile.preferences.selected_corpora);
    }
  } catch (error) {
    console.error('Failed to load corpus preferences:', error);
  }
  
  // Existing profile logic...
};
```

### **3.4 Update API Client**
File: `frontend/src/lib/api-client.ts` (or `api-enhanced.ts`)

Add/verify methods:
```typescript
async getUserProfile(): Promise<UserProfile> {
  // GET /api/users/me
}

async updateUserPreferences(preferences: any): Promise<UserProfile> {
  // PUT /api/users/me/preferences
}
```

---

## 📝 **Phase 4: Implementation Steps**

### **Step 1: Backend - User Service** (15 min)
- [ ] Update `user_service.py` with corpus preference methods
- [ ] Test saving/loading from preferences JSON field

### **Step 2: Backend - API Endpoint** (10 min)
- [ ] Verify `/api/users/me/preferences` endpoint works
- [ ] Test with Postman/curl
- [ ] Add logging for debugging

### **Step 3: Frontend - API Client** (10 min)
- [ ] Add/verify `getUserProfile()` method
- [ ] Add/verify `updateUserPreferences()` method
- [ ] Test API calls in browser console

### **Step 4: Frontend - Sidebar Fix** (30 min)
- [ ] Add CorpusSelector to chat interface sidebar (lines 320-422)
- [ ] Create `handleCorporaChange` with auto-save logic
- [ ] Replace `setSelectedCorpora` with `handleCorporaChange` in both sidebars
- [ ] Test selector visibility in both landing and chat modes

### **Step 5: Frontend - Login Loading** (15 min)
- [ ] Update `handleLoginSuccess` to load preferences
- [ ] Update `useEffect` (initial auth) to load preferences
- [ ] Test login → corpus selection restore flow

### **Step 6: Testing** (20 min)
- [ ] Test: Select corpora → verify auto-save to backend
- [ ] Test: Logout → Login → verify corpora restored
- [ ] Test: Refresh page → verify corpora maintained (via session)
- [ ] Test: Guest user → no save errors
- [ ] Test: Multi-corpus selection persistence

---

## 🧪 **Testing Checklist**

### **Manual Tests**
- [ ] Selector visible on landing page ✅ (already works)
- [ ] Selector visible during chat session ❌ (needs fix)
- [ ] Selecting corpus triggers auto-save to backend
- [ ] Backend receives and stores selection correctly
- [ ] Logout → Login restores previous selection
- [ ] Guest users don't trigger save errors
- [ ] Page refresh maintains selection (via localStorage/session)
- [ ] Multi-corpus selection works correctly
- [ ] Corpus names display in chat header

### **Edge Cases**
- [ ] Empty selection (no corpora selected)
- [ ] All corpora selected
- [ ] Rapid selection changes (debouncing?)
- [ ] Network failure during save
- [ ] Invalid corpus names

---

## 🔄 **Data Flow Diagram**

```
User Action → Frontend State → Backend API → Database
    ↓              ↓               ↓             ↓
Select corpus  selectedCorpora  PUT /api/users/  user_profiles
                   state        me/preferences   .preferences
                                                  {selected_corpora}
                     ↓
                 Chat header
                displays names
```

**On Login:**
```
Login → GET /api/users/me → Load preferences → setSelectedCorpora()
         or /me/preferences    .selected_corpora      ↓
                                                  CorpusSelector
                                                  shows selection
```

---

## 📦 **Files to Modify**

### **Backend**
1. `backend/src/services/user_service.py` - Add corpus preference methods
2. `backend/src/api/routes/users.py` - Verify/test preference endpoint

### **Frontend**
1. `frontend/src/app/page.tsx` - Main changes:
   - Add CorpusSelector to chat sidebar (lines 320-422)
   - Create `handleCorporaChange` with auto-save
   - Load preferences in `handleLoginSuccess`
   - Load preferences in initial auth `useEffect`

2. `frontend/src/lib/api-client.ts` or `api-enhanced.ts` - Verify API methods

---

## ⏱️ **Time Estimate**

- **Phase 1:** 0 min (using existing JSON field)
- **Phase 2:** 25 min (backend service + endpoint)
- **Phase 3:** 55 min (frontend changes)
- **Phase 4:** 20 min (testing)

**Total:** ~1.5-2 hours

---

## 🚀 **Deployment Notes**

1. No database migration required (using existing `preferences` field)
2. Backend changes are backward compatible
3. Frontend changes are non-breaking
4. Can deploy incrementally (backend first, then frontend)

---

## 📌 **Success Criteria**

- [x] CorpusSelector visible in both landing and chat modes
- [x] User selections automatically saved to backend
- [x] Selections persist across login sessions
- [x] Guest users work without errors
- [x] No console errors or warnings
- [x] Clean, maintainable code

---

## 🔮 **Future Enhancements**

- Debounce auto-save to reduce API calls
- Add "Recently Used" corpora section
- Add "Favorite" corpus feature
- Corpus selection analytics
- Bulk corpus operations

---

## ✅ **IMPLEMENTATION COMPLETED**

**Date Completed:** January 8, 2026  
**Total Time Spent:** ~3 hours  
**All Phases:** ✅ Complete

### **Commits**

1. **Phase 3 - Corpus Selector Visibility & Vertex AI Sync**
   - Commit: `0647577`
   - Added CorpusSelector to chat interface sidebar
   - Implemented Vertex AI validation in backend
   - Deleted corpora automatically filtered out

2. **Phase 4 - Auto-Save Functionality**
   - Commit: `0e7bdd0`
   - Auto-save handler in page.tsx
   - Saves to user_profiles.preferences.selected_corpora
   - Guest users skipped (no save)

3. **Phase 5 - Load Preferences on Login**
   - Commit: `b2c3b4b`
   - Preference loading in initial auth check
   - Preference loading in handleLoginSuccess
   - Restores selection automatically

4. **Show All Corpora with Access Indicators**
   - Commit: `eabe7e1`
   - New backend endpoint: GET /api/corpora/all-with-access
   - Lock icons for restricted corpora
   - "(No Access)" labels
   - Disabled state for inaccessible corpora

### **Final Implementation**

#### **Backend Files Modified**
- `backend/src/api/routes/corpora.py` - Added all-with-access endpoint
- `backend/src/services/corpus_service.py` - Added get_all_corpora_with_user_access() method
- `backend/src/services/user_service.py` - Added save_corpus_selection() and get_corpus_selection()

#### **Frontend Files Modified**
- `frontend/src/app/page.tsx` - Auto-save handler, preference loading
- `frontend/src/components/CorpusSelector.tsx` - All corpora display, access indicators
- `frontend/src/lib/api-enhanced.ts` - getAllCorporaWithAccess() method

#### **Features Delivered**
✅ Corpus selector always visible (landing + chat modes)  
✅ Auto-save on selection change  
✅ Load preferences on login/refresh  
✅ Show all corpora with access indicators  
✅ Vertex AI sync (filter deleted corpora)  
✅ Per-user independent preferences  
✅ Guest users handled (no save)  
✅ Visual indicators (lock icons, colors, labels)  

#### **Testing Guide**
See: `cascade-logs/2026-01-08/TESTING_GUIDE_Corpus_Selector_Persistence.md`

---

**Status:** ✅ Complete - Ready for User Testing
