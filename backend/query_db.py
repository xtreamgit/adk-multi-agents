#!/usr/bin/env python3
"""
Query SQLite database to show current users, groups, and corpora.
"""
import sqlite3
import os
import json

# Determine database path (same logic as connection.py)
if os.environ.get('K_SERVICE'):  # Running in Cloud Run
    DB_PATH = '/app/data/users.db'
else:  # Running locally
    DB_PATH = './data/users.db'

print(f"Using database: {DB_PATH}")
print("=" * 60)

try:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # Return rows as dictionaries
    cursor = conn.cursor()
    
    # Query Users
    print("\n📊 USERS:")
    print("-" * 60)
    cursor.execute("SELECT id, username, email, full_name, is_active, created_at FROM users")
    users = cursor.fetchall()
    if users:
        for user in users:
            print(f"  ID: {user['id']}")
            print(f"  Username: {user['username']}")
            print(f"  Email: {user['email']}")
            print(f"  Full Name: {user['full_name']}")
            print(f"  Active: {user['is_active']}")
            print(f"  Created: {user['created_at']}")
            print()
    else:
        print("  No users found")
    
    # Query Groups
    print("\n👥 GROUPS:")
    print("-" * 60)
    cursor.execute("SELECT id, name, description, created_at FROM groups")
    groups = cursor.fetchall()
    if groups:
        for group in groups:
            print(f"  ID: {group['id']}")
            print(f"  Name: {group['name']}")
            print(f"  Description: {group['description']}")
            print(f"  Created: {group['created_at']}")
            
            # Get users in this group
            cursor.execute("""
                SELECT u.username 
                FROM users u 
                JOIN user_groups ug ON u.id = ug.user_id 
                WHERE ug.group_id = ?
            """, (group['id'],))
            group_users = cursor.fetchall()
            if group_users:
                print(f"  Members: {', '.join([u['username'] for u in group_users])}")
            print()
    else:
        print("  No groups found")
    
    # Query Corpora
    print("\n📚 CORPORA:")
    print("-" * 60)
    cursor.execute("""
        SELECT id, name, vertex_corpus_id, description, is_active, created_at 
        FROM corpora
    """)
    corpora = cursor.fetchall()
    if corpora:
        for corpus in corpora:
            print(f"  ID: {corpus['id']}")
            print(f"  Name: {corpus['name']}")
            print(f"  Vertex Corpus ID: {corpus['vertex_corpus_id']}")
            print(f"  Description: {corpus['description']}")
            print(f"  Active: {corpus['is_active']}")
            print(f"  Created: {corpus['created_at']}")
            print()
    else:
        print("  No corpora found")
    
    # Summary
    print("\n" + "=" * 60)
    print(f"📊 SUMMARY:")
    print(f"  Total Users: {len(users)}")
    print(f"  Total Groups: {len(groups)}")
    print(f"  Total Corpora: {len(corpora)}")
    print("=" * 60)
    
    conn.close()
    
except sqlite3.Error as e:
    print(f"❌ Database error: {e}")
except Exception as e:
    print(f"❌ Error: {e}")
