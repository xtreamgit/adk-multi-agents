# Phase 2 Integration Guide

**Date:** December 31, 2025  
**Status:** Phase 2 Complete - API Routes Implemented

---

## 🎯 What Was Built in Phase 2

### **API Route Modules (5 modules)**

Created complete REST API with 40+ endpoints:

1. **Authentication Routes** (`auth.py`)
   - User registration
   - Login/logout
   - Token refresh
   - Current user info

2. **User Routes** (`users.py`)
   - Profile management
   - Preferences (theme, language, timezone)
   - Default agent selection
   - Group and role viewing

3. **Group Routes** (`groups.py`)
   - Group CRUD (admin)
   - Role CRUD (admin)
   - User-group management
   - Group-role assignments

4. **Agent Routes** (`agents.py`)
   - Agent listing and details
   - User agent access
   - Agent switching in sessions
   - Access management (admin)

5. **Corpus Routes** (`corpora.py`)
   - Corpus listing and details
   - Session corpus selection
   - Access management (admin)
   - Last session restoration

---

## 📋 Integration Steps

### Step 1: Update `server.py`

Add route registration to your existing `backend/src/api/server.py`:

```python
# At the top, add imports
from api.routes import (
    auth_router,
    users_router,
    groups_router,
    agents_router,
    corpora_router
)

# After app creation, register routers
# (After: app = FastAPI(...))

# Register new authentication and management routes
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(groups_router)
app.include_router(agents_router)
app.include_router(corpora_router)

print("✅ New API routes registered:")
print("  - /api/auth/* (Authentication)")
print("  - /api/users/* (User Management)")
print("  - /api/groups/* (Groups & Roles)")
print("  - /api/agents/* (Agent Management)")
print("  - /api/corpora/* (Corpus Management)")
```

### Step 2: Run Database Setup

```bash
cd backend

# 1. Run migrations
python src/database/migrations/run_migrations.py

# 2. Seed agents
python scripts/seed_agents.py

# 3. Seed default data (groups, roles, corpora)
python scripts/seed_default_group.py

# 4. Create admin user
python scripts/create_admin_user.py
```

### Step 3: Test the API

```bash
# Start the server
cd backend
python src/api/server.py

# Test registration
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "full_name": "Test User"
  }'

# Test login
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123"
  }'
```

---

## 🔐 Authentication Flow

### 1. User Registration
```
POST /api/auth/register
└─> Creates user account
    └─> Auto-creates user profile
        └─> Returns User object
```

### 2. User Login
```
POST /api/auth/login
└─> Validates credentials
    └─> Creates JWT token (30-day expiry)
        └─> Returns token + user info
```

### 3. Authenticated Requests
```
Request with Authorization: Bearer <token>
└─> JWT validation (auth_middleware)
    └─> User extraction
        └─> Permission check (if required)
            └─> Route handler
```

---

## 🎨 Frontend Integration Examples

### React/TypeScript Example

```typescript
// API Client
class ApiClient {
  private token: string | null = null;
  
  setToken(token: string) {
    this.token = token;
    localStorage.setItem('auth_token', token);
  }
  
  private async request(url: string, options: RequestInit = {}) {
    const headers = {
      'Content-Type': 'application/json',
      ...(this.token && { 'Authorization': `Bearer ${this.token}` }),
      ...options.headers,
    };
    
    const response = await fetch(`http://localhost:8080${url}`, {
      ...options,
      headers,
    });
    
    if (!response.ok) {
      throw new Error(await response.text());
    }
    
    return response.json();
  }
  
  // Authentication
  async login(username: string, password: string) {
    const data = await this.request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    });
    this.setToken(data.access_token);
    return data.user;
  }
  
  async register(userData: UserCreate) {
    return this.request('/api/auth/register', {
      method: 'POST',
      body: JSON.stringify(userData),
    });
  }
  
  // User Management
  async getMyProfile() {
    return this.request('/api/users/me');
  }
  
  async updatePreferences(preferences: UserProfileUpdate) {
    return this.request('/api/users/me/preferences', {
      method: 'PUT',
      body: JSON.stringify(preferences),
    });
  }
  
  // Agent Management
  async getMyAgents() {
    return this.request('/api/agents/me');
  }
  
  async switchAgent(sessionId: string, agentId: number) {
    return this.request(`/api/agents/sessions/${sessionId}/switch/${agentId}`, {
      method: 'POST',
    });
  }
  
  // Corpus Management
  async getMyCorpora() {
    return this.request('/api/corpora/');
  }
  
  async updateActiveCorpora(sessionId: string, corpusIds: number[]) {
    return this.request(`/api/corpora/sessions/${sessionId}/active`, {
      method: 'PUT',
      body: JSON.stringify({ corpus_ids: corpusIds }),
    });
  }
}

export const api = new ApiClient();
```

### React Components

```typescript
// Login Component
function LoginForm() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  
  const handleLogin = async () => {
    try {
      const user = await api.login(username, password);
      console.log('Logged in:', user);
      // Redirect to dashboard
    } catch (error) {
      console.error('Login failed:', error);
    }
  };
  
  return (
    <form onSubmit={handleLogin}>
      <input value={username} onChange={e => setUsername(e.target.value)} />
      <input type="password" value={password} onChange={e => setPassword(e.target.value)} />
      <button type="submit">Login</button>
    </form>
  );
}

