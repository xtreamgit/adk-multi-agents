# 🏗️ Feature Architecture: Authentication, Groups, Roles & Corpus Access

**Date:** December 31, 2025  
**Project:** ADK Multi-Agents  
**Status:** ✅ Architecture Approved - Implementation In Progress

---

## 📊 **Recommended Architecture Pattern**

### **Service-Layer Modules (Clean Architecture)**

```
backend/src/
├── api/
│   ├── server.py                    # Main FastAPI app (existing)
│   └── routes/                      # NEW: Organized route modules
│       ├── __init__.py
│       ├── auth.py                  # Authentication endpoints
│       ├── users.py                 # User profile management
│       ├── groups.py                # Group/role management
│       ├── agents.py                # Agent selection/switching
│       ├── corpora.py               # Corpus access management
│       └── chat.py                  # Chat endpoints (refactored)
├── services/                        # NEW: Business logic layer
│   ├── __init__.py
│   ├── auth_service.py              # Authentication & JWT logic
│   ├── user_service.py              # User CRUD & preferences
│   ├── group_service.py             # Group/role management
│   ├── agent_service.py             # Agent access control
│   ├── corpus_service.py            # Corpus access control
│   └── session_service.py           # Session management (enhanced)
├── models/                          # NEW: Data models & schemas
│   ├── __init__.py
│   ├── user.py                      # User, UserProfile models
│   ├── group.py                     # Group, Role models
│   ├── agent.py                     # AgentAccess models
│   ├── corpus.py                    # CorpusAccess models
│   └── session.py                   # SessionData models
├── database/                        # ENHANCED: Database layer
│   ├── __init__.py
│   ├── connection.py                # DB connection management
│   ├── repositories/                # Repository pattern
│   │   ├── user_repository.py
│   │   ├── group_repository.py
│   │   ├── agent_repository.py
│   │   └── corpus_repository.py
│   └── migrations/                  # Database migrations
│       ├── 001_initial_schema.sql
│       ├── 002_add_groups_roles.sql
│       └── 003_add_agents_corpora.sql
├── middleware/                      # NEW: Request processing
│   ├── __init__.py
│   ├── auth_middleware.py           # JWT validation
│   └── authorization_middleware.py  # Role-based access control
└── rag_agent/                       # EXISTING: Agent tools
    └── ... (current structure)
```

---

## 🗄️ **Database Schema Design**

### **Complete Entity-Relationship Model**

```sql
-- Core Users Table (existing, enhanced)
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    hashed_password TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    default_agent_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    FOREIGN KEY (default_agent_id) REFERENCES agents(id)
);

-- User Profiles (preferences & settings)
CREATE TABLE user_profiles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER UNIQUE NOT NULL,
    theme TEXT DEFAULT 'light',
    language TEXT DEFAULT 'en',
    timezone TEXT DEFAULT 'UTC',
    preferences JSON,  -- Flexible JSON for additional settings
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Groups (organizational units)
CREATE TABLE groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

-- Roles (access permissions)
CREATE TABLE roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    permissions JSON,  -- Store permissions as JSON
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User-Group Mapping (many-to-many)
CREATE TABLE user_groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    UNIQUE(user_id, group_id)
);

-- Group-Role Mapping (many-to-many)
CREATE TABLE group_roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    UNIQUE(group_id, role_id)
);

-- Agents (available agents in system)
CREATE TABLE agents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT,
    config_path TEXT NOT NULL,  -- e.g., 'agent1', 'develom'
    is_active BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User-Agent Access (which users can access which agents)
CREATE TABLE user_agent_access (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id INTEGER NOT NULL,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    UNIQUE(user_id, agent_id)
);

-- Corpora (RAG corpus definitions)
CREATE TABLE corpora (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT,
    gcs_bucket TEXT NOT NULL,
    vertex_corpus_id TEXT,  -- Vertex AI corpus ID
    is_active BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Group-Corpus Access (which groups can access which corpora)
CREATE TABLE group_corpus_access (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL,
    corpus_id INTEGER NOT NULL,
    permission TEXT DEFAULT 'read',  -- read, write, admin
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (corpus_id) REFERENCES corpora(id) ON DELETE CASCADE,
    UNIQUE(group_id, corpus_id)
);

-- User Sessions (enhanced for agent & corpus tracking)
CREATE TABLE user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    user_id INTEGER NOT NULL,
    active_agent_id INTEGER,
    active_corpora JSON,  -- Array of corpus IDs
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (active_agent_id) REFERENCES agents(id)
);

-- Session Corpus Selections (for restoration)
CREATE TABLE session_corpus_selections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    corpus_id INTEGER NOT NULL,
    last_selected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (corpus_id) REFERENCES corpora(id) ON DELETE CASCADE,
    UNIQUE(user_id, corpus_id)
);

-- Indexes for performance
CREATE INDEX idx_user_groups_user ON user_groups(user_id);
CREATE INDEX idx_user_groups_group ON user_groups(group_id);
CREATE INDEX idx_group_roles_group ON group_roles(group_id);
CREATE INDEX idx_user_agent_access_user ON user_agent_access(user_id);
CREATE INDEX idx_group_corpus_access_group ON group_corpus_access(group_id);
CREATE INDEX idx_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_sessions_active ON user_sessions(is_active);
```

