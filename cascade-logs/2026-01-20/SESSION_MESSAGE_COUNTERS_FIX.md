# Session Message Counters Fix

**Date:** January 20, 2026  
**Status:** ✅ Implemented

---

## Issue

The "All Sessions" admin page showed:
- **Total Messages**: 0
- **0 user queries**

Even though there were active sessions with messages being sent. The counters never increased.

---

## Root Cause

### Backend Hardcoded Values

**File:** `backend/src/api/routes/admin.py` (line 857)

```python
formatted_sessions.append({
    "session_id": row['session_id'],
    "username": row['username'],
    "created_at": row['created_at'],
    "last_activity": row['last_activity'],
    "chat_messages": 0,  # ❌ Hardcoded to 0!
    # ❌ user_queries field was missing entirely
})
```

### Missing Database Columns

The `user_sessions` table had no columns to track:
- Message count per session
- User query count per session

### Ephemeral In-Memory Storage

Messages were stored in `sessions[session_id]["chat_history"]` (server.py line 842), but:
- Lost on server restarts
- Not persisted to database
- Not accessible from admin endpoint

---

## Solution

### 1. Added Database Columns

**Migration:** `backend/src/database/migrations/add_message_counters.sql`

```sql
ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS message_count INTEGER DEFAULT 0;
ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS user_query_count INTEGER DEFAULT 0;
```

**Columns:**
- `message_count`: Total messages in session (user + agent)
- `user_query_count`: Number of user queries

---

### 2. Updated Chat Endpoint to Increment Counters

**File:** `backend/src/api/server.py` (lines 844-853)

**Before:**
```python
# Update last activity in database
with get_db_connection() as conn:
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE user_sessions 
        SET last_activity = %s
        WHERE session_id = %s
    """, (datetime.now(timezone.utc), session_id))
    conn.commit()
```

**After:**
```python
# Update last activity and increment message counters in database
with get_db_connection() as conn:
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE user_sessions 
        SET last_activity = %s,
            message_count = COALESCE(message_count, 0) + 2,
            user_query_count = COALESCE(user_query_count, 0) + 1
        WHERE session_id = %s
    """, (datetime.now(timezone.utc), session_id))
    conn.commit()
```

**Logic:**
- `message_count + 2`: User message + agent response = 2 messages
- `user_query_count + 1`: Each user message is one query
- `COALESCE` handles NULL values (defaults to 0)

---

### 3. Updated Admin Endpoint to Return Actual Counts

**File:** `backend/src/api/routes/admin.py` (lines 827-866)

**Before:**
```python
cursor.execute("""
    SELECT us.session_id, u.username, us.created_at, us.last_activity,
           us.active_agent_id, us.active_corpora
    FROM user_sessions us
    LEFT JOIN users u ON us.user_id = u.id
    WHERE us.is_active = TRUE
    ORDER BY us.last_activity DESC
    LIMIT 100
""")
rows = cursor.fetchall()

formatted_sessions.append({
    "session_id": row['session_id'],
    "username": row['username'],
    "created_at": row['created_at'],
    "last_activity": row['last_activity'],
    "chat_messages": 0,  # ❌ Hardcoded
    "agent_id": row['active_agent_id'],
    "active_corpora": row['active_corpora']
})
```

**After:**
```python
cursor.execute("""
    SELECT us.session_id, u.username, us.created_at, us.last_activity,
           us.active_agent_id, us.active_corpora,
           COALESCE(us.message_count, 0) as message_count,
           COALESCE(us.user_query_count, 0) as user_query_count
    FROM user_sessions us
    LEFT JOIN users u ON us.user_id = u.id
    WHERE us.is_active = TRUE
    ORDER BY us.last_activity DESC
    LIMIT 100
""")
rows = cursor.fetchall()

formatted_sessions.append({
    "session_id": row['session_id'],
    "username": row['username'],
    "created_at": row['created_at'],
    "last_activity": row['last_activity'],
    "chat_messages": row['message_count'],  # ✅ From database
    "user_queries": row['user_query_count'],  # ✅ New field
    "agent_id": row['active_agent_id'],
    "active_corpora": row['active_corpora']
})
```

---

## Frontend Display

**File:** `frontend/src/app/admin/sessions/page.tsx`

