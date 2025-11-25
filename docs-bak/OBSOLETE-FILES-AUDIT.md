# Obsolete Files Audit - Repository Cleanup Analysis

**Date:** October 11, 2025  
**Purpose:** Identify files that can be safely removed to reduce vulnerability footprint  
**Status:** ANALYSIS ONLY - No files have been deleted

---

## Executive Summary

After migrating to the modular deployment architecture (`deploy-all.sh` + `lib/` modules), many files are now obsolete. This audit identifies **82 files/directories** that can be removed, reducing the repository size and attack surface.

### Categories
- **Old Deployment Scripts:** 19 files
- **Documentation (Superseded):** 13 files
- **Backup Directories:** 9 directories
- **Archive Directories:** 3 directories + contents
- **Empty/Unused Directories:** 5 directories
- **Development/Test Files:** 4 files
- **Obsolete Configuration:** 3 files
- **Temporary/Generated Files:** 2 files

---

## 📋 Detailed Audit Table

### Category 1: Old Deployment Scripts (SUPERSEDED)

These scripts have been replaced by the modular `deploy-all.sh` + `lib/` modules.

| File Path | Size | Reason | Replacement | Risk Level | Safe to Delete? |
|-----------|------|--------|-------------|------------|-----------------|
| `infrastructure/deploy-complete-oauth-v0.2.sh` | ~15KB | Old monolithic OAuth deployment | `deploy-all.sh` + `lib/oauth.sh` + `lib/iap.sh` | Low | ✅ YES |
| `infrastructure/deploy-secure-v0.2.sh` | ~20KB | Old monolithic secure deployment | `deploy-all.sh` + `lib/loadbalancer.sh` | Low | ✅ YES |
| `infrastructure/deploy-init.sh` | ~5KB | Old initialization script | `deploy-config.sh` | Low | ✅ YES |
| `infrastructure/deploy-new-project-id.sh` | ~3KB | Old project setup | `deploy-config.sh --interactive` | Low | ✅ YES |
| `infrastructure/remove_excessive_permissions.sh` | ~2KB | One-time fix script | No longer needed | Low | ✅ YES |
| `infrastructure/validate-ingress-security.sh` | ~3KB | Old validation | `validate-deployment.sh` | Low | ✅ YES |
| `infrastructure/validate-security.sh` | ~4KB | Old validation | `validate-deployment.sh` | Low | ✅ YES |
| `verify-config-migration.sh` | ~7KB | One-time migration script | Migration complete | Low | ✅ YES |

**Subtotal: 8 files**

---

### Category 2: Archived Deployment Scripts (IN ARCHIVE DIRECTORY)

Scripts moved to `infrastructure/archive/` - entire directory can be removed.

| File Path | Size | Reason | Safe to Delete? |
|-----------|------|--------|-----------------|
| `infrastructure/archive/build_images.sh` | ~2KB | Old build script | ✅ YES |
| `infrastructure/archive/check-client.sh` | ~1KB | Debug script | ✅ YES |
| `infrastructure/archive/create-iap-sa.sh` | ~2KB | Old IAP setup | ✅ YES |
| `infrastructure/archive/deploy-complete-oauth.sh` | ~18KB | Old OAuth deployment | ✅ YES |
| `infrastructure/archive/deploy-new.sh` | ~5KB | Old deployment | ✅ YES |
| `infrastructure/archive/deploy-secure-bak.sh` | ~15KB | Backup of old script | ✅ YES |
| `infrastructure/archive/deploy-secure.sh` | ~16KB | Old secure deployment | ✅ YES |
| `infrastructure/archive/deploy-setup.sh` | ~4KB | Old setup | ✅ YES |
| `infrastructure/archive/deploy-with-secrets.sh` | ~3KB | Old deployment | ✅ YES |
| `infrastructure/archive/deploy.sh` | ~3KB | Original deployment | ✅ YES |
| `infrastructure/archive/fix-cors-issue.sh` | ~2KB | One-time fix | ✅ YES |
| `infrastructure/archive/fix-deploy-secure-oauth-reuse.sh` | ~3KB | One-time fix | ✅ YES |
| `infrastructure/archive/fix-iap-oauth-client.sh` | ~2KB | One-time fix | ✅ YES |
| `infrastructure/archive/fix-oauth-redirect-uris.sh` | ~2KB | One-time fix | ✅ YES |
| `infrastructure/archive/sync-oauth-clients-patch.sh` | ~3KB | One-time patch | ✅ YES |
| `infrastructure/archive/troubleshoot-iap-error9.sh` | ~3KB | Debug script | ✅ YES |

