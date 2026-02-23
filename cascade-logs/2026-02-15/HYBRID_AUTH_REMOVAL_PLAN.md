# Hybrid Auth Removal Plan — IAP-Only Authentication

**Date:** February 15, 2026  
**Priority:** HIGH — Must complete before Google Groups Bridge implementation  
**Goal:** Remove the Bearer token / username-password login path and make IAP the sole authentication method. Simplify the auth flow so that every request is authenticated by Google IAP automatically.

---

## Current State: Two Auth Paths

```
                    ┌─────────────────────────────┐
                    │     hybrid_auth_middleware    │
                    │                               │
  IAP path ────────►│  1. Check X-Goog-IAP-JWT     │──► User object
  (Google OAuth)    │     ↓ (if missing/invalid)    │
                    │  2. Check Bearer token         │──► User object
  Local path ──────►│     (username/password JWT)   │
                    │     ↓ (if both fail)           │
                    │  3. Return 401                 │
                    └─────────────────────────────┘
```

### Files Involved in Local Auth (to be removed/simplified)

**Backend — Auth system (REMOVE):**
| File | Purpose | Action |
|---|---|---|
| `middleware/auth_middleware.py` | Bearer-only auth dependency | **DELETE** |
| `middleware/hybrid_auth_middleware.py` | Dual IAP+Bearer auth | **REPLACE** with IAP-only |
| `services/auth_service.py` | Password hashing, JWT creation/verification | **KEEP** (needed for password hashing in admin user creation, but remove token methods) |
| `api/routes/auth.py` | `/api/auth/login`, `/register`, `/refresh`, `/logout`, `/me` | **DELETE** |
| `api/server.py` (lines 460-562) | Legacy auth endpoints (`login-legacy`, `register-legacy`, `verify-legacy`, `check-username`) | **DELETE** |
| `database/seed_default_users.py` | Seeds default users with passwords | **KEEP** (still useful for seeding admin users) |

**Backend — Consumers (UPDATE import):**
| File | Current Import | New Import |
|---|---|---|
| `api/routes/admin.py` | `from middleware.hybrid_auth_middleware import get_current_user_hybrid` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user` |
| `api/routes/agents.py` | `from middleware.hybrid_auth_middleware import get_current_user_hybrid as get_current_user` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user` |
| `api/routes/chatbot_admin.py` | `from middleware.hybrid_auth_middleware import get_current_user_hybrid as get_current_user` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user` |
| `api/routes/corpora.py` | `from middleware.hybrid_auth_middleware import get_current_user_hybrid as get_current_user` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user` |
| `api/routes/documents.py` | `from middleware.hybrid_auth_middleware import get_current_user_hybrid` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user_hybrid` |
| `api/routes/groups.py` | `from middleware.hybrid_auth_middleware import get_current_user_hybrid as get_current_user` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user` |
| `api/routes/users.py` | `from middleware.hybrid_auth_middleware import get_current_user_hybrid as get_current_user` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user` |
| `api/server.py` (line 43) | `from middleware.hybrid_auth_middleware import get_current_user_hybrid as get_current_user_from_middleware` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user_from_middleware` |
| `middleware/authorization_middleware.py` | `from middleware.hybrid_auth_middleware import get_current_user_hybrid as get_current_user` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user` |
| `middleware/tool_permission_middleware.py` | `from middleware.hybrid_auth_middleware import get_current_user_hybrid as get_current_user` | `from middleware.iap_auth_middleware import get_current_user_iap as get_current_user` |

**Frontend (UPDATE):**
| File | Change |
|---|---|
| `components/LoginForm.tsx` | **DELETE** — no more username/password form |
| `app/landing/page.tsx` | **SIMPLIFY** — remove "Sign In" button that shows LoginForm; IAP handles auth automatically |
| `app/page.tsx` | **SIMPLIFY** — remove Bearer token check, remove `showLogin` state, remove guest flow |
| `lib/api-enhanced.ts` | **SIMPLIFY** — remove `login()`, `register()`, `refreshToken()`, Bearer token management |
| `lib/api.ts` | **SIMPLIFY** — remove `login()`, `register()`, `verifyToken()`, Bearer token management |
| `lib/auth-headers.ts` | **SIMPLIFY** — remove Bearer token from localStorage; IAP headers are injected by LB |

---

## Target State: IAP-Only

```
                    ┌─────────────────────────────┐
                    │     iap_auth_middleware       │
                    │                               │
  IAP path ────────►│  1. Check X-Goog-IAP-JWT     │──► User object
  (Google OAuth)    │     ↓ (if missing)            │
                    │  2. Return 401                 │
                    └─────────────────────────────┘
