#!/usr/bin/env python3
"""
seed_data.py — Bootstrap deployment defaults from an environment YAML file.

Reads the seed_data section from an environment YAML and populates the
target database with the chatbot system defaults:

  1. chatbot_groups       — access tiers (viewer, contributor, content-manager, admin)
  2. chatbot_agents       — one agent per tier with cumulative tool sets
  3. chatbot_group_agents — 1:1 group → agent assignments
  4. google_group_agent_mappings  — Google Group → chatbot group (agent type dimension)
  5. google_group_corpus_mappings — Google Group → corpus + permission (corpus access)
  6. users + chatbot_users        — initial admin user(s) for IAP-based auth

Corpora are NOT seeded here — they come from Vertex AI via CorpusSyncService
on application startup. Corpus mappings (step 5) reference corpora by name
and are resolved at seed time.

Usage:
    python seed_data.py --env ../environments/develom.yaml [OPTIONS]

Options:
    --env FILE       Path to environment YAML file (required)
    --target TARGET  Target database: 'local' (default) or 'cloud'
    --dry-run        Show what would be done without making changes
    --force          Update existing records instead of skipping
    --verbose        Show detailed output
"""

import argparse
import json
import os
import sys
from datetime import datetime

import psycopg2
import psycopg2.extras
import yaml

# ─── Colors ───────────────────────────────────────────────────────────────────

GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
NC = "\033[0m"


def log_info(msg):
    print(f"  {msg}")


def log_success(msg):
    print(f"  {GREEN}✅ {msg}{NC}")


def log_warning(msg):
    print(f"  {YELLOW}⚠️  {msg}{NC}")


def log_error(msg):
    print(f"  {RED}❌ {msg}{NC}")


def log_skip(msg):
    print(f"  ⏭️  {msg}")


def log_section(title):
    print(f"\n{CYAN}{BOLD}{'─' * 60}{NC}")
    print(f"{CYAN}{BOLD}  {title}{NC}")
    print(f"{CYAN}{BOLD}{'─' * 60}{NC}\n")


# ─── Database Connection ──────────────────────────────────────────────────────

def get_connection(config: dict, target: str) -> psycopg2.extensions.connection:
    """Create a database connection based on target (local or cloud)."""
    db_config = config.get("database", {})

    if target == "local":
        local = db_config.get("local", {})
        conn = psycopg2.connect(
            host=local.get("host", "localhost"),
            port=local.get("port", 5433),
            dbname=local.get("name", "adk_agents_db_dev"),
            user=local.get("user", "adk_dev_user"),
            password=local.get("password", "dev_password_123"),
        )
    elif target == "cloud":
        password = os.getenv("DB_PASSWORD", "") or db_config.get("password", "")
        if not password:
            password_secret = db_config.get("password_secret_name", "")
            if password_secret:
                try:
                    from google.cloud import secretmanager
                    client = secretmanager.SecretManagerServiceClient()
                    project_id = config.get("project_id", "")
                    name = f"projects/{project_id}/secrets/{password_secret}/versions/latest"
                    response = client.access_secret_version(request={"name": name})
                    password = response.payload.data.decode("UTF-8")
                except Exception as e:
                    log_error(f"Failed to get password from Secret Manager: {e}")
                    sys.exit(1)
        if not password:
            import getpass
            password = getpass.getpass(f"  Enter password for {db_config.get('user', 'adk_app_user')}@cloud: ")

        conn = psycopg2.connect(
            host="127.0.0.1",
            port=5434,
            dbname=db_config.get("name", "adk_agents_db"),
            user=db_config.get("user", "adk_app_user"),
            password=password,
        )
    else:
        log_error(f"Unknown target: {target}")
        sys.exit(1)

    conn.autocommit = False
    return conn


# ─── Seed Functions ───────────────────────────────────────────────────────────