---

## 🔧 **Implementation Strategy**

### **Phase 1: Foundation (Week 1)**

#### 1. Database Layer
- Migrate from SQLite to **Cloud SQL** (PostgreSQL) for production
  - Reason: Better support for JSON, concurrent access, Cloud Run integration
- Create migration scripts
- Implement Repository Pattern for data access

#### 2. Service Layer
```python
# backend/src/services/auth_service.py
class AuthService:
    """Handles authentication, JWT, password management"""
    def authenticate_user(username: str, password: str) -> Optional[User]
    def create_access_token(user: User) -> str
    def verify_token(token: str) -> Optional[User]
    def refresh_token(token: str) -> str

# backend/src/services/user_service.py
class UserService:
    """User CRUD and profile management"""
    def get_user_by_id(user_id: int) -> Optional[User]
    def update_profile(user_id: int, profile: UserProfile) -> User
    def set_default_agent(user_id: int, agent_id: int) -> bool
    def get_user_preferences(user_id: int) -> Dict
```

### **Phase 2: Authorization & Groups (Week 2)**

#### 3. Group & Role Management
```python
# backend/src/services/group_service.py
class GroupService:
    """Group and role management"""
    def get_user_groups(user_id: int) -> List[Group]
    def get_user_roles(user_id: int) -> List[Role]
    def check_permission(user_id: int, permission: str) -> bool
    def assign_user_to_group(user_id: int, group_id: int) -> bool

# backend/src/middleware/authorization_middleware.py
class AuthorizationMiddleware:
    """RBAC enforcement"""
    async def verify_access(user: User, resource: str, action: str) -> bool
```

### **Phase 3: Agent & Corpus Access (Week 3)**

#### 4. Agent Management
```python
# backend/src/services/agent_service.py
class AgentService:
    """Agent access control and switching"""
    def get_user_agents(user_id: int) -> List[Agent]
    def get_default_agent(user_id: int) -> Optional[Agent]
    def switch_agent(session_id: str, agent_id: int) -> bool
    def validate_agent_access(user_id: int, agent_id: int) -> bool
```

#### 5. Corpus Management
```python
# backend/src/services/corpus_service.py
class CorpusService:
    """Corpus access control"""
    def get_user_corpora(user_id: int) -> List[Corpus]
    def get_session_corpora(session_id: str) -> List[Corpus]
    def update_session_corpora(session_id: str, corpus_ids: List[int]) -> bool
    def restore_last_corpora(user_id: int) -> List[Corpus]
    def validate_corpus_access(user_id: int, corpus_id: int) -> bool
```

---

## 🎯 **Why This Modular Approach?**

### **✅ Advantages**

1. **Separation of Concerns**
   - Each service has a single responsibility
   - Easy to test in isolation
   - Reduces code coupling

2. **Scalability**
   - Services can be extracted to microservices later
   - Easy to add new features without touching existing code

3. **Maintainability**
   - Clear boundaries between layers
   - Easy to locate and fix bugs
   - New developers can understand quickly

4. **Reusability**
   - Services can be used across different API endpoints
   - Business logic is centralized

5. **Testing**
   - Unit test services independently
   - Mock dependencies easily
   - Integration tests are cleaner

6. **Security**
   - Authorization logic is centralized
   - Easier to audit and enforce policies

---

## 🚀 **API Endpoints Structure**

```python
# backend/src/api/routes/auth.py
POST   /api/auth/register        # Register new user
POST   /api/auth/login           # Login and get JWT
POST   /api/auth/refresh         # Refresh JWT token
POST   /api/auth/logout          # Logout and invalidate session

# backend/src/api/routes/users.py
GET    /api/users/me             # Get current user profile
PUT    /api/users/me             # Update user profile
GET    /api/users/me/preferences # Get user preferences
PUT    /api/users/me/preferences # Update preferences
PUT    /api/users/me/default-agent/{agent_id}  # Set default agent

# backend/src/api/routes/groups.py
GET    /api/groups/me            # Get my groups
GET    /api/groups/{id}          # Get group details (admin)
POST   /api/groups               # Create group (admin)
PUT    /api/groups/{id}/users    # Add user to group (admin)

# backend/src/api/routes/agents.py
GET    /api/agents               # Get all available agents
GET    /api/agents/me            # Get agents I have access to
GET    /api/agents/default       # Get my default agent
POST   /api/sessions/{id}/agent  # Switch active agent in session

# backend/src/api/routes/corpora.py
GET    /api/corpora              # Get all corpora I can access
GET    /api/corpora/active       # Get active corpora for session
PUT    /api/corpora/active       # Update active corpora
POST   /api/corpora/{id}/documents  # Add document to corpus

# backend/src/api/routes/chat.py
POST   /api/chat                 # Send message (uses active agent & corpora)
GET    /api/chat/history         # Get chat history
```

