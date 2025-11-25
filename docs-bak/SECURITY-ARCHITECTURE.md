<!--
================================================================================
SECURITY ARCHITECTURE REFERENCE DOCUMENT
ADK RAG Agent - Google Cloud Platform Deployment
================================================================================

DOCUMENT INFORMATION:
---------------------
Author:       Hector (hector@develom.com)
Date:         2025-01-08
Version:      1.0.0
Project:      adk-rag-agent
Repository:   xtreamgit/adk-rag-agent-deploy

PURPOSE:
--------
This document provides a comprehensive security architecture reference for
deploying the ADK RAG Agent application on Google Cloud Platform (GCP) using
Identity-Aware Proxy (IAP) with External HTTPS Load Balancer.

IMPORTANCE FOR FUTURE DEPLOYMENTS:
----------------------------------
This reference is CRITICAL for understanding and replicating secure GCP 
deployments because it documents:

1. THE CORS BREAKTHROUGH SOLUTION
   - Explains why backend services require `allUsers` IAM access
   - Documents how to prevent OAuth redirect loops with Load Balancer + IAP
   - Critical for any GCP deployment using IAP with Cloud Run backends

2. MULTI-LAYER SECURITY MODEL
   - Network-level ingress controls (internal-and-cloud-load-balancing)
   - IAP + OAuth authentication at Load Balancer
   - Application-level CORS and JWT token validation
   - Complete defense-in-depth strategy