def seed_chatbot_groups(cur, groups: list, dry_run: bool, force: bool, verbose: bool) -> dict:
    """
    Seed chatbot_groups.
    Returns dict mapping group_name → group_id.
    """
    log_section("Seeding Chatbot Groups")
    group_map = {}
    created = 0
    skipped = 0
    updated = 0

    for group_def in groups:
        name = group_def["name"]
        description = group_def.get("description", "")

        cur.execute("SELECT id, name, description FROM chatbot_groups WHERE name = %s", (name,))
        existing = cur.fetchone()

        if existing:
            group_map[name] = existing["id"]
            if force and not dry_run and existing["description"] != description:
                cur.execute(
                    "UPDATE chatbot_groups SET description = %s, is_active = TRUE, updated_at = CURRENT_TIMESTAMP WHERE id = %s",
                    (description, existing["id"]),
                )
                updated += 1
                log_success(f"Updated: {name} (id={existing['id']})")
            else:
                skipped += 1
                if verbose:
                    log_skip(f"Exists: {name} (id={existing['id']})")
        else:
            if dry_run:
                log_info(f"[DRY RUN] Would create chatbot_group: {name}")
                created += 1
            else:
                cur.execute(
                    "INSERT INTO chatbot_groups (name, description, is_active) VALUES (%s, %s, TRUE) RETURNING id",
                    (name, description),
                )
                new_id = cur.fetchone()["id"]
                group_map[name] = new_id
                created += 1
                log_success(f"Created: {name} (id={new_id})")

    print(f"\n  Summary: {created} created, {updated} updated, {skipped} skipped")
    return group_map


def seed_chatbot_agents(cur, agents: list, dry_run: bool, force: bool, verbose: bool) -> dict:
    """
    Seed chatbot_agents.
    Returns dict mapping agent_name → agent_id.
    """
    log_section("Seeding Chatbot Agents")
    agent_map = {}
    created = 0
    skipped = 0
    updated = 0

    for agent_def in agents:
        name = agent_def["name"]
        display_name = agent_def.get("display_name", name)
        agent_type = agent_def.get("agent_type", "viewer")
        description = agent_def.get("description", "")
        tools = agent_def.get("tools", [])
        tools_json = json.dumps(tools)

        cur.execute("SELECT id, name FROM chatbot_agents WHERE name = %s", (name,))
        existing = cur.fetchone()

        if existing:
            agent_map[name] = existing["id"]
            if force and not dry_run:
                cur.execute(
                    """UPDATE chatbot_agents
                       SET display_name = %s, agent_type = %s, description = %s,
                           tools = %s, is_active = TRUE, updated_at = CURRENT_TIMESTAMP
                       WHERE id = %s""",
                    (display_name, agent_type, description, tools_json, existing["id"]),
                )
                updated += 1
                log_success(f"Updated: {name} (id={existing['id']})")
            else:
                skipped += 1
                if verbose:
                    log_skip(f"Exists: {name} (id={existing['id']})")
        else:
            if dry_run:
                log_info(f"[DRY RUN] Would create chatbot_agent: {name} ({agent_type})")
                created += 1
            else:
                cur.execute(
                    """INSERT INTO chatbot_agents (name, display_name, agent_type, description, tools, is_active)
                       VALUES (%s, %s, %s, %s, %s, TRUE) RETURNING id""",
                    (name, display_name, agent_type, description, tools_json),
                )
                new_id = cur.fetchone()["id"]
                agent_map[name] = new_id
                created += 1
                log_success(f"Created: {name} (id={new_id})")

    print(f"\n  Summary: {created} created, {updated} updated, {skipped} skipped")
    return agent_map


