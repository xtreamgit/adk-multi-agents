"""
API route modules.
"""

from .auth import router as auth_router
from .users import router as users_router
from .groups import router as groups_router
from .agents import router as agents_router
from .corpora import router as corpora_router
from .admin import router as admin_router

__all__ = [
    "auth_router",
    "users_router",
    "groups_router",
    "agents_router",
    "corpora_router",
    "admin_router",
]