```

**Login flow after change:**
1. User navigates to app URL (behind IAP load balancer)
2. Google IAP redirects to Google OAuth login (automatic)
3. After OAuth, IAP injects `X-Goog-IAP-JWT-Assertion` header on every request
4. Backend `iap_auth_middleware` verifies JWT, extracts email, gets/creates user
5. User is authenticated — no login form, no Bearer tokens, no passwords

---

## Implementation Phases

### Phase 1: Backend — Make `iap_auth_middleware` the sole auth dependency

**1a. Update `iap_auth_middleware.py`**
- Add `get_current_user_iap_optional` (already exists)
- Ensure backward-compatible re-export so existing `get_current_user_hybrid` alias still works during transition
- Add local dev bypass: when `IAP_DEV_MODE=true`, accept a configurable dev user email without JWT verification (for local development without IAP)

**1b. Update all route files** (10 files)
- Change imports from `hybrid_auth_middleware` → `iap_auth_middleware`
- Use `get_current_user_iap` as the dependency

**1c. Remove `auth.py` routes**
- Delete `/api/auth/login`, `/register`, `/refresh`, `/logout`, `/me`
- Keep `/api/iap/me` and `/api/iap/status` (already exist in `iap_auth.py`)

**1d. Remove legacy endpoints from `server.py`**
- Delete `register-legacy`, `login-legacy`, `verify-legacy`, `check-username`

**1e. Archive `hybrid_auth_middleware.py` and `auth_middleware.py`**
- Don't delete yet — rename to `.py.bak` or move to an `archive/` folder for safety

### Phase 2: Backend — Local Dev Mode

Since developers won't have IAP locally, add a dev bypass:

```python
# In iap_auth_middleware.py
IAP_DEV_MODE = os.getenv("IAP_DEV_MODE", "false").lower() == "true"
IAP_DEV_USER_EMAIL = os.getenv("IAP_DEV_USER_EMAIL", "dev@develom.com")

async def get_current_user_iap(request: Request) -> User:
    if IAP_DEV_MODE:
        # In dev mode, skip JWT verification and use a configured dev user
        user = UserService.get_user_by_email(IAP_DEV_USER_EMAIL)
        if not user:
            user = UserService.create_user_from_iap(
                email=IAP_DEV_USER_EMAIL,
                google_id="dev-mode-id",
                full_name="Dev User"
            )
        return user
    
    # Production: verify IAP JWT as before
    iap_jwt = request.headers.get(IAP_JWT_HEADER)
    ...
