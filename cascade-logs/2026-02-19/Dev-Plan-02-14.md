# ADK Multi-Agent RAG — Prioritized Task List

> **Last updated:** 2026-02-15
> Items are prioritized by functional dependency — tasks that other features depend on come first.

---

## Priority Legend

| Priority | Meaning |
|----------|---------|
| **Critical** | Blocks other work, causes data loss/integrity issues, or breaks core functionality |
| **High** | Core user experience or important architectural work |
| **Medium** | Improves UX, fixes non-blocking bugs, or adds useful features |
| **Low** | Future enhancements, polish, and nice-to-haves |

## Classification Legend

| Tag | Scope |
|-----|-------|
| `system` | Deployment, infrastructure, environment bootstrapping |
| `backend` | Python services, API endpoints, data processing |
| `frontend` | React/Next.js UI components, pages, styling |
| `IAM` | Service accounts, roles, groups, access control |
| `logging` | Observability, metrics, debug output |

---

## Critical

These must be resolved first — other tasks depend on them or they affect data integrity and availability.

| # | Task | Classification | Tags | Description |
|---|------|---------------|------|-------------|
| C-1 | Create deployment defaults | system | `#deployment` `#bootstrap` | Create default corpora, groups, users, agents, roles, IAM groups, and IAM roles during deployment so new environments start without errors. This is the foundation all other features assume exists. |
### C1 - Status: in-progress

| C-2 | Implement IAM group management interface | IAM, frontend | `#iam` `#admin` `#groups` | In `/admin/groups`, replace the current Group Management page with an interface that integrates with Google Cloud IAM group definitions. Research the best approach to leverage IAM groups as the source of truth for app-level group membership. Before the sync will actually work, the operator also needs to verify:
Cloud Identity API is enabled (already in prerequisites.sh)
The service account may need domain-wide delegation configured in Google Workspace Admin Console with scope https://www.googleapis.com/auth/cloud-identity.groups.readonly — this is a manual step in the Workspace admin UI, not something the deploy script can do|
### C2 - Status: CANCELLED - NOT RELEVANT ANYMORE


| C-3 | Implement IAM role assignment and removal | IAM, backend | `#iam` `#roles` `#auth` | Roles currently cannot be removed once assigned. Design and implement a proper IAM role lifecycle — create, assign to groups, and revoke — so that access control changes propagate correctly. |

| C-4 | Assign agent tools to groups and users | IAM, backend | `#iam` `#agents` `#access-control` | Agent tools (RAG query, document upload, etc.) should be grantable per-group and per-user. Without this, all users have access to all tools regardless of their role. |

| C-5 | Prevent corpus creation against folders with subfolders | backend | `#corpus` `#data-integrity` `#validation` | Validate that users only create corpora against GCS "folders" (prefixes) with no nested subfolders. A subfolder corpus (e.g. `fiction/` inside `usfs-corpora/`) can be silently deleted when the parent is managed, breaking all queries against it. |

| C-6 | Fix Vertex AI sync in `/admin/corpora` | backend | `#sync` `#bug` `#admin` | "Sync with Vertex AI" produces stale results — deleted corpora still appear in the list, and some lists update while others do not. Diagnose whether the issue is in the sync service, the DB query, or the frontend cache. |

| C-7 | Fix save button in `/admin/corpora` edit field | frontend, backend | `#bug` `#admin` `#corpus` | The save button in the corpus metadata edit panel does not persist changes. Determine whether the issue is in the API call, the request payload, or the UI state management. |

| C-8 | Handle Vertex AI 429 RESOURCE_EXHAUSTED errors | backend, frontend | `#error-handling` `#resilience` | Implement graceful handling for `429 RESOURCE_EXHAUSTED` errors from Vertex AI. Add retry with exponential backoff on the backend and show a user-friendly message on the frontend instead of a raw JSON error. |

---

## High

Core experience and architectural work that directly impacts daily use.

| # | Task | Classification | Tags | Description |
|---|------|---------------|------|-------------|
| H-1 | Set a default corpus for new sessions | backend, frontend | `#corpus` `#ux` `#session` | Automatically select one corpus as the default when a user starts a chat session so the conversation can begin without requiring manual corpus selection first. |

| H-2 | Live-update corpora list on access changes | frontend, backend | `#corpus` `#access-control` `#realtime` | When an admin adds, removes, activates, or deactivates corpus access for a group, the affected users' available corpora list should update without requiring a page refresh or re-login. |

