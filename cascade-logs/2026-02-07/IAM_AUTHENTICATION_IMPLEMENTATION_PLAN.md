# Google Cloud IAM Authentication Implementation Plan

**Author:** Hector  
**Date:** February 07, 2026  
**Branch:** `feature/google-cloud-iam-auth`  
**Status:** Planning Phase

---

## Executive Summary

This plan outlines the integration of Google Cloud Identity-Aware Proxy (IAP) and OAuth2 authentication to replace the current username/password authentication system in the ADK Multi-Agents RAG application. The implementation will enable internal users to authenticate using their Google Cloud credentials while maintaining backward compatibility during the transition period.

---

## Current State Analysis

### Existing Authentication Flow
1. User enters username/password on login page
2. Frontend sends credentials to `/api/auth/login`
3. Backend validates against PostgreSQL `chatbot_users` table
4. JWT token issued and stored in localStorage
5. Subsequent requests use Bearer token authentication

### Current Components
- **Frontend:** `LoginForm` component with username/password fields
- **Backend:** `auth_service.py` - password hashing and JWT generation
- **Middleware:** `auth_middleware.py` - Bearer token validation
- **Database:** `chatbot_users` table with hashed passwords

### Important Context
- **IAP is already partially configured** at `https://34.49.46.115.nip.io` (working)
- **Local login** at `https://frontend-2weuwmamca-uw.a.run.app/` (has datetime serialization fixes)
- **Database:** Cloud SQL PostgreSQL (NOT SQLite)
- **GCP Project:** `adk-rag-ma`, Region: `us-west1`

---

## Target State Architecture

### New Authentication Flow
1. User navigates to app → IAP intercepts and redirects to Google login
2. Google authenticates user via OAuth2
3. IAP validates user is in authorized group
4. IAP forwards request with `X-Goog-IAP-JWT-Assertion` header
5. Backend validates IAP JWT, extracts user email
6. Backend checks/creates user profile in database
7. Backend checks group membership for authorization (agents, corpora)
8. User accesses application with their profile and permissions

### IAM Authorization Model
- **Primary Group:** `rag-app-users@domain.com` — Full application access
- **Future Groups:** Organization-specific groups with granular permissions
- **Fallback:** Existing username/password for local development/testing

---

## Implementation Phases

---

## Phase 1: Research & GCP Setup (Days 1–2)

### 1.1 Audit Existing IAP Configuration
**Objective:** Understand what's already configured and what's missing

**Tasks:**
- [ ] Review current IAP setup on `https://34.49.46.115.nip.io`
- [ ] Document existing OAuth 2.0 credentials in GCP Console
- [ ] Review current IAP access policies
- [ ] Identify gaps between current IAP and target state

### 1.2 Google Cloud IAM Configuration
**Objective:** Configure OAuth2 and IAP fully in GCP

**Tasks:**
- [ ] Verify/create OAuth 2.0 credentials in GCP Console
- [ ] Configure OAuth consent screen (internal users only)
- [ ] Set authorized redirect URIs for both local dev and production
- [ ] **Create test Google Group** (e.g., `rag-app-test-users@domain.com`) for testing purposes
- [ ] **Create test Google users** specifically for testing authentication flows
- [ ] Configure IAP access policies to use the test group
- [ ] Document test group and test user credentials

> **Authorization Note:** Cascade is authorized to create test Google Groups and test Google Users for the sole purpose of testing the IAM authentication integration. These test resources should be clearly labeled as test artifacts (e.g., prefixed with `test-` or `rag-test-`) and documented for cleanup after testing is complete.

**Testing (Phase 1):**
- ✅ Verify OAuth credentials exist and are valid
- ✅ Test IAP access with a **test user IN the test group** → should succeed
- ✅ Test IAP access with a **test user NOT in the test group** → should be denied
- ✅ Confirm `X-Goog-IAP-JWT-Assertion` header is present in requests
- ✅ Verify test users can authenticate via Google OAuth flow
- ✅ Verify test group membership is detectable via API

**Test Resources to Create:**

| Resource | Name | Purpose |
|----------|------|---------|
| Google Group | `rag-app-test-users` | Test group for authorized access |
| Test User 1 | `rag-test-admin@domain.com` | Test admin-level access |
| Test User 2 | `rag-test-viewer@domain.com` | Test viewer-level access |
| Test User 3 | `rag-test-unauthorized@domain.com` | Test denied access (NOT in group) |

