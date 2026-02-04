# Recommended User-to-Agent Access Assignment Model

**Date:** February 3, 2026  
**Project:** ADK Multi-Agents - Chatbot Admin System

---

## Overview

This document outlines the recommended approach for assigning users access to agents with different tool capabilities. The model leverages the existing chatbot admin infrastructure (users, groups, roles, permissions) to provide a scalable and maintainable access control system.

---

## Access Model: Group-Based Agent Assignment

Use your **existing group structure** to control agent access. This leverages the work you've already done and provides a scalable, maintainable solution.

### Recommended Architecture

```
User → Groups → Agent Access → Agent Type (with specific tools)
```

---

## Implementation Approach

### Option 1: **Group-to-Agent Mapping** (Recommended)

Assign agents to groups, where each group gets access to specific agent types:

| Group | Agent Access | Agent Type | Tools Available |
|-------|--------------|------------|-----------------|
| `default-chatbot-users` | Viewer Agent | Read-only | rag_query, list_corpora, get_corpus_info, browse_documents |
| `engineering` | Contributor Agent | Read + Add | Viewer tools + add_data |
| `marketing` | Contributor Agent | Read + Add | Viewer tools + add_data |
| `customer-support` | Viewer Agent | Read-only | rag_query, list_corpora, get_corpus_info, browse_documents |
| `developers` | Content Manager Agent | Read + Write + Delete Docs | Contributor tools + delete_document |
| `it-admin` | Corpus Manager Agent | Full Admin | ALL TOOLS |
| `gcp-admin` | Corpus Manager Agent | Full Admin | ALL TOOLS |

### Option 2: **Role-Based Agent Access** (More Granular)

Use roles to define agent access levels:

| Role | Agent Type | Description |
|------|------------|-------------|
| `viewer` | Viewer Agent | Read-only access |
| `contributor` | Contributor Agent | Can add documents |
| `content-manager` | Content Manager Agent | Can manage documents |
| `admin` | Corpus Manager Agent | Full control |

Then assign roles to groups, and groups to users (which you already have).

---

## Agent Type Definitions

### 1. Viewer Agent
- **Use Case:** Read-only access for general users
- **Tools:**
  - `rag_query` - Query documents
  - `list_corpora` - List available corpora
  - `get_corpus_info` - Get corpus details
  - `browse_documents` - Browse document links
- **Rationale:** Minimum viable toolset for querying and viewing information. Cannot modify any data.

### 2. Contributor Agent
- **Use Case:** Users who can add content
- **Tools:**
  - All Viewer Agent tools
  - `add_data` - Add documents to corpora
- **Rationale:** All viewer tools + ability to add documents. Cannot create/delete corpora or documents.

### 3. Content Manager Agent
- **Use Case:** Manage documents within existing corpora
- **Tools:**
  - All Contributor Agent tools
  - `delete_document` - Delete specific documents
- **Rationale:** Contributor tools + document deletion. Can manage content but not corpus structure.

### 4. Corpus Manager Agent
- **Use Case:** Full corpus lifecycle management
- **Tools:**
  - All Content Manager Agent tools
  - `create_corpus` - Create new corpora
  - `delete_corpus` - Delete entire corpora
- **Rationale:** **ALL TOOLS** - Complete control over corpora and documents. For administrators only.

---

## Database Schema Addition

Add new tables to track agent access:

```sql
-- Agent definitions with tool configurations
CREATE TABLE chatbot_agents (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    agent_type VARCHAR(100) NOT NULL, -- 'viewer', 'contributor', 'content-manager', 'corpus-manager'
    tools JSONB NOT NULL, -- Array of tool names: ["rag_query", "list_corpora", ...]
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Group to Agent access mapping
CREATE TABLE chatbot_group_agents (
    id SERIAL PRIMARY KEY,
    group_id INTEGER REFERENCES chatbot_groups(id) ON DELETE CASCADE,
    agent_id INTEGER REFERENCES chatbot_agents(id) ON DELETE CASCADE,
    can_use BOOLEAN DEFAULT TRUE,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    granted_by INTEGER REFERENCES users(id),
    UNIQUE(group_id, agent_id)
);
```

