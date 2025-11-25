# OAuth Consent Screen Setup

**Date:** October 7, 2025  
**Author:** Hector  
**Purpose:** This document provides the complete OAuth Consent Screen configuration for the ADK RAG Agent deployment with Identity-Aware Proxy (IAP) and Google OAuth authentication.

**Screen Captures:** The information in this document was generated from screen captures located in the `doc-screen-captures/` directory:
- `Audience.png` - Audience configuration screenshot
- `Branding.png` - Branding section screenshot
- `Client.png` - OAuth client overview screenshot
- `Client1.png` - Detailed OAuth client configuration screenshot

---

## Overview

This configuration sets up the Google OAuth consent screen for the ADK RAG Agent application. The OAuth consent screen is displayed when users authenticate through Identity-Aware Proxy (IAP) to access the application. This setup ensures proper branding, domain authorization, and user trust during the authentication process.

---

## Branding

### Application Information

| Field | Value |
|-------|-------|
| **App name** | HD Test 5 |
| **User support email** | hector@develom.com |
| **Application home page** | https://frontend-334722600921.us-east4.run.app |
| **Application privacy policy link** | https://frontend-334722600921.us-east4.run.app |
| **Developer contact email** | hector@develom.com |

### Authorized Domains

The following domains are authorized for OAuth authentication:

1. **frontend-334722600921.us-east4.run.app** - Cloud Run frontend service domain
2. **develom.com** - Organization domain
3. **nip.io** - Dynamic DNS service for Load Balancer access
4. **frontend-z35gahfla-uk.a.run.app** - Alternative Cloud Run frontend domain

---

## Audience

### User Type Configuration

| Field | Value |
|-------|-------|
| **User type** | Internal |

**Description**: The OAuth consent screen is configured for **Internal** use, meaning it is restricted to users within the organization (develom.com domain). This setting ensures that only authorized organizational users can access the application through IAP authentication.

**Implications**:
- Only users with `@develom.com` email addresses can authenticate
- External users will be denied access
- Suitable for internal applications and organizational tools
- No Google OAuth verification required for internal apps

---

## Configuration Steps

### 1. Access OAuth Consent Screen

