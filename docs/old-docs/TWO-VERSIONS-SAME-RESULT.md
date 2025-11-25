<!-- Document Header -->
- **Title**: Two Versions, Same Result
- **Purpose**: Compare two Cloud Run authentication postures behind an External HTTPS Load Balancer with IAP and explain why both work; outline security posture and organization policy differences.
- **Date**: 2025-10-31
- **Author**: Hector De Jesus
- **Topics**: External HTTPS Load Balancer, Identity-Aware Proxy (IAP), Cloud Run Authentication, Ingress Restriction, Organization Policy (iam.allowedPolicyMemberDomains)

# TWO-VERSIONS-SAME-RESULT.md

This document explains why two Google Cloud projects with different Cloud Run authentication postures both work behind the same External HTTPS Load Balancer (LB) with Identity-Aware Proxy (IAP).

- **Project A**: `adk-rag-hdtest6`
  - Cloud Run: Public access (`allUsers` invoker present)
  - Ingress: `internal-and-cloud-load-balancing`
  - Org Policy: `iam.allowedPolicyMemberDomains: allowAll: true`
- **Project B**: `adk-rag-tt`
  - Cloud Run: Require authentication (no `allUsers`; only IAP service agent)
  - Ingress: `internal-and-cloud-load-balancing`
  - Org Policy: `iam.allowedPolicyMemberDomains: allowedValues: [C02qxenb7]` (blocks public principals)

Both work because the LB with IAP invokes Cloud Run using the IAP service agent identity, which has `roles/run.invoker` in both projects.

## Side-by-side Architecture Diagram

```mermaid
flowchart LR
  %% Left side: adk-rag-hdtest6
  subgraph L[Project: adk-rag-hdtest6]
    direction TB
    U1[End User (Browser)]
    LB1[External HTTPS LB\n+ IAP Enabled]
    IAP1[IAP AuthN/AuthZ\n(Users, Groups, Domain)]
    SA1[LB invokes as\nIAP Service Agent\nservice-<project#>@gcp-sa-iap.iam.gserviceaccount.com]
    CR1[Cloud Run Service\nAuth: Public access\nIngress: internal-and-cloud-load-balancing]
    IAM1[IAM on Cloud Run:\n- allUsers: roles/run.invoker\n- IAP SA: roles/run.invoker]
    OP1[Effective Org Policy:\niam.allowedPolicyMemberDomains:\nallowAll: true]

    U1 -->|HTTPS| LB1 --> IAP1 --> SA1 -->|HTTP on Google network| CR1
    CR1 --- IAM1
    L -. posture .-> OP1
  end

  %% Right side: adk-rag-tt
  subgraph R[Project: adk-rag-tt]
    direction TB
    U2[End User (Browser)]
    LB2[External HTTPS LB\n+ IAP Enabled]
    IAP2[IAP AuthN/AuthZ\n(Users, Groups, Domain)]
    SA2[LB invokes as\nIAP Service Agent\nservice-<project#>@gcp-sa-iap.iam.gserviceaccount.com]
    CR2[Cloud Run Service\nAuth: Require authentication\nIngress: internal-and-cloud-load-balancing]
    IAM2[IAM on Cloud Run:\n- IAP SA: roles/run.invoker\n- NO allUsers (blocked)]
    OP2[Effective Org Policy:\niam.allowedPolicyMemberDomains:\nallowedValues: [C02qxenb7]]

    U2 -->|HTTPS| LB2 --> IAP2 --> SA2 -->|HTTP on Google network| CR2
    CR2 --- IAM2
    R -. posture .-> OP2
  end

  %% Styling
  classDef green fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20;
  classDef yellow fill:#fffde7,stroke:#f9a825,color:#5f370e;
  classDef blue fill:#e3f2fd,stroke:#1565c0,color:#0d47a1;

  class LB1,LB2,IAP1,IAP2,SA1,SA2 blue
  class CR1,CR2 green
  class OP1,OP2 yellow
```

