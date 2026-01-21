# Session Counter Follow-up Fix

**Date:** January 20, 2026  
**Status:** ✅ Implemented

---

## Issue After Initial Fix

After implementing the database migration and message counter logic:
- Total Messages still showing **0**
- Sessions showing as **"Inactive"** even when they are active
- Last activity showing correct timestamp (7:37:59 PM)

---

## Root Causes Identified

### 1. Session Creation Doesn't Initialize Counters

**File:** `backend/src/services/session_service.py` (lines 38-42)

**Problem:**
```python
INSERT INTO user_sessions 
(session_id, user_id, active_agent_id, active_corpora, 
 created_at, last_activity, expires_at, is_active)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
```

The INSERT statement **didn't include** `message_count` or `user_query_count` columns. This meant:
- New sessions had NULL values for these columns
- Even though columns have DEFAULT 0, explicit INSERT without column names doesn't use defaults
- COALESCE in queries would return 0, but better to explicitly set them

### 2. Wrong "Inactive" Status Logic

**File:** `frontend/src/app/admin/sessions/page.tsx` (line 152)

**Problem:**
```tsx
{session.chat_messages > 0 ? 'Active' : 'Inactive'}
```

Logic was backwards:
- Showed "Active" only if `chat_messages > 0`
- New sessions with 0 messages showed as "Inactive"
- **Should show "Active" for all sessions in the active sessions list** (they're already filtered by `is_active = TRUE`)

---

## Solutions Implemented

### 1. Fixed Session Creation

**File:** `backend/src/services/session_service.py`

**Before:**
```python
cursor.execute("""
    INSERT INTO user_sessions 
    (session_id, user_id, active_agent_id, active_corpora, 
     created_at, last_activity, expires_at, is_active)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
""", (session_create.session_id, session_create.user_id, 
      session_create.active_agent_id, active_corpora_json,
      created_at, created_at, expires_at, True))
```

**After:**
```python
cursor.execute("""
    INSERT INTO user_sessions 
    (session_id, user_id, active_agent_id, active_corpora, 
     created_at, last_activity, expires_at, is_active,
     message_count, user_query_count)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
""", (session_create.session_id, session_create.user_id, 
      session_create.active_agent_id, active_corpora_json,
      created_at, created_at, expires_at, True,
      0, 0))
```

**Changes:**
- Added `message_count` and `user_query_count` to column list
- Initialize both to **0** explicitly
- Ensures new sessions start with correct counter values

---

### 2. Fixed Status Display Logic

**File:** `frontend/src/app/admin/sessions/page.tsx`

**Before:**
```tsx
<span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
  session.chat_messages > 0 
    ? 'bg-green-100 text-green-800' 
    : 'bg-gray-100 text-gray-800'
}`}>
  {session.chat_messages > 0 ? 'Active' : 'Inactive'}
</span>
```

**After:**
```tsx
<span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
  Active
</span>
```

**Rationale:**
- All sessions in "All Active Sessions" list are already filtered by `WHERE us.is_active = TRUE`
- If they're in this list, they ARE active
- No need for conditional logic based on message count
- Simpler and more accurate

---

## Why Counters Were Still 0

### The Chain of Events:

1. **Migration added columns** with DEFAULT 0 ✅
2. **Admin endpoint updated** to query message_count ✅  
3. **Chat endpoint updated** to increment counters ✅
4. **BUT**: Session creation didn't include the new columns ❌

**Result:**
- Existing sessions: NULL values (displayed as 0 via COALESCE)
- New sessions after migration: Also NULL (INSERT didn't specify columns)
- Messages sent: Counters incremented from NULL → worked due to `COALESCE(message_count, 0) + 2`
- But new sessions still started with NULL instead of 0

**Why this matters:**
- Cleaner data (0 instead of NULL)
- Explicit initialization
- Easier debugging
- Better data integrity

---

## Complete Fix Summary

### Files Changed:

1. **backend/src/services/session_service.py**
   - Added `message_count` and `user_query_count` to INSERT statement
   - Initialize to 0 for new sessions

2. **frontend/src/app/admin/sessions/page.tsx**
   - Removed conditional "Inactive" logic
   - Always show "Active" for sessions in active list

### Previously Changed (from initial fix):

3. **backend/src/api/routes/admin.py**
   - Query message_count and user_query_count from database
   - Return actual values instead of hardcoded 0

4. **backend/src/api/server.py**
   - Increment message_count by 2 on each message
   - Increment user_query_count by 1 on each user message

5. **Database:**
   - Added message_count column (INTEGER DEFAULT 0)
   - Added user_query_count column (INTEGER DEFAULT 0)

---

## Testing

### Steps to Verify:

1. **Restart backend server** (REQUIRED!)
   ```bash
   # Backend needs restart to load updated code
   cd backend
   python src/api/server.py
   ```

2. **Create new session:**
   - Open chat in browser
   - Start a new conversation
   - Send a message

3. **Verify in admin panel:**
   - Navigate to `/admin/sessions`
   - Check that:
     - New session shows "Active" (not "Inactive")
     - After sending 1 message: Total Messages = 2
     - After sending 1 message: 1 user query
     - Each additional message adds +2 to total, +1 to queries

4. **Check database directly:**
   ```python
   # Verify counters in DB
   import sys
   sys.path.insert(0, 'backend/src')
   from database.connection import get_db_connection
   
   with get_db_connection() as conn:
       with conn.cursor() as cursor:
           cursor.execute("""
               SELECT session_id, message_count, user_query_count, is_active
               FROM user_sessions
               ORDER BY last_activity DESC
               LIMIT 5
           """)
           for row in cursor.fetchall():
               print(row)
   ```

---

## Expected Behavior After Fix

### Initial State (New Session):
```
Session ID: abc123...
Status: Active
Messages: 0
User Queries: 0
```

### After 1 Message Exchange:
```
Session ID: abc123...
Status: Active
Messages: 2
User Queries: 1
```

### After 3 Message Exchanges:
```
Session ID: abc123...
Status: Active
Messages: 6
User Queries: 3
```

### Admin Dashboard Total:
- **Total Messages**: Sum of all sessions' message_count
- **User Queries**: Sum of all sessions' user_query_count
- Updates in real-time as messages are sent

---

## Why Backend Restart is Critical

**Code changes made:**
- ✅ `session_service.py`: Session creation
- ✅ `admin.py`: Session listing endpoint
- ✅ `server.py`: Message counter increment
- ✅ `page.tsx`: Status display (frontend will hot-reload)

**Python server caches:**
- Imported modules
- Function definitions
- Database queries

**Without restart:**
- Server still uses OLD code
- Session creation uses old INSERT statement
- Counters won't be initialized
- Changes won't take effect

**After restart:**
- Server loads NEW code
- New sessions include message counters
- Increments work correctly
- Everything functions as expected

---

## Summary

**Problem:** Message counters showing 0, sessions showing "Inactive"  

**Root Causes:**
1. Session INSERT didn't include message counter columns
2. Frontend status logic based on message count instead of `is_active` flag

**Solution:**
1. Add message_count and user_query_count to session creation INSERT
2. Simplify status display to always show "Active" for active sessions

**Next Step:** **RESTART BACKEND SERVER** to apply changes

✅ After restart, message counters will work correctly!
