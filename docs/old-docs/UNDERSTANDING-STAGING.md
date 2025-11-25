# Understanding the Staging Branch & Environment

Great question! Let me clarify what staging is and why you'd deploy specific versions there.

---

## 🎯 What is the Staging Branch/Environment?

**Staging** is a **testing environment** that mirrors your production setup but isn't exposed to real users.

### **The Three Environments Explained:**

```
┌──────────────┬─────────────────────────────────────────────────┐
│ Environment  │ Purpose                                         │
├──────────────┼─────────────────────────────────────────────────┤
│ Development  │ Experimental, rapid changes, break things      │
│ (develop)    │ "Does it work at all?"                         │
│              │                                                 │
│ Staging      │ Pre-production testing, final validation       │
│ (staging)    │ "Will it work in production?"                  │
│              │                                                 │
│ Production   │ Live users, stable, always working             │
│ (main)       │ "It's working in production"                   │
└──────────────┴─────────────────────────────────────────────────┘
```

---

## 📊 Normal Workflow: Development → Staging → Production

### **The Standard Path (Most Common)**

```bash
# Step 1: Develop new feature
git checkout develop
git checkout -b feature/add-monitoring

# Work on feature
git add .
git commit -m "Add monitoring dashboard"
git checkout develop
git merge feature/add-monitoring
git push origin develop

# ✅ Deploy to DEV environment (automatic)
# Test: Does the feature work?

# Step 2: Promote to staging
git checkout staging
git merge develop --no-ff -m "RC for v1.1.0"
git push origin staging

# ✅ Deploy to STAGING environment (automatic)
# Test: Does it work in production-like environment?
# Test: Performance, security, integration tests
# Test: User acceptance testing (UAT)

# Step 3: If staging tests pass → Deploy to production
git checkout main
git merge staging --no-ff -m "Release v1.1.0"
git tag -a v1.1.0 -m "v1.1.0: Monitoring added"
git push origin main v1.1.0

# ✅ Deploy to PRODUCTION (automatic on tag)
```

**This is the normal flow 90% of the time.**

---

## 🔍 Special Case: Testing Specific Versions in Staging

### **When Would You Do This?**

Sometimes you need to test an **old version** or **specific version** in staging:

1. **Testing a rollback plan** before doing it in production
2. **Comparing versions** side-by-side
3. **Reproducing a production bug** from an older version
4. **Customer wants to test a specific version** before upgrading

### **Example Scenario:**

```
Current State:
- Production (main): v1.2.0 ← Users are here
- Staging: v1.3.0 (release candidate)
- Problem: v1.2.0 has a bug in production

You want to:
1. Deploy v1.2.0 to staging to reproduce the bug
2. Test the fix in staging
3. Then deploy the fix to production
```

### **How to Deploy v1.2.0 to Staging:**

```bash
# Option 1: Reset staging to specific tag (what I showed)
git checkout staging
git reset --hard v1.2.0      # Move staging to v1.2.0
git push -f origin staging    # Force push (overwrites staging)
./infrastructure/deploy.sh --env=staging

# Now staging is running v1.2.0 (same as production)
# You can reproduce the bug and test fixes

# Option 2: Deploy tag directly without changing branch
git checkout v1.2.0
./infrastructure/deploy.sh --env=staging

# Staging runs v1.2.0, but the branch hasn't changed
```

---

## ⚠️ Important: When NOT to Use This

```bash
# ❌ DON'T do this in normal workflow
# This is ONLY for special testing scenarios

# Normal workflow is:
develop → staging → main
   ↓         ↓        ↓
  dev     staging   prod
```

The `git reset --hard v1.0.0` example was for **special cases only**, not your regular workflow.

---

## 🎯 Staging Branch: Key Concepts

### **What Staging Branch Contains:**

```
staging branch = "Release candidates waiting for production"

Example timeline:
- Monday: merge develop → staging (v1.1.0-rc)
- Tuesday-Thursday: Test in staging environment
- Friday: If tests pass, merge staging → main (v1.1.0)
```

### **Why Have a Staging Branch?**

✅ **Isolates production from active development**
- Developers keep working on `develop` (v1.2.0 features)
- QA tests `staging` (v1.1.0 release candidate)
- Production runs `main` (v1.0.0 stable)

✅ **Production-like testing**
- Same database structure as production
- Same infrastructure setup
- Same security configuration
- But with test data, not real users

✅ **Safety gate**
- Last chance to catch bugs before users see them
- Run full test suites
- Performance testing
- Security scans

---

## 📋 Complete Example: Real-World Scenario

### **Week 1: Normal Development**

```bash
# Day 1-3: Development
git checkout develop
# Work on new features
git push origin develop
# → Auto-deploys to DEV environment (adk-rag-dev)

# Day 4: Ready for staging
git checkout staging
git merge develop --no-ff -m "Release candidate v1.1.0"
git push origin staging
# → Auto-deploys to STAGING environment (adk-rag-staging)

# Day 5: QA team tests in staging
# ✅ All tests pass

# Day 5 end: Deploy to production
git checkout main
git merge staging --no-ff -m "Release v1.1.0"
git tag -a v1.1.0 -m "v1.1.0"
git push origin main v1.1.0
# → Auto-deploys to PRODUCTION (adk-rag-prod)
```