## Legend and Flow

- **External HTTPS LB + IAP**: Terminates TLS, authenticates users with Google, and authorizes via IAP IAM (users/groups/domain).
- **IAP Service Agent**: After IAP, the LB calls Cloud Run using the IAP service agent identity.
- **Cloud Run IAM**:
  - Must allow the IAP service agent (`roles/run.invoker`) in both projects.
  - `adk-rag-hdtest6` also has `allUsers` invoker; `adk-rag-tt` does not.
- **Ingress restriction**: Both Cloud Run services use `internal-and-cloud-load-balancing`, so only the LB can reach them (not the public internet).

## Why Both Work

- **Core reason**: In both projects, the IAP service agent has `roles/run.invoker` on Cloud Run. Cloud Run sees the LB’s call as coming from that service account and allows it.
- **adk-rag-hdtest6**: “Public access” exists (via `allUsers`), but ingress blocks direct public traffic; only the LB reaches Cloud Run.
- **adk-rag-tt**: “Require authentication” allows only identities with invoker (the IAP service agent), which the LB presents.

## Key Differences

- **Org Policy**:
  - `adk-rag-hdtest6`: `allowAll: true` → permits public principals like `allUsers`.
  - `adk-rag-tt`: restricted to Customer ID (`C02qxenb7`) → blocks public principals.
- **IAM Surface**:
  - `adk-rag-hdtest6`: Slightly broader (includes `allUsers`), but safe with ingress restriction.
  - `adk-rag-tt`: Tighter (IAP SA only), aligned with stricter policy.

## Recommended Actions (Optional)

- **Normalize posture** in `adk-rag-hdtest6`: Remove `allUsers` if the IAP service agent already has invoker, to match `adk-rag-tt`.
  - `gcloud run services remove-iam-policy-binding backend  --region=us-east4 --member="allUsers" --role="roles/run.invoker"`
  - `gcloud run services remove-iam-policy-binding frontend --region=us-east4 --member="allUsers" --role="roles/run.invoker"`
- **Keep essentials**:
  - Ensure IAP service agent remains bound with `roles/run.invoker`.
  - Keep Cloud Run ingress = `internal-and-cloud-load-balancing`.
  - Manage who can log in via IAP IAM (users/groups/domain) at the LB layer.

# Status

- Provided a complete Markdown document with a Mermaid diagram you can save as `TWO-VERSIONS-SAME-RESULT.md`.


## Organization Policy Differences Observed (from screenshots)

Image 1 appears more restrictive (likely `adk-rag-tt`). Image 2 appears less restrictive (likely `adk-rag-hdtest6`). Differences visible in the screenshot lists:

- **Present only in Image 1 (more restrictive):**
  - Disable Automatic IAM Grants for Default Service Accounts (`iam.automaticIamGrantsForDefaultServiceAccounts`)
  - Domain restricted sharing (`iam.allowedPolicyMemberDomains`)
  - Domain restricted contacts (`essentialcontacts.allowedContactDomains`)
  - Enforce uniform bucket-level access (`storage.uniformBucketLevelAccess`)
  - Disable Service Account Key Upload (`iam.disableServiceAccountKeyUpload`)
  - Sets the internal DNS setting for new projects to Zonal DNS Only (`compute.setNewProjectDefaultToZonalDNSOnly`)

