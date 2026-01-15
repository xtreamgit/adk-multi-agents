# Git Branching Strategy for Parallel Cascade Development

## Overview

This branching strategy is designed to support multiple parallel Cascade sessions working on different features simultaneously without conflicts.

## Branch Structure

```
main (production-ready code)
  ├── develop (integration branch)
  │   ├── feature/admin-dashboard-enhancements
  │   ├── feature/corpus-sync-automation
  │   ├── feature/user-permissions-refactor
  │   ├── fix/session-timeout-bug
  │   └── refactor/database-queries
  └── hotfix/critical-production-issue
```

## Branch Types

### 1. `main` - Production Branch
- **Purpose:** Always production-ready, deployed code
- **Protection:** Protected, requires PR approval
- **Deployments:** Auto-deploys to Cloud Run production
- **Rules:** Only merge from `develop` or `hotfix/*`

### 2. `develop` - Integration Branch
- **Purpose:** Integration point for all features
- **Testing:** All features tested together here
- **Merges to:** `main` when stable
- **Created from:** `main`

### 3. `feature/*` - Feature Branches
- **Purpose:** New features or enhancements
- **Naming:** `feature/<short-description>`
- **Examples:**
  - `feature/corpus-metadata-ui`
  - `feature/advanced-search`
  - `feature/user-analytics-dashboard`
- **Created from:** `develop`
- **Merges to:** `develop`
- **Lifespan:** Delete after merge

### 4. `fix/*` - Bug Fix Branches
- **Purpose:** Non-critical bug fixes
- **Naming:** `fix/<bug-description>`
- **Examples:**
  - `fix/login-timeout`
  - `fix/corpus-display-order`
- **Created from:** `develop`
- **Merges to:** `develop`

### 5. `hotfix/*` - Critical Production Fixes
- **Purpose:** Emergency fixes for production
- **Naming:** `hotfix/<critical-issue>`
- **Created from:** `main`
- **Merges to:** `main` AND `develop`
- **Priority:** Highest

### 6. `refactor/*` - Code Refactoring
- **Purpose:** Code improvements without feature changes
- **Naming:** `refactor/<component>`
- **Created from:** `develop`
- **Merges to:** `develop`

## Workflow for Parallel Cascade Sessions

### Starting a New Feature (Cascade Session)

```bash
# 1. Ensure you're on develop and up to date
git checkout develop
git pull origin develop

# 2. Create and checkout new feature branch
git checkout -b feature/your-feature-name

# 3. Document in session summary what feature this session is working on
# Add to SESSION_SUMMARY: "Branch: feature/your-feature-name"
```

### During Development

```bash
# Commit frequently with descriptive messages
git add .
git commit -m "feat: add corpus metadata editing UI"

# Push to remote regularly to backup work
git push origin feature/your-feature-name
```

### Finishing a Feature

```bash
# 1. Ensure feature is complete and tested
# 2. Update develop with latest changes
git checkout develop
git pull origin develop

# 3. Merge develop into your feature branch (handle conflicts)
git checkout feature/your-feature-name
git merge develop

# 4. Test your feature with latest develop changes
# 5. Push final version
git push origin feature/your-feature-name

# 6. Create Pull Request on GitHub: feature/your-feature-name → develop
```

### Merging to Develop

```bash
# After PR approval
git checkout develop
git pull origin develop
git merge --no-ff feature/your-feature-name
git push origin develop

# Delete feature branch
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

## Parallel Session Coordination

### Session Assignment Strategy

Create a tracking file to assign features to Cascade sessions:

**Example: `cascade-logs/ACTIVE_BRANCHES.md`**
```markdown
| Branch Name | Session | Status | Started | Owner/Focus |
|-------------|---------|--------|---------|-------------|
| feature/corpus-ui-enhancements | Cascade-1 | In Progress | 2026-01-15 | Admin Dashboard |
| feature/user-role-management | Cascade-2 | In Progress | 2026-01-15 | Permissions |
| fix/search-performance | Cascade-3 | Testing | 2026-01-14 | Performance |
```

### Rules for Parallel Sessions

1. **One Feature Per Session:** Each Cascade session works on exactly one feature branch
2. **No Shared Files:** Try to work on different files/components to minimize conflicts
3. **Clear Ownership:** Document which session owns which branch
4. **Regular Syncs:** Merge `develop` into your feature branch daily
5. **Communication:** Update `ACTIVE_BRANCHES.md` with status

## Branch Naming Conventions

### Format
```
<type>/<short-description-with-hyphens>
```

### Good Examples
- `feature/admin-corpus-metadata-editor`
- `feature/enhanced-search-filters`
- `fix/session-persistence-bug`
- `refactor/database-connection-pool`
- `hotfix/auth-token-expiration`

### Bad Examples
- `my-changes` (not descriptive)
- `feature/fix` (wrong type)
- `admin_dashboard_changes` (use hyphens, not underscores)
- `Feature/AdminStuff` (use lowercase)

## Commit Message Conventions

Follow Conventional Commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat:` New feature
- `fix:` Bug fix
- `refactor:` Code refactoring
- `docs:` Documentation changes
- `test:` Adding or updating tests
- `chore:` Maintenance tasks
- `perf:` Performance improvements

### Examples
```bash
git commit -m "feat(admin): add corpus metadata editing interface"
git commit -m "fix(auth): resolve token expiration issue"
git commit -m "refactor(db): optimize query execution in cursor wrapper"
git commit -m "docs: update API documentation for admin endpoints"
```

## Conflict Resolution

### When Conflicts Occur

1. **Pull latest develop:**
   ```bash
   git checkout develop
   git pull origin develop
   ```

2. **Merge develop into your feature:**
   ```bash
   git checkout feature/your-feature
   git merge develop
   ```

3. **Resolve conflicts:**
   - Open conflicted files in IDE
   - Choose correct version or merge manually
   - Test thoroughly after resolution

4. **Complete the merge:**
   ```bash
   git add .
   git commit -m "merge: resolve conflicts with develop"
   git push origin feature/your-feature
   ```

## Pull Request Template

Create `.github/pull_request_template.md`:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Refactoring
- [ ] Documentation
- [ ] Hotfix

## Related Issue
Closes #(issue number)

## Changes Made
- Change 1
- Change 2

## Testing
- [ ] Manual testing completed
- [ ] Endpoint tested via curl/Postman
- [ ] Tested in browser
- [ ] Cloud Run deployment verified

## Deployment Notes
Any special deployment considerations

## Cascade Session
Session summary: `cascade-logs/SESSION_SUMMARY_YYYY-MM-DD.md`
```

## Daily Workflow for Multiple Sessions

### Morning Routine (Each Cascade Session)

```bash
# 1. Check what branches exist
git fetch origin
git branch -a

# 2. Review ACTIVE_BRANCHES.md to see what others are working on

# 3. Start your session
git checkout develop
git pull origin develop
git checkout -b feature/todays-feature

# 4. Update ACTIVE_BRANCHES.md with your branch
```

### End of Day Routine

```bash
# 1. Commit all work
git add .
git commit -m "feat: work in progress on feature X"

# 2. Push to remote
git push origin feature/your-feature

# 3. Update session summary with branch name and status
```

## Deployment Strategy

### Development Deployments
- Deploy from `feature/*` branches to test environments
- Use separate Cloud Run services or revisions with 0% traffic

### Staging Deployments
- Deploy from `develop` branch
- Integration testing environment

### Production Deployments
- Only deploy from `main` branch
- After thorough testing in staging

## Emergency Procedures

### Hotfix Process

```bash
# 1. Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-issue

# 2. Fix the issue
# ... make changes ...
git commit -m "hotfix: resolve critical production issue"

# 3. Merge to main
git checkout main
git merge --no-ff hotfix/critical-issue
git push origin main

# 4. Merge to develop
git checkout develop
git merge --no-ff hotfix/critical-issue
git push origin develop

# 5. Delete hotfix branch
git branch -d hotfix/critical-issue
```

## Tools and Automation

### Recommended Git Aliases

Add to `~/.gitconfig`:

```ini
[alias]
    # Branch management
    newfeature = "!f() { git checkout develop && git pull && git checkout -b feature/$1; }; f"
    newfix = "!f() { git checkout develop && git pull && git checkout -b fix/$1; }; f"
    
    # Quick status
    st = status -sb
    
    # Branch list
    branches = branch -a
    
    # Log
    lg = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
```

### Usage Examples

```bash
# Create new feature branch
git newfeature admin-dashboard-enhancements

# Create new fix branch
git newfix session-timeout-bug

# View branch graph
git lg
```

## Best Practices Summary

1. ✅ **Always branch from develop** (except hotfixes)
2. ✅ **Keep branches short-lived** (days, not weeks)
3. ✅ **Commit frequently with good messages**
4. ✅ **Push to remote regularly** (backup your work)
5. ✅ **Sync with develop daily** (avoid big merge conflicts)
6. ✅ **Delete branches after merge** (keep repo clean)
7. ✅ **Use descriptive branch names** (future you will thank you)
8. ✅ **Document your branch** in ACTIVE_BRANCHES.md
9. ✅ **Test before creating PR** (save reviewer time)
10. ✅ **One feature per branch** (easier to review and rollback)

## Troubleshooting

### "My branch is behind develop by 50 commits"
```bash
git checkout your-branch
git merge develop
# Resolve conflicts if any
git push
```

### "I accidentally committed to develop"
```bash
# Undo last commit (keep changes)
git reset --soft HEAD~1

# Create proper feature branch
git checkout -b feature/proper-branch-name
git commit -m "feat: proper commit message"
git push origin feature/proper-branch-name
```

### "I need to switch branches but have uncommitted changes"
```bash
# Option 1: Stash changes
git stash
git checkout other-branch
# Later: git stash pop

# Option 2: Commit work in progress
git add .
git commit -m "wip: work in progress"
git checkout other-branch
```

## Resources

- [Git Branching Best Practices](https://git-scm.com/book/en/v2/Git-Branching-Branching-Workflows)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)