---

## User Experience Flow

1. **User logs in** → System identifies user
2. **System checks groups** → User belongs to groups (e.g., `engineering`, `default-chatbot-users`)
3. **System determines available agents** → Based on group memberships
4. **User selects agent** → From dropdown/switcher in UI
5. **Agent loads with appropriate tools** → Backend enforces tool restrictions

---

## Example Scenarios

### Scenario 1: New User (Alice)
- Alice is added to `default-chatbot-users` group (via checkbox)
- She gets access to **Viewer Agent**
- She can query documents but cannot add/delete anything

### Scenario 2: Engineer (Bob)
- Bob is in `engineering` group
- He gets access to **Contributor Agent**
- He can query documents AND add new documents
- He cannot delete documents or corpora

### Scenario 3: Admin (Carol)
- Carol is in `it-admin` group
- She gets access to **Corpus Manager Agent**
- She has ALL tools available
- She can create/delete corpora and manage all documents

---

## Tool Permission Hierarchy

```
Level 1 (Read):     rag_query, list_corpora, get_corpus_info, browse_documents
                    ↓
Level 2 (Write):    + add_data
                    ↓
Level 3 (Manage):   + delete_document
                    ↓
Level 4 (Admin):    + create_corpus, delete_corpus
```

---

## Benefits of This Approach

✅ **Leverages existing infrastructure** - Uses groups you've already built  
✅ **Scalable** - Easy to add new agent types or modify permissions  
✅ **Flexible** - Users can belong to multiple groups → access multiple agents  
✅ **Auditable** - Track who has access to which agents via `chatbot_group_agents`  
✅ **Secure** - Backend enforces tool restrictions based on agent type  
✅ **User-friendly** - Clear agent selection in UI  

---

## UI Integration

In the chatbot interface, add an **Agent Switcher** that shows:
- Available agents based on user's group memberships
- Current active agent
- Agent capabilities (read-only, can add data, full admin, etc.)

This would be similar to your existing corpus switcher but for agents.

---

## Implementation Steps

### Phase 1: Database & Backend
1. Create `chatbot_agents` and `chatbot_group_agents` tables
2. Seed with the 4 agent types (Viewer, Contributor, Content Manager, Corpus Manager)
3. Create API endpoints for agent management
4. Update backend to filter tools based on user's agent access

### Phase 2: Admin UI
1. Add agent management page to admin interface
2. Create group-to-agent assignment interface
3. Add agent configuration UI (name, description, tools)

### Phase 3: User UI
1. Add agent selection UI to frontend chatbot interface
2. Display current agent and capabilities
3. Implement agent switcher dropdown
4. Show tool availability based on selected agent

### Phase 4: Testing & Deployment
1. Test all agent types with different user groups
2. Verify tool restrictions are enforced
3. Deploy to cloud environment
4. Gather user feedback

---

## Security Considerations

- **Backend Enforcement:** Tool restrictions MUST be enforced on the backend, not just the UI
- **Token Validation:** Verify user's group memberships on every agent tool call
- **Audit Logging:** Log all agent tool usage for security auditing
- **Least Privilege:** Default to minimum permissions (Viewer Agent)
- **Regular Reviews:** Periodically review group-to-agent assignments

---

## Future Enhancements

- **Custom Agents:** Allow admins to create custom agent types with specific tool combinations
- **Time-based Access:** Temporary agent access for specific projects
- **Usage Analytics:** Track which agents and tools are most used
- **Agent Policies:** Define additional constraints (e.g., max documents per day)
- **Multi-tenancy:** Support for organization-level agent configurations

---

## Conclusion

This group-based agent access model provides a secure, scalable, and user-friendly approach to managing agent capabilities. By leveraging your existing chatbot admin infrastructure, implementation is straightforward and maintains consistency with your current access control patterns.
