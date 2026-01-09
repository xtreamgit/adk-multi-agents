# Sessions Not Displaying - Root Cause & Fix

**Date:** January 9, 2026  
**Issue:** Sessions page showing 0 sessions even after users create chat sessions

---

## 🔍 Root Cause

**Problem:** Sessions were only stored in-memory, never persisted to database.

### What Was Happening:

When `POST /api/sessions` was called to create a session:

```python
# backend/src/api/server.py (OLD CODE)
session_service.create_session(  # This was the ADK session service
    app_name="rag_agent_api",
    user_id="api_user",
    session_id=session_id,
)

sessions[session_id] = {  # Only stored in-memory dict
    "session_id": session_id,
    "username": current_user.username,
    "user_id": current_user.id,
    ...
}
```

**Issue:** 
- Line 609: Called ADK's `session_service.create_session()` (not our SessionService)
- Line 616: Stored session in `sessions` dict (in-memory only)
- **NEVER called our `SessionService.create_session()` to persist to `user_sessions` table**

### Why Admin Page Was Empty:

The admin sessions endpoint queries the database:

```python
# backend/src/api/routes/admin.py
SELECT us.session_id, u.username, us.created_at, us.last_activity
FROM user_sessions us
LEFT JOIN users u ON us.user_id = u.id
WHERE us.is_active = 1
```

**Result:** 0 sessions because `user_sessions` table was empty!

---

## ✅ Fix Applied

**Commit:** `da0d4a7` - Persist sessions to database when created via POST /api/sessions

### Changes Made:

Added database persistence call in `backend/src/api/server.py`:

```python
# NEW CODE (lines 615-624)
# Persist session to database using SessionService
from services.session_service import SessionService
from models.session import SessionCreate

session_create_data = SessionCreate(
    session_id=session_id,
    user_id=current_user.id,
    active_agent_id=agent_id
)
SessionService.create_session(session_create_data)

# Store session information with agent details (in-memory for quick access)
sessions[session_id] = {
    ...
}
```

**Now:**
1. ✅ Session stored in `user_sessions` table
2. ✅ Session also stored in-memory for fast access
3. ✅ Admin endpoint can retrieve from database
4. ✅ Sessions persist across server restarts

---

## 🧪 Verification

### Created Test Session:

```bash
POST /api/sessions
Authorization: Bearer <token>
```

**Response:**
```json
{
    "session_id": "8ed85514-1227-4f14-abfb-9b4693810e12",
    "username": "alice",
    "created_at": "2026-01-09T22:50:01.798926Z",
    "last_activity": "2026-01-09T22:50:01.798926Z"
}
```

### Database Check:

```bash
sqlite3 backend/data/users.db "SELECT * FROM user_sessions WHERE is_active = 1;"
```

**Result:**
```
8ed85514-1227-4f14-abfb-9b4693810e12|2|1|2026-01-09T22:50:01.801117+00:00|1
```

✅ **Session persisted to database!**

### Admin Endpoint Check:

```bash
GET /api/admin/sessions
Authorization: Bearer <token>
```

**Response:**
```json
[
    {
        "session_id": "8ed85514-1227-4f14-abfb-9b4693810e12",
        "username": "alice",
        "created_at": "2026-01-09T22:50:01.801117+00:00",
        "last_activity": "2026-01-09T22:50:01.801117+00:00",
        "chat_messages": 0
    }
]
```

✅ **Admin endpoint now returns sessions!**

---

## 📊 How Sessions Work Now

### Session Creation Flow:

1. User starts chat in main app (`http://localhost:3000`)
2. Frontend calls `POST /api/sessions` with auth token
3. Backend:
   - Creates ADK session (for RAG agent)
   - **Creates database record** in `user_sessions` table
   - Stores in-memory for quick access
4. Session includes:
   - `session_id` (UUID)
   - `user_id` (who created it)
   - `active_agent_id` (which agent)
   - `created_at`, `last_activity` timestamps
   - `is_active` flag

### Admin Page Display:

1. Admin navigates to `/admin/sessions`
2. Frontend calls `GET /api/admin/sessions`
3. Backend queries `user_sessions` table
4. Returns all active sessions
5. Frontend displays in table format

---

## 🎯 Next Steps for User

### To See Sessions in Admin Page:

1. **Refresh the admin sessions page** (`/admin/sessions`)
2. You should now see **1 session** displayed
3. Session will show:
   - Session ID: `8ed85514-1227-4f14-abfb-9b4693810e12`
   - Username: `alice`
   - Created: Today's timestamp
   - Last Activity: Today's timestamp
   - Messages: 0

### To Create More Sessions:

**Option 1:** Use the main chat app
- Go to `http://localhost:3000`
- Start chatting
- Each chat creates a new session

**Option 2:** Call API directly
```bash
curl -X POST "http://localhost:8000/api/sessions" \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json"
```

---

## 📝 Technical Details

### Tables Involved:

**user_sessions:**
- Stores persistent session data
- Survives server restarts
- Used by admin panel

**sessions (in-memory dict):**
- Fast access during active chat
- Lost on server restart
- Used for chat operations

### SessionService Methods:

- `create_session()` - Persists to database
- `get_session_by_session_id()` - Retrieves from database
- `update_last_activity()` - Updates timestamps
- `invalidate_session()` - Deactivates session

---

## 🎉 Summary

**Issue:** Sessions not displaying because they weren't saved to database  
**Fix:** Added `SessionService.create_session()` call to persist sessions  
**Status:** ✅ Fixed and verified  
**Result:** Admin sessions page will now display all active sessions  

**The session variable exists and is greater than zero - refresh your browser to see it!**
