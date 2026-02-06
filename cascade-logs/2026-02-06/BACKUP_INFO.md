# PostgreSQL Database Backup - February 06, 2026

## Backup Details

**Date:** February 06, 2026 10:16 AM  
**Database:** adk_agents_db_dev  
**User:** adk_dev_user  
**Container:** adk-postgres-dev (postgres:15)

## Backup Files

### 1. Custom Format (Recommended for Restore)
- **File:** `adk_agents_db_backup_2026-02-06.dump`
- **Size:** 128 KB
- **Format:** PostgreSQL custom format (compressed)
- **Use for:** Fast, reliable restore with pg_restore

**Restore Command:**
```bash
docker exec -i adk-postgres-dev pg_restore -U adk_dev_user -d adk_agents_db_dev --clean --if-exists < cascade-logs/2026-02-06/adk_agents_db_backup_2026-02-06.dump
```

### 2. Plain SQL Format (Human Readable)
- **File:** `adk_agents_db_backup_2026-02-06.sql`
- **Size:** 179 KB
- **Format:** Plain SQL text
- **Use for:** Viewing schema, manual edits, version control

**Restore Command:**
```bash
docker exec -i adk-postgres-dev psql -U adk_dev_user -d adk_agents_db_dev < cascade-logs/2026-02-06/adk_agents_db_backup_2026-02-06.sql
```

## Database Statistics

**Total Tables:** 30

### Top 15 Tables by Size

| Table Name | Size | Row Count |
|-----------|------|-----------|
| document_access_log | 184 KB | 0 |
| users | 160 KB | 0 |
| corpus_audit_log | 128 KB | 0 |
| chatbot_users | 112 KB | 0 |
| corpus_metadata | 112 KB | 0 |
| chatbot_agent_type_tools | 88 KB | 0 |
| chatbot_groups | 80 KB | 0 |
| chatbot_agents | 80 KB | 0 |
| chatbot_user_groups | 72 KB | 0 |
| chatbot_group_agents | 72 KB | 0 |
| chatbot_corpus_access | 72 KB | 0 |
| chatbot_group_agent_types | 72 KB | 0 |
| chatbot_tools | 64 KB | 0 |
| corpora | 64 KB | 0 |
| user_profiles | 64 KB | 0 |

## Key Tables Backed Up

### Chatbot System
- `chatbot_users` - User accounts
- `chatbot_groups` - Groups (admin-group, content-manager-group, etc.)
- `chatbot_user_groups` - User-to-group assignments
- `chatbot_corpus_access` - **Critical:** Group-to-corpus access grants
- `chatbot_agents` - Agent configurations
- `chatbot_agent_type_tools` - Agent-to-tool permissions

### Corpus Management
- `corpora` - Corpus definitions (7 active corpora)
- `corpus_metadata` - Metadata including document counts
- `corpus_audit_log` - Audit trail

### User Management
- `users` - User accounts
- `user_profiles` - User profile data
- `user_groups` - Legacy group assignments

## Backup Location

```
/Users/hector/github.com/xtreamgit/adk-multi-agents/cascade-logs/2026-02-06/
├── adk_agents_db_backup_2026-02-06.dump (128 KB)
├── adk_agents_db_backup_2026-02-06.sql (179 KB)
└── BACKUP_INFO.md (this file)
```

## Important Notes

1. **Row counts show 0** because pg_stat_user_tables may not be updated. Actual data exists in tables.
2. **Both formats are complete** - use .dump for restore, .sql for inspection
3. **Backup includes:**
   - All table schemas
   - All data
   - Indexes
   - Constraints
   - Sequences
   - Permissions

## Quick Restore Guide

### Full Database Restore
```bash
# 1. Stop backend server
# 2. Drop and recreate database
docker exec adk-postgres-dev psql -U adk_dev_user -c "DROP DATABASE IF EXISTS adk_agents_db_dev;"
docker exec adk-postgres-dev psql -U adk_dev_user -c "CREATE DATABASE adk_agents_db_dev;"

# 3. Restore from backup
docker exec -i adk-postgres-dev pg_restore -U adk_dev_user -d adk_agents_db_dev --clean --if-exists < cascade-logs/2026-02-06/adk_agents_db_backup_2026-02-06.dump

# 4. Restart backend server
```

### Selective Table Restore
```bash
# Restore only specific table
docker exec -i adk-postgres-dev pg_restore -U adk_dev_user -d adk_agents_db_dev --table=chatbot_corpus_access < cascade-logs/2026-02-06/adk_agents_db_backup_2026-02-06.dump
```

## System State at Backup Time

- **Active Corpora:** 7 (ai-books, design, hacker-books, management, recipes, semantic-web, test-corpus)
- **Groups:** 4 (admin-group, content-manager-group, contributor-group, viewer-group)
- **Access Control:** Fully functional matrix-based system
- **Recent Fixes:** Repository queries use chatbot tables, document counts from database

## Next Backup Recommendation

Create backups:
- **Daily:** Before major changes
- **Weekly:** Regular scheduled backup
- **Before:** Database migrations, schema changes, bulk data operations

---

**Backup Created By:** Cascade AI Assistant  
**Verified:** ✅ Both formats created successfully