No changes needed! Frontend already calculates totals correctly:

```tsx
{/* Total Messages */}
<p className="text-3xl font-bold text-green-600">
  {userSessions.reduce((total, session) => total + (session.chat_messages || 0), 0)}
</p>
<p className="text-sm text-gray-500 mt-1">
  {userSessions.reduce((total, session) => total + (session.user_queries || 0), 0)} user queries
</p>
```

Now that backend provides actual counts, these will display correctly.

---

## How It Works

### Message Flow

1. **User sends message** → Chat endpoint receives it
2. **Chat endpoint:**
   - Stores message in in-memory `sessions` dict
   - Updates database: `message_count += 2`, `user_query_count += 1`
3. **Agent responds** → Response included in the +2 count
4. **Admin page loads** → Fetches sessions with actual counts from database
5. **Frontend displays** → Aggregates counts across all sessions

### Counter Logic

**Per message exchange:**
- User sends: "What is RAG?"
- Agent responds: "RAG stands for..."
- **Result:** `message_count += 2`, `user_query_count += 1`

**Why +2 for messages?**
- Each conversation turn has 2 messages (user + agent)
- Counted together when user message is received
- Simplifies tracking since responses are guaranteed

---

## Testing

### Run Migration (if needed)

```bash
cd /Users/hector/github.com/xtreamgit/adk-multi-agents

# Option 1: Using Python
python3 -c "
import sys
sys.path.insert(0, 'backend/src')
from database.connection import get_db_connection
conn = get_db_connection()
cursor = conn.cursor()
cursor.execute('ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS message_count INTEGER DEFAULT 0')
cursor.execute('ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS user_query_count INTEGER DEFAULT 0')
conn.commit()
print('✅ Columns added')
"

# Option 2: Using SQL file (if you have psql access)
psql -h localhost -p 5433 -d ragma -f backend/src/database/migrations/add_message_counters.sql
```

### Restart Backend

```bash
# Backend will pick up the new code
# Restart your backend server
```

### Test the Fix

1. **Navigate to `/admin/sessions`**
2. **Send new messages in chat:**
   - Go to main chat page
   - Send a few messages to the agent
3. **Refresh admin sessions page**
4. **Verify counters:**
   - "Total Messages" should increase by 2 per exchange
   - "User Queries" should increase by 1 per user message
5. **Check per-session counts:**
   - Each session row shows its message count
   - Verify numbers match expected values

---

## Example Output

### Before Fix
```
Active Sessions: 14
Total Messages: 0
0 user queries
```

### After Fix (After 5 user messages)
```
Active Sessions: 14
Total Messages: 10
5 user queries
```

**Per Session:**
```
Session 1: Messages: 6, User Queries: 3
Session 2: Messages: 4, User Queries: 2
```

---

## Edge Cases Handled

### NULL Values
- `COALESCE(message_count, 0)` handles sessions created before migration
- Defaults to 0 if column is NULL

### Existing Sessions
- Old sessions start at 0
- New messages increment from 0
- No data loss or corruption

### Server Restarts
- Counts persisted in database
- Survive server restarts
- Always accurate

---

## Benefits

✅ **Accurate Counts**: Real message and query counts  
✅ **Persistent**: Stored in database, not ephemeral  
✅ **Real-time**: Updates with each message  
✅ **Admin Visibility**: Monitor system usage  
✅ **Session Tracking**: See activity per session  

---

## Files Changed

### Backend
- `backend/src/api/routes/admin.py`: Query and return message counts
- `backend/src/api/server.py`: Increment counters on each message
- `backend/src/database/migrations/add_message_counters.sql`: Add columns

### Frontend
- No changes needed (already handles the data correctly)

### Database
- `user_sessions` table: +2 columns (`message_count`, `user_query_count`)

---

## Summary

**Problem:** Message counters always showed 0  
**Cause:** Backend hardcoded values, no database tracking  
**Solution:** Added DB columns + increment on each message + query actual counts  
**Result:** Accurate real-time message counters in admin dashboard

**User Flow:**
1. User sends message
2. Backend increments counters in DB
3. Admin page shows actual counts
4. Counters persist across restarts

✅ **All Sessions page now shows accurate message statistics!**