def seed_group_agent_assignments(cur, assignments: dict, group_map: dict, agent_map: dict,
                                  dry_run: bool, verbose: bool):
    """Seed chatbot_group_agents (group → agent 1:1 mapping)."""
    log_section("Seeding Group → Agent Assignments")
    created = 0
    skipped = 0
    errors = 0

    for group_name, agent_name in assignments.items():
        group_id = group_map.get(group_name)
        agent_id = agent_map.get(agent_name)

        if not group_id:
            log_warning(f"Group '{group_name}' not found — skipping")
            errors += 1
            continue
        if not agent_id:
            log_warning(f"Agent '{agent_name}' not found — skipping")
            errors += 1
            continue

        cur.execute(
            "SELECT id FROM chatbot_group_agents WHERE group_id = %s AND agent_id = %s",
            (group_id, agent_id),
        )
        if cur.fetchone():
            skipped += 1
            if verbose:
                log_skip(f"{group_name} → {agent_name}")
            continue

        if dry_run:
            log_info(f"[DRY RUN] Would assign: {group_name} → {agent_name}")
            created += 1
        else:
            cur.execute(
                "INSERT INTO chatbot_group_agents (group_id, agent_id) VALUES (%s, %s)",
                (group_id, agent_id),
            )
            created += 1
            log_success(f"{group_name} → {agent_name}")

    print(f"\n  Summary: {created} created, {skipped} skipped, {errors} errors")


def seed_google_group_agent_mappings(cur, mappings: list, group_map: dict,
                                     dry_run: bool, force: bool, verbose: bool):
    """Seed google_group_agent_mappings (Google Group → chatbot group)."""
    log_section("Seeding Google Group → Agent Mappings")
    created = 0
    skipped = 0
    updated = 0
    errors = 0

    for mapping in mappings:
        email = mapping["google_group_email"]
        group_name = mapping["chatbot_group"]
        priority = mapping.get("priority", 0)

        group_id = group_map.get(group_name)
        if not group_id:
            log_warning(f"Group '{group_name}' not found — skipping mapping for {email}")
            errors += 1
            continue

        cur.execute(
            "SELECT id, chatbot_group_id, priority FROM google_group_agent_mappings WHERE google_group_email = %s",
            (email,),
        )
        existing = cur.fetchone()

        if existing:
            if force and not dry_run and (existing["chatbot_group_id"] != group_id or existing["priority"] != priority):
                cur.execute(
                    "UPDATE google_group_agent_mappings SET chatbot_group_id = %s, priority = %s, is_active = TRUE WHERE id = %s",
                    (group_id, priority, existing["id"]),
                )
                updated += 1
                log_success(f"Updated: {email} → {group_name} (priority={priority})")
            else:
                skipped += 1
                if verbose:
                    log_skip(f"{email} → {group_name} (priority={priority})")
        else:
            if dry_run:
                log_info(f"[DRY RUN] Would map: {email} → {group_name} (priority={priority})")
                created += 1
            else:
                cur.execute(
                    """INSERT INTO google_group_agent_mappings
                       (google_group_email, chatbot_group_id, priority, is_active)
                       VALUES (%s, %s, %s, TRUE)""",
                    (email, group_id, priority),
                )
                created += 1
                log_success(f"{email} → {group_name} (priority={priority})")

    print(f"\n  Summary: {created} created, {updated} updated, {skipped} skipped, {errors} errors")


def seed_google_group_corpus_mappings(cur, mappings: list,
                                      dry_run: bool, force: bool, verbose: bool):
    """Seed google_group_corpus_mappings (Google Group → corpus + permission)."""
    log_section("Seeding Google Group → Corpus Mappings")
    created = 0
    skipped = 0
    updated = 0
    errors = 0

    # Build corpus name → id map
    cur.execute("SELECT id, name FROM corpora WHERE is_active = TRUE")
    corpus_map = {row["name"]: row["id"] for row in cur.fetchall()}

    if not corpus_map:
        log_warning("No active corpora found in database.")
        log_info("Corpus mappings will be skipped. Run Vertex AI sync first, then re-seed.")
        return

    if verbose:
        log_info(f"Active corpora in DB: {list(corpus_map.keys())}")

    for mapping in mappings:
        email = mapping["google_group_email"]
        corpus_name = mapping["corpus_name"]
        permission = mapping.get("permission", "read")

        corpus_id = corpus_map.get(corpus_name)
        if not corpus_id:
            log_warning(f"Corpus '{corpus_name}' not found in DB — skipping mapping for {email}")
            errors += 1
            continue

        cur.execute(
            "SELECT id, corpus_id, permission FROM google_group_corpus_mappings WHERE google_group_email = %s AND corpus_id = %s",
            (email, corpus_id),
        )
        existing = cur.fetchone()

        if existing:
            if force and not dry_run and existing["permission"] != permission:
                cur.execute(
                    "UPDATE google_group_corpus_mappings SET permission = %s, is_active = TRUE WHERE id = %s",
                    (permission, existing["id"]),
                )
                updated += 1
                log_success(f"Updated: {email} → {corpus_name} ({existing['permission']} → {permission})")
            else:
                skipped += 1
                if verbose:
                    log_skip(f"{email} → {corpus_name} ({permission})")
        else:
            if dry_run:
                log_info(f"[DRY RUN] Would map: {email} → {corpus_name} ({permission})")
                created += 1
            else:
                cur.execute(
                    """INSERT INTO google_group_corpus_mappings
                       (google_group_email, corpus_id, permission, is_active)
                       VALUES (%s, %s, %s, TRUE)""",
                    (email, corpus_id, permission),
                )
                created += 1
                log_success(f"{email} → {corpus_name} ({permission})")

    print(f"\n  Summary: {created} created, {updated} updated, {skipped} skipped, {errors} errors")