**Cleanup Plan:**
- All test groups and users will be documented
- After successful production deployment, test resources will be reviewed for retention or deletion

**Documentation:**
- OAuth client ID and secret storage location
- IAP configuration steps
- Group management procedures

---

## Phase 2: Backend — IAM Auth Service (Days 3–4)

### 2.1 Install Dependencies
**Objective:** Add required Python packages

**Tasks:**
- [ ] Add `google-auth` to `requirements.txt`
- [ ] Add `google-auth-oauthlib` to `requirements.txt`
- [ ] Add `google-auth-httplib2` to `requirements.txt`
- [ ] Verify packages install in Docker image

**Testing (Phase 2.1):**
- ✅ `pip install` succeeds
- ✅ `import google.auth` works
- ✅ Docker build succeeds

### 2.2 Create IAM Authentication Service
**File:** `backend/src/services/iam_auth_service.py`

**Tasks:**
- [ ] Create `IAMAuthService` class
- [ ] Implement `verify_iap_jwt(token)` — validate IAP JWT signature using Google's public keys
- [ ] Implement `extract_user_info(token)` — get email, name, Google ID from token
- [ ] Implement `create_or_update_user(user_info)` — upsert user in `chatbot_users` table
- [ ] Implement `check_authorization(user, resource)` — check group/role permissions
- [ ] Add error handling and structured logging

**Testing (Phase 2.2):**
- ✅ Unit test: `verify_iap_jwt()` with valid mock token → returns user info
- ✅ Unit test: `verify_iap_jwt()` with invalid token → raises exception
- ✅ Unit test: `verify_iap_jwt()` with expired token → raises exception
- ✅ Unit test: `create_or_update_user()` with new user → creates record
- ✅ Unit test: `create_or_update_user()` with existing user → updates record
- ✅ Unit test: `check_authorization()` with authorized user → returns True
- ✅ Unit test: `check_authorization()` with unauthorized user → returns False

**Documentation:**
- Service API documentation
- Error codes and handling

---

## Phase 3: Backend — Hybrid Auth Middleware (Day 5)

### 3.1 Create Hybrid Authentication Middleware
**File:** `backend/src/api/middleware/hybrid_auth_middleware.py`

**Tasks:**
- [ ] Create `get_current_user_hybrid()` FastAPI dependency
- [ ] Priority 1: Check for `X-Goog-IAP-JWT-Assertion` header
- [ ] Priority 2: Fall back to existing Bearer token auth
- [ ] Validate IAP JWT signature against Google's public keys
- [ ] Extract user email from IAP token
- [ ] Look up or create user in database
- [ ] Return consistent user object regardless of auth method

**Testing (Phase 3):**
- ✅ Test: Request with valid IAP header → authenticated as Google user
- ✅ Test: Request with valid Bearer token (no IAP) → authenticated as local user
- ✅ Test: Request with invalid IAP header → falls back to Bearer token
- ✅ Test: Request with no auth at all → 401 Unauthorized
- ✅ Test: Request with both IAP and Bearer → IAP takes priority
- ✅ Test: IAP user not in database → auto-created and authenticated

**Documentation:**
- Middleware flow diagram
- Header requirements
- Fallback behavior

---

## Phase 4: Backend — OAuth2 Endpoints & Route Updates (Day 6)

### 4.1 Create OAuth2 Endpoints
**File:** `backend/src/api/routes/oauth.py`

**Tasks:**
- [ ] `GET /api/auth/google/login` — redirect to Google OAuth consent
- [ ] `GET /api/auth/google/callback` — handle OAuth callback, exchange code for token
- [ ] Validate user is in authorized group
- [ ] Create/update user in database
- [ ] Issue internal JWT token for session
- [ ] Redirect to frontend with token

**Testing (Phase 4.1):**
- ✅ Test: `/api/auth/google/login` → returns redirect URL to Google
- ✅ Test: `/api/auth/google/callback` with valid code → creates user, returns JWT
- ✅ Test: `/api/auth/google/callback` with invalid code → returns error
- ✅ Test: Callback for unauthorized user (not in group) → returns 403
- ✅ Test: Callback for new user → profile created in database
- ✅ Test: Callback for existing user → profile updated (last login time)

**Documentation:**
- Endpoint specifications
- OAuth flow diagram
- Error responses

### 4.2 Update Existing Routes to Hybrid Auth
**Tasks:**
- [ ] Replace `get_current_user` with `get_current_user_hybrid` in all route files
- [ ] Update `chatbot_admin.py` routes
- [ ] Update `chatbot.py` routes
- [ ] Update any other protected routes
- [ ] Keep `/api/auth/login` endpoint for legacy support

