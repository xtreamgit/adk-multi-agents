# Git Version Control Strategy - Clarified

## ✅ Recommended Approach for Your Requirements

### **Branch Strategy (Environments)**
```
main        → Production environment (always deployable)
staging     → Staging environment (pre-production testing)
develop     → Development environment (active development)
feature/*   → Short-lived feature branches
hotfix/*    → Emergency production fixes
```

### **Version Strategy (Git Tags on main)**
```
main branch commits:
├── v1.0.0  ← Tag (not branch)
├── v1.1.0  ← Tag (not branch)
├── v1.2.0  ← Tag (not branch)
└── v2.0.0  ← Tag (not branch)
```

---

## 🎯 Why Tags vs Branches for Versions?

| Aspect | Branches (❌ Wrong) | Tags (✅ Correct) |
|--------|---------------------|-------------------|
| **Purpose** | Active development streams | Immutable version snapshots |
| **Changes** | Continues to evolve | Never changes |
| **Proliferation** | Creates branch clutter | Clean version history |
| **Rollback** | Confusing (which branch?) | Clear (checkout tag) |
| **CI/CD** | Hard to automate | Easy to automate |
| **Industry Standard** | Not used for versions | Standard practice |

**Example of what NOT to do:**
```bash
❌ git checkout -b prod-v1.0.0  # Wrong - creates unmaintainable branch clutter
❌ git checkout -b prod-v1.1.0  # Wrong - now you have dozens of branches
```

**Example of what TO do:**
```bash
✅ git tag -a v1.0.0 -m "Version 1.0.0"  # Right - clean, immutable snapshot
✅ git tag -a v1.1.0 -m "Version 1.1.0"  # Right - standard practice
```

---

## 📋 Your Specific Workflow

### **Current State → Recommended Migration**

```
CURRENT:                      RECOMMENDED:
────────                      ────────────
network (feature) ──┐         develop ──────────┐
cicd (feature) ─────┤         feature/network ──┤
deploy (feature) ───┤         feature/cicd ─────┤
                    ▼         feature/deploy ───┤
main ───────────────          staging ──────────┤
                                                 ▼
                              main (prod) ──────
                              ├── v1.0.0 (tag)
                              ├── v1.1.0 (tag)
                              └── v1.2.0 (tag)
```

---

## 🚀 Complete Workflow for Dev/Stage/Prod

### **1. Development (Day-to-Day)**

```bash
# Create feature branch from develop
git checkout develop
git checkout -b feature/add-monitoring

# Work on feature
git add .
git commit -m "Add monitoring dashboard"
git push origin feature/add-monitoring

# Merge to develop when ready
git checkout develop
git merge feature/add-monitoring --no-ff
git push origin develop

# Deploy to DEV environment
# Trigger: automatic on push to develop
# or manual: ./infrastructure/deploy.sh --env=dev
```

### **2. Staging (Pre-Production Testing)**

```bash
# Promote develop to staging
git checkout staging
git merge develop --no-ff -m "Release candidate for v1.1.0"
git push origin staging

# Deploy to STAGING environment
# Trigger: automatic on push to staging
# or manual: ./infrastructure/deploy.sh --env=staging

# Run full test suite on staging
./infrastructure/test-pipeline.sh --env=staging
```

### **3. Production (Release)**

```bash
# Promote staging to main (production)
git checkout main
git merge staging --no-ff -m "Release v1.1.0"

# Tag the release
git tag -a v1.1.0 -m "v1.1.0: Added monitoring and alerts"

# Push main and tag
git push origin main
git push origin v1.1.0

# Deploy to PRODUCTION
# Trigger: automatic on tag push
# or manual: ./infrastructure/deploy.sh --env=prod
```

### **4. Emergency Hotfix**

```bash
# Create hotfix from main (production)
git checkout main
git checkout -b hotfix/critical-security-fix

# Fix the issue
git commit -m "Fix security vulnerability"

# Merge to main and tag
git checkout main
git merge hotfix/critical-security-fix --no-ff
git tag -a v1.0.1 -m "v1.0.1: Security hotfix"
git push origin main v1.0.1

# Backport to staging and develop
git checkout staging
git merge hotfix/critical-security-fix --no-ff
git checkout develop
git merge hotfix/critical-security-fix --no-ff
git push origin staging develop

# Delete hotfix branch
git branch -d hotfix/critical-security-fix
```

---

## 🔄 Environment → Branch → Deployment Mapping

