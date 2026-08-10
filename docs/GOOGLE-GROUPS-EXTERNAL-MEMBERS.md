# Google Groups — External Member Restriction

## The Error

```
An error occurred
1 user is outside of your organization. Based on your group or organization settings,
you can only add organization users to this group. Contact your group owner or domain
administrator for help.
```

This error occurs when attempting to add a GCP service account (e.g.
`backend-sa@usfs-gcp-arch-testing.iam.gserviceaccount.com`) to a Google Group
that belongs to an organization domain (e.g. `usda.gov`).

## Why It Happens

Google Workspace enforces domain-based membership policies on Google Groups.
By default, groups created under an organization domain (such as `usda.gov`)
only accept members whose email addresses belong to that same domain.

A GCP service account email has the format:

```
<name>@<project-id>.iam.gserviceaccount.com
```

The domain `<project-id>.iam.gserviceaccount.com` does not match the
organization domain `usda.gov`, so Google treats the service account as an
**external member** and rejects the request.

## Solution

A **Google Workspace Super Admin** must change the group or organization
settings to allow external members.

### Option A — Change the Setting for a Single Group

1. Go to [groups.google.com](https://groups.google.com)
2. Open the target group and navigate to **Group settings**
3. Under **Who can join the group**, enable **"Allow members outside your organization"**
4. Save the change
5. Retry adding the service account

### Option B — Change the Organization-Wide Policy

1. Go to [Google Admin Console](https://admin.google.com)
2. Navigate to **Apps > Google Workspace > Groups for Business**
3. Under **Sharing settings**, set **"Who can be a member"** to
   **"Anyone with a Google Account"**
4. Save — this applies to all groups in the domain

### ~~Option C — Avoid Adding Service Accounts to Groups Entirely~~

**NOT VIABLE for this application.** A common workaround for the external
member restriction is to grant IAM roles directly to the service account
instead of adding it to a group:

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:backend-sa@PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/DESIRED_ROLE"
```

However, this does **not** work for the Google Groups Bridge. The bridge
uses the Cloud Identity `groups:search` API, which only returns groups that
are **visible to the calling identity**. A service account has no presence
in the Google Workspace directory by default — even with IAM roles like
`roles/cloudidentity.groupsViewer`, the API returns **zero groups** unless
the service account is an actual **member** of those groups.

| Caller | `groups:search` Result |
|---|---|
| Workspace user (e.g. `user@usda.gov`) | All org groups |
| Service account with IAM roles only | **0 groups** |
| Service account added as group member | **All org groups** |

The service account **must** be a member of each application-related Google
Group. Use Option A or Option B to allow the external member, then add the
service account with the **MEMBER** role (not OWNER or MANAGER).

See: [SA-in-Groups Implementation Guide](../cascade-logs/2026-02-18/SA-IN-GROUPS-IMPLEMENTATION-GUIDE-02-18-26.md)

## Security Risks of Allowing External Members

Enabling external members on an organization's Google Groups introduces
several risks that must be carefully evaluated.

### 1. Data Exposure

Google Groups are often used to distribute emails, share Drive folders, and
control access to internal resources. Adding external members grants them
visibility into all content shared through the group, including emails,
documents, and calendar events that may contain sensitive or controlled
information.

### 2. Privilege Escalation via IAM

In GCP, Google Groups can be bound to IAM roles. Any member of the group
inherits those roles. If external accounts are permitted, an attacker who
compromises an external member account (such as a service account key)
gains all IAM permissions associated with the group — potentially including
access to production resources, databases, or secrets.

### 3. Reduced Audit Visibility

External accounts are not managed by the organization's identity provider.
They fall outside centralized logging, credential rotation, and offboarding
workflows. If an external member's credentials are compromised, the
organization may not detect or revoke access promptly.

### 4. Compliance Implications

Federal and regulated environments (FedRAMP, FISMA, NIST 800-53) require
strict access control boundaries. Allowing external identities into
organization groups may violate the principle of least privilege and boundary
protections required by these frameworks. Auditors may flag externally
accessible groups as a control deficiency.

### 5. Shadow Access

Once external membership is enabled, any group owner — not just domain
admins — can add outside accounts. This creates a risk of unreviewed access
grants that bypass the organization's normal approval process.

## Recommendation

For this application, the service account **must** be added as a member of
each Google Group used by the bridge. Direct IAM bindings (Option C) do not
provide the Cloud Identity API visibility required for the bridge to
function.

The recommended approach:

1. Use **Option A** (per-group setting) to allow external members on each
   application-related group. This is safer than Option B because it limits
   the change to specific groups rather than the entire organization.
2. Add the service account as a **MEMBER** (not OWNER or MANAGER).
3. Set the service account's delivery preference to **"No email"** in each
   group to prevent unnecessary email delivery.
4. Periodically audit each group's member list to ensure only authorized
   external accounts are present.
5. When new application-related groups are created, repeat the process —
   add the service account to the new group immediately.
