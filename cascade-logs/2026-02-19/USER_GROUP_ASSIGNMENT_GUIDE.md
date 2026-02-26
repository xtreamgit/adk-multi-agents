# User Group Assignment Guide

## Overview
This guide shows you how to add users to groups in the ADK Multi-Agents system. There are two methods: **Automatic (Google Groups Bridge)** for production, and **Manual (API)** for testing.

---

## Method 1: Automatic via Google Groups Bridge (RECOMMENDED)

This is the preferred method for production. Users are automatically assigned based on Google Workspace group membership.

### Prerequisites
- Google Workspace account with admin access
- User has a Google Workspace email (@develom.com)
- Google Groups Bridge is enabled (GOOGLE_GROUPS_ENABLED=true)

### Step 1: Add User to Google Workspace
1. Go to [Google Admin Console](https://admin.google.com)
2. Navigate to **Directory** → **Users**
3. Click **Add new user**
4. Enter user details (e.g., `newuser@develom.com`)
5. Click **Add new user**

### Step 2: Add User to Google Workspace Group
1. In Google Admin Console, go to **Directory** → **Groups**
2. Select the appropriate RAG group:
   - **rag-admins@develom.com** → Admin access (full permissions)
   - **rag-content-managers@develom.com** → Content management
   - **rag-contributors@develom.com** → Contributor access
   - **rag-viewers@develom.com** → Read-only access
   - **corpus-design@develom.com** → Design corpus access
   - **corpus-ai-books@develom.com** → AI Books corpus access
   - **corpus-management@develom.com** → Management corpus access
   - **corpus-recipes@develom.com** → Recipes corpus access
3. Click **Add members**
4. Enter the user's email
5. Click **Add to group**

### Step 3: User Logs In (Automatic Sync)
1. User navigates to your application URL
2. IAP authenticates user via Google OAuth
3. **Google Groups Bridge automatically:**
   - Queries Cloud Identity API for user's Google Groups
   - Checks `google_group_agent_mappings` table
   - Assigns user to highest-priority chatbot group
   - Creates/updates entry in `chatbot_users` table
   - Creates entry in `chatbot_user_groups` table
   - Syncs corpus access via `google_group_corpus_mappings`
   - Creates entries in `chatbot_corpus_access` table

### Step 4: Verify Assignment
1. Navigate to `/admin/access-matrix` in your app
2. User should appear with:
   - ✅ Email and full name
   - ✅ Assigned chatbot group
   - ✅ Agent assignment (checkmark in appropriate row)
   - ✅ Corpus access (checkmarks in appropriate rows)

### Example: Adding a Contributor
```
Google Workspace:
1. Add user: contributor@develom.com
2. Add to group: rag-contributors@develom.com

User logs in → Automatic sync:
- Chatbot group: contributor-group
- Agent: Contributor Agent
- Corpus access: (based on group mappings)

Access Matrix shows:
- Contributor Agent row → contributor@develom.com column: ✓
```

---

## Method 2: Manual via Admin API (FOR TESTING)

Use this for testing or when Google Workspace integration isn't available.

### Prerequisites
- Backend running on http://localhost:8000
- User must exist in `chatbot_users` table
- You need to know the user's `chatbot_user_id`
- You need to know the target group's `chatbot_group_id`

### Step 1: List Available Users
```bash
curl -s "http://localhost:8000/api/admin/chatbot/users" | python3 -m json.tool
```

**Find the user's ID:**
```json
{
  "id": 4,
  "email": "robert@develom.com",
  "full_name": "Robert Hughes",
  "is_active": true,
  "groups": []
}
```
Note: `id: 4` is the `chatbot_user_id`

### Step 2: List Available Groups
```bash
curl -s "http://localhost:8000/api/admin/chatbot/groups" | python3 -m json.tool
```

**Find the group's ID:**
```json
{
  "id": 19,
  "name": "contributor-group",
  "description": "Contributors with upload access",
  "is_active": true
}
```
Note: `id: 19` is the `chatbot_group_id`

### Step 3: Assign User to Group
```bash
curl -X POST "http://localhost:8000/api/admin/chatbot/users/{user_id}/groups/{group_id}"
```

**Example:**
```bash
curl -X POST "http://localhost:8000/api/admin/chatbot/users/4/groups/19"
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "User assigned to group"
}
```

### Step 4: Grant Corpus Access to Group (Optional)
If the group doesn't have corpus access yet, grant it:

**List available corpora:**
```bash
curl -s "http://localhost:8000/api/admin/access-matrix" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for corpus in data['corpora']:
    print(f'ID: {corpus[\"id\"]:2} Name: {corpus[\"name\"]:20} Display: {corpus[\"display_name\"]}')
"
```

**Grant access:**
```bash
curl -X POST "http://localhost:8000/api/admin/chatbot/corpus-access" \
  -H "Content-Type: application/json" \
  -d '{
    "chatbot_group_id": 19,
    "corpus_id": 3,
    "permission": "query"
  }'
```

**Permissions:**
- `query` - Can query the corpus
- `read` - Can read documents
- `upload` - Can upload documents
- `admin` - Full admin access

### Step 5: Verify in Access Matrix
```bash
curl -s "http://localhost:8000/api/admin/access-matrix" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for user in data['users']:
    if user['chatbot_user_id'] == 4:  # Replace with your user_id
        print(f'User: {user[\"email\"]}')
        print(f'Group: {user[\"chatbot_group_name\"]}')
        agent_id = data['agent_assignments'].get(str(user['chatbot_user_id']))
        print(f'Agent ID: {agent_id}')
        corpus_ids = data['corpus_access'].get(str(user['chatbot_user_id']), [])
        print(f'Corpus IDs: {corpus_ids}')
"
```

---

## Complete Manual Example: Adding robert@develom.com

### Scenario
Add robert@develom.com to contributor-group with access to design corpus.

### Commands
```bash
# Step 1: Find user ID
curl -s "http://localhost:8000/api/admin/chatbot/users" | grep -A 5 "robert@develom.com"
# Result: user_id = 4

# Step 2: Find group ID
curl -s "http://localhost:8000/api/admin/chatbot/groups" | grep -A 3 "contributor-group"
# Result: group_id = 19

# Step 3: Assign user to group
curl -X POST "http://localhost:8000/api/admin/chatbot/users/4/groups/19"
# Response: {"status": "success", "message": "User assigned to group"}

# Step 4: Find corpus ID
curl -s "http://localhost:8000/api/admin/access-matrix" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data['corpora']:
    if 'design' in c['name']:
        print(f'Design corpus ID: {c[\"id\"]}')
"
# Result: corpus_id = 3

# Step 5: Grant corpus access to group
curl -X POST "http://localhost:8000/api/admin/chatbot/corpus-access" \
  -H "Content-Type: application/json" \
  -d '{"chatbot_group_id": 19, "corpus_id": 3, "permission": "query"}'
# Response: {"status": "success", "message": "Corpus access granted"}

# Step 6: Verify in access matrix
curl -s "http://localhost:8000/api/admin/access-matrix" | python3 -c "
import sys, json
data = json.load(sys.stdin)
robert = next((u for u in data['users'] if 'robert' in u['email'].lower()), None)
if robert:
    print(f'✅ User: {robert[\"email\"]}')
    print(f'✅ Group: {robert[\"chatbot_group_name\"]}')
    agent_id = data['agent_assignments'].get(str(robert['chatbot_user_id']))
    if agent_id:
        agent = next((a for a in data['agents'] if a['id'] == agent_id), None)
        print(f'✅ Agent: {agent[\"display_name\"]}')
    corpus_ids = data['corpus_access'].get(str(robert['chatbot_user_id']), [])
    if corpus_ids:
        print(f'✅ Corpora: {corpus_ids}')
"
```

### Expected Output
```
✅ User: robert@develom.com
✅ Group: contributor-group
✅ Agent: Contributor Agent
✅ Corpora: [3]
```

---

## Available Chatbot Groups

| Group ID | Group Name | Description | Agent |
|----------|------------|-------------|-------|
| 21 | admin-group | Full admin access | Admin Agent |
| 20 | content-manager-group | Content management | Content Manager Agent |
| 19 | contributor-group | Upload and contribute | Contributor Agent |
| 18 | viewer-group | Read-only access | Viewer Agent |

---

## Available Agents

| Agent ID | Agent Name | Description |
|----------|------------|-------------|
| 4 | Admin Agent | Full system access |
| 3 | Content Manager Agent | Content management |
| 2 | Contributor Agent | Upload and query |
| 1 | Viewer Agent | Query only |

---

## Available Corpora

| Corpus ID | Corpus Name | Display Name |
|-----------|-------------|--------------|
| 1 | ai-books | AI Books Collection |
| 3 | design | design |
| 4 | management | management |
| 5 | recipes | recipes |
| 6 | semantic-web | semantic-web |
| 7 | hacker-books | hacker-books |
| 17 | great-books | great-books |

---

## Troubleshooting

### User doesn't appear in access matrix
**Check:**
1. User is active: `is_active = TRUE` in `chatbot_users` table
2. User has group assignment in `chatbot_user_groups` table
3. Refresh the page (matrix is query-based, not real-time)

### User shows "No group"
**Fix:**
- Assign user to a chatbot group using the API
- Or add user to a Google Workspace group and have them log in

### User shows no agent
**Check:**
1. User is assigned to a chatbot group
2. Group has an agent assigned in `chatbot_group_agents` table
3. Agent is active in `chatbot_agents` table

### User shows no corpus access
**Fix:**
- Grant corpus access to the user's chatbot group
- Or add user to a corpus-specific Google Workspace group

### Google Groups Bridge not syncing
**Check:**
1. `GOOGLE_GROUPS_ENABLED=true` in `.env.local`
2. `GOOGLE_GROUPS_CUSTOMER_ID` is set correctly
3. Cloud Identity API is enabled in GCP
4. Service account has "Group Reader" role
5. Check backend logs for sync errors

---

## Database Tables Reference

### User → Group Assignment
```
chatbot_users (user exists)
    ↓
chatbot_user_groups (user_id → group_id)
    ↓
chatbot_groups (group definition)
```

### Group → Agent Assignment
```
chatbot_groups (group exists)
    ↓
chatbot_group_agents (group_id → agent_id)
    ↓
chatbot_agents (agent definition)
```

### Group → Corpus Access
```
chatbot_groups (group exists)
    ↓
chatbot_corpus_access (group_id → corpus_id + permission)
    ↓
corpora (corpus definition)
```

---

## Quick Reference Commands

### List all users
```bash
curl -s "http://localhost:8000/api/admin/chatbot/users" | python3 -m json.tool
```

### List all groups
```bash
curl -s "http://localhost:8000/api/admin/chatbot/groups" | python3 -m json.tool
```

### Assign user to group
```bash
curl -X POST "http://localhost:8000/api/admin/chatbot/users/{user_id}/groups/{group_id}"
```

### Grant corpus access
```bash
curl -X POST "http://localhost:8000/api/admin/chatbot/corpus-access" \
  -H "Content-Type: application/json" \
  -d '{"chatbot_group_id": {group_id}, "corpus_id": {corpus_id}, "permission": "query"}'
```

### View access matrix
```bash
curl -s "http://localhost:8000/api/admin/access-matrix" | python3 -m json.tool
```

---

**Date:** February 19, 2026  
**Status:** ✅ Verified and Working  
**Last Updated:** After successful robert@develom.com assignment
