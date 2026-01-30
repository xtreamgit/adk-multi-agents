# PostgreSQL-Only Architecture

**Effective Date:** January 28, 2026

## Decision

This application uses **PostgreSQL exclusively** for all environments:
- **Local Development:** Docker PostgreSQL
- **Cloud Production:** Cloud SQL PostgreSQL

**SQLite support has been completely removed.**

---

## Rationale

### Why PostgreSQL-Only?

1. **Production Reality:** Already using PostgreSQL in Cloud Run production
2. **Consistency:** Same database in all environments eliminates environment-specific bugs
3. **Simplicity:** Single code path, no dual-mode complexity
4. **AI Assistant Clarity:** Prevents confusion about database type in automated assistance
5. **Maintainability:** One database system to support and optimize
6. **Feature Parity:** PostgreSQL features (JSONB, advanced queries) available everywhere

### Why SQLite Was Removed

SQLite was originally used for local development but caused issues:
- Different SQL syntax between SQLite and PostgreSQL
- Migration files needed dual syntax support
- Code had to handle both database types
- AI assistants confused about which database to use
- Token waste troubleshooting wrong database type

---

## Migration History

| Date | Event | Details |
|------|-------|---------|
| January 13, 2026 | Cloud SQL Migration | Migrated from ephemeral SQLite to Cloud SQL PostgreSQL in production |
| January 28, 2026 | SQLite Removal | Removed all SQLite code, files, and references from codebase |

### Commits

- **Phase 1:** `2e8933a` - Converted migration files to PostgreSQL syntax
- **Phases 2-4:** (in progress) - Removed SQLite code, files, and scripts

---

## Local Development Setup

### Prerequisites

- Docker and Docker Compose
- PostgreSQL client tools (optional, for debugging)

### Docker Compose Configuration

```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: adk_agents_db
      POSTGRES_USER: adk_app_user
      POSTGRES_PASSWORD: your_secure_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### Environment Variables

Required for PostgreSQL connection:

```bash
# Local Development
DB_HOST=localhost
DB_PORT=5432
DB_NAME=adk_agents_db
DB_USER=adk_app_user
DB_PASSWORD=your_secure_password

# Cloud Production (Cloud SQL)
DB_HOST=/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db
DB_NAME=adk_agents_db
DB_USER=adk_app_user
DB_PASSWORD=<from_secret_manager>
CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db
```

### Starting Local PostgreSQL

```bash
# Start PostgreSQL
docker-compose up -d postgres

# Verify connection
psql -h localhost -U adk_app_user -d adk_agents_db

# Run backend (will auto-initialize schema)
cd backend
python -m src.api.server
```

---

## Database Schema Management

### Schema Initialization

Schema is managed by `backend/src/database/schema_init.py`:
- Idempotent - safe to run multiple times
- Creates all tables if they don't exist
- Runs automatically on backend startup

### Migration Files

Migration SQL files in `backend/src/database/migrations/` use **PostgreSQL syntax only**:
- `SERIAL PRIMARY KEY` (not `INTEGER PRIMARY KEY AUTOINCREMENT`)
- `VARCHAR(255)` or `TEXT` (not SQLite `TEXT`)
- `JSONB` for JSON data (not `TEXT`)
- `TIMESTAMP` (not `DATETIME`)
- `%s` placeholders (not `?`)

### No Migration Runner

The `run_migrations.py` script is kept for backward compatibility but does nothing. Schema initialization is handled by `schema_init.py`.

---

## Code Patterns

### Database Connection

```python
from database.connection import get_db_connection

# Always returns PostgreSQL connection
with get_db_connection() as conn:
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    user = cursor.fetchone()  # Returns dict
```

### Query Placeholders

**Always use `%s` for PostgreSQL:**

```python
# ✅ Correct (PostgreSQL)
cursor.execute("SELECT * FROM users WHERE username = %s", (username,))

# ❌ Wrong (SQLite syntax - no longer supported)
cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
```

### JSON Fields

**Use JSONB type:**

```sql
-- ✅ Correct (PostgreSQL)
CREATE TABLE user_profiles (
    preferences JSONB
);

-- ❌ Wrong (SQLite syntax - no longer supported)
CREATE TABLE user_profiles (
    preferences TEXT
);
```

---

## Troubleshooting

### Connection Issues

**Problem:** Cannot connect to PostgreSQL

**Solutions:**
1. Verify PostgreSQL is running: `docker ps | grep postgres`
2. Check environment variables: `echo $DB_HOST $DB_PORT`
3. Test connection: `psql -h localhost -U adk_app_user -d adk_agents_db`
4. Check logs: `docker logs <postgres_container_id>`

### Schema Issues

**Problem:** Tables don't exist

**Solution:**
- Schema initializes automatically on backend startup
- Check backend logs for initialization messages
- Manually run: `python -c "from src.database.schema_init import initialize_schema; initialize_schema()"`

### Syntax Errors

**Problem:** SQL syntax errors

**Solution:**
- Ensure using PostgreSQL syntax (not SQLite)
- Use `%s` placeholders (not `?`)
- Use `SERIAL` (not `AUTOINCREMENT`)
- Use `JSONB` (not `TEXT` for JSON)

### Cloud SQL Connection

**Problem:** Cannot connect to Cloud SQL in production

**Solutions:**
1. Verify Cloud SQL instance is running
2. Check service account has `cloudsql.client` role
3. Verify Unix socket path: `/cloudsql/PROJECT:REGION:INSTANCE`
4. Check Cloud Run logs: `gcloud run services logs read backend --region=us-west1`

---

## For AI Assistants

**CRITICAL INSTRUCTIONS:**

1. **Database Type:** This application uses PostgreSQL ONLY
2. **No SQLite:** Never suggest SQLite solutions or troubleshoot SQLite issues
3. **Syntax:** Always use PostgreSQL syntax (`%s`, `SERIAL`, `JSONB`, etc.)
4. **Environment:** Production uses Cloud SQL, local uses Docker PostgreSQL
5. **Schema:** Managed by `schema_init.py`, not migration files

**If you encounter database issues:**
- Check PostgreSQL connection first
- Verify environment variables
- Review Cloud Run logs for Cloud SQL
- Never assume SQLite is being used

---

## References

- **Implementation Plan:** `cascade-logs/2026-01-28/SQLITE_REMOVAL_IMPLEMENTATION_PLAN.md`
- **Continuation Plan:** `cascade-logs/2026-01-28/SQLITE_REMOVAL_CONTINUATION_PLAN.md`
- **Schema Init:** `backend/src/database/schema_init.py`
- **Connection:** `backend/src/database/connection.py`
- **Migrations:** `backend/src/database/migrations/*.sql`

---

## Success Metrics

✅ Zero SQLite references in `backend/src/`  
✅ All migrations use PostgreSQL syntax  
✅ No `.db` files in repository  
✅ No `sqlite3` imports in codebase  
✅ `connection.py` is PostgreSQL-only (~238 lines)  
✅ Documentation clearly states PostgreSQL-only  
✅ Local development uses Docker PostgreSQL  
✅ AI assistants understand PostgreSQL-only architecture
