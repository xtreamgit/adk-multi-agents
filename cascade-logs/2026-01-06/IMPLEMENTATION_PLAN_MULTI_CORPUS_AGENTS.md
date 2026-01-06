# Implementation Plan: Multi-Corpus, Multi-Agent RAG System

**Date:** January 6, 2026  
**Status:** Planning Phase  
**Priority:** High

---

## 📋 **Executive Summary**

Implementation of an enhanced RAG system supporting:
- Multiple corpus grounding in single queries (Vertex AI multi-corpus RAG)
- User-based agent selection with permission controls
- Persistent corpus selections across sessions
- Group-based access control for agents and corpora

---

## 🎯 **Technical Requirements**

### **Core Requirements**
1. ✅ Users belong to one or more groups (IMPLEMENTED)
2. ✅ Groups determine access to roles (IMPLEMENTED)
3. ✅ Each corpus stored in separate GCS bucket (IMPLEMENTED)
4. ✅ Group/role-based corpus access control (IMPLEMENTED)
5. ⚠️ Agent selection from allowed set (PARTIAL - needs UI)
6. ⚠️ Default agent: "default-agent" (PARTIAL - needs enforcement)
7. ❌ **Multi-corpus grounding in Vertex AI** (NOT IMPLEMENTED - CRITICAL)
8. ❌ Persistent corpus selection based on last session (NOT IMPLEMENTED)
9. ❌ Multi-corpus vectorization/querying (NOT IMPLEMENTED)

### **Critical Feature: Multi-Corpus Grounding**
The most important requirement is enabling Vertex AI RAG to query **multiple corpora simultaneously** in a single grounding operation. This is the foundation for all other features.

---

## 📊 **Current Architecture Analysis**

### **Database Schema** ✅ (Already Implemented)
```sql
✅ agents - agent definitions with config paths
✅ user_agent_access - user-to-agent permissions
✅ corpora - corpus definitions with GCS buckets
✅ group_corpus_access - group-to-corpus permissions
✅ user_sessions - tracks active_agent_id and active_corpora (JSON)
✅ session_corpus_selections - last selected corpora per user
```

### **Backend RAG Query** ⚠️ (Needs Enhancement)
Current: `rag_query.py` - Single corpus only
```python
# Current implementation (line 75-83)
response = rag.retrieval_query(
    rag_resources=[
        rag.RagResource(
            rag_corpus=corpus_resource_name,  # Single corpus only
        )
    ],
    text=query,
)
```

**CRITICAL GAP:** Cannot query multiple corpora simultaneously.

### **Frontend** ⚠️ (Needs Enhancement)
- ✅ Multi-corpus selection UI (implemented)
- ❌ Agent selection UI (not implemented)
- ❌ Corpus persistence on session end (not implemented)

---

## 🚀 **PHASE 1: Multi-Corpus RAG Query Foundation**
**Duration:** 2-3 days  
**Priority:** CRITICAL  
**Status:** Not Started

### **Objective**
Enable Vertex AI to query multiple corpora simultaneously in a single RAG operation.

### **Tasks**

#### **1.1 Research Vertex AI Multi-Corpus Capabilities**
- [ ] Verify Vertex AI RAG API supports multiple `rag_resources`
- [ ] Test if multiple `RagResource` objects can be passed to `rag.retrieval_query()`
- [ ] Document any limitations or best practices
- [ ] Determine if corpus priority/weighting is supported

**Expected API Pattern:**
```python
response = rag.retrieval_query(
    rag_resources=[
        rag.RagResource(rag_corpus=corpus_1_resource_name),
        rag.RagResource(rag_corpus=corpus_2_resource_name),
        rag.RagResource(rag_corpus=corpus_3_resource_name),
    ],
    text=query,
    rag_retrieval_config=config,
)
```

#### **1.2 Create Multi-Corpus RAG Query Tool**
**File:** `backend/src/rag_agent/tools/rag_multi_query.py`

