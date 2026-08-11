"""
Pytest configuration and global fixtures.
"""

import sys
import os
from pathlib import Path
from dotenv import load_dotenv

# Ensure backend/src is in Python path before any imports occur
backend_dir = Path(__file__).parent.parent
src_dir = backend_dir / "src"
if str(src_dir) not in sys.path:
    sys.path.insert(0, str(src_dir))

# Force load environment variables from .env.local on startup
env_path = backend_dir / ".env.local"
if env_path.exists():
    load_dotenv(dotenv_path=env_path, override=True)
    print(f"✅ [conftest] Loaded environment variables from {env_path}")
else:
    print(f"⚠️ [conftest] .env.local not found at {env_path}")
