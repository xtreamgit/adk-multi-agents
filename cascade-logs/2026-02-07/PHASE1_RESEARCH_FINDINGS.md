# Phase 1 Research Findings — IAM Authentication Audit

**Date:** February 07, 2026  
**Branch:** `feature/google-cloud-iam-auth`

---

## What Already Exists (Significant!)

The codebase already has substantial IAP infrastructure from a previous implementation effort. Here's what's in place:

### Backend — Services
- **`iap_service.py`** — Full IAP JWT verification service with:
  - `verify_iap_jwt()` — Validates JWT signature using Google's public keys (ES256)
  - `extract_user_info()` — Extracts email, google_id, name from decoded JWT
  - `is_iap_enabled()` / `get_iap_audience()` — Configuration checks
  - Reads `PROJECT_NUMBER` and `BACKEND_SERVICE_ID` from env vars

- **`user_service.py`** — Already has IAP user management:
  - `create_user_from_iap()` — Creates user without password, generates username from email
  - `get_user_by_google_id()` — Lookup by Google ID
  - `update_google_id()` — Links existing user to Google account

- **`auth_service.py`** — Legacy JWT auth (username/password) — fully working

### Backend — Middleware
- **`hybrid_auth_middleware.py`** (in `middleware/`) — Full hybrid auth with:
  - Priority 1: IAP JWT (`X-Goog-IAP-JWT-Assertion` header)
  - Priority 2: Bearer token fallback
  - Auto-creates users from IAP if not in DB
  - Updates last login on IAP auth

- **`iap_auth_middleware.py`** — IAP-only middleware with:
  - `get_current_user_iap()` — Strict IAP-only auth
  - `get_current_user_optional_iap()` — Optional IAP auth
  - `get_current_user_hybrid()` — Duplicate hybrid auth (different implementation)

- **`auth_middleware.py`** — Legacy Bearer-only auth

### Backend — Routes
- **`iap_auth.py`** — IAP diagnostic routes at `/api/iap/*`:
  - `GET /api/iap/me` — Get IAP-authenticated user
  - `GET /api/iap/status` — Check IAP configuration
  - `GET /api/iap/verify` — Verify IAP JWT token
  - `GET /api/iap/headers` — Debug IAP headers

### Backend — Database
- **`users` table** already has IAP columns:
  - `google_id VARCHAR(255) UNIQUE` — Google user ID
  - `auth_provider VARCHAR(50) DEFAULT 'local'` — 'local', 'iap', 'google'
  - `hashed_password VARCHAR(255)` — Already nullable (for IAP users)

- **`user_repository.py`** has:
  - `get_by_google_id()` — Query by Google ID
  - `create_iap_user()` — Insert without password

### Backend — User Model
- **`User` model** already includes:
  - `google_id: Optional[str] = None`
  - `auth_provider: str = "local"` — supports 'local', 'iap', 'google'

### Frontend
- **`LoginForm.tsx`** — Username/password only (no Google sign-in button yet)

### GCP Infrastructure
- **IAP enabled** on both `frontend-backend-service` and `backend-backend-service`
- **OAuth Client ID:** `351592762922-t4k0kr1kqk3i4rdbu6porj8p881fjo13.apps.googleusercontent.com`
- **Project Number:** `351592762922`
- **Backend Service IDs:**
  - `frontend-backend-service`: `6089863363627744831`
  - `backend-backend-service`: `2781125957286789109`

---

## Gaps Identified

### CRITICAL — Must Fix

| # | Gap | Impact | Fix |
|---|-----|--------|-----|
| 1 | **`PROJECT_NUMBER` not set** in Cloud Run backend env vars | `IAPService` can't verify JWTs — `IAP_AUDIENCE` is `None` | Add env var to Cloud Run |
| 2 | **`BACKEND_SERVICE_ID` not set** in Cloud Run backend env vars | Same as above | Add env var to Cloud Run |
| 3 | **No IAP access policy** — `etag: ACAB` (empty) on all services | No users are authorized through IAP | Grant `roles/iap.httpsResourceAccessor` to users/groups |
| 4 | **Routes inconsistency** — Most routes use `auth_middleware.get_current_user` (Bearer only), not hybrid | IAP-authenticated users can't access agents, groups, chatbot_admin, users routes | Migrate routes to `hybrid_auth_middleware.get_current_user_hybrid` |

### HIGH — Should Fix

| # | Gap | Impact | Fix |
|---|-----|--------|-----|
| 5 | **Duplicate hybrid middleware** — Two different implementations in `hybrid_auth_middleware.py` and `iap_auth_middleware.py` | Confusion, maintenance burden | Consolidate to single implementation |
| 6 | **No "Sign in with Google" button** on frontend | Users can't initiate Google OAuth from the login page | Add Google sign-in button to `LoginForm.tsx` |
| 7 | **No OAuth callback page** on frontend | No way to handle OAuth redirect flow | Create `/auth/callback` page |
| 8 | **No Google Group** created for access control | Can't test group-based authorization | Create `rag-app-test-users` group |

### MEDIUM — Nice to Have

| # | Gap | Impact | Fix |
|---|-----|--------|-----|
| 9 | **No group membership check** in IAP auth flow | All IAP users get access regardless of group | Add group membership validation |
| 10 | **No `.env.local` IAP config** | Can't test IAP locally | Add PROJECT_NUMBER and BACKEND_SERVICE_ID to `.env.local` |
| 11 | **`chatbot_admin.py`** uses `auth_middleware.get_current_user` | Admin routes won't work with IAP | Migrate to hybrid |

---

## Route Auth Middleware Usage (Current State)

| Route File | Current Middleware | Needs Migration? |
|------------|-------------------|-----------------|
| `admin.py` | `hybrid_auth_middleware.get_current_user_hybrid` | ✅ Already hybrid |
| `documents.py` | `hybrid_auth_middleware.get_current_user_hybrid` | ✅ Already hybrid |
| `auth.py` | `auth_middleware.get_current_user` | ⚠️ Keep as-is (legacy login) |
| `users.py` | `auth_middleware.get_current_user` | ❌ Needs migration |
| `groups.py` | `auth_middleware.get_current_user` | ❌ Needs migration |
| `agents.py` | `auth_middleware.get_current_user` | ❌ Needs migration |
| `chatbot_admin.py` | `auth_middleware.get_current_user` | ❌ Needs migration |
| `iap_auth.py` | `iap_auth_middleware.get_current_user_iap` | ✅ IAP-specific (keep) |

---

## Revised Implementation Plan

Given the existing infrastructure, the original 14-day plan can be **significantly compressed**:

### Immediate Actions (Today)
1. Set `PROJECT_NUMBER=351592762922` on Cloud Run backend
2. Set `BACKEND_SERVICE_ID=2781125957286789109` on Cloud Run backend
3. Create test Google Group and add test users
4. Add IAP access policy for the test group
5. Test IAP JWT verification end-to-end

### Phase 2 (Revised) — Route Migration (1 day instead of 2)
- Migrate `users.py`, `groups.py`, `agents.py`, `chatbot_admin.py` to hybrid middleware
- Consolidate duplicate hybrid middleware implementations

### Phase 3 (Revised) — Frontend (1-2 days instead of 2)
- Add "Sign in with Google" button
- Create OAuth callback page
- Update API client for IAP headers

### Phases 4-5 (Revised) — Already done!
- Database schema already has IAP columns
- IAM Auth Service already exists
- Hybrid middleware already exists

**Revised Total: ~4-5 days instead of 14**
