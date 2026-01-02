#!/usr/bin/env python3
"""
Seed script to populate initial agents in the database.
"""

import sys
import os
import logging

# Add backend/src to path
backend_src = os.path.join(os.path.dirname(__file__), '..', 'src')
sys.path.insert(0, backend_src)

# Import after path setup
from database.migrations.run_migrations import main as run_migrations
from services.agent_service import AgentService
from models.agent import AgentCreate

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Agent configurations based on existing backend/config structure
AGENTS = [
    {
        "name": "default-agent",
        "display_name": "Default Agent",
        "config_path": "develom",
        "description": "Default general-purpose RAG agent"
    },
    {
        "name": "agent1",
        "display_name": "Agent 1",
        "config_path": "agent1",
        "description": "Specialized agent 1"
    },
    {
        "name": "agent2",
        "display_name": "Agent 2",
        "config_path": "agent2",
        "description": "Specialized agent 2"
    },
    {
        "name": "agent3",
        "display_name": "Agent 3",
        "config_path": "agent3",
        "description": "Specialized agent 3"
    },
    {
        "name": "tt-agent",
        "display_name": "TT Agent",
        "config_path": "tt",
        "description": "TT specialized agent"
    },
    {
        "name": "usfs-agent",
        "display_name": "USFS Agent",
        "config_path": "usfs",
        "description": "USFS specialized agent"
    }
]


def seed_agents():
    """Seed initial agents into the database."""
    logger.info("Starting agent seeding...")
    
    # Run migrations first
    logger.info("Running database migrations...")
    run_migrations()
    
    created_count = 0
    skipped_count = 0
    
    for agent_data in AGENTS:
        try:
            # Check if agent already exists
            existing = AgentService.get_agent_by_name(agent_data["name"])
            if existing:
                logger.info(f"⏭️  Agent '{agent_data['name']}' already exists (ID: {existing.id})")
                skipped_count += 1
                continue
            
            # Create agent
            agent_create = AgentCreate(**agent_data)
            agent = AgentService.create_agent(agent_create)
            logger.info(f"✅ Created agent: {agent.name} (ID: {agent.id})")
            created_count += 1
            
        except Exception as e:
            logger.error(f"❌ Failed to create agent '{agent_data['name']}': {e}")
    
    logger.info(f"\n{'='*60}")
    logger.info(f"Agent Seeding Summary:")
    logger.info(f"  Created: {created_count}")
    logger.info(f"  Skipped: {skipped_count}")
    logger.info(f"  Total: {len(AGENTS)}")
    logger.info(f"{'='*60}\n")


if __name__ == "__main__":
    seed_agents()
