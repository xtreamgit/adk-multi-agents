"""
Database connection management with PostgreSQL and SQLite support.
"""

import os
import sqlite3
import logging
from contextlib import contextmanager
from typing import Generator, Any

logger = logging.getLogger(__name__)

# Determine database type from environment
DB_TYPE = os.getenv("DB_TYPE", "sqlite")  # 'sqlite' or 'postgresql'

# SQLite configuration
if os.path.exists("/app/data"):
    DEFAULT_SQLITE_PATH = "/app/data/users.db"
else:
    DEFAULT_SQLITE_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data", "users.db")

DATABASE_PATH = os.getenv("DATABASE_PATH", DEFAULT_SQLITE_PATH)

# PostgreSQL configuration (for Cloud SQL)
PG_CONFIG = {
    'host': os.getenv('DB_HOST', '/cloudsql/' + os.getenv('CLOUD_SQL_CONNECTION_NAME', '')),
    'port': int(os.getenv('DB_PORT', '5432')),
    'database': os.getenv('DB_NAME', 'adk_agents_db'),
    'user': os.getenv('DB_USER', 'adk_app_user'),
    'password': os.getenv('DB_PASSWORD', ''),
}

# PostgreSQL connection pool
_pg_pool = None


def _get_pg_pool():
    """Get or create PostgreSQL connection pool."""
    global _pg_pool
    if _pg_pool is None:
        import psycopg2.pool
        _pg_pool = psycopg2.pool.SimpleConnectionPool(
            minconn=1,
            maxconn=10,
            **PG_CONFIG
        )
        logger.info("PostgreSQL connection pool initialized")
    return _pg_pool


def init_database():
    """Initialize the database (PostgreSQL or SQLite based on DB_TYPE)."""
    try:
        if DB_TYPE == 'postgresql':
            # Test PostgreSQL connection
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                logger.info(f"✅ PostgreSQL connection successful: {PG_CONFIG['database']} @ {PG_CONFIG['host']}")
                logger.info(f"✅ Using Cloud SQL PostgreSQL database")
        else:
            # SQLite: Ensure directory exists and create file
            db_dir = os.path.dirname(DATABASE_PATH)
            if db_dir and not os.path.exists(db_dir):
                os.makedirs(db_dir, exist_ok=True)
                logger.info(f"Created database directory: {db_dir}")
            
            # Create database file if it doesn't exist
            with get_db_connection() as conn:
                conn.execute("PRAGMA foreign_keys = ON")
                logger.info(f"SQLite database initialized at {DATABASE_PATH}")
            
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise


class PostgreSQLCursorWrapper:
    """Wrapper for PostgreSQL cursor that converts SQLite ? to %s and results to dicts."""
    def __init__(self, cursor):
        self._cursor = cursor
    
    def execute(self, query, params=()):
        # Convert SQLite ? placeholders to PostgreSQL %s
        converted_query = query.replace('?', '%s')
        return self._cursor.execute(converted_query, params)
    
    def executemany(self, query, params_list):
        converted_query = query.replace('?', '%s')
        return self._cursor.executemany(converted_query, params_list)
    
    def _row_to_dict(self, row):
        """Convert PostgreSQL tuple result to dictionary."""
        if row is None:
            return None
        if self._cursor.description is None:
            return row
        columns = [desc[0] for desc in self._cursor.description]
        return dict(zip(columns, row))
    
    def fetchone(self):
        row = self._cursor.fetchone()
        return self._row_to_dict(row)
    
    def fetchall(self):
        rows = self._cursor.fetchall()
        if not rows or self._cursor.description is None:
            return rows
        columns = [desc[0] for desc in self._cursor.description]
        return [dict(zip(columns, row)) for row in rows]
    
    def fetchmany(self, size=None):
        rows = self._cursor.fetchmany(size)
        if not rows or self._cursor.description is None:
            return rows
        columns = [desc[0] for desc in self._cursor.description]
        return [dict(zip(columns, row)) for row in rows]
    
    @property
    def rowcount(self):
        return self._cursor.rowcount
    
    @property
    def lastrowid(self):
        return self._cursor.lastrowid
    
    @property
    def description(self):
        return self._cursor.description
    
    def close(self):
        return self._cursor.close()
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