- **Common in both images:**
  - Block Compute Engine Preview Features (`compute.managed.blockPreviewFeatures`)
  - Block service account API key bindings (`iam.managed.disableServiceAccountApiKeyCreation`)
  - Restrict enablement of service mesh endpoints (`gcp.managed.mcpAllowedServices`)
  - Allow extending lifetime of OAuth 2.0 access tokens up to 12 hours (`iam.allowServiceAccountCredentialLifetimeExtension`)
  - Allowed Destinations for Exporting Resources (`resourcemanager.allowedExportDestinations`)
  - Allowed Sources for Importing Resources (`resourcemanager.allowedImportSources`)
  - Disable Create Default Service Account (Cloud Build) (`cloudbuild.disableCreateDefaultServiceAccount`)
  - Disable Cross-Project Service Account Usage (`iam.disableCrossProjectServiceAccountUsage`)
  - Require Enabled Services Allow List for Cross-Organization Move (`resourcemanager.allowedServicesForExport`)
  - Restrict access on marketplace services (`commerceorgagency.restrictMarketplaceServices`)
  - Runtime Deployment Exemption (App Engine) (`appengine.runtimeDeploymentExemption`)
  - Service account key exposure response (`iam.serviceAccountKeyExposureResponse`)
  - Shared Reservations Owner Projects (`compute.sharedReservationsOwnerProjects`)
  - Use Compute Engine Service Account by Default (Cloud Build) (`cloudbuild.useBuildServiceAccount`)
  - Use default service account (Cloud Build) (`cloudbuild.useBuildServiceAccount`)

- **Present only in Image 2 (less restrictive):**
  - None clearly visible; Image 2 appears to be a subset of Image 1’s enforced constraints.

These visual differences align with the earlier finding that `adk-rag-tt` enforces domain/member restrictions (e.g., `iam.allowedPolicyMemberDomains` tied to your customer), while `adk-rag-hdtest6` allows broader membership (`allowAll: true`).


Project: adk-rag-hdtest6                              Project: adk-rag-tt
───────────────────────────────────                   ───────────────────────────────────
End User (Browser)                                    End User (Browser)
        │ HTTPS                                               │ HTTPS
        ▼                                                     ▼
External HTTPS LB + IAP                               External HTTPS LB + IAP
        │ (IAP authenticates user)                           │ (IAP authenticates user)
        ▼                                                     ▼
LB invokes Cloud Run as                                    LB invokes Cloud Run as
IAP Service Agent                                           IAP Service Agent
service-<proj#>@gcp-sa-iap.iam.gserviceaccount.com          service-<proj#>@gcp-sa-iap.iam.gserviceaccount.com
        │ (Google internal HTTP)                             │ (Google internal HTTP)
        ▼                                                     ▼
Cloud Run Service                                           Cloud Run Service
Auth: Public access                                         Auth: Require authentication
Ingress: internal-and-cloud-load-balancing                  Ingress: internal-and-cloud-load-balancing

Cloud Run IAM:                                              Cloud Run IAM:
- allUsers: roles/run.invoker  [present]                    - allUsers: roles/run.invoker  [absent]
- IAP SA: roles/run.invoker    [present]                    - IAP SA: roles/run.invoker    [present]

Effective Org Policy:                                       Effective Org Policy:
iam.allowedPolicyMemberDomains:                             iam.allowedPolicyMemberDomains:
- allowAll: true                                            - allowedValues: [C02qxenb7]
(permits public principals)                                 (blocks public principals)

Why it works:                                               Why it works:
- LB calls as IAP Service Agent                             - LB calls as IAP Service Agent
- IAP SA has invoker → allowed                              - IAP SA has invoker → allowed
- Ingress restricts to LB only                              - Ingress restricts to LB only



More details:
# Findings

You have the same External HTTPS Load Balancer + IAP in front of Cloud Run for both projects, but each Cloud Run service has a different “Authentication” posture:

- adk-rag-hdtest6: Cloud Run shows “Public access” and has `allUsers: roles/run.invoker` plus the IAP service agent.
- adk-rag-tt: Cloud Run shows “Require authentication” and has only the IAP service agent (no `allUsers`, due to org policy).

Both still work because the LB with IAP calls Cloud Run using a Google-managed identity (the IAP service agent), which has `roles/run.invoker` on your Cloud Run service in both projects.

## How requests flow

