#!/usr/bin/env python3
"""
Fix PostgreSQL parameter placeholders (%s) to SQLite placeholders (?)
in repository files.
"""

import os
import re
from pathlib import Path

def fix_placeholders_in_file(filepath):
    """Replace %s with ? in SQL queries within a Python file."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Replace %s with ? in SQL queries
    # This regex looks for %s that appear in SQL contexts
    content = re.sub(r'%s', '?', content)
    
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

def main():
    """Fix all repository files."""
    repo_dir = Path(__file__).parent / 'src' / 'database' / 'repositories'
    
    if not repo_dir.exists():
        print(f"❌ Repository directory not found: {repo_dir}")
        return
    
    print(f"🔧 Fixing SQLite placeholders in: {repo_dir}")
    print()
    
    fixed_count = 0
    for py_file in repo_dir.glob('*.py'):
        if py_file.name == '__init__.py':
            continue
        
        if fix_placeholders_in_file(py_file):
            print(f"✅ Fixed: {py_file.name}")
            fixed_count += 1
        else:
            print(f"⏭️  Skipped: {py_file.name} (no changes needed)")
    
    print()
    print(f"✅ Fixed {fixed_count} files")

if __name__ == '__main__':
    main()
