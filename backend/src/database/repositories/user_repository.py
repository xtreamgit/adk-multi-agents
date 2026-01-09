"""
User repository for database operations.
"""

import json
from typing import Optional, List, Dict
from datetime import datetime, timezone

from ..connection import get_db_connection


class UserRepository:
    """Repository for user-related database operations."""
    
    @staticmethod
    def get_by_id(user_id: int) -> Optional[Dict]:
        """Get user by ID."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
            row = cursor.fetchone()
            return dict(row) if row else None
    
    @staticmethod
    def get_by_username(username: str) -> Optional[Dict]:
        """Get user by username."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
            row = cursor.fetchone()
            return dict(row) if row else None
    
    @staticmethod
    def get_by_email(email: str) -> Optional[Dict]:
        """Get user by email."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
            row = cursor.fetchone()
            return dict(row) if row else None
    
    @staticmethod
    def create(username: str, email: str, full_name: str, hashed_password: str) -> Dict:
        """Create a new user."""
        created_at = datetime.now(timezone.utc).isoformat()
        updated_at = created_at
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO users (username, email, full_name, hashed_password, 
                                   is_active, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (username, email, full_name, hashed_password, True, created_at, updated_at))
            conn.commit()
            user_id = cursor.lastrowid
        
        return UserRepository.get_by_id(user_id)
    
    @staticmethod
    def update(user_id: int, **kwargs) -> Optional[Dict]:
        """Update user fields."""
        if not kwargs:
            return UserRepository.get_by_id(user_id)
        
        # Add updated_at timestamp
        kwargs['updated_at'] = datetime.now(timezone.utc).isoformat()
        
        # Build UPDATE query
        set_clause = ", ".join([f"{key} = ?" for key in kwargs.keys()])
        values = list(kwargs.values()) + [user_id]
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f"UPDATE users SET {set_clause} WHERE id = ?", values)
            conn.commit()
        
        return UserRepository.get_by_id(user_id)
    
    @staticmethod
    def update_last_login(user_id: int) -> None:
        """Update the last login timestamp."""
        last_login = datetime.now(timezone.utc).isoformat()
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("UPDATE users SET last_login = ? WHERE id = ?", (last_login, user_id))
            conn.commit()
    
    @staticmethod
    def exists(username: str) -> bool:
        """Check if a user exists."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1 FROM users WHERE username = ? LIMIT 1", (username,))
            return cursor.fetchone() is not None
    
    @staticmethod
    def get_profile(user_id: int) -> Optional[Dict]:
        """Get user profile."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM user_profiles WHERE user_id = ?", (user_id,))
            row = cursor.fetchone()
            if row:
                profile = dict(row)
                # Parse JSON preferences
                if profile.get('preferences'):
                    try:
                        profile['preferences'] = json.loads(profile['preferences'])
                    except (json.JSONDecodeError, TypeError):
                        profile['preferences'] = {}
                return profile
            return None
    
    @staticmethod
    def create_profile(user_id: int, theme: str = 'light', language: str = 'en', 
                       timezone: str = 'UTC', preferences: Optional[Dict] = None) -> Dict:
        """Create user profile."""
        preferences_json = json.dumps(preferences) if preferences else None
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO user_profiles (user_id, theme, language, timezone, preferences)
                VALUES (?, ?, ?, ?, ?)
            """, (user_id, theme, language, timezone, preferences_json))
            conn.commit()
        
        return UserRepository.get_profile(user_id)
    
    @staticmethod
    def update_profile(user_id: int, **kwargs) -> Optional[Dict]:
        """Update user profile."""
        if not kwargs:
            return UserRepository.get_profile(user_id)
        
        # Convert preferences dict to JSON string
        if 'preferences' in kwargs and kwargs['preferences'] is not None:
            kwargs['preferences'] = json.dumps(kwargs['preferences'])
        
        # Build UPDATE query
        set_clause = ", ".join([f"{key} = ?" for key in kwargs.keys()])
        values = list(kwargs.values()) + [user_id]
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f"UPDATE user_profiles SET {set_clause} WHERE user_id = ?", values)
            conn.commit()
        
        return UserRepository.get_profile(user_id)
    
    @staticmethod
    def get_groups(user_id: int) -> List[int]:
        """Get group IDs for a user."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT group_id FROM user_groups WHERE user_id = ?", (user_id,))
            return [row['group_id'] for row in cursor.fetchall()]
    
    @staticmethod
    def add_to_group(user_id: int, group_id: int) -> bool:
        """Add user to a group."""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO user_groups (user_id, group_id)
                    VALUES (?, ?)
                """, (user_id, group_id))
                conn.commit()
            return True
        except Exception:
            return False
    
    @staticmethod
    def remove_from_group(user_id: int, group_id: int) -> bool:
        """Remove user from a group."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                DELETE FROM user_groups WHERE user_id = ? AND group_id = ?
            """, (user_id, group_id))
            conn.commit()
            return cursor.rowcount > 0
    
    @staticmethod
    def get_all() -> List[Dict]:
        """Get all users."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users ORDER BY created_at DESC")
            return [dict(row) for row in cursor.fetchall()]
    
    @staticmethod
    def update_password(user_id: int, hashed_password: str) -> bool:
        """Update user password."""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE users SET hashed_password = ?, updated_at = ? WHERE id = ?
                """, (hashed_password, datetime.now(timezone.utc).isoformat(), user_id))
                conn.commit()
            return True
        except Exception:
            return False
