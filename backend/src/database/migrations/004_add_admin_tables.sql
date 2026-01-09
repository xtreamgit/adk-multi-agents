-- Migration 004: Admin Panel Tables
-- Description: Add audit logging and corpus metadata tables for admin panel
-- Date: 2026-01-08

-- Audit log for all corpus changes
CREATE TABLE IF NOT EXISTS corpus_audit_log (
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

-- Enhanced corpus metadata
CREATE TABLE IF NOT EXISTS corpus_metadata (
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

-- Scheduled sync jobs (for future automation)
CREATE TABLE IF NOT EXISTS corpus_sync_schedule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    corpus_id INTEGER,
    frequency TEXT, -- 'hourly', 'daily', 'weekly'
    last_run DATETIME,
    next_run DATETIME,
    is_active BOOLEAN DEFAULT 1,
    FOREIGN KEY (corpus_id) REFERENCES corpora(id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_audit_corpus ON corpus_audit_log(corpus_id);
CREATE INDEX IF NOT EXISTS idx_audit_user ON corpus_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON corpus_audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_action ON corpus_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_corpus_metadata_corpus ON corpus_metadata(corpus_id);
CREATE INDEX IF NOT EXISTS idx_corpus_metadata_status ON corpus_metadata(sync_status);
CREATE INDEX IF NOT EXISTS idx_sync_schedule_corpus ON corpus_sync_schedule(corpus_id);
CREATE INDEX IF NOT EXISTS idx_sync_schedule_active ON corpus_sync_schedule(is_active);
