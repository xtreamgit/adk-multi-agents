# Get Started Button Flow Test Results

**Date:** January 11, 2026  
**Test Script:** `frontend/test-get-started-flow.js`

## Test Purpose
Trace the navigation flow when user clicks "Get Started" button on the landing page and diagnose why users are being redirected back to landing instead of seeing the chatbot UI.

---

## Navigation Flow

### Step 1: Landing Page
- **Location:** `/landing`
- **Button:** "Get Started"
- **Code:** `frontend/src/app/landing/page.tsx:9-11`
```typescript
const handleGetStarted = () => {
  router.push('/');
};
```
- **Action:** Navigates to root path `/`

### Step 2: Root Page Authentication Check
- **Location:** `/`
- **Code:** `frontend/src/app/page.tsx:46-124`
- **Process:**

#### 2a. Check IAP Status
```typescript
const iapStatus = await apiClient.checkIAPStatus();
```
- **Endpoint:** `GET /api/iap/status`
- **Expected Response:**
```json
{
  "iap_enabled": true,
  "iap_audience": "/projects/351592762922/global/backendServices/7515488100092641154",
  "message": "IAP is properly configured"
}
```

#### 2b. If IAP is enabled, get IAP user
```typescript
if (iapStatus.iap_enabled) {
  userData = await apiClient.getIAPUser();
}
```
- **Endpoint:** `GET /api/iap/me`
- **Requires:** `X-Goog-IAP-JWT-Assertion` header (injected by Google IAP)
- **Expected Response:**
```json
{
  "id": 1,
  "username": "...",
  "email": "user@example.com",
  "full_name": "User Name",
  "is_active": true
}
```

#### 2c. Success Path
- User data stored in React state
- Load user's agents and corpus preferences
- Show chatbot UI

#### 2d. Failure Path
- Falls back to token-based auth
- If no token: `router.push('/landing')`
- **→ User redirected back to landing page (infinite loop)**

---

## Test Results

### Direct API Tests (without IAP headers)

**Test 1: `/api/health`**
```
Status: 200 OK
Response: "Invalid IAP credentials: empty token"
```

**Test 2: `/api/iap/status`**
```
Status: 200 OK
Response: "Invalid IAP credentials: empty token"
```

**Test 3: `/api/iap/me`**
```
Status: 200 OK
Response: "Invalid IAP credentials: empty token"
```

---

## Root Cause Analysis

### ✅ What's Working
1. **Landing page navigation:** Button correctly calls `router.push('/')`
2. **Backend IAP enforcement:** Backend properly rejects requests without IAP headers
3. **Load balancer IAP:** IAP is enabled on `backend-backend-service`
4. **Frontend logic:** Code correctly checks `iapStatus.iap_enabled` property

### ❌ What's Broken
**The frontend is making API requests from the client side, but IAP headers are only injected for server-side requests or requests that go through the load balancer properly.**

When the Next.js app runs in the browser:
```typescript
// This runs in the user's browser
const response = await fetch(this.buildUrl('/api/iap/status'), {
  method: 'GET',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
});
```

The browser makes a request to:
- `https://34.49.46.115.nip.io/api/iap/status`

**Problem:** The frontend fetch call from the browser does NOT include IAP headers because:
1. IAP headers are injected by the load balancer BEFORE the request reaches the backend
2. But if the request goes to `/api/*`, it should route to the backend
3. The browser's fetch doesn't have IAP headers to begin with

**Expected behavior:**
- Browser request → Load Balancer → IAP injects headers → Backend
- But the load balancer path matching might not be working correctly

---

## Load Balancer Configuration

**URL Map Path Rules:**
```bash
/api/* → backend-backend-service
/agent1/api/* → backend-agent1-backend-service
/agent2/api/* → backend-agent2-backend-service
/agent3/api/* → backend-agent3-backend-service
/* → frontend-backend-service (default)
```

**IAP Configuration:**
- `backend-backend-service`: IAP enabled ✓
- OAuth Client: `351592762922-t4k0kr1kqk3i4rdbu6porj8p881fjo13.apps.googleusercontent.com`

---

## The Real Problem

When a user accesses `https://34.49.46.115.nip.io`:

1. **Load Balancer routes to frontend** (default route)
2. **Frontend serves React app** with client-side JavaScript
3. **React runs in browser**, makes fetch to `/api/iap/status`
4. **Browser request goes back to load balancer**
5. **Load balancer should match `/api/*` path and route to backend**
6. **IAP should inject headers before reaching backend**

**BUT:** The backend is returning "Invalid IAP credentials: empty token"

This means either:
- ❌ IAP is not injecting headers for these requests
- ❌ The path matching isn't working and requests aren't going to backend
- ❌ Something in the request is causing IAP to skip header injection

---

## Next Diagnostic Steps

### 1. Verify Load Balancer Path Matching
```bash
# Check if /api/* requests are reaching backend
curl -v https://34.49.46.115.nip.io/api/health 2>&1 | grep -i "x-goog"
```

### 2. Check Backend Logs
```bash
# See if requests are reaching backend and what headers they have
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=backend" --limit 50 --format json
```

### 3. Test IAP Directly
```bash
# Access through browser and check network tab
# Look for X-Goog-IAP-JWT-Assertion header in request
```

### 4. Verify IAP on Load Balancer
```bash
# Check if IAP is configured on the backend service
gcloud compute backend-services describe backend-backend-service --global --format="yaml(iap)"
```

---

## Potential Solutions

### Option A: Frontend Should Call Backend Through Load Balancer
**Status:** Already configured correctly

The frontend is using `NEXT_PUBLIC_BACKEND_URL=https://34.49.46.115.nip.io` which points to the load balancer. The issue is IAP isn't injecting headers.

### Option B: Make Frontend Requests Server-Side
Use Next.js API routes as a proxy:
```typescript
// frontend/src/app/api/iap/status/route.ts
export async function GET() {
  const response = await fetch('https://34.49.46.115.nip.io/api/iap/status');
  return response;
}
```

**Problem:** This still goes through the same load balancer path.

### Option C: Check CORS Configuration
The backend might need CORS headers to allow the frontend domain:
```python
# backend CORS should allow:
origins = ["https://34.49.46.115.nip.io"]
```

### Option D: Verify IAP Configuration on Backend Service
IAP might need to be re-enabled or reconfigured on the backend Cloud Run service.

---

## Immediate Action Required

**The test reveals that backend API endpoints are not receiving IAP headers when called from the browser.**

Next step: Check browser Network tab when accessing the app to see:
1. Are `/api/*` requests going to the backend or frontend?
2. Do requests have `X-Goog-IAP-JWT-Assertion` header?
3. What response is actually returned?

**User should:**
1. Open https://34.49.46.115.nip.io in browser
2. Open Developer Tools → Network tab
3. Click "Get Started"
4. Check the `/api/iap/status` request
5. Report what headers and response are shown
