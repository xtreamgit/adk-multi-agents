"""
Add missing display_name and config_path columns to agents table.
This handles the case where the table exists but is missing these columns.
"""

import logging
from .connection import get_db_connection, DB_TYPE

logger = logging.getLogger(__name__)


def add_missing_agent_columns():
    """Add missing columns to agents table if they don't exist."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Check if display_name column exists
            if DB_TYPE == "postgresql":
                cursor.execute("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name='agents' AND column_name='display_name'
                """)
                has_display_name = cursor.fetchone() is not None
                
                cursor.execute("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name='agents' AND column_name='config_path'
                """)
                has_config_path = cursor.fetchone() is not None
            else:
                # SQLite
                cursor.execute("PRAGMA table_info(agents)")
                columns = [row[1] for row in cursor.fetchall()]
                has_display_name = 'display_name' in columns
                has_config_path = 'config_path' in columns
            
            # Add display_name if missing
            if not has_display_name:
                logger.info("Adding display_name column to agents table...")
                if DB_TYPE == "postgresql":
                    cursor.execute("ALTER TABLE agents ADD COLUMN display_name VARCHAR(255)")
                else:
                    cursor.execute("ALTER TABLE agents ADD COLUMN display_name TEXT")
                conn.commit()
                logger.info("✅ Added display_name column")
            
            # Add config_path if missing
            if not has_config_path:
                logger.info("Adding config_path column to agents table...")
                if DB_TYPE == "postgresql":
                    cursor.execute("ALTER TABLE agents ADD COLUMN config_path VARCHAR(255)")
                else:
                    cursor.execute("ALTER TABLE agents ADD COLUMN config_path TEXT")
                conn.commit()
                logger.info("✅ Added config_path column")
            
            if has_display_name and has_config_path:
                logger.debug("All agent columns already exist")
                
    except Exception as e:
        logger.warning(f"Could not add agent columns: {e}")