1. User hits the External HTTPS LB.
2. IAP on the LB authenticates the user.
3. The LB invokes Cloud Run using the IAP service agent identity.
4. Cloud Run checks IAM:
   - If “Require authentication”: it allows the IAP service agent (because it has `roles/run.invoker`).
   - If “Public access”: it would also allow `allUsers`; however, ingress is restricted to `internal-and-cloud-load-balancing`, so only the LB can actually reach Cloud Run.

This is why:
- adk-rag-tt works with “Require authentication” (IAP SA satisfies the auth requirement).
- adk-rag-hdtest6 works with “Public access” (but practically still only LB can reach it due to ingress restriction).

## Why your two environments differ and still work

- adk-rag-hdtest6 effective org policy allows public members, so `allUsers` was added. It also has the IAP service agent.
- adk-rag-tt effective org policy restricts to your customer ID, blocking `allUsers`, but the IAP service agent is present and sufficient.

In both, ingress is `internal-and-cloud-load-balancing`, so direct internet access to Cloud Run URLs is blocked. Only the LB can invoke, and it does so as the IAP service agent.

# Security posture comparison

- adk-rag-tt (Require auth, IAP SA only)
  - Tighter Cloud Run IAM surface (no `allUsers`).
  - Works because IAP SA has invoker.

- adk-rag-hdtest6 (Public, IAP SA + allUsers)
  - Functionally safe because ingress restricts to LB.
  - Slightly broader IAM (includes `allUsers`), but not internet-exposed due to ingress restriction.

# Recommended Actions

- **Normalize posture**: You can safely remove `allUsers` in `adk-rag-hdtest6` if the IAP service agent already has `roles/run.invoker`, to match `adk-rag-tt`:
  - `gcloud run services remove-iam-policy-binding backend  --region=us-east4 --member="allUsers" --role="roles/run.invoker"`
  - `gcloud run services remove-iam-policy-binding frontend --region=us-east4 --member="allUsers" --role="roles/run.invoker"`
- **Keep IAP SA binding** on both services and keep ingress as `internal-and-cloud-load-balancing`. That preserves the secure LB + IAP pattern without needing `allUsers`.

# Status

- Both projects work because the LB with IAP invokes Cloud Run as the IAP service agent, which has `roles/run.invoker`. The difference in Cloud Run “Authentication” setting doesn’t break the flow, provided the IAP service agent is bound and ingress is restricted.


# Additional notes:

After looking at the difference list I see that the domain restricted shareing  may be the policy that blocks the userAll in the tt project. Is that correct?

Findings
Yes. The “Domain restricted sharing” org policy is the constraints/iam.allowedPolicyMemberDomains constraint.
In adk-rag-tt, the effective policy shows allowedValues: [C02qxenb7] (your Customer ID). This restricts IAM principals to your organization’s identities and blocks public principals like allUsers and allAuthenticatedUsers.
That’s why gcloud run services add-iam-policy-binding ... --member="allUsers" fails in adk-rag-tt.
Why this blocks allUsers
allUsers/allAuthenticatedUsers are not tied to any specific customer domain.
When allowedPolicyMemberDomains is enforced with a specific customer ID, attempting to add those public principals returns the FAILED_PRECONDITION error you saw.
Recommended Actions
If keeping External LB + IAP + serverless NEG:
Ask org admins for an exception at the project/folder level to relax iam.allowedPolicyMemberDomains so Cloud Run can have allUsers: roles/run.invoker.
Keep Cloud Run ingress = internal-and-cloud-load-balancing and ensure IAP SA has roles/run.invoker.
If changing architecture:
Use IAP directly on Cloud Run (no External LB). No allUsers binding needed.
Where to see/change it
Console: IAM & Admin → Organization Policies → search “Allowed policy member domains”.
Check at the project; if inherited, switch to the folder/org scope shown under “Inherited from”.
Status
Correct: “Domain restricted sharing” is the policy preventing allUsers in adk-rag-t