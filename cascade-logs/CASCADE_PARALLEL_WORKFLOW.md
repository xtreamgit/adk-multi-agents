# Cascade Parallel Development Workflow

## Overview

This guide explains how to leverage multiple Cascade sessions with git branches to accelerate development.

## The Strategy

### Key Concept: Isolation + Coordination

Each Cascade session works in isolation on its own feature branch, but coordinates through:
1. **Shared integration branch** (`develop`)
2. **Branch tracking file** (`ACTIVE_BRANCHES.md`)
3. **Session summaries** (document what each session did)

## Setting Up Multiple Cascade Sessions

### Initial Setup (Do Once)

1. **Initialize branching strategy:**
   ```bash
   ./scripts/setup-branches.sh
   ```

2. **Review documentation:**
   - `GIT_BRANCHING_STRATEGY.md` - Complete branching guide
   - `cascade-logs/ACTIVE_BRANCHES.md` - Track active work
   - `.github/pull_request_template.md` - PR template

### Starting Each Cascade Session

#### Session 1: Feature A
```bash
# Terminal 1
git checkout develop
git pull origin develop
git checkout -b feature/admin-enhancements
```

Update `ACTIVE_BRANCHES.md`:
```markdown
| feature/admin-enhancements | Cascade-1 | In Progress | 2026-01-15 | Admin dashboard UI |
```

Start session summary:
```markdown
# SESSION_SUMMARY_2026-01-15_SESSION_1.md
Branch: feature/admin-enhancements
Focus: Admin dashboard enhancements
```

#### Session 2: Feature B (Parallel)
```bash
# Terminal 2  
git checkout develop
git pull origin develop
git checkout -b feature/search-improvements
```

Update `ACTIVE_BRANCHES.md`:
```markdown
| feature/search-improvements | Cascade-2 | In Progress | 2026-01-15 | Search optimization |
```

Start session summary:
```markdown
# SESSION_SUMMARY_2026-01-15_SESSION_2.md
Branch: feature/search-improvements
Focus: Search performance and UX
```

#### Session 3: Bug Fix (Parallel)
```bash
# Terminal 3
git checkout develop
git pull origin develop
git checkout -b fix/timeout-issue
```

## Workflow Patterns

### Pattern 1: Independent Features (No Conflicts)

**Best for:** Features that touch different parts of the codebase

**Example:**
- Session 1: Frontend UI changes (`frontend/src/components/Admin/*`)
- Session 2: Backend API endpoint (`backend/src/api/routes/search.py`)
- Session 3: Documentation (`docs/*`)

**Workflow:**
```bash
# Each session works independently
# Minimal coordination needed
# Merge to develop when ready
```

### Pattern 2: Dependent Features (Sequential)

**Best for:** Features that build on each other

**Example:**
- Session 1: Create new database table and repository
- Session 2: Build API endpoint using new repository (waits for Session 1)
- Session 3: Build UI using new API (waits for Session 2)

**Workflow:**
```bash
# Session 1 finishes and merges to develop
# Session 2 pulls develop and starts
# Session 3 pulls develop and starts
```

### Pattern 3: Coordinated Features (Shared Components)

**Best for:** Features that modify shared code

**Example:**
- Session 1: Refactor authentication service
- Session 2: Add new auth features (coordinates with Session 1)

**Workflow:**
```bash
# Frequent communication via ACTIVE_BRANCHES.md
# Regular syncs from develop
# Coordinate merge timing
```

## Coordination Mechanisms

### 1. ACTIVE_BRANCHES.md (Primary Coordination)

**Purpose:** Real-time view of who's doing what

**Update frequency:** Every time you start/stop work

**Example:**
```markdown
| Branch | Session | Status | Notes |
|--------|---------|--------|-------|
| feature/admin-ui | Cascade-1 | In Progress | Working on corpus metadata editor |
| feature/search | Cascade-2 | Testing | Needs review before merge |
| fix/timeout | Cascade-3 | Blocked | Waiting for Session 1 to merge |
```

