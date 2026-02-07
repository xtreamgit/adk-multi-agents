# Corpus Selector Persistence - Testing Guide
**Date:** January 8, 2026  
**Feature:** Corpus Selector Persistence & Visibility  
**Status:** ✅ Implementation Complete - Ready for Testing

---

## Overview

This guide provides comprehensive testing scenarios for the corpus selector persistence feature. All code is implemented and committed. This document helps validate that the feature works as expected.

---

## Feature Summary

### What Was Implemented

1. **Persistent Corpus Selection**
   - Auto-saves corpus selection to user profile preferences
   - Loads saved preferences on login/page refresh
   - Per-user storage (alice's selection != bob's selection)

2. **Always-Visible Corpus Selector**
   - Visible on landing page (before first query)
   - Visible during active chat sessions
   - Consistent sidebar placement

3. **All Corpora Display**
   - Shows all active corpora regardless of user access
   - Visual indicators for accessible vs. restricted corpora
   - Lock icon (🔒) and "(No Access)" label for restricted corpora

4. **Vertex AI Sync**
   - Real-time validation against Vertex AI
   - Deleted corpora automatically filtered out
   - No stale corpus data displayed

---

## Test Environment Setup

### Prerequisites
```bash
# Backend running
cd backend && python -m src.api.server

# Frontend running
cd frontend && npm run dev

# Database has users and corpora
sqlite3 backend/data/users.db
```

### Test Users
- **alice** - member of `developers` group
- **guest** - limited access (auto-save disabled)

### Expected Corpora (as of Jan 8, 2026)
1. `ai-books` - AI Books Collection
2. `design` - design
3. `fiction` - fiction
4. `management` - management
5. `test-corpus` - Test Corpus

---

## Testing Scenarios

### Scenario 1: Basic Selection & Auto-Save

**Objective:** Verify corpus selection is automatically saved

**Steps:**
1. Open browser console (F12)
2. Login as `alice`
3. Navigate to corpus selector in left sidebar
4. Select 2-3 corpora (e.g., "ai-books", "design")
5. Watch console for: `✅ Corpus selection saved: ["ai-books", "design"]`
6. Wait 2 seconds for save to complete

**Expected Results:**
- ✅ Checkboxes turn blue when selected
- ✅ Console shows save confirmation
- ✅ No error messages in console

**Verification:**
```bash
# Check database
sqlite3 backend/data/users.db "SELECT u.username, up.preferences FROM users u JOIN user_profiles up ON u.id = up.user_id WHERE u.username = 'alice';"

# Expected output:
# alice|{"selected_corpora": ["ai-books", "design"]}
```

---

### Scenario 2: Page Refresh Persistence

**Objective:** Verify selection persists across page refreshes

**Steps:**
1. Login as `alice`
2. Select corpora: "management", "test-corpus"
3. Verify console: `✅ Corpus selection saved`
4. **Refresh page** (Cmd+R or F5)
5. Watch console for: `✅ Loaded saved corpus preferences: ["management", "test-corpus"]`
6. Check corpus selector

**Expected Results:**
- ✅ "management" checkbox is checked
- ✅ "test-corpus" checkbox is checked
- ✅ Other corpora remain unchecked
- ✅ Selection restored immediately on page load

---

### Scenario 3: Logout & Login Persistence

**Objective:** Verify selection persists across logout/login

**Steps:**
1. Login as `alice`
2. Select: "ai-books", "fiction" (if alice has access)
3. Verify console save confirmation
4. Click "Logout" button
5. Login again as `alice`
6. Check corpus selector

**Expected Results:**
- ✅ "ai-books" is checked
- ✅ "fiction" is checked (if accessible)
- ✅ Console shows: `✅ Loaded saved corpus preferences`
- ✅ Selection restored automatically

---

### Scenario 4: Cross-Browser Persistence

**Objective:** Verify selection persists across different browsers/sessions