- [ ] Create new tool `rag_multi_query(corpus_names: List[str], query: str)`
- [ ] Accept list of corpus names/IDs
- [ ] Validate all corpora exist before querying
- [ ] Build list of `RagResource` objects for each corpus
- [ ] Execute single `rag.retrieval_query()` with all corpora
- [ ] Process results with corpus source attribution
- [ ] Handle errors gracefully (missing corpus, access denied, etc.)

**Key Features:**
```python
def rag_multi_query(
    corpus_names: List[str],  # Can be display names or resource names
    query: str,
    tool_context: ToolContext,
) -> dict:
    """
    Query multiple Vertex AI RAG corpora simultaneously.
    Results will include which corpus each result came from.
    """
```

#### **1.3 Update Agent Tool Registry**
**Files:** 
- `backend/src/services/agent_loader.py`
- `backend/config/agent_instructions/*.json`

- [ ] Register `rag_multi_query` as available tool
- [ ] Update agent instructions to use multi-corpus queries
- [ ] Deprecate single-corpus `rag_query` or keep for backward compatibility
- [ ] Document when to use single vs multi-corpus queries

#### **1.4 Testing**
- [ ] Unit test: Query 2 corpora with overlapping content
- [ ] Unit test: Query 3+ corpora with distinct content
- [ ] Unit test: Handle missing corpus in list
- [ ] Unit test: Empty corpus list (should error)
- [ ] Integration test: Full chat session with multi-corpus grounding
- [ ] Performance test: Compare single vs multi-corpus query times

**Success Criteria:**
- ✅ Can query 2+ corpora in single API call
- ✅ Results include source corpus attribution
- ✅ Performance acceptable (<2s for 3 corpora)
- ✅ Error handling for edge cases

---

## 🔐 **PHASE 2: Session Corpus Persistence**
**Duration:** 1-2 days  
**Priority:** High  
**Status:** Not Started  
**Depends On:** Phase 1

### **Objective**
Save user's selected corpora when session ends and restore on next login.

### **Tasks**

#### **2.1 Backend: Corpus Selection Tracking**
**File:** `backend/src/services/session_service.py`

- [ ] Create `save_session_corpus_selections(user_id, corpus_ids)` method
- [ ] Update `session_corpus_selections` table on corpus change
- [ ] Use `ON CONFLICT REPLACE` to update `last_selected_at`
- [ ] Create `get_last_corpus_selections(user_id)` method
- [ ] Return list of corpus IDs sorted by `last_selected_at DESC`

#### **2.2 Backend: Session End Handler**
**File:** `backend/src/api/routes/sessions.py`

- [ ] Add `/api/sessions/{sessionId}/end` endpoint
- [ ] Accept current `corpus_ids` in request body
- [ ] Call `save_session_corpus_selections()`
- [ ] Mark session as inactive
- [ ] Return success confirmation

#### **2.3 Backend: Session Start/Resume Handler**
**File:** `backend/src/api/routes/sessions.py`

- [ ] Update `/api/sessions/create` endpoint
- [ ] Check for last corpus selections
- [ ] If found, include in session initialization
- [ ] If not found, use default corpus (ai-books)
- [ ] Return corpus IDs to frontend

#### **2.4 Frontend: Save on Logout/Refresh**
**File:** `frontend/src/app/page.tsx`

- [ ] Call `/api/sessions/end` on logout
- [ ] Save corpus selections to session before unmount
- [ ] Use `beforeunload` event to persist on browser close
- [ ] Restore corpus selections on login/session resume

#### **2.5 Testing**
- [ ] Test: Select corpora, logout, login → corpora restored
- [ ] Test: Select corpora, close browser, reopen → corpora restored
- [ ] Test: First-time login → default corpus selected
- [ ] Test: Multi-tab behavior (same user, different sessions)

**Success Criteria:**
- ✅ Corpus selections persist across sessions
- ✅ Last-used corpora restored on login
- ✅ Default corpus used for new users
- ✅ No data loss on browser close

