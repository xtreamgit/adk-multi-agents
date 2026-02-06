# Corpus-Filtered RAG Query Plan

**Date:** February 6, 2026  
**Status:** Planning  
**Goal:** Ensure that when a user has access to a set of corpora, only those documents participate in answering queries — reliably and securely.

---

## Current State Assessment

| Layer | Status | Details |
|-------|--------|---------|
| **DB Schema** | ✅ Complete | `chatbot_corpus_access` links groups → corpora with permissions; `get_user_corpora()` resolves user → groups → corpora |
| **Backend API** | ✅ Complete | `/api/corpora/` returns user's accessible corpora; `/api/corpora/all-with-access` returns all corpora with `has_access` flag |
| **Frontend Selector** | ✅ Complete | `CorpusSelector.tsx` shows checkboxes, respects `has_access`, sends `selectedCorpora` names |
| **Chat Endpoint** | ⚠️ Partial | `server.py:888-897` injects corpora into the LLM prompt as a "CRITICAL INSTRUCTION" — relies on the **LLM obeying the instruction** |
| **RAG Tools** | ✅ Complete | `rag_query` (single) and `rag_multi_query` (parallel multi-corpus) both work |
| **Access Validation at Query Time** | ❌ Missing | No server-side enforcement that the user actually has access to the corpora being queried |

---

## The Core Problem

There are **two gaps** that make the current approach unreliable:

1. **No server-side enforcement** — The chat endpoint trusts whatever `corpora` list the frontend sends. A user could craft a request with corpora they don't have access to.

2. **LLM-dependent corpus routing** — The corpora list is injected as a text instruction into the prompt. The LLM *may* ignore it, use a subset, or default to a single corpus. This is **not deterministic**.

---

## Vertex AI Multi-Corpus Architecture (Reference)

Vertex AI Agent Builder supports multiple corpora simultaneously without re-vectorization or merging.

### Separate Corpora Approach (Recommended)

- Create multiple data stores (corpora) in Vertex AI Agent Builder
- Each corpus maintains its own vector index
- At query time, search across multiple data stores in a single request
- Agent Builder handles federated search and result merging automatically

### Key Benefits

- **No re-indexing needed** when adding new document collections
- **Granular access control** — different corpora can have different permissions
- **Independent update cycles** — update one corpus without affecting others
- **Better organization** — segment by topic, department, or sensitivity level

### How Vertex AI Federates Multiple Corpora

Each GCS bucket is treated as a separate **Data Store**, but can be queried together at runtime through **federated search** — they don't become "one source," but rather multiple sources queried simultaneously.

```
GCS Bucket 1 (Corpus A)          GCS Bucket 2 (Corpus B)
         ↓                                ↓
   Data Store 1                     Data Store 2
   (Vector Index 1)                 (Vector Index 2)
         ↓                                ↓
         └──────────────┬─────────────────┘
                        ↓
              Vertex AI Search Engine
                   (Query Time)
                        ↓
              Merged Results + Citations
```

### Critical Points

- **They Are NOT Combined Into One Index** — each corpus maintains its own vector index
- **They ARE Queried Together** — single API call searches both; results merged by relevance score
- **No re-vectorization** when adding corpora
- **Each bucket/corpus can be updated independently**

### Current Implementation (rag_multi_query.py)

Since Vertex AI RAG API doesn't support multi-corpus queries in a single call, `rag_multi_query` queries each corpus in parallel using `concurrent.futures.ThreadPoolExecutor` and merges results sorted by score.

```python
# Simplified flow from rag_multi_query.py
rag_retrieval_config = rag.RagRetrievalConfig(
    top_k=top_k,
    filter=rag.Filter(vector_distance_threshold=DEFAULT_DISTANCE_THRESHOLD),
)

# Query each corpus in parallel
with concurrent.futures.ThreadPoolExecutor() as executor:
    futures = [
        executor.submit(_query_single_corpus, corpus_name, query, rag_retrieval_config)
        for corpus_name in validated_corpora
    ]
    corpus_results = [future.result() for future in futures]

# Merge and sort by score
all_results.sort(key=lambda x: x.get("score", 0), reverse=True)
top_results = all_results[:top_k]
```

---

## Recommended Step-by-Step Plan

### Phase 1: Server-Side Access Validation (Security)

**Step 1 — Validate corpora in the chat endpoint**

In `server.py`, before injecting corpora into the prompt, validate each corpus name against the authenticated user's access list:

```
User sends: corpora=["ai-books", "design", "management"]
Server checks: user has access to ["ai-books", "design"] only
Server filters: corpora=["ai-books", "design"]  (silently drops "management")
Server logs: warning about unauthorized corpus access attempt
```

This uses the existing `CorpusRepository.get_user_corpora(user_id)` to get the allowed set, then intersects with the requested set.

**Key files:**
- `backend/src/api/server.py` (chat endpoint, lines ~880-900)
- `backend/src/database/repositories/corpus_repository.py` (`get_user_corpora`, `check_user_access`)

---

### Phase 2: Deterministic Corpus Filtering (Reliability)

**Step 2 — Bypass LLM for corpus selection; call `rag_multi_query` directly**