**Steps:**
1. **Browser A (Chrome):**
   - Login as `alice`
   - Select "design", "management"
   - Logout
2. **Browser B (Firefox):**
   - Login as `alice`
   - Check corpus selector

**Expected Results:**
- ✅ "design" is checked in Browser B
- ✅ "management" is checked in Browser B
- ✅ Selection synced via backend storage

---

### Scenario 5: Multi-User Independence

**Objective:** Verify each user has independent preferences

**Steps:**
1. Login as `alice`
2. Select "ai-books", "design"
3. Logout
4. Login as different user (e.g., `bob` or `guest`)
5. Check corpus selector
6. Select different corpora (e.g., "management")
7. Logout
8. Login as `alice` again
9. Check corpus selector

**Expected Results:**
- ✅ Alice's selection: "ai-books", "design" (unchanged)
- ✅ Bob's selection: "management" (independent)
- ✅ No cross-contamination between users

---

### Scenario 6: Corpus Selector Visibility in Chat

**Objective:** Verify selector remains visible during chat sessions

**Steps:**
1. Login as `alice`
2. Select "design" corpus
3. Type query: "What is design thinking?"
4. Submit query
5. Wait for response
6. Check left sidebar

**Expected Results:**
- ✅ Corpus selector still visible in sidebar
- ✅ "design" still checked
- ✅ Can change corpus selection during chat
- ✅ Selector doesn't disappear after query

---

### Scenario 7: All Corpora Display with Access Indicators

**Objective:** Verify all corpora shown with proper access indicators

**Steps:**
1. Login as `alice`
2. Check corpus selector
3. Count total corpora displayed
4. Identify accessible vs. restricted corpora

**Expected for Alice (developers group):**
- ✅ 5 total corpora displayed
- ✅ Accessible corpora (selectable):
  - `ai-books` (no lock icon)
  - `design` (no lock icon)
  - `management` (no lock icon)
  - `test-corpus` (no lock icon)
- ✅ Restricted corpora (if any, grayed out with 🔒):
  - Lock icon visible
  - "(No Access)" label shown
  - Cannot click to select
  - Grayed out appearance

**Visual Indicators:**
- **Accessible:** White/blue background, clickable
- **Restricted:** Gray background, lock icon, "No Access" label

---

### Scenario 8: Guest User (No Auto-Save)

**Objective:** Verify guest users can select but selection isn't saved

**Steps:**
1. Ensure not logged in or login as `guest`
2. Select corpora in selector
3. Check browser console
4. Refresh page

**Expected Results:**
- ✅ Can select corpora for current session
- ✅ Console shows NO save message (skipped for guest)
- ❌ Selection NOT restored after refresh
- ✅ No error messages

---

### Scenario 9: Vertex AI Sync - Deleted Corpus

**Objective:** Verify deleted corpora don't appear

**Setup:**
```bash
# Delete a corpus from Vertex AI (or simulate by marking inactive in DB)
sqlite3 backend/data/users.db "UPDATE corpora SET is_active = 0 WHERE name = 'test-corpus';"
```

**Steps:**
1. Login as `alice`
2. Check corpus selector
3. Count displayed corpora

**Expected Results:**
- ✅ `test-corpus` NOT shown (deleted/inactive)
- ✅ Only active corpora displayed (4 instead of 5)
- ✅ No errors in console

**Cleanup:**
```bash
sqlite3 backend/data/users.db "UPDATE corpora SET is_active = 1 WHERE name = 'test-corpus';"
```

---

### Scenario 10: Backend Validation

**Objective:** Verify backend API returns correct data

**Steps:**
```bash
# Get alice's auth token
TOKEN=$(sqlite3 backend/data/users.db "SELECT 'test_token_for_user_' || id FROM users WHERE username='alice' LIMIT 1")

# Test all-with-access endpoint
curl -s http://localhost:8000/api/corpora/all-with-access \
  -H "Authorization: Bearer $TOKEN" | jq '.[] | {name: .name, has_access: .has_access}'

# Test preferences endpoint
curl -s http://localhost:8000/api/users/me \
  -H "Authorization: Bearer $TOKEN" | jq '.profile.preferences'
```

