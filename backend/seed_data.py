#!/usr/bin/env python3
"""
seed_data.py - Seed users, groups, memberships, and group-corpus access
from an environment YAML configuration file.

This script reads the seed_data section from an environment YAML file
and populates the target database with:
  1. Users (with bcrypt-hashed passwords)
  2. Groups
  3. User-group memberships
  4. Group-corpus access (maps group names to corpus names)

Corpora must already exist in the database (via sync_corpora_from_vertex.py)
before running group_corpus_access seeding.

Usage:
    python seed_data.py --env ../environments/develom.yaml [OPTIONS]

Options:
    --env FILE          Path to environment YAML file (required)
    --target TARGET     Target database: 'local' (default) or 'cloud'
    --dry-run           Show what would be done without making changes
    --skip-users        Skip user seeding
    --skip-groups       Skip group seeding
    --skip-memberships  Skip membership seeding
    --skip-access       Skip group-corpus access seeding
    --verbose           Show detailed output
    --force             Overwrite existing records (update instead of skip)
"""

import argparse
import os
import sys
from datetime import datetime

import psycopg2
import psycopg2.extras
import yaml
from passlib.context import CryptContext

# Password hashing (same as auth_service.py)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

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
        # Cloud SQL via proxy on port 5434
        password = db_config.get("password", "")
        if not password:
            # Try to get from Secret Manager
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
            else:
                log_error("No cloud DB password configured. Set database.password or database.password_secret_name in YAML.")
                sys.exit(1)

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
    # Use RealDictCursor for dict-like row access
    return conn


# ─── Seed Functions ───────────────────────────────────────────────────────────

def seed_users(conn, users: list, dry_run: bool, force: bool, verbose: bool) -> dict:
    """
    Seed users into the database.
    Returns a dict mapping username → user_id.
    """
    log_section("Seeding Users")
    user_map = {}
    created = 0
    skipped = 0
    updated = 0

    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        for user_def in users:
            username = user_def["username"]
            email = user_def["email"]
            full_name = user_def.get("full_name", username)
            password = user_def.get("password", "changeme")
            auth_provider = user_def.get("auth_provider", "local")

            # Check if user already exists
            cur.execute("SELECT id, username, email FROM users WHERE username = %s OR email = %s",
                        (username, email))
            existing = cur.fetchone()

            if existing:
                user_map[username] = existing["id"]
                if force and not dry_run:
                    hashed = pwd_context.hash(password)
                    cur.execute("""
                        UPDATE users SET email = %s, full_name = %s, hashed_password = %s,
                               auth_provider = %s, is_active = TRUE, updated_at = %s
                        WHERE id = %s
                    """, (email, full_name, hashed, auth_provider, datetime.now(), existing["id"]))
                    updated += 1
                    log_success(f"Updated: {username} (id={existing['id']})")
                else:
                    skipped += 1
                    if verbose:
                        log_skip(f"Exists: {username} (id={existing['id']})")
            else:
                if dry_run:
                    log_info(f"[DRY RUN] Would create user: {username} ({email})")
                    created += 1
                else:
                    hashed = pwd_context.hash(password)
                    cur.execute("""
                        INSERT INTO users (username, email, full_name, hashed_password, auth_provider, is_active, created_at, updated_at)
                        VALUES (%s, %s, %s, %s, %s, TRUE, %s, %s)
                        RETURNING id
                    """, (username, email, full_name, hashed, auth_provider, datetime.now(), datetime.now()))
                    new_id = cur.fetchone()["id"]
                    user_map[username] = new_id
                    created += 1
                    log_success(f"Created: {username} (id={new_id})")

    print(f"\n  Summary: {created} created, {updated} updated, {skipped} skipped")
    return user_map