**Testing (Phase 4.2):**
- ✅ Test: All admin endpoints work with IAP auth
- ✅ Test: All admin endpoints work with Bearer token auth
- ✅ Test: Chat endpoints work with IAP auth
- ✅ Test: Chat endpoints work with Bearer token auth
- ✅ Test: Legacy `/api/auth/login` still works

---

## Phase 5: Database Schema Updates (Day 7)

### 5.1 Add Google Auth Fields
**File:** `backend/migrations/add_google_auth_fields.sql`

**Tasks:**
- [ ] Add `google_id` column (VARCHAR, unique, nullable)
- [ ] Add `google_email` column (VARCHAR, nullable)
- [ ] Add `auth_method` column (VARCHAR, default 'local') — values: 'local', 'google', 'both'
- [ ] Add `last_google_login` column (TIMESTAMP, nullable)
- [ ] Make `password_hash` column nullable (Google users won't have passwords)
- [ ] Create indexes on `google_id` and `google_email`
- [ ] Write rollback migration script

**Testing (Phase 5):**
- ✅ Test: Migration runs successfully on dev database
- ✅ Test: Existing users unaffected (all fields nullable/defaulted)
- ✅ Test: New Google user can be created without password
- ✅ Test: Existing user can be linked to Google account
- ✅ Test: Rollback migration works cleanly
- ✅ Test: Indexes created and queryable

**Documentation:**
- Migration guide
- Schema documentation
- Rollback procedures

---

## Phase 6: Frontend — Login Page & Callback (Days 8–9)

### 6.1 Update Login Page
**File:** `frontend/src/components/LoginForm.tsx` (or equivalent)

**Tasks:**
- [ ] Add prominent "Sign in with Google" button (brand green styling: `rgb(0,84,64)`)
- [ ] Keep username/password form as secondary option (collapsible/toggle)
- [ ] "Sign in with Google" redirects to `/api/auth/google/login`
- [ ] Maintain USFS branding and logo
- [ ] Remove "Sign up" link (Google users auto-provisioned)

**Testing (Phase 6.1):**
- ✅ Test: "Sign in with Google" button visible and styled correctly
- ✅ Test: Click redirects to Google OAuth
- ✅ Test: Legacy login toggle works
- ✅ Test: Username/password login still functional
- ✅ Test: Responsive design on mobile

### 6.2 Create OAuth Callback Page
**File:** `frontend/src/app/auth/callback/page.tsx`

**Tasks:**
- [ ] Create callback page component
- [ ] Extract authorization code from URL parameters
- [ ] Send code to backend `/api/auth/google/callback`
- [ ] Store returned JWT token in localStorage
- [ ] Redirect to main application
- [ ] Show loading spinner during processing
- [ ] Handle and display errors gracefully

**Testing (Phase 6.2):**
- ✅ Test: Successful callback → token stored, redirected to app
- ✅ Test: Error callback → error message displayed
- ✅ Test: Missing code parameter → appropriate error
- ✅ Test: Backend returns 403 → "Not authorized" message

### 6.3 Update API Client for IAP Headers
**File:** `frontend/src/lib/api-enhanced.ts`

**Tasks:**
- [ ] Detect IAP headers when present (Cloud Run behind IAP)
- [ ] Include IAP headers in API requests when available
- [ ] Maintain Bearer token support for local development
- [ ] Handle 401/403 errors → redirect to login

**Testing (Phase 6.3):**
- ✅ Test: API calls work with IAP (production)
- ✅ Test: API calls work with Bearer token (local dev)
- ✅ Test: 401 response → redirect to login page

---

## Phase 7: End-to-End Integration Testing (Days 10–11)

### 7.1 Complete Flow Testing

| # | Scenario | Expected Result |
|---|----------|----------------|
| 1 | New Google user (in group) logs in | Profile auto-created, access granted, lands on chat |
| 2 | Existing Google user logs in | Profile updated (last_google_login), access granted |
| 3 | Google user NOT in group | Access denied with clear error message |
| 4 | Legacy user logs in with username/password | Works as before, no regression |
| 5 | User with both Google and local accounts | Both methods work, same profile |
| 6 | JWT token expires | User redirected to login, can re-authenticate |
| 7 | User logs out | Session cleared, redirected to login |
| 8 | Admin user via Google | Admin panel accessible based on role |
| 9 | Non-admin Google user | Admin panel not accessible |
| 10 | Concurrent sessions | Both work independently |

**Testing (Phase 7):**
- ✅ Manual testing of all 10 scenarios above using test Google users
- ✅ Test on production URL (`https://34.49.46.115.nip.io`)
- ✅ Test on local development (`http://localhost:3000`)
- ✅ Verify no regressions in existing functionality

---

## Phase 8: Security Hardening (Day 12)

### 8.1 Security Review
**Objective:** Ensure secure implementation

**Tasks:**
- [ ] Validate IAP JWT signature verification uses Google's public keys
- [ ] Verify token expiration is enforced
- [ ] Confirm HTTPS is enforced on all auth endpoints
- [ ] Review CORS configuration for OAuth callback URLs
- [ ] Add audit logging for all auth events (login, logout, denied)
- [ ] Implement rate limiting on auth endpoints
- [ ] Verify no sensitive data in logs

**Testing (Phase 8):**
- ✅ Test: Tampered JWT → rejected
- ✅ Test: Expired JWT → rejected
- ✅ Test: HTTP request → redirected to HTTPS
- ✅ Test: Auth events appear in audit log
- ✅ Test: Rapid login attempts → rate limited

**Documentation:**
- Security audit report
- Threat model
- Mitigation strategies

---

## Phase 9: Documentation & Deployment (Days 13–14)

### 9.1 Documentation
**Objective:** Complete user and developer docs

**Tasks:**
- [ ] User guide: "How to sign in with Google"
- [ ] Admin guide: Managing Google Groups for access control
- [ ] Developer guide: How the hybrid auth system works
- [ ] API documentation updates for new endpoints
- [ ] Troubleshooting guide for common auth issues

### 9.2 Deployment
**Objective:** Deploy to production

**Tasks:**
- [ ] Deploy to staging (new Cloud Run revision)
- [ ] Smoke test all auth flows
- [ ] Deploy to production
- [ ] Monitor logs for auth errors
- [ ] Rollback plan documented and tested

**Testing (Phase 9):**
- ✅ Staging environment validation
- ✅ Production smoke tests
- ✅ User acceptance testing

---

## Rollback Strategy

### Immediate Rollback
If critical issues arise:
1. Revert to previous Cloud Run revision
2. Disable IAP requirement
3. Re-enable username/password only
4. Investigate issues

### Gradual Rollback
For non-critical issues:
1. Keep both auth methods active
2. Fix issues on feature branch
3. Redeploy when ready

---

## Success Criteria

- [ ] Users can authenticate with Google accounts via IAP
- [ ] Group membership controls application access
- [ ] User profiles auto-created/updated on first Google login
- [ ] Legacy username/password still works (backward compatible)
- [ ] No security vulnerabilities introduced
- [ ] Login time < 2 seconds
- [ ] All tests passing
- [ ] Documentation complete

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| OAuth misconfiguration | High | Test in staging first, detailed docs |
| Group sync delays | Medium | Cache group membership, refresh periodically |
| Token expiration issues | Medium | Implement token refresh flow |
| User confusion (two login methods) | Low | Clear UI with Google as primary |
| Performance degradation | Medium | Load testing, caching strategy |
| Security vulnerabilities | High | Security audit, penetration testing |

---

## Timeline Summary

| Phase | Days | Focus |
|-------|------|-------|
| 1 | 1–2 | Research & GCP Setup |
| 2 | 3–4 | Backend IAM Auth Service |
| 3 | 5 | Hybrid Auth Middleware |
| 4 | 6 | OAuth Endpoints & Route Updates |
| 5 | 7 | Database Schema Updates |
| 6 | 8–9 | Frontend Login & Callback |
| 7 | 10–11 | End-to-End Integration Testing |
| 8 | 12 | Security Hardening |
| 9 | 13–14 | Documentation & Deployment |

**Total Duration:** 14 days

---

## Next Steps

1. ✅ Review and approve this plan
2. ✅ Create feature branch (`feature/google-cloud-iam-auth`)
3. Set up Google Cloud OAuth credentials
4. Create test Google Groups and Users
5. Begin Phase 1 implementation

---

## References

- [Google Cloud IAP Documentation](https://cloud.google.com/iap/docs)
- [OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Google Groups API](https://developers.google.com/admin-sdk/directory/v1/guides/manage-groups)
- Current auth code: `backend/src/services/auth_service.py`
- Current middleware: `backend/src/api/middleware/auth_middleware.py`
