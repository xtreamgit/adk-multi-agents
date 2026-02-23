# Service Account Group Membership: Implementation Guide

**Author:** Hector DeJesus  
**Date:** February 18, 2026  
**Status:** Validated — 28/28 integration tests passing  
**Audience:** Client technical team / DevOps

---

## Executive Summary

The ADK RAG application uses the **Google Cloud Identity API** to determine which Google Groups a user belongs to, then automatically assigns them the correct chatbot group and corpus access permissions. This replaces the previous Admin SDK approach that required Domain-Wide Delegation and a Workspace admin account.

The Cloud Identity API requires that the calling identity (our Cloud Run service account) has **visibility into the organization's Google Groups directory**. We achieve this by adding the service account as a **member of each application-related Google Group**. This document explains why this is necessary, how to implement it, and the operational procedures to maintain it.

---

## Table of Contents

1. [Why the Service Account Needs Group Membership](#1-why-the-service-account-needs-group-membership)
2. [How It Works](#2-how-it-works)
3. [Initial Setup](#3-initial-setup)
4. [Operational Procedures](#4-operational-procedures)
5. [Alternatives Considered](#5-alternatives-considered)
6. [Security Considerations](#6-security-considerations)
7. [Monitoring and Health Checks](#7-monitoring-and-health-checks)
8. [Validated Test Results](#8-validated-test-results)
9. [FAQ](#9-faq)

---

## 1. Why the Service Account Needs Group Membership

The Cloud Identity `groups:search` API endpoint returns only groups that are **visible to the calling identity**. A GCP service account is not a Google Workspace user — it has no presence in the Workspace directory by default. This means:

| Caller | `groups:search` Result |
|---|---|
| Workspace user (e.g., `hector@develom.com`) | All 10 org groups |
| Service account (before fix) | **0 groups** |
| Service account (after adding to groups) | **All 10 org groups** |

By adding the service account as a **MEMBER** of each Google Group, it becomes a recognized participant in the Workspace directory and gains visibility into those groups.

### What This Replaces

Previously, the application used **Domain-Wide Delegation (DWD)** to impersonate a Workspace admin user. This required:

- A real admin email address hardcoded in environment variables
- DWD configured in the Admin Console (Security → API Controls)
- The `iam.serviceAccountTokenCreator` IAM role for JWT signing on Cloud Run
- ~40 lines of complex credential handling code

The SA-in-Groups approach eliminates **all** of these requirements. The service account authenticates as itself using standard Application Default Credentials.

---

## 2. How It Works

### Authentication Flow

```
User logs in via IAP
        │
        ▼
Backend receives authenticated request
        │
        ▼
Google Groups Bridge checks cache (5-min TTL)
        │
        ├── Cache hit → Use cached groups
        │
        └── Cache miss → Call Cloud Identity API
                │
                ▼
        Step 1: groups:search
        (List all org groups visible to the SA)
                │
                ▼
        Step 2: checkTransitiveMembership
        (For each group, check if the user is a member)
                │
                ▼
        Return list of groups the user belongs to
                │
                ▼
        Map groups → chatbot group + corpus access
                │
                ▼
        Cache result for 5 minutes
```

### API Calls

| Step | API Endpoint | Purpose |
|---|---|---|
| 1 | `GET /v1/groups:search` | List all org groups (filtered by customer ID) |
| 2 | `GET /v1/groups/{id}/memberships:checkTransitiveMembership` | Check if user is a member (supports nested groups) |

For an organization with N groups, this makes **1 + N API calls** per uncached user login. With 10 groups, this adds ~500ms-1s of latency on the first request, then zero latency for the next 5 minutes (cache).

---

## 3. Initial Setup

### Prerequisites

- Google Cloud project with Cloud Identity API enabled
- Cloud Run service account (e.g., `backend-sa@adk-rag-ma.iam.gserviceaccount.com`)
- Google Workspace organization with Google Groups configured

### Step 1: Enable the Cloud Identity API

```bash
gcloud services enable cloudidentity.googleapis.com --project=adk-rag-ma
```

### Step 2: Find Your Customer ID

```bash
gcloud organizations describe 554687400902 \
  --format="value(owner.directoryCustomerId)"
# Output: C01xpu8ag
```

### Step 3: Add the Service Account to All Application-Related Groups

This can be done via:

**Option A: Google Groups Web UI**
1. Go to [groups.google.com](https://groups.google.com)
2. Open each group → Members → Add members
3. Enter: `backend-sa@adk-rag-ma.iam.gserviceaccount.com`
4. Role: **Member**

**Option B: Google Admin Console**
1. Go to [admin.google.com](https://admin.google.com) → Directory → Groups
2. Open each group → Members → Add
3. Enter the SA email, role: Member

**Option C: Programmatic (Cloud Identity API)**

Requires a user with group management permissions:

```bash
# Get access token for a Workspace user with group management permissions
TOKEN=$(gcloud auth print-access-token)

# For each group, add the SA as a member
# Replace GROUP_NAME with the group resource name (e.g., groups/00haapch2lsvwro)
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "https://cloudidentity.googleapis.com/v1/${GROUP_NAME}/memberships" \
  -d '{
    "preferredMemberKey": {
      "id": "backend-sa@adk-rag-ma.iam.gserviceaccount.com"
    },
    "roles": [{"name": "MEMBER"}]
  }'
```

### Step 4: Set Environment Variables

```bash
# Required
GOOGLE_GROUPS_ENABLED=true
GOOGLE_GROUPS_API_MODE=cloud_identity
GOOGLE_GROUPS_CUSTOMER_ID=C01xpu8ag

# Optional (for local development with user ADC)
GOOGLE_GROUPS_QUOTA_PROJECT=adk-rag-ma
```

### Current Group Inventory

The following groups are configured in the `develom.com` organization as of February 18, 2026:

| Google Group | Purpose | SA Added |
|---|---|---|
| `rag-admins@develom.com` | Admin-level access | ✅ |
| `rag-content-managers@develom.com` | Content management access | ✅ |
| `rag-contributors@develom.com` | Contributor access | ✅ |
| `rag-viewers@develom.com` | Read-only access | ✅ |
| `corpus-ai-books@develom.com` | AI Books corpus access | ✅ |
| `corpus-design@develom.com` | Design corpus access | ✅ |
| `corpus-management@develom.com` | Management corpus access | ✅ |
| `corpus-recipes@develom.com` | Recipes corpus access | ✅ |
| `rag-app-test-users@develom.com` | Test users | ✅ |
| `adk-rag-agent-email@develom.com` | Agent notification group | ✅ |

---

## 4. Operational Procedures

### When a New Google Group Is Created

**Action required:** Add the service account as a member of the new group.

```
Who:     Workspace admin or group owner
When:    Immediately after creating the group
How:     Add backend-sa@adk-rag-ma.iam.gserviceaccount.com as a MEMBER
Impact:  Without this step, the new group will NOT appear in the
         application's group search results, and users in that group
         will not receive the associated permissions.
```

### When a Google Group Is Deleted

**No action required.** The `groups:search` API will no longer return the deleted group, and the `checkTransitiveMembership` call will simply return "not a member." The application handles this gracefully.

### When the Service Account Is Rotated or Replaced

**Action required:** Add the new service account to all application-related groups and remove the old one.

1. Add the new SA email to all groups (see Step 3 above)
2. Update the Cloud Run service configuration to use the new SA
3. Optionally remove the old SA from all groups

### When Deploying to a New Environment

**Action required:** Repeat Step 3 for the new environment's service account.

Each environment (dev, staging, production) has its own service account. Each must be added to the relevant groups independently.

---

## 5. Alternatives Considered

### Alternative A: Groups Reader Admin Role

Assign the Workspace "Groups Reader" admin role to the service account via the Admin Console. This grants org-wide read access to all groups without requiring individual group membership.

| Aspect | SA-in-Groups (Chosen) | Groups Reader |
|---|---|---|
| **Maintenance** | Must add SA to each new group | Zero maintenance |
| **Admin Console required** | No | Yes (one-time role assignment) |
| **Workspace admin role on SA** | No | Yes (read-only) |
| **SA appears in group member lists** | Yes | No |
| **New groups auto-visible** | No — must add SA | Yes — automatic |
| **Principle of least privilege** | Stronger — SA only sees groups it's in | Weaker — SA sees all org groups |

**Why we chose SA-in-Groups:** It requires zero Workspace admin roles, follows the principle of least privilege, and keeps the "no admin access required" benefit of the Cloud Identity API refactor. The operational overhead of adding the SA to new groups is minimal for organizations with a stable group structure.

### Alternative B: Domain-Wide Delegation (Previous Approach)

The original implementation. Rejected due to complexity, fragility, and dependency on a human admin account. See the [Cloud Identity API Refactor document](../2026-02-17/CLOUD-IDENTITY-API-REFACTOR-02-17-26.md) for the full comparison.

### Alternative C: Automation Script

A Cloud Function or cron job that periodically checks for new groups and adds the SA automatically. This could be added as a future enhancement if the group structure changes frequently.

---

## 6. Security Considerations

### What the Service Account Can Do

| Action | Permitted |
|---|---|
| List groups it is a member of | ✅ |
| Check if a user is a member of those groups | ✅ |
| Create, modify, or delete groups | ❌ |
| Add or remove group members | ❌ |
| Access group conversations or files | ❌ |
| Access user directory information | ❌ |

The SA uses the **read-only** scope `cloud-identity.groups.readonly`. It cannot modify any group or membership data.

### Service Account Identity

| Property | Value |
|---|---|
| **Email** | `backend-sa@adk-rag-ma.iam.gserviceaccount.com` |
| **Project** | `adk-rag-ma` |
| **OAuth Scope** | `https://www.googleapis.com/auth/cloud-identity.groups.readonly` |
| **Workspace Admin Roles** | None |
| **Domain-Wide Delegation** | Not configured |

### Comparison to Previous Approach

| Security Aspect | Admin SDK + DWD (Before) | SA-in-Groups (After) |
|---|---|---|
| **Admin impersonation** | Yes — SA impersonates a real admin | No |
| **DWD configured** | Yes — broad delegation scope | No |
| **Admin Console config** | Required | Not required |
| **Blast radius if SA compromised** | Full admin directory read access | Read-only access to groups SA is a member of |
| **Audit trail** | Actions appear as the impersonated admin | Actions appear as the SA itself |

---

## 7. Monitoring and Health Checks

### Recommended Health Check

Add a periodic check (e.g., daily) that verifies the SA can see all expected groups:

```python
# Pseudocode for health check
expected_groups = get_expected_groups_from_database()
visible_groups = call_groups_search_as_sa()

missing = expected_groups - visible_groups
if missing:
    alert(f"SA cannot see {len(missing)} groups: {missing}")
    # Action: Add SA to missing groups
```

### Logging

The application logs the following on each bridge sync:

```
INFO: Bridge sync for user@domain.com: groups=10, chatbot_group=admin-group, corpora=4, cached=True
```

If a user reports missing permissions, check:
1. Is the user a member of the expected Google Group?
2. Can the SA see that group? (Check `groups:search` results)
3. Is the group mapped in `google_group_agent_mappings` or `google_group_corpus_mappings`?

### Key Metrics to Monitor

| Metric | Expected | Alert If |
|---|---|---|
| Groups visible to SA | 10 (current) | Decreases unexpectedly |
| Bridge sync success rate | ~100% | Falls below 95% |
| Cache hit rate | >90% during normal usage | Falls below 50% |
| API latency (uncached) | 500ms-1s | Exceeds 5s |

---

## 8. Validated Test Results

Integration testing was performed on **February 18, 2026** against the live `develom.com` organization.

### Test Suite: 28 Assertions Passed, 0 Failed

| # | Test | Result |
|---|---|---|
| 1 | ADC credential acquisition | ✅ |
| 2 | `groups:search` — list all org groups | ✅ (10 groups) |
| 3 | `checkTransitiveMembership` — per-group membership check | ✅ (10/10) |
| 4 | Service layer `_query_cloud_identity()` | ✅ (10 groups) |
| 5 | Public API `get_user_groups()` | ✅ (10 groups) |
| 6 | Edge case: non-member email → empty list | ✅ |
| 7 | Edge case: invalid email → graceful handling | ✅ |
| 8 | Edge case: missing customer ID → clear error | ✅ |
| 9 | Fallback: Cloud Identity failure → Admin SDK | ✅ |
| 10 | Cache: write → read → TTL expiry | ✅ |
| 11 | SA credentials: `groups:search` returns all groups | ✅ (10 groups) |
| 12 | Consistency: raw API vs service layer results | ✅ (identical) |

### End-to-End Validation

| Test | Result |
|---|---|
| Force sync single user (`POST /sync/5`) | ✅ — 10 groups, `admin-group`, 4 corpora |
| Sync all org users (`POST /sync-all`) | ✅ — 3 users synced |
| Login flow (IAP → bridge → group assignment) | ✅ — confirmed in backend logs |

---

## 9. FAQ

**Q: What happens if we forget to add the SA to a new group?**  
A: Users in that group will not receive the associated chatbot group or corpus access. The application will not error — it simply won't see the group. This can be detected by monitoring the number of visible groups.

**Q: Does the SA need to be an OWNER or MANAGER of the group?**  
A: No. **MEMBER** role is sufficient. The SA only needs read visibility, not management permissions.

**Q: Will the SA receive group emails?**  
A: By default, yes. To prevent this, set the SA's delivery preference to "No email" in the group membership settings. Since the SA is not a real mailbox, emails sent to the group will simply bounce for the SA — this has no operational impact.

**Q: Can we automate adding the SA to new groups?**  
A: Yes. A Cloud Function triggered by Google Workspace audit logs (group creation events) could automatically add the SA. This is a future enhancement if the group structure changes frequently.

**Q: What if the SA is removed from a group accidentally?**  
A: Users in that group will lose their auto-synced permissions on their next uncached login (after the 5-minute cache expires). Re-adding the SA to the group restores functionality immediately.

**Q: How does this compare to the old Admin SDK approach in terms of reliability?**  
A: The SA-in-Groups approach is more reliable because it has no dependency on a human admin account. The service account is a stable, infrastructure-managed identity that won't be disabled, renamed, or have its password changed.

**Q: Is there a limit to how many groups the SA can be a member of?**  
A: Google Workspace allows a user/SA to be a member of up to 2,000 groups. This is well above the expected number of application-related groups.

---

## Document References

- [Cloud Identity API Refactor (Feb 17, 2026)](../2026-02-17/CLOUD-IDENTITY-API-REFACTOR-02-17-26.md) — Full technical comparison of Admin SDK vs Cloud Identity API
- [Security Risk Assessment (Feb 17, 2026)](../2026-02-17/SECURITY-RISK-ASSESSMENT-02-17-26.md) — Security analysis of the authentication approaches
- [Integration Test Script](../../backend/tests/test_cloud_identity_integration.py) — Automated test suite (12 tests, 28 assertions)