Instead of embedding corpus names in the prompt text and hoping the LLM calls the right tool, the **server should call `rag_multi_query` directly** (or the underlying `rag.retrieval_query` API) with the validated corpus list, then inject the **retrieved context chunks** into the LLM prompt as grounding data.

This is the standard RAG pattern:
1. **Retrieve** — Server calls Vertex AI RAG with the validated corpus list → gets ranked chunks
2. **Augment** — Server injects those chunks into the LLM prompt as context
3. **Generate** — LLM generates an answer grounded only in the provided chunks

This removes the LLM from the corpus-selection decision entirely.

**Step 3 — Use Vertex AI's `rag_resources` parameter for multi-corpus queries**

The existing `rag_multi_query` already queries each corpus in parallel and merges results by score. This is correct since Vertex AI RAG doesn't support multi-corpus in a single API call. The key change is to call this **from the server**, not from the agent's tool.

**Key files:**
- `backend/src/rag_agent/tools/rag_multi_query.py` (existing parallel query logic)
- `backend/src/rag_agent/tools/rag_query.py` (single corpus query)
- `backend/src/rag_agent/tools/utils.py` (`get_corpus_resource_name`, `check_corpus_exists`)

---

### Phase 3: Default Behavior When No Corpora Selected

**Step 4 — Define fallback behavior**

When the user sends a message with no corpora selected:
- **Option A**: Query ALL corpora the user has access to (broadest scope) ← Recommended
- **Option B**: Require at least one corpus selection (show a UI prompt)
- **Option C**: Use the user's last-selected corpora (already supported via `session_corpus_selections` table)

**Key files:**
- `backend/src/database/repositories/corpus_repository.py` (`get_last_selected_corpora`)
- `frontend/src/components/CorpusSelector.tsx`

---

### Phase 4: Response Attribution (Transparency)

**Step 5 — Include corpus source in response metadata**

The `rag_multi_query` already returns `corpus_source` per result chunk. Surface this in the chat response so the user sees which corpus each piece of evidence came from:

```
Answer: "Forest management practices include..."

Sources:
- [management] Chapter 3: Sustainable Forestry (score: 0.89)
- [design] Landscape Design Principles (score: 0.82)
```

**Key files:**
- `backend/src/rag_agent/tools/rag_multi_query.py` (already returns `corpus_source`)
- `frontend/src/components/ChatInterface.tsx` (render source attribution)

---

### Phase 5: Frontend Enhancements

**Step 6 — Visual feedback on active corpus filter**

Already partially done (the blue pill in the chat header). Enhance to show:
- Number of results per corpus
- Ability to toggle corpora mid-conversation
- Warning if no corpora are selected

**Key files:**
- `frontend/src/components/ChatInterface.tsx`
- `frontend/src/components/CorpusSelector.tsx`

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     FRONTEND                             │
│  CorpusSelector → selectedCorpora[] → ChatInterface      │
│  (only shows corpora user has access to)                 │
└────────────────────────┬────────────────────────────────┘
                         │ POST /api/chat {message, corpora}
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  BACKEND (server.py)                      │
│                                                          │
│  1. Authenticate user                                    │
│  2. Validate corpora against user's access (DB lookup)   │
│  3. If no corpora → use all user's accessible corpora    │
│  4. Call rag_multi_query() directly with validated list   │
│  5. Inject retrieved chunks as grounding context         │
│  6. Send augmented prompt to LLM agent                   │
│  7. Return response + source attribution                 │
└────────────────────────┬────────────────────────────────┘
                         │ rag.retrieval_query() per corpus
                         ▼
┌─────────────────────────────────────────────────────────┐
│              VERTEX AI RAG (per corpus)                   │
│                                                          │
│  Corpus 1 ──→ Vector search ──→ Top-K chunks            │
│  Corpus 2 ──→ Vector search ──→ Top-K chunks            │
│  Corpus N ──→ Vector search ──→ Top-K chunks            │
│                                                          │
│  Merge + re-rank by score → Return to server             │
└─────────────────────────────────────────────────────────┘
```

---

## Existing Database Schema (Reference)

### Access Control Chain

```
users → chatbot_users (linked by username)
  → chatbot_user_groups (many-to-many)
    → chatbot_groups
      → chatbot_corpus_access (group_id → corpus_id + permission)
        → corpora (id, name, display_name, vertex_corpus_id, gcs_bucket)
```

### Key Tables

- **`chatbot_corpus_access`** — Links chatbot groups to corpora with permission levels (`query`, `read`, `upload`, `delete`, `admin`)
- **`session_corpus_selections`** — Tracks last-selected corpora per user for session restoration
- **`corpus_metadata`** — Stores document counts per corpus

### Key Repository Methods

- `CorpusRepository.get_user_corpora(user_id)` — Returns all corpora a user has access to through their groups
- `CorpusRepository.check_user_access(user_id, corpus_id)` — Returns permission level or None
- `CorpusRepository.get_last_selected_corpora(user_id)` — Returns last-selected corpus IDs

---

## Decisions Pending

1. **Phase 2 approach** — Keep agent-tool approach (LLM decides) vs. server-side retrieval (deterministic)?
2. **Default behavior** (Step 4) — When no corpora selected: query all accessible, require selection, or restore last session?
3. **Implementation priority** — Phase 1 (security) first, or full deterministic pipeline?
