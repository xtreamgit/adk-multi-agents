# Quick Start Guide - New API Features

**Date:** December 31, 2025  
**Status:** Ready for Testing

---

## ✅ Integration Complete

The new API routes have been successfully integrated into `backend/src/api/server.py`. The server will automatically detect and load the new routes if the database has been set up.

---

## 🚀 Setup Steps

### 1. Run Database Migrations

```bash
cd backend

# Run migrations (creates all 13 tables)
python src/database/migrations/run_migrations.py
```

**Expected output:**
```
Starting database migrations
Database: /app/data/users.db
Found 3 migration files
Running migration: 001_initial_schema.sql
✅ Migration 001_initial_schema.sql completed successfully
Running migration: 002_add_groups_roles.sql
✅ Migration 002_add_groups_roles.sql completed successfully
Running migration: 003_add_agents_corpora.sql
✅ Migration 003_add_agents_corpora.sql completed successfully

Migration Summary:
  Applied: 3
  Skipped: 0
  Total: 3
```

---

### 2. Seed Initial Data

```bash
# Create agents (6 agents)
python scripts/seed_agents.py

# Create groups, roles, and corpora
python scripts/seed_default_group.py

# Create admin user (interactive)
python scripts/create_admin_user.py
```

**For the admin user, enter:**
- Username: `admin`
- Email: `admin@develom.com`
- Password: (choose a secure password)

---

### 3. Start the Server

```bash
python src/api/server.py
```

**Expected startup output:**
```
✅ New API routes loaded successfully
🔧 Loading agent for account: develom
📋 Config resolved: PROJECT_ID=adk-rag-ma, LOCATION=us-west1
✅ Loaded agent: RAG Agent with 7 tools
CORS Configuration:
  FRONTEND_URL env var: 
  Allowed origins: ['http://localhost:3000', 'http://127.0.0.1:3000']

======================================================================
🚀 New API Routes Registered:
  ✅ /api/auth/*        - Authentication (register, login, refresh)
  ✅ /api/users/*       - User Management (profile, preferences)
  ✅ /api/groups/*      - Groups & Roles (admin)
  ✅ /api/agents/*      - Agent Management (switching, access)
  ✅ /api/corpora/*     - Corpus Management (access, selection)
======================================================================

INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8080
```

---

## 🧪 Test the API

### Test 1: Health Check

```bash
curl http://localhost:8080/api/health | jq
```

### Test 2: Register User

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "full_name": "Test User"
  }' | jq
```

**Expected response:**
```json
{
  "id": 1,
  "username": "testuser",
  "email": "test@example.com",
  "full_name": "Test User",
  "is_active": true,
  "default_agent_id": null,
  "created_at": "2025-12-31T...",
  "updated_at": "2025-12-31T...",
  "last_login": null
}
```

### Test 3: Login

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123"
  }' | jq
```

**Expected response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "username": "testuser",
    ...
  }
}
```

**Save the token:**
```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}' \
  | jq -r '.access_token')

echo "Token: $TOKEN"
```

### Test 4: Get User Profile

```bash
curl http://localhost:8080/api/users/me \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Test 5: Get Available Agents

```bash
curl http://localhost:8080/api/agents/me \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Note:** User won't have agent access until granted by admin

### Test 6: Admin - Grant Agent Access

First, login as admin:

```bash
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your_admin_password"}' \
  | jq -r '.access_token')

# Grant access to agent (agent_id=1, user_id=2)
curl -X PUT http://localhost:8080/api/agents/1/grant/2 \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq
```

### Test 7: Get Corpora

```bash
curl http://localhost:8080/api/corpora/ \
  -H "Authorization: Bearer $TOKEN" | jq
```

---

## 📖 Interactive API Documentation

Once the server is running, access:

- **Swagger UI:** http://localhost:8080/docs
- **ReDoc:** http://localhost:8080/redoc

These provide:
- Complete API documentation
- Interactive testing interface
- Request/response schemas
- Try out endpoints directly in browser

---

## 🔍 Verify Integration

### Check Routes Loaded

Look for this in the startup output:
```
✅ New API routes loaded successfully