```
┌─────────────┬──────────────┬─────────────────┬─────────────────┐
│ Environment │ Git Branch   │ Deploy Trigger  │ GCP Project     │
├─────────────┼──────────────┼─────────────────┼─────────────────┤
│ Development │ develop      │ Push to develop │ adk-rag-dev     │
│ Staging     │ staging      │ Push to staging │ adk-rag-staging │
│ Production  │ main         │ Push tag v*.*   │ adk-rag-prod    │
└─────────────┴──────────────┴─────────────────┴─────────────────┘
```

---

## 📦 Version Rollback Examples

### **Rollback to Previous Version**

```bash
# List available versions
git tag -l
# Output: v1.0.0, v1.1.0, v1.2.0

# Rollback production to v1.1.0
git checkout v1.1.0

# Deploy that specific version
./infrastructure/deploy.sh --env=prod

# Or create emergency rollback branch
git checkout -b rollback-to-v1.1.0 v1.1.0
git push origin rollback-to-v1.1.0
# Then merge to main if needed
```

### **Deploy Specific Version to Staging**

```bash
# Test old version in staging
git checkout staging
git reset --hard v1.0.0
git push -f origin staging
./infrastructure/deploy.sh --env=staging
```

---

## 🛠️ Migration Steps for Your Repository

### **Step 1: Clean Up Current Branches**

```bash
# Ensure feature branches are merged to main
git checkout main
git merge cicd --no-ff -m "Merge cicd features"
git merge network --no-ff -m "Merge network features"  
git merge deploy --no-ff -m "Merge deploy features"

# Tag current main as v1.0.0
git tag -a v1.0.0 -m "v1.0.0: Production stable baseline"

# Push
git push origin main v1.0.0
```

### **Step 2: Create Environment Branches**

```bash
# Create staging from main
git checkout main
git checkout -b staging
git push -u origin staging

# Create develop from main
git checkout main
git checkout -b develop
git push -u origin develop
```

### **Step 3: Delete Old Feature Branches (Optional)**

```bash
# Delete locally
git branch -d cicd network deploy

# Delete remotely
git push origin --delete cicd network deploy
```

### **Step 4: Update GitHub Actions**

```yaml
# .github/workflows/deploy.yml
on:
  push:
    branches:
      - develop   # Deploy to dev
      - staging   # Deploy to staging
    tags:
      - 'v*.*.*'  # Deploy to prod on version tags
  
  pull_request:
    branches:
      - main      # Run tests on PRs to prod
      - staging   # Run tests on PRs to staging

jobs:
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Development
        run: ./infrastructure/deploy.sh --env=dev

  deploy-staging:
    if: github.ref == 'refs/heads/staging'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Staging
        run: ./infrastructure/deploy.sh --env=staging

  deploy-production:
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Production
        run: ./infrastructure/deploy.sh --env=prod
```

---

## 📊 Final Branch Structure

```
Repository: adk-rag-agent
│
├── main (protected)           → Production environment
│   ├── v1.0.0 ← tag
│   ├── v1.1.0 ← tag
│   └── v1.2.0 ← tag
│
├── staging (protected)        → Staging environment
│   └── (release candidates)
│
├── develop                    → Development environment
│   └── (active development)
│
└── feature/* (temporary)      → Feature branches
    ├── feature/monitoring
    ├── feature/secret-manager
    └── hotfix/security-patch
```

---

## ✅ Best Practices Summary

### **DO:**
- ✅ Use `main` for production
- ✅ Use tags (`v1.0.0`) for version snapshots
- ✅ Use `staging` and `develop` branches for environments
- ✅ Delete feature branches after merge
- ✅ Protect `main` and `staging` branches
- ✅ Deploy from branches (main→prod, staging→staging)
- ✅ Tag every production release

### **DON'T:**
- ❌ Don't create version branches (`prod-v1.0.0`)
- ❌ Don't keep old feature branches forever
- ❌ Don't commit directly to `main`
- ❌ Don't rewrite history on `main` or `staging`
- ❌ Don't mix version branches with environment branches

---

## 🎯 Answer to Your Specific Question

> "Should I create a new branch from main and call it prod-v1.0.0 and v1.1.0 and so on?"

**Answer:** ❌ **No, absolutely not.** This is a common anti-pattern that leads to:
- Dozens of unmaintainable branches
- Confusion about which branch to deploy
- Difficulty comparing versions
- Branch clutter

**Instead:** ✅ Use Git tags on the `main` branch:

```bash
# Right approach
git checkout main
git tag -a v1.0.0 -m "Version 1.0.0"
git push origin v1.0.0

# View all versions
git tag -l

# Deploy specific version
git checkout v1.0.0
./infrastructure/deploy.sh --env=prod

# Return to latest
git checkout main
```

---

**Summary:** Use **branches for environments** (main, staging, develop) and **tags for versions** (v1.0.0, v1.1.0). Never create version branches.
