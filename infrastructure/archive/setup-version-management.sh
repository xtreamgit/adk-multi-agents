#!/bin/bash

#############################################################################
# Version Management Setup Script
# 
# Purpose: Set up Git branching strategy and version tags for ADK RAG Agent
# Author: Hector DeJesus
# Date: October 14, 2025
#
# This script will:
# 1. Tag current cicd branch as v1.0.0 (stable production version)
# 2. Merge cicd into main (make main the production-ready branch)
# 3. Create develop branch for future CI/CD improvements
# 4. Push all changes to remote
# 5. Display branching strategy summary
#############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Confirmation prompt
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled by user"
        exit 1
    fi
}

#############################################################################
# Main Script
#############################################################################

print_header "ADK RAG Agent - Version Management Setup"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not a git repository!"
    exit 1
fi

# Display current state
print_info "Current branch: $(git branch --show-current)"
print_info "Git status:"
git status --short

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    print_error "You have uncommitted changes. Please commit or stash them first."
    git status --short
    exit 1
fi

print_success "Working tree is clean"

#############################################################################
# Step 1: Tag current cicd branch as v1.0.0
#############################################################################

print_header "Step 1: Tag v1.0.0 on cicd branch"

# Check if tag already exists
if git rev-parse v1.0.0 >/dev/null 2>&1; then
    print_warning "Tag v1.0.0 already exists!"
    confirm "Do you want to delete it and recreate?"
    git tag -d v1.0.0
    print_success "Deleted existing v1.0.0 tag"
fi

# Ensure we're on cicd branch
git checkout cicd

# Create annotated tag
print_info "Creating annotated tag v1.0.0..."
git tag -a v1.0.0 -m "v1.0.0: Production stable release

Features:
- OAuth-protected access with Google IAP
- Load Balancer with SSL/HTTPS
- Cloud Armor security (SQL injection, XSS, DDoS protection)
- JWT authentication with SQLite
- RAG agent with Vertex AI integration
- Simplified deployment with deploy-all.sh
- Modular infrastructure library
- Comprehensive validation scripts

Status: Production ready, tested and working"

print_success "Created tag v1.0.0 on cicd branch"

# Show tag details
git show v1.0.0 --quiet

#############################################################################
# Step 2: Merge cicd into main
#############################################################################

print_header "Step 2: Merge cicd into main"

print_info "Switching to main branch..."
git checkout main

print_info "Pulling latest changes from remote..."
git pull origin main

print_info "Merging cicd into main..."
if git merge cicd --no-ff -m "Merge cicd branch - v1.0.0 stable release

This merge brings the stable v1.0.0 release to main branch:
- Simplified deployment with deploy-all.sh
- All OAuth, IAP, and Cloud Armor features working
- Comprehensive documentation and validation scripts

Tagged as v1.0.0 for future rollback capability."; then
    print_success "Successfully merged cicd into main"
else
    print_error "Merge conflict detected! Please resolve conflicts manually."
    print_info "After resolving conflicts:"
    print_info "  git add <resolved-files>"
    print_info "  git commit"
    print_info "  Then run this script again"
    exit 1
fi

# Also tag main at this point
print_info "Creating v1.0.0 tag on main branch as well..."
if git rev-parse v1.0.0 >/dev/null 2>&1; then
    # Tag already exists from cicd, no need to recreate
    print_info "v1.0.0 tag already points to this commit"
else
    git tag -a v1.0.0 -m "v1.0.0: Production stable on main branch"
    print_success "Tagged main branch as v1.0.0"
fi

#############################################################################
# Step 3: Create develop branch
#############################################################################

print_header "Step 3: Create develop branch"

# Check if develop branch already exists
if git rev-parse --verify develop >/dev/null 2>&1; then
    print_warning "Branch 'develop' already exists locally"
    confirm "Do you want to delete it and recreate from main?"
    git branch -D develop
    print_success "Deleted existing develop branch"
fi

# Create develop branch from main
print_info "Creating develop branch from main..."
git checkout -b develop

print_success "Created develop branch from main (v1.0.0)"

#############################################################################
# Step 4: Push everything to remote
#############################################################################

print_header "Step 4: Push to remote repository"

print_info "Pushing main branch..."
git push origin main

print_info "Pushing develop branch..."
git push -u origin develop

print_info "Pushing cicd branch..."
git push origin cicd

print_info "Pushing tag v1.0.0..."
git push origin v1.0.0

print_success "All branches and tags pushed to remote"

#############################################################################
# Step 5: Display branching strategy
#############################################################################

print_header "Version Management Setup Complete!"

cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║              BRANCHING STRATEGY SUMMARY                        ║
╚════════════════════════════════════════════════════════════════╝

Branch Structure:
─────────────────

  main            → Production-ready code (always deployable)
                    Tagged: v1.0.0
                    
  develop         → Active development for CI/CD improvements
                    Merge to main when stable
                    
  cicd            → Original work (can keep or delete)
  deploy          → Old feature branch (can delete)
  network         → Old feature branch (can delete)


Workflow Going Forward:
───────────────────────

1. Daily Development:
   $ git checkout develop
   $ # Make changes
   $ git add .
   $ git commit -m "Add feature"
   $ git push origin develop

2. When Ready for Production:
   $ git checkout main
   $ git merge develop --no-ff
   $ git tag -a v1.1.0 -m "Description of changes"
   $ git push origin main
   $ git push origin v1.1.0

3. Deploy to Production:
   $ git checkout main  # or specific tag
   $ ./infrastructure/deploy-all.sh

4. Rollback to v1.0.0 (if needed):
   $ git checkout v1.0.0
   $ ./infrastructure/deploy-all.sh
   # Or create rollback branch:
   $ git checkout -b rollback-v1.0.0 v1.0.0


Version Tagging (Semantic Versioning):
───────────────────────────────────────

  v1.0.0  → Current stable (OAuth + IAP + deploy-all.sh)
  v1.1.0  → Next: Add automated testing
  v1.2.0  → Next: Add Secret Manager integration
  v2.0.0  → Major: Terraform migration

  Format: vMAJOR.MINOR.PATCH
  - MAJOR: Breaking changes
  - MINOR: New features (backward compatible)
  - PATCH: Bug fixes


GitHub Actions Configuration:
──────────────────────────────

Your CI/CD pipeline already configured for this structure!

  .github/workflows/ci.yml:
    on:
      push:
        branches: [ main, develop ]  ✓
      pull_request:
        branches: [ main ]           ✓


Current Repository State:
─────────────────────────

EOF

echo "  Branches:"
git branch -a | grep -v "HEAD"

echo ""
echo "  Tags:"
git tag -l -n1

echo ""
echo "  Current branch: $(git branch --show-current)"

echo ""
print_success "You are now on the 'develop' branch ready for CI/CD improvements!"

cat << 'EOF'

Next Steps:
───────────

1. Review the Phase 1 CI/CD tasks (from previous recommendations)
2. Work on develop branch for all new changes
3. Test thoroughly before merging to main
4. Tag each stable release

Optional Cleanup:
─────────────────

If you no longer need the old feature branches:
  $ git branch -d deploy network cicd
  $ git push origin --delete deploy network cicd

Or keep them for historical reference.


Documentation Created:
──────────────────────

  ✓ VERSION-MANAGEMENT.md - Detailed branching strategy
  ✓ CHANGELOG.md - Version history tracker

EOF

print_header "Setup Complete!"

exit 0