3. COMMON PITFALLS AND SOLUTIONS
   - Why CORS alone is insufficient (doesn't protect against curl/API access)
   - Why URL obscurity is not a security control
   - Why ingress restriction is the missing security layer
   - Attack vectors and their mitigations

4. ARCHITECTURAL DECISIONS
   - Trade-offs between security and functionality
   - Why certain configurations are required vs. optional
   - How different security layers interact and complement each other

5. GOOGLE CLOUD BEST PRACTICES
   - Proper IAM role assignments
   - Service account security
   - Load Balancer configuration with IAP
   - Cloud Run ingress controls

TARGET AUDIENCE:
----------------
- Cloud Architects designing GCP deployments
- DevOps Engineers implementing secure infrastructure
- Security Engineers auditing cloud deployments
- Developers troubleshooting authentication issues
- Future team members maintaining this application

KEY LESSONS LEARNED:
--------------------
This document captures hard-won knowledge from resolving complex security
challenges that are not well-documented in Google's official documentation,
particularly around the interaction between IAP, Load Balancers, Cloud Run,
and CORS policies.

Without this reference, future deployments risk:
- OAuth redirect loops and authentication failures
- Exposed backend services vulnerable to direct access
- CORS errors breaking application functionality
- Incomplete security implementations
- Hours of debugging similar issues

MAINTENANCE:
------------
This document should be updated when:
- Security architecture changes are implemented
- New attack vectors are discovered and mitigated
- GCP introduces new security features relevant to this deployment
- Lessons learned from production incidents

VERSION HISTORY:
----------------
v1.0.0 (2025-01-08) - Initial comprehensive security architecture documentation
                      including CORS breakthrough solution and ingress controls

================================================================================
-->

# ADK RAG Agent Security Architecture

## Overview

This document provides a complete security architecture reference for the ADK RAG Agent deployment on Google Cloud Platform, with emphasis on the critical security layers required for production-grade deployments using Identity-Aware Proxy (IAP) with Cloud Run services.

---

## The Dual Protection Model

### **Important Distinction:**

There are **two separate authentication layers** that often get confused:

1. **Cloud Run Service IAM** - Controls who can invoke the Cloud Run service directly
2. **Load Balancer IAP** - Controls who can access resources through the Load Balancer

Let me break down what's actually happening:

---

## Current Configuration Analysis

### **Backend Cloud Run Service IAM:**

```bash
# Check backend IAM policy
gcloud run services get-iam-policy backend --region=$REGION
```

**Expected output:**
```yaml
bindings:
- members:
  - allUsers  ← Anyone can invoke the Cloud Run service
  role: roles/run.invoker
- members:
  - user:hector@develom.com
  role: roles/run.invoker
```

**What this means:**
- ✅ The Load Balancer can invoke the backend without authentication
- ⚠️ **Anyone with the direct Cloud Run URL can also invoke it** (but read below for why this is mitigated)

### **Load Balancer Backend Service IAP:**

```bash
# Check IAP configuration on Load Balancer backend service
gcloud compute backend-services describe backend-backend-service \
  --global \
  --format="yaml(iap)"
```

**Expected output:**
```yaml
iap:
  enabled: true
  oauth2ClientId: 965537996595-oo6omqp06vlimbfbhluvnahkfda8b0d9.apps.googleusercontent.com
  oauth2ClientSecret: GOCSPX-***
  oauth2ClientSecretSha256: ***
```

**What this means:**
- ✅ IAP authentication is required to access the Load Balancer endpoint
- ✅ Only authenticated users from your organization can reach the backend **through the Load Balancer**

---

## Does Backend `allUsers` Prevent Direct Internet Access? **NO**

### **The Hard Truth:**

**No, granting `allUsers` to the backend Cloud Run service does NOT prevent direct internet access to the backend Cloud Run URL.**

If someone knows your backend Cloud Run URL, they **can** make direct HTTP requests to it:

```bash
# Direct access to backend Cloud Run URL (bypasses Load Balancer)
curl https://backend-xyz-uc.a.run.app/api/sessions

# This request will:
# ✅ Reach the backend Cloud Run service (allUsers allows invocation)
# ✅ Backend processes the request
# ❌ CORS blocks the response in browser (Origin header doesn't match)
# ⚠️ BUT: curl/API clients can still see the response!
```

---

## What Actually Protects the Backend?

### **Protection Layers:**

#### **1. CORS Protection (Browser-Only Defense)**

```python
# backend/src/api/server.py
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3000")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[FRONTEND_URL],  # Only https://YOUR-IP.nip.io
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Protection Level:** 🟡 **Medium**
- ✅ Blocks browser-based attacks
- ✅ Prevents XSS/CSRF from malicious websites
- ❌ Does NOT block command-line tools (curl, wget, API clients)
- ❌ Does NOT block direct HTTP requests outside browsers

**Example Attack Blocked:**
```javascript
// Malicious website tries to access backend
fetch('https://backend-xyz-uc.a.run.app/api/sessions')
  .then(r => r.json())
  .catch(err => console.error('CORS blocked!'));
// ❌ Blocked by CORS
```

**Example Attack NOT Blocked:**
```bash
# Attacker with backend URL can bypass CORS
curl https://backend-xyz-uc.a.run.app/api/sessions
# ✅ Returns data (no CORS check in non-browser client)
```

#### **2. URL Obscurity (Security by Obscurity)**

**Protection Level:** 🟡 **Low-Medium**
- Backend Cloud Run URL is not published: `backend-[random]-uc.a.run.app`
- Users only know Load Balancer URL: `https://YOUR-IP.nip.io`
- ⚠️ **But:** Backend URL can be discovered through:
  - Network inspection tools
  - DNS enumeration
  - Error messages
  - Social engineering

#### **3. Application-Level Authentication**

**Protection Level:** 🟢 **High** (if implemented)
- JWT token validation on sensitive endpoints
- API key requirements
- Session validation

**Current State:**
Looking at your troubleshooting output, this may not be fully implemented for all endpoints.

---

## The Real Problem: Backend is Partially Exposed

### **Your TROUBLESHOOT.md Shows:**

```
📋 7. Testing HTTP Security
  Testing Frontend authentication requirement... ✅ (HTTP 403 - authentication required)
  Testing Backend API authentication requirement... ❌ (HTTP 405 - may allow unauthenticated access)
```

**HTTP 405** means the backend is responding (not blocked), but the method isn't allowed.

### **What This Means:**

The backend Cloud Run service **is directly accessible** from the internet if someone knows the URL. The only protections are:

1. **CORS** - Blocks browser-based requests
2. **URL Obscurity** - Backend URL is not advertised
3. **Application Logic** - Endpoints may require JWT tokens (but not all do)

---

## How to Properly Secure the Backend

### **Option 1: Remove `allUsers` and Fix IAP Authentication (Ideal but Complex)**

This requires solving the OAuth redirect loop differently:

```bash
# Remove allUsers from backend
gcloud run services remove-iam-policy-binding backend \
  --region=$REGION \
  --member="allUsers" \
  --role="roles/run.invoker"

# Grant IAP service account access
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
IAP_SA="service-${PROJECT_NUMBER}@gcp-sa-iap.iam.gserviceaccount.com"

gcloud run services add-iam-policy-binding backend \
  --region=$REGION \
  --member="serviceAccount:${IAP_SA}" \
  --role="roles/run.invoker"
```

**Problem:**
This brings back the CORS/OAuth redirect loop issue we solved. You'd need to:
- Configure IAP to pass authentication headers to backend
- Ensure backend accepts IAP-signed requests
- May still encounter CORS issues

### **Option 2: Use VPC Service Controls (Enterprise Solution)**

Restrict Cloud Run services to only be accessible from within a VPC:

```bash
# Create VPC connector
gcloud compute networks vpc-access connectors create rag-connector \
  --region=$REGION \
  --network=default \
  --range=10.8.0.0/28

# Update backend to use VPC connector
gcloud run services update backend \
  --region=$REGION \
  --vpc-connector=rag-connector \
  --vpc-egress=all-traffic
```

**Benefits:**
- Backend only accessible through VPC
- Load Balancer can access via VPC
- Direct internet access blocked

### **Option 3: Add Ingress Controls (Simplest Additional Layer)**

Restrict backend to only accept traffic from Load Balancer:

```bash
# Set ingress to internal and cloud load balancing
gcloud run services update backend \
  --region=$REGION \
  --ingress=internal-and-cloud-load-balancing
```

**What this does:**
- ✅ Blocks direct internet access to backend Cloud Run URL
- ✅ Only allows traffic from:
  - Google Cloud Load Balancing
  - VPC internal traffic
- ✅ **This is the missing piece!**

Let me check if this is already configured:





Perfect! I found the security gap. Let me explain:

---

## **The Critical Missing Security Control**

### **Current Configuration:**

Looking at your deployment scripts, both services are configured with:

```bash
--ingress=all  # ⚠️ This allows ALL internet traffic
```

**This means:**
- ✅ Load Balancer can access backend
- ⚠️ **Anyone on the internet can also access backend directly** (if they know the URL)
- The backend is **NOT restricted** to Load Balancer-only traffic

---

## **The Complete Security Picture**

### **What Currently Protects Backend:**

1. **URL Obscurity** 🟡 - Backend URL not advertised (`backend-xyz-uc.a.run.app`)
2. **CORS Headers** 🟡 - Browser-based requests blocked (but curl/API tools bypass)
3. **JWT Tokens** 🟢 - Application-level auth (only for endpoints that check tokens)
4. **IAM `allUsers`** ❌ - Actually allows everyone to invoke the service

### **What's Missing:**

**Network-level ingress restriction** 🔴 - Backend accepts traffic from anywhere

---

## **The Secure Solution: Ingress Restriction**

### **Add This to Your Deployment Scripts:**

```bash
# Update backend to ONLY accept Load Balancer traffic
gcloud run services update backend \
  --region=$REGION \
  --ingress=internal-and-cloud-load-balancing

# Update frontend (optional but recommended)
gcloud run services update frontend \
  --region=$REGION \
  --ingress=internal-and-cloud-load-balancing
```

### **What `--ingress=internal-and-cloud-load-balancing` Does:**

**Blocks:**
- ❌ Direct internet access to `backend-xyz-uc.a.run.app`
- ❌ Curl/wget from public internet
- ❌ Any client outside Google Cloud

**Allows:**
- ✅ Google Cloud Load Balancer traffic
- ✅ Traffic from VPC (if configured)
- ✅ Traffic from other Cloud Run services in same project

---

## **Complete Security Architecture (With Ingress Control)**

```
┌─────────────────────────────────────────────────────────┐
│           Internet User (Untrusted)                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
        Tries: https://backend-xyz-uc.a.run.app
                     │
                     ▼
        ┌────────────────────────────┐
        │   Cloud Run Backend        │
        │   Ingress: internal-and-   │
        │   cloud-load-balancing     │
        │                            │
        │   ❌ ACCESS DENIED         │
        │   (not from Load Balancer) │
        └────────────────────────────┘


┌─────────────────────────────────────────────────────────┐
│           Internet User (Trusted Path)                   │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
        https://YOUR-IP.nip.io (Load Balancer)
                     │
        ┌────────────▼────────────┐
        │    IAP Authentication   │
        │    OAuth Required       │
        │    @develom.com only    │
        └────────────┬────────────┘
                     │ ✅ Authenticated
                     ▼
        ┌────────────────────────────┐
        │   Load Balancer Routes:    │
        │   /* → Frontend            │
        │   /api/* → Backend         │
        └────────┬───────────┬───────┘
                 │           │
                 ▼           ▼
        ┌─────────────┐  ┌──────────────┐
        │  Frontend   │  │   Backend    │
        │  Ingress:   │  │   Ingress:   │
        │  internal-  │  │   internal-  │
        │  and-lb     │  │   and-lb     │
        │             │  │              │
        │  ✅ Accepts │  │   ✅ Accepts │
        │  from LB    │  │   from LB    │
        └─────────────┘  └──────────────┘
```

---

## **Security Comparison**

### **Without Ingress Restriction (Current):**

| Attack Vector | Protected? | How |
|--------------|-----------|-----|
| Browser direct access to backend | 🟡 Partial | CORS blocks browser |
| Curl/API direct access to backend | ❌ No | No protection |
| Direct backend URL enumeration | ❌ No | Service responds |
| XSS/CSRF attacks | ✅ Yes | CORS + IAP |
| DDoS on backend URL | ❌ No | Backend is exposed |

### **With Ingress Restriction (Recommended):**

| Attack Vector | Protected? | How |
|--------------|-----------|-----|
| Browser direct access to backend | ✅ Yes | Ingress blocks + CORS |
| Curl/API direct access to backend | ✅ Yes | Ingress blocks |
| Direct backend URL enumeration | ✅ Yes | Connection refused |
| XSS/CSRF attacks | ✅ Yes | CORS + IAP |
| DDoS on backend URL | ✅ Yes | Traffic must go through LB |

---

## **Recommended Fix**

### **Update Your Deployment Scripts:**



---

## **Summary: Why Backend Needs Both `allUsers` AND Ingress Restriction**

### **The Answer to Your Question:**

> "Please explain how is the backend only allows IAP service account can invoke and does this prevent internet users from accessing the backend?"

**Current State:**
- **Backend IAM:** `allUsers` granted → Anyone can invoke if they have the URL
- **Backend Ingress:** `--ingress=all` → Service accepts traffic from anywhere
- **Result:** ❌ **Does NOT prevent direct internet access**

**What You Need:**
1. **Keep `allUsers` IAM** - Required for Load Balancer to invoke without OAuth loop
2. **Add Ingress Restriction** - `--ingress=internal-and-cloud-load-balancing`

### **Change Lines 195 and 216 in [deploy-secure-v0.2.sh](cci:7://file:///Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent/infrastructure/deploy-secure-v0.2.sh:0:0-0:0):**

```bash
# Line 195: Change this
--ingress=all

# To this
--ingress=internal-and-cloud-load-balancing

# Line 216: Change this
--ingress=all  

# To this
--ingress=internal-and-cloud-load-balancing
```

### **After This Change:**

**Security Enforcement:**
1. ✅ Load Balancer can access backend (IAP authenticates users first)
2. ✅ Direct internet access to backend URL is **blocked at network level**
3. ✅ CORS still provides browser protection
4. ✅ IAP provides user authentication
5. ✅ Backend only responds to Load Balancer traffic

**Attack Scenarios:**
- User tries `https://backend-xyz-uc.a.run.app` → ❌ **Connection refused**
- User tries `curl https://backend-xyz-uc.a.run.app` → ❌ **Connection refused**
- User tries `https://YOUR-IP.nip.io` → ✅ **IAP authentication required** → ✅ **Allowed if authorized**

This is the **missing security layer** that prevents direct backend access while maintaining the CORS breakthrough solution! 🔒









┌──────────────────────────────────────────────────┐
│  Internet User                                    │
└────────────┬─────────────────────────────────────┘
             │
             │ Direct access attempt:
             │ curl https://backend-xyz.run.app
             │
             ▼
┌──────────────────────────────────────────────────┐
│  Cloud Run Backend                                │
│  --ingress=internal-and-cloud-load-balancing     │
│                                                   │
│  ❌ Request rejected: Not from Load Balancer     │
└──────────────────────────────────────────────────┘


┌──────────────────────────────────────────────────┐
│  Internet User → Load Balancer (IAP)             │
└────────────┬─────────────────────────────────────┘
             │
             │ https://YOUR-IP.nip.io/api/...
             │
             ▼
┌──────────────────────────────────────────────────┐
│  Google Cloud Load Balancer                      │
│  (Recognized as trusted source)                  │
└────────────┬─────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│  Cloud Run Backend                                │
│  --ingress=internal-and-cloud-load-balancing     │
│                                                   │
│  ✅ Request accepted: From Load Balancer         │
└──────────────────────────────────────────────────┘



I'll update both deployment scripts to use the secure ingress setting. Let me make the changes:





Let me search for the deployment sections in the complete OAuth script:





Perfect! I can see that [deploy-complete-oauth-v0.2.sh](cci:7://file:///Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent/infrastructure/deploy-complete-oauth-v0.2.sh:0:0-0:0) actually calls [deploy-secure-v0.2.sh](cci:7://file:///Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent/infrastructure/deploy-secure-v0.2.sh:0:0-0:0) internally (line 241), so I only need to update the [deploy-secure-v0.2.sh](cci:7://file:///Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent/infrastructure/deploy-secure-v0.2.sh:0:0-0:0) file. Let me make the changes:

Perfect! I've successfully updated [deploy-secure-v0.2.sh](cci:7://file:///Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent/infrastructure/deploy-secure-v0.2.sh:0:0-0:0) with the secure ingress settings. Let me also add documentation about this security enhancement to the README:





Perfect! I've successfully updated both the deployment script and documentation. Here's a summary of the changes:

## ✅ Changes Completed

### **1. Updated [deploy-secure-v0.2.sh](cci:7://file:///Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent/infrastructure/deploy-secure-v0.2.sh:0:0-0:0)**

**Line 195:** Backend ingress
```bash
# Changed from:
--ingress=all

# To:
--ingress=internal-and-cloud-load-balancing
```

**Line 216:** Frontend ingress
```bash
# Changed from:
--ingress=all

# To:
--ingress=internal-and-cloud-load-balancing
```

### **2. Updated [README.md](cci:7://file:///Users/hector/github.com/xtreamgit/adk-rag-agent-deploy/adk-rag-agent/README.md:0:0-0:0)**

Added a new section **"Network-Level Ingress Control"** explaining:
- What `internal-and-cloud-load-balancing` does
- Attack prevention examples
- How it complements IAP protection

## Security Impact

### **Before (Less Secure):**
```
Internet User → Direct backend URL → ✅ Backend accepts (CORS only protection)
```

### **After (Secure):**
```
Internet User → Direct backend URL → ❌ CONNECTION REFUSED (network-level block)
Internet User → Load Balancer URL → IAP Auth → ✅ Backend (if authenticated)
```

## How This Works with CORS Breakthrough

The complete security architecture now has **three layers**:

1. **Network Layer:** `--ingress=internal-and-cloud-load-balancing` blocks direct access
2. **Authentication Layer:** IAP + OAuth at Load Balancer
3. **Application Layer:** CORS + JWT tokens + `allUsers` IAM for LB routing

This maintains the CORS breakthrough solution (allowing `allUsers` IAM access) while adding network-level protection that prevents any direct access to the Cloud Run service URLs.

## Next Deployment

When you run either script:
```bash
./infrastructure/deploy-complete-oauth-v0.2.sh
```

Both services will be deployed with the secure ingress setting automatically! 🔒✅