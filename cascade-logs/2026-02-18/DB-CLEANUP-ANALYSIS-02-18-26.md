# Database Cleanup Analysis — Pre-Bridge Manual Assignments

**Date:** February 18, 2026  
**Context:** Transition from manual UI-based access control to Google Groups Bridge automation

---

## Executive Summary

The database contains **11 manual corpus access entries** that were granted via the admin UI before the Google Groups Bridge was implemented. These entries may conflict with the new automated access control approach and should be reviewed for cleanup.

**Key Finding:** All user→group assignments are already bridge-managed (6 entries). No cleanup needed for `chatbot_user_groups`.

---

## 1. Manual Corpus Access Entries (11 total)

These were granted via the admin UI and have `granted_by` set to a user ID (not NULL).

| ID | Group | Corpus | Permission | Granted Date | Granted By | Status | Recommendation |
|---|---|---|---|---|---|---|
| 1 | viewer-group | ai-books | query | 2026-02-04 | user 16 | ⚠️ **CONFLICT** | DELETE — now managed by bridge |
| 3 | viewer-group | design | query | 2026-02-04 | user 16 | ⚠️ **CONFLICT** | DELETE — now managed by bridge |
| 4 | contributor-group | design | query | 2026-02-04 | user 16 | ⚠️ **LEGACY** | DELETE — no corpus mapping for this |
| 2 | content-manager-group | management | query | 2026-02-04 | user 16 | ⚠️ **LEGACY** | DELETE — no corpus mapping for this |
| 24 | content-manager-group | hacker-books | query | 2026-02-09 | user 5 | ⚠️ **LEGACY** | DELETE — no corpus mapping for this |
| 25 | content-manager-group | design | query | 2026-02-09 | user 5 | ⚠️ **LEGACY** | DELETE — no corpus mapping for this |
| 21 | admin-group | management | query | 2026-02-06 | user 16 | ⚠️ **LEGACY** | DELETE — no corpus mapping for this |
| 22 | admin-group | recipes | query | 2026-02-06 | user 16 | ⚠️ **LEGACY** | DELETE — no corpus mapping for this |
| 23 | admin-group | semantic-web | query | 2026-02-06 | user 16 | ⚠️ **LEGACY** | DELETE — no corpus mapping for this |
| 26 | admin-group | design | query | 2026-02-11 | user 5 | ⚠️ **LEGACY** | DELETE — no corpus mapping for this |
| 27 | admin-group | ai-books | admin | 2026-02-11 | user 5 | ⚠️ **LEGACY** | DELETE — no corpus mapping for this |

### Analysis

**Conflict Entries (3):**
- IDs 1, 3: `viewer-group` has manual access to `ai-books` and `design`, but these are NOT mapped in `google_group_corpus_mappings`. The bridge added `management` (ID 341) today when Mila synced, but the other two are orphaned manual grants.

**Legacy Entries (8):**
- IDs 2, 4, 21-27: These were manually granted to groups that have NO corresponding Google Group corpus mappings. They represent the old manual access control model and should be removed.

**Current Bridge Mappings:**
```
corpus-ai-books@develom.com      → ai-books (admin)
corpus-design@develom.com        → design (query)
corpus-management@develom.com    → management (query)
corpus-recipes@develom.com       → recipes (query)
```

None of the manual entries align with these mappings except for the bridge-created ones (IDs 19, 341).

---

## 2. Bridge-Managed Corpus Access (2 total)

These have `granted_by = NULL` and were created by the bridge.

| ID | Group | Corpus | Permission | Granted Date | Status |
|---|---|---|---|---|---|
| 19 | admin-group | hacker-books | query | 2026-02-06 | ✅ **KEEP** — bridge-managed |
| 341 | viewer-group | management | query | 2026-02-18 | ✅ **KEEP** — bridge-managed |

**Note:** ID 19 is odd — it's marked as bridge-managed (granted_by=NULL) but was created on Feb 6, before the bridge was fully implemented. This may have been a test or early prototype. However, there's no `corpus-hacker-books@develom.com` Google Group, so this entry is orphaned.

**Recommendation:** DELETE ID 19 — no corresponding Google Group corpus mapping exists.

---

## 3. User→Group Assignments (6 total)

All current assignments are in **bridge-managed groups** (admin-group, viewer-group, content-manager-group, contributor-group).

| ID | Email | Group | Joined Date | Status |
|---|---|---|---|---|
| 26 | annika.muller@company.com | content-manager-group | 2026-02-04 | ⚠️ **REVIEW** — not a develom.com user, no Google Groups cache |
| 28 | hector@develom.com | admin-group | 2026-02-04 | ✅ **KEEP** — synced via bridge (10 groups) |
| 30 | alice@example.com | admin-group | 2026-02-05 | ⚠️ **REVIEW** — not a develom.com user, no Google Groups cache |
| 31 | jiawei.chen@company.com | admin-group | 2026-02-06 | ⚠️ **REVIEW** — not a develom.com user, no Google Groups cache |
| 32 | ciara.oreilly@company.com | content-manager-group | 2026-02-06 | ⚠️ **REVIEW** — not a develom.com user, no Google Groups cache |
| 111 | mila@develom.com | viewer-group | 2026-02-18 | ✅ **KEEP** — synced via bridge (2 groups) |

### Analysis

**Bridge-synced users (2):**
- `hector@develom.com` — in `admin-group` via `rag-admins@develom.com` mapping
- `mila@develom.com` — in `viewer-group` via `rag-viewers@develom.com` mapping