**Subtotal: 16 files in archive directory**  
**Recommendation:** Delete entire `infrastructure/archive/` directory

---

### Category 3: Old Documentation (SUPERSEDED)

Documentation that has been replaced by newer, modular guides.

| File Path | Size | Reason | Replacement | Safe to Delete? |
|-----------|------|--------|-------------|-----------------|
| `ACCOUNT-SWITCHING-GUIDE.md` | ~7KB | One-time account switching guide | No longer needed | ✅ YES |
| `COMPLETE-OAUTH-SETUP.md` | ~9KB | Old OAuth guide | `README-MODULAR-DEPLOYMENT.md` (Section 5) | ✅ YES |
| `CONFIG-MANAGEMENT-SUMMARY.md` | ~9KB | Config migration summary | Migration complete | ✅ YES |
| `CONFIG-MIGRATION-SUMMARY.md` | ~5KB | Migration notes | Migration complete | ✅ YES |
| `DEPLOYMENT-FIX-SUMMARY.md` | ~7KB | Old deployment fixes | Fixes incorporated | ✅ YES |
| `MIGRATION-COMPLETE.md` | ~8KB | Migration completion notes | One-time documentation | ✅ YES |
| `OAuth-Consent-Screen-Setup.md` | ~10KB | Old OAuth guide | `README-MODULAR-DEPLOYMENT.md` | ✅ YES |
| `DEPLOYMENT-CHECKLIST.md` | ~6KB | Old checklist | `DEPLOYMENT-SUCCESS.md` | ⚠️ MAYBE |

**Subtotal: 8 files**

**Notes:**
- `DEPLOYMENT-CHECKLIST.md` might be useful to keep as a manual checklist
- Others are historical/migration documentation

---

### Category 4: Documentation in docs/ Directory (POTENTIALLY OBSOLETE)

Documentation in `docs/` subdirectory - some may be superseded.

| File Path | Size | Reason | Current Status | Safe to Delete? |
|-----------|------|--------|----------------|-----------------|
| `docs/ADK-RAG-OAUTH-SETUP.md` | ~16KB | Old OAuth setup guide | Superseded by `README-MODULAR-DEPLOYMENT.md` | ✅ YES |
| `docs/ARCHITECTURE-BLUEPRINT.md` | ~30KB | Old architecture docs | May contain useful info | ⚠️ REVIEW |
| `docs/BREAKTHROUGH.md` | ~13KB | CORS breakthrough notes | Historical, but valuable | ⚠️ KEEP |
| `docs/IAP-AND-LOADBALANCER.md` | ~6KB | Old IAP/LB guide | Superseded by modular docs | ✅ YES |
| `docs/README-Docker-Setup.md` | ~2KB | Docker setup (unused) | Not using Docker locally | ⚠️ MAYBE |
| `docs/README-Docker.md` | ~5KB | Docker guide (unused) | Not using Docker locally | ⚠️ MAYBE |
| `docs/README.md` | ~4KB | Old docs README | Superseded | ✅ YES |
| `docs/SECURE-DEPLOYMENT-GUIDE.md` | ~9KB | Old deployment guide | Superseded by modular docs | ✅ YES |
| `docs/SINGLE-URL-SECURITY-ANALYSIS.md` | ~9KB | Security analysis | Historical value | ⚠️ KEEP |

