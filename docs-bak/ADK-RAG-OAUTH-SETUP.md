# Google Cloud Resources Inventory and Explanation

This document explains, in plain terms, all Google Cloud resources used to deploy the OAuth-protected RAG Agent with IAP and an HTTP(S) Load Balancer. It is written for readers who may be new to IAP, OAuth2, VPCs, and firewalls.

## What these components are (simple explanations)

- **Cloud Run (frontend, backend)**: Fully managed containers. We deploy our web UI ("frontend") and API ("backend") as separate Cloud Run services.
- **External HTTP(S) Load Balancer**: A global entry point on the public internet that terminates HTTPS, routes "/" to the frontend, and "/api/*" to the backend.
- **IAP (Identity-Aware Proxy)**: Sits in front of the Load Balancer backends and requires Google login. Enforces that only users in your org (e.g., @develom.com) can access the app.
- **OAuth 2 client and brand**: The IAP login flow uses a Google OAuth client and brand tied to your project number.
- **Serverless NEG**: A "Network Endpoint Group" that points the Load Balancer to Cloud Run services (no VMs needed).
- **VPC and Firewalls**: Cloud Run and the global external HTTP(S) Load Balancer do not require you to configure custom VPCs or firewall rules for this setup. Google-managed networking and firewalling are used.
- **IAM Policies**: Permissions that allow IAP and specific users/domains to invoke the services.
- **SSL/TLS**: HTTPS is terminated at the Load Balancer with a certificate for your domain.
- **Environment Variables**: Application-level settings that enabled CORS and correct API routing (e.g., `FRONTEND_URL` for backend CORS; `NEXT_PUBLIC_BACKEND_URL` for frontend).

## Environment specifics

- **Project ID**: `adk-rag-agent-2025`
- **Project Number**: `895727663973`
- **Region**: `us-central1`
- **Public URL**: `https://34.36.213.78.nip.io`
- **IAP OAuth Client ID**: `895727663973-1k6tu1a8vm9q4rt3gbcls8aca5m6ia7m.apps.googleusercontent.com`
- **IAP Service Account**: `service-895727663973@gcp-sa-iap.iam.gserviceaccount.com`
- **Organization access restricted to**: `@develom.com`

## High-level architecture

```
Browser → HTTPS → External HTTP(S) Load Balancer (IAP enforced)
├── "/" → Frontend Cloud Run service
└── "/api/*" → Backend Cloud Run service
```

- IAP handles OAuth 2 Google login, then passes authorized requests to Cloud Run.
- Backend allows CORS from the frontend origin via `FRONTEND_URL` environment variable.

## Resource Inventory

*Note: Some Google-managed resources (e.g., SSL cert names, forwarding rule names) are not explicitly named in deployment logs. Where exact names weren't available, they're documented as "Google-managed" with known IDs when available.*

