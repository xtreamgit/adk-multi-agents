# Admin Section Audit — Post-Cleanup Review

**Date:** February 18, 2026  
**Context:** After Option A cleanup (strict Google Groups-only), verify all admin pages are clean

---

## Summary

**Status:** Several issues found that need cleanup

- ✅ **Corpus access:** Clean (5 bridge-managed entries only)
- ✅ **User→group assignments:** Clean (2 Workspace users only)
- ⚠️ **Orphaned chatbot users:** 8 users without app user records
- ⚠️ **Empty groups:** 2 groups with no users
- ⚠️ **Non-Workspace app users:** 7 test/example users
- ⚠️ **Inactive users:** 7 inactive app users
- ⚠️ **Unused corpora:** 3 active corpora with no group access

---

## 1. USERS (App Authentication)

**Active: 9 users**

| ID | Email | Domain | Google ID | Status |
|---|---|---|---|---|
| 1 | test@example.com | example.com | N | ⚠️ Non-Workspace |
| 5 | hector@develom.com | develom.com | N | ✅ Workspace user |
| 11 | mila@develom.com | develom.com | N | ✅ Workspace user |
| 15 | test-writer@develom.com | develom.com | N | ✅ Workspace user |
| 16 | alice@test.com | test.com | N | ⚠️ Non-Workspace |
| 17 | charlie@example.com | example.com | N | ⚠️ Non-Workspace |
| 18 | charlie_b376971e@example.com | example.com | N | ⚠️ Non-Workspace |
| 19 | charlie_08df027b@example.com | example.com | N | ⚠️ Non-Workspace |
| 20 | test@test.com | test.com | N | ⚠️ Non-Workspace |

**Inactive: 7 users**

| ID | Email | Status |
|---|---|---|
| 4 | testuser1768858532@example.com | ⚠️ Can be deleted |
| 6 | octavio@develom.com | ⚠️ Can be deleted |
| 7 | robert@develom.com | ⚠️ Can be deleted |
| 8 | test_1768859726@example.com | ⚠️ Can be deleted |
| 9 | test999@example.com | ⚠️ Can be deleted |
| 10 | robert.new@example.com | ⚠️ Can be deleted |
| 13 | robert.fresh@example.com | ⚠️ Can be deleted |

### Recommendations

**Non-Workspace users (7):**
- These users cannot be in Google Groups (not @develom.com)
- Under strict Google Groups-only policy, they should be deleted
- If they need access, add them to Google Workspace as external users

**Inactive users (7):**
- All appear to be test accounts
- Safe to delete (already inactive)

---

## 2. CHATBOT USERS

**Active: 11 users**

| ID | Email | Groups | Status |
|---|---|---|---|
| 2 | hector@develom.com | 1 | ✅ Bridge-synced |
| 4 | robert@develom.com | 0 | ⚠️ Orphaned (app user inactive) |
| 8 | marisol.fernandez@company.com | 0 | ⚠️ Orphaned (no app user) |
| 9 | trung.pham@company.com | 0 | ⚠️ Orphaned (no app user) |
| 12 | kavita.patel@company.com | 0 | ⚠️ Orphaned (no app user) |
| 15 | jun.mori@company.com | 0 | ⚠️ Orphaned (no app user) |
| 17 | ciara.oreilly@company.com | 0 | ⚠️ Orphaned (no app user) |
| 19 | jiawei.chen@company.com | 0 | ⚠️ Orphaned (no app user) |
| 20 | annika.muller@company.com | 0 | ⚠️ Orphaned (no app user) |
| 21 | alice@example.com | 0 | ⚠️ Orphaned (no app user) |
| 22 | mila@develom.com | 1 | ✅ Bridge-synced |

### Recommendations

**Orphaned chatbot users (8):**
- These were created during earlier testing
- They have no corresponding app user records
- They have no group assignments (we deleted them in Option A cleanup)
- **Action:** Delete all 8 orphaned chatbot users

**robert@develom.com:**
- Has chatbot user record but app user is inactive
- **Action:** Deactivate chatbot user or delete

---

## 3. CHATBOT GROUPS

| ID | Name | Active | Users | Corpora | Bridge-Managed | Status |
|---|---|---|---|---|---|---|
| 18 | viewer-group | Y | 1 | 1 | ✅ | ✅ In use |
| 19 | contributor-group | Y | 0 | 0 | ✅ | ⚠️ Empty |
| 20 | content-manager-group | Y | 0 | 0 | ✅ | ⚠️ Empty |
| 21 | admin-group | Y | 1 | 4 | ✅ | ✅ In use |

### Recommendations

