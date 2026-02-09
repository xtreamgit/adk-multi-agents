# Document Retrieval 500 Error Fix - January 28, 2026

## Problem

The `/open-document` page at https://34.49.46.115.nip.io was showing 500 errors when trying to retrieve documents:

```
Failed to load resource: the server responded with a status of 500 () (retrieve, line 0)
Failed to generate thumbnail: Error: Failed to generate access URL for document
```

## Root Causes

### 1. Missing IAM Permission: `iam.serviceAccounts.signBlob`

**Error in logs:**
```
ERROR:services.document_service:Error generating signed URL for gs://usfs-corpora/...: 
Error calling sign_bytes: {'error': {'code': 403, 'message': 
"Permission 'iam.serviceAccounts.signBlob' denied on resource (or it may not exist)."}}
```

**Cause:** Service account `adk-rag-agent-sa@adk-rag-ma.iam.gserviceaccount.com` lacked permission to sign URLs for GCS documents.

**Solution:** Added IAM role `roles/iam.serviceAccountTokenCreator`
```bash
gcloud projects add-iam-policy-binding adk-rag-ma \
  --member="serviceAccount:adk-rag-agent-sa@adk-rag-ma.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

### 2. Missing Database Table: `document_access_log`

**Error in logs:**
```
ERROR:services.document_service:Error logging document access: 
relation "document_access_log" does not exist
```

**Cause:** The `document_access_log` table was never created in Cloud SQL PostgreSQL. The migration file `008_create_document_access_log.sql` used SQLite syntax and wasn't run on PostgreSQL.

**Solution:** Added table creation to PostgreSQL schema initialization

**File:** `backend/src/database/schema_init.py`

Added PostgreSQL-compatible table definition:
```python
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
```

Modified `initialize_schema()` to create the table on startup:
```python
def initialize_schema():
    """Initialize database schema if using PostgreSQL."""
    if DB_TYPE != "postgresql":
        logger.info("Skipping schema initialization (not PostgreSQL)")
        return
    
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
            
            # ... rest of schema initialization
```

## Deployment

**Commit:** `b82cebf` - "Add document_access_log table to PostgreSQL schema initialization"

**Backend Revision:** `backend-00100-q62`

**Image:** `us-west1-docker.pkg.dev/adk-rag-ma/cloud-run-repo1/backend:b82cebf`

## Verification

✅ Backend logs show successful table creation:
```
INFO:database.schema_init:Creating document_access_log table...
INFO:database.schema_init:✅ document_access_log table ready
INFO:database.schema_init:✅ Database schema initialized successfully
```

✅ IAM permission granted successfully

## Testing

The user should now be able to:
1. Navigate to https://34.49.46.115.nip.io/open-document
2. Select a corpus and document
3. View document thumbnails without 500 errors
4. Open documents successfully

Document access will now be logged in the `document_access_log` table for audit purposes.

## Files Changed

- `backend/src/database/schema_init.py` - Added document_access_log table creation
- `backend/migrations/create_document_access_log_pg.py` - Created standalone migration script (for reference)

## Related Issues

This fix addresses the same pattern of issues from the PostgreSQL migration:
- SQLite migration files need PostgreSQL equivalents
- Schema initialization should handle all required tables
- IAM permissions must be configured for GCS signed URL generation