---

## 👥 **PHASE 3: Agent Selection UI & Permissions**
**Duration:** 2-3 days  
**Priority:** High  
**Status:** Not Started  
**Depends On:** Phase 2

### **Objective**
Allow users to select agents from their permitted set with visual UI.

### **Tasks**

#### **3.1 Backend: User Agent Access API**
**File:** `backend/src/api/routes/agents.py`

- [ ] Enhance `GET /api/agents/me` endpoint
- [ ] Return agents filtered by `user_agent_access` table
- [ ] Include agent metadata: name, display_name, description, capabilities
- [ ] Mark default agent if user has preference saved
- [ ] Return agent configuration details

**Response Format:**
```json
{
  "agents": [
    {
      "id": 1,
      "name": "default-agent",
      "display_name": "Default RAG Agent",
      "description": "General purpose agent",
      "is_default": true,
      "capabilities": ["rag_query", "list_corpora", "create_corpus"]
    },
    {
      "id": 2,
      "name": "research-agent",
      "display_name": "Research Agent",
      "is_default": false,
      "capabilities": ["rag_query", "list_corpora"]
    }
  ]
}
```

#### **3.2 Backend: Agent Switching Enhancement**
**File:** `backend/src/api/routes/agents.py`

- [ ] Update `POST /api/agents/session/{sessionId}/switch/{agentId}` endpoint
- [ ] Verify user has permission to access agent
- [ ] Check agent is active (`is_active = true`)
- [ ] Update session's `active_agent_id`
- [ ] Return new agent details
- [ ] Log agent switch for auditing

#### **3.3 Frontend: Agent Selector Component**
**File:** `frontend/src/components/AgentSelector.tsx` (NEW)

- [ ] Create dropdown/card UI for agent selection
- [ ] Fetch available agents on mount
- [ ] Display agent name, description, capabilities
- [ ] Highlight current agent
- [ ] Allow switching agents
- [ ] Show "default-agent" badge for default
- [ ] Disable unavailable agents (with tooltip)

**Design Pattern:** Similar to `CorpusSelector` with cards

#### **3.4 Frontend: Agent Display in Header**
**File:** `frontend/src/components/ChatInterface.tsx`

- [ ] Update header to show agent selector button
- [ ] Show current agent name (already implemented)
- [ ] Add dropdown/modal to switch agents
- [ ] Confirm before switching (warn about session reset)
- [ ] Update UI immediately after switch

#### **3.5 Frontend: Default Agent Enforcement**
**File:** `frontend/src/app/page.tsx`

- [ ] On session create, verify default agent is set
- [ ] If user has no agent preference, set to "default-agent"
- [ ] Save agent preference in user profile
- [ ] Restore agent preference on login

#### **3.6 Testing**
- [ ] Test: User with 1 agent → no selection UI, auto-use
- [ ] Test: User with 3 agents → can select any
- [ ] Test: Switch agent mid-session → chat history preserved
- [ ] Test: User tries to access forbidden agent → denied
- [ ] Test: New user → default-agent auto-selected

**Success Criteria:**
- ✅ Users see only permitted agents
- ✅ Agent switching works smoothly
- ✅ Default agent enforced for new users
- ✅ Agent capabilities clearly displayed
- ✅ Audit trail for agent switches

---

## 🔗 **PHASE 4: Integration & Multi-Corpus Chat**
**Duration:** 2-3 days  
**Priority:** High  
**Status:** Not Started  
**Depends On:** Phases 1, 2, 3

### **Objective**
Integrate multi-corpus querying into the chat interface with proper UI feedback.

### **Tasks**

#### **4.1 Backend: Chat Endpoint Enhancement**
**File:** `backend/src/api/server.py` (chat_with_agent endpoint)

- [ ] Accept `corpus_ids` from frontend in chat request
- [ ] Validate user has access to all requested corpora
- [ ] Pass corpus list to agent context
- [ ] Use `rag_multi_query` instead of `rag_query`
- [ ] Return results with corpus attribution

