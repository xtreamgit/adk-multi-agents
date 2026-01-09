# Sessions Page - How It Works

**Date:** January 9, 2026

---

## ❓ Why Sessions Page Is Empty

The Sessions page is showing **0 sessions** because **no chat sessions have been created yet**.

### What Are Sessions?

Sessions are created when users start chatting with the RAG agents. Each chat conversation is tracked as a session in the `user_sessions` table.

**Session Creation Flow:**
1. User logs into the main app (`http://localhost:3000`)
2. User starts a chat conversation
3. Backend creates a new session via `POST /api/sessions`
4. Session is stored in `user_sessions` table with:
   - `session_id`: Unique identifier
   - `user_id`: The user who created it
   - `active_agent_id`: Which agent they're talking to
   - `active_corpora`: Which knowledge bases are being used
   - `created_at`, `last_activity`: Timestamps

---

## 📊 Database Structure

### Table: `user_sessions`

```sql
CREATE TABLE user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    user_id INTEGER NOT NULL,
    active_agent_id INTEGER,
    active_corpora TEXT,  -- JSON array
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (active_agent_id) REFERENCES agents(id)
);
```

**Current Count:** 0 sessions

---

## 🔍 What The Admin Sessions Page Shows

The Admin Sessions page (`/admin/sessions`) displays:
- All active sessions across all users
- Session ID
- Username of the session owner
- Created timestamp
- Last activity timestamp
- Message count (currently set to 0 as messages aren't tracked in this table)

---

## ✅ How To Test Sessions Display

### Option 1: Create a Session Via Chat

1. Login to main app: `http://localhost:3000`
2. Start a chat conversation with the agent
3. This will automatically create a session
4. Go back to `/admin/sessions` and refresh

### Option 2: Create a Test Session Manually

```sql
-- Insert a test session
INSERT INTO user_sessions (session_id, user_id, active_agent_id, is_active)
VALUES ('test-session-001', 2, 1, 1);

-- alice (user_id=2), default agent (agent_id=1)
```

Then refresh the admin sessions page.

### Option 3: Use API to Create Session

```bash
# Login as alice first
TOKEN=$(curl -s -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "AdminPass123!"}' | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

# Create a session
curl -X POST "http://localhost:8000/api/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

---

## 🛠️ Fix Applied

**Issue:** Sessions endpoint was querying wrong table name (`sessions` instead of `user_sessions`)

**Fix:** 
- Updated query to use correct table: `user_sessions`
- Fixed field names: `last_activity` instead of `updated_at`
- Removed JOIN to non-existent `messages` table

**Commit:** `b646b40` - fix: Correct sessions endpoint to query user_sessions table

---

## 📋 Session Management Features

The admin can see:
- **All active sessions** across all users
- **Session details**: ID, owner, timestamps
- **Activity metrics**: When session was created, last activity

**Note:** Message counts are currently set to 0 because individual messages aren't stored in the `user_sessions` table. To track message counts, you would need to:
1. Create a `messages` table
2. Link messages to sessions
3. Update the query to COUNT messages per session

---

## 🎯 Next Steps

To see sessions in the admin panel:
1. Create at least one chat session in the main app
2. Or manually insert a test session in the database
3. Refresh the Sessions page

**Sessions are stored per user** - each session has a `user_id` field that links it to the user who created it.