| H-3 | Assign default group on user creation | backend, frontend | `#users` `#groups` `#onboarding` | When creating a new user, automatically assign them to a default group and provide a multi-select option to add them to additional groups during creation. |
| H-4 | Add corpus metadata on creation | frontend, backend | `#corpus` `#metadata` `#admin` | When a corpus is created, capture structured metadata: owning group, data source, data type, creation date, author, and purpose. Expose this via a dialog accessible from the corpus management UI. This enables reporting and data governance. |
| H-5 | Manage corpora and bucket inventory | backend, frontend | `#corpus` `#buckets` `#inventory` | Build an inventory view of all GCS buckets used by corpora, showing which teams/groups use each bucket. Supports the case where multiple teams share a bucket or a single team uses multiple buckets. |
| H-6 | Revise agent/tool categorization | frontend, backend | `#agents` `#tools` `#admin` | In `/chatbot-agents`, the current count of tools vs. agent categories is inconsistent. Audit the tool-to-agent mapping and correct the categorization so admins see accurate assignments. |
| H-7 | Restructure navigation — hide Application Management | frontend | `#navigation` `#rbac` `#ux` | Replace the "Application Management" menu category with a "Settings" section visible only to super-users. Regular users should not see administrative menu items at all. |
| H-8 | Remove or hide legacy chatbot access pages | frontend | `#navigation` `#cleanup` | Hide or remove the Chatbot Group, Chatbot User, and Chatbot Corpora Access (`/chatbot-corpora`) pages. These are superseded by the admin group/corpus management. |
| H-9 | Test corpus selection isolation | backend | `#testing` `#corpus` `#qa` | Verify that when a user selects specific corpora, only those corpora are queried during the session. No cross-corpus leakage should occur. |
| H-10 | Test multi-corpus queries end-to-end | backend | `#testing` `#corpus` `#qa` | Run real user queries against multiple selected corpora simultaneously and verify that results correctly attribute sources to the right corpus. |
| H-11 | Verify all corpora accessible in UI | frontend | `#testing` `#corpus` `#qa` | Confirm that all active corpora appear in the user-facing corpus selector and admin corpus list. |
| H-12 | Clean up debug logging | logging | `#logging` `#cleanup` | Remove or reduce verbose debug-level log statements introduced during development. Keep structured info/warning/error logs; remove console noise. |
| H-13 | Set the current environment using the Util tool. Automate it. | frontend | `#testing` `#corpus` `#qa` | Confirm that all active corpora appear in the user-facing corpus selector and admin corpus list. |


---

## Medium

Improves UX, fixes non-blocking bugs, or adds useful supporting features.

| # | Task | Classification | Tags | Description |
|---|------|---------------|------|-------------|
| M-1 | Fix first-query disappearing from chat frame | frontend | `#bug` `#ux` `#chat` | The first query sometimes renders briefly then disappears from the chat window. Investigate whether this is a state management race condition or a rendering issue. |
| M-2 | Lighten chat response background color | frontend | `#styling` `#ux` | Reduce the background color intensity of the AI response bubbles in the chatbot UI to improve readability. |
| M-3 | Lighten chat query background color | frontend | `#styling` `#ux` | Reduce the background color intensity of the user query bubbles in the chatbot UI to improve readability. |
| M-4 | Show per-user session totals in `/admin/sessions` | frontend, backend | `#admin` `#sessions` `#bug` | Session totals currently show lifetime counts across all users. Change to show totals scoped to the selected user profile. |
| M-5 | Reduce sync frequency on `/admin/sessions` page | frontend | `#performance` `#admin` `#sessions` | The sessions admin page syncs too aggressively, causing unnecessary API calls. Add a reasonable polling interval or switch to on-demand refresh. |
| M-6 | Add admin shortcut in chatbot UI | frontend | `#navigation` `#admin` `#ux` | Add a menu option or icon button in the chatbot interface that lets admin users jump directly to the admin panel without navigating away manually. |
| M-7 | Darken and standardize sidebar collapse button | frontend | `#styling` `#ux` `#navigation` | Increase the background contrast of the sidebar collapse/expand button and ensure it appears consistently on every page. |
| M-8 | Add dark/light mode toggle | frontend | `#theming` `#ux` | Implement a theme toggle that switches between dark and light mode across the entire application. |
| M-9 | Move Agent Type Definition to documentation | frontend | `#docs` `#admin` `#cleanup` | The Agent Type Definition section in `/admin/agents` is informational, not operational. Move it out of the admin UI and into the project documentation. |
| M-10 | Auto-grant group permissions on sync | backend | `#sync` `#groups` `#access-control` | When the Vertex AI sync discovers new corpora, automatically grant appropriate permissions to relevant groups based on configurable rules instead of requiring manual admin action. |
| M-11 | Add query performance metrics | backend, logging | `#performance` `#metrics` `#observability` | Track and expose query latency, token usage, and corpus hit rates per query. Store metrics for trend analysis and display in admin dashboard. |
| M-12 | Export chat conversations | frontend, backend | `#utility` `#export` `#chat` | Allow users to export complete conversation threads (questions and answers with metadata) for offline analysis, compliance, or record-keeping. |

