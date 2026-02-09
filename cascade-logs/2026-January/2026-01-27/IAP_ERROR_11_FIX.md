# IAP Error Code 11 - Fix Instructions

**Error**: "There was a problem with your request. Error code 11"

**Cause**: OAuth client is missing required redirect URIs for IAP

**Solution**: Add redirect URIs to the OAuth client

---

## Quick Fix Steps

### 1. Open OAuth Client Configuration
Direct link: https://console.cloud.google.com/apis/credentials/oauthclient/351592762922-rrh8e1didp94udgm9lvrtbh00rj5d4rf.apps.googleusercontent.com?project=adk-rag-ma

Or manually:
1. Go to: https://console.cloud.google.com/apis/credentials?project=adk-rag-ma
2. Find and click: **Load Balancer IAP Client**
3. Client ID: `351592762922-rrh8e1didp94udgm9lvrtbh00rj5d4rf.apps.googleusercontent.com`

### 2. Add Authorized Redirect URIs

Click **"ADD URI"** and add these **exact** URIs:

```
https://iap.googleapis.com/v1/oauth/clientIds/351592762922-rrh8e1didp94udgm9lvrtbh00rj5d4rf.apps.googleusercontent.com:handleRedirect
```

**Important**: This is the primary IAP redirect URI that must be added.

### 3. Optional Additional URIs (if needed)

You may also want to add:
```
https://34.49.46.115.nip.io/_gcp_gatekeeper/authenticate
```

### 4. Save Changes

1. Click **SAVE** at the bottom of the page
2. Wait 1-2 minutes for changes to propagate
3. Try accessing: https://34.49.46.115.nip.io

---

## What This Error Means

**IAP Error Code 11**: "Access denied: The OAuth client is not authorized for this request"

This happens when:
- OAuth client exists and is configured in IAP backend services ✅
- But the OAuth client doesn't have the redirect URIs that IAP needs ❌

---

## Verification

After adding the redirect URIs, test access:

```bash
curl -I https://34.49.46.115.nip.io
```

You should see a redirect to `accounts.google.com` for authentication.

---

## Current Deployment Status

✅ **Backend deployed**: `backend-00016-86x`
✅ **Frontend deployed**: `frontend-00016-86x`
✅ **IAP enabled**: All backend services configured
✅ **OAuth client created**: `351592762922-rrh8e1didp94udgm9lvrtbh00rj5d4rf`
⚠️ **OAuth redirect URIs**: Need to be added manually (this step)

---

## Alternative: Use Existing OAuth Client

If you prefer, you can revert to the old OAuth client that already has redirect URIs configured:

```bash
# Revert to old OAuth client
OLD_CLIENT_ID="351592762922-t4k0kr1kqk3i4rdbu6porj8p881fjo13.apps.googleusercontent.com"

gcloud iap web enable \
  --resource-type=backend-services \
  --service=backend-backend-service \
  --oauth2-client-id=$OLD_CLIENT_ID \
  --oauth2-client-secret=$(gcloud secrets versions access latest --secret=iap-oauth-client-secret --project=adk-rag-ma) \
  --project=adk-rag-ma

gcloud iap web enable \
  --resource-type=backend-services \
  --service=frontend-backend-service \
  --oauth2-client-id=$OLD_CLIENT_ID \
  --oauth2-client-secret=$(gcloud secrets versions access latest --secret=iap-oauth-client-secret --project=adk-rag-ma) \
  --project=adk-rag-ma
```

---

**Next Step**: Add the redirect URI in the console, then test access.