**Non-Workspace users (4):**
- `annika.muller@company.com`, `alice@example.com`, `jiawei.chen@company.com`, `ciara.oreilly@company.com`
- These are NOT `@develom.com` users, so they will never appear in Google Workspace Groups
- They were manually assigned to chatbot groups via the admin UI
- **Decision needed:** Should non-Workspace users be allowed? If yes, keep these. If no (Google Groups-only), delete them.

---

## 4. Cleanup Recommendations

### Option A: Strict Google Groups-Only (Recommended)

**Principle:** Only Google Groups Bridge controls access. All manual assignments are removed.

**Actions:**
1. **DELETE all 11 manual corpus access entries** (IDs: 1, 2, 3, 4, 21, 22, 23, 24, 25, 26, 27)
2. **DELETE orphaned bridge entry** (ID: 19 — hacker-books has no Google Group mapping)
3. **DELETE non-Workspace user assignments** (IDs: 26, 30, 31, 32 — @company.com and @example.com users)
4. **KEEP bridge-synced entries:**
   - Corpus access: ID 341 (viewer-group → management)
   - User groups: IDs 28, 111 (hector, mila)

**Result:** Clean slate. Only Google Groups control access. Non-Workspace users lose access.

---

### Option B: Hybrid (Manual + Bridge)

**Principle:** Google Groups Bridge manages `@develom.com` users. Non-Workspace users can be manually assigned.

**Actions:**
1. **DELETE all 11 manual corpus access entries** (IDs: 1, 2, 3, 4, 21, 22, 23, 24, 25, 26, 27)
2. **DELETE orphaned bridge entry** (ID: 19)
3. **KEEP non-Workspace user assignments** (IDs: 26, 30, 31, 32)
4. **Manually grant corpus access to non-Workspace user groups** if needed (via admin UI or SQL)

**Result:** Google Groups control Workspace users. Non-Workspace users managed manually.

---

## 5. SQL Cleanup Scripts

### Option A: Strict Google Groups-Only

```sql
-- 1. Delete all manual corpus access entries
DELETE FROM chatbot_corpus_access WHERE id IN (1, 2, 3, 4, 21, 22, 23, 24, 25, 26, 27);

-- 2. Delete orphaned bridge entry (hacker-books)
DELETE FROM chatbot_corpus_access WHERE id = 19;

-- 3. Delete non-Workspace user group assignments
DELETE FROM chatbot_user_groups WHERE id IN (26, 30, 31, 32);

-- 4. Verify remaining entries
SELECT 'Corpus Access' as table_name, COUNT(*) as remaining FROM chatbot_corpus_access
UNION ALL
SELECT 'User Groups', COUNT(*) FROM chatbot_user_groups;
```

**Expected result:**
- `chatbot_corpus_access`: 1 entry (ID 341 — viewer-group → management)
- `chatbot_user_groups`: 2 entries (IDs 28, 111 — hector, mila)

---

### Option B: Hybrid (Manual + Bridge)

```sql
-- 1. Delete all manual corpus access entries
DELETE FROM chatbot_corpus_access WHERE id IN (1, 2, 3, 4, 21, 22, 23, 24, 25, 26, 27);

-- 2. Delete orphaned bridge entry (hacker-books)
DELETE FROM chatbot_corpus_access WHERE id = 19;

-- 3. Keep non-Workspace user assignments (no action)

-- 4. Verify remaining entries
SELECT 'Corpus Access' as table_name, COUNT(*) as remaining FROM chatbot_corpus_access
UNION ALL
SELECT 'User Groups', COUNT(*) FROM chatbot_user_groups;
```

**Expected result:**
- `chatbot_corpus_access`: 1 entry (ID 341)
- `chatbot_user_groups`: 6 entries (all current assignments)

---

## 6. Post-Cleanup Validation

After cleanup, run the bridge validation test to ensure everything still works:

```bash
cd backend
source .venv/bin/activate
python tests/test_bridge_validation.py --email hector@develom.com
python tests/test_bridge_validation.py --email mila@develom.com
```

Expected results:
- `hector@develom.com`: 10 Google Groups → `admin-group` → 4 corpora (ai-books admin, design/management/recipes query)
- `mila@develom.com`: 2 Google Groups → `viewer-group` → 1 corpus (management query)

---

## 7. Decision Matrix

| Scenario | Option A (Strict) | Option B (Hybrid) |
|---|---|---|
| **Workspace users** | ✅ Managed by Google Groups | ✅ Managed by Google Groups |
| **Non-Workspace users** | ❌ Lose access | ✅ Manually managed |
| **Corpus access** | ✅ Only via Google Group mappings | ⚠️ Manual grants allowed for non-Workspace users |
| **Maintenance** | ✅ Zero manual work | ⚠️ Manual grants for non-Workspace users |
| **Audit trail** | ✅ All access via Google Groups | ⚠️ Mixed (Google Groups + manual) |
| **Simplicity** | ✅ Single source of truth | ⚠️ Two sources of truth |

---

## 8. Recommendation

**Choose Option A (Strict Google Groups-Only)** unless you have a specific business requirement to support non-Workspace users.

**Rationale:**
1. The entire refactor was designed to eliminate manual access control
2. Non-Workspace users can be added to Google Workspace as external users if needed
3. Single source of truth (Google Groups) is easier to audit and maintain
4. No risk of manual grants conflicting with bridge automation

If non-Workspace users are required, they should be added to Google Workspace as external/guest users, then added to the appropriate Google Groups. This keeps the access control model consistent.
