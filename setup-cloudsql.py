#!/usr/bin/env python3
"""
Cloud SQL Setup Script for ADK RAG Agent
=========================================
Automates Phase 1 of database deployment:

  1. Create Cloud SQL PostgreSQL instance
  2. Create the application database
  3. Create the application user
  4. Store the password in Secret Manager
  5. Grant Cloud Run service accounts access to the secret

Usage:
  python setup-cloudsql.py                          # interactive, reads environments/usfs.yaml
  python setup-cloudsql.py --env environments/usfs.yaml --dry-run
  python setup-cloudsql.py --skip-existing
  python setup-cloudsql.py --force                  # delete & recreate existing resources

Reads configuration from an environment YAML file (same format used by
backend/deploy_env_config.py). Prompts for any missing values interactively.
"""

import argparse
import getpass
import logging
import os
import subprocess
import sys
import time
from typing import List, Optional, Tuple

import yaml

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)
logger = logging.getLogger("setup_cloudsql")

# ---------------------------------------------------------------------------
# ANSI colours (matching deploy_env_config.py / pre-deploy-check.sh)
# ---------------------------------------------------------------------------
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
CYAN = "\033[0;36m"
MAGENTA = "\033[0;35m"
BOLD = "\033[1m"
NC = "\033[0m"


def c_green(t):
    return f"{GREEN}{t}{NC}"


def c_yellow(t):
    return f"{YELLOW}{t}{NC}"


def c_red(t):
    return f"{RED}{t}{NC}"


def c_blue(t):
    return f"{BLUE}{t}{NC}"


def c_cyan(t):
    return f"{CYAN}{t}{NC}"


def c_bold(t):
    return f"{BOLD}{t}{NC}"


# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DEFAULT_ENV_FILE = "environments/usfs.yaml"
DEFAULT_TIER = "db-f1-micro"
DEFAULT_DB_VERSION = "POSTGRES_15"
DEFAULT_STORAGE_SIZE = "10"
DEFAULT_SECRET_NAME = "db-password"
INSTANCE_READY_TIMEOUT = 1200  # seconds (20 min — instance creation can take 5-15+ min)


# ---------------------------------------------------------------------------
# Deployment Tracker
# ---------------------------------------------------------------------------
class DeploymentTracker:
    """Track created / skipped / failed resources for the final summary."""

    def __init__(self):
        self.created: List[str] = []
        self.skipped: List[str] = []
        self.failed: List[str] = []

    def add_created(self, resource: str):
        self.created.append(resource)

    def add_skipped(self, resource: str):
        self.skipped.append(resource)

    def add_failed(self, resource: str):
        self.failed.append(resource)

    def print_summary(self):
        logger.info(f"\n{CYAN}{'=' * 64}{NC}")
        logger.info(f"  {c_bold('DEPLOYMENT SUMMARY')}")
        logger.info(f"{CYAN}{'=' * 64}{NC}")

        if self.created:
            logger.info(f"\n  {c_green('CREATED')} ({len(self.created)}):")
            for r in self.created:
                logger.info(f"    {GREEN}+{NC} {r}")

        if self.skipped:
            logger.info(f"\n  {c_yellow('SKIPPED')} ({len(self.skipped)}):")
            for r in self.skipped:
                logger.info(f"    {YELLOW}-{NC} {r}")

        if self.failed:
            logger.info(f"\n  {c_red('FAILED')} ({len(self.failed)}):")
            for r in self.failed:
                logger.info(f"    {RED}x{NC} {r}")

        logger.info(f"\n{CYAN}{'=' * 64}{NC}")

        if self.failed:
            logger.info(f"  {c_red('RESULT: Completed with errors.  Review failures above.')}")
            return False
        elif self.skipped and not self.created:
            logger.info(f"  {c_yellow('RESULT: All resources already exist.  Nothing created.')}")
            return True
        else:
            logger.info(f"  {c_green('RESULT: Phase 1 completed successfully!')}")
            return True


