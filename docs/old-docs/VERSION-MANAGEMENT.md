# Version Management Guide

**Project:** ADK RAG Agent  
**Repository:** Single repository with branch-based versioning  
**Strategy:** Git tags + Branch workflow  
**Date:** October 14, 2025

---

## Table of Contents

- [Overview](#overview)
- [Branch Structure](#branch-structure)
- [Version Tagging Strategy](#version-tagging-strategy)
- [Daily Workflow](#daily-workflow)
- [Release Process](#release-process)
- [Rollback Procedures](#rollback-procedures)
- [Best Practices](#best-practices)

---

## Overview

This repository uses a **hybrid branching strategy** combining:
- **Git tags** for immutable version snapshots (v1.0.0, v1.1.0, etc.)
- **Branch workflow** for development and production separation
- **Semantic versioning** (SemVer) for clear version communication

### Why This Approach?

✅ **Immutable versions** - Tags provide exact snapshots for rollback  
✅ **Continuous development** - Develop branch for experimentation  
✅ **Production safety** - Main branch always deployable  
✅ **No repository duplication** - Everything in one repo  
✅ **CI/CD compatible** - GitHub Actions already configured

---

## Branch Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    BRANCH WORKFLOW                          │
└─────────────────────────────────────────────────────────────┘

main            Production-ready code (protected)
 │              Always deployable, tagged with versions
 │              Tags: v1.0.0, v1.1.0, v1.2.0, v2.0.0
 │
 ├─── develop   Active development (CI/CD improvements)
 │              All new features developed here
 │              Merge to main when stable
 │
 └─── feature/* Short-lived feature branches (optional)
                Create from develop, merge back to develop
```

### Branch Purposes

| Branch | Purpose | Protection | Deployment |
|--------|---------|------------|------------|
| **main** | Production-ready code | Should be protected | Deploy to production |
| **develop** | Active development | CI runs on push | Deploy to dev/staging |
| **feature/** | Isolated features | Optional | Local testing only |
| **hotfix/** | Emergency fixes | Merge to main + develop | Immediate deployment |

---

## Version Tagging Strategy

### Semantic Versioning (SemVer)

```
vMAJOR.MINOR.PATCH

Example: v1.2.3
         │ │ │
         │ │ └─── PATCH: Bug fixes (backward compatible)
         │ └───── MINOR: New features (backward compatible)
         └─────── MAJOR: Breaking changes
```

### Version History

| Version | Date | Description | Status |
|---------|------|-------------|--------|
| **v1.0.0** | 2025-10-14 | Production stable: OAuth, IAP, Cloud Armor | ✅ Current |
| **v1.1.0** | TBD | Planned: Automated testing suite | 📋 Planned |
| **v1.2.0** | TBD | Planned: Secret Manager integration | 📋 Planned |
| **v2.0.0** | TBD | Planned: Terraform migration (breaking) | 📋 Planned |

### Tagging Conventions

```bash
# Production releases (on main branch)
v1.0.0, v1.1.0, v1.2.0, v2.0.0

# Release candidates (testing)
v1.1.0-rc.1, v1.1.0-rc.2

# Beta releases
v1.1.0-beta.1

# Alpha releases (experimental)
v1.1.0-alpha.1

# Hotfixes
v1.0.1, v1.0.2
```

---

## Daily Workflow

### Starting New Development

```bash
# 1. Switch to develop branch
git checkout develop

# 2. Pull latest changes
git pull origin develop

# 3. Create feature branch (optional)
git checkout -b feature/add-monitoring

# 4. Make changes
# ... edit files ...

# 5. Commit changes
git add .
git commit -m "Add Cloud Monitoring dashboard"

# 6. Push to remote
git push origin feature/add-monitoring
# or
git push origin develop
```

### Creating a Feature Branch

```bash
# Create from develop
git checkout develop
git checkout -b feature/secret-manager

# Work on feature
git add .
git commit -m "Implement Secret Manager integration"

# Push feature branch
git push -u origin feature/secret-manager

# When complete, merge back to develop
git checkout develop
git merge feature/secret-manager --no-ff
git push origin develop

# Delete feature branch (optional)
git branch -d feature/secret-manager
git push origin --delete feature/secret-manager
```

---

## Release Process

### Standard Release (Minor/Major Version)

```bash
# 1. Ensure develop branch is stable
git checkout develop
# Run tests, validate everything works
./infrastructure/test-pipeline.sh

# 2. Merge develop to main
git checkout main
git pull origin main
git merge develop --no-ff -m "Merge develop: v1.1.0 release"

# 3. Create version tag
git tag -a v1.1.0 -m "v1.1.0: Added automated testing and monitoring

New Features:
- Automated unit and integration tests
- Cloud Monitoring dashboards
- Secret Manager integration

Improvements:
- Enhanced error handling
- Better logging

Bug Fixes:
- Fixed IAP error handling
- Resolved deployment script issues"

# 4. Push to remote
git push origin main
git push origin v1.1.0

# 5. Deploy to production
./infrastructure/deploy-all.sh

# 6. Create GitHub Release (optional)
# Go to GitHub → Releases → Draft new release
# Select tag: v1.1.0
# Add release notes
```

### Hotfix Release (Patch Version)

```bash
# 1. Create hotfix branch from main
git checkout main
git checkout -b hotfix/critical-bug

# 2. Fix the bug
# ... make changes ...
git add .
git commit -m "Fix critical IAP authentication bug"

# 3. Merge to main
git checkout main
git merge hotfix/critical-bug --no-ff

# 4. Tag the hotfix
git tag -a v1.0.1 -m "v1.0.1: Hotfix for IAP authentication"

# 5. Merge back to develop
git checkout develop
git merge hotfix/critical-bug --no-ff

# 6. Push everything
git push origin main
git push origin develop
git push origin v1.0.1

# 7. Deploy immediately
./infrastructure/deploy-all.sh

# 8. Delete hotfix branch
git branch -d hotfix/critical-bug
```

---

## Rollback Procedures

### Method 1: Deploy Previous Tag (Recommended)

```bash
# 1. Check available versions
git tag -l

# 2. Checkout specific version
git checkout v1.0.0

# 3. Deploy that version
./infrastructure/deploy-all.sh

# 4. Return to main when ready
git checkout main
```

**Pros:** 
- ✅ Quick and safe
- ✅ No changes to branches
- ✅ Can test before committing

**Cons:**
- ❌ Leaves repository in "detached HEAD" state temporarily

---

### Method 2: Create Rollback Branch

```bash
# 1. Create rollback branch from tag
git checkout -b rollback-to-v1.0.0 v1.0.0

# 2. Deploy
./infrastructure/deploy-all.sh

# 3. If rollback needs to be permanent:
git checkout main
git merge rollback-to-v1.0.0 -X theirs

# 4. Tag as new version
git tag -a v1.0.2 -m "v1.0.2: Rollback to v1.0.0 due to critical issue"

# 5. Push
git push origin main
git push origin v1.0.2

# 6. Clean up rollback branch
git branch -d rollback-to-v1.0.0
```

**Pros:**
- ✅ Clear audit trail
- ✅ Can make adjustments during rollback
- ✅ Normal branch workflow

**Cons:**
- ❌ More steps
- ❌ Creates temporary branches

---

### Method 3: Hard Reset (Nuclear Option)

```bash
# WARNING: This rewrites history! Use with caution.

# 1. Reset main to specific tag
git checkout main
git reset --hard v1.0.0

# 2. Force push (requires force-push permissions)
git push -f origin main

# 3. Deploy
./infrastructure/deploy-all.sh
```

**Pros:**
- ✅ Completely removes problematic commits
- ✅ Clean history

**Cons:**
- ❌ **DANGEROUS**: Rewrites history
- ❌ Breaks for other developers
- ❌ Only use in emergencies

---

## Best Practices

### Commit Messages

```bash
# Good commit messages
git commit -m "Add Secret Manager integration for JWT secrets"
git commit -m "Fix: IAP authentication timeout issue"
git commit -m "Docs: Update deployment guide with new scripts"

# Format:
[Type]: [Brief description]

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation changes
- refactor: Code restructuring
- test: Adding tests
- chore: Maintenance tasks
```

### Tag Annotations

```bash
# Always use annotated tags (not lightweight)
git tag -a v1.1.0 -m "Description"  # ✅ Good
git tag v1.1.0                       # ❌ Avoid

# Good tag message format:
git tag -a v1.1.0 -m "v1.1.0: Brief title

Detailed description of changes:
- Feature 1
- Feature 2
- Bug fix 3

Breaking changes: None
Migration required: No"
```

### Branch Naming

```bash
# Good branch names
feature/add-monitoring
feature/secret-manager-integration
hotfix/iap-authentication-bug
bugfix/deployment-script-error

# Avoid
my-branch
test
wip
```

### Before Merging to Main

- [ ] All tests pass in CI/CD
- [ ] Code reviewed (if team workflow)
- [ ] Documentation updated
- [ ] Deployment tested in staging
- [ ] Breaking changes documented
- [ ] CHANGELOG.md updated

---

## Viewing History

### List All Tags

```bash
# List tags
git tag -l

# List tags with messages
git tag -l -n1

# Show specific tag details
git show v1.0.0
```

### Compare Versions

```bash
# Compare two tags
git diff v1.0.0..v1.1.0

# Show commits between tags
git log v1.0.0..v1.1.0 --oneline

# Show files changed between versions
git diff --name-status v1.0.0..v1.1.0
```

### Find Which Version Contains a Commit

```bash
# Find tags containing specific commit
git tag --contains <commit-hash>

# Show all branches containing commit
git branch --contains <commit-hash>
```

---

## CI/CD Integration

Your GitHub Actions workflows are already configured for this branching strategy:

```yaml
# .github/workflows/ci.yml
on:
  push:
    branches: [ main, develop ]  # CI runs on both branches
  pull_request:
    branches: [ main ]            # PRs to main trigger CI
```

### Deployment Automation

```yaml
# Future enhancement: Add deployment on tag creation
on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        run: ./infrastructure/deploy-all.sh
```

---

## Emergency Procedures

### If Main Branch is Broken

```bash
# 1. Immediately rollback deployment
git checkout v1.0.0
./infrastructure/deploy-all.sh

# 2. Fix on develop branch
git checkout develop
# ... make fixes ...
git commit -m "Fix: Critical production bug"

# 3. Merge to main when ready
git checkout main
git merge develop
git tag -a v1.0.1 -m "v1.0.1: Emergency fix"
git push origin main v1.0.1

# 4. Deploy fixed version
./infrastructure/deploy-all.sh
```

### If Tag Was Created Incorrectly

```bash
# Delete local tag
git tag -d v1.1.0

# Delete remote tag
git push origin --delete v1.1.0

# Recreate correctly
git tag -a v1.1.0 -m "Correct message"
git push origin v1.1.0
```

---

## Additional Resources

- **CHANGELOG.md** - Detailed version history
- **README.md** - Project overview and setup
- **docs/DEPLOYMENT-CHECKLIST.md** - Pre-deployment checklist
- [Git Tagging Documentation](https://git-scm.com/book/en/v2/Git-Basics-Tagging)
- [Semantic Versioning Spec](https://semver.org/)

---

## Questions?

If you need to:
- Revert to a previous version → Use Method 1 (checkout tag)
- Create a new release → Follow Release Process
- Fix a critical bug → Use Hotfix workflow
- Understand version history → Use `git log` and `git diff`

**Remember:** Main branch should always be deployable, tagged, and production-ready!
