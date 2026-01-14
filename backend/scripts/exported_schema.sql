-- Exported from SQLite on 2026-01-13T09:24:31.385677
-- Convert to PostgreSQL syntax
-- Note: This is for reference only. Use migration scripts for actual schema.

-- Table: agents
CREATE TABLE agents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT,
    config_path TEXT NOT NULL,  -- e.g., 'agent1', 'develom'
    is_active BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_agents_name ON agents(name);
CREATE INDEX idx_agents_active ON agents(is_active);

-- Table: corpora
CREATE TABLE corpora (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT,
    gcs_bucket TEXT NOT NULL,
    vertex_corpus_id TEXT,  -- Vertex AI corpus ID
    is_active BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_corpora_name ON corpora(name);
CREATE INDEX idx_corpora_active ON corpora(is_active);

-- Table: corpus_audit_log
CREATE TABLE corpus_audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    corpus_id INTEGER,
    user_id INTEGER,
    action TEXT NOT NULL, -- 'created', 'updated', 'deleted', 'granted_access', 'revoked_access', 'synced', 'activated', 'deactivated'
    changes TEXT, -- JSON: Store before/after snapshot
    metadata TEXT, -- JSON: Additional context (IP, user agent, etc)
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (corpus_id) REFERENCES corpora(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX idx_audit_corpus ON corpus_audit_log(corpus_id);
CREATE INDEX idx_audit_user ON corpus_audit_log(user_id);
CREATE INDEX idx_audit_timestamp ON corpus_audit_log(timestamp);
CREATE INDEX idx_audit_action ON corpus_audit_log(action);

-- Table: corpus_metadata
CREATE TABLE corpus_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    corpus_id INTEGER UNIQUE NOT NULL,
    created_by INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_synced_at DATETIME,
    last_synced_by INTEGER,
    document_count INTEGER DEFAULT 0,
    last_document_count_update DATETIME,
    sync_status TEXT DEFAULT 'active', -- 'active', 'syncing', 'error', 'deleted'
    sync_error_message TEXT,
    tags TEXT, -- JSON: For categorization
    notes TEXT, -- Admin notes
    FOREIGN KEY (corpus_id) REFERENCES corpora(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (last_synced_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX idx_corpus_metadata_corpus ON corpus_metadata(corpus_id);
CREATE INDEX idx_corpus_metadata_status ON corpus_metadata(sync_status);

-- Table: corpus_sync_schedule
CREATE TABLE corpus_sync_schedule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    corpus_id INTEGER,
    frequency TEXT, -- 'hourly', 'daily', 'weekly'
    last_run DATETIME,
    next_run DATETIME,
    is_active BOOLEAN DEFAULT 1,
    FOREIGN KEY (corpus_id) REFERENCES corpora(id) ON DELETE CASCADE
);

CREATE INDEX idx_sync_schedule_corpus ON corpus_sync_schedule(corpus_id);
CREATE INDEX idx_sync_schedule_active ON corpus_sync_schedule(is_active);

-- Table: group_corpus_access
CREATE TABLE group_corpus_access (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL,
    corpus_id INTEGER NOT NULL,
    permission TEXT DEFAULT 'read',  -- read, write, admin
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (corpus_id) REFERENCES corpora(id) ON DELETE CASCADE,
    UNIQUE(group_id, corpus_id)
);

CREATE INDEX idx_group_corpus_access_group ON group_corpus_access(group_id);
CREATE INDEX idx_group_corpus_access_corpus ON group_corpus_access(corpus_id);

-- Table: group_roles
CREATE TABLE group_roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    UNIQUE(group_id, role_id)
);

CREATE INDEX idx_group_roles_group ON group_roles(group_id);
CREATE INDEX idx_group_roles_role ON group_roles(role_id);

-- Table: groups
CREATE TABLE groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);


-- Table: roles
CREATE TABLE roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    permissions TEXT,  -- JSON stored as TEXT in SQLite
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Table: schema_migrations
CREATE TABLE schema_migrations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            migration_name TEXT UNIQUE NOT NULL,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );


-- Table: session_corpus_selections
CREATE TABLE session_corpus_selections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    corpus_id INTEGER NOT NULL,
    last_selected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (corpus_id) REFERENCES corpora(id) ON DELETE CASCADE,
    UNIQUE(user_id, corpus_id)
);

CREATE INDEX idx_session_corpus_user ON session_corpus_selections(user_id);
CREATE INDEX idx_session_corpus_corpus ON session_corpus_selections(corpus_id);

-- Table: user_agent_access
CREATE TABLE user_agent_access (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id INTEGER NOT NULL,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    UNIQUE(user_id, agent_id)
);

CREATE INDEX idx_user_agent_access_user ON user_agent_access(user_id);
CREATE INDEX idx_user_agent_access_agent ON user_agent_access(agent_id);

-- Table: user_groups
CREATE TABLE user_groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    UNIQUE(user_id, group_id)
);

CREATE INDEX idx_user_groups_user ON user_groups(user_id);
CREATE INDEX idx_user_groups_group ON user_groups(group_id);

-- Table: user_profiles
CREATE TABLE user_profiles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER UNIQUE NOT NULL,
    theme TEXT DEFAULT 'light',
    language TEXT DEFAULT 'en',
    timezone TEXT DEFAULT 'UTC',
    preferences TEXT,  -- JSON stored as TEXT in SQLite
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);


-- Table: user_sessions
CREATE TABLE user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    user_id INTEGER NOT NULL,
    active_agent_id INTEGER,
    active_corpora TEXT,  -- JSON array stored as TEXT in SQLite
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT 1, message_count INTEGER DEFAULT 0, user_query_count INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (active_agent_id) REFERENCES agents(id)
);

CREATE INDEX idx_sessions_session_id ON user_sessions(session_id);
CREATE INDEX idx_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_sessions_active ON user_sessions(is_active);
CREATE INDEX idx_sessions_user_query_count ON user_sessions(user_query_count);

-- Table: users
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    hashed_password TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    default_agent_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(is_active);

