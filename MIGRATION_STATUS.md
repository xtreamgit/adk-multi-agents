# Cloud SQL Migration Status

## ✅ Completed Steps

### Phase 1-5: Database Setup
- Created PostgreSQL Cloud SQL instance: `adk-multi-agents-db`
- Configured database: `adk_agents_db`
- Created user: `adk_app_user`
- Exported SQLite schema and data
- Migrated schema to PostgreSQL
- Imported all data successfully

### Phase 6: Backend Configuration
- Updated `backend/src/database/connection.py` with PostgreSQL support
- Created cursor wrappers for SQLite→PostgreSQL query translation
- Configured Cloud Run environment variables:
  - `DB_TYPE=postgresql`
  - `CLOUD_SQL_CONNECTION_NAME=adk-rag-ma:us-west1:adk-multi-agents-db`
  - `DB_NAME=adk_agents_db`
  - `DB_USER=adk_app_user`
  - `DB_HOST=/cloudsql/adk-rag-ma:us-west1:adk-multi-agents-db`
  - `DB_PASSWORD=AkdDB2024!SecurePass`
- Added Cloud SQL instance connection to Cloud Run
- **Deployed revision**: `backend-00021-r58`

## ⚠️ Current Blocker

### Password Hash Mismatch
The backend is successfully connected to PostgreSQL, but authentication fails because the imported password hashes from SQLite don't match the expected bcrypt format.

**Error**: `Authentication failed: invalid password for user 'alice'`

## 🔧 Solution Ready

Execute these SQL commands to fix the passwords:

```bash
# Connect to Cloud SQL as postgres superuser
gcloud sql connect adk-multi-agents-db \
  --database=adk_agents_db \
  --user=postgres \
  --project=adk-rag-ma
```

Then run:

```sql
-- Reset passwords with fresh bcrypt hashes
UPDATE users SET hashed_password = '$2b$12$8uwPP/tCIx8BJE9LeYudbu./ODStaWtPGK33HwbwW4t8f2LhM8fri' WHERE username = 'alice';
UPDATE users SET hashed_password = '$2b$12$SJuiqfsEmi8FGTRSA1v4Xe/cRMg3iVUhLg0R758paUKlVdNMHA7Hi' WHERE username = 'bob';
UPDATE users SET hashed_password = '$2b$12$5X3kiRCiVyq8LhbpI9.tS.7RKQST6WhssE4YYVPBfNn5owsCWH116' WHERE username = 'admin';

-- Verify
SELECT username, email, is_active FROM users WHERE username IN ('alice', 'bob', 'admin');
```

**User passwords after fix:**
- alice: `alice123`
- bob: `bob123`
- admin: `admin123`

## 📝 Alternative: Local Password Fix Script

If `gcloud sql connect` doesn't work, you can use Cloud SQL Proxy:

```bash
# Start Cloud SQL Proxy
cloud_sql_proxy -instances=adk-rag-ma:us-west1:adk-multi-agents-db=tcp:5432 &

# Run password update
PGPASSWORD="AkdDB2024!SecurePass" psql \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d adk_agents_db \
  -f backend/scripts/update_cloudsql_passwords.sql
```

## ✅ Test Authentication

After updating passwords:

```bash
curl -X POST "https://backend-351592762922.us-west1.run.app/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}' | jq '.'
```

**Expected**: JSON response with `access_token` field

## 📊 Verification Checklist

- [x] PostgreSQL Cloud SQL instance running
- [x] Backend connecting to Cloud SQL
- [x] Data imported successfully
- [x] Environment variables configured
- [ ] **Password hashes updated** ← Current step
- [ ] Authentication working
- [ ] Full production testing

## 🚀 Next Steps

1. Update password hashes in Cloud SQL (manual SQL execution required)
2. Test authentication with curl
3. Verify all API endpoints work correctly
4. Test frontend integration
5. Document the migration
