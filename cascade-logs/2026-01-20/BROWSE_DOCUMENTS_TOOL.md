# Browse Documents Tool Implementation

**Date:** January 20, 2026  
**Status:** ✅ Implemented

---

## Overview

Created a new agent tool `browse_documents` that allows the RAG agent to provide users with a clickable link to browse and preview/download documents from a corpus through a web interface.

---

## Implementation Details

### **1. Agent Tool: `browse_documents`**

**File:** `backend/src/rag_agent/tools/browse_documents.py`

**Purpose:** Generate a user-friendly link to the document browser with the corpus pre-selected.

**Parameters:**
- `corpus_name` (str): Name of the corpus to browse

**Returns:**
```python
{
    "status": "success",
    "message": "I've prepared the document browser for you...",
    "corpus_name": "ai-books",
    "browser_url": "http://localhost:3000/test-documents?corpus=ai-books",
    "instructions": [...]
}
```

**Features:**
- Validates corpus exists before generating link
- Uses `FRONTEND_URL` environment variable (defaults to `http://localhost:3000`)
- Provides clear user instructions
- Logs access for audit trail

---

### **2. Backend API Endpoint**

**File:** `backend/src/api/routes/documents.py`

**New Endpoint:** `GET /api/documents/corpus/{corpus_id}/list`

**Purpose:** List all documents in a corpus for the document browser.

**Security:**
- Validates user has access to corpus
- Returns 403 if unauthorized
- Logs access attempts

**Response:**
```json
{
  "status": "success",
  "corpus_id": 1,
  "corpus_name": "ai-books",
  "documents": [
    {
      "file_id": "abc123",
      "display_name": "Hands-On Large Language Models.pdf",
      "file_type": "pdf",
      "source_uri": "gs://...",
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "count": 1
}
```

---

### **3. Document Service Enhancement**

**File:** `backend/src/services/document_service.py`

**New Method:** `list_documents(corpus_resource_name: str)`

**Features:**
- Retrieves all files from Vertex AI RAG corpus
- Extracts metadata (file_id, display_name, file_type, source_uri, timestamps)
- Sorts documents alphabetically by name
- Handles different Vertex AI API structures
- Error handling and logging

---

### **4. Frontend Page Enhancement**

**File:** `frontend/src/app/test-documents/page.tsx`

**Changes:**
- Accepts `corpus` query parameter from URL
- Example: `/test-documents?corpus=ai-books`
- Passes parameter to `DocumentRetrievalPanel` component

---

### **5. Document Browser Component**

**File:** `frontend/src/components/DocumentRetrievalPanel.tsx`

**New Features:**

#### **Props:**
```typescript
interface DocumentRetrievalPanelProps {
  defaultCorpusId?: number;
  preselectedCorpusName?: string; // New prop
}
```

#### **Auto-Loading:**
1. When component loads with `preselectedCorpusName`:
   - Finds matching corpus by name
   - Pre-selects it in dropdown
   - Auto-loads document list

2. When user changes corpus:
   - Automatically loads documents from new corpus
   - Updates UI with loading state

#### **Document List UI:**
- Displays all documents in selected corpus
- Clickable list items
- Shows file type and creation date
- Hover effects for better UX
- Scrollable container (max height 96px)
- Click document to auto-fill name in input field

#### **Loading States:**
- Loading corpora spinner
- Loading documents spinner
- Empty state messages

---

### **6. Agent Integration**

**File:** `backend/src/rag_agent/agent.py`

**Updates:**
- Added `browse_documents` to imports
- Added to agent tools list
- Updated agent instructions:
  - Added capability description
  - Added usage guidelines
  - Updated tool documentation

**Agent Behavior:**

When user asks to:
- "Open file X"
- "Show me documents"
- "Browse documents in corpus Y"
- "View files"

Agent will:
1. Call `browse_documents` tool with corpus name
2. Receive clickable URL
3. Present link to user with instructions

**Example Response:**
```
I've prepared the document browser for you. You can view all documents 
in the 'ai-books' corpus.

Click the link to open the document browser: 
http://localhost:3000/test-documents?corpus=ai-books

The page will show all documents in the selected corpus. Click on any 
document name to preview it (PDFs) or download it (other formats).
```

---

## User Flow

### **1. User asks agent to browse documents:**
```
User: "Show me the documents in the ai-books corpus"
```

### **2. Agent calls browse_documents tool:**
```python
browse_documents(corpus_name="ai-books")
```

### **3. Agent responds with link:**
```
Agent: I've prepared the document browser for you...
       http://localhost:3000/test-documents?corpus=ai-books
```

### **4. User clicks link:**
- Browser opens test-documents page
- `corpus=ai-books` parameter in URL

### **5. Page auto-loads:**
- Loads all corpora
- Finds "ai-books" corpus
- Pre-selects it in dropdown
- Loads all documents from Vertex AI
- Displays document list

### **6. User interacts:**
- Sees list of documents
- Clicks document name → auto-fills input
- Clicks "Retrieve Document" → previews/downloads

---

## Technical Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     User Chat                            │
│  "Show me documents in ai-books corpus"                 │
└───────────────────┬─────────────────────────────────────┘
                    │
                    v
┌─────────────────────────────────────────────────────────┐
│                  RAG Agent                               │
│  - Receives request                                      │
│  - Calls browse_documents(corpus_name="ai-books")       │
└───────────────────┬─────────────────────────────────────┘
                    │
                    v
┌─────────────────────────────────────────────────────────┐
│            browse_documents Tool                         │
│  - Validates corpus exists                               │
│  - Generates URL: /test-documents?corpus=ai-books       │
│  - Returns clickable link                                │
└───────────────────┬─────────────────────────────────────┘
                    │
                    v