def seed_users(cur, users: list, group_map: dict,
               dry_run: bool, force: bool, verbose: bool):
    """
    Seed initial users into users + chatbot_users tables.
    If is_admin is true, also assigns the user to admin-group.
    """
    log_section("Seeding Users")
    created = 0
    skipped = 0
    updated = 0

    for user_def in users:
        email = user_def["email"]
        full_name = user_def.get("full_name", email.split("@")[0])
        username = email.split("@")[0]
        is_admin = user_def.get("is_admin", False)

        # 1. Ensure users table record
        cur.execute("SELECT id, email FROM users WHERE email = %s", (email,))
        existing_user = cur.fetchone()

        if existing_user:
            user_id = existing_user["id"]
            if force and not dry_run:
                cur.execute(
                    "UPDATE users SET full_name = %s, is_active = TRUE, updated_at = CURRENT_TIMESTAMP WHERE id = %s",
                    (full_name, user_id),
                )
                updated += 1
                log_success(f"Updated user: {email} (id={user_id})")
            else:
                skipped += 1
                if verbose:
                    log_skip(f"User exists: {email} (id={user_id})")
        else:
            if dry_run:
                log_info(f"[DRY RUN] Would create user: {email}")
                created += 1
                continue
            else:
                cur.execute(
                    """INSERT INTO users (username, email, full_name, auth_provider, is_active, created_at, updated_at)
                       VALUES (%s, %s, %s, 'iap', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                       RETURNING id""",
                    (username, email, full_name),
                )
                user_id = cur.fetchone()["id"]
                created += 1
                log_success(f"Created user: {email} (id={user_id})")

        if dry_run:
            continue

        # 2. Ensure chatbot_users record linked to users.id
        cur.execute("SELECT id FROM chatbot_users WHERE user_id = %s", (user_id,))
        existing_cu = cur.fetchone()
        if not existing_cu:
            cur.execute(
                """INSERT INTO chatbot_users (username, email, full_name, user_id, is_active)
                   VALUES (%s, %s, %s, %s, TRUE)
                   ON CONFLICT (email) DO UPDATE SET user_id = EXCLUDED.user_id
                   RETURNING id""",
                (username, email, full_name, user_id),
            )
            chatbot_user_id = cur.fetchone()["id"]
            log_success(f"  Created chatbot_user for {email} (id={chatbot_user_id})")
        else:
            chatbot_user_id = existing_cu["id"]

        # 3. If admin, assign to admin-group
        if is_admin:
            admin_group_id = group_map.get("admin-group")
            if admin_group_id:
                cur.execute(
                    "INSERT INTO chatbot_user_groups (chatbot_user_id, chatbot_group_id) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                    (chatbot_user_id, admin_group_id),
                )
                log_success(f"  Assigned {email} → admin-group")
            else:
                log_warning(f"  admin-group not found — cannot assign {email}")

    print(f"\n  Summary: {created} created, {updated} updated, {skipped} skipped")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Bootstrap deployment defaults from an environment YAML file."
    )
    parser.add_argument("--env", required=True, help="Path to environment YAML file")
    parser.add_argument("--target", choices=["local", "cloud"], default="local",
                        help="Target database (default: local)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done")
    parser.add_argument("--force", action="store_true",
                        help="Update existing records instead of skipping")
    parser.add_argument("--verbose", action="store_true", help="Show detailed output")

    args = parser.parse_args()

    # Load YAML config
    env_path = os.path.abspath(args.env)
    if not os.path.exists(env_path):
        log_error(f"Environment file not found: {env_path}")
        sys.exit(1)

    with open(env_path, "r") as f:
        config = yaml.safe_load(f)

    seed_config = config.get("seed_data")
    if not seed_config:
        log_error(f"No 'seed_data' section found in {env_path}")
        sys.exit(1)

    client_name = config.get("client_name", "unknown")

    # Header
    print(f"\n{BOLD}{'=' * 60}{NC}")
    print(f"{BOLD}  Seed Data — {client_name} ({args.target}){NC}")
    print(f"{BOLD}{'=' * 60}{NC}")
    if args.dry_run:
        print(f"\n  {YELLOW}🔍 DRY RUN MODE — no changes will be made{NC}")
    if args.force:
        print(f"  {YELLOW}⚡ FORCE MODE — existing records will be updated{NC}")

    # Connect
    log_section(f"Connecting to {args.target} database")
    try:
        conn = get_connection(config, args.target)
        log_success(f"Connected to {args.target} database")
    except Exception as e:
        log_error(f"Failed to connect: {e}")
        sys.exit(1)

    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        # 1. Chatbot groups
        group_map = {}
        chatbot_groups = seed_config.get("chatbot_groups", [])
        if chatbot_groups:
            group_map = seed_chatbot_groups(cur, chatbot_groups, args.dry_run, args.force, args.verbose)
        else:
            log_warning("No chatbot_groups defined in seed_data")

        # 2. Chatbot agents
        agent_map = {}
        chatbot_agents = seed_config.get("chatbot_agents", [])
        if chatbot_agents:
            agent_map = seed_chatbot_agents(cur, chatbot_agents, args.dry_run, args.force, args.verbose)
        else:
            log_warning("No chatbot_agents defined in seed_data")

        # 3. Group → Agent assignments
        group_agents = seed_config.get("chatbot_group_agents", {})
        if group_agents:
            seed_group_agent_assignments(cur, group_agents, group_map, agent_map, args.dry_run, args.verbose)
        else:
            log_warning("No chatbot_group_agents defined in seed_data")

        # 4. Google Group → Agent mappings
        gg_agent_mappings = seed_config.get("google_group_agent_mappings", [])
        if gg_agent_mappings:
            seed_google_group_agent_mappings(cur, gg_agent_mappings, group_map, args.dry_run, args.force, args.verbose)
        else:
            log_warning("No google_group_agent_mappings defined in seed_data")

        # 5. Google Group → Corpus mappings
        gg_corpus_mappings = seed_config.get("google_group_corpus_mappings", [])
        if gg_corpus_mappings:
            seed_google_group_corpus_mappings(cur, gg_corpus_mappings, args.dry_run, args.force, args.verbose)
        else:
            log_warning("No google_group_corpus_mappings defined in seed_data")

        # 6. Users
        users = seed_config.get("users", [])
        if users:
            seed_users(cur, users, group_map, args.dry_run, args.force, args.verbose)
        else:
            log_warning("No users defined in seed_data")

        # Commit or rollback
        if not args.dry_run:
            conn.commit()
            log_section("Complete")
            log_success("All changes committed successfully")
        else:
            conn.rollback()
            log_section("Complete")
            log_info("Dry run complete — no changes were made")

    except Exception as e:
        conn.rollback()
        log_error(f"Error during seeding: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        conn.close()

    print()


if __name__ == "__main__":
    main()