def seed_groups(conn, groups: list, dry_run: bool, force: bool, verbose: bool) -> dict:
    """
    Seed groups into the database.
    Returns a dict mapping group_name → group_id.
    """
    log_section("Seeding Groups")
    group_map = {}
    created = 0
    skipped = 0
    updated = 0

    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        for group_def in groups:
            name = group_def["name"]
            description = group_def.get("description", "")

            cur.execute("SELECT id, name FROM groups WHERE name = %s", (name,))
            existing = cur.fetchone()

            if existing:
                group_map[name] = existing["id"]
                if force and not dry_run:
                    cur.execute("UPDATE groups SET description = %s, is_active = TRUE WHERE id = %s",
                                (description, existing["id"]))
                    updated += 1
                    log_success(f"Updated: {name} (id={existing['id']})")
                else:
                    skipped += 1
                    if verbose:
                        log_skip(f"Exists: {name} (id={existing['id']})")
            else:
                if dry_run:
                    log_info(f"[DRY RUN] Would create group: {name}")
                    created += 1
                else:
                    cur.execute("""
                        INSERT INTO groups (name, description, is_active, created_at)
                        VALUES (%s, %s, TRUE, %s)
                        RETURNING id
                    """, (name, description, datetime.now()))
                    new_id = cur.fetchone()["id"]
                    group_map[name] = new_id
                    created += 1
                    log_success(f"Created: {name} (id={new_id})")

    print(f"\n  Summary: {created} created, {updated} updated, {skipped} skipped")
    return group_map


def seed_memberships(conn, memberships: dict, user_map: dict, group_map: dict,
                     dry_run: bool, verbose: bool):
    """Seed user-group memberships."""
    log_section("Seeding User-Group Memberships")
    created = 0
    skipped = 0
    errors = 0

    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        for username, group_names in memberships.items():
            user_id = user_map.get(username)
            if not user_id:
                # Try to look up the user by username
                cur.execute("SELECT id FROM users WHERE username = %s", (username,))
                row = cur.fetchone()
                if row:
                    user_id = row["id"]
                else:
                    log_warning(f"User '{username}' not found — skipping memberships")
                    errors += 1
                    continue

            for group_name in group_names:
                group_id = group_map.get(group_name)
                if not group_id:
                    cur.execute("SELECT id FROM groups WHERE name = %s", (group_name,))
                    row = cur.fetchone()
                    if row:
                        group_id = row["id"]
                    else:
                        log_warning(f"Group '{group_name}' not found — skipping")
                        errors += 1
                        continue

                # Check if membership exists
                cur.execute("SELECT 1 FROM user_groups WHERE user_id = %s AND group_id = %s",
                            (user_id, group_id))
                if cur.fetchone():
                    skipped += 1
                    if verbose:
                        log_skip(f"{username} ↔ {group_name}")
                    continue

                if dry_run:
                    log_info(f"[DRY RUN] Would add: {username} → {group_name}")
                    created += 1
                else:
                    cur.execute("""
                        INSERT INTO user_groups (user_id, group_id, joined_at)
                        VALUES (%s, %s, %s)
                    """, (user_id, group_id, datetime.now()))
                    created += 1
                    log_success(f"{username} → {group_name}")

    print(f"\n  Summary: {created} created, {skipped} skipped, {errors} errors")