// Agent Selector Component
function AgentSelector({ sessionId }: { sessionId: string }) {
  const [agents, setAgents] = useState([]);
  const [currentAgent, setCurrentAgent] = useState(null);
  
  useEffect(() => {
    api.getMyAgents().then(setAgents);
  }, []);
  
  const handleAgentSwitch = async (agentId: number) => {
    await api.switchAgent(sessionId, agentId);
    setCurrentAgent(agentId);
  };
  
  return (
    <select value={currentAgent} onChange={e => handleAgentSwitch(Number(e.target.value))}>
      {agents.map(agent => (
        <option key={agent.id} value={agent.id}>
          {agent.display_name}
        </option>
      ))}
    </select>
  );
}

// Corpus Selector Component
function CorpusSelector({ sessionId }: { sessionId: string }) {
  const [corpora, setCorpora] = useState([]);
  const [activeCorpora, setActiveCorpora] = useState<number[]>([]);
  
  useEffect(() => {
    api.getMyCorpora().then(setCorpora);
  }, []);
  
  const handleCorpusToggle = async (corpusId: number) => {
    const newActive = activeCorpora.includes(corpusId)
      ? activeCorpora.filter(id => id !== corpusId)
      : [...activeCorpora, corpusId];
    
    await api.updateActiveCorpora(sessionId, newActive);
    setActiveCorpora(newActive);
  };
  
  return (
    <div>
      {corpora.map(corpus => (
        <label key={corpus.id}>
          <input
            type="checkbox"
            checked={activeCorpora.includes(corpus.id)}
            onChange={() => handleCorpusToggle(corpus.id)}
          />
          {corpus.display_name}
        </label>
      ))}
    </div>
  );
}
```

---

## 🧪 Testing the Implementation

### Manual Testing

```bash
# 1. Create admin user
cd backend
python scripts/create_admin_user.py

# 2. Test login
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your_password"}' \
  | jq -r '.access_token')

echo "Token: $TOKEN"

# 3. Test user profile
curl -s http://localhost:8080/api/users/me \
  -H "Authorization: Bearer $TOKEN" | jq

# 4. Test agents
curl -s http://localhost:8080/api/agents/me \
  -H "Authorization: Bearer $TOKEN" | jq

# 5. Test corpora
curl -s http://localhost:8080/api/corpora/ \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Python Testing Script

```python
#!/usr/bin/env python3
import requests
import json

BASE_URL = "http://localhost:8080"

# 1. Register user
response = requests.post(f"{BASE_URL}/api/auth/register", json={
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "full_name": "Test User"
})
print("Register:", response.status_code, response.json())

# 2. Login
response = requests.post(f"{BASE_URL}/api/auth/login", json={
    "username": "testuser",
    "password": "password123"
})
data = response.json()
token = data['access_token']
print("Login:", response.status_code)
print("Token:", token[:20] + "...")

# 3. Get profile
headers = {"Authorization": f"Bearer {token}"}
response = requests.get(f"{BASE_URL}/api/users/me", headers=headers)
print("Profile:", response.status_code, response.json())

# 4. Get agents
response = requests.get(f"{BASE_URL}/api/agents/me", headers=headers)
print("Agents:", response.status_code, len(response.json()), "agents")

# 5. Get corpora
response = requests.get(f"{BASE_URL}/api/corpora/", headers=headers)
print("Corpora:", response.status_code, len(response.json()), "corpora")
```

---

## 📚 API Endpoint Summary

### Public Endpoints (No Auth Required)
- `POST /api/auth/register` - Register
- `POST /api/auth/login` - Login

### User Endpoints (Authenticated)
- `GET /api/auth/me` - Current user info
- `GET /api/users/me` - User profile
- `PUT /api/users/me` - Update profile
- `GET /api/users/me/preferences` - Get preferences
- `PUT /api/users/me/preferences` - Update preferences
- `GET /api/agents/me` - My agents
- `GET /api/corpora/` - My corpora

### Admin Endpoints (Permissions Required)
- `POST /api/groups/` - Create group (`manage:groups`)
- `POST /api/agents/` - Create agent (`manage:agents`)
- `POST /api/corpora/` - Create corpus (`create:corpus`)
- `PUT /api/agents/{id}/grant/{user_id}` - Grant access (`manage:agent_access`)
- `POST /api/corpora/{id}/grant` - Grant access (`manage:corpus_access`)

---

## 🔄 Migration from Old Endpoints

If you have existing endpoints in `server.py`, you can:

1. **Keep both**: New routes coexist with old ones
2. **Gradual migration**: Move functionality step-by-step
3. **Version the API**: Old at `/api/v1/`, new at `/api/v2/`

Example:
```python
# Old endpoint (keep for backwards compatibility)
@app.post("/register")
async def old_register(...):
    # Redirect to new endpoint
    return await register(...)

# New endpoint
app.include_router(auth_router)  # Includes /api/auth/register
```

---

## 🎓 Next Steps

1. **Update Frontend**
   - Implement login/register forms
   - Add agent selector component
   - Add corpus selection panel
   - Add user profile page

2. **Add Tests**
   - Unit tests for route handlers
   - Integration tests for API flows
   - End-to-end tests

3. **Deploy**
   - Update Cloud Build config
   - Add environment variables
   - Deploy to Cloud Run

4. **Monitor**
   - Add logging for API calls
   - Track authentication failures
   - Monitor permission denials

---

**Phase 2 Status:** ✅ Complete  
**Total Endpoints:** 40+  
**Routes Created:** 5 modules  
**Ready for:** Frontend Integration & Testing
