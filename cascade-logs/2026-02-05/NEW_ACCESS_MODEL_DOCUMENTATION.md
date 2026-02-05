# New Access Model Documentation

**Date:** February 5, 2026  
**Version:** 2.0  
**Status:** ✅ Implemented and Tested

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Access Model Comparison](#access-model-comparison)
3. [New Access Model Architecture](#new-access-model-architecture)
4. [Group-to-Agent Mapping](#group-to-agent-mapping)
5. [Agent Type Definitions](#agent-type-definitions)
6. [Implementation Changes](#implementation-changes)
7. [Database Schema](#database-schema)
8. [API Endpoints](#api-endpoints)
9. [Frontend Components](#frontend-components)
10. [Testing & Verification](#testing--verification)
11. [Migration Guide](#migration-guide)
12. [Future Considerations](#future-considerations)

---

## Executive Summary

The application has transitioned from a complex **role-based access control (RBAC)** model to a simplified **group-to-agent access model**. This change eliminates the intermediate permissions layer and provides direct, intuitive access control.

### Key Benefits

✅ **Simplified Administration** - Direct group-to-agent mapping eliminates confusion  
✅ **Clearer User Experience** - Users understand "I'm in the contributor group" vs "I have these 12 permissions"  
✅ **Reduced Complexity** - No need to manage individual permissions  
✅ **Hierarchical Tool Access** - Agent types inherit tools from lower levels  
✅ **Easier Onboarding** - New users can be added to a group and immediately have appropriate access

---

## Access Model Comparison

### Old Model (RBAC)

```
Users → Groups → Roles → Permissions → Tools
```

**Characteristics:**
- Users belong to groups
- Groups are assigned roles
- Roles have collections of permissions
- Permissions grant access to specific tools
- Complex many-to-many relationships at multiple levels
- Difficult to understand what access a user actually has

**Problems:**
- Too many layers of abstraction
- Permissions management was tedious
- Hard to audit user access
- Confusing for administrators
- Required managing permissions separately from roles

---

### New Model (Group-to-Agent)

```
Users → Groups → Agents → Tools
```

**Characteristics:**
- Users belong to groups
- Groups are assigned ONE agent type
- Agent types have predefined tool sets
- Tools are inherited hierarchically
- Simple, direct relationship

**Advantages:**
- Only 2 layers: group assignment and agent type
- Clear, predictable access patterns
- Easy to understand and audit
- Agent types are standardized
- No permission management needed

---

## New Access Model Architecture

### Conceptual Flow

```
┌─────────────┐
│   User      │
│  (alice)    │
└──────┬──────┘
       │ belongs to
       ▼
┌─────────────────────┐
│   Group             │
│ (Test Contributors) │
└──────┬──────────────┘
       │ assigned
       ▼
┌─────────────────────┐
│   Agent Type        │
│  (contributor)      │
└──────┬──────────────┘
       │ provides
       ▼
┌─────────────────────┐
│   Tools             │
│ • rag_query         │
│ • list_corpora      │
│ • get_corpus_info   │
│ • browse_documents  │
│ • add_data          │
└─────────────────────┘
```

### Key Principles

1. **One Agent Per Group** - Each group is assigned exactly one agent type
2. **Hierarchical Inheritance** - Higher-level agents inherit all tools from lower levels
3. **Predefined Agent Types** - Agent types are standardized and cannot be customized
4. **Direct Tool Access** - Users get tools directly from their group's agent type
5. **No Permission Management** - Permissions are implicit in the agent type

---

## Group-to-Agent Mapping

### Standard Mapping

| Group Name | Agent Type | Tool Count | Purpose |
|------------|------------|------------|---------|
| `viewer-group` | `viewer-agent` | 4 | Read-only access for general users |
| `contributor-group` | `contributor-agent` | 5 | Users who can add content |
| `content-manager-group` | `content-manager-agent` | 6 | Manage documents within corpora |
| `admin-group` | `admin-agent` | 8 | Full corpus lifecycle management |

### Naming Convention

**Pattern:** `{agent-type}-group` → `{agent-type}-agent`

**Examples:**
- viewer-group → viewer-agent
- contributor-group → contributor-agent
- content-manager-group → content-manager-agent
- admin-group → admin-agent

**Note:** The "admin-agent" is equivalent to "corpus-manager" in the hierarchy system.

---

## Agent Type Definitions

### 1. Viewer Agent 👁️

**Purpose:** Read-only access for general users

**Tools (4):**
- `rag_query` - Query documents using RAG
- `list_corpora` - List available corpora
- `get_corpus_info` - Get corpus details
- `browse_documents` - Browse document links

**Use Cases:**
- General users who need to query information
- Read-only access to knowledge base
- No ability to modify data

**Color Code:** Blue (#2563eb)

---

### 2. Contributor Agent ➕

**Purpose:** Users who can add content

**Tools (5):**
- **All Viewer Agent tools** (inherited)
- `add_data` - Add documents to corpora

**Use Cases:**
- Content creators who add documents
- Users who upload files to knowledge base
- Cannot delete or modify existing content

**Color Code:** Emerald (#059669)

---

### 3. Content Manager Agent 📝

**Purpose:** Manage documents within existing corpora

**Tools (6):**
- **All Contributor Agent tools** (inherited)
- `delete_document` - Delete documents from corpora

**Use Cases:**
- Content moderators
- Document lifecycle management
- Cannot create or delete entire corpora

**Color Code:** Amber (#d97706)

---

### 4. Corpus Manager Agent (Admin) 🔧

**Purpose:** Full corpus lifecycle management

**Tools (8):**
- **All Content Manager Agent tools** (inherited)
- `create_corpus` - Create new corpora
- `delete_corpus` - Delete entire corpora

**Use Cases:**
- System administrators
- Full control over knowledge base structure
- Can perform all operations

**Color Code:** Purple (#9333ea)

---

## Implementation Changes

### UI Changes

#### 1. Admin Sidebar Navigation

**Removed:**
- ❌ "Permissions" submenu item

**Kept:**
- ✅ Chatbot Users
- ✅ Chatbot Groups
- ✅ Agents
- ✅ Corpora Access
- ✅ Agent Access

**Rationale:** Permissions are now implicit in agent types, no need for separate management.

---

#### 2. Agents Page (`/admin/agents`)

**Before:**
```
| Name | Description | Permissions | Actions |
```

**After:**
```
| Agent | Description | Actions |
```

**Changes:**
- Column header "Name" → "Agent"
- Removed "Permissions" column
- Removed "Permissions" button from Actions
- Updated page title: "Agent List" → "Agents"
- Updated subtitle: "Create custom agents" → "Manage agent types and their tool access"

**Rationale:** Agents have predefined tool sets, no need to display permissions in table.

---

#### 3. Chatbot Groups Page (`/admin/chatbot-groups`)

**Before:**
```
| Name | Description | Users | Roles | Actions |
```

**After:**
```
| Name | Description | Users | Agent | Actions |
```

**Changes:**
- Column header "Roles" → "Agent"
- Action button "Roles" → "Agent"
- Dialog title "Roles: {name}" → "Agent Assignment: {name}"
- Dialog section "Assigned Roles" → "Assigned Agent"
- Dialog section "Available Roles" → "Available Agents"
- Page subtitle: "their roles" → "their agent assignments"

**Rationale:** Groups are assigned agents, not roles. Terminology should reflect this.

---

### Code Changes

#### Frontend Files Modified

1. **`frontend/src/app/admin/layout.tsx`**
   - Removed Permissions menu item
   - Simplified Chatbot Access submenu

2. **`frontend/src/app/admin/agents/page.tsx`**
   - Removed Permissions column
   - Renamed "Roles" to "Agent"
   - Updated page titles and descriptions

3. **`frontend/src/app/admin/chatbot-groups/page.tsx`**
   - Renamed interface `ChatbotRole` → `ChatbotAgent`
   - Updated all UI text from "roles" to "agents"
   - Changed dialog state `showRoleDialog` → `showAgentDialog`

#### Backend Files (No Changes Required)

**Important:** Backend API endpoints and database tables still use "roles" terminology internally. This is intentional and maintains backward compatibility.

**API Endpoints (unchanged):**
- `/api/admin/chatbot/roles` - Still works
- `/api/admin/chatbot/groups/{id}/roles` - Still works
- `/api/admin/chatbot/permissions` - Still works (for internal use)

**Database Tables (unchanged):**
- `chatbot_agent_types` (formerly chatbot_roles)
- `chatbot_tools` (formerly chatbot_permissions)
- `chatbot_group_agent_types` (formerly chatbot_group_roles)

---

## Database Schema

### Core Tables

#### chatbot_users
```sql
CREATE TABLE chatbot_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    hashed_password VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    notes TEXT
);
```

#### chatbot_groups
```sql
CREATE TABLE chatbot_groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id)
);
```

#### chatbot_agent_types
```sql
CREATE TABLE chatbot_agent_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id)
);
```

#### chatbot_user_groups (Many-to-Many)
```sql
CREATE TABLE chatbot_user_groups (
    id SERIAL PRIMARY KEY,
    chatbot_user_id INTEGER NOT NULL REFERENCES chatbot_users(id) ON DELETE CASCADE,
    chatbot_group_id INTEGER NOT NULL REFERENCES chatbot_groups(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(chatbot_user_id, chatbot_group_id)
);
```

#### chatbot_group_agent_types (Many-to-Many)
```sql
CREATE TABLE chatbot_group_agent_types (
    id SERIAL PRIMARY KEY,
    chatbot_group_id INTEGER NOT NULL REFERENCES chatbot_groups(id) ON DELETE CASCADE,
    chatbot_agent_type_id INTEGER NOT NULL REFERENCES chatbot_agent_types(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(chatbot_group_id, chatbot_agent_type_id)
);
```

### Relationship Diagram

```
chatbot_users
    ↓ (many-to-many via chatbot_user_groups)
chatbot_groups
    ↓ (many-to-many via chatbot_group_agent_types)
chatbot_agent_types
    ↓ (defines tool access)
Tools (predefined in code)
```

---

## API Endpoints

### Agent Type Hierarchy

#### GET /api/admin/chatbot/agent-type-hierarchy

**Description:** Returns complete agent type hierarchy with tool definitions

**Response:**
```json
[
  {
    "name": "viewer",
    "display_name": "Viewer Agent",
    "description": "Read-only access for general users",
    "tools": ["rag_query", "list_corpora", "get_corpus_info", "browse_documents"],
    "tool_count": 4,
    "incremental_tools": ["rag_query", "list_corpora", "get_corpus_info", "browse_documents"],
    "color": "blue",
    "use_cases": ["General users querying information", "Read-only knowledge base access"]
  },
  {
    "name": "contributor",
    "display_name": "Contributor Agent",
    "description": "Users who can add content",
    "tools": ["rag_query", "list_corpora", "get_corpus_info", "browse_documents", "add_data"],
    "tool_count": 5,
    "incremental_tools": ["add_data"],
    "color": "emerald",
    "use_cases": ["Content creators", "Document uploaders"]
  }
  // ... more agent types
]
```

---

#### GET /api/admin/chatbot/agent-type-tools/{agent_type}

**Description:** Returns all tools for a specific agent type

**Parameters:**
- `agent_type` - One of: viewer, contributor, content-manager, corpus-manager

**Response:**
```json
{
  "agent_type": "contributor",
  "tools": ["rag_query", "list_corpora", "get_corpus_info", "browse_documents", "add_data"],
  "tool_count": 5
}
```

**Error Response (400):**
```json
{
  "detail": "Invalid agent type: invalid-type. Must be one of: viewer, contributor, content-manager, corpus-manager"
}
```

---

#### GET /api/admin/chatbot/my-agent-type

**Description:** Returns current user's agent type and allowed tools

**Authentication:** Required (Bearer token or IAP)

**Response (with agent type):**
```json
{
  "agent_type": "contributor",
  "allowed_tools": ["rag_query", "list_corpora", "get_corpus_info", "browse_documents", "add_data"],
  "tool_count": 5
}
```

**Response (no agent type):**
```json
{
  "agent_type": null,
  "allowed_tools": [],
  "tool_count": 0
}
```

---

### Group Management

#### GET /api/admin/chatbot/groups

**Description:** List all chatbot groups with their assigned agents

**Response:**
```json
[
  {
    "id": 26,
    "name": "Test Contributors",
    "description": "Test group for contributor agent type",
    "is_active": true,
    "created_at": "2026-02-05T19:30:00Z",
    "user_count": 1,
    "roles": [
      {
        "id": 2,
        "name": "contributor",
        "description": "Users who can add content"
      }
    ]
  }
]
```

---

#### POST /api/admin/chatbot/groups/{group_id}/roles/{role_id}

**Description:** Assign an agent type to a group

**Note:** Despite the endpoint name using "roles", this assigns an agent type to the group.

---

#### DELETE /api/admin/chatbot/groups/{group_id}/roles/{role_id}

**Description:** Remove an agent type from a group

---

## Frontend Components

### Permission Indicator Banner

**Location:** `/admin/agents` page

**Purpose:** Shows user's current agent type and available tools

**Features:**
- Color-coded badge matching agent type
- Displays tool count
- Lists first 6 tools with "+N more" indicator
- Responsive design

**Code:**
```tsx
{!permLoading && userPermissions && (
  <div className={`mb-6 p-4 rounded-lg border-2 ${
    userPermissions.agentType === 'corpus-manager' ? 'bg-purple-50 border-purple-200' :
    userPermissions.agentType === 'content-manager' ? 'bg-amber-50 border-amber-200' :
    userPermissions.agentType === 'contributor' ? 'bg-emerald-50 border-emerald-200' :
    'bg-blue-50 border-blue-200'
  }`}>
    {/* Banner content */}
  </div>
)}
```

---

### Agent Type Definitions Cards

**Location:** `/admin/agents` page (below table)

**Purpose:** Visual reference for all agent types and their tools

**Features:**
- Color-coded gradient backgrounds
- Tool lists with inheritance indicators
- Use case descriptions
- Rationale explanations

---

### useAgentPermissions Hook

**Location:** `frontend/src/hooks/useAgentPermissions.ts`

**Purpose:** React hook for checking user permissions

**Usage:**
```tsx
import { useAgentPermissions } from '@/hooks/useAgentPermissions';

function MyComponent() {
  const { 
    permissions, 
    canUseTool, 
    isContributor,
    loading 
  } = useAgentPermissions();

  if (loading) return <div>Loading...</div>;

  return (
    <div>
      {canUseTool('add_data') && (
        <button>Add Document</button>
      )}
      
      {isContributor() && (
        <div>Contributor features</div>
      )}
    </div>
  );
}
```

**Available Functions:**
- `canUseTool(toolName)` - Check if user can use specific tool
- `hasAgentTypeLevel(type)` - Check if user has minimum agent type level
- `isViewer()` - Check if user is viewer or higher
- `isContributor()` - Check if user is contributor or higher
- `isContentManager()` - Check if user is content manager or higher
- `isCorpusManager()` - Check if user is corpus manager
- `refetch()` - Refresh permissions from server

---

## Testing & Verification

### Test Setup

**Test User:** alice  
**Password:** alice123  
**Group:** Test Contributors  
**Agent Type:** contributor  
**Tools:** 5 (rag_query, list_corpora, get_corpus_info, browse_documents, add_data)

### Setup Script

**File:** `backend/setup_test_data_docker.sh`

**Usage:**
```bash
./backend/setup_test_data_docker.sh
```

**What it does:**
1. Creates chatbot user for alice
2. Creates "Test Contributors" group
3. Creates all 4 agent types
4. Assigns alice to Test Contributors group
5. Assigns contributor agent type to the group
6. Verifies the setup

---

### Test Scenarios

#### Scenario 1: Login and View Permissions

1. Navigate to http://localhost:3000
2. Login as alice/alice123
3. Go to `/admin/agents`
4. **Expected:** Permission indicator banner shows:
   - Agent Type: Contributor (emerald badge)
   - Tool Count: 5 tools
   - Tools: add_data, browse_documents, get_corpus_info, list_corpora, rag_query

---

#### Scenario 2: View Agent Definitions

1. Scroll down on `/admin/agents` page
2. **Expected:** See 4 agent type cards:
   - Viewer (blue)
   - Contributor (emerald)
   - Content Manager (amber)
   - Corpus Manager (purple)

---

#### Scenario 3: View Group Assignment

1. Navigate to `/admin/chatbot-groups`
2. Find "Test Contributors" group
3. **Expected:** 
   - Agent column shows "contributor"
   - Click "Agent" button to see assignment dialog

---

#### Scenario 4: API Endpoint Test

**Test Script:** `backend/test_agent_hierarchy.py`

**Run:**
```bash
python backend/test_agent_hierarchy.py
```

**Expected Results:**
- ✅ GET /api/admin/chatbot/agent-type-hierarchy (200)
- ✅ GET /api/admin/chatbot/agent-type-tools/viewer (200)
- ✅ GET /api/admin/chatbot/agent-type-tools/contributor (200)
- ✅ GET /api/admin/chatbot/agent-type-tools/content-manager (200)
- ✅ GET /api/admin/chatbot/agent-type-tools/corpus-manager (200)
- ✅ GET /api/admin/chatbot/agent-type-tools/invalid-type (400)
- ✅ GET /api/admin/chatbot/my-agent-type (200) - Returns contributor

---

## Migration Guide

### For Administrators

#### Step 1: Understand the New Model

Read this documentation thoroughly, especially:
- [Access Model Comparison](#access-model-comparison)
- [Agent Type Definitions](#agent-type-definitions)
- [Group-to-Agent Mapping](#group-to-agent-mapping)

---

#### Step 2: Review Existing Groups

1. Navigate to `/admin/chatbot-groups`
2. Review all existing groups
3. Note which groups have which roles assigned
4. Plan which agent type each group should have

---

#### Step 3: Assign Agent Types to Groups

For each group:

1. Click the "Agent" button
2. Remove any old role assignments (if multiple)
3. Assign the appropriate agent type:
   - Read-only users → viewer
   - Content creators → contributor
   - Document managers → content-manager
   - Administrators → corpus-manager (admin)

**Best Practice:** Each group should have exactly ONE agent type.

---

#### Step 4: Verify User Access

1. Test with a user from each group
2. Verify they can access appropriate tools
3. Check permission indicator shows correct agent type
4. Test tool functionality

---

#### Step 5: Clean Up Old Permissions (Optional)

The old permissions system still exists in the database but is no longer used in the UI. You can:

- Leave it as-is (no harm, just unused)
- Or clean up via database queries (advanced users only)

**Note:** Do NOT delete the `chatbot_agent_types` or `chatbot_tools` tables - these are still used internally.

---

### For Developers

#### Frontend Development

**When building new features:**

1. Use `useAgentPermissions()` hook to check access
2. Hide/show UI elements based on tool access
3. Use color-coded badges for agent types
4. Follow existing patterns in `/admin/agents` page

**Example:**
```tsx
const { canUseTool } = useAgentPermissions();

return (
  <div>
    {canUseTool('create_corpus') && (
      <button>Create Corpus</button>
    )}
  </div>
);
```

---

#### Backend Development

**When adding new tool endpoints:**

1. Use `require_tool_access()` middleware
2. Specify required tool name
3. Middleware will validate user has access

**Example:**
```python
from middleware.tool_permission_middleware import require_tool_access

@router.post('/create-corpus')
async def create_corpus(
    _: bool = Depends(require_tool_access('create_corpus')),
    current_user: dict = Depends(get_current_user)
):
    # Only users with create_corpus tool can access
    pass
```

---

#### Adding New Tools

**To add a new tool to the system:**

1. Update `backend/src/services/agent_hierarchy.py`
2. Add tool to appropriate agent type in `AGENT_HIERARCHY` dict
3. Update tool descriptions and use cases
4. Update frontend agent type cards if needed
5. Add permission middleware to relevant endpoints

**Example:**
```python
AGENT_HIERARCHY = {
    AgentType.CONTRIBUTOR: {
        "tools": [
            "rag_query",
            "list_corpora", 
            "get_corpus_info",
            "browse_documents",
            "add_data",
            "new_tool_here"  # Add new tool
        ],
        # ...
    }
}
```

---

## Future Considerations

### Potential Enhancements

#### 1. Custom Agent Types

**Current:** Agent types are predefined and standardized  
**Future:** Allow administrators to create custom agent types with custom tool sets

**Pros:**
- More flexibility for unique use cases
- Organizations can define their own access levels

**Cons:**
- Increases complexity
- May lead to inconsistent access patterns
- Harder to maintain

**Recommendation:** Only implement if there's strong demand from users.

---

#### 2. Temporary Access Grants

**Concept:** Allow temporary elevation of access for specific users

**Use Case:** A viewer needs contributor access for a specific project for 2 weeks

**Implementation:**
- Add `expires_at` field to `chatbot_user_groups` table
- Automatic removal when expired
- UI indicator for temporary access

---

#### 3. Access Request Workflow

**Concept:** Users can request access to higher agent types

**Flow:**
1. User requests contributor access
2. Administrator receives notification
3. Administrator approves/denies
4. User is automatically added to appropriate group

**Benefits:**
- Self-service access management
- Audit trail of access requests
- Reduces administrator workload

---

#### 4. Group Hierarchies

**Concept:** Groups can inherit from parent groups

**Example:**
```
Engineering (corpus-manager)
  ├─ Frontend Team (content-manager)
  └─ Backend Team (content-manager)
```

**Benefits:**
- Organizational structure reflected in access
- Easier to manage large teams

**Complexity:** Significant increase in logic and UI

---

#### 5. Tool-Level Audit Logging

**Concept:** Log every tool usage with user, timestamp, and result

**Benefits:**
- Security auditing
- Usage analytics
- Compliance requirements

**Implementation:**
- Add middleware to log all tool calls
- Store in `tool_usage_logs` table
- Create dashboard for viewing logs

---

### Performance Optimizations

#### 1. Permission Caching

**Current:** Permissions fetched on every request  
**Future:** Cache user permissions in Redis or session

**Benefits:**
- Reduced database queries
- Faster response times
- Lower server load

**Implementation:**
```python
# Cache user agent type for 5 minutes
@cache(ttl=300)
async def get_user_agent_type(user_id: int):
    # ... fetch from database
```

---

#### 2. Batch Permission Checks

**Current:** Individual permission checks per tool  
**Future:** Batch check multiple tools at once

**Use Case:** Frontend needs to check 10 tools at once

**Implementation:**
```python
@router.post('/check-tools')
async def check_multiple_tools(
    tools: List[str],
    current_user: dict = Depends(get_current_user)
):
    results = {}
    user_tools = await get_user_allowed_tools(current_user)
    for tool in tools:
        results[tool] = tool in user_tools
    return results
```

---

## Appendix

### Glossary

**Agent Type** - A predefined set of tools that define what a user can do (e.g., viewer, contributor)

**Chatbot User** - A user account specifically for chatbot access (separate from app managers)

**Group** - A collection of chatbot users with shared access level

**Tool** - A specific capability or action (e.g., rag_query, add_data)

**Hierarchical Inheritance** - Higher-level agent types automatically include all tools from lower levels

**Permission Indicator** - UI banner showing user's current agent type and tools

---

### Quick Reference

#### Agent Types & Tool Counts

| Agent Type | Tool Count | Key Tools |
|------------|------------|-----------|
| Viewer | 4 | rag_query, list_corpora, get_corpus_info, browse_documents |
| Contributor | 5 | + add_data |
| Content Manager | 6 | + delete_document |
| Corpus Manager | 8 | + create_corpus, delete_corpus |

---

#### Color Codes

| Agent Type | Color | Hex Code |
|------------|-------|----------|
| Viewer | Blue | #2563eb |
| Contributor | Emerald | #059669 |
| Content Manager | Amber | #d97706 |
| Corpus Manager | Purple | #9333ea |

---

#### Key Files

**Backend:**
- `backend/src/services/agent_hierarchy.py` - Agent type definitions
- `backend/src/middleware/tool_permission_middleware.py` - Permission validation
- `backend/src/api/routes/chatbot_admin.py` - API endpoints
- `backend/setup_test_data_docker.sh` - Test data setup script

**Frontend:**
- `frontend/src/app/admin/layout.tsx` - Admin navigation
- `frontend/src/app/admin/agents/page.tsx` - Agents management page
- `frontend/src/app/admin/chatbot-groups/page.tsx` - Groups management page
- `frontend/src/hooks/useAgentPermissions.ts` - Permission hooks

**Documentation:**
- `cascade-logs/2026-02-05/AGENT_HIERARCHY_IMPLEMENTATION_SUMMARY.md` - Implementation details
- `cascade-logs/2026-02-05/NEW_ACCESS_MODEL_DOCUMENTATION.md` - This document

---

### Git Commits

**Access Model Refactor:**
1. `cf6d4ef` - Restored missing emoji icons in sidebar
2. `b9d7340` - Updated /admin/agents page to reflect new model
3. `221aec9` - Updated chatbot groups page with agent terminology

**Previous Implementation:**
1. `d196bb5` - Admin route updates
2. `8ab5455` - Agent hierarchy system
3. `68745a8` - API endpoint permissions
4. `049a3b3` - Frontend permission checks
5. `e2ead8f` - Test data setup scripts

---

### Support & Questions

**For questions about:**

- **Access model concepts** - Review [Access Model Comparison](#access-model-comparison)
- **Implementation details** - See [Implementation Changes](#implementation-changes)
- **Testing** - Check [Testing & Verification](#testing--verification)
- **Migration** - Follow [Migration Guide](#migration-guide)
- **Development** - See developer sections in Migration Guide

---

**Document Version:** 2.0  
**Last Updated:** February 5, 2026  
**Author:** Cascade AI Assistant  
**Status:** ✅ Complete and Production-Ready