### 2. Session Summaries (Historical Record)

**Purpose:** Document what was accomplished

**Naming:** `SESSION_SUMMARY_YYYY-MM-DD_SESSION_N.md`

**Include:**
- Branch name
- What was built
- What was learned
- What's next

### 3. Git Commit Messages (Technical Coordination)

**Purpose:** Clear commit history shows intent

**Format:**
```bash
git commit -m "feat(admin): add corpus metadata editing form

- Created MetadataEditor component
- Added validation for tags and notes
- Connected to /api/admin/corpora/metadata endpoint

Part of feature/admin-enhancements
Session: Cascade-1, 2026-01-15"
```

## Daily Workflow Example

### Morning: Planning Phase

1. **Review ACTIVE_BRANCHES.md** - See what's in progress
2. **Choose features** - Assign features to sessions
3. **Update tracking** - Mark sessions as "In Progress"

### During Day: Development Phase

**Session 1 (Hours 1-3):**
```bash
# Work on feature/admin-enhancements
git add .
git commit -m "feat(admin): add metadata editor component"
git push origin feature/admin-enhancements
```

**Session 2 (Hours 1-3, parallel):**
```bash
# Work on feature/search-improvements
git add .
git commit -m "perf(search): optimize query execution"
git push origin feature/search-improvements
```

**Session 3 (Hours 2-4, parallel):**
```bash
# Work on fix/timeout-issue
git add .
git commit -m "fix(auth): resolve session timeout bug"
git push origin fix/timeout-issue
```

### Mid-Day: Integration Check

```bash
# Each session syncs with develop
git checkout feature/your-branch
git fetch origin
git merge origin/develop
# Resolve any conflicts
git push
```

### End of Day: Merge Phase

**Session 1 - Ready to merge:**
```bash
# Create PR
gh pr create --base develop --head feature/admin-enhancements \
  --title "feat: Admin dashboard enhancements" \
  --body "See SESSION_SUMMARY_2026-01-15_SESSION_1.md"

# Or via GitHub UI
```

**Session 2 - Still in progress:**
```bash
# Push latest work
git push origin feature/search-improvements
# Update ACTIVE_BRANCHES.md status to "In Progress - 70% complete"
```

**Session 3 - Testing:**
```bash
# Deploy to test environment
# Update ACTIVE_BRANCHES.md status to "Testing"
```

## Handling Conflicts

### Scenario 1: Two Sessions Modify Same File

**Session 1:** Modified `backend/src/api/routes/admin.py`
**Session 2:** Also modified `backend/src/api/routes/admin.py`

**Resolution:**
```bash
# Session 2 syncs with develop after Session 1 merges
git checkout feature/session-2-branch
git fetch origin
git merge origin/develop

# Resolve conflicts in admin.py
# Test thoroughly
git add backend/src/api/routes/admin.py
git commit -m "merge: resolve conflicts with admin endpoint changes"
git push
```

### Scenario 2: Dependent Features Need Coordination

**Session 1:** Creates new database table
**Session 2:** Needs to use that table

**Solution:**
```bash
# Session 1: Merge to develop first
# Session 2: Wait for merge, then pull develop

# Session 2:
git checkout feature/session-2-branch
git merge develop  # Gets Session 1's database changes
# Now can use new table
```

## Best Practices for Cascade Parallel Work

### ✅ DO

1. **Work on different components** when possible
   - Session 1: Frontend
   - Session 2: Backend API
   - Session 3: Database/migrations

2. **Update ACTIVE_BRANCHES.md** immediately
   - Before starting work
   - When changing status
   - When blocked

3. **Commit frequently** with good messages
   - Small, focused commits
   - Clear descriptions
   - Reference session number

4. **Sync with develop daily**
   ```bash
   git merge origin/develop
   ```

5. **Create PRs when features are complete**
   - Don't wait for perfection
   - Merge small features frequently

6. **Document your session**
   - What you built
   - What you learned
   - What's next

7. **Use descriptive branch names**
   - `feature/corpus-metadata-editor` ✅
   - `feature/stuff` ❌

