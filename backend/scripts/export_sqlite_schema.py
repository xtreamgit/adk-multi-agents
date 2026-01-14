#!/usr/bin/env python3
"""Export SQLite schema to PostgreSQL-compatible SQL."""
import sqlite3
import os

DB_PATH = './data/users.db'
OUTPUT_PATH = './scripts/exported_schema.sql'

print("📂 Exporting SQLite schema...")
print(f"Source: {DB_PATH}")
print(f"Output: {OUTPUT_PATH}")
print("-" * 60)

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

# Get all table schemas
cursor.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
tables = cursor.fetchall()

with open(OUTPUT_PATH, 'w') as f:
    f.write("-- Exported from SQLite on " + __import__('datetime').datetime.now().isoformat() + "\n")
    f.write("-- Convert to PostgreSQL syntax\n")
    f.write("-- Note: This is for reference only. Use migration scripts for actual schema.\n\n")
    
    for table_name, table_sql in tables:
        f.write(f"-- Table: {table_name}\n")
        f.write(table_sql + ";\n\n")
        
        # Get indexes for this table
        cursor.execute(f"SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=? AND sql IS NOT NULL", (table_name,))
        indexes = cursor.fetchall()
        for (index_sql,) in indexes:
            f.write(index_sql + ";\n")
        f.write("\n")

conn.close()

print(f"✅ Schema exported to {OUTPUT_PATH}")
print(f"   Tables exported: {len(tables)}")
for table_name, _ in tables:
    print(f"   - {table_name}")