# ---------------------------------------------------------------------------
# Helpers — run gcloud
# ---------------------------------------------------------------------------
def run_gcloud(
    args: List[str],
    *,
    stdin_data: Optional[str] = None,
    timeout: int = 300,
    quiet: bool = False,
) -> Tuple[int, str, str]:
    """Run a gcloud command and return (returncode, stdout, stderr)."""

    cmd = ["gcloud"] + args
    if not quiet:
        logger.info(f"  {BLUE}${NC} gcloud {' '.join(args)}")

    try:
        result = subprocess.run(
            cmd,
            input=stdin_data,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return 1, "", "Command timed out"
    except FileNotFoundError:
        return 127, "", "gcloud CLI not found. Install: https://cloud.google.com/sdk/docs/install"


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------
def find_project_root() -> str:
    """Walk up from this script to find the repo root (has infrastructure/)."""
    current = os.path.dirname(os.path.abspath(__file__))
    for _ in range(5):
        if os.path.isdir(os.path.join(current, "infrastructure")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    return os.path.dirname(os.path.abspath(__file__))


def load_env_config(env_path: str) -> dict:
    """Load the environment YAML file."""
    abs_path = os.path.abspath(env_path)
    if not os.path.exists(abs_path):
        logger.error(f"  {c_red('x')} Environment file not found: {abs_path}")
        sys.exit(1)

    with open(abs_path, "r") as f:
        config = yaml.safe_load(f)

    logger.info(f"  {c_green('ok')} Loaded config from {abs_path}")
    return config


def extract_db_config(config: dict) -> dict:
    """Pull the database-relevant fields out of the YAML config."""
    db = config.get("database", {})
    return {
        "project_id": config.get("project_id", ""),
        "region": config.get("region", ""),
        "instance_name": db.get("cloud_sql_instance", ""),
        "connection_name": db.get("cloud_sql_connection", ""),
        "database_name": db.get("name", ""),
        "user_name": db.get("user", ""),
        "password": db.get("password", ""),
        # NOTE: in the current usfs.yaml this field holds the actual password
        "password_secret_value": db.get("password_secret_name", ""),
    }


# ---------------------------------------------------------------------------
# Validate & prompt for missing values
# ---------------------------------------------------------------------------
def validate_config(cfg: dict, no_interactive: bool) -> dict:
    """Ensure every required value is present; prompt if missing."""

    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Validating configuration')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    fields = [
        ("project_id", "GCP Project ID"),
        ("region", "GCP Region"),
        ("instance_name", "Cloud SQL instance name"),
        ("database_name", "Database name"),
        ("user_name", "Database user"),
    ]

    for key, label in fields:
        if cfg[key]:
            logger.info(f"  {c_green('ok')} {label}: {c_cyan(cfg[key])}")
        else:
            if no_interactive:
                logger.error(f"  {c_red('x')} {label} is missing and --no-interactive is set.")
                sys.exit(1)
            cfg[key] = input(f"  {c_yellow('?')}  Enter {label}: ").strip()
            if not cfg[key]:
                logger.error(f"  {c_red('x')} {label} cannot be empty.")
                sys.exit(1)

    # --- Password resolution ---------------------------------------------------
    password = cfg["password"]
    secret_value = cfg["password_secret_value"]

    if password:
        cfg["actual_password"] = password
        logger.info(f"  {c_green('ok')} Password: {c_cyan('(from database.password field)')}")
    elif secret_value:
        cfg["actual_password"] = secret_value
        logger.info(
            f"  {c_green('ok')} Password: {c_cyan('(from database.password_secret_name field)')}"
        )
    else:
        if no_interactive:
            logger.error(f"  {c_red('x')} No password found in config and --no-interactive is set.")
            sys.exit(1)
        logger.info(f"  {c_yellow('!')} No password found in config.")
        cfg["actual_password"] = getpass.getpass(f"  {c_yellow('?')}  Enter database password: ")
        if not cfg["actual_password"]:
            logger.error(f"  {c_red('x')} Password cannot be empty.")
            sys.exit(1)

    return cfg


def print_config_summary(cfg: dict, secret_name: str, tier: str):
    logger.info(f"\n{CYAN}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Configuration Summary')}")
    logger.info(f"{CYAN}{'_' * 64}{NC}")
    logger.info(f"  Project ID       : {c_blue(cfg['project_id'])}")
    logger.info(f"  Region           : {cfg['region']}")
    logger.info(f"  Instance         : {cfg['instance_name']}")
    logger.info(f"  Database         : {cfg['database_name']}")
    logger.info(f"  User             : {cfg['user_name']}")
    logger.info(f"  Password         : {c_green('****** (set)')}")
    logger.info(f"  Secret name      : {secret_name}")
    logger.info(f"  Tier             : {tier}")
    logger.info(f"  Connection       : {cfg.get('connection_name', 'N/A')}")
    logger.info(f"{CYAN}{'_' * 64}{NC}\n")


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------
def check_gcloud_auth() -> Tuple[bool, str]:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Checking gcloud authentication')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    rc, stdout, stderr = run_gcloud(["--version"], quiet=True)
    if rc != 0:
        logger.error(f"  {c_red('x')} gcloud CLI not found.")
        logger.error(f"  Install: https://cloud.google.com/sdk/docs/install")
        return False, ""

    rc, stdout, stderr = run_gcloud(
        ["auth", "list", "--filter=status=ACTIVE", "--format=value(account)"], quiet=True
    )
    if rc != 0 or not stdout:
        logger.error(f"  {c_red('x')} Not authenticated with gcloud.")
        logger.error(f"  Run: gcloud auth login")
        return False, ""

    account = stdout.split("\n")[0]
    logger.info(f"  {c_green('ok')} Authenticated as: {c_cyan(account)}")
    return True, account


def set_gcloud_project(project_id: str) -> bool:
    logger.info(f"  Setting active project to {c_cyan(project_id)} ...")
    rc, _, stderr = run_gcloud(["config", "set", "project", project_id], quiet=True)
    if rc == 0:
        logger.info(f"  {c_green('ok')} Active project set.")
        return True
    logger.error(f"  {c_red('x')} Failed to set project: {stderr}")
    return False


def get_project_number(project_id: str) -> Optional[str]:
    """Fetch the numeric project number (needed for compute SA)."""
    rc, stdout, _ = run_gcloud(
        ["projects", "describe", project_id, "--format=value(projectNumber)"], quiet=True
    )
    return stdout if rc == 0 else None


# ---------------------------------------------------------------------------
# Resource existence checks
# ---------------------------------------------------------------------------
def instance_exists(project_id: str, name: str) -> Tuple[bool, str]:
    """Return (exists, state)."""
    logger.info(f"  Checking instance '{name}' ...")
    rc, stdout, _ = run_gcloud(
        ["sql", "instances", "describe", name, "--project", project_id, "--format=value(state)"],
        quiet=True,
    )
    if rc == 0:
        state = stdout or "UNKNOWN"
        logger.info(f"    {c_yellow('!')} Instance exists  (state: {state})")
        return True, state
    logger.info(f"    {c_green('ok')} Instance does not exist.")
    return False, ""


def database_exists(project_id: str, instance: str, db_name: str) -> bool:
    logger.info(f"  Checking database '{db_name}' ...")
    rc, _, _ = run_gcloud(
        ["sql", "databases", "describe", db_name, "--instance", instance, "--project", project_id],
        quiet=True,
    )
    if rc == 0:
        logger.info(f"    {c_yellow('!')} Database exists.")
        return True
    logger.info(f"    {c_green('ok')} Database does not exist.")
    return False


def user_exists(project_id: str, instance: str, user_name: str) -> bool:
    logger.info(f"  Checking user '{user_name}' ...")
    rc, stdout, _ = run_gcloud(
        ["sql", "users", "list", "--instance", instance, "--project", project_id,
         "--format=value(name)"],
        quiet=True,
    )
    if rc != 0:
        logger.info(f"    {c_yellow('!')} Could not list users (instance may not exist yet).")
        return False
    users = [u.strip() for u in stdout.split("\n") if u.strip()]
    if user_name in users:
        logger.info(f"    {c_yellow('!')} User exists.")
        return True
    logger.info(f"    {c_green('ok')} User does not exist.")
    return False


def secret_exists(project_id: str, secret_name: str) -> bool:
    logger.info(f"  Checking secret '{secret_name}' ...")
    rc, _, _ = run_gcloud(
        ["secrets", "describe", secret_name, "--project", project_id], quiet=True
    )
    if rc == 0:
        logger.info(f"    {c_yellow('!')} Secret exists.")
        return True
    logger.info(f"    {c_green('ok')} Secret does not exist.")
    return False


# ---------------------------------------------------------------------------
# Delete helpers (for --force / overwrite)
# ---------------------------------------------------------------------------
def delete_instance(project_id: str, name: str) -> bool:
    logger.info(f"  {c_yellow('!')} Deleting instance '{name}' ...")
    logger.info(f"  (This may take several minutes)")
    rc, _, stderr = run_gcloud(
        ["sql", "instances", "delete", name, "--project", project_id, "--quiet"],
        timeout=900,
    )
    if rc == 0:
        logger.info(f"  {c_green('ok')} Instance deleted.")
        return True
    logger.error(f"  {c_red('x')} Failed to delete instance: {stderr}")
    return False


def delete_database(project_id: str, instance: str, db_name: str) -> bool:
    logger.info(f"  {c_yellow('!')} Deleting database '{db_name}' ...")
    rc, _, stderr = run_gcloud(
        ["sql", "databases", "delete", db_name, "--instance", instance,
         "--project", project_id, "--quiet"],
    )
    if rc == 0:
        logger.info(f"  {c_green('ok')} Database deleted.")
        return True
    logger.error(f"  {c_red('x')} Failed to delete database: {stderr}")
    return False


def delete_user(project_id: str, instance: str, user_name: str) -> bool:
    logger.info(f"  {c_yellow('!')} Deleting user '{user_name}' ...")
    rc, _, stderr = run_gcloud(
        ["sql", "users", "delete", user_name, "--instance", instance,
         "--project", project_id, "--quiet"],
    )
    if rc == 0:
        logger.info(f"  {c_green('ok')} User deleted.")
        return True
    logger.error(f"  {c_red('x')} Failed to delete user: {stderr}")
    return False


def delete_secret(project_id: str, secret_name: str) -> bool:
    logger.info(f"  {c_yellow('!')} Deleting secret '{secret_name}' ...")
    rc, _, stderr = run_gcloud(
        ["secrets", "delete", secret_name, "--project", project_id, "--quiet"],
    )
    if rc == 0:
        logger.info(f"  {c_green('ok')} Secret deleted.")
        return True
    logger.error(f"  {c_red('x')} Failed to delete secret: {stderr}")
    return False


# ---------------------------------------------------------------------------
# Create functions
# ---------------------------------------------------------------------------
def wait_for_instance(project_id: str, name: str) -> bool:
    """Poll until the instance reaches RUNNABLE or timeout."""
    start = time.time()
    logger.info(f"  Polling every 30s for up to {INSTANCE_READY_TIMEOUT // 60} min ...")
    while time.time() - start < INSTANCE_READY_TIMEOUT:
        rc, stdout, _ = run_gcloud(
            ["sql", "instances", "describe", name, "--project", project_id,
             "--format=value(state)"],
            quiet=True,
        )
        elapsed = int(time.time() - start)
        if rc == 0 and stdout == "RUNNABLE":
            logger.info(f"  {c_green('ok')} Instance is RUNNABLE.  ({elapsed}s total)")
            return True
        # rc != 0 means the instance isn't visible in the API yet (normal
        # for the first 30-60s after an --async create).
        state_label = stdout if rc == 0 else "NOT_VISIBLE_YET"
        logger.info(f"    {state_label} ... ({elapsed}s elapsed)")
        time.sleep(30)
    logger.error(f"  {c_red('x')} Timed out after {INSTANCE_READY_TIMEOUT}s waiting for RUNNABLE.")
    logger.error(f"  The instance may still be provisioning.  Check manually:")
    logger.error(f"    gcloud sql instances describe {name} "
                 f"--project {project_id} --format='value(state)'")
    return False


def create_instance(
    project_id: str, name: str, region: str, tier: str, dry_run: bool
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 1/5  -  Create Cloud SQL Instance')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")
    logger.info(f"  Instance   : {name}")
    logger.info(f"  Region     : {region}")
    logger.info(f"  Tier       : {tier}")
    logger.info(f"  Engine     : {DEFAULT_DB_VERSION}")
    logger.info(f"  Storage    : {DEFAULT_STORAGE_SIZE} GB SSD\n")

    cmd = [
        "sql", "instances", "create", name,
        "--project", project_id,
        "--region", region,
        "--tier", tier,
        "--database-version", DEFAULT_DB_VERSION,
        "--storage-size", DEFAULT_STORAGE_SIZE,
        "--storage-type", "SSD",
        "--database-flags", "max_connections=100",
        "--async",      # return immediately — we poll separately
        "--quiet",
    ]

    if dry_run:
        logger.info(f"  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    gcloud {' '.join(cmd)}")
        return True

    logger.info(f"  Submitting instance creation (async) ...")
    logger.info(f"  The instance will provision in the background.  Polling for readiness ...")
    rc, stdout, stderr = run_gcloud(cmd, timeout=120)
    if rc != 0:
        logger.error(f"\n  {c_red('x')} Failed to submit instance creation.")
        logger.error(f"  Error: {stderr}")
        return False

    logger.info(f"  {c_green('ok')} Create operation submitted.")
    logger.info(f"  Waiting for instance to become RUNNABLE (up to ~15 min) ...")
    return wait_for_instance(project_id, name)


def create_database(
    project_id: str, instance: str, db_name: str, dry_run: bool
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 2/5  -  Create Database')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")
    logger.info(f"  Database : {db_name}")
    logger.info(f"  Instance : {instance}\n")

    cmd = [
        "sql", "databases", "create", db_name,
        "--instance", instance,
        "--project", project_id,
    ]

    if dry_run:
        logger.info(f"  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    gcloud {' '.join(cmd)}")
        return True

    rc, _, stderr = run_gcloud(cmd)
    if rc != 0:
        logger.error(f"\n  {c_red('x')} Failed to create database.")
        logger.error(f"  Error: {stderr}")
        return False

    logger.info(f"  {c_green('ok')} Database '{db_name}' created.")
    return True


def create_user(
    project_id: str, instance: str, user_name: str, password: str, dry_run: bool
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 3/5  -  Create Database User')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")
    logger.info(f"  User     : {user_name}")
    logger.info(f"  Instance : {instance}\n")

    cmd = [
        "sql", "users", "create", user_name,
        "--instance", instance,
        "--project", project_id,
        "--password", password,
    ]

    if dry_run:
        safe_cmd = cmd[:-1] + ["******"]
        logger.info(f"  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    gcloud {' '.join(safe_cmd)}")
        return True

    rc, _, stderr = run_gcloud(cmd)
    if rc != 0:
        logger.error(f"\n  {c_red('x')} Failed to create user.")
        logger.error(f"  Error: {stderr}")
        return False

    logger.info(f"  {c_green('ok')} User '{user_name}' created.")
    return True


def create_secret(
    project_id: str, secret_name: str, password: str, dry_run: bool
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 4/5  -  Store Password in Secret Manager')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")
    logger.info(f"  Secret name : {secret_name}\n")

    if dry_run:
        logger.info(f"  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    gcloud secrets create {secret_name} --project={project_id} "
                     f"--replication-policy=automatic")
        logger.info(f"    echo '******' | gcloud secrets versions add {secret_name} "
                     f"--project={project_id} --data-file=-")
        return True

    # Create the secret resource
    logger.info(f"  Creating secret '{secret_name}' ...")
    rc, _, stderr = run_gcloud(
        ["secrets", "create", secret_name, "--project", project_id,
         "--replication-policy", "automatic"],
    )
    if rc != 0:
        logger.error(f"  {c_red('x')} Failed to create secret: {stderr}")
        return False
    logger.info(f"  {c_green('ok')} Secret created.")

    # Add the password as the first version
    logger.info(f"  Adding password as secret version ...")
    rc, _, stderr = run_gcloud(
        ["secrets", "versions", "add", secret_name, "--project", project_id, "--data-file", "-"],
        stdin_data=password,
    )
    if rc != 0:
        logger.error(f"  {c_red('x')} Failed to add secret version: {stderr}")
        return False
    logger.info(f"  {c_green('ok')} Password stored in Secret Manager.")
    return True


def update_secret_version(
    project_id: str, secret_name: str, password: str, dry_run: bool
) -> bool:
    """Add a new version to an existing secret."""
    logger.info(f"  Adding new version to existing secret '{secret_name}' ...")

    if dry_run:
        logger.info(f"  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    echo '******' | gcloud secrets versions add {secret_name} "
                     f"--project={project_id} --data-file=-")
        return True

    rc, _, stderr = run_gcloud(
        ["secrets", "versions", "add", secret_name, "--project", project_id, "--data-file", "-"],
        stdin_data=password,
    )
    if rc != 0:
        logger.error(f"  {c_red('x')} Failed to update secret: {stderr}")
        return False
    logger.info(f"  {c_green('ok')} Secret version added.")
    return True


def grant_secret_access(
    project_id: str, secret_name: str, member: str, dry_run: bool
) -> bool:
    logger.info(f"  Granting secretAccessor to {c_cyan(member)} ...")

    cmd = [
        "secrets", "add-iam-policy-binding", secret_name,
        "--project", project_id,
        "--member", f"serviceAccount:{member}",
        "--role", "roles/secretmanager.secretAccessor",
    ]

    if dry_run:
        logger.info(f"  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    gcloud {' '.join(cmd)}")
        return True

    rc, _, stderr = run_gcloud(cmd)
    if rc != 0:
        logger.error(f"  {c_red('x')} Failed to grant access: {stderr}")
        logger.info(f"  {c_yellow('!')} You can grant access manually later:")
        logger.info(f"    gcloud {' '.join(cmd)}")
        return False

    logger.info(f"  {c_green('ok')} Access granted.")
    return True


# ---------------------------------------------------------------------------
# Confirmation prompt
# ---------------------------------------------------------------------------
def confirm(message: str, default_yes: bool = False) -> bool:
    suffix = "[Y/n]" if default_yes else "[y/N]"
    try:
        reply = input(f"  {c_yellow('?')}  {message} {suffix}: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        return False
    if default_yes:
        return reply not in ("n", "no")
    return reply in ("y", "yes")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Cloud SQL Setup — Phase 1 of ADK RAG Agent database deployment",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup-cloudsql.py                                   # interactive
  python setup-cloudsql.py --env environments/usfs.yaml      # explicit YAML
  python setup-cloudsql.py --dry-run                         # preview only
  python setup-cloudsql.py --skip-existing                   # skip what exists
  python setup-cloudsql.py --force                           # overwrite existing
""",
    )
    parser.add_argument("--env", default=DEFAULT_ENV_FILE,
                        help=f"Path to environment YAML (default: {DEFAULT_ENV_FILE})")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview commands without executing")
    parser.add_argument("--skip-existing", action="store_true",
                        help="Silently skip resources that already exist")
    parser.add_argument("--force", action="store_true",
                        help="Delete and recreate existing resources")
    parser.add_argument("--secret-name", default=DEFAULT_SECRET_NAME,
                        help=f"Secret Manager name for DB password (default: {DEFAULT_SECRET_NAME})")
    parser.add_argument("--tier", default=DEFAULT_TIER,
                        help=f"Cloud SQL machine tier (default: {DEFAULT_TIER})")
    parser.add_argument("--no-interactive", action="store_true",
                        help="Exit with error instead of prompting for missing values")

    args = parser.parse_args()

    # --- Banner ---------------------------------------------------------------
    logger.info(f"\n{MAGENTA}{'=' * 64}{NC}")
    logger.info(f"  {c_bold('Cloud SQL Setup  -  ADK RAG Agent')}")
    logger.info(f"  Phase 1: Database Infrastructure Deployment")
    if args.dry_run:
        logger.info(f"  {c_yellow('MODE: DRY RUN  (no changes will be made)')}")
    if args.force:
        logger.info(f"  {c_red('MODE: FORCE  (existing resources will be deleted)')}")
    logger.info(f"{MAGENTA}{'=' * 64}{NC}")

    # --- Load config ----------------------------------------------------------
    root = find_project_root()
    env_file = os.path.join(root, args.env) if not os.path.isabs(args.env) else args.env

    config = load_env_config(env_file)
    cfg = extract_db_config(config)

    # --- Validate / prompt ----------------------------------------------------
    cfg = validate_config(cfg, no_interactive=args.no_interactive)
    print_config_summary(cfg, args.secret_name, args.tier)

    # --- Authentication -------------------------------------------------------
    auth_ok, _ = check_gcloud_auth()
    if not auth_ok:
        sys.exit(1)

    if not set_gcloud_project(cfg["project_id"]):
        sys.exit(1)

    # --- Confirmation ---------------------------------------------------------
    if not args.dry_run and not args.no_interactive:
        if not confirm("Proceed with Cloud SQL setup?"):
            logger.info(f"\n  {c_yellow('Aborted by user.')}")
            sys.exit(0)

    tracker = DeploymentTracker()

    # =========================================================================
    # STEP 1 — Cloud SQL Instance
    # =========================================================================
    inst_found, inst_state = instance_exists(cfg["project_id"], cfg["instance_name"])

    if inst_found:
        if args.force:
            logger.info(f"\n  {c_yellow('!')} --force: deleting existing instance ...")
            if not args.dry_run:
                if not delete_instance(cfg["project_id"], cfg["instance_name"]):
                    tracker.add_failed(f"Delete instance '{cfg['instance_name']}'")
                    tracker.print_summary()
                    sys.exit(1)
            inst_found = False  # proceed to create
        elif args.skip_existing:
            logger.info(f"  {c_yellow('-')} Skipping instance (already exists).")
            tracker.add_skipped(f"Cloud SQL instance '{cfg['instance_name']}'")
        else:
            logger.info(f"\n  Instance '{cfg['instance_name']}' already exists (state: {inst_state}).")
            if confirm("Delete and recreate it?"):
                if not args.dry_run:
                    if not delete_instance(cfg["project_id"], cfg["instance_name"]):
                        tracker.add_failed(f"Delete instance '{cfg['instance_name']}'")
                        tracker.print_summary()
                        sys.exit(1)
                inst_found = False
            else:
                tracker.add_skipped(f"Cloud SQL instance '{cfg['instance_name']}'")

    if not inst_found:
        ok = create_instance(cfg["project_id"], cfg["instance_name"], cfg["region"],
                             args.tier, args.dry_run)
        if ok:
            tracker.add_created(f"Cloud SQL instance '{cfg['instance_name']}'")
        else:
            tracker.add_failed(f"Cloud SQL instance '{cfg['instance_name']}'")
            tracker.print_summary()
            sys.exit(1)

    # =========================================================================
    # STEP 2 — Database
    # =========================================================================
    db_found = database_exists(cfg["project_id"], cfg["instance_name"], cfg["database_name"])

    if db_found:
        if args.force:
            logger.info(f"\n  {c_yellow('!')} --force: deleting existing database ...")
            if not args.dry_run:
                if not delete_database(cfg["project_id"], cfg["instance_name"],
                                       cfg["database_name"]):
                    tracker.add_failed(f"Delete database '{cfg['database_name']}'")
                    tracker.print_summary()
                    sys.exit(1)
            db_found = False
        elif args.skip_existing:
            logger.info(f"  {c_yellow('-')} Skipping database (already exists).")
            tracker.add_skipped(f"Database '{cfg['database_name']}'")
        else:
            logger.info(f"\n  Database '{cfg['database_name']}' already exists.")
            if confirm("Delete and recreate it?"):
                if not args.dry_run:
                    if not delete_database(cfg["project_id"], cfg["instance_name"],
                                           cfg["database_name"]):
                        tracker.add_failed(f"Delete database '{cfg['database_name']}'")
                        tracker.print_summary()
                        sys.exit(1)
                db_found = False
            else:
                tracker.add_skipped(f"Database '{cfg['database_name']}'")

    if not db_found:
        ok = create_database(cfg["project_id"], cfg["instance_name"], cfg["database_name"],
                             args.dry_run)
        if ok:
            tracker.add_created(f"Database '{cfg['database_name']}'")
        else:
            tracker.add_failed(f"Database '{cfg['database_name']}'")
            tracker.print_summary()
            sys.exit(1)

    # =========================================================================
    # STEP 3 — User
    # =========================================================================
    usr_found = user_exists(cfg["project_id"], cfg["instance_name"], cfg["user_name"])

    if usr_found:
        if args.force:
            logger.info(f"\n  {c_yellow('!')} --force: deleting existing user ...")
            if not args.dry_run:
                if not delete_user(cfg["project_id"], cfg["instance_name"], cfg["user_name"]):
                    tracker.add_failed(f"Delete user '{cfg['user_name']}'")
                    tracker.print_summary()
                    sys.exit(1)
            usr_found = False
        elif args.skip_existing:
            logger.info(f"  {c_yellow('-')} Skipping user (already exists).")
            tracker.add_skipped(f"User '{cfg['user_name']}'")
        else:
            logger.info(f"\n  User '{cfg['user_name']}' already exists.")
            if confirm("Delete and recreate with the configured password?"):
                if not args.dry_run:
                    if not delete_user(cfg["project_id"], cfg["instance_name"], cfg["user_name"]):
                        tracker.add_failed(f"Delete user '{cfg['user_name']}'")
                        tracker.print_summary()
                        sys.exit(1)
                usr_found = False
            else:
                tracker.add_skipped(f"User '{cfg['user_name']}'")

    if not usr_found:
        ok = create_user(cfg["project_id"], cfg["instance_name"], cfg["user_name"],
                         cfg["actual_password"], args.dry_run)
        if ok:
            tracker.add_created(f"User '{cfg['user_name']}'")
        else:
            tracker.add_failed(f"User '{cfg['user_name']}'")
            tracker.print_summary()
            sys.exit(1)

    # =========================================================================
    # STEP 4 — Secret Manager
    # =========================================================================
    sec_found = secret_exists(cfg["project_id"], args.secret_name)

    if sec_found:
        if args.force:
            logger.info(f"\n  {c_yellow('!')} --force: deleting existing secret ...")
            if not args.dry_run:
                if not delete_secret(cfg["project_id"], args.secret_name):
                    tracker.add_failed(f"Delete secret '{args.secret_name}'")
                    tracker.print_summary()
                    sys.exit(1)
            sec_found = False
        elif args.skip_existing:
            logger.info(f"  {c_yellow('-')} Skipping secret (already exists).  Adding new version.")
            ok = update_secret_version(cfg["project_id"], args.secret_name,
                                       cfg["actual_password"], args.dry_run)
            if ok:
                tracker.add_created(f"Secret version for '{args.secret_name}'")
            else:
                tracker.add_failed(f"Secret version for '{args.secret_name}'")
        else:
            logger.info(f"\n  Secret '{args.secret_name}' already exists.")
            if confirm("Update with new password version?", default_yes=True):
                ok = update_secret_version(cfg["project_id"], args.secret_name,
                                           cfg["actual_password"], args.dry_run)
                if ok:
                    tracker.add_created(f"Secret version for '{args.secret_name}'")
                else:
                    tracker.add_failed(f"Secret version for '{args.secret_name}'")
            else:
                tracker.add_skipped(f"Secret '{args.secret_name}'")

    if not sec_found:
        ok = create_secret(cfg["project_id"], args.secret_name, cfg["actual_password"],
                           args.dry_run)
        if ok:
            tracker.add_created(f"Secret '{args.secret_name}'")
        else:
            tracker.add_failed(f"Secret '{args.secret_name}'")
            tracker.print_summary()
            sys.exit(1)

    # =========================================================================
    # STEP 5 — IAM bindings
    # =========================================================================
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 5/5  -  Grant Secret Access to Service Accounts')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    project_number = get_project_number(cfg["project_id"])

    service_accounts = []
    if project_number:
        service_accounts.append(
            f"{project_number}-compute@developer.gserviceaccount.com"
        )
        logger.info(f"  {c_green('ok')} Project number: {project_number}")
    else:
        logger.info(f"  {c_yellow('!')} Could not fetch project number.  "
                     f"Skipping compute default SA binding.")

    service_accounts.append(f"backend-sa@{cfg['project_id']}.iam.gserviceaccount.com")

    for sa in service_accounts:
        ok = grant_secret_access(cfg["project_id"], args.secret_name, sa, args.dry_run)
        if ok:
            tracker.add_created(f"IAM binding: {sa}")
        else:
            # Non-fatal — the SA may not exist yet (created later by deploy-all.sh)
            tracker.add_failed(f"IAM binding: {sa}")
            logger.info(f"  {c_yellow('!')} The service account may not exist yet.  "
                        f"You can re-run this step after deploy-all.sh creates SAs.")

    # =========================================================================
    # Summary
    # =========================================================================
    tracker.print_summary()

    # --- Next steps -----------------------------------------------------------
    if not args.dry_run and tracker.created:
        conn = f"{cfg['project_id']}:{cfg['region']}:{cfg['instance_name']}"
        logger.info(f"\n{CYAN}{'_' * 64}{NC}")
        logger.info(f"  {c_bold('Next Steps')}")
        logger.info(f"{CYAN}{'_' * 64}{NC}")
        logger.info(f"")
        logger.info(f"  1. Start Cloud SQL Proxy (in a separate terminal):")
        logger.info(f"     cloud-sql-proxy {conn} --port=5434")
        logger.info(f"")
        logger.info(f"  2. Apply the database schema:")
        logger.info(f"     PGPASSWORD=<password> psql -h 127.0.0.1 -p 5434 \\")
        logger.info(f"       -U {cfg['user_name']} -d {cfg['database_name']} \\")
        logger.info(f"       -f backend/init_postgresql_schema.sql")
        logger.info(f"")
        logger.info(f"  3. Run migrations:")
        logger.info(f"     cd backend")
        logger.info(f"     python src/database/migrations/run_migrations.py")
        logger.info(f"     python add_missing_columns.py")
        logger.info(f"")
        logger.info(f"  4. Sync corpora from Vertex AI:")
        logger.info(f"     python sync_corpora_from_vertex.py")
        logger.info(f"")
        logger.info(f"  5. Seed users, groups & permissions:")
        logger.info(f"     python seed_data.py --env ../environments/usfs.yaml --target cloud")
        logger.info(f"")
        logger.info(f"  Connection : {conn}")
        logger.info(f"  Database   : {cfg['database_name']}")
        logger.info(f"  User       : {cfg['user_name']}")
        logger.info(f"  Password   : Stored in Secret Manager as '{args.secret_name}'")
        logger.info(f"{CYAN}{'_' * 64}{NC}\n")

    sys.exit(0 if not tracker.failed else 1)


if __name__ == "__main__":
    main()