#### **4.2 Backend: Agent Context Update**
**File:** `backend/src/rag_agent/agent.py`

- [ ] Update agent to use session's `active_corpora`
- [ ] Pass corpora to RAG tools automatically
- [ ] Handle empty corpus list (use default)
- [ ] Log which corpora were queried

#### **4.3 Frontend: Multi-Corpus Query Indication**
**File:** `frontend/src/components/ChatInterface.tsx`

- [ ] Show selected corpora in chat input area
- [ ] Display "Searching in: ai-books, test-corpus" message
- [ ] Show corpus badges above user message
- [ ] Indicate which corpus results came from (in citations)

#### **4.4 Frontend: Result Source Attribution**
**File:** `frontend/src/components/ChatMessage.tsx` (if exists)

- [ ] Parse result metadata for corpus source
- [ ] Display corpus name next to each citation
- [ ] Color-code results by corpus (optional)
- [ ] Show "Results from 2/3 corpora" summary

**Example UI:**
```
🔍 Searching in: AI Books Collection, Test Corpus

User: What is machine learning?

Agent: Based on your corpora...
📚 AI Books Collection: "Machine learning is..."
📄 Test Corpus: "ML algorithms include..."
```

#### **4.5 Testing**
- [ ] Test: Query with 1 corpus → works as before
- [ ] Test: Query with 3 corpora → results from all shown
- [ ] Test: Query with no results in corpus A, results in corpus B
- [ ] Test: Change corpus mid-session → new queries use new set
- [ ] Test: User without corpus access → error message

**Success Criteria:**
- ✅ Chat uses selected corpora automatically
- ✅ Results attributed to source corpus
- ✅ Performance acceptable for 3+ corpora
- ✅ Clear UI feedback on what's being searched
- ✅ Error handling for access issues

---

## 🧪 **PHASE 5: Testing & Validation**
**Duration:** 2-3 days  
**Priority:** High  
**Status:** Not Started  
**Depends On:** Phases 1-4

### **Objective**
Comprehensive testing of all features working together.

### **Tasks**

#### **5.1 Unit Tests**
- [ ] Multi-corpus RAG query tool tests
- [ ] Session persistence tests
- [ ] Agent access control tests
- [ ] Corpus access control tests
- [ ] Permission validation tests

#### **5.2 Integration Tests**
- [ ] End-to-end chat with multi-corpus grounding
- [ ] Agent switching during active session
- [ ] Corpus selection changes during session
- [ ] Login → restore last corpora → query → logout cycle
- [ ] Multi-user scenarios (different permissions)

#### **5.3 Permission Tests**
- [ ] User with no corpus access → denied
- [ ] User with partial corpus access → only allowed shown
- [ ] User tries to query forbidden corpus → error
- [ ] User switches to forbidden agent → denied
- [ ] Group membership changes → access updated

#### **5.4 Performance Tests**
- [ ] Single corpus query baseline
- [ ] 2 corpus query (measure latency increase)
- [ ] 3 corpus query (measure latency increase)
- [ ] 5+ corpus query (identify limits)
- [ ] Large result set handling

#### **5.5 Edge Case Tests**
- [ ] Empty corpus (no documents)
- [ ] Corpus with 1 document
- [ ] Corpus with 10,000+ documents
- [ ] Query matching no documents
- [ ] Query matching documents in all corpora
- [ ] Concurrent users querying same corpus
- [ ] Session timeout with unsaved selections

#### **5.6 User Acceptance Testing**
- [ ] Create test scenarios for each user type
- [ ] Verify UI is intuitive
- [ ] Check error messages are helpful
- [ ] Validate performance is acceptable
- [ ] Confirm all requirements met

**Success Criteria:**
- ✅ All unit tests pass
- ✅ All integration tests pass
- ✅ All permission tests pass
- ✅ Performance within acceptable limits (<3s for 3 corpora)
- ✅ No critical bugs found
- ✅ User feedback positive

---

