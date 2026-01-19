"""
Group and Role repository for database operations.
"""

import json
from typing import Optional, List, Dict
from datetime import datetime, timezone

from ..connection import get_db_connection


class GroupRepository:
    """Repository for group and role-related database operations."""
    
    # ========== Group Operations ==========
    
    @staticmethod
    def get_group_by_id(group_id: int) -> Optional[Dict]:
        """Get group by ID."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM groups WHERE id = ?", (group_id,))
            row = cursor.fetchone()
            return dict(row) if row else None
    
    @staticmethod
    def get_group_by_name(name: str) -> Optional[Dict]:
        """Get group by name."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM groups WHERE name = ?", (name,))
            row = cursor.fetchone()
            return dict(row) if row else None
    
    @staticmethod
    def create_group(name: str, description: Optional[str] = None) -> Dict:
        """Create a new group."""
        created_at = datetime.now(timezone.utc).isoformat()
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO groups (name, description, is_active, created_at)
                VALUES (?, ?, ?, ?)
            """, (name, description, True, created_at))
            conn.commit()
            group_id = cursor.lastrowid
        
        return GroupRepository.get_group_by_id(group_id)
    
    @staticmethod
    def update_group(group_id: int, **kwargs) -> Optional[Dict]:
        """Update group fields."""
        if not kwargs:
            return GroupRepository.get_group_by_id(group_id)
        
        set_clause = ", ".join([f"{key} = ?" for key in kwargs.keys()])
        values = list(kwargs.values()) + [group_id]
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f"UPDATE groups SET {set_clause} WHERE id = ?", values)
            conn.commit()
        
        return GroupRepository.get_group_by_id(group_id)
    
    @staticmethod
    def get_all_groups(active_only: bool = True) -> List[Dict]:
        """Get all groups."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            if active_only:
                cursor.execute("SELECT * FROM groups WHERE is_active = TRUE ORDER BY name")
            else:
                cursor.execute("SELECT * FROM groups ORDER BY name")
            return [dict(row) for row in cursor.fetchall()]
    
    @staticmethod
    def delete_group(group_id: int) -> bool:
        """Delete (deactivate) a group."""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("UPDATE groups SET is_active = FALSE WHERE id = ?", (group_id,))
                conn.commit()
                return cursor.rowcount > 0
        except Exception:
            return False
    
    @staticmethod
    def get_group_users(group_id: int) -> List[Dict]:
        """Get all users in a group."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT u.id, u.username, u.email, u.full_name, u.is_active, u.created_at
                FROM users u
                INNER JOIN user_groups ug ON u.id = ug.user_id
                WHERE ug.group_id = ?
                ORDER BY u.username
            """, (group_id,))
            return [dict(row) for row in cursor.fetchall()]
    
    # ========== Role Operations ==========
    
    @staticmethod
    def get_role_by_id(role_id: int) -> Optional[Dict]:
        """Get role by ID."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM roles WHERE id = ?", (role_id,))
            row = cursor.fetchone()
            if row:
                role = dict(row)
                # Parse JSON permissions - ensure it's always an array
                permissions_str = role.get('permissions')
                if permissions_str:
                    try:
                        role['permissions'] = json.loads(permissions_str)
                    except (json.JSONDecodeError, TypeError):
                        role['permissions'] = []
                else:
                    role['permissions'] = []
                return role
            return None
    
    @staticmethod
    def get_role_by_name(name: str) -> Optional[Dict]:
        """Get role by name."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM roles WHERE name = ?", (name,))
            row = cursor.fetchone()
            if row:
                role = dict(row)
                # Parse JSON permissions - ensure it's always an array
                permissions_str = role.get('permissions')
                if permissions_str:
                    try:
                        role['permissions'] = json.loads(permissions_str)
                    except (json.JSONDecodeError, TypeError):
                        role['permissions'] = []
                else:
                    role['permissions'] = []
                return role
            return None
    
    @staticmethod
    def create_role(name: str, description: Optional[str] = None, 
                   permissions: Optional[List[str]] = None) -> Dict:
        """Create a new role."""
        created_at = datetime.now(timezone.utc).isoformat()
        permissions_json = json.dumps(permissions) if permissions else None
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO roles (name, description, permissions, created_at)
                VALUES (?, ?, ?, ?)
            """, (name, description, permissions_json, created_at))
            conn.commit()
            role_id = cursor.lastrowid
        
        return GroupRepository.get_role_by_id(role_id)
    
    @staticmethod
    def get_all_roles() -> List[Dict]:
        """Get all roles."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM roles ORDER BY name")
            roles = []
            for row in cursor.fetchall():
                role = dict(row)
                # Parse JSON permissions - ensure it's always an array
                permissions_str = role.get('permissions')
                if permissions_str:
                    try:
                        role['permissions'] = json.loads(permissions_str)
                    except (json.JSONDecodeError, TypeError):
                        role['permissions'] = []
                else:
                    role['permissions'] = []
                roles.append(role)
            return roles
    
    # ========== Group-Role Associations ==========
    
    @staticmethod
    def assign_role_to_group(group_id: int, role_id: int) -> bool:
        """Assign a role to a group."""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO group_roles (group_id, role_id)
                    VALUES (?, ?)
                """, (group_id, role_id))
                conn.commit()
            return True
        except Exception:
            return False
    
    @staticmethod
    def remove_role_from_group(group_id: int, role_id: int) -> bool:
        """Remove a role from a group."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                DELETE FROM group_roles WHERE group_id = ? AND role_id = ?
            """, (group_id, role_id))
            conn.commit()
            return cursor.rowcount > 0
    
    @staticmethod
    def get_group_roles(group_id: int) -> List[Dict]:
        """Get all roles for a group."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT r.* FROM roles r
                JOIN group_roles gr ON r.id = gr.role_id
                WHERE gr.group_id = ?
            """, (group_id,))
            roles = []
            for row in cursor.fetchall():
                role = dict(row)
                if role.get('permissions'):
                    try:
                        role['permissions'] = json.loads(role['permissions'])
                    except (json.JSONDecodeError, TypeError):
                        role['permissions'] = []
                roles.append(role)
            return roles
    
    @staticmethod
    def get_user_roles(user_id: int) -> List[Dict]:
        """Get all roles for a user (through their groups)."""
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT DISTINCT r.* FROM roles r
                JOIN group_roles gr ON r.id = gr.role_id
                JOIN user_groups ug ON gr.group_id = ug.group_id
                WHERE ug.user_id = ?
            """, (user_id,))
            roles = []
            for row in cursor.fetchall():
                role = dict(row)
                if role.get('permissions'):
                    try:
                        role['permissions'] = json.loads(role['permissions'])
                    except (json.JSONDecodeError, TypeError):
                        role['permissions'] = []
                roles.append(role)
            return roles
