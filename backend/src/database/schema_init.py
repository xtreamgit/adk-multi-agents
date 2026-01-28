"""
Database schema initialization for PostgreSQL.
Automatically creates tables on first run.
"""

import logging
from .connection import get_db_connection

logger = logging.getLogger(__name__)

# Document access log table (for audit trail)
DOCUMENT_ACCESS_LOG_TABLE = """
CREATE TABLE IF NOT EXISTS document_access_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    corpus_id INTEGER NOT NULL REFERENCES corpora(id) ON DELETE CASCADE,
    document_name VARCHAR(255) NOT NULL,
    document_file_id VARCHAR(255),
    access_type VARCHAR(50) DEFAULT 'view',
    success BOOLEAN NOT NULL,
    error_message TEXT,
    source_uri TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_document_access_user ON document_access_log(user_id, accessed_at);
CREATE INDEX IF NOT EXISTS idx_document_access_corpus ON document_access_log(corpus_id, accessed_at);
CREATE INDEX IF NOT EXISTS idx_document_access_time ON document_access_log(accessed_at);
CREATE INDEX IF NOT EXISTS idx_document_access_success ON document_access_log(success, accessed_at);
"""

POSTGRESQL_SCHEMA = DOCUMENT_ACCESS_LOG_TABLE + """
-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    hashed_password VARCHAR(255),
    google_id VARCHAR(255) UNIQUE,
    auth_provider VARCHAR(50) DEFAULT 'local',
    is_active BOOLEAN DEFAULT TRUE,
    default_agent_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    preferences JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_groups (
    user_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, group_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS group_roles (
    group_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    PRIMARY KEY (group_id, role_id),
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS agents (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    config_path VARCHAR(255),
    instructions TEXT,
    model VARCHAR(255) DEFAULT 'gemini-2.0-flash-exp',
    temperature FLOAT DEFAULT 0.7,
    top_p FLOAT DEFAULT 0.95,
    top_k INTEGER DEFAULT 40,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS corpora (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    vertex_corpus_id VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS group_corpora (
    group_id INTEGER NOT NULL,
    corpus_id INTEGER NOT NULL,
    PRIMARY KEY (group_id, corpus_id),
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (corpus_id) REFERENCES corpora(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS chat_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    agent_id INTEGER,
    title VARCHAR(255),
    message_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS user_stats (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL,
    total_queries INTEGER DEFAULT 0,
    total_sessions INTEGER DEFAULT 0,
    last_query_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_users_auth_provider ON users(auth_provider);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_groups_user_id ON user_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_user_groups_group_id ON user_groups(group_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_agent_id ON chat_sessions(agent_id);
CREATE INDEX IF NOT EXISTS idx_corpora_active ON corpora(is_active);
CREATE INDEX IF NOT EXISTS idx_agents_active ON agents(is_active);

-- Default data will be inserted separately after schema creation
"""


def initialize_schema():
    """Initialize PostgreSQL database schema."""
    
    try:
        logger.info("Initializing PostgreSQL schema...")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # First, create document_access_log table if it doesn't exist
            try:
                logger.info("Creating document_access_log table...")
                cursor.execute(DOCUMENT_ACCESS_LOG_TABLE)
                conn.commit()
                logger.info("✅ document_access_log table ready")
            except Exception as e:
                logger.warning(f"⚠️  document_access_log table creation: {e}")
                conn.rollback()
            
            statements = [stmt.strip() for stmt in POSTGRESQL_SCHEMA.split(';') if stmt.strip()]
            
            # Execute each statement individually with its own transaction
            for statement in statements:
                if statement and not statement.startswith('--'):
                    try:
                        cursor.execute(statement)
                        conn.commit()  # Commit after each successful statement
                    except Exception as e:
                        # Rollback failed statement and continue
                        conn.rollback()
                        logger.debug(f"Statement skipped (may already exist): {str(e)[:100]}")
            
            # Insert default data with rollback protection
            try:
                cursor.execute("INSERT INTO roles (name, description) VALUES ('user', 'Standard user role') ON CONFLICT (name) DO NOTHING")
                conn.commit()
            except Exception as e:
                conn.rollback()
                logger.debug(f"Default role insert skipped: {e}")
            
            try:
                cursor.execute("INSERT INTO groups (name, description) VALUES ('users', 'Default user group') ON CONFLICT (name) DO NOTHING")
                conn.commit()
            except Exception as e:
                conn.rollback()
                logger.debug(f"Default group insert skipped: {e}")
            
            try:
                cursor.execute("""
                    INSERT INTO group_roles (group_id, role_id) 
                    SELECT g.id, r.id FROM groups g, roles r 
                    WHERE g.name = 'users' AND r.name = 'user'
                    ON CONFLICT DO NOTHING
                """)
                conn.commit()
            except Exception as e:
                conn.rollback()
                logger.debug(f"Default group_roles insert skipped: {e}")
            
            logger.info("✅ Database schema initialized successfully")
            
    except Exception as e:
        logger.error(f"Failed to initialize schema: {e}")
        # Don't raise - allow app to continue even if schema init fails
        logger.warning("Continuing despite schema initialization error")
