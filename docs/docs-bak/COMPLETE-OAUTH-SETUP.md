# Complete OAuth Setup Instructions for ADK RAG Agent

## Overview

This document provides step-by-step instructions to recreate the complete OAuth-protected RAG Agent deployment with **Load Balancer + IAP** that was successfully working at `https://34.36.213.78.nip.io`.

The current `deploy-secure.sh` script only sets up **Cloud Run OAuth**, but the working solution requires **External Load Balancer + Identity-Aware Proxy (IAP)**.

## 🏗️ Architecture Overview

```
Internet → External HTTPS Load Balancer (SSL + IAP) → Cloud Run Services
├── "/" → Frontend Cloud Run service
└── "/api/*" → Backend Cloud Run service
```

## 📋 Prerequisites

### 1. Required Tools
- `gcloud` CLI authenticated with admin permissions
- Project: `adk-rag-agent-2025`
- Region: `us-central1`

### 2. OAuth Consent Screen (Manual Setup Required)
**⚠️ CRITICAL: This must be done manually in Google Cloud Console**

1. Go to [Google Cloud Console > APIs & Services > OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)
2. Select **Internal** (for organization users only)
3. Fill in required fields:
   - **App name**: ADK RAG Agent
   - **User support email**: hector@develom.com
   - **Developer contact**: hector@develom.com
4. **Save and Continue** through all steps
5. **Publish** the consent screen

## 🚀 Deployment Steps

### Step 1: Build and Deploy Cloud Run Services

```bash
# Run the current deploy-secure.sh to get Cloud Run services
./infrastructure/deploy-secure.sh
```

This creates:
- Backend Cloud Run service
- Frontend Cloud Run service
- OAuth client for IAP
- Basic authentication setup

### Step 2: Create External Load Balancer with IAP

**⚠️ MISSING: The current script doesn't create the Load Balancer. You need to run additional commands:**

#### 2.1 Create Static IP Address
```bash
gcloud compute addresses create rag-agent-ip --global
```

#### 2.2 Get the Static IP
```bash
export STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --format="value(address)")
echo "Static IP: $STATIC_IP"
```

#### 2.3 Create SSL Certificate
```bash
gcloud compute ssl-certificates create rag-agent-ssl-cert \
  --domains="$STATIC_IP.nip.io" \
  --global
```

#### 2.4 Create Backend Services for Load Balancer
```bash
# Create serverless NEGs for Cloud Run services
gcloud compute network-endpoint-groups create frontend-neg \
  --region=us-central1 \
  --network-endpoint-type=serverless \
  --cloud-run-service=frontend

gcloud compute network-endpoint-groups create backend-neg \
  --region=us-central1 \
  --network-endpoint-type=serverless \
  --cloud-run-service=backend

# Create backend services
gcloud compute backend-services create frontend-backend-service \
  --global \
  --load-balancing-scheme=EXTERNAL_MANAGED

gcloud compute backend-services create backend-backend-service \
  --global \
  --load-balancing-scheme=EXTERNAL_MANAGED

# Add NEGs to backend services
gcloud compute backend-services add-backend frontend-backend-service \
  --global \
  --network-endpoint-group=frontend-neg \
  --network-endpoint-group-region=us-central1

gcloud compute backend-services add-backend backend-backend-service \
  --global \
  --network-endpoint-group=backend-neg \
  --network-endpoint-group-region=us-central1
```

#### 2.5 Create URL Map for Routing
```bash
# Create URL map
gcloud compute url-maps create rag-agent-url-map \
  --default-service=frontend-backend-service \
  --global

# Add path matcher for API routes
gcloud compute url-maps add-path-matcher rag-agent-url-map \
  --path-matcher-name=api-matcher \
  --default-service=frontend-backend-service \
  --path-rules="/api/*=backend-backend-service" \
  --global
```

#### 2.6 Create HTTPS Proxy and Forwarding Rule
```bash
# Create target HTTPS proxy
gcloud compute target-https-proxies create rag-agent-https-proxy \
  --ssl-certificates=rag-agent-ssl-cert \
  --url-map=rag-agent-url-map \
  --global

# Create forwarding rule
gcloud compute forwarding-rules create rag-agent-forwarding-rule \
  --address=rag-agent-ip \
  --target-https-proxy=rag-agent-https-proxy \
  --global \
  --ports=443
```

### Step 3: Configure Identity-Aware Proxy (IAP)

#### 3.1 Create IAP Service Account
```bash
# Create official IAP service account
gcloud beta services identity create --service=iap.googleapis.com
```

