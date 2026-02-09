# Fix: "The string did not match the expected pattern" Error

## Problem
When trying to login via IAP at `https://34.49.46.115.nip.io`, you get the error:
**"The string did not match the expected pattern"**

This is a Google OAuth client-side validation error indicating the OAuth client doesn't have the correct redirect URIs configured.

## Root Cause
The IAP OAuth client `351592762922-t4k0kr1kqk3i4rdbu6porj8p881fjo13.apps.googleusercontent.com` is missing the required redirect URIs for the load balancer domain.

## Solution: Add Redirect URIs Manually

### Step 1: Open Google Cloud Console
1. Go to: https://console.cloud.google.com/apis/credentials?project=adk-rag-ma
2. Find the OAuth 2.0 Client ID: `351592762922-t4k0kr1kqk3i4rdbu6porj8p881fjo13`
3. Click on it to edit

### Step 2: Add Authorized Redirect URIs
Add the following redirect URI:
```
https://iap.googleapis.com/v1/oauth/clientIds/351592762922-t4k0kr1kqk3i4rdbu6porj8p881fjo13.apps.googleusercontent.com:handleRedirect
```

### Step 3: Save Changes
Click **Save** at the bottom of the page.

### Step 4: Test
1. Wait 1-2 minutes for changes to propagate
2. Clear browser cache/cookies or use incognito mode
3. Try accessing: https://34.49.46.115.nip.io
4. You should now be able to authenticate successfully

## Why This Happens
- The `gcloud` CLI cannot programmatically update OAuth client redirect URIs
- When IAP backend services are configured, the redirect URI must be manually added
- This is a one-time manual step required for IAP setup

## Alternative: Use Existing OAuth Client
If you have another OAuth client that already has the correct redirect URIs configured, you can update the IAP backend services to use that client instead:

```bash
# List available OAuth clients
gcloud alpha iap oauth-clients list \
  --brand=projects/351592762922/brands/351592762922 \
  --project=adk-rag-ma

# Update backend service to use different OAuth client
gcloud iap web update-oauth2 \
  --oauth2-client-id=<WORKING_CLIENT_ID> \
  --oauth2-client-secret=<CLIENT_SECRET> \
  --resource-type=backend-services \
  --service=backend-backend-service \
  --project=adk-rag-ma
```

## Status
- **Current OAuth Client**: `351592762922-t4k0kr1kqk3i4rdbu6porj8p881fjo13.apps.googleusercontent.com`
- **Load Balancer**: https://34.49.46.115.nip.io
- **Required Action**: Add redirect URI manually in console
