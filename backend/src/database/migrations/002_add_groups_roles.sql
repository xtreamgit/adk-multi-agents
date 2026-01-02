-- Migration 002: Groups and Roles
-- Description: Add groups, roles, and user-group relationships
-- Date: 2025-12-31

-- User Profiles (preferences & settings)
CREATE TABLE IF NOT EXISTS user_profiles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER UNIQUE NOT NULL,
    theme TEXT DEFAULT 'light',
    language TEXT DEFAULT 'en',
    timezone TEXT DEFAULT 'UTC',
    preferences TEXT,  -- JSON stored as TEXT in SQLite
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Groups (organizational units)
CREATE TABLE IF NOT EXISTS groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

-- Roles (access permissions)
CREATE TABLE IF NOT EXISTS roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    permissions TEXT,  -- JSON stored as TEXT in SQLite
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User-Group Mapping (many-to-many)
CREATE TABLE IF NOT EXISTS user_groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    UNIQUE(user_id, group_id)
);

-- Group-Role Mapping (many-to-many)
CREATE TABLE IF NOT EXISTS group_roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    UNIQUE(group_id, role_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_groups_user ON user_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_user_groups_group ON user_groups(group_id);
CREATE INDEX IF NOT EXISTS idx_group_roles_group ON group_roles(group_id);
CREATE INDEX IF NOT EXISTS idx_group_roles_role ON group_roles(role_id);