#### 3.2 Grant IAP Service Account Permissions
```bash
# Get project number
export PROJECT_NUMBER=$(gcloud projects describe adk-rag-agent-2025 --format="value(projectNumber)")

# Grant Cloud Run Invoker role to IAP service account
gcloud run services add-iam-policy-binding frontend \
  --region=us-central1 \
  --member="serviceAccount:service-$PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding backend \
  --region=us-central1 \
  --member="serviceAccount:service-$PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

#### 3.3 Enable IAP on Backend Services
```bash
# Get OAuth client details from deploy-secure.sh output
export CLIENT_ID="895727663973-1k6tu1a8vm9q4rt3gbcls8aca5m6ia7m.apps.googleusercontent.com"
export CLIENT_SECRET="GOCSPX-[your-secret-from-deploy-output]"

# Enable IAP on frontend backend service
gcloud compute backend-services update frontend-backend-service \
  --global \
  --iap=enabled,oauth2-client-id=$CLIENT_ID,oauth2-client-secret=$CLIENT_SECRET

# Enable IAP on backend backend service  
gcloud compute backend-services update backend-backend-service \
  --global \
  --iap=enabled,oauth2-client-id=$CLIENT_ID,oauth2-client-secret=$CLIENT_SECRET
```

#### 3.4 Configure IAP Access Permissions
```bash
# Grant IAP access to admin user
gcloud projects add-iam-policy-binding adk-rag-agent-2025 \
  --member="user:hector@develom.com" \
  --role="roles/iap.httpsResourceAccessor"

# Grant IAP access to organization domain
gcloud projects add-iam-policy-binding adk-rag-agent-2025 \
  --member="domain:develom.com" \
  --role="roles/iap.httpsResourceAccessor"
```

### Step 4: Configure CORS and Environment Variables

#### 4.1 Update Backend CORS Configuration
```bash
# Set FRONTEND_URL to Load Balancer domain
gcloud run services update backend \
  --region=us-central1 \
  --set-env-vars="FRONTEND_URL=https://$STATIC_IP.nip.io"
```

#### 4.2 Update Frontend Backend URL
```bash
# Set frontend to use Load Balancer for API calls
gcloud run services update frontend \
  --region=us-central1 \
  --set-env-vars="NEXT_PUBLIC_BACKEND_URL=https://$STATIC_IP.nip.io"
```

### Step 5: Wait for SSL Certificate Provisioning

```bash
# Check SSL certificate status (takes 10-15 minutes)
gcloud compute ssl-certificates describe rag-agent-ssl-cert --global
```

Wait until status shows `ACTIVE`.

## 🧪 Testing and Validation

### Test the Complete Setup
```bash
# Run validation script
./infrastructure/validate-security.sh
```

### Manual Testing
1. **Wait 2-3 minutes** for all configurations to propagate
2. **Clear browser cache** completely
3. **Open**: `https://$STATIC_IP.nip.io`
4. **Expected flow**:
   - Redirect to Google OAuth login
   - Sign in with @develom.com account
   - OAuth consent screen (if first time)
   - Access to RAG application

## 📋 Final Configuration Summary

### Working Architecture:
- **URL**: `https://$STATIC_IP.nip.io`
- **Load Balancer**: External HTTPS with SSL certificate
- **IAP**: Enabled with Google OAuth
- **OAuth Client**: Created by deploy-secure.sh
- **IAP Service Account**: `service-$PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com`
- **Domain Restriction**: @develom.com only
- **CORS**: Properly configured for same-domain API calls

### Security Features:
- ✅ Two-layer authentication (IAP + Cloud Run IAM)
- ✅ OAuth consent screen flow
- ✅ Domain-restricted access
- ✅ SSL/HTTPS encryption
- ✅ Enterprise-grade security

## 🔧 Troubleshooting

### Common Issues:

1. **SSL Certificate not ready**: Wait 10-15 minutes for provisioning
2. **IAP Error 52**: Ensure OAuth consent screen is published
3. **CORS errors**: Verify FRONTEND_URL is set correctly on backend
4. **Access denied**: Check IAP permissions and domain restrictions

### Debug Commands:
```bash
# Check SSL certificate status
gcloud compute ssl-certificates describe rag-agent-ssl-cert --global

# Check IAP status
gcloud compute backend-services describe frontend-backend-service --global

# Check Cloud Run environment variables
gcloud run services describe backend --region=us-central1 --format="export"

# Check IAP permissions
gcloud projects get-iam-policy adk-rag-agent-2025
```

## 📝 Notes

- The current `deploy-secure.sh` script is **incomplete** - it only sets up Cloud Run OAuth
- The **Load Balancer + IAP** configuration must be done manually using the commands above
- Consider creating a new script `deploy-complete-oauth.sh` that includes all these steps
- The working solution from the breakthrough used this exact architecture

---

**This setup recreates the complete OAuth-protected RAG Agent that was successfully working with Load Balancer + IAP!** 🚀
