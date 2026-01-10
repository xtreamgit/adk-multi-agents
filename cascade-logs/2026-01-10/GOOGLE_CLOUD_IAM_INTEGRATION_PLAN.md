# Google Cloud IAP + OAuth 2.0 Integration Plan
## Secure Authentication & Authorization Best Practices

**Project:** adk-multi-agents  
**Date:** January 10, 2026  
**Updated:** Based on existing IAP infrastructure  
**Purpose:** Design secure authentication and authorization architecture leveraging Google Cloud Identity-Aware Proxy (IAP)

---

## Table of Contents
1. [Current State Analysis](#current-state-analysis)
2. [Existing IAP Infrastructure](#existing-iap-infrastructure)
3. [Recommended Architecture with IAP](#recommended-architecture-with-iap)
4. [Security Best Practices](#security-best-practices)
5. [Implementation Approach](#implementation-approach)
6. [Migration Strategy](#migration-strategy)
7. [Code Examples](#code-examples)
8. [IAP vs Firebase Comparison](#iap-vs-firebase-comparison)

---

## Current State Analysis

### Existing Authentication System
Your application currently implements a **custom JWT-based authentication** system with:

**Components:**
- `AuthService`: JWT token creation/verification, password hashing (bcrypt)
- `AuthMiddleware`: Token validation via FastAPI dependencies
- `AuthorizationMiddleware`: Role-based access control (RBAC)
- SQLite database for user storage
- Custom user/group/role/permission model

**Current Flow:**
```
User Login → Verify Password → Generate JWT → Store Session → Validate Token on Requests
```

**Strengths:**
- ✅ Working RBAC system with groups, roles, and permissions
- ✅ Session tracking with agent/corpus context
- ✅ Flexible permission system (wildcard, prefix matching)
- ✅ Active user management

**Limitations:**
- ❌ Local database (not scalable for multi-instance deployments)
- ❌ Manual password management
- ❌ No federated identity support
- ❌ No SSO capabilities
- ❌ Secret key management in code/env vars
- ❌ Token refresh requires database query

### Existing IAP Infrastructure (Found in Repository)

Your repository already contains **comprehensive IAP deployment scripts**:

**Infrastructure Files:**
- `infrastructure/lib/iap.sh` - IAP configuration and OAuth client setup
- `infrastructure/lib/oauth.sh` - OAuth consent screen configuration
- `infrastructure/deploy-config.sh` - Deployment configuration management
- `infrastructure/deploy-all.sh` - Complete deployment orchestration

**Current IAP Setup:**
- ✅ Load Balancer with HTTPS and SSL certificates
- ✅ IAP enabled on Cloud Run backend services
- ✅ OAuth 2.0 client configuration
- ✅ Domain-restricted access (@{ORGANIZATION_DOMAIN})
- ✅ IAP Service Account: `service-{PROJECT_NUMBER}@gcp-sa-iap.iam.gserviceaccount.com`
- ✅ Role: `roles/iap.httpsResourceAccessor`

**What's Missing:**
- ❌ Backend JWT token verification from IAP headers
- ❌ User synchronization between IAP and local database
- ❌ Integration with existing RBAC system
- ❌ Frontend authentication flow

---

## Identity-Aware Proxy (IAP) Architecture

### What is IAP?

**Identity-Aware Proxy (IAP)** is Google Cloud's application-level access control service that:
- Sits between users and your Cloud Run services via Load Balancer
- Authenticates users using Google OAuth 2.0
- Injects verified user identity into request headers
- Provides centralized access control
- **No code changes needed for basic authentication**
- Works seamlessly with Cloud Run and Load Balancer

### Why IAP Over Firebase?

**Advantages:**
- ✅ **Zero-trust security** - Authentication happens at Google's edge, before reaching your app
- ✅ **No frontend changes needed** - IAP handles OAuth flow automatically
- ✅ **Domain restriction** - Automatically restrict to @yourcompany.com
- ✅ **Enterprise SSO** - SAML/OIDC federation support
- ✅ **Audit logging** - Built into Cloud Logging
- ✅ **Lower cost** - Free (no per-user charges like Identity Platform)
- ✅ **Already deployed** - Your infrastructure scripts are ready
- ✅ **Simpler architecture** - One less service to manage

**Perfect for:**
- Internal enterprise applications
- Organization-wide access (@develom.com)
- B2B applications with known domains
- Applications already on Cloud Run + Load Balancer

### Your Existing IAP Deployment Scripts

From `infrastructure/lib/iap.sh`:
```bash
# 1. Creates OAuth 2.0 client with Load Balancer redirect URIs
# 2. Creates IAP service account: service-{PROJECT_NUMBER}@gcp-sa-iap.iam.gserviceaccount.com
# 3. Grants Cloud Run Invoker permissions to IAP SA
# 4. Enables IAP on all backend services
# 5. Grants roles/iap.httpsResourceAccessor to:
#    - Admin user
#    - Organization domain (@{ORGANIZATION_DOMAIN})
```

**Deployment Flow:**
1. `deploy-config.sh` - Configure project settings
2. `oauth.sh` - Set up OAuth consent screen
3. `iap.sh` - Enable IAP on Load Balancer backends
4. Access controlled at Load Balancer level

### IAP Authentication Flow

```
User Request → Load Balancer → IAP Check
                                   ↓
                            Authenticated?
                                   ↓
                    No ←───────────┴───────────→ Yes
                    ↓                            ↓
         Redirect to Google OAuth      Add IAP headers:
                    ↓                  - X-Goog-IAP-JWT-Assertion
         Google Sign-In Page           - X-Goog-Authenticated-User-Email
                    ↓                  - X-Goog-Authenticated-User-ID
         User Authenticates                      ↓
                    ↓                  Forward to Cloud Run
         Callback to IAP                         ↓
                    ↓                  Backend verifies JWT
         Set IAP session                         ↓
                    └──────────→      Extract user info
                                                 ↓
                                      Get/Create user in DB
                                                 ↓
                                      Apply custom RBAC
                                                 ↓
                                      Return response
```

---

## Recommended Architecture with IAP

### Three-Layer Security Architecture

```
                         User Browser
                              │
                              │ HTTPS Request
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                     LOAD BALANCER (HTTPS)                     │
│                     (External IP + SSL Cert)                  │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       │ All traffic flows through IAP
                       ▼
┌──────────────────────────────────────────────────────────────┐
│              LAYER 1: Identity-Aware Proxy (IAP)              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  1. Check if user is authenticated                     │  │
│  │  2. If not → Redirect to Google OAuth 2.0             │  │
│  │  3. Verify domain (@develom.com)                      │  │
│  │  4. Check roles/iap.httpsResourceAccessor permission  │  │
│  │  5. Generate & sign JWT token                         │  │
│  │  6. Inject headers:                                   │  │
│  │     - X-Goog-IAP-JWT-Assertion (signed JWT)          │  │
│  │     - X-Goog-Authenticated-User-Email                │  │
│  │     - X-Goog-Authenticated-User-ID                   │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────────┘
                       │ Request + IAP Headers
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                    CLOUD RUN (Backend/Frontend)               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │   LAYER 2: IAP JWT Verification (Backend Middleware)   │  │
│  │  1. Extract X-Goog-IAP-JWT-Assertion header           │  │
│  │  2. Verify JWT signature with Google's public keys    │  │
│  │  3. Validate audience matches your OAuth client       │  │
│  │  4. Extract user email from verified JWT              │  │
│  │  5. Get or create user in local SQLite database       │  │
│  │  6. Map Google account → Local user record            │  │
│  └────────────────────┬───────────────────────────────────┘  │
│                       ▼                                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │   LAYER 3: Application RBAC (Your Existing System)     │  │
│  │  1. Check user's groups (admin-users, analysts)       │  │
│  │  2. Verify corpus access permissions                  │  │
│  │  3. Apply role-based permissions (read:*, write:*)    │  │
│  │  4. Session tracking (agent, corpora context)         │  │
│  └────────────────────┬───────────────────────────────────┘  │
│                       ▼                                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │     LAYER 4: GCP Resource Access (Service Account)     │  │
│  │  - Vertex AI RAG queries                               │  │
│  │  - Cloud Storage access                                │  │
│  │  - Secret Manager for credentials                      │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Key Components

**1. Load Balancer**
- Entry point for all traffic
- Terminates HTTPS (SSL certificate)
- Routes to backend services via serverless NEGs
- IAP enabled at backend service level

**2. IAP Layer (Google-Managed)**
- Automatic OAuth 2.0 flow
- No frontend code needed
- Injects verified identity headers
- Domain restriction enforcement

**3. Backend Middleware (You implement)**
- Verify IAP JWT assertion
- Sync user to local database
- Apply custom RBAC rules

**4. Existing RBAC System (Keep as-is)**
- Groups, roles, permissions
- Corpus access control
- Session management

### IAP Authentication Flow

```
User accesses https://your-domain.com
         ↓
Load Balancer receives request
         ↓
IAP checks: User authenticated?
         ↓
    [NO] → Redirect to accounts.google.com
         → User signs in with Google (@develom.com)
         → Validate domain matches allowed list  
         → Check roles/iap.httpsResourceAccessor
         → Create IAP session cookie
         → Redirect back to original URL
         ↓
    [YES] → Extract IAP session
          → Generate signed JWT with user info
          → Add headers to request:
             * X-Goog-IAP-JWT-Assertion: eyJhbGc...
             * X-Goog-Authenticated-User-Email: accounts.google.com:user@develom.com
             * X-Goog-Authenticated-User-ID: accounts.google.com:12345
          ↓
Forward request to Cloud Run (Backend/Frontend)
          ↓
Backend Middleware:
  1. Extract X-Goog-IAP-JWT-Assertion header
  2. Verify JWT signature (Google public keys)
  3. Validate audience = OAuth client ID
  4. Extract email from verified JWT payload
  5. Query local DB for user by Google email
     → If not exists: Create new user record
     → If exists: Update last_login timestamp
  6. Load user's groups, roles, permissions
  7. Create/update session in user_sessions table
  8. Attach User object to request context
          ↓
Application Logic:
  - Check permissions (existing RBAC)
  - Execute business logic
  - Query Vertex AI (via service account)
          ↓
Return response to user
```

---

## Security Best Practices

### 1. IAP JWT Verification (Critical!)
```python
# ✅ DO: Always verify IAP JWT on backend
from google.auth.transport import requests
from google.oauth2 import id_token
import logging

logger = logging.getLogger(__name__)

# Your OAuth 2.0 client ID from IAP setup
IAP_AUDIENCE = "/projects/{PROJECT_NUMBER}/global/backendServices/{BACKEND_SERVICE_ID}"

def verify_iap_jwt(iap_jwt: str) -> dict:
    """
    Verify IAP JWT assertion.
    
    Returns:
        Decoded JWT payload with user info
        
    Raises:
        ValueError: If JWT is invalid
    """
    try:
        # Verify and decode JWT
        # Google's public keys are automatically fetched
        decoded_token = id_token.verify_oauth2_token(
            iap_jwt,
            requests.Request(),
            audience=IAP_AUDIENCE
        )
        
        # Validate issuer
        if decoded_token['iss'] != 'https://cloud.google.com/iap':
            raise ValueError('Invalid issuer')
        
        return decoded_token
        
    except Exception as e:
        logger.error(f"IAP JWT verification failed: {e}")
        raise ValueError("Invalid IAP token")

# ❌ DON'T: Trust X-Goog-Authenticated-User-Email without verifying JWT
# Anyone can set HTTP headers - always verify the signed JWT!
```

### 2. Secret Management
```python
# ✅ DO: Use Secret Manager
from google.cloud import secretmanager

def get_secret(secret_id: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")

# ❌ DON'T: Store secrets in code or environment variables
SECRET_KEY = "hardcoded-secret"  # Bad!
```

### 3. Service Account Permissions (Principle of Least Privilege)
```bash
# ✅ DO: Grant minimal required permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:backend@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"  # Only Vertex AI access

# ❌ DON'T: Use overly broad permissions
# --role="roles/owner"  # Too much access!
```

### 4. Session Management with IAP
```python
# ✅ DO: IAP manages authentication sessions via cookies
# Your backend just needs to verify the JWT on each request
# No need to manage tokens on frontend!

# Backend creates application session after IAP verification:
from datetime import datetime, timezone

def create_user_session(user_id: int, session_id: str):
    """Create application session in database."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO user_sessions 
            (session_id, user_id, created_at, last_activity, is_active)
            VALUES (?, ?, ?, ?, ?)
        """, (
            session_id,
            user_id,
            datetime.now(timezone.utc).isoformat(),
            datetime.now(timezone.utc).isoformat(),
            True
        ))
        conn.commit()

# ❌ DON'T: Try to manage IAP cookies yourself
# IAP handles authentication cookies automatically
```

### 5. CORS Configuration
```python
# ✅ DO: Restrict origins
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://your-domain.com",
        "https://admin.your-domain.com"
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)

# ❌ DON'T: Allow all origins
# allow_origins=["*"]
```

### 6. Rate Limiting
```python
# ✅ DO: Implement rate limiting
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/api/auth/login")
@limiter.limit("5/minute")  # Max 5 attempts per minute
async def login(request: Request):
    pass
```

### 7. Audit Logging
```python
# ✅ DO: Log authentication events
import logging
from google.cloud import logging as cloud_logging

def log_auth_event(user_id: str, event: str, success: bool):
    cloud_logging_client = cloud_logging.Client()
    logger = cloud_logging_client.logger('auth-events')
    
    logger.log_struct({
        'user_id': user_id,
        'event': event,
        'success': success,
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'ip_address': request.client.host
    })
```

---

## Implementation Approach

### Phase 1: Deploy IAP Infrastructure (Day 1)

#### 1.1 Configure Deployment Settings
```bash
cd infrastructure

# Interactive configuration
./deploy-config.sh --interactive

# Or command line
./deploy-config.sh \
  --project=adk-rag-ma \
  --region=us-west1 \
  --domain=develom.com \
  --admin=admin@develom.com \
  --repo=cloud-run-repo1
```

#### 1.2 Deploy Infrastructure with IAP
```bash
# Full deployment (includes IAP setup)
./deploy-all.sh

# This will:
# 1. Create OAuth consent screen (manual step)
# 2. Create OAuth 2.0 client
# 3. Set up Load Balancer with SSL
# 4. Deploy Cloud Run services
# 5. Enable IAP on backend services
# 6. Grant IAP access to your domain
```

#### 1.3 Install Backend Dependencies
```bash
cd backend

# Add IAP verification library
pip install google-auth google-auth-httplib2

# Update requirements.txt
echo "google-auth>=2.23.0" >> requirements.txt
echo "google-auth-httplib2>=0.1.1" >> requirements.txt
```

### Phase 2: Backend IAP Integration (Days 2-3)

#### 2.1 Create IAP Verification Service
```python
# backend/src/services/iap_service.py
"""
IAP (Identity-Aware Proxy) verification service.
Verifies JWT tokens from Google Cloud IAP.
"""

import os
import logging
from typing import Optional, Dict
from google.auth.transport import requests
from google.oauth2 import id_token

logger = logging.getLogger(__name__)

# Get from environment or Cloud Run metadata
PROJECT_NUMBER = os.getenv('PROJECT_NUMBER')
BACKEND_SERVICE_ID = os.getenv('BACKEND_SERVICE_ID')  # From Load Balancer

# Construct IAP audience
# Format: /projects/{PROJECT_NUMBER}/global/backendServices/{BACKEND_SERVICE_ID}
IAP_AUDIENCE = f"/projects/{PROJECT_NUMBER}/global/backendServices/{BACKEND_SERVICE_ID}"


class IAPService:
    """Service for IAP JWT verification."""
    
    @staticmethod
    def verify_iap_jwt(iap_jwt: str) -> Dict[str, any]:
        """
        Verify IAP JWT assertion from X-Goog-IAP-JWT-Assertion header.
        
        Args:
            iap_jwt: JWT token from IAP header
            
        Returns:
            Decoded JWT payload containing:
            - email: User's email address
            - sub: User's unique Google ID
            - iss: Issuer (should be https://cloud.google.com/iap)
            - aud: Audience (your backend service)
            
        Raises:
            ValueError: If JWT is invalid, expired, or has wrong audience
        """
        try:
            # Verify JWT signature and decode
            # This automatically fetches Google's public keys
            decoded_token = id_token.verify_oauth2_token(
                iap_jwt,
                requests.Request(),
                audience=IAP_AUDIENCE
            )
            
            # Validate issuer
            if decoded_token.get('iss') != 'https://cloud.google.com/iap':
                raise ValueError(f"Invalid issuer: {decoded_token.get('iss')}")
            
            logger.info(f"IAP JWT verified for user: {decoded_token.get('email')}")
            return decoded_token
            
        except Exception as e:
            logger.error(f"IAP JWT verification failed: {e}")
            raise ValueError(f"Invalid IAP token: {str(e)}")
    
    @staticmethod
    def extract_user_info(decoded_jwt: Dict[str, any]) -> Dict[str, str]:
        """
        Extract user information from verified JWT.
        
        Args:
            decoded_jwt: Verified JWT payload
            
        Returns:
            Dictionary with user info:
            - email: User's Google email
            - google_id: User's unique Google identifier
            - name: User's display name (if available)
        """
        return {
            'email': decoded_jwt.get('email'),
            'google_id': decoded_jwt.get('sub'),
            'name': decoded_jwt.get('name', decoded_jwt.get('email').split('@')[0])
        }
    
    @staticmethod
    def get_iap_audience() -> str:
        """Get configured IAP audience for debugging."""
        return IAP_AUDIENCE
```

#### 2.2 Create IAP Authentication Middleware
```python
# backend/src/middleware/iap_auth_middleware.py
"""
IAP authentication middleware for FastAPI.
Verifies IAP JWT and creates/updates user in local database.
"""

from fastapi import Request, HTTPException, status, Depends
from typing import Optional
import logging

from services.iap_service import IAPService
from services.user_service import UserService
from models.user import User

logger = logging.getLogger(__name__)

# Header name for IAP JWT
IAP_JWT_HEADER = "X-Goog-IAP-JWT-Assertion"
IAP_EMAIL_HEADER = "X-Goog-Authenticated-User-Email"


async def get_current_user_iap(request: Request) -> User:
    """
    FastAPI dependency to get current user from IAP headers.
    
    Flow:
    1. Extract IAP JWT from header
    2. Verify JWT signature and audience
    3. Extract user email from verified JWT
    4. Get or create user in local database
    5. Return User object with groups/permissions
    
    Raises:
        HTTPException 401: If IAP JWT is missing or invalid
        HTTPException 403: If user is inactive
        
    Returns:
        User object from local database
    """
    # Extract IAP JWT header
    iap_jwt = request.headers.get(IAP_JWT_HEADER)
    
    if not iap_jwt:
        logger.warning("Missing IAP JWT header - request not from IAP?")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing IAP authentication. Access must be through Load Balancer.",
        )
    
    try:
        # Verify IAP JWT
        decoded_token = IAPService.verify_iap_jwt(iap_jwt)
        user_info = IAPService.extract_user_info(decoded_token)
        
        email = user_info['email']
        google_id = user_info['google_id']
        name = user_info['name']
        
        logger.info(f"IAP authenticated user: {email}")
        
        # Get or create user in local database
        user = UserService.get_user_by_email(email)
        
        if not user:
            # Create new user from IAP authentication
            user = UserService.create_user_from_iap(
                email=email,
                google_id=google_id,
                full_name=name
            )
            logger.info(f"New user created from IAP: {email}")
        else:
            # Update last login
            UserService.update_last_login(user.id)
        
        # Check if user is active
        if not user.is_active:
            logger.warning(f"Inactive user attempted access: {email}")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Your account is inactive. Please contact an administrator."
            )
        
        return user
        
    except ValueError as e:
        logger.error(f"IAP JWT verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid IAP token: {str(e)}",
        )
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication failed"
        )


async def get_current_user_optional_iap(request: Request) -> Optional[User]:
    """
    Optional IAP authentication - returns None if not authenticated.
    Useful for endpoints that work with or without authentication.
    """
    iap_jwt = request.headers.get(IAP_JWT_HEADER)
    
    if not iap_jwt:
        return None
    
    try:
        return await get_current_user_iap(request)
    except HTTPException:
        return None
```

#### 2.3 Update User Model and Service
```python
# backend/src/models/user.py
# Add firebase_uid field to User model
from pydantic import BaseModel
from typing import Optional

class User(BaseModel):
    id: int
    username: str
    email: str
    full_name: str
    firebase_uid: Optional[str] = None  # Add this field
    is_active: bool = True
    created_at: str
    last_login: Optional[str] = None

# backend/src/services/user_service.py
# Add methods to UserService
class UserService:
    @staticmethod
    def get_user_by_firebase_uid(firebase_uid: str) -> Optional[User]:
        """Get user by Firebase UID."""
        user_dict = UserRepository.get_by_firebase_uid(firebase_uid)
        if user_dict:
            return User(**user_dict)
        return None
    
    @staticmethod
    def create_user_from_firebase(
        firebase_uid: str, 
        email: str, 
        full_name: str
    ) -> User:
        """Create user from Firebase authentication."""
        # Generate username from email
        username = email.split('@')[0]
        
        # Create user without password (Firebase handles auth)
        user_dict = UserRepository.create_firebase_user(
            username=username,
            email=email,
            full_name=full_name,
            firebase_uid=firebase_uid
        )
        
        # Add to default group
        GroupService.add_user_to_default_group(user_dict['id'])
        
        return User(**user_dict)
```

#### 2.4 Database Migration
```sql
-- backend/src/database/migrations/006_add_firebase_uid.sql
-- Migration 006: Add Firebase UID to users table
-- Description: Support Firebase authentication alongside local auth
-- Date: 2026-01-10

-- Add firebase_uid column
ALTER TABLE users ADD COLUMN firebase_uid TEXT UNIQUE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);

-- Add auth_provider column to track authentication method
ALTER TABLE users ADD COLUMN auth_provider TEXT DEFAULT 'local';
-- Values: 'local', 'firebase', 'google', 'saml'

-- Make password nullable for Firebase users
-- (Keep for backward compatibility with existing users)

-- Update existing users
UPDATE users SET auth_provider = 'local' WHERE firebase_uid IS NULL;
```

### Phase 3: Frontend Integration (Week 2)

#### 3.1 Firebase Configuration
```typescript
// frontend/src/lib/firebase.ts
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
```

#### 3.2 Google Sign-In Component
```typescript
// frontend/src/components/GoogleSignIn.tsx
'use client';

import { signInWithPopup, GoogleAuthProvider } from 'firebase/auth';
import { auth } from '@/lib/firebase';
import { useRouter } from 'next/navigation';

export default function GoogleSignIn() {
  const router = useRouter();

  const handleGoogleSignIn = async () => {
    const provider = new GoogleAuthProvider();
    
    try {
      const result = await signInWithPopup(auth, provider);
      const idToken = await result.user.getIdToken();
      
      // Send token to backend
      const response = await fetch('/api/auth/firebase-login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken })
      });
      
      if (response.ok) {
        const { user, sessionToken } = await response.json();
        // Store session token
        localStorage.setItem('sessionToken', sessionToken);
        router.push('/chat');
      }
    } catch (error) {
      console.error('Sign-in error:', error);
    }
  };

  return (
    <button
      onClick={handleGoogleSignIn}
      className="flex items-center gap-3 px-6 py-3 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
    >
      <svg width="20" height="20" viewBox="0 0 48 48">
        {/* Google logo SVG */}
      </svg>
      <span>Sign in with Google</span>
    </button>
  );
}
```

#### 3.3 Update API Client
```typescript
// frontend/src/lib/api-enhanced.ts
// Add Firebase token handling
class APIClient {
  async getAuthToken(): Promise<string | null> {
    // Check for Firebase user first
    const user = auth.currentUser;
    if (user) {
      return await user.getIdToken();
    }
    
    // Fall back to session token
    return localStorage.getItem('sessionToken');
  }
  
  async request(endpoint: string, options: RequestInit = {}) {
    const token = await this.getAuthToken();
    
    const headers = {
      'Content-Type': 'application/json',
      ...(token && { 'Authorization': `Bearer ${token}` }),
      ...options.headers
    };
    
    return fetch(`${this.baseURL}${endpoint}`, {
      ...options,
      headers
    });
  }
}
```

### Phase 4: Service Account Configuration (Week 2)

#### 4.1 Create Service Account
```bash
# Create service account for backend
gcloud iam service-accounts create adk-backend \
  --display-name="ADK Backend Service" \
  --project=adk-rag-ma

# Grant Vertex AI permissions
gcloud projects add-iam-policy-binding adk-rag-ma \
  --member="serviceAccount:adk-backend@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# Grant Secret Manager access
gcloud projects add-iam-policy-binding adk-rag-ma \
  --member="serviceAccount:adk-backend@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Bind to Cloud Run service
gcloud run services update backend \
  --service-account=adk-backend@adk-rag-ma.iam.gserviceaccount.com \
  --region=us-west1
```

#### 4.2 Use Application Default Credentials
```python
# backend/src/services/vertex_ai_service.py
from google.cloud import aiplatform
from google.auth import default

# No need for explicit credentials - uses service account
credentials, project = default()
aiplatform.init(
    project='adk-rag-ma',
    location='us-west1',
    credentials=credentials
)
```

---

## Migration Strategy

### Option A: Gradual Migration (Recommended)
**Timeline:** 2-3 weeks

```python
# Support both authentication methods during transition
async def get_current_user_hybrid(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> User:
    """Support both Firebase and legacy JWT tokens."""
    token = credentials.credentials
    
    # Try Firebase first
    try:
        return await get_current_user_firebase(credentials)
    except:
        pass
    
    # Fall back to legacy JWT
    try:
        return await get_current_user(credentials)
    except:
        raise HTTPException(401, "Invalid token")
```

**Steps:**
1. ✅ Deploy Firebase authentication alongside existing system
2. ✅ Update frontend to offer both login methods
3. ✅ Monitor usage and migrate users gradually
4. ✅ Deprecate legacy system after 90% adoption
5. ✅ Remove legacy code

### Option B: Big Bang Migration
**Timeline:** 1 week

**Steps:**
1. ✅ Set maintenance window
2. ✅ Migrate all users to Firebase
3. ✅ Force password reset via Firebase
4. ✅ Deploy new system
5. ✅ Notify users

---

## Cost Estimation

### Identity Platform
- **Free Tier:** 50,000 MAUs/month
- **Paid:** $0.0055 per MAU beyond free tier
- **Estimate:** ~$10-50/month for 2,000-10,000 users

### Secret Manager
- **Storage:** $0.06 per secret version per month
- **Access:** $0.03 per 10,000 operations
- **Estimate:** ~$1-5/month

### Cloud Logging
- **First 50 GB:** Free
- **Beyond:** $0.50 per GB
- **Estimate:** ~$5-20/month

**Total Estimated Cost:** $15-75/month

---

## Next Steps

### Immediate Actions (This Week)
1. ✅ Enable Identity Platform API
2. ✅ Create Firebase project configuration
3. ✅ Set up development environment
4. ✅ Create service accounts
5. ✅ Plan database migration

### Week 1 Tasks
- [ ] Implement FirebaseService
- [ ] Update authentication middleware
- [ ] Create database migration
- [ ] Add frontend Firebase SDK
- [ ] Build Google Sign-In component

### Week 2 Tasks
- [ ] Integrate Firebase auth with existing RBAC
- [ ] Test authentication flows
- [ ] Configure service accounts for Vertex AI
- [ ] Update API client
- [ ] Deploy to staging

### Week 3 Tasks
- [ ] User acceptance testing
- [ ] Performance testing
- [ ] Security audit
- [ ] Deploy to production
- [ ] Monitor and optimize

---

## Security Checklist

- [ ] Token verification on every request
- [ ] HTTPS only (no HTTP)
- [ ] Secrets in Secret Manager (not env vars)
- [ ] Service account with minimal permissions
- [ ] CORS restrictions configured
- [ ] Rate limiting enabled
- [ ] Audit logging active
- [ ] MFA enabled for admin users
- [ ] Session timeout configured
- [ ] Regular security scans
- [ ] Vulnerability monitoring
- [ ] Backup and disaster recovery plan

---

## References

- [Google Cloud Identity Platform Docs](https://cloud.google.com/identity-platform/docs)
- [Firebase Authentication Best Practices](https://firebase.google.com/docs/auth/best-practices)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

---

**Last Updated:** January 10, 2026
