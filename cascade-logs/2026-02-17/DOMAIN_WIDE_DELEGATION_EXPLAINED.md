# Why We Use Domain-Wide Delegation for Google Groups Integration

## The Problem We Were Trying to Solve

Imagine Google Workspace is like a **school building**. Inside the school, there are **clubs** (Google Groups) — like "Chess Club", "Art Club", "Science Club". Each student (user) belongs to different clubs.

Our app (running on Google Cloud Run) needs to **look up which clubs each student belongs to** when they log in. Based on their clubs, we give them access to different things in our app.

But here's the catch: **the list of who belongs to which club is private**. Only the **school principal** (the Google Workspace admin) can see the full club roster. Our app is not a person — it's a **robot** (a service account) that runs on Cloud Run.

---

## Why Can't the Robot Just Look It Up?

Google keeps club membership (Google Groups) information in a special system called the **Admin SDK Directory API**. This API has a strict rule:

> "Only **admin users** (real people with admin access to the Google Workspace domain) can query who belongs to which group."

Our robot (service account) is **not** an admin user. It's not even a real person. It's just a program running on a server. So Google says: **"Nope, you can't see the club list."**

This is where **Domain-Wide Delegation** comes in.

---

## What Is Domain-Wide Delegation?

Think of it like this:

> The **school principal** (admin) gives the **robot** a special **permission slip** that says: *"I authorize this robot to act on my behalf when looking up club memberships."*

In technical terms:
1. The **Google Workspace admin** goes to the **Google Admin Console**
2. They find the robot's **ID number** (Client ID)
3. They say: *"I trust this robot to use the scope `admin.directory.group.readonly` — which means it can **read** which groups a user belongs to"*
4. Now when the robot makes an API call, it **pretends to be the admin** (impersonates them) — but only for that one specific permission

It's like the principal giving the robot a **hall pass** that only works for checking the club roster board, nothing else.

---

## So Where Does the IAM Signer Come In?

This is a **separate but related problem** that happens on Cloud Run specifically.

To use that "permission slip" (domain-wide delegation), the robot needs to **sign a special document** (a JWT — like a digital signature) to prove it's really the authorized robot and not an imposter.

### How signing works locally vs. on Cloud Run:

| Environment | How the robot signs | Analogy |
|---|---|---|
| **Local development** | The robot has a **key file** (a JSON file with a private key) stored on disk. It uses this key to sign the document directly. | The robot carries its own **stamp** in its pocket |
| **Cloud Run** | There is **no key file**. Cloud Run gives the robot temporary credentials that **don't include a stamp**. | The robot's pocket is empty — no stamp! |

So on Cloud Run, the robot says: *"I need to sign this document, but I don't have my stamp!"*

### The Fix: IAM Signer

Google provides a service called **IAM signBlob** — think of it as a **notary office** in the cloud. Instead of carrying its own stamp, the robot:

1. Goes to the IAM notary office
2. Says: *"Please stamp this document for me"*
3. The notary checks: *"Are you authorized?"* → Yes (we granted the appropriate IAM role)
4. The notary stamps (signs) the document
5. The robot takes the stamped document to the Admin SDK and says: *"Here's my signed permission slip, let me see the club roster"*

---

## The Full Chain (Putting It All Together)

```
User logs in via IAP (Identity-Aware Proxy)
    ↓
Backend (Cloud Run) needs to check their Google Groups
    ↓
Robot needs to call Admin SDK (requires admin privileges)
    ↓
Robot uses Domain-Wide Delegation to impersonate the admin
    ↓
To prove identity, robot needs to sign a JWT
    ↓
No local key on Cloud Run → uses IAM Signer (remote notary)
    ↓
Signed JWT sent to Google → "OK, you're authorized"
    ↓
Admin SDK returns the user's group memberships
    ↓
Bridge maps groups → assigns app permissions and data access
```

---

## What the Google Workspace Admin Needs to Do

For this integration to work, the **Google Workspace admin** must complete one setup step in the **Google Admin Console**:

1. Go to **Admin Console** → **Security** → **API Controls** → **Domain-wide Delegation**
2. Click **Add new**
3. Enter the service account's **Client ID** (provided by the development team)
4. Enter the OAuth scope: `https://www.googleapis.com/auth/admin.directory.group.readonly`
5. Click **Authorize**

This grants the application permission to read group memberships — nothing more. The application cannot modify groups, read emails, or access any other Workspace data.

---

## Important Clarification: Delegation vs. IAM Signer

A common question is: *"Do we need Domain-Wide Delegation because of Cloud Run?"*

**No.** These are two separate requirements:

**Domain-Wide Delegation** is needed **regardless of where the app runs** — Cloud Run, a virtual machine, or even a developer's laptop. The reason is that Google's Admin SDK Directory API has a hard rule: only admin users can query group memberships. A service account is not an admin user, no matter how many IAM roles you give it. Delegation is the only way to bridge that gap.

