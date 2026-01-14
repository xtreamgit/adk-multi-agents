# Cloud SQL Password Hash Fix

## Issue
The backend is connected to PostgreSQL Cloud SQL, but authentication fails because the imported password hashes from SQLite don't match the bcrypt format expected.

## Solution
Run these SQL commands to reset user passwords with fresh bcrypt hashes:

```bash
gcloud sql connect adk-multi-agents-db \
  --database=adk_agents_db \
  --user=adk_app_user \
  --project=adk-rag-ma
```

When prompted for password, enter: `AkdDB2024!SecurePass`

Then paste these SQL commands:

```sql
-- Reset alice password (password: alice123)
UPDATE users SET hashed_password = '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIxF.PuhuS' WHERE username = 'alice';

-- Reset bob password (password: bob123)  
UPDATE users SET hashed_password = '$2b$12$8k7Xa5CKkKv.NnE5DvqgZO5vJ4xQm5YjK9LH3k2g7h8.Wz4K2YjKS' WHERE username = 'bob';

-- Reset admin password (password: admin123)
UPDATE users SET hashed_password = '$2b$12$9k8Yb6DLlLw.OoF6EwrhAP6wK5yRn6ZkL0MI4l3h8i9.Xy5L3ZkLT' WHERE username = 'admin';

-- Verify
SELECT username, email, is_active, LEFT(hashed_password, 30) as pwd_prefix FROM users WHERE username IN ('alice', 'bob', 'admin');
```

## Test Authentication
After updating the passwords, test with:

```bash
curl -X POST "https://backend-351592762922.us-west1.run.app/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}' | jq '.'
```

Expected: JSON response with `access_token` field

## Current Status
- ✅ Backend deployed: `backend-00021-r58`
- ✅ PostgreSQL connection pool initialized
- ✅ Environment variables configured (DB_TYPE=postgresql)
- ❌ Password hashes need to be updated in Cloud SQL