---

## 📦 **Migration from Current System**

### **Backwards Compatibility Strategy**

1. **Keep existing endpoints working** - Don't break current frontend
2. **Add new endpoints alongside** - `/api/v2/...` for new features
3. **Gradual migration** - Move users to new system incrementally

### **Data Migration Steps**

```bash
# Step 1: Create new tables (non-destructive)
python backend/src/database/migrations/run_migrations.py

# Step 2: Seed initial data
python backend/scripts/seed_agents.py      # Create agent records
python backend/scripts/seed_default_group.py  # Create default group

# Step 3: Migrate existing users
python backend/scripts/migrate_users.py    # Add to default group

# Step 4: Test in parallel
# Old system continues running while new system is tested
```

---

## 🔐 **Security Considerations**

### **Authorization Flow**

```
Request → JWT Middleware → Extract User
       → Authorization Middleware → Check Permissions
       → Service Layer → Validate Resource Access
       → Database → Execute Query
```

### **Permission Model**

```python
# Example permissions
PERMISSIONS = {
    "user": ["read:own_profile", "read:own_corpora", "chat:own_agents"],
    "group_admin": ["manage:group_users", "view:group_corpora"],
    "corpus_admin": ["create:corpus", "delete:corpus", "manage:corpus_access"],
    "system_admin": ["*"]  # All permissions
}
```

---

## 📋 **Feature Requirements Summary**

### **Authentication & Authorization**
- [x] Users authenticate with username/password
- [x] JWT-based session management
- [ ] Users must authorize access to resources
- [ ] Role-based access control (RBAC)

### **User Profile & Preferences**
- [ ] Users have profile settings (theme, language, timezone)
- [ ] Users can select default agent
- [ ] User preferences persist across sessions

### **Groups & Roles**
- [ ] Users belong to one or more groups
- [ ] Groups have roles that define permissions
- [ ] Group membership determines resource access

### **Agent Management**
- [ ] Users have access to one or more agents
- [ ] Users can switch between agents in session
- [ ] Users cannot chat with multiple agents simultaneously
- [ ] Default agent is "default-agent"
- [ ] Agent selection persists until changed

### **Corpus Access Control**
- [ ] Users access one or more corpora per session
- [ ] Corpus access determined by group and role
- [ ] Each corpus stored in separate GCS bucket
- [ ] Session restores last active corpora on login
- [ ] Agents use grounded data from user's accessible corpora

---

## 🎨 **Frontend Considerations**

### **UI Components Needed**

1. **Agent Selector Dropdown**
   - Shows available agents for user
   - Highlights current active agent
   - Switch agent triggers session update

2. **Corpus Selection Panel**
   - Multi-select for available corpora
   - Shows which corpora are active
   - Persists selection across sessions

3. **User Profile Page**
   - Edit profile information
   - Set preferences (theme, language)
   - Select default agent
   - View group memberships

4. **Admin Panel** (for admins)
   - Manage users and groups
   - Assign roles and permissions
   - Manage corpus access

---

## 📊 **Data Flow Diagrams**

### **User Login Flow**
```
1. User enters credentials
2. Backend validates credentials
3. Backend checks user groups & roles
4. Backend loads user's allowed agents & corpora
5. Backend creates session with default agent & last corpora
6. Backend returns JWT + user profile + available resources
7. Frontend stores JWT and initializes UI
```

### **Agent Switch Flow**
```
1. User selects different agent from dropdown
2. Frontend sends POST /api/sessions/{id}/agent
3. Backend validates user has access to agent
4. Backend updates session active_agent_id
5. Backend returns updated session info
6. Frontend updates UI to reflect new agent
7. Next chat message uses new agent
```

### **Corpus Selection Flow**
```
1. User selects/deselects corpora in UI
2. Frontend sends PUT /api/corpora/active
3. Backend validates user has access to each corpus
4. Backend updates session active_corpora
5. Backend updates session_corpus_selections for restoration
6. Backend returns updated session info
7. Next chat query uses selected corpora
```

---

**Document Version:** 1.0  
**Last Updated:** December 31, 2025  
**Status:** ✅ Architecture Approved - Implementation In Progress