---

## Low

Future enhancements, advanced features, and polish.

| # | Task | Classification | Tags | Description |
|---|------|---------------|------|-------------|
| L-1 | Generate document preview thumbnails | backend | `#corpus` `#documents` `#preview` | When documents are uploaded to a corpus (manually or via managed import), generate a preview image (e.g. first-page thumbnail for PDFs). Process in the background to avoid blocking uploads. |
| L-2 | Create UTILITY menu for corpus tools | frontend | `#navigation` `#utility` `#corpus` | Add a dedicated "Utilities" menu section that groups basic corpus management operations (create, delete, add documents) into a single toolbar-style interface. |
| L-3 | Convert corpus management tools to toolbar buttons | frontend | `#ux` `#utility` `#corpus` | Migrate individual corpus management actions from menu items to a compact button toolbar for quicker access. Depends on L-2. |
| L-4 | User profile and account dialog | frontend, backend | `#users` `#profile` `#ux` | Create a user account dialog showing profile metadata, access summary (corpora, agents, utilities, reports), and usage statistics. |
| L-5 | Implement Corpora Actions framework | frontend, backend | `#corpus` `#documents` `#actions` | Build a "Corpora Actions" system for in-session document operations: download/save the current document, open an inline document editor, and edit document metadata — all triggered from the chat context. |
| L-6 | Rate limit prediction and throttling | backend | `#performance` `#resilience` `#quota` | Predict when Vertex AI rate limits will be hit based on current usage patterns and proactively throttle requests to avoid 429 errors. |
| L-7 | Corpus query result caching | backend | `#performance` `#caching` `#corpus` | Cache frequently-requested corpus query results to reduce Vertex AI API calls and improve response latency for repeated or similar queries. |
| L-8 | User-configurable retry settings | frontend, backend | `#configuration` `#resilience` `#ux` | Allow users or admins to configure retry behavior (max attempts, backoff strategy) for failed Vertex AI requests instead of relying on hardcoded defaults. |
| L-9 | Corpus health monitoring dashboard | frontend, backend | `#monitoring` `#admin` `#corpus` | Build a dashboard showing corpus health: sync status, document counts, last-updated timestamps, error rates, and bucket accessibility. |
| L-10 | Automated multi-corpus query tests | system | `#testing` `#automation` `#ci` | Create an automated test suite that runs multi-corpus queries against known data and validates result accuracy, source attribution, and latency thresholds. |
| L-11 | Corpus creation best practices documentation | system | `#docs` `#corpus` `#onboarding` | Write a guide covering bucket structure conventions, folder vs. subfolder rules, naming standards, metadata requirements, and IAM implications when creating new corpora. |
| L-12 | Performance benchmarking tools | system, backend | `#performance` `#testing` `#benchmarks` | Build tools to benchmark query latency, sync duration, and throughput under load. Use results to identify bottlenecks and set performance baselines. |

---

## Dependency Map

Key ordering constraints between tasks:

```
C-1 (deployment defaults)
 ├── C-2 (IAM group interface) ── depends on default groups existing
 ├── C-3 (IAM role lifecycle) ── depends on default roles existing
 │    └── C-4 (agent tool assignment) ── depends on working role system
 └── H-3 (default group on user creation) ── depends on default group

C-6 (fix sync) ── blocks ──► H-2 (live-update corpora list)
                              M-10 (auto-grant on sync)

C-7 (fix save button) ── blocks ──► H-4 (corpus metadata on creation)

C-8 (429 error handling) ── foundation for ──► L-6 (rate limit prediction)
                                               L-8 (configurable retry)

H-7 (restructure nav) ── should precede ──► H-8 (remove legacy pages)
                                            M-6 (admin shortcut in chat)

L-2 (utility menu) ── should precede ──► L-3 (toolbar buttons)
                                          L-5 (corpora actions)
```

---

## Summary by Classification

| Classification | Critical | High | Medium | Low | Total |
|---------------|----------|------|--------|-----|-------|
| **system** | 1 | — | — | 3 | 4 |
| **backend** | 4 | 4 | 3 | 4 | 15 |
| **frontend** | 2 | 6 | 8 | 4 | 20 |
| **IAM** | 3 | — | — | — | 3 |
| **logging** | — | 1 | 1 | — | 2 |

> Note: Tasks with multiple classifications are counted once per classification.
> Total unique tasks: **44**