def seed_group_corpus_access(conn, access_config: dict, group_map: dict,
                             dry_run: bool, force: bool, verbose: bool):
    """Seed group-corpus access permissions."""
    log_section("Seeding Group-Corpus Access")
    created = 0
    skipped = 0
    updated = 0
    errors = 0

    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        # Build corpus name → id map from database
        cur.execute("SELECT id, name FROM corpora WHERE is_active = TRUE")
        corpus_map = {row["name"]: row["id"] for row in cur.fetchall()}

        if not corpus_map:
            log_warning("No active corpora found in database.")
            log_info("Run sync_corpora_from_vertex.py first to populate corpora from Vertex AI.")
            return

        if verbose:
            log_info(f"Active corpora in DB: {list(corpus_map.keys())}")

        for group_name, corpus_entries in access_config.items():
            group_id = group_map.get(group_name)
            if not group_id:
                cur.execute("SELECT id FROM groups WHERE name = %s", (group_name,))
                row = cur.fetchone()
                if row:
                    group_id = row["id"]
                else:
                    log_warning(f"Group '{group_name}' not found — skipping")
                    errors += 1
                    continue

            for entry in corpus_entries:
                corpus_name = entry["corpus"]
                permission = entry.get("permission", "read")

                corpus_id = corpus_map.get(corpus_name)
                if not corpus_id:
                    log_warning(f"Corpus '{corpus_name}' not found in DB — skipping")
                    errors += 1
                    continue

                # Check if access already exists
                cur.execute("""
                    SELECT id, permission FROM group_corpus_access
                    WHERE group_id = %s AND corpus_id = %s
                """, (group_id, corpus_id))
                existing = cur.fetchone()

                if existing:
                    if force and existing["permission"] != permission and not dry_run:
                        cur.execute("""
                            UPDATE group_corpus_access SET permission = %s WHERE id = %s
                        """, (permission, existing["id"]))
                        updated += 1
                        log_success(f"Updated: {group_name} → {corpus_name} ({existing['permission']} → {permission})")
                    else:
                        skipped += 1
                        if verbose:
                            log_skip(f"{group_name} → {corpus_name} ({existing['permission']})")
                else:
                    if dry_run:
                        log_info(f"[DRY RUN] Would grant: {group_name} → {corpus_name} ({permission})")
                        created += 1
                    else:
                        cur.execute("""
                            INSERT INTO group_corpus_access (group_id, corpus_id, permission, granted_at)
                            VALUES (%s, %s, %s, %s)
                        """, (group_id, corpus_id, permission, datetime.now()))
                        created += 1
                        log_success(f"{group_name} → {corpus_name} ({permission})")

    print(f"\n  Summary: {created} created, {updated} updated, {skipped} skipped, {errors} errors")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Seed users, groups, memberships, and group-corpus access from environment YAML."
    )
    parser.add_argument("--env", required=True, help="Path to environment YAML file")
    parser.add_argument("--target", choices=["local", "cloud"], default="local",
                        help="Target database (default: local)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done")
    parser.add_argument("--skip-users", action="store_true", help="Skip user seeding")
    parser.add_argument("--skip-groups", action="store_true", help="Skip group seeding")
    parser.add_argument("--skip-memberships", action="store_true", help="Skip membership seeding")
    parser.add_argument("--skip-access", action="store_true", help="Skip group-corpus access seeding")
    parser.add_argument("--verbose", action="store_true", help="Show detailed output")
    parser.add_argument("--force", action="store_true",
                        help="Update existing records instead of skipping")

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
        # 1. Seed groups first (users may reference them, but groups have no FK deps)
        group_map = {}
        if not args.skip_groups:
            groups = seed_config.get("groups", [])
            if groups:
                group_map = seed_groups(conn, groups, args.dry_run, args.force, args.verbose)
            else:
                log_warning("No groups defined in seed_data")

        # 2. Seed users
        user_map = {}
        if not args.skip_users:
            users = seed_config.get("users", [])
            if users:
                user_map = seed_users(conn, users, args.dry_run, args.force, args.verbose)
            else:
                log_warning("No users defined in seed_data")

        # 3. Seed memberships
        if not args.skip_memberships:
            memberships = seed_config.get("memberships", {})
            if memberships:
                seed_memberships(conn, memberships, user_map, group_map, args.dry_run, args.verbose)
            else:
                log_warning("No memberships defined in seed_data")

        # 4. Seed group-corpus access
        if not args.skip_access:
            access = seed_config.get("group_corpus_access", {})
            if access:
                seed_group_corpus_access(conn, access, group_map, args.dry_run, args.force, args.verbose)
            else:
                log_warning("No group_corpus_access defined in seed_data")

        # Commit
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
