-- Migration 006: Add IAP authentication support
-- Description: Add google_id and auth_provider fields to support IAP authentication
-- Date: 2026-01-10
--
-- Note: SQLite doesn't support adding UNIQUE columns or making columns nullable via ALTER TABLE.
-- We need to recreate the table with the new schema and copy the data.

-- Create new users table with updated schema including IAP support
CREATE TABLE IF NOT EXISTS users_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    hashed_password TEXT,  -- Now nullable for IAP users
    google_id TEXT UNIQUE,
    auth_provider TEXT DEFAULT 'local',
    is_active BOOLEAN DEFAULT 1,
    default_agent_id INTEGER,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_login TEXT,
    FOREIGN KEY (default_agent_id) REFERENCES agents(id)
);

-- Copy existing data to new table (only existing columns, new ones get defaults)
INSERT INTO users_new (id, username, email, full_name, hashed_password, google_id, 
                       auth_provider, is_active, default_agent_id, created_at, updated_at, last_login)
SELECT id, username, email, full_name, hashed_password, NULL,
       'local', is_active, default_agent_id, created_at, updated_at, last_login
FROM users;

-- Drop old table and rename new one
DROP TABLE users;
ALTER TABLE users_new RENAME TO users;

-- Recreate indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_users_auth_provider ON users(auth_provider);

-- Migration complete
