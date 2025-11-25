# Git Quick Reference - ADK RAG Agent

Quick commands for daily version management tasks.

---

## 🚀 Daily Development

```bash
# Switch to develop branch
git checkout develop

# Pull latest changes
git pull origin develop

# Make changes, then commit
git add .
git commit -m "Add monitoring dashboard"
git push origin develop
```

---

## 📦 Create a Release

```bash
# 1. Switch to main
git checkout main

# 2. Merge develop
git merge develop --no-ff -m "Release v1.1.0"

# 3. Tag the release
git tag -a v1.1.0 -m "v1.1.0: Description"

# 4. Push everything
git push origin main
git push origin v1.1.0

# 5. Deploy
./infrastructure/deploy-all.sh
```

---

## 🔥 Emergency Hotfix

```bash
# 1. Create hotfix from main
git checkout main
git checkout -b hotfix/critical-bug

# 2. Fix and commit
git add .
git commit -m "Fix critical bug"

# 3. Merge to main and tag
git checkout main
git merge hotfix/critical-bug --no-ff
git tag -a v1.0.1 -m "v1.0.1: Hotfix"

# 4. Merge to develop
git checkout develop
git merge hotfix/critical-bug --no-ff

# 5. Push and deploy
git push origin main develop v1.0.1
git checkout main
./infrastructure/deploy-all.sh
```

---

## ⏮️ Rollback to Previous Version

```bash
# Quick rollback (deploy old version)
git checkout v1.0.0
./infrastructure/deploy-all.sh

# Return to main when done
git checkout main
```

---

## 📊 View History

```bash
# List all tags
git tag -l

# List tags with messages
git tag -l -n1

# Show specific tag
git show v1.0.0

# Compare two versions
git diff v1.0.0..v1.1.0

# Show commits between versions
git log v1.0.0..v1.1.0 --oneline
```

---

## 🌿 Branch Management

```bash
# List all branches
git branch -a

# Create feature branch
git checkout develop
git checkout -b feature/new-feature

# Merge feature to develop
git checkout develop
git merge feature/new-feature --no-ff

# Delete feature branch
git branch -d feature/new-feature
```

---

## 🔍 Current Status

```bash
# Check current branch
git branch --show-current

# Check status
git status

# View recent commits
git log --oneline -5

# Show uncommitted changes
git diff
```

---

## 📝 Commit Message Format

```bash
# Format: [type]: [description]

git commit -m "feat: Add Secret Manager integration"
git commit -m "fix: Resolve IAP timeout issue"
git commit -m "docs: Update deployment guide"
git commit -m "refactor: Simplify deployment script"
git commit -m "test: Add unit tests for RAG tools"
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `refactor` - Code restructuring
- `test` - Adding tests
- `chore` - Maintenance

---

## 🏷️ Tagging Conventions

```bash
# Production release
git tag -a v1.1.0 -m "v1.1.0: Description"

# Release candidate
git tag -a v1.1.0-rc.1 -m "Release candidate 1"

# Beta release
git tag -a v1.1.0-beta.1 -m "Beta release"

# Hotfix
git tag -a v1.0.1 -m "v1.0.1: Hotfix description"
```

---

## ⚠️ Emergency Commands

```bash
# Undo last commit (keep changes)
git reset --soft HEAD~1

# Discard all local changes
git reset --hard HEAD

# Stash changes temporarily
git stash
git stash pop

# Delete local tag
git tag -d v1.1.0

# Delete remote tag
git push origin --delete v1.1.0
```

---

## 📋 Pre-Merge Checklist

Before merging develop to main:

- [ ] `git status` - Clean working tree
- [ ] `./infrastructure/test-pipeline.sh` - Tests pass
- [ ] `git log develop --oneline -10` - Review commits
- [ ] Update `CHANGELOG.md` with changes
- [ ] Update version in relevant files

---

## 🔗 Useful Aliases (Optional)

Add to `~/.gitconfig`:

```ini
[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = log --graph --oneline --all
    tags = tag -l -n1
```

Then use:
```bash
git st          # git status
git co develop  # git checkout develop
git br          # git branch
git tags        # git tag -l -n1
```

---

## 📚 Full Documentation

For detailed information, see:
- **VERSION-MANAGEMENT.md** - Complete branching strategy
- **CHANGELOG.md** - Version history
- **README.md** - Project overview

---

## 🆘 Quick Help

```bash
# Where am I?
git branch --show-current

# What changed?
git status
git diff

# Show me versions
git tag -l

# Go to version
git checkout v1.0.0

# Go back to latest
git checkout main
```

---

**Remember:**
- Work on `develop` for new features
- Merge to `main` when stable
- Tag every release
- Always test before merging to main
- Keep CHANGELOG.md updated
