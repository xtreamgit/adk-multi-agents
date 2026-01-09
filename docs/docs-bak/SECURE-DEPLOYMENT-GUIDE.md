# Secure GCP Deployment Guide for ADK RAG Agent

This guide provides step-by-step instructions to deploy your RAG application with **Identity-Aware Proxy (IAP)** protection using Google OAuth authentication.

## 🎯 Security Architecture Overview

Your deployment will have **two layers of security**:

1. **IAP Layer**: Google OAuth authentication restricting access to `develom.com` organization
2. **Application Layer**: Your existing JWT-based user authentication system

This provides defense-in-depth security where users must:
1. First authenticate with Google OAuth (@develom.com accounts only)
2. Then authenticate with your application's login system

## 📋 Prerequisites

Before starting, ensure you have:

- [x] Google Cloud account with billing enabled
- [x] Project `adk-rag-agent-2025` created
- [x] Your account (`hector@develom.com`) has Owner or Editor role on the project
- [x] `gcloud` CLI installed and updated
- [x] Docker installed (for local testing)
- [x] Git repository cloned locally

## 🚀 Step-by-Step Deployment

### Step 1: Authenticate with Google Cloud

```bash
# Login to gcloud
gcloud auth login

# Set application default credentials
gcloud auth application-default login

# Set the project
gcloud config set project adk-rag-agent-2025

# Verify authentication
gcloud auth list
```

### Step 2: Generate Application Secret Key

```bash
# Navigate to your project directory
cd /path/to/adk-rag-agent

# Generate a secure secret key
python3 generate_secret_key.py

# Create secrets file (replace YOUR_GENERATED_KEY with the output from above)
echo "SECRET_KEY=YOUR_GENERATED_KEY" > secrets.env
```

### Step 3: Configure OAuth Consent Screen

**⚠️ This step must be done manually in the Google Cloud Console:**

