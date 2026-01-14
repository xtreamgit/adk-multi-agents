#!/usr/bin/env python3
"""Export all data from SQLite to JSON for migration."""
import sqlite3
import json
from datetime import datetime

DB_PATH = './data/users.db'
OUTPUT_PATH = './scripts/exported_data.json'

def export_table(cursor, table_name):
    """Export all rows from a table."""
    cursor.execute(f"SELECT * FROM {table_name}")
    columns = [description[0] for description in cursor.description]
    rows = cursor.fetchall()
    
    return {
        'columns': columns,
        'rows': [dict(zip(columns, row)) for row in rows]
    }

print("📂 Exporting SQLite data...")
print(f"Source: {DB_PATH}")
print(f"Output: {OUTPUT_PATH}")
print("-" * 60)

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

# Get all table names
cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
tables = [row[0] for row in cursor.fetchall()]

export_data = {
    'export_timestamp': datetime.utcnow().isoformat(),
    'source_database': 'SQLite',
    'database_path': DB_PATH,
    'tables': {}
}

total_rows = 0

for table_name in tables:
    print(f"Exporting {table_name}...", end=' ')
    export_data['tables'][table_name] = export_table(cursor, table_name)
    row_count = len(export_data['tables'][table_name]['rows'])
    total_rows += row_count
    print(f"✅ {row_count} rows")

with open(OUTPUT_PATH, 'w') as f:
    json.dump(export_data, f, indent=2, default=str)

conn.close()

# Summary
print("-" * 60)
print(f"✅ Data exported to {OUTPUT_PATH}")
print(f"\n📊 Export Summary:")
print(f"   Total tables: {len(export_data['tables'])}")
print(f"   Total rows: {total_rows}")
print(f"\nTable Details:")
for table, data in export_data['tables'].items():
    print(f"   {table:30} {len(data['rows']):5} rows")

# File size
import os
file_size = os.path.getsize(OUTPUT_PATH)
print(f"\n   Export file size: {file_size:,} bytes ({file_size/1024:.1f} KB)")