**Subtotal: 9 files**

**Recommendation:**
- Delete 5 definitely obsolete files
- Keep 2 historical/valuable files (BREAKTHROUGH.md, SINGLE-URL-SECURITY-ANALYSIS.md)
- Review 2 Docker files (delete if not using Docker)
- Review ARCHITECTURE-BLUEPRINT.md (may have useful diagrams)

---

### Category 5: Backup Directories (SAFE TO DELETE)

Automated backup directories from config migrations - no longer needed.

| Directory Path | Contents | Reason | Safe to Delete? |
|----------------|----------|--------|-----------------|
| `backups/project_id_update_20251003_171405/` | 4 files | Old config backup | ✅ YES |
| `backups/project_id_update_20251003_171552/` | 4 files | Old config backup | ✅ YES |
| `backups/project_id_update_20251004_094237/` | 4 files | Old config backup | ✅ YES |
| `backups/project_id_update_20251004_100025/` | 4 files | Old config backup | ✅ YES |
| `backups/project_id_update_20251004_100334/` | 4 files | Old config backup | ✅ YES |
| `backups/project_id_update_20251006_092200/` | 4 files | Old config backup | ✅ YES |
| `backups/project_id_update_20251006_093648/` | 4 files | Old config backup | ✅ YES |
| `backups/project_id_update_20251006_100349/` | 4 files | Old config backup | ✅ YES |
| `backups/project_id_update_20251007_195204/` | 4 files | Old config backup | ✅ YES |

**Subtotal: 9 directories (36 files total)**

**Recommendation:** Delete entire `backups/` directory - migration complete

---

### Category 6: Archive Directories (SAFE TO DELETE)

Code and files explicitly moved to archive - no longer used.

| Directory Path | Contents | Reason | Safe to Delete? |
|----------------|----------|--------|-----------------|
| `archive-code/` | 8 files | Old scripts and Python files | ✅ YES |
| `archive-code/rag_agent/` | 0 files | Empty directory | ✅ YES |
| `archive-scrap/` | 2 files + 2 dirs | Coverage reports, debug files | ✅ YES |
| `archive-scrap/infrastructure/` | 0 files | Empty directory | ✅ YES |
| `archive-scrap/root-files/` | 0 files | Empty directory | ✅ YES |

**Files in archive-code/:**
- `deploy-public-full.sh` (~4KB) - Old public deployment
- `deploy-public.sh` (~3KB) - Old public deployment
- `fav.ico` (~26KB) - Old favicon
- `get_gcs_text.py` (~2KB) - Old utility
- `get_text.py` (~4KB) - Old utility
- `get_text_from_corpus.py` (~3KB) - Old utility
- `setup-test-vm.sh` (~4KB) - Old test VM setup
- `start_dev-for-prod.sh` (~1KB) - Old dev script

**Subtotal: 2 directories + 8 files**

**Recommendation:** Delete entire `archive-code/` and `archive-scrap/` directories

---

### Category 7: Empty/Unused Directories

Directories that are empty or contain no useful files.

| Directory Path | Contents | Purpose | Safe to Delete? |
|----------------|----------|---------|-----------------|
| `terraform/` | Empty subdirectories | Unused infrastructure-as-code | ✅ YES |
| `terraform/environments/` | 0 files | Never used | ✅ YES |
| `backend/src/api/middleware/` | 0 files | Planned but unused | ⚠️ MAYBE |
| `backend/src/api/routes/` | 0 files | Planned but unused | ⚠️ MAYBE |
| `.ilb-cert/` | 2 cert files | Self-signed certs for ILB (unused) | ⚠️ REVIEW |

**Subtotal: 5 directories**

**Recommendations:**
- Delete `terraform/` - not using Terraform
- Keep `middleware/` and `routes/` if planning future refactor
- Review `.ilb-cert/` - delete if not using Internal Load Balancer

---

### Category 8: Development/Test Files