## 📚 **PHASE 6: Documentation & Deployment**
**Duration:** 1-2 days  
**Priority:** Medium  
**Status:** Not Started  
**Depends On:** Phase 5

### **Objective**
Document new features and prepare for production deployment.

### **Tasks**

#### **6.1 API Documentation**
- [ ] Document multi-corpus query API
- [ ] Document agent selection endpoints
- [ ] Document session persistence endpoints
- [ ] Update OpenAPI/Swagger specs
- [ ] Add code examples for each endpoint

#### **6.2 User Documentation**
- [ ] How to select multiple corpora
- [ ] How to switch agents
- [ ] Understanding corpus permissions
- [ ] Troubleshooting guide
- [ ] FAQ for common issues

#### **6.3 Developer Documentation**
- [ ] Architecture diagram with multi-corpus flow
- [ ] Database schema documentation
- [ ] RAG query flow diagram
- [ ] Permission model explanation
- [ ] Migration guide from old system

#### **6.4 Deployment Preparation**
- [ ] Update environment variables
- [ ] Database migration scripts
- [ ] Seed script updates (default agents, corpora)
- [ ] Backup procedures
- [ ] Rollback plan

#### **6.5 Deployment Steps**
- [ ] Deploy to staging environment
- [ ] Run full test suite in staging
- [ ] Performance testing in staging
- [ ] User acceptance testing in staging
- [ ] Deploy to production
- [ ] Monitor for issues

#### **6.6 Post-Deployment**
- [ ] Monitor query performance
- [ ] Track multi-corpus usage metrics
- [ ] Collect user feedback
- [ ] Address any issues quickly
- [ ] Plan for future enhancements

**Success Criteria:**
- ✅ All documentation complete
- ✅ Deployment successful
- ✅ No critical production issues
- ✅ Monitoring in place
- ✅ User adoption verified

---

## 📊 **Implementation Timeline**

```
Week 1: Foundation
├─ Day 1-2: Phase 1 (Multi-Corpus RAG) - CRITICAL
├─ Day 3-4: Phase 2 (Session Persistence)
└─ Day 5:   Phase 3 Start (Agent Selection Backend)

Week 2: Integration
├─ Day 6-7: Phase 3 Complete (Agent Selection UI)
├─ Day 8-9: Phase 4 (Integration & Multi-Corpus Chat)
└─ Day 10:  Buffer / Catchup

Week 3: Testing & Deployment
├─ Day 11-12: Phase 5 (Testing & Validation)
├─ Day 13:    Phase 6 (Documentation)
└─ Day 14-15: Deployment & Monitoring
```

**Total Estimated Duration:** 15 working days (3 weeks)

---

## 🎯 **Success Metrics**

### **Technical Metrics**
- [ ] Multi-corpus queries working for 2-5 corpora simultaneously
- [ ] Query latency <3 seconds for 3 corpora
- [ ] Session persistence 100% reliable
- [ ] Agent switching <1 second response time
- [ ] Zero permission bypass vulnerabilities

### **User Metrics**
- [ ] Users can successfully select multiple corpora
- [ ] Users can switch agents without issues
- [ ] Corpus selections persist across sessions
- [ ] Clear visual feedback on what's being searched
- [ ] Error messages are helpful and actionable

### **Business Metrics**
- [ ] All technical requirements met
- [ ] System scalable to 10+ corpora per user
- [ ] Maintains backward compatibility
- [ ] Production-ready security
- [ ] Comprehensive documentation

---

## ⚠️ **Risks & Mitigation**

### **Risk 1: Vertex AI Multi-Corpus Limitations**
**Impact:** High | **Probability:** Medium

**Description:** Vertex AI RAG API may not support multiple corpora in single query, or may have performance issues.

**Mitigation:**
- Research API capabilities thoroughly in Phase 1 Day 1
- If not supported, implement sequential queries with result merging
- Benchmark performance early
- Have fallback strategy ready

