# Google Groups Bridge — Two-Dimensional Mapping Model

**Date:** February 16, 2026  
**Purpose:** Explains how Google Groups map to agent types and corpus access independently, giving maximum flexibility.

---

## Overview

The Google Groups Bridge uses **two separate access dimensions** to control what a user can do and what data they can access:

1. **Agent Groups** — which agent type (tools/capabilities) the user gets
2. **Corpora Groups** — which corpora (data) the user can access

These are independent — a user can be in one agent group and multiple corpora groups.

---

## 1. Agent Groups (which agent type you get)

These control the tools and capabilities available to the user:

| Google Group | Agent Type | Tools |
|---|---|---|
| `rag-viewers@develom.com` | Viewer | `rag_query`, `list_corpora`, `browse_documents`, `set_current_corpus`, `get_corpus_info` |
| `rag-contributors@develom.com` | Contributor | All Viewer tools + `add_data` |
| `rag-content-managers@develom.com` | Content Manager | All Contributor tools + `delete_document`, `retrieve_document`, `rag_multi_query` |
| `rag-admins@develom.com` | Admin | All tools including `create_corpus`, `delete_corpus` |

**Mapping:** 1 Google Group → 1 Chatbot Group (4 rows total)

---

## 2. Corpora Groups (which corpora you can access)

These control which data the user can query/interact with:

| Google Group | Corpus Access |
|---|---|
| `corpus-ai-books@develom.com` | ai-books |
| `corpus-design@develom.com` | design |
| `corpus-management@develom.com` | management |
| `corpus-recipes@develom.com` | recipes |
| `corpus-great-books@develom.com` | great-books |
| `corpus-hacker-books@develom.com` | hacker-books |
| `corpus-semantic-web@develom.com` | semantic-web |

**Mapping:** 1 Google Group → 1 Corpus (1 row per corpus)

---

## 3. How They Combine

A user can be in **one agent group** + **multiple corpora groups**:

| User | Agent Group | Corpora Groups | Result |
|---|---|---|---|
| Alice | `rag-viewers` | `corpus-ai-books` | Can query ai-books only |
| Bob | `rag-contributors` | `corpus-ai-books`, `corpus-design` | Can query + add data to both |
| Carol | `rag-content-managers` | `corpus-management`, `corpus-recipes`, `corpus-design` | Can query, add, delete docs in 3 corpora |
| Dave | `rag-admins` | All corpus groups | Full access to everything |

---

## 4. How the Bridge Works

The sync process on each IAP login is simple:

1. **Read** the user's Google Groups (via Cloud Identity API)
2. **Find the highest-priority agent group** → assign that chatbot group (agent type)
3. **Find all matching corpus groups** → grant access to those corpora
4. **Cache** the result for 5 minutes (`GOOGLE_GROUPS_CACHE_TTL=300`)

No complex matrix needed. The two dimensions are resolved independently.

---

## 5. Scaling Considerations

**Total Google Groups needed:** `4 + N` (4 agent groups + 1 per corpus)

| Corpora Count | Total Groups | Manageable? |
|---|---|---|
| 7 (current) | 11 | Very easy |
| 20 | 24 | Easy |
| 50 | 54 | Still manageable |

**Adding a new corpus requires:**
1. Create one new Google Group in Google Admin Console
2. Add one mapping row via Admin UI (`/admin/google-groups` → Corpus tab)
3. Add users to the Google Group

**Alternative: Bundled Tiers**

If per-corpus granularity isn't needed, you can bundle corpora into tiers:

| Google Group | Corpora |
|---|---|
| `corpus-tier1@develom.com` | ai-books, great-books, recipes |
| `corpus-tier2@develom.com` | design, management |
| `corpus-all@develom.com` | All corpora |

This reduces the number of groups but sacrifices per-corpus control.

---

## 6. Configuration Steps (in order)

### Step 1: Create Google Groups (Google Admin Console — prerequisite)

The bridge **reads** Google Groups but does not create them. You must create them first.

Go to [Google Admin Console](https://admin.google.com) → **Directory** → **Groups** → **Create group**

**Agent Groups (4 groups):**

| Group Email | Group Name | Description |
|---|---|---|
| `rag-viewers@develom.com` | RAG Viewers | Read-only access to corpora |
| `rag-contributors@develom.com` | RAG Contributors | Can query and add data |
| `rag-content-managers@develom.com` | RAG Content Managers | Can manage documents |
| `rag-admins@develom.com` | RAG Admins | Full admin access |

**Corpus Groups (1 per corpus):**

| Group Email | Group Name | Description |
|---|---|---|
| `corpus-ai-books@develom.com` | Corpus: AI Books | Access to ai-books corpus |
| `corpus-design@develom.com` | Corpus: Design | Access to design corpus |
| `corpus-management@develom.com` | Corpus: Management | Access to management corpus |
| `corpus-recipes@develom.com` | Corpus: Recipes | Access to recipes corpus |
| `corpus-great-books@develom.com` | Corpus: Great Books | Access to great-books corpus |
| `corpus-hacker-books@develom.com` | Corpus: Hacker Books | Access to hacker-books corpus |
| `corpus-semantic-web@develom.com` | Corpus: Semantic Web | Access to semantic-web corpus |

### Step 2: Add users to Google Groups (Google Admin Console)

For each user, add them to:
- **One** agent group (their role/tier)
- **One or more** corpus groups (the data they need)

Example for user `alice@develom.com`:
- Add to `rag-viewers@develom.com` (agent tier)
- Add to `corpus-ai-books@develom.com` (corpus access)
- Add to `corpus-design@develom.com` (corpus access)

### Step 3: Create mappings in Admin UI (`/admin/google-groups`)

This tells the bridge how to translate Google Groups → app access.

**Agent Mappings tab (4 rows):**

| Google Group Email | Chatbot Group | Priority |
|---|---|---|
| `rag-viewers@develom.com` | Viewer | 25 |
| `rag-contributors@develom.com` | Contributor | 50 |
| `rag-content-managers@develom.com` | Content Manager | 75 |
| `rag-admins@develom.com` | Admin | 100 |

**Corpus Mappings tab (1 row per corpus):**

| Google Group Email | Corpus | Access Level |
|---|---|---|
| `corpus-ai-books@develom.com` | ai-books | read |
| `corpus-design@develom.com` | design | read |
| `corpus-management@develom.com` | management | read |
| ... | ... | read |

### Step 4: Verify

```bash
# Check bridge status
curl -s http://localhost:8000/api/admin/google-groups/status | python3 -m json.tool

# Should show enabled=true, mappings counts > 0
```

Users will auto-sync on their next IAP login.

---

## 7. Priority Rules

- **Agent groups:** If a user is in multiple agent groups, the one with the **highest priority value** wins. Set Admin=100, Content Manager=75, Contributor=50, Viewer=25.
- **Corpus groups:** All matching corpus groups are applied (additive, not exclusive).
- **Fallback:** If bridge sync fails, the user keeps their existing permissions (non-blocking).
