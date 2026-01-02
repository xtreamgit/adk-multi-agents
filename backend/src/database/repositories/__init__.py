"""
Repository pattern for data access.
"""

from .user_repository import UserRepository
from .group_repository import GroupRepository
from .agent_repository import AgentRepository
from .corpus_repository import CorpusRepository

__all__ = [
    "UserRepository",
    "GroupRepository",
    "AgentRepository",
    "CorpusRepository",
]