### ❌ DON'T

1. **Don't have multiple sessions on same branch**
   - Causes confusion and conflicts
   - Hard to track who did what

2. **Don't let branches get stale**
   - Merge within 3-5 days
   - Long-lived branches = merge hell

3. **Don't commit directly to develop**
   - Always use feature branches
   - Develop is for integration only

4. **Don't ignore conflicts**
   - Resolve immediately
   - Test after resolution

5. **Don't work on same files simultaneously**
   - Coordinate via ACTIVE_BRANCHES.md
   - Sequence dependent work

## Example: Full Day with 3 Parallel Sessions

### Morning (9 AM)

**Planning:**
```markdown
Session 1: feature/admin-corpus-editor
Session 2: feature/search-filters  
Session 3: fix/session-persistence
```

### Development (9 AM - 12 PM)

**All sessions work in parallel:**
- Each on their own branch
- Regular commits
- Push to remote every hour

### Lunch Break (12 PM - 1 PM)

**Sync check:**
```bash
# Each session pulls develop
git merge origin/develop
# Resolve any conflicts
```

### Afternoon (1 PM - 5 PM)

**Session 1 finishes at 3 PM:**
- Creates PR
- Merges to develop
- Deletes branch

**Session 2 & 3 continue:**
- Pull latest develop (includes Session 1's work)
- Continue development

### End of Day (5 PM)

**Session 2 finishes:**
- Creates PR
- Merges to develop

**Session 3 still in progress:**
- Pushes latest work
- Updates ACTIVE_BRANCHES.md: "80% complete, finishing tomorrow"

## Tools to Help

### Git Aliases (from setup-branches.sh)

```bash
# Quick branch creation
git newfeature admin-enhancements

# Quick status
git st

# See all branches
git branches

# Pretty log
git lg
```

### GitHub CLI (Optional)

```bash
# Install
brew install gh

# Create PR from command line
gh pr create --base develop --head feature/my-feature

# Check PR status
gh pr status

# Merge PR
gh pr merge
```

### VS Code Extensions (Recommended)

- **GitLens** - Enhanced git visualization
- **Git Graph** - Visual branch graph
- **GitHub Pull Requests** - Manage PRs in VS Code

## Troubleshooting

### "I'm blocked waiting for another session"

**Solution:**
1. Update ACTIVE_BRANCHES.md with "Blocked" status
2. Work on a different feature in a new branch
3. Check back when blocker is resolved

### "I have conflicts and don't know how to resolve"

**Solution:**
```bash
# See what's conflicting
git status

# Open files, look for conflict markers:
<<<<<<< HEAD
Your changes
=======
Their changes
>>>>>>> develop

# Choose correct version or merge manually
# Test thoroughly after resolution
git add <file>
git commit -m "merge: resolve conflicts"
```

### "I accidentally committed to develop"

**Solution:**
```bash
# Undo the commit
git checkout develop
git reset --soft HEAD~1

# Create proper feature branch
git checkout -b feature/my-feature
git commit -m "feat: proper commit"
```

## Scaling to More Sessions

Current: 3 parallel sessions → Can scale to 5-10 sessions

**Keys to scaling:**
1. Clear component boundaries
2. Strong coordination via ACTIVE_BRANCHES.md
3. Frequent merges to develop
4. Good test coverage

## Success Metrics

You're doing it right when:
- ✅ Multiple features ship per day
- ✅ Minimal merge conflicts
- ✅ Clear history of who did what
- ✅ Each session is productive
- ✅ Features integrate smoothly

## Next Steps

1. **Run setup script:**
   ```bash
   ./scripts/setup-branches.sh
   ```

2. **Try it out:**
   - Start 2 parallel sessions
   - Work on different features
   - Merge both to develop

3. **Refine process:**
   - Adjust coordination mechanisms
   - Find optimal session count
   - Improve communication

---

**Remember:** The goal is to move fast while staying organized. Use branches to enable parallelism, but don't let process slow you down.