1. Navigate to [Google Cloud Console](https://console.cloud.google.com)
2. Select project: `adk-rag-hdtest5`
3. Go to **APIs & Services** > **OAuth consent screen**

### 2. Configure Branding Information

1. **App name**: Enter `HD Test 5`
2. **User support email**: Select `hector@develom.com`
3. **Application home page**: Enter `https://frontend-334722600921.us-east4.run.app`
4. **Application privacy policy link**: Enter `https://frontend-334722600921.us-east4.run.app`
5. **Developer contact email**: Enter `hector@develom.com`

### 3. Add Authorized Domains

Click **Add Domain** and add each of the following:

```
frontend-334722600921.us-east4.run.app
develom.com
nip.io
frontend-z35gahfla-uk.a.run.app
```

### 4. Configure Scopes (Optional)

For IAP authentication, the default scopes are typically sufficient:
- `openid`
- `email`
- `profile`

### 5. Add Test Users (if in Testing mode)

If the OAuth consent screen is in **Testing** mode, add authorized test users:
- `hector@develom.com`
- Any other @develom.com users who need access

---

## Client

### OAuth Clients

#### Client 1: Load Balancer IAP Client

| Field | Value |
|-------|-------|
| **Client Name** | Load Balancer IAP Client |
| **Creation date** | Oct 6, 2025 |
| **Type** | Web application |
| **Client ID** | 334722600921-3bb9... |

#### Client 2: Web client 1

| Field | Value |
|-------|-------|
| **Client Name** | Web client 1 |
| **Creation date** | Oct 6, 2025 |
| **Type** | Web application |
| **Client ID** | 334722600921-kg9d... |

### Important Note

> **Note:** Client 1 (Load Balancer IAP Client) is automatically created by the Google OAuth service when Identity-Aware Proxy (IAP) is enabled on the Load Balancer backend services. This client is managed by Google and is specifically configured for IAP authentication flows. Client 2 (Web client 1) may be manually created for additional OAuth integration needs.

---

## Authorized URIs

### Web client 1

#### Authorized JavaScript Origins

```
(Empty)
```

#### Authorized Redirect URIs

1. `https://34.36.175.81.nip.io`
2. `https://34.36.175.81.nip.io/_gcp_gatekeeper/authenticate`

#### Client Details

| Field | Value |
|-------|-------|
| **Name** | Web client 1 |
| **Client ID** | 334722600921-kg9dthpps.googleusercontent.com |
| **Creation date** | October 6, 2025 |
| **Last used date** | October 6, 2025 |
| **Client secret** | *****JK |
| **Status** | Enabled |

---

## OAuth Client Configuration

### Client Details

| Field | Value |
|-------|-------|
| **OAuth Client ID** | 334722600921-3bb9hgjnjfd7dijokfugf4hogb7cl0ja.apps.googleusercontent.com |
| **Project Number** | 334722600921 |
| **Brand ID** | 334722600921 |

### Authorized Redirect URIs

The OAuth client should include the following redirect URIs:

```
https://34.36.175.81.nip.io/_gcp_gatekeeper/authenticate
https://frontend-334722600921.us-east4.run.app/_gcp_gatekeeper/authenticate
https://frontend-z35gahfla-uk.a.run.app/_gcp_gatekeeper/authenticate
```

### Authorized JavaScript Origins

```
https://34.36.175.81.nip.io
https://frontend-334722600921.us-east4.run.app
https://frontend-z35gahfla-uk.a.run.app
```

---

## Publishing Status

### Testing Mode vs Production Mode

**Current Status**: Testing (Internal)

**Testing Mode:**
- Only test users can access the application
- OAuth consent screen shows "unverified app" warning
- Suitable for development and internal testing
- Limited to specified test users

**Production Mode:**
- Requires Google OAuth verification process
- Available to all users with @develom.com domain
- No "unverified app" warning
- Requires app verification submission

### Moving to Production

To publish the OAuth consent screen for production:

1. Complete all required branding information
2. Add all necessary scopes
3. Submit for Google verification (if needed)
4. Change publishing status from "Testing" to "Production"

---

## Domain Restrictions

### Organization Domain Access

The application is configured to restrict access to the organization domain:

- **Allowed Domain**: `develom.com`
- **IAP Access Control**: Domain-based restriction via Cloud IAP
- **Effect**: Only users with `@develom.com` email addresses can authenticate

### Implementation

Domain restriction is enforced at two levels:

1. **IAP Configuration**: Domain policy in Identity-Aware Proxy settings
2. **OAuth Consent Screen**: Authorized domains configuration

---

## Troubleshooting

### Common Issues

#### Error 52: OAuth Configuration Issue
- **Cause**: OAuth consent screen not configured or not published
- **Solution**: Verify all branding fields are completed and consent screen is configured

#### Unauthorized Domain Error
- **Cause**: Redirect URI domain not in authorized domains list
- **Solution**: Add the domain to the authorized domains list

#### Access Denied for User
- **Cause**: User not in test users list (if in Testing mode)
- **Solution**: Add user to test users or publish to production

#### Unverified App Warning
- **Cause**: OAuth consent screen in Testing mode
- **Solution**: This is expected for testing; publish to production to remove warning

---

## Security Considerations

### Best Practices

1. **Use Organization Domain Restriction**: Limit access to @develom.com users only
2. **Keep Test Users Updated**: Regularly review and update test user list
3. **Minimal Scopes**: Only request OAuth scopes that are absolutely necessary
4. **Regular Review**: Periodically review and update OAuth configuration
5. **Monitor Access Logs**: Check IAP access logs for unauthorized attempts

### Privacy & Compliance

- **Privacy Policy**: Ensure privacy policy link is accessible and up-to-date
- **User Support**: Provide valid support email for user inquiries
- **Data Handling**: Document what user data is collected and how it's used
- **Compliance**: Ensure OAuth configuration meets organizational compliance requirements

---

## Related Documentation

- [deploy-complete-oauth-v0.2.sh](./infrastructure/deploy-complete-oauth-v0.2.sh) - Complete OAuth deployment script
- [validate-security.sh](./infrastructure/validate-security.sh) - Security validation script
- [COMPLETE-OAUTH-SETUP.md](./COMPLETE-OAUTH-SETUP.md) - Complete OAuth setup guide

---

## Validation Commands

### Check OAuth Consent Screen

```bash
# List OAuth brands
gcloud iap oauth-brands list

# Describe specific brand
gcloud iap oauth-brands describe projects/334722600921/brands/334722600921
```

### Check OAuth Clients

```bash
# List OAuth clients for the brand
gcloud iap oauth-clients list projects/334722600921/brands/334722600921

# Describe specific OAuth client
gcloud iap oauth-clients describe 334722600921-3bb9hgjnjfd7dijokfugf4hogb7cl0ja.apps.googleusercontent.com \
    --brand=projects/334722600921/brands/334722600921
```

### Test OAuth Flow

1. Open incognito browser
2. Navigate to: `https://34.36.175.81.nip.io`
3. Verify OAuth consent screen appears with correct branding
4. Sign in with `@develom.com` account
5. Confirm successful authentication and app access

---

## Maintenance

### Regular Updates

- **Quarterly Review**: Review OAuth configuration every 3 months
- **Domain Updates**: Add new domains as deployment expands
- **User List**: Update test users as team changes
- **Branding**: Update app name, logo, or links as needed

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-10-07 | Initial OAuth consent screen configuration | Hector |

---

## Support

For issues or questions regarding OAuth consent screen configuration:

- **Email**: hector@develom.com
- **Project**: adk-rag-hdtest5
- **Region**: us-east4

---

**Document Version**: 1.0  
**Last Updated**: October 7, 2025