class PostgreSQLConnectionWrapper:
    """Wrapper for PostgreSQL connection that returns wrapped cursors."""
    def __init__(self, conn):
        self._conn = conn
    
    def cursor(self):
        return PostgreSQLCursorWrapper(self._conn.cursor())
    
    def commit(self):
        return self._conn.commit()
    
    def rollback(self):
        return self._conn.rollback()
    
    def close(self):
        return self._conn.close()
    
    @property
    def autocommit(self):
        return self._conn.autocommit
    
    @autocommit.setter
    def autocommit(self, value):
        self._conn.autocommit = value


@contextmanager
def get_db_connection() -> Generator[Any, None, None]:
    """
    Context manager for database connections.
    Returns SQLite or PostgreSQL connection based on DB_TYPE.
    
    Usage:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users")
    """
    if DB_TYPE == 'postgresql':
        import psycopg2
        import psycopg2.extras
        
        pool = _get_pg_pool()
        conn = pool.getconn()
        conn.autocommit = False
        
        # Wrap connection to handle query conversion
        wrapped_conn = PostgreSQLConnectionWrapper(conn)
        
        try:
            yield wrapped_conn
        finally:
            pool.putconn(conn)
    else:
        conn = sqlite3.connect(DATABASE_PATH)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        
        try:
            yield conn
        finally:
            conn.close()


def execute_query(query: str, params: tuple = ()) -> list:
    """
    Execute a SELECT query and return results.
    Works with both SQLite and PostgreSQL.
    
    Args:
        query: SQL query string
        params: Query parameters (optional)
        
    Returns:
        List of rows as dictionaries
    """
    # Convert query for PostgreSQL (? to %s)
    if DB_TYPE == 'postgresql':
        query = query.replace('?', '%s')
    
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        
        if DB_TYPE == 'postgresql':
            columns = [desc[0] for desc in cursor.description] if cursor.description else []
            rows = cursor.fetchall()
            return [dict(zip(columns, row)) for row in rows]
        else:
            rows = cursor.fetchall()
            return [dict(row) for row in rows]


def execute_insert(query: str, params: tuple = ()) -> int:
    """
    Execute an INSERT query and return the last inserted row ID.
    Works with both SQLite and PostgreSQL.
    
    Args:
        query: SQL INSERT query string
        params: Query parameters (optional)
        
    Returns:
        Last inserted row ID
    """
    if DB_TYPE == 'postgresql':
        # PostgreSQL uses RETURNING id
        query = query.replace('?', '%s')
        if 'RETURNING' not in query.upper():
            query = query.rstrip(';') + ' RETURNING id'
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            result = cursor.fetchone()
            conn.commit()
            return result[0] if result else None
    else:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            conn.commit()
            return cursor.lastrowid


def execute_update(query: str, params: tuple = ()) -> int:
    """
    Execute an UPDATE or DELETE query and return affected rows count.
    Works with both SQLite and PostgreSQL.
    
    Args:
        query: SQL UPDATE/DELETE query string
        params: Query parameters (optional)
        
    Returns:
        Number of affected rows
    """
    # Convert query for PostgreSQL (? to %s)
    if DB_TYPE == 'postgresql':
        query = query.replace('?', '%s')
    
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        conn.commit()
        return cursor.rowcount


def close_pool():
    """Close PostgreSQL connection pool (call on shutdown)."""
    global _pg_pool
    if _pg_pool is not None:
        _pg_pool.closeall()
        _pg_pool = None
        logger.info("PostgreSQL connection pool closed")