| # | Resource Type | Name | ID / Number | Location / Scope | Purpose | Key Config | IAM / Policies | Labels/Tags |
|---|---|---|---|---|---|---|---|---|
| 1 | **Project** | adk-rag-agent-2025 | Number: 895727663973 | Global | Administrative container for all resources | Org: restricted to `@develom.com` via IAP | Standard project-level IAM | N/A |
| 2 | **Cloud Run Service** | frontend | URL: https://frontend-895727663973.us-central1.run.app | us-central1 | Hosts Next.js UI | Env: `NEXT_PUBLIC_BACKEND_URL=https://34.36.213.78.nip.io` | roles/run.invoker: domain:develom.com, user:hector@develom.com, IAP SA | None specified |
| 3 | **Cloud Run Service** | backend | URL: https://backend-43uf5nyn7a-uc.a.run.app | us-central1 | Hosts FastAPI RAG API | Env: `FRONTEND_URL=https://34.36.213.78.nip.io` (CORS) | roles/run.invoker: domain:develom.com, user:hector@develom.com, IAP SA | None specified |
| 4 | **Serverless NEG** | backend-neg | Path: projects/adk-rag-agent-2025/regions/us-central1/networkEndpointGroups/backend-neg | us-central1 | Connects LB to backend Cloud Run | Targets Cloud Run backend | Google-managed IAM | N/A |
| 5 | **LB Backend Service** | frontend-backend-service | Global ID not shown | Global | Default service for "/" paths | Protocol: HTTP; port 80 | IAP enabled at LB layer overall | N/A |
| 6 | **LB Backend Service** | backend-backend-service | ID: 8085438154401310765 | Global | Routes "/api", "/api/*" to backend | IAP: enabled true; OAuth client configured | IAP binding: roles/iap.httpsResourceAccessor to domain:develom.com and user:hector@develom.com | N/A |
| 7 | **URL Map** | frontend-url-map | ID: 4575056165271674379 | Global | Routing logic for LB | Path rules: "/api", "/api/*" → backend-backend-service; default → frontend-backend-service | N/A | N/A |
| 8 | **External HTTPS LB** | Google-managed LB for 34.36.213.78.nip.io | Public IP: 34.36.213.78 | Global | Terminates TLS; applies IAP; routes to Cloud Run via NEGs | HTTPS; SSL cert for nip.io; URL map attached | IAP policy attached to backend services | N/A |
| 9 | **SSL Certificate** | Google-managed cert for 34.36.213.78.nip.io | Google-managed | Global | Enables HTTPS at LB | Auto-provisioned/managed by Google | N/A | N/A |
| 10 | **IAP OAuth Brand** | projects/895727663973/brands/895727663973 | Brand ID: 895727663973 | Project scope | Google OAuth screen metadata | Published consent screen | N/A | N/A |
| 11 | **IAP OAuth Client** | IAP client for LB | ID: 895727663973-1k6tu1a8vm9q4rt3gbcls8aca5m6ia7m.apps.googleusercontent.com | Project scope | Used by IAP to authenticate users | Redirects to accounts.google.com | N/A | N/A |
| 12 | **IAP Service Account** | gcp-sa-iap | Email: service-895727663973@gcp-sa-iap.iam.gserviceaccount.com | Project scope | IAP control plane identity | Granted roles/run.invoker on Cloud Run services | roles/run.invoker on frontend & backend | N/A |
| 13 | **IAM Binding** | Cloud Run Invoker (frontend) | Binding on service "frontend" | us-central1 | Allow LB/IAP and org users to call frontend | Members: IAP SA; domain:develom.com; user:hector@develom.com | role: roles/run.invoker | N/A |
| 14 | **IAM Binding** | Cloud Run Invoker (backend) | Binding on service "backend" | us-central1 | Allow LB/IAP and org users to call backend | Members: IAP SA; domain:develom.com; user:hector@develom.com | role: roles/run.invoker | N/A |
| 15 | **IAM Binding** | IAP HTTPS Resource Access | Binding on LB backend services | Global | Restrict IAP access to org and specific user | Members: domain:develom.com; user:hector@develom.com | role: roles/iap.httpsResourceAccessor | N/A |
| 16 | **VPC** | Google-managed serverless networking | N/A | Global | Underpins Cloud Run and LB | No custom VPC configured | N/A | N/A |
| 17 | **Firewall Rules** | Google-managed | N/A | Global | Default allow for managed entry points | No custom firewall rules created | N/A | N/A |
| 18 | **DNS** | nip.io wildcard | Domain: 34.36.213.78.nip.io | Public | Name resolves to IP automatically | No Cloud DNS managed zone needed | N/A | N/A |
| 19 | **App Env Vars (Frontend)** | NEXT_PUBLIC_BACKEND_URL | Value: https://34.36.213.78.nip.io | us-central1 | Next.js client-side base URL | Ensures same-origin calls via LB | N/A | N/A |
| 20 | **App Env Vars (Backend)** | FRONTEND_URL | Value: https://34.36.213.78.nip.io | us-central1 | FastAPI CORS allowlist | Enables CORS for frontend origin | N/A | N/A |