**Empty groups (2):**
- `contributor-group` and `content-manager-group` have no users
- They are bridge-managed but no one is in the corresponding Google Groups
- **Action:** Keep them (they're part of the bridge mapping configuration)
- They will auto-populate when users join the Google Groups

---

## 4. CORPORA

**Active: 7 corpora**

| ID | Name | Groups | Status |
|---|---|---|---|
| 1 | ai-books | 1 | ✅ In use (admin-group) |
| 3 | design | 1 | ✅ In use (admin-group) |
| 4 | management | 2 | ✅ In use (admin-group, viewer-group) |
| 5 | recipes | 1 | ✅ In use (admin-group) |
| 6 | semantic-web | 0 | ⚠️ No group access |
| 7 | hacker-books | 0 | ⚠️ No group access |
| 17 | great-books | 0 | ⚠️ No group access |

**Inactive: 4 corpora**

| ID | Name | Status |
|---|---|---|
| 2 | test-corpus | ⚠️ Can be deleted |
| 11 | develom-general | ⚠️ Can be deleted |
| 14 | usfs-corpora | ⚠️ Can be deleted |
| 16 | fiction | ⚠️ Can be deleted |

### Recommendations

**Unused active corpora (3):**
- `semantic-web`, `hacker-books`, `great-books` have no group access
- They exist in Vertex AI but aren't mapped to any Google Groups
- **Options:**
  1. Create Google Groups for them (e.g., `corpus-semantic-web@develom.com`)
  2. Deactivate them if not needed
  3. Leave them (they can be accessed by creating mappings later)

**Inactive corpora (4):**
- Safe to delete (already inactive)

---

## 5. AGENTS

**Active: 4 agents**

| ID | Name | Status |
|---|---|---|
| 1 | default_agent | ✅ |
| 2 | agent1 | ✅ |
| 3 | agent2 | ✅ |
| 4 | agent3 | ✅ |

**No issues found.**

---

## 6. Cleanup Recommendations

### Priority 1: Delete Orphaned Chatbot Users

**8 chatbot users without app user records:**

```sql
DELETE FROM chatbot_users WHERE id IN (8, 9, 12, 15, 17, 19, 20, 21);
```

**1 chatbot user with inactive app user:**

```sql
UPDATE chatbot_users SET is_active = FALSE WHERE id = 4;  -- robert@develom.com
```

---

### Priority 2: Delete Non-Workspace App Users

**7 non-Workspace users (cannot use Google Groups):**

```sql
DELETE FROM users WHERE id IN (1, 16, 17, 18, 19, 20) AND email NOT LIKE '%@develom.com';
-- Note: Excludes user 15 (test-writer@develom.com) which IS a Workspace user
```

**Alternative:** If you want to keep test users for local development, keep them but understand they won't have Google Groups access.

---

### Priority 3: Delete Inactive App Users

**7 inactive test accounts:**

```sql
DELETE FROM users WHERE id IN (4, 6, 7, 8, 9, 10, 13);
```

---

### Priority 4: Clean Up Inactive Corpora

**4 inactive corpora:**

```sql
DELETE FROM corpora WHERE id IN (2, 11, 14, 16);
```

---

### Priority 5: Handle Unused Active Corpora (Optional)

**3 active corpora with no group access:**

Option A: Deactivate them
```sql
UPDATE corpora SET is_active = FALSE WHERE id IN (6, 7, 17);
```

Option B: Create Google Groups and mappings for them
```sql
-- Create groups in Google Workspace first, then:
INSERT INTO google_group_corpus_mappings (google_group_email, corpus_id, permission, is_active, created_by)
VALUES 
  ('corpus-semantic-web@develom.com', 6, 'query', TRUE, 5),
  ('corpus-hacker-books@develom.com', 7, 'query', TRUE, 5),
  ('corpus-great-books@develom.com', 17, 'query', TRUE, 5);
```

---

## 7. Complete Cleanup Script

```sql
-- 1. Delete orphaned chatbot users
DELETE FROM chatbot_users WHERE id IN (8, 9, 12, 15, 17, 19, 20, 21);

-- 2. Deactivate chatbot user with inactive app user
UPDATE chatbot_users SET is_active = FALSE WHERE id = 4;

-- 3. Delete non-Workspace app users (optional - keep if needed for local dev)
DELETE FROM users WHERE id IN (1, 16, 17, 18, 19, 20);

-- 4. Delete inactive app users
DELETE FROM users WHERE id IN (4, 6, 7, 8, 9, 10, 13);

-- 5. Delete inactive corpora
DELETE FROM corpora WHERE id IN (2, 11, 14, 16);

-- 6. Deactivate unused active corpora (optional)
UPDATE corpora SET is_active = FALSE WHERE id IN (6, 7, 17);

-- Verify final state
SELECT 'Active Users' as table_name, COUNT(*) as count FROM users WHERE is_active = TRUE
UNION ALL SELECT 'Active Chatbot Users', COUNT(*) FROM chatbot_users WHERE is_active = TRUE
UNION ALL SELECT 'Active Groups', COUNT(*) FROM chatbot_groups WHERE is_active = TRUE
UNION ALL SELECT 'Active Corpora', COUNT(*) FROM corpora WHERE is_active = TRUE
UNION ALL SELECT 'Corpus Access Entries', COUNT(*) FROM chatbot_corpus_access
UNION ALL SELECT 'User Group Assignments', COUNT(*) FROM chatbot_user_groups;
```

---

## 8. Expected Final State

After cleanup:

| Table | Current | After Cleanup |
|---|---|---|
| Active users | 9 | 3 (hector, mila, test-writer) |
| Active chatbot users | 11 | 2 (hector, mila) |
| Active groups | 4 | 4 (unchanged) |
| Active corpora | 7 | 4 (ai-books, design, management, recipes) |
| Corpus access entries | 5 | 5 (unchanged) |
| User group assignments | 2 | 2 (unchanged) |

**Result:** Clean database with only Workspace users and bridge-managed access control.