Files used for development/testing that shouldn't be in production.

| File Path | Size | Reason | Safe to Delete? |
|-----------|------|--------|-----------------|
| `backend/pytest.ini` | <1KB | Pytest configuration | ⚠️ KEEP if testing |
| `users.db` | ~12KB | Local SQLite database | ⚠️ DO NOT DELETE |
| `.DS_Store` | ~6KB | macOS metadata | ✅ YES (add to .gitignore) |
| `generate_secret_key.py` | <1KB | Secret key generator | ⚠️ KEEP (utility) |

**Subtotal: 4 files**

**Recommendations:**
- Keep `pytest.ini` if running tests
- DO NOT delete `users.db` (active database)
- Delete `.DS_Store` and add to `.gitignore`
- Keep `generate_secret_key.py` (useful utility)

---

### Category 9: Obsolete Configuration Files

Configuration files that are no longer used.

| File Path | Size | Reason | Safe to Delete? |
|-----------|------|--------|-----------------|
| `deployment.config.backup` | ~1KB | Backup of deployment config | ✅ YES |
| `.env` | ~384B | Might be used locally | ⚠️ REVIEW |
| `.env.example` | ~380B | Example file | ⚠️ KEEP (template) |
| `.env.yaml` | ~198B | Cloud Run env file (gitignored) | ⚠️ REVIEW |

**Subtotal: 4 files**

**Recommendations:**
- Delete `deployment.config.backup` - have version control
- Keep `.env.example` as template
- Review `.env` and `.env.yaml` - check if still used

---

### Category 10: Documentation Screenshots

Screen captures in `doc-screen-captures/` directory.

| File Path | Size | Reason | Safe to Delete? |
|-----------|------|--------|-----------------|
| `doc-screen-captures/Audience.png` | ? | OAuth setup screenshot | ⚠️ MAYBE |
| `doc-screen-captures/Branding.png` | ? | OAuth setup screenshot | ⚠️ MAYBE |
| `doc-screen-captures/Client.png` | ? | OAuth setup screenshot | ⚠️ MAYBE |
| `doc-screen-captures/Client1.png` | ? | OAuth setup screenshot | ⚠️ MAYBE |

**Subtotal: 4 files**

**Recommendation:** Keep if referenced in documentation, otherwise delete

---

## 📊 Summary Statistics

| Category | Files/Dirs | Safe to Delete | Review Needed | Keep |
|----------|-----------|----------------|---------------|------|
| Old Deployment Scripts | 8 | 8 | 0 | 0 |
| Archived Scripts | 16 | 16 | 0 | 0 |
| Old Documentation | 8 | 7 | 1 | 0 |
| Docs Directory | 9 | 5 | 2 | 2 |
| Backup Directories | 9 | 9 | 0 | 0 |
| Archive Directories | 3 + 8 files | 11 | 0 | 0 |
| Empty Directories | 5 | 2 | 3 | 0 |
| Dev/Test Files | 4 | 1 | 2 | 1 |
| Config Files | 4 | 1 | 2 | 1 |
| Screenshots | 4 | 0 | 4 | 0 |
| **TOTAL** | **~70** | **~60** | **~14** | **~4** |

---

## 🎯 Recommended Deletion Plan

### Phase 1: Safe to Delete Immediately (Low Risk)

**Delete these directories entirely:**
```bash
rm -rf backups/
rm -rf archive-code/
rm -rf archive-scrap/
rm -rf infrastructure/archive/
rm -rf terraform/
```