## Why IAP + LB + Cloud Run was chosen

- **Security**: IAP adds an enterprise-grade OAuth layer before any request hits your services.
- **Simplicity**: Cloud Run serverless removes VM management and auto-scales.
- **Maintainability**: Clear separation of concerns (routing at LB, auth at IAP, app logic in services).
- **CORS Resolution**: Using same domain via LB and correctly configuring backend CORS (`FRONTEND_URL`) prevents browser-side fetch failures.

## Policies and access control (plain-language)

- **Who can open the app**: Users who pass Google OAuth through IAP and belong to the `@develom.com` domain (and optionally specific user accounts).
- **Who can invoke services**: The IAP service account and your org-domain are granted `roles/run.invoker` on both Cloud Run services.
- **Backend CORS**: Only the frontend origin `https://34.36.213.78.nip.io` is allowed by the backend's CORS middleware.

## Notes on resources not explicitly named

Some LB components (forwarding rule names, target proxies, SSL cert resource names) are Google-managed in this deployment path. Their exact names aren't necessary to operate or understand the system; what matters is how they connect:

```
Global HTTPS endpoint → URL Map → Backend Services → Serverless NEGs → Cloud Run services
```

## Final checks you can run

### Verify IAP login redirect
```bash
# Navigate to the URL - should redirect to Google OAuth
curl -I https://34.36.213.78.nip.io
```

### Verify API routes via LB
```bash
# Should return HTTP 302 (IAP) when not logged in
curl -I https://34.36.213.78.nip.io/api
```

### Verify CORS headers from backend
```bash
# Should include access-control-allow-origin header
curl -s -I -H "Origin: https://34.36.213.78.nip.io" https://backend-43uf5nyn7a-uc.a.run.app/
```

## Summary

- You now have a secure, production-grade architecture using **Cloud Run + External HTTPS LB + IAP**.
- Access is constrained to your org domain; **OAuth 2** is handled by IAP with a properly configured client and brand.
- Routing sends "/" to frontend and "/api/*" to backend via **serverless NEGs**.
- Browser **CORS issues** are resolved by setting `FRONTEND_URL` on the backend and using same-origin calls from the frontend.

## Architecture Diagram

```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer                            │
│                https://34.36.213.78.nip.io                 │
│                     (SSL + IAP)                            │
│  Routes: "/" → Frontend, "/api/*" → Backend                │
└─────────────────────┬───────────────────────────────────────┘
                      │
              ┌───────┴────────┐
              │                │
              ▼                ▼
    ┌─────────────────┐  ┌─────────────────┐
    │    Frontend     │  │    Backend      │
    │   (Next.js)     │  │   (FastAPI)     │
    │                 │  │                 │
    │ NEXT_PUBLIC_    │  │ FRONTEND_URL=   │
    │ BACKEND_URL=    │  │ https://34.36.  │
    │ https://34.36.  │  │ 213.78.nip.io   │
    │ 213.78.nip.io   │  │ (CORS allowlist)│
    │ (API calls to)  │  │                 │
    └─────────────────┘  └─────────────────┘
```

## Request Flow

1. **User visits**: `https://34.36.213.78.nip.io`
2. **IAP redirects**: Google OAuth login
3. **After auth**: Frontend loads from Load Balancer
4. **API calls**: Frontend → `https://34.36.213.78.nip.io/api/*`
5. **Load Balancer routes**: `/api/*` → Backend service
6. **Backend allows**: CORS from `https://34.36.213.78.nip.io`
7. **Success**: API calls work without CORS blocking

---

## 🎯 Why the Same URL Appears Multiple Times

Excellent question! This is actually the **key insight** that solved our CORS problem. Let me explain why the same URL appears in different places and what each one means:

### 1. Load Balancer URL: `https://34.36.213.78.nip.io`
- **What it is**: The **public entry point** that users access
- **Purpose**: Single domain for the entire application
- **Routes**: 
  - `/` → Frontend service
  - `/api/*` → Backend service

