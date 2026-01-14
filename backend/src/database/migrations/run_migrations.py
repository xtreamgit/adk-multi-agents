#!/usr/bin/env python3
"""
Database Migration Runner
Runs all SQL migration files in order
"""

import os
import sqlite3
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Use local path for development, Cloud Run path in production
if os.path.exists("/app/data"):
    DEFAULT_DB_PATH = "/app/data/users.db"
else:
    # Local development - use ./data relative to backend directory
    backend_dir = Path(__file__).parent.parent.parent.parent
    DEFAULT_DB_PATH = str(backend_dir / "data" / "users.db")

DATABASE_PATH = os.getenv("DATABASE_PATH", DEFAULT_DB_PATH)
MIGRATIONS_DIR = Path(__file__).parent


def get_migration_files():
    """Get all migration files in order."""
    migrations = []
    for file in sorted(MIGRATIONS_DIR.glob("*.sql")):
        migrations.append(file)
    return migrations


def run_migration(conn, migration_file):
    """Run a single migration file."""
    logger.info(f"Running migration: {migration_file.name}")
    
    with open(migration_file, 'r') as f:
        sql = f.read()
    
    try:
        cursor = conn.cursor()
        cursor.executescript(sql)
        conn.commit()
        logger.info(f"✅ Migration {migration_file.name} completed successfully")
        return True
    except Exception as e:
        error_msg = str(e).lower()
        # Handle "duplicate column" errors gracefully - treat as warning, not failure
        if "duplicate column" in error_msg or "already exists" in error_msg:
            logger.warning(f"⚠️  Migration {migration_file.name}: {e} (treating as success - column already exists)")
            conn.rollback()
            return True  # Treat as success since the desired state is already achieved
        else:
            logger.error(f"❌ Migration {migration_file.name} failed: {e}")
            conn.rollback()
            return False


def init_migration_tracking(conn):
    """Create a table to track which migrations have been run."""
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS schema_migrations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            migration_name TEXT UNIQUE NOT NULL,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()


def is_migration_applied(conn, migration_name):
    """Check if a migration has already been applied."""
    cursor = conn.cursor()
    cursor.execute(
        "SELECT 1 FROM schema_migrations WHERE migration_name = ?",
        (migration_name,)
    )
    return cursor.fetchone() is not None


def mark_migration_applied(conn, migration_name):
    """Mark a migration as applied."""
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO schema_migrations (migration_name) VALUES (?)",
        (migration_name,)
    )
    conn.commit()


def run_all_migrations():
    """Run all migration files."""
    # Skip migrations if using PostgreSQL (already applied to Cloud SQL)
    if os.getenv('DB_TYPE') == 'postgresql':
        logger.info("⏭️  Skipping SQLite migrations (using PostgreSQL Cloud SQL)")
        return True  # Return success
    
    logger.info("🔧 Running database migrations...")
    
    # Ensure database and directory exist
    db_dir = os.path.dirname(DATABASE_PATH)
    if db_dir and not os.path.exists(db_dir):
        os.makedirs(db_dir, exist_ok=True)
        logger.info(f"Created database directory: {db_dir}")
    
    # Connect to database
    conn = sqlite3.connect(DATABASE_PATH)
    conn.execute("PRAGMA foreign_keys = ON")  # Enable foreign key constraints
    
    try:
        # Initialize migration tracking
        init_migration_tracking(conn)
        
        # Get all migration files
        migrations = get_migration_files()
        logger.info(f"Found {len(migrations)} migration files")
        
        # Run each migration
        applied_count = 0
        skipped_count = 0
        
        for migration_file in migrations:
            migration_name = migration_file.name
            
            if is_migration_applied(conn, migration_name):
                logger.info(f"⏭️  Skipping {migration_name} (already applied)")
                skipped_count += 1
                continue
            
            if run_migration(conn, migration_file):
                mark_migration_applied(conn, migration_name)
                applied_count += 1
            else:
                logger.error(f"Migration failed, stopping execution")
                return False
        
        logger.info(f"\n{'='*60}")
        logger.info(f"Migration Summary:")
        logger.info(f"  Applied: {applied_count}")
        logger.info(f"  Skipped: {skipped_count}")
        logger.info(f"  Total: {len(migrations)}")
        logger.info(f"{'='*60}\n")
        
        return True
        
    except Exception as e:
        logger.error(f"Migration runner failed: {e}")
        return False
    finally:
        conn.close()


if __name__ == "__main__":
    import sys
    success = run_all_migrations()
    sys.exit(0 if success else 1)