**The IAM Signer** is needed **only on Cloud Run**. It solves a different problem: Cloud Run doesn't give the service account a local private key file to sign authentication tokens. If you ran the same app locally with a downloaded JSON key file, you wouldn't need the IAM Signer at all.

| Requirement | Why | Where it matters |
|---|---|---|
| **Domain-Wide Delegation** | Admin SDK only allows admin users; the service account must impersonate one | **Everywhere** — Cloud Run, VMs, local dev |
| **IAM Signer** | Cloud Run doesn't give the service account a local private key to sign JWTs | **Cloud Run only** — not needed locally with a key file |

Two separate problems, two separate solutions, both required for the integration to work on Cloud Run.

---

## Why We Built the Google Groups Bridge

### The Application's Access Model

The application has **two dimensions of access control** that determine what each user can do:

**1. Agent Access (Which AI agent do you talk to?)**

The app has multiple specialized AI agents, each configured differently:

| Agent Group | What it does |
|---|---|
| **admin-group** | Full access agent — can search all corpora, manage settings |
| **contributor-group** | Can search and upload documents to assigned corpora |
| **viewer-group** | Read-only — can search and ask questions, but can't upload |
| **content-manager-group** | Can manage document collections (corpora) |

When a user logs in, they're assigned to **one agent group** which determines their agent type and capabilities.

**2. Corpus Access (Which document collections can you search?)**

The app has multiple corpora (document collections) in Vertex AI RAG — for example:
- `ai-books` — AI and machine learning books
- `design` — Design documents
- `management` — Management resources
- `recipes` — Recipe collection

Each user can access **a different subset** of corpora.

### The Problem: How Do You Manage This at Scale?

**Without the bridge**, an admin would have to:
1. Log into the app's admin panel
2. Manually assign each user to an agent group
3. Manually grant each user access to specific corpora
4. Repeat for every new user
5. Update manually whenever someone's role changes

For 5 users, that's manageable. For **500 users across a large organization** — it's a nightmare. And it's **duplicating work** because the organization already manages who belongs to which team using **Google Groups** in Google Workspace.

### The Solution: Let Google Groups Drive Everything

The bridge maps **Google Groups → app permissions** automatically:

```
Google Groups (managed by org admins)     →     App Permissions (automatic)
─────────────────────────────────────           ─────────────────────────────
rag-admins@domain.com                     →     admin-group (full access agent)
rag-contributors@domain.com               →     contributor-group
rag-viewers@domain.com                    →     viewer-group
rag-content-managers@domain.com           →     content-manager-group

corpus-ai-books@domain.com               →     Access to ai-books corpus
corpus-design@domain.com                  →     Access to design corpus
corpus-management@domain.com              →     Access to management corpus
corpus-recipes@domain.com                 →     Access to recipes corpus
```

**What happens on login:**

1. User logs in via IAP (Google authenticates them)
2. Bridge queries Admin SDK: *"Which Google Groups does this user belong to?"*
3. Admin SDK returns the user's groups
4. Bridge maps agent groups → assigns the appropriate **AI agent**
5. Bridge maps corpus groups → grants access to the appropriate **document collections**
6. User sees the right agent and the right documents — **zero manual admin work**

**To change someone's access:**

- **Add them to a Google Group** → next login, they automatically get the new permissions
- **Remove them from a Google Group** → next login, access is revoked
- **No app admin panel needed** — the org's existing Google Workspace admin manages everything

### Why This Matters

| Without Bridge | With Bridge |
|---|---|
| Admin manually assigns each user's agent group | Automatic from Google Groups |
| Admin manually grants corpus access per user | Automatic from Google Groups |
| New employee = manual setup in app | New employee = add to Google Groups, done |
| Role change = manual update in app | Role change = update Google Groups, done |
| Scales poorly (100+ users = constant admin work) | Scales effortlessly (Google Groups is the single source of truth) |

The bridge exists so that organizations can manage app access using the tools they already use (Google Groups) instead of maintaining a separate, manual permission system inside the app. It turns Google Groups into the **single source of truth** for both agent assignment and corpus access.

---

## Summary of the Solution

| Problem | Solution |
|---|---|
| **Admin SDK requires admin privileges** | Domain-Wide Delegation — admin authorizes the service account to impersonate them for group lookups |
| **Cloud Run has no local key file to sign JWTs** | IAM Signer — signs JWTs remotely via Google's IAM signBlob API |
| **Scope must match between code and Admin Console** | Both configured to use `admin.directory.group.readonly` |

---

## Three-Sentence Summary

We use **Domain-Wide Delegation** because Google's Admin SDK — the only API that can look up which Google Groups a user belongs to — requires admin-level privileges, and our application's service account is not an admin user; delegation lets it temporarily impersonate an admin for that one specific read-only query. The **IAM Signer** is needed because Google Cloud Run does not provide a local private key file to the service account, so instead of signing the authentication token locally, the application uses Google's remote IAM signing service to prove its identity. Together, these two mechanisms allow the application running on Cloud Run to securely query Google Groups memberships on every user login, without storing any secret keys and with the minimum possible permissions.