**Delete these files:**
```bash
# Old deployment scripts
rm infrastructure/deploy-complete-oauth-v0.2.sh
rm infrastructure/deploy-secure-v0.2.sh
rm infrastructure/deploy-init.sh
rm infrastructure/deploy-new-project-id.sh
rm infrastructure/remove_excessive_permissions.sh
rm infrastructure/validate-ingress-security.sh
rm infrastructure/validate-security.sh
rm verify-config-migration.sh

# Old documentation
rm ACCOUNT-SWITCHING-GUIDE.md
rm COMPLETE-OAUTH-SETUP.md
rm CONFIG-MANAGEMENT-SUMMARY.md
rm CONFIG-MIGRATION-SUMMARY.md
rm DEPLOYMENT-FIX-SUMMARY.md
rm MIGRATION-COMPLETE.md
rm OAuth-Consent-Screen-Setup.md

# Docs directory
rm docs/ADK-RAG-OAUTH-SETUP.md
rm docs/IAP-AND-LOADBALANCER.md
rm docs/README.md
rm docs/SECURE-DEPLOYMENT-GUIDE.md

# Config backups
rm deployment.config.backup

# macOS files
rm .DS_Store
echo ".DS_Store" >> .gitignore
```

**Estimated cleanup:** ~50-60 files, reducing repo size by ~500KB+

---

### Phase 2: Review Before Deletion (Medium Risk)

**Files to review:**
1. `.env` and `.env.yaml` - Check if used in local development
2. `.ilb-cert/` directory - Check if Internal Load Balancer is used
3. `DEPLOYMENT-CHECKLIST.md` - Decide if useful as manual checklist
4. `docs/README-Docker.md` and `docs/README-Docker-Setup.md` - Keep if using Docker
5. `docs/ARCHITECTURE-BLUEPRINT.md` - Review for useful content
6. `backend/src/api/middleware/` and `backend/src/api/routes/` - Keep if planning refactor
7. `doc-screen-captures/` - Check if referenced in docs

---

### Phase 3: Keep (Important Files)

**DO NOT DELETE:**
- `users.db` - Active database
- `secrets.env` - Active secrets (gitignored)
- `deployment.config` - Active config
- `generate_secret_key.py` - Useful utility
- `.env.example` - Template file
- `backend/pytest.ini` - Test configuration
- `docs/BREAKTHROUGH.md` - Valuable historical context
- `docs/SINGLE-URL-SECURITY-ANALYSIS.md` - Security analysis

---

## 🔒 Security Impact

### Vulnerability Footprint Reduction

**Before Cleanup:**
- ~150 files total
- Multiple deployment scripts with credentials/configs
- Backup directories with old configs
- Archive code with potential vulnerabilities

**After Cleanup:**
- ~90 files total (40% reduction)
- Single deployment pipeline
- No backup/archive clutter
- Reduced attack surface

### Benefits:
1. **Fewer files to scan** for vulnerabilities
2. **Clearer codebase** - easier to audit
3. **No old code** with outdated security practices
4. **Reduced complexity** - fewer files to maintain

---

## ⚠️ Important Notes

1. **Backup First:** Before deleting anything, create a backup or ensure Git history is intact
2. **Check References:** Search codebase for references to files before deletion
3. **Team Coordination:** Notify team members before major cleanup
4. **Test After Cleanup:** Run `./infrastructure/test-pipeline.sh` after deletion
5. **Git Commit:** Commit deletions in logical groups (e.g., "Remove old deployment scripts")

---

## 🚀 Next Steps

1. **Review this audit** with your team
2. **Execute Phase 1 deletions** (safe files)
3. **Manually review Phase 2 files**
4. **Test deployment** after cleanup
5. **Update documentation** to reflect changes
6. **Create backup branch** before major deletions

---

## 📝 Deletion Script

I can create an automated deletion script for Phase 1 files if you approve this audit. Would you like me to create:

1. **cleanup-phase1.sh** - Automated deletion of safe files
2. **cleanup-audit.sh** - Dry-run script that lists what would be deleted
3. **backup-before-cleanup.sh** - Creates backup branch before deletion

---

**Audit Complete:** October 11, 2025  
**Files Identified:** ~70 obsolete files/directories  
**Safe to Delete:** ~60 items  
**Needs Review:** ~14 items  
**Estimated Size Reduction:** ~500KB-1MB