### **Week 2: Production Bug Found**

```bash
# Users report bug in production (v1.1.0)
# You want to reproduce it in staging first

# Reset staging to match production
git checkout staging
git reset --hard v1.1.0  # ← This is that command!
git push -f origin staging
./infrastructure/deploy.sh --env=staging

# Now staging = production
# Reproduce bug in staging (safe to break things here)

# Create hotfix
git checkout main
git checkout -b hotfix/critical-bug
# Fix the bug
git commit -m "Fix critical bug"

# Test in staging first
git checkout staging
git merge hotfix/critical-bug
git push origin staging
./infrastructure/deploy.sh --env=staging
# Test the fix in staging

# If fix works in staging → Deploy to production
git checkout main
git merge hotfix/critical-bug --no-ff
git tag -a v1.1.1 -m "v1.1.1: Hotfix"
git push origin main v1.1.1
```

---

## 🏗️ Three Environments = Three GCP Projects

**In practice, you'd have:**

```
┌─────────────┬──────────────────┬─────────────────────────────┐
│ Environment │ GCP Project      │ Purpose                     │
├─────────────┼──────────────────┼─────────────────────────────┤
│ Development │ adk-rag-dev      │ Experiments, break things   │
│ Staging     │ adk-rag-staging  │ Pre-production testing      │
│ Production  │ adk-rag-prod     │ Real users                  │
└─────────────┴──────────────────┴─────────────────────────────┘

Each has:
- Its own Cloud Run services
- Its own database
- Its own Load Balancer
- Same code, different data
```

---

## ✅ Simple Summary

### **Staging Branch Normal Use:**
```bash
# 90% of the time:
develop → staging → main
(test)   (final    (users)
         check)
```

### **Staging Branch Special Use:**
```bash
# 10% of the time:
# Deploy specific version to staging for testing
git checkout staging
git reset --hard v1.0.0  # Test old version
```

### **When to Use Staging:**
- ✅ Before every production deployment (test release candidates)
- ✅ Testing production-like environment
- ✅ User acceptance testing (UAT)
- ✅ Performance/security testing
- ✅ Reproducing production bugs safely

### **When NOT to Use Staging:**
- ❌ Daily development (use `develop` branch)
- ❌ Experimenting with new features (use `develop`)
- ❌ Breaking changes that aren't ready (use feature branches)

---

## 🎬 Visual Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Development Workflow                      │
└─────────────────────────────────────────────────────────────┘

Developer writes code:
  feature/add-auth
         │
         ▼
  merge to develop
         │
         ▼
  Deploy to DEV (adk-rag-dev)
         │
         │ Tests pass?
         ▼
  merge to staging
         │
         ▼
  Deploy to STAGING (adk-rag-staging)
         │
         │ QA approves?
         │ Security scan pass?
         │ Performance OK?
         ▼
  merge to main + tag
         │
         ▼
  Deploy to PRODUCTION (adk-rag-prod)
         │
         ▼
  ✅ Users see new feature


Special Case: Reproduce Production Bug
─────────────────────────────────────

Production bug found:
  main (v1.2.0) ← Bug here!
         │
         ▼
  Deploy v1.2.0 to staging
  git reset --hard v1.2.0
         │
         ▼
  Reproduce bug in staging
         │
         ▼
  Create hotfix branch
         │
         ▼
  Test fix in staging
         │
         ▼
  Deploy fix to production
  v1.2.1
```

---

## 📝 Staging Checklist

Before merging staging to production:

- [ ] All automated tests pass
- [ ] Manual QA testing complete
- [ ] Performance tests acceptable
- [ ] Security scans clean
- [ ] Database migrations tested
- [ ] Rollback plan documented
- [ ] Stakeholder approval received
- [ ] Documentation updated
- [ ] Monitoring dashboards ready
- [ ] On-call team notified

---

## 🔑 Key Takeaways

1. **Staging = Production dress rehearsal**
   - Same infrastructure, test data
   - Last safety check before users see changes

2. **Normal flow: develop → staging → main**
   - 90% of releases follow this path
   - Predictable, safe, tested

3. **Special use: Test specific versions**
   - `git reset --hard v1.0.0` for reproducing bugs
   - Not part of normal workflow
   - Only when needed

4. **Three environments = Three GCP projects**
   - dev: Break things
   - staging: Final validation
   - prod: Users

5. **Staging protects production**
   - Catch bugs before users see them
   - Test performance at scale
   - Validate security
   - Train team on new features

---

**Bottom line:** Staging is your "dress rehearsal" before the real show (production). That `git reset --hard v1.0.0` command was just showing you *can* put any version in staging for testing, but normally you just merge `develop` → `staging` → `main`.
