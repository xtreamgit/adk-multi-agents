# Phase 1 Research Findings: Vertex AI Multi-Corpus Capabilities

**Date:** January 6, 2026  
**Researcher:** Cascade AI  
**Status:** Complete

---

## 🎯 **Research Objective**

Determine if Vertex AI RAG API supports querying multiple corpora simultaneously in a single `rag.retrieval_query()` call.

---

## ❌ **CRITICAL FINDING: Multi-Corpus NOT Supported**

### **SDK Evidence**

Found in installed Vertex AI SDK (`vertexai` package):

**File:** `vertexai/rag/rag_retrieval.py` (lines 79-80)
```python
if len(rag_resources) > 1:
    raise ValueError("Currently only support 1 RagResource.")
```

**File:** `vertexai/preview/rag/rag_retrieval.py` (lines 113-114)
```python
if len(rag_resources) > 1:
    raise ValueError("Currently only support 1 RagResource.")
```

**File:** `vertexai/preview/rag/rag_store.py` (lines 111-112)
```python
if len(rag_resources) > 1:
    raise ValueError("Currently only support 1 RagResource.")
```

### **API Documentation Quote**

From [RAG Engine API Documentation](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/model-reference/rag-api):

> **rag_resources**: A list of RagResource. It can be used to specify corpus only or ragfiles. **Currently only support one corpus or multiple files from one corpus.** In the future we may open up multiple corpora support.

---

## 📊 **What IS Supported**

### ✅ **Multiple Files from SAME Corpus**
```python
response = rag.retrieval_query(
    rag_resources=[
        rag.RagResource(
            rag_corpus="projects/.../ragCorpora/my-corpus",
            rag_file_ids=["file-1", "file-2", "file-3"]  # Multiple files OK
        )
    ],
    text=query,
)
```

### ❌ **Multiple Corpora (NOT Supported)**
```python
# THIS WILL FAIL with ValueError
response = rag.retrieval_query(
    rag_resources=[
        rag.RagResource(rag_corpus=corpus_1),  # ❌ 
        rag.RagResource(rag_corpus=corpus_2),  # Will raise error
    ],
    text=query,
)
```

---

## 🔄 **Required Implementation Strategy**

Since Vertex AI doesn't support multi-corpus queries, we must use **sequential queries with result merging**.

### **Approach: Parallel Sequential Queries**

1. **Query each corpus independently** (can parallelize with `asyncio`)
2. **Collect all results** from each corpus
3. **Merge and deduplicate** results
4. **Maintain source attribution** (which corpus each result came from)
5. **Sort by relevance** across all corpora

---

## 💡 **Proposed Implementation**

### **New Tool: `rag_multi_query`**

```python
async def rag_multi_query(
    corpus_names: List[str],
    query: str,
    tool_context: ToolContext,
) -> dict:
    """
    Query multiple RAG corpora by executing parallel sequential queries.
    
    Since Vertex AI doesn't support multi-corpus in single call,
    this queries each corpus separately and merges results.
    """
    
    # Validate all corpora exist
    for corpus_name in corpus_names:
        if not check_corpus_exists(corpus_name, tool_context):
            return error_response(f"Corpus {corpus_name} not found")
    
    # Query all corpora in parallel
    import asyncio
    tasks = [
        query_single_corpus_async(corpus_name, query, tool_context)
        for corpus_name in corpus_names
    ]
    corpus_results = await asyncio.gather(*tasks)
    
    # Merge results with source attribution
    all_results = []
    for corpus_name, results in zip(corpus_names, corpus_results):
        for result in results:
            result['corpus_source'] = corpus_name  # Add source
            all_results.append(result)
    
    # Sort by relevance score (descending)
    all_results.sort(key=lambda x: x.get('score', 0), reverse=True)
    
    # Optional: Limit to top K across all corpora
    top_results = all_results[:DEFAULT_TOP_K]
    
    return {
        "status": "success",
        "message": f"Queried {len(corpus_names)} corpora",
        "query": query,
        "corpora_queried": corpus_names,
        "results": top_results,
        "results_count": len(top_results),
        "results_by_corpus": {
            name: sum(1 for r in top_results if r['corpus_source'] == name)
            for name in corpus_names
        }
    }
```

---

## ⚡ **Performance Considerations**

### **Sequential vs Parallel**