┌─────────────────────────────────────────────────────────┐
│                User Clicks Link                          │
└───────────────────┬─────────────────────────────────────┘
                    │
                    v
┌─────────────────────────────────────────────────────────┐
│           test-documents Page                            │
│  - Reads ?corpus=ai-books parameter                     │
│  - Passes to DocumentRetrievalPanel                     │
└───────────────────┬─────────────────────────────────────┘
                    │
                    v
┌─────────────────────────────────────────────────────────┐
│        DocumentRetrievalPanel Component                  │
│  - Loads all corpora from API                           │
│  - Finds corpus matching "ai-books"                     │
│  - Pre-selects in dropdown                              │
│  - Calls GET /api/documents/corpus/{id}/list           │
└───────────────────┬─────────────────────────────────────┘
                    │
                    v
┌─────────────────────────────────────────────────────────┐
│            Backend API Endpoint                          │
│  /api/documents/corpus/{corpus_id}/list                 │
│  - Validates user access to corpus                      │
│  - Calls DocumentService.list_documents()               │
└───────────────────┬─────────────────────────────────────┘
                    │
                    v
┌─────────────────────────────────────────────────────────┐
│           DocumentService                                │
│  - Calls rag.list_files(vertex_corpus_id)              │
│  - Extracts metadata from each file                     │
│  - Sorts alphabetically                                  │
│  - Returns document list                                 │
└───────────────────┬─────────────────────────────────────┘
                    │
                    v
┌─────────────────────────────────────────────────────────┐
│            Vertex AI RAG API                             │
│  - Returns RagFile objects with metadata                │
└───────────────────┬─────────────────────────────────────┘
                    │
                    v
┌─────────────────────────────────────────────────────────┐
│         Frontend Displays Document List                 │
│  - Shows all documents                                   │
│  - User clicks document name                             │
│  - Name auto-fills in input                              │
│  - User clicks "Retrieve Document"                       │
│  - Document previews or downloads                        │
└─────────────────────────────────────────────────────────┘
```

---

## Files Changed

### **Backend:**
1. `backend/src/rag_agent/tools/browse_documents.py` - New tool
2. `backend/src/rag_agent/tools/__init__.py` - Export new tool
3. `backend/src/rag_agent/agent.py` - Add tool to agent
4. `backend/src/api/routes/documents.py` - New list endpoint
5. `backend/src/services/document_service.py` - New list_documents method

### **Frontend:**
6. `frontend/src/app/test-documents/page.tsx` - Accept corpus parameter
7. `frontend/src/components/DocumentRetrievalPanel.tsx` - Auto-load documents

---

## Testing

### **1. Restart Backend:**
```bash
# Backend needs restart to load new tool
cd backend
python src/api/server.py
```

### **2. Test Agent Tool:**
In chat, ask:
```
"Show me the documents in the ai-books corpus"
```

Expected response:
- Agent calls `browse_documents` tool
- Returns clickable link
- Link includes `?corpus=ai-books` parameter

### **3. Test Document Browser:**
Click the link from agent response or navigate directly:
```
http://localhost:3000/test-documents?corpus=ai-books
```

Expected behavior:
- Page loads
- "ai-books" pre-selected in dropdown
- Document list appears automatically
- Shows all documents alphabetically
- Click document → name fills input
- Click "Retrieve Document" → preview/download works

### **4. Test Manual Corpus Selection:**
1. Go to `/test-documents` (no parameter)
2. Select corpus from dropdown
3. Documents auto-load
4. Click document to select
5. Retrieve works

---

## Configuration

### **Environment Variable:**
```bash
# Optional: Set custom frontend URL for production
export FRONTEND_URL=https://your-production-domain.com
```

Default: `http://localhost:3000`

---

## Security Features

1. **Access Control:**
   - Validates user has access to corpus before listing documents
   - Returns 403 if unauthorized

2. **Audit Logging:**
   - Agent tool logs when browse links are generated
   - API endpoint logs document list access

3. **Corpus Validation:**
   - Tool validates corpus exists before generating link
   - Returns error if corpus not found

---

## Benefits

✅ **User-Friendly:** Click link instead of manual navigation  
✅ **Context-Aware:** Pre-selects correct corpus automatically  
✅ **Visual Browse:** See all documents at once  
✅ **Quick Selection:** Click to select instead of typing  
✅ **Agent Integration:** Natural language commands to browse  
✅ **Download Support:** Preview PDFs, download other formats  

---

## Example Usage

### **Example 1: Browse Specific Corpus**
```
User: "Open the documents in ai-books"

Agent: I've prepared the document browser for you. You can view 
       all documents in the 'ai-books' corpus.
       
       Click here: http://localhost:3000/test-documents?corpus=ai-books
```

### **Example 2: Find Specific Document**
```
User: "Show me the LLM book file"

Agent: [Calls get_corpus_info to find file name]
       The document is "Hands-On Large Language Models.pdf"
       
       [Then calls browse_documents]
       Click here to browse: http://localhost:3000/test-documents?corpus=ai-books
```

### **Example 3: List All Documents**
```
User: "What documents are in the design corpus?"

Agent: [Calls get_corpus_info]
       The design corpus contains 5 documents:
       1. Design Patterns.pdf
       2. UI UX Fundamentals.pdf
       ...
       
       [Then calls browse_documents]
       View and download: http://localhost:3000/test-documents?corpus=design
```

---

## Summary

**Problem:** Users needed easy way to browse and access corpus documents  
**Solution:** Agent tool generates links to document browser with auto-loaded document list  
**Result:** Seamless workflow from chat to document preview/download  

**User says:** "Show me documents"  
**Agent provides:** Clickable link  
**Page shows:** All documents, ready to preview/download  

✅ **Implementation complete - ready for testing!**
