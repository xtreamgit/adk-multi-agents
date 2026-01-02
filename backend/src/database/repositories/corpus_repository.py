"""
Corpus repository for database operations.
"""

import json
from typing import Optional, List, Dict
from datetime import datetime, timezone

from ..connection import get_db_connection


class CorpusRepository:
    """Repository for corpus-related database operations."""
    
    @staticmethod
    def get_by_id(corpus_id: int) -> Optional[Dict]:
        """Get corpus by ID."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM corpora WHERE id = ?", (corpus_id,))
            row = cursor.fetchone()
            return dict(row) if row else None
    
    @staticmethod
    def get_by_name(name: str) -> Optional[Dict]:
        """Get corpus by name."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM corpora WHERE name = ?", (name,))
            row = cursor.fetchone()
            return dict(row) if row else None
    
    @staticmethod
    def create(name: str, display_name: str, gcs_bucket: str,
              description: Optional[str] = None, vertex_corpus_id: Optional[str] = None) -> Dict:
        """Create a new corpus."""
        created_at = datetime.now(timezone.utc).isoformat()
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO corpora (name, display_name, description, gcs_bucket, 
                                    vertex_corpus_id, is_active, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (name, display_name, description, gcs_bucket, vertex_corpus_id, True, created_at))
            conn.commit()
            corpus_id = cursor.lastrowid
        
        return CorpusRepository.get_by_id(corpus_id)
    
    @staticmethod
    def get_all(active_only: bool = True) -> List[Dict]:
        """Get all corpora."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            if active_only:
                cursor.execute("SELECT * FROM corpora WHERE is_active = 1 ORDER BY display_name")
            else:
                cursor.execute("SELECT * FROM corpora ORDER BY display_name")
            return [dict(row) for row in cursor.fetchall()]
    
    @staticmethod
    def update(corpus_id: int, **kwargs) -> Optional[Dict]:
        """Update corpus fields."""
        if not kwargs:
            return CorpusRepository.get_by_id(corpus_id)
        
        set_clause = ", ".join([f"{key} = ?" for key in kwargs.keys()])
        values = list(kwargs.values()) + [corpus_id]
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f"UPDATE corpora SET {set_clause} WHERE id = ?", values)
            conn.commit()
        
        return CorpusRepository.get_by_id(corpus_id)
    
    # ========== Group-Corpus Access ==========
    
    @staticmethod
    def grant_group_access(group_id: int, corpus_id: int, permission: str = 'read') -> bool:
        """Grant group access to a corpus."""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO group_corpus_access (group_id, corpus_id, permission)
                    VALUES (?, ?, ?)
                """, (group_id, corpus_id, permission))
                conn.commit()
            return True
        except Exception:
            return False
    
    @staticmethod
    def revoke_group_access(group_id: int, corpus_id: int) -> bool:
        """Revoke group access to a corpus."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                DELETE FROM group_corpus_access WHERE group_id = ? AND corpus_id = ?
            """, (group_id, corpus_id))
            conn.commit()
            return cursor.rowcount > 0
    
    @staticmethod
    def get_user_corpora(user_id: int, active_only: bool = True) -> List[Dict]:
        """Get all corpora a user has access to (through their groups)."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            query = """
                SELECT DISTINCT c.*, gca.permission
                FROM corpora c
                JOIN group_corpus_access gca ON c.id = gca.corpus_id
                JOIN user_groups ug ON gca.group_id = ug.group_id
                WHERE ug.user_id = ?
            """
            if active_only:
                query += " AND c.is_active = 1"
            query += " ORDER BY c.display_name"
            
            cursor.execute(query, (user_id,))
            return [dict(row) for row in cursor.fetchall()]
    
    @staticmethod
    def check_user_access(user_id: int, corpus_id: int) -> Optional[str]:
        """
        Check if user has access to a corpus and return permission level.
        Returns permission string ('read', 'write', 'admin') or None.
        """
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT gca.permission
                FROM group_corpus_access gca
                JOIN user_groups ug ON gca.group_id = ug.group_id
                WHERE ug.user_id = ? AND gca.corpus_id = ?
                ORDER BY 
                    CASE gca.permission 
                        WHEN 'admin' THEN 1 
                        WHEN 'write' THEN 2 
                        WHEN 'read' THEN 3 
                    END
                LIMIT 1
            """, (user_id, corpus_id))
            row = cursor.fetchone()
            return row['permission'] if row else None
    
    # ========== Session Corpus Selections ==========
    
    @staticmethod
    def update_session_selection(user_id: int, corpus_id: int) -> bool:
        """Update or create session corpus selection."""
        last_selected_at = datetime.now(timezone.utc).isoformat()
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO session_corpus_selections (user_id, corpus_id, last_selected_at)
                VALUES (?, ?, ?)
                ON CONFLICT(user_id, corpus_id) 
                DO UPDATE SET last_selected_at = ?
            """, (user_id, corpus_id, last_selected_at, last_selected_at))
            conn.commit()
            return True
    
    @staticmethod
    def get_last_selected_corpora(user_id: int, limit: int = 10) -> List[int]:
        """Get last selected corpus IDs for a user."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT corpus_id FROM session_corpus_selections
                WHERE user_id = ?
                ORDER BY last_selected_at DESC
                LIMIT ?
            """, (user_id, limit))
            return [row['corpus_id'] for row in cursor.fetchall()]