1. Go to [OAuth Consent Screen](https://console.cloud.google.com/apis/credentials/consent?project=adk-rag-agent-2025)

2. Configure the consent screen:
   - **User Type**: Select `Internal` (for develom.com organization users only)
   - **App name**: `ADK RAG Agent`
   - **User support email**: `hector@develom.com`
   - **App logo**: Upload your organization logo (optional)
   - **App domain**: Leave blank or add your domain
   - **Authorized domains**: Add `develom.com`
   - **Developer contact information**: `hector@develom.com`

3. Click **Save and Continue**

4. **Scopes**: Click **Save and Continue** (no additional scopes needed)

5. **Test users**: Skip this section since you're using Internal user type

6. **Summary**: Review and click **Back to Dashboard**

### Step 4: Run the Secure Deployment Script

```bash
# Make the script executable
chmod +x infrastructure/deploy-secure.sh

# Run the deployment
./infrastructure/deploy-secure.sh
```

The script will:
- ✅ Enable all required APIs
- ✅ Create Artifact Registry repository
- ✅ Set up service accounts with minimal permissions
- ✅ Build and deploy backend/frontend to Cloud Run
- ✅ Create OAuth client for IAP
- ✅ Enable IAP on both services
- ✅ Grant access to your account and organization

### Step 5: Verify Deployment

After deployment completes, you'll see output like:

```
🎉 Secure Deployment Complete!

📋 Deployment Summary:
  Frontend URL: https://frontend-xxxxx-uc.a.run.app
  Backend URL: https://backend-xxxxx-uc.a.run.app
  OAuth Client ID: 123456789-xxxxx.apps.googleusercontent.com
```

### Step 6: Test the Security

1. **Open the frontend URL** in an incognito browser window
2. **You should be redirected** to Google OAuth login
3. **Sign in with your @develom.com account**
4. **After OAuth success**, you'll see your RAG application
5. **Create an account** in the application or log in with existing credentials

## 🔐 Security Validation Checklist

Verify your deployment is secure:

- [ ] Frontend URL redirects to Google OAuth login
- [ ] Only @develom.com accounts can access
- [ ] After OAuth, application login screen appears
- [ ] Application authentication works correctly
- [ ] Backend API is protected (test direct access)
- [ ] CORS is properly configured between frontend/backend

## 🛠️ Management Commands

### Add Additional Users to IAP

```bash
# Add a specific user
gcloud iap web add-iam-policy-binding \
  --resource-type=cloud-run \
  --service=frontend \
  --region=us-central1 \
  --member="user:newuser@develom.com" \
  --role="roles/iap.httpsResourceAccessor"

# Add the same user to backend access
gcloud iap web add-iam-policy-binding \
  --resource-type=cloud-run \
  --service=backend \
  --region=us-central1 \
  --member="user:newuser@develom.com" \
  --role="roles/iap.httpsResourceAccessor"
```

### View Current IAP Permissions

```bash
# Frontend permissions
gcloud iap web get-iam-policy \
  --resource-type=cloud-run \
  --service=frontend \
  --region=us-central1

# Backend permissions
gcloud iap web get-iam-policy \
  --resource-type=cloud-run \
  --service=backend \
  --region=us-central1
```

### Monitor Application Logs

```bash
# Backend logs
gcloud logs read --service=backend --region=us-central1 --limit=50

# Frontend logs
gcloud logs read --service=frontend --region=us-central1 --limit=50

# Real-time log streaming
gcloud logs tail --service=backend --region=us-central1
```

### Update Environment Variables

```bash
# Update backend environment variables
gcloud run services update backend \
  --region=us-central1 \
  --set-env-vars="LOG_LEVEL=DEBUG,NEW_VAR=value"
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### 1. "OAuth Error: access_denied"
**Cause**: User account is not from develom.com organization
**Solution**: Ensure you're signing in with a @develom.com account

#### 2. "This app isn't verified"
**Cause**: OAuth consent screen not properly configured
**Solution**: 
- Go back to OAuth consent screen configuration
- Ensure "Internal" user type is selected
- Add develom.com to authorized domains

#### 3. "IAP Error: You don't have access"
**Cause**: User not granted IAP access
**Solution**:
```bash
gcloud iap web add-iam-policy-binding \
  --resource-type=cloud-run \
  --service=frontend \
  --region=us-central1 \
  --member="user:your-email@develom.com" \
  --role="roles/iap.httpsResourceAccessor"
```

#### 4. CORS Errors in Browser Console
**Cause**: Frontend can't communicate with backend
**Solution**: Redeploy with updated CORS configuration:
```bash
./infrastructure/deploy-secure.sh
```

#### 5. "Missing key inputs argument" Error
**Cause**: Vertex AI environment variables not properly set
**Solution**: Check backend logs and verify PROJECT_ID and GOOGLE_CLOUD_LOCATION are set

### Debug Commands

```bash
# Check service status
gcloud run services list --region=us-central1

# Check IAP status
gcloud iap web list --filter="cloud-run"

# Test backend health (should redirect to OAuth)
curl -I https://your-backend-url.a.run.app/

# Check OAuth brands
gcloud iap oauth-brands list
```

## 🔄 Updating Your Application

When you make code changes:

1. **Commit your changes** to git
2. **Run the deployment script** again:
   ```bash
   ./infrastructure/deploy-secure.sh
   ```
3. **The script will**:
   - Build new images with updated git SHA
   - Deploy updated services
   - Preserve all IAP and security configurations

## 🔒 Security Best Practices

1. **Regular Access Reviews**: Periodically review IAP permissions
2. **Principle of Least Privilege**: Only grant access to users who need it
3. **Monitor Logs**: Set up log-based alerts for security events
4. **Secret Rotation**: Periodically regenerate your SECRET_KEY
5. **OAuth Consent Screen**: Keep contact information updated

## 📊 Monitoring and Alerting

Set up monitoring for your secure deployment:

```bash
# Create log-based metric for failed authentications
gcloud logging metrics create iap_auth_failures \
  --description="Failed IAP authentication attempts" \
  --log-filter='resource.type="cloud_run_revision" AND "IAP" AND "denied"'

# Create alerting policy (configure in Cloud Console)
```

## 🎯 Production Readiness Checklist

Before going live:

- [ ] OAuth consent screen properly configured
- [ ] All required users have IAP access
- [ ] Application authentication working
- [ ] HTTPS enforced on all endpoints
- [ ] Monitoring and alerting configured
- [ ] Backup and disaster recovery plan
- [ ] Security incident response plan
- [ ] Regular security reviews scheduled

## 📞 Support and Resources

- **Google Cloud IAP Documentation**: https://cloud.google.com/iap/docs
- **Cloud Run Security**: https://cloud.google.com/run/docs/securing
- **OAuth 2.0 Best Practices**: https://tools.ietf.org/html/draft-ietf-oauth-security-topics

---

Your RAG Agent is now deployed with enterprise-grade security using Google OAuth and IAP! 🎉