### 2. Frontend `NEXT_PUBLIC_BACKEND_URL`: `https://34.36.213.78.nip.io`
- **What it is**: Where the frontend **thinks** the backend API is located
- **Purpose**: Tells the frontend JavaScript code where to send API calls
- **Result**: Frontend makes calls to `https://34.36.213.78.nip.io/api/auth/register`

### 3. Backend `FRONTEND_URL`: `https://34.36.213.78.nip.io`
- **What it is**: Which domain the backend **allows** for CORS requests
- **Purpose**: Backend CORS middleware allows requests from this origin
- **Result**: Backend accepts API calls from the Load Balancer domain

## 🔄 The Magic of Same-Domain Architecture

```
User Browser:
├── Loads frontend from: https://34.36.213.78.nip.io/
├── Makes API calls to:  https://34.36.213.78.nip.io/api/*
└── Same origin = No CORS issues! ✅

Load Balancer:
├── Receives: https://34.36.213.78.nip.io/
├── Routes to: Frontend Cloud Run service
├── Receives: https://34.36.213.78.nip.io/api/*  
└── Routes to: Backend Cloud Run service

Backend CORS:
├── Receives request from: https://34.36.213.78.nip.io
├── Checks FRONTEND_URL: https://34.36.213.78.nip.io
└── Match! Allow the request ✅
```

## 🚫 What We Avoided (The Broken Approach)

If we had used **different URLs**:

```
❌ BROKEN APPROACH:
Frontend loaded from: https://34.36.213.78.nip.io/
Frontend calls API at: https://backend-43uf5nyn7a-uc.a.run.app/api/*
                       ↑
                   Different domain = CORS error!
```

## 🎓 The Key Insight

The **same URL in all three places** creates a **same-origin architecture**:

1. **Browser perspective**: All requests go to `34.36.213.78.nip.io` → No CORS
2. **Load Balancer**: Routes different paths to different services
3. **Backend CORS**: Allows requests from the Load Balancer domain

## 🎯 The Three Different Roles of the Same URL

### 1. Load Balancer: `https://34.36.213.78.nip.io`
- **Role**: Public entry point that users access
- **Function**: Routes different paths to different services
- **Routes**: `/` → Frontend, `/api/*` → Backend

### 2. Frontend `NEXT_PUBLIC_BACKEND_URL`: `https://34.36.213.78.nip.io`
- **Role**: Where frontend JavaScript sends API calls
- **Function**: Tells the browser where the backend API is located
- **Result**: API calls go to `https://34.36.213.78.nip.io/api/*`

### 3. Backend `FRONTEND_URL`: `https://34.36.213.78.nip.io`
- **Role**: CORS allowlist for the backend
- **Function**: Backend allows requests from this origin
- **Result**: Backend accepts API calls from the Load Balancer domain

## 🔄 Why This Architecture Works

```
Browser's Perspective (Same Origin):
┌─────────────────────────────────────┐
│ Page loaded from: 34.36.213.78.nip.io/     │
│ API calls go to:  34.36.213.78.nip.io/api/ │
│ Same domain = No CORS restrictions! ✅      │
└─────────────────────────────────────┘
```

## 🚫 What We Avoided (Alternative Broken Approach)

If we had used different URLs:
```
❌ BROKEN:
Frontend: https://34.36.213.78.nip.io/
API calls: https://backend-43uf5nyn7a-uc.a.run.app/api/
           ↑ Different domain = CORS error!
```

## 🎓 Final Key Insight

Using the **same URL in all three places** creates a **same-origin architecture** where:
- Browser sees all requests as same-domain (no CORS)
- Load Balancer intelligently routes to different services
- Backend allows requests from the "frontend" domain (which is actually the Load Balancer)

This is why the same URL appears everywhere - it's not duplication, it's **intentional architectural design** to solve the CORS problem! 🎉

---

*This document serves as a comprehensive inventory of all Google Cloud resources used in the RAG Agent deployment. It can be used for auditing, troubleshooting, or replicating the deployment in other environments.*