```

**Environment variables:**
- `IAP_DEV_MODE=true` — set in `.env.local` for local development
- `IAP_DEV_USER_EMAIL=hector@develom.com` — which user to simulate

### Phase 3: Frontend — Remove Login Form

**3a. Delete `LoginForm.tsx`**

**3b. Simplify `page.tsx`**
- Remove `showLogin` state and all login-related UI
- Remove Bearer token check from `checkAuth()`
- Auth flow becomes: try IAP → if fails, show "Access requires IAP" message
- Remove "Continue as Guest" button
- Remove guest user handling

**3c. Simplify `landing/page.tsx`**
- Remove "Sign In" button that shows LoginForm
- The page becomes informational only, or redirects to IAP automatically
- If user is not behind IAP, show message: "Please access via the organization URL"

**3d. Simplify `api-enhanced.ts`**
- Remove `login()`, `register()`, `refreshToken()` methods
- Remove `setToken()`, `clearToken()` Bearer token management
- Remove `isAuthenticated()` Bearer check — only `isIapAuthenticated()` matters
- Keep `checkIapAuth()` as the primary auth check
- All API calls use `credentials: 'include'` instead of Bearer headers

**3e. Simplify `auth-headers.ts`**
- Remove Bearer token from localStorage lookup
- Headers become just `{ 'Content-Type': 'application/json' }`
- IAP headers are injected by the load balancer automatically

**3f. Simplify `api.ts`** (legacy client)
- Same changes as api-enhanced.ts — remove Bearer token management

### Phase 4: Cleanup

- Remove `auth_middleware.py` (Bearer-only middleware)
- Remove `hybrid_auth_middleware.py` (dual middleware)
- Remove `api/routes/auth.py` (login/register routes)
- Remove legacy auth endpoints from `server.py`
- Remove `LoginForm.tsx`
- Clean up `auth_service.py` — keep `hash_password()` (needed for admin user creation), remove JWT token methods
- Update `api/routes/README.md` to reflect new auth model

---

## Local Development Strategy

| Environment | Auth Method |
|---|---|
| **Production** (Cloud Run + IAP) | IAP JWT — automatic via load balancer |
| **Local dev** (`IAP_DEV_MODE=true`) | Dev bypass — auto-authenticates as configured user |
| **Testing** | Dev bypass or mock IAP headers |

The `.env.local` file already exists. We add:
```
IAP_DEV_MODE=true
IAP_DEV_USER_EMAIL=hector@develom.com
```

---

## Risk Assessment

| Risk | Mitigation |
|---|---|
| Breaking local development | Dev mode bypass with `IAP_DEV_MODE=true` |
| Admin user creation needs passwords | Keep `AuthService.hash_password()` for admin-created users |
| Existing Bearer tokens in localStorage | Frontend cleanup clears localStorage on next load |
| Frontend pages that check `isAuthenticated()` | Update to check IAP auth only |
| Legacy API consumers using Bearer tokens | Legacy endpoints already suffixed with `-legacy`; remove them |

---

## Files Changed Summary

### Backend DELETE (4 files):
1. `middleware/auth_middleware.py`
2. `middleware/hybrid_auth_middleware.py`
3. `api/routes/auth.py`
4. Legacy endpoints in `api/server.py`

### Backend MODIFY (12 files):
1. `middleware/iap_auth_middleware.py` — add dev mode bypass
2. `middleware/authorization_middleware.py` — update import
3. `middleware/tool_permission_middleware.py` — update import
4. `api/routes/admin.py` — update import
5. `api/routes/agents.py` — update import
6. `api/routes/chatbot_admin.py` — update import
7. `api/routes/corpora.py` — update import
8. `api/routes/documents.py` — update import
9. `api/routes/groups.py` — update import
10. `api/routes/users.py` — update import
11. `api/server.py` — update import, remove legacy endpoints
12. `services/auth_service.py` — remove JWT methods (optional, can keep)

### Frontend DELETE (1 file):
1. `components/LoginForm.tsx`

### Frontend MODIFY (5 files):
1. `app/page.tsx` — remove login form, Bearer check, guest flow
2. `app/landing/page.tsx` — remove Sign In button / LoginForm
3. `lib/api-enhanced.ts` — remove login/register/token methods
4. `lib/api.ts` — remove login/register/token methods
5. `lib/auth-headers.ts` — remove Bearer token lookup

---

## Implementation Order

| Step | Description | Risk |
|---|---|---|
| **1** | Add dev mode bypass to `iap_auth_middleware.py` | LOW — additive only |
| **2** | Update all 10 backend route imports to use `iap_auth_middleware` | MEDIUM — must update all at once |
| **3** | Remove `auth.py` routes and legacy endpoints from `server.py` | LOW — already replaced |
| **4** | Archive/delete `auth_middleware.py` and `hybrid_auth_middleware.py` | LOW — no longer imported |
| **5** | Frontend: simplify auth flow in `page.tsx` and `landing/page.tsx` | MEDIUM — UI changes |
| **6** | Frontend: simplify API clients | MEDIUM — remove token management |
| **7** | Frontend: delete `LoginForm.tsx` | LOW — no longer imported |
| **8** | Test locally with `IAP_DEV_MODE=true` | — |
| **9** | Deploy and test with IAP | — |