**Expected Results:**
```json
// All corpora with access flags
[
  {"name": "ai-books", "has_access": true},
  {"name": "design", "has_access": true},
  {"name": "fiction", "has_access": false},
  {"name": "management", "has_access": true},
  {"name": "test-corpus", "has_access": true}
]

// User preferences
{
  "selected_corpora": ["ai-books", "design"]
}
```

---

## Common Issues & Troubleshooting

### Issue 1: Selection Not Saving
**Symptoms:** No console message, preferences not in DB

**Checks:**
1. User logged in? (guest users don't save)
2. Console errors?
3. Backend running?
4. Network tab shows PUT request to `/api/users/me/preferences`?

**Solution:**
```bash
# Check backend logs
# Verify database connection
# Check browser console for errors
```

---

### Issue 2: Selection Not Loading
**Symptoms:** Page loads but corpora unchecked

**Checks:**
1. Console shows load message?
2. Preferences exist in database?
3. Corpus names match exactly (case-sensitive)?

**Solution:**
```bash
# Verify preferences in DB
sqlite3 backend/data/users.db "SELECT preferences FROM user_profiles WHERE user_id = (SELECT id FROM users WHERE username='alice');"

# Should return JSON with selected_corpora array
```

---

### Issue 3: Corpus Selector Not Visible
**Symptoms:** Can't find selector in sidebar

**Checks:**
1. Logged in?
2. Page fully loaded?
3. Check left sidebar scroll position

**Solution:**
- Scroll left sidebar
- Selector between navigation buttons and "Chats" section

---

### Issue 4: Wrong Corpora Count
**Symptoms:** Not seeing all 5 corpora

**Checks:**
1. Backend synced with Vertex AI?
2. Corpora active in database?
3. User has any access?

**Solution:**
```bash
# Run sync script
python backend/sync_corpora_from_vertex.py

# Check active corpora
sqlite3 backend/data/users.db "SELECT name, is_active FROM corpora;"
```

---

## Performance Benchmarks

### Expected Response Times
- Corpus list load: < 2 seconds
- Auto-save: < 1 second
- Preference load: < 500ms
- Page load with preferences: < 3 seconds

### Database Queries
- All corpora fetch: ~50-100ms
- User preferences save: ~20-50ms
- Vertex AI validation: ~500-1000ms

---

## Feature Commits

All changes committed to main branch:

1. **Phase 3 (eabe7e1):** Show all corpora with access indicators
2. **Phase 5 (b2c3b4b):** Load saved corpus preferences on login
3. **Phase 4 (0e7bdd0):** Auto-save corpus selection to user preferences
4. **Phase 3 (0647577):** Add corpus selector to chat interface & Vertex AI sync

---

## Sign-Off Checklist

- [ ] All 10 test scenarios pass
- [ ] No console errors during normal use
- [ ] Database preferences correctly formatted
- [ ] Multi-user independence verified
- [ ] Cross-browser persistence confirmed
- [ ] Vertex AI sync working
- [ ] Performance within acceptable range
- [ ] Visual indicators clear and intuitive

---

## Next Steps After Testing

If all tests pass:
1. ✅ Feature ready for production
2. Update user documentation
3. Train users on corpus selection
4. Monitor backend logs for issues

If tests fail:
1. Document specific failures
2. Check console/backend logs
3. Verify database state
4. Review recent commits

---

## Support & Documentation

**Implementation Plan:** `cascade-logs/2026-01-08/IMPLEMENTATION_PLAN_Corpus_Selector_Persistence.md`  
**Code Changes:** See git commits above  
**TODO Items:** `cascade-logs/TODO.md`

---

**Testing completed:** ___________  
**Tested by:** ___________  
**Status:** ⏳ Awaiting User Validation