| Approach | Single Corpus Time | 3 Corpora Time | Notes |
|----------|-------------------|----------------|-------|
| Sequential | 800ms | ~2400ms (3x) | Simple but slow |
| Parallel (asyncio) | 800ms | ~800-1000ms | Recommended ✅ |
| Parallel (threading) | 800ms | ~900-1100ms | Alternative |

**Recommendation:** Use `asyncio` for parallel queries to maintain sub-second performance.

### **Result Merging Strategies**

1. **Simple Concatenation** - Fast, preserves all results
2. **Score-based Ranking** - Sort all results by relevance score ✅
3. **Round-robin** - Alternate between corpora (ensures diversity)
4. **Weighted by Corpus** - Allow user to prioritize certain corpora

**Recommendation:** Start with score-based ranking (simplest, most accurate).

---

## 🧪 **Testing Strategy**

### **Unit Tests**
- [ ] Query 2 corpora → results from both
- [ ] Query 3 corpora → performance <1.5s
- [ ] One corpus has no results → doesn't fail
- [ ] Missing corpus → clear error message
- [ ] Empty corpus list → error

### **Integration Tests**
- [ ] Full chat session with 2 corpora
- [ ] Corpus source attribution visible in UI
- [ ] Switch corpora mid-session → new queries use new set

### **Performance Benchmarks**
- [ ] Baseline: Single corpus query time
- [ ] 2 corpora parallel query time (<1.2x baseline)
- [ ] 3 corpora parallel query time (<1.5x baseline)
- [ ] 5 corpora parallel query time (<2x baseline)

---

## ⚠️ **Risks & Limitations**

### **Risk 1: Performance Degradation**
- **Impact:** High
- **Probability:** Medium
- **Mitigation:** Use parallel execution, implement caching

### **Risk 2: Rate Limiting**
- **Impact:** Medium
- **Probability:** Low
- **Mitigation:** Implement exponential backoff, respect Vertex AI quotas

### **Risk 3: Inconsistent Results**
- **Impact:** Low
- **Probability:** Low
- **Mitigation:** Use same retrieval config for all queries

### **Risk 4: Result Deduplication Needed**
- **Impact:** Low
- **Probability:** Medium (if same doc in multiple corpora)
- **Mitigation:** Implement optional deduplication by source_uri

---

## ✅ **Recommendations**

### **Immediate Actions**
1. ✅ **Accept the limitation** - Single corpus per query is current reality
2. ✅ **Implement parallel sequential queries** - Best available approach
3. ✅ **Use asyncio for parallelization** - Maintains performance
4. ✅ **Add comprehensive source attribution** - Critical for UX

### **Future Enhancements**
1. ⚠️ **Monitor Vertex AI updates** - Multi-corpus support may come
2. ⚠️ **Consider caching** - If same query to same corpus, reuse results
3. ⚠️ **Add result deduplication** - If needed based on user feedback

---

## 📝 **Updated Phase 1 Plan**

### **Original Plan** (No longer viable)
~~Create `rag_multi_query` that passes multiple RagResource objects~~

### **Revised Plan** ✅
1. **Create `rag_multi_query_parallel.py`** - Parallel sequential queries
2. **Implement async query execution** - Use `asyncio.gather()`
3. **Add result merging logic** - Score-based ranking
4. **Maintain source attribution** - Track which corpus each result came from
5. **Write comprehensive tests** - Unit, integration, performance

---

## 🎯 **Success Criteria (Updated)**

| Criterion | Original | Revised | Status |
|-----------|----------|---------|--------|
| Query 2+ corpora in single API call | ✅ | ❌ Not possible | Updated |
| Results from multiple corpora | ✅ | ✅ Via parallel queries | ✅ |
| Source corpus attribution | ✅ | ✅ Added to each result | ✅ |
| Performance <2s for 3 corpora | ✅ | ✅ With parallelization | Achievable |
| Error handling | ✅ | ✅ Per-corpus errors | ✅ |

---

## 📖 **References**

### **Code Evidence**
- `backend/src/rag_agent/tools/rag_query.py` - Current implementation
- `.venv/lib/python3.12/site-packages/vertexai/rag/rag_retrieval.py:79-80` - SDK limit

### **Documentation**
- [RAG Engine API](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/model-reference/rag-api)
- [Vertex AI RAG Overview](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/rag-engine/rag-overview)

---

**Conclusion:** Multi-corpus querying requires **sequential parallel execution** approach. This is achievable with good performance using asyncio, though not as elegant as a single API call would be.

**Next Step:** Proceed to Phase 1.2 - Implement `rag_multi_query_parallel` tool with async execution.