🚀 New API Routes Registered:
  ✅ /api/auth/*        - Authentication (register, login, refresh)
  ✅ /api/users/*       - User Management (profile, preferences)
  ✅ /api/groups/*      - Groups & Roles (admin)
  ✅ /api/agents/*      - Agent Management (switching, access)
  ✅ /api/corpora/*     - Corpus Management (access, selection)
```

### If Routes Don't Load

You'll see:
```
⚠️  New API routes not available: No module named 'api.routes'
   Run migrations and setup first: python src/database/migrations/run_migrations.py
   
⚠️  Using legacy authentication endpoints
   To enable new features, run: python src/database/migrations/run_migrations.py
```

**Solution:** Run the setup steps above (migrations and seeding)

---

## 🎯 Common Tasks

### Create a Regular User

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice",
    "email": "alice@example.com",
    "password": "securepass",
    "full_name": "Alice Johnson"
  }'
```

### Grant User Access to Agent

```bash
# As admin, grant user (id=2) access to default-agent (id=1)
curl -X PUT http://localhost:8080/api/agents/1/grant/2 \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### Set User's Default Agent

```bash
# As user, set default agent
curl -X PUT http://localhost:8080/api/users/me/default-agent/1 \
  -H "Authorization: Bearer $TOKEN"
```

### Update User Preferences

```bash
curl -X PUT http://localhost:8080/api/users/me/preferences \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "theme": "dark",
    "language": "en",
    "timezone": "America/New_York",
    "preferences": {
      "notifications": true,
      "auto_save": true
    }
  }'
```

### Add User to Group (Admin)

```bash
# Add user (id=2) to default-users group (id=1)
curl -X PUT http://localhost:8080/api/groups/1/users/2 \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## 🐛 Troubleshooting

### Issue: "New API routes not available"

**Cause:** Database migrations haven't been run

**Solution:**
```bash
cd backend
python src/database/migrations/run_migrations.py
python scripts/seed_agents.py
python scripts/seed_default_group.py
```

### Issue: "403 Forbidden" on admin endpoints

**Cause:** User doesn't have required permissions

**Solution:**
- Ensure user is added to `admin-users` group
- Admin users need `system_admin` role
- Check with: `curl http://localhost:8080/api/users/me/roles -H "Authorization: Bearer $TOKEN"`

### Issue: "User has no agents"

**Cause:** User hasn't been granted access to any agents

**Solution:**
```bash
# As admin, grant access
curl -X PUT http://localhost:8080/api/agents/1/grant/{user_id} \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### Issue: Database file not found

**Cause:** DATABASE_PATH environment variable not set

**Solution:**
```bash
# Set environment variable
export DATABASE_PATH=/app/data/users.db

# Or run with variable
DATABASE_PATH=/app/data/users.db python src/api/server.py
```

---

## 📊 Database Inspection

To inspect the database:

```bash
# Connect to database
sqlite3 /app/data/users.db

# List tables
.tables

# View users
SELECT * FROM users;

# View agents
SELECT * FROM agents;

# View user-agent access
SELECT u.username, a.name 
FROM user_agent_access uaa
JOIN users u ON uaa.user_id = u.id
JOIN agents a ON uaa.agent_id = a.id;

# Exit
.quit
```

---

## ✅ Success Criteria

You've successfully integrated the new features if:

- ✅ Server starts without errors
- ✅ New routes appear in startup message
- ✅ Can register and login users
- ✅ Can access `/docs` for API documentation
- ✅ Admin can manage users, groups, and access
- ✅ Users can switch agents and select corpora
- ✅ Existing chat functionality still works

---

## 🎉 Next Steps

1. **Test all endpoints** using Swagger UI at http://localhost:8080/docs
2. **Create test users** with different permission levels
3. **Test agent switching** in chat sessions
4. **Test corpus selection** for different users
5. **Build frontend components** for the new features

---

**Need Help?**

- Check logs: Server prints detailed startup information
- Use Swagger UI: http://localhost:8080/docs for interactive testing
- Review documentation: See PHASE2-INTEGRATION-GUIDE.md for details
