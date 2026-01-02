"""
Database connection management.
"""

import os
import sqlite3
import logging
from contextlib import contextmanager
from typing import Generator

logger = logging.getLogger(__name__)

# Use local path for development, Cloud Run path in production
# Check if /app/data exists (Cloud Run), otherwise use local ./data
if os.path.exists("/app/data"):
    DEFAULT_DB_PATH = "/app/data/users.db"
else:
    # Local development - use ./data relative to backend directory
    DEFAULT_DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data", "users.db")

DATABASE_PATH = os.getenv("DATABASE_PATH", DEFAULT_DB_PATH)


def init_database():
    """Initialize the SQLite database and ensure it exists."""
    try:
        # Ensure the directory exists
        db_dir = os.path.dirname(DATABASE_PATH)
        if db_dir and not os.path.exists(db_dir):
            os.makedirs(db_dir, exist_ok=True)
            logger.info(f"Created database directory: {db_dir}")
        
        # Create database file if it doesn't exist
        with get_db_connection() as conn:
            conn.execute("PRAGMA foreign_keys = ON")
            logger.info(f"Database initialized at {DATABASE_PATH}")
            
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise


@contextmanager
def get_db_connection() -> Generator[sqlite3.Connection, None, None]:
    """
    Context manager for database connections.
    
    Usage:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users")
    """
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row  # Enable dict-like access to rows
    conn.execute("PRAGMA foreign_keys = ON")  # Enable foreign key constraints
    
    try:
        yield conn
    finally:
        conn.close()


def execute_query(query: str, params: tuple = ()) -> list:
    """
    Execute a SELECT query and return results.
    
    Args:
        query: SQL query string
        params: Query parameters (optional)
        
    Returns:
        List of rows as dictionaries
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        rows = cursor.fetchall()
        return [dict(row) for row in rows]


def execute_insert(query: str, params: tuple = ()) -> int:
    """
    Execute an INSERT query and return the last inserted row ID.
    
    Args:
        query: SQL INSERT query string
        params: Query parameters (optional)
        
    Returns:
        Last inserted row ID
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        conn.commit()
        return cursor.lastrowid


def execute_update(query: str, params: tuple = ()) -> int:
    """
    Execute an UPDATE or DELETE query and return affected rows count.
    
    Args:
        query: SQL UPDATE/DELETE query string
        params: Query parameters (optional)
        
    Returns:
        Number of affected rows
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        conn.commit()
        return cursor.rowcount