### **Risk 2: Performance Degradation**
**Impact:** Medium | **Probability:** Medium

**Description:** Querying multiple large corpora may be too slow for good UX.

**Mitigation:**
- Implement caching where possible
- Add query timeout limits
- Allow user to limit number of corpora
- Optimize retrieval config (top_k, distance threshold)
- Consider corpus size limits

### **Risk 3: Complex Permission Logic**
**Impact:** Medium | **Probability:** Low

**Description:** Group/role/corpus permissions may create edge cases.

**Mitigation:**
- Comprehensive test coverage
- Clear permission hierarchy documentation
- Admin UI for permission management
- Audit logging for all access decisions

### **Risk 4: Session State Management**
**Impact:** Low | **Probability:** Low

**Description:** Browser refresh or multi-tab scenarios may cause state issues.

**Mitigation:**
- Use server-side session as source of truth
- Implement proper session synchronization
- Handle race conditions gracefully
- Test multi-tab scenarios thoroughly

---

## 🔄 **Migration Strategy**

### **Backward Compatibility**
- [ ] Keep single-corpus `rag_query` tool functional
- [ ] Existing sessions continue to work
- [ ] Default corpus used if none selected
- [ ] Gradual rollout to user groups

### **Data Migration**
- [ ] No breaking schema changes needed (tables exist)
- [ ] Seed default agents if missing
- [ ] Assign all users to default agent initially
- [ ] Populate `session_corpus_selections` from current sessions

### **Rollback Plan**
- [ ] Keep previous version deployable
- [ ] Database changes are additive (no drops)
- [ ] Feature flags to disable new features
- [ ] Quick rollback procedure documented

---

## 📝 **Open Questions**

1. **Multi-Corpus Priority/Weighting**
   - Should users be able to prioritize certain corpora?
   - Should more recent corpora get higher weight?
   - Decision needed by: Phase 1

2. **Agent Capabilities UI**
   - How detailed should capability descriptions be?
   - Should we show tool list to users?
   - Decision needed by: Phase 3

3. **Corpus Limit Per User**
   - What's the maximum corpora a user can select?
   - Should it be configurable per group?
   - Decision needed by: Phase 2

4. **Performance Targets**
   - What's acceptable query time for 5 corpora?
   - Should we implement progressive loading?
   - Decision needed by: Phase 1

5. **Audit Logging**
   - How detailed should query logs be?
   - Should we log all multi-corpus queries?
   - Decision needed by: Phase 4

---

## 📖 **References**

### **Existing Code**
- `backend/src/rag_agent/tools/rag_query.py` - Current single-corpus implementation
- `backend/src/models/session.py` - Session models (ready for multi-corpus)
- `backend/src/database/migrations/003_add_agents_corpora.sql` - Schema
- `frontend/src/components/CorpusSelector.tsx` - Multi-select UI reference

### **Documentation**
- Vertex AI RAG API: https://cloud.google.com/vertex-ai/docs/generative-ai/rag-overview
- Google ADK Documentation: https://github.com/google/genai-agent-framework
- Current README: `/Users/hector/github.com/xtreamgit/adk-multi-agents/README.md`

### **Related Work**
- Session Summary: `cascade-logs/SESSION_SUMMARY_2026-01-06.md`
- Previous Implementation: Multi-select corpus UI (completed Jan 6, 2026)

---

## ✅ **Next Steps**

### **Immediate Actions (This Week)**
1. **Review this plan** with stakeholders
2. **Start Phase 1** - Multi-Corpus RAG research and implementation
3. **Set up test environment** with multiple corpora
4. **Create feature branch** for development

### **Before Starting Development**
- [ ] Confirm Vertex AI multi-corpus support
- [ ] Review and approve timeline
- [ ] Identify any additional requirements
- [ ] Set up monitoring for new features
- [ ] Prepare test data (multiple corpora with known content)

---

**Plan Status:** ✅ Ready for Review  
**Last Updated:** January 6, 2026  
**Next Review:** After Phase 1 completion
