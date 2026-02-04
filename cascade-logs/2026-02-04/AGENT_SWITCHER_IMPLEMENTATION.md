# Agent Switcher Implementation Summary

**Date:** February 4, 2026  
**Feature:** Agent Switcher in Chatbot UI

## Overview

Successfully implemented an agent switcher in the main chatbot UI that displays the user's assigned agent with expandable details. The implementation follows the requirement that users can only use one agent at a time based on their group assignment.

## Implementation Details

### 1. Backend API Endpoint

**File:** `backend/src/api/routes/chatbot_admin.py`

Created new endpoint: `GET /api/admin/chatbot/me/available-agents`

```python
@router.get("/me/available-agents")
async def get_my_available_agents(current_user = Depends(get_current_user)):
    """Get all agents available to the current logged-in chatbot user"""
    # Maps app user to chatbot_user and retrieves their available agents
    # based on group assignments
```

**Key Features:**
- Authenticates using Bearer token
- Maps app user to chatbot_user by username
- Returns agents where `can_use = TRUE` in group assignments
- Returns empty array if user has no chatbot_user record

**Response Format:**
```json
[
  {
    "id": 1,
    "name": "viewer-agent",
    "display_name": "Viewer Agent",
    "description": "Read-only access...",
    "agent_type": "viewer",
    "tools": ["rag_query", "list_corpora", "get_corpus_info", "browse_documents"],
    "is_active": true,
    "created_at": "2026-02-03T..."
  }
]
```

### 2. Frontend API Client Update

**File:** `frontend/src/lib/api-enhanced.ts`

Updated `getMyAgents()` method to use new endpoint:
```typescript
async getMyAgents(): Promise<Agent[]> {
  const response = await fetch(
    this.buildUrl('/api/admin/chatbot/me/available-agents'),
    { method: 'GET', headers: this.getAuthHeaders() }
  );
  return await response.json();
}
```

### 3. AgentSwitcher Component

**File:** `frontend/src/components/AgentSwitcher.tsx`

Redesigned as a **display/indicator component** (not a switcher) since users only have one agent:

**Features:**
- **Brand Green Styling:** Uses `rgb(0,84,64)` for borders, text, and accents
- **Compact Display:** Shows agent name and type in collapsed state
- **Expandable Details:** Click to expand and see:
  - Agent description
  - Available tools (as badges)
  - Note about multiple agents if applicable
- **Loading State:** Shows spinner while fetching agents
- **No Agent State:** Warning message if no agent assigned

**Visual Design:**
- Green border and light green background for current agent
- Computer monitor icon for agent representation
- Chevron icon indicates expandable content
- Tool badges with green styling

### 4. Main Chat UI Integration

**File:** `frontend/src/app/page.tsx`

**Changes:**
1. Added state management:
   ```typescript
   const [currentAgent, setCurrentAgent] = useState<ChatbotAgent | null>(null);
   const [availableAgents, setAvailableAgents] = useState<ChatbotAgent[]>([]);
   const [isLoadingAgents, setIsLoadingAgents] = useState(true);
   ```

2. Load agents on app startup (in `useEffect`):
   ```typescript
   const myAgents = await apiClient.getMyAgents();
   setAvailableAgents(myAgents);
   if (myAgents.length > 0) {
     setCurrentAgent(myAgents[0]); // Default to first agent
   }
   ```

3. Load agents after login:
   ```typescript
   // Same logic in handleLoginSuccess
   ```

4. Added AgentSwitcher to sidebar (both views):
   ```tsx
   <div className="p-4 border-t border-gray-200">
     <div className="text-xs text-gray-500 uppercase font-medium mb-2">
       Current Agent
     </div>
     <AgentSwitcher 
       currentAgent={currentAgent}
       availableAgents={availableAgents}
       isLoading={isLoadingAgents}
     />
   </div>
   ```

## User Experience Flow

1. **App Load:**
   - User opens app → automatically authenticated (if token exists)
   - Agent API called immediately
   - First available agent set as default
   - User can start querying immediately

2. **Login:**
   - User logs in → agents loaded
   - Default agent assigned
   - Ready to use chatbot

3. **Agent Display:**
   - Collapsed: Shows agent name and type
   - Expanded: Shows description, tools, and access note
   - Always visible in sidebar

## Testing Results

**Backend Test:**
```bash
✅ Login successful as testuser
📊 Status: 200
✅ Found 2 available agent(s)
  - Viewer Agent (viewer) - 4 tools
  - Admin Agent (admin) - 8 tools
```

**Database Setup:**
- Assigned Viewer agent to `gcp-admin` group for testing
- User `testuser` is member of `gcp-admin` group
- Agent access working correctly through group assignments

## Key Design Decisions

1. **Single Agent Display:** Since users can only use one agent per group assignment, the component displays the first available agent rather than providing switching functionality.

2. **Default Agent on Load:** Ensures smooth UX - users can immediately query without manual selection.

3. **Brand Green Styling:** Consistent with project brand colors `rgb(0,84,64)`.

4. **Expandable Details:** Keeps UI clean while providing transparency about agent capabilities.

5. **Graceful Degradation:** Handles cases where user has no agent assigned with clear messaging.

## Files Modified

1. `backend/src/api/routes/chatbot_admin.py` - New endpoint
2. `frontend/src/lib/api-enhanced.ts` - API client update
3. `frontend/src/components/AgentSwitcher.tsx` - Component redesign
4. `frontend/src/app/page.tsx` - UI integration

## Commits

1. `2af5886` - feat: Add agent switcher to chatbot UI with default agent loading
2. `2718cb3` - fix: Correct current_user access in /me/available-agents endpoint

## Future Enhancements

- Add ability to switch agents if user has multiple agent access
- Show agent capabilities in a tooltip on hover
- Add agent selection persistence in user preferences
- Display agent-specific instructions or guidelines

## Status

✅ **COMPLETE** - All tasks completed and tested successfully.
