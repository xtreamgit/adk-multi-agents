#!/usr/bin/env python3
"""
Seed Data Script for ADK RAG Agent
====================================
Automates Phase 4 of database deployment:

  1. Ensure seed_data section exists in environment YAML
  2. Seed chatbot groups, agents, mappings, and users

Requires Cloud SQL Proxy running on localhost (or use --start-proxy).

Usage:
  python setup-seed.py                                # interactive
  python setup-seed.py --env environments/usfs.yaml   # explicit YAML
  python setup-seed.py --dry-run                      # preview only
  python setup-seed.py --start-proxy                  # auto-start proxy
  python setup-seed.py --force                        # update existing records
"""

import argparse
import atexit
import getpass
import logging
import os
import platform
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import List, Optional, Tuple

import yaml

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("setup_seed")

# ---------------------------------------------------------------------------
# ANSI colours
# ---------------------------------------------------------------------------
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
CYAN = "\033[0;36m"
MAGENTA = "\033[0;35m"
BOLD = "\033[1m"
NC = "\033[0m"


def c_green(t):  return f"{GREEN}{t}{NC}"
def c_yellow(t): return f"{YELLOW}{t}{NC}"
def c_red(t):    return f"{RED}{t}{NC}"
def c_blue(t):   return f"{BLUE}{t}{NC}"
def c_cyan(t):   return f"{CYAN}{t}{NC}"
def c_bold(t):   return f"{BOLD}{t}{NC}"


# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DEFAULT_ENV_FILE = "environments/usfs.yaml"
DEFAULT_PROXY_PORT = 5434
PROXY_STARTUP_TIMEOUT = 15
TEMPLATE_ENV_FILE = "environments/client-template.yaml"


# ---------------------------------------------------------------------------
# Deployment Tracker
# ---------------------------------------------------------------------------
class DeploymentTracker:
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
        logger.info(f"  {c_bold('SEED DATA SUMMARY')}")
        logger.info(f"{CYAN}{'=' * 64}{NC}")

        if self.created:
            logger.info(f"\n  {c_green('SEEDED')} ({len(self.created)}):")
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
            logger.info(f"  {c_yellow('RESULT: Nothing new seeded.')}")
            return True
        else:
            logger.info(f"  {c_green('RESULT: Phase 4 completed successfully!')}")
            return True


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------
def find_project_root() -> str:
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
    abs_path = os.path.abspath(env_path)
    if not os.path.exists(abs_path):
        logger.error(f"  {c_red('x')} Environment file not found: {abs_path}")
        sys.exit(1)
    with open(abs_path, "r") as f:
        config = yaml.safe_load(f)
    logger.info(f"  {c_green('ok')} Loaded config from {abs_path}")
    return config


def extract_db_config(config: dict) -> dict:
    db = config.get("database", {})
    return {
        "project_id": config.get("project_id", ""),
        "region": config.get("region", ""),
        "account_env": config.get("account_env", ""),
        "instance_name": db.get("cloud_sql_instance", ""),
        "connection_name": db.get("cloud_sql_connection", ""),
        "database_name": db.get("name", ""),
        "user_name": db.get("user", ""),
        "password": db.get("password", ""),
        "password_secret_value": db.get("password_secret_name", ""),
        "organization_domain": config.get("organization_domain", ""),
        "iap_admin_user": config.get("iap_admin_user", ""),
        "client_name": config.get("client_name", ""),
    }


def resolve_password(cfg: dict, no_interactive: bool) -> str:
    if cfg["password"]:
        logger.info(f"  {c_green('ok')} Password: {c_cyan('(from database.password field)')}")
        return cfg["password"]
    if cfg["password_secret_value"]:
        logger.info(f"  {c_green('ok')} Password: {c_cyan('(from database.password_secret_name field)')}")
        return cfg["password_secret_value"]
    if no_interactive:
        logger.error(f"  {c_red('x')} No password found and --no-interactive is set.")
        sys.exit(1)
    logger.info(f"  {c_yellow('!')} No password found in config.")
    pw = getpass.getpass(f"  {c_yellow('?')}  Enter database password: ")
    if not pw:
        logger.error(f"  {c_red('x')} Password cannot be empty.")
        sys.exit(1)
    return pw


def validate_config(cfg: dict, no_interactive: bool) -> dict:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Validating configuration')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    fields = [
        ("project_id", "GCP Project ID"),
        ("region", "GCP Region"),
        ("instance_name", "Cloud SQL instance"),
        ("connection_name", "Cloud SQL connection string"),
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

    cfg["actual_password"] = resolve_password(cfg, no_interactive)
    return cfg


def print_config_summary(cfg: dict, proxy_port: int):
    logger.info(f"\n{CYAN}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Configuration Summary')}")
    logger.info(f"{CYAN}{'_' * 64}{NC}")
    logger.info(f"  Project        : {c_blue(cfg['project_id'])}")
    logger.info(f"  Instance       : {cfg['instance_name']}")
    logger.info(f"  Database       : {cfg['database_name']}")
    logger.info(f"  User           : {cfg['user_name']}")
    logger.info(f"  Password       : {c_green('****** (set)')}")
    logger.info(f"  Proxy target   : 127.0.0.1:{proxy_port}")
    logger.info(f"  Domain         : {cfg.get('organization_domain', 'N/A')}")
    logger.info(f"  Client         : {cfg.get('client_name', 'N/A')}")
    logger.info(f"{CYAN}{'_' * 64}{NC}\n")


# ---------------------------------------------------------------------------
# Confirmation
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
# Cloud SQL Proxy management
# ---------------------------------------------------------------------------
_proxy_process: Optional[subprocess.Popen] = None


def _cleanup_proxy():
    global _proxy_process
    if _proxy_process is not None:
        logger.info(f"\n  {c_yellow('!')} Stopping Cloud SQL Proxy (pid {_proxy_process.pid}) ...")
        _proxy_process.terminate()
        try:
            _proxy_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            _proxy_process.kill()
        _proxy_process = None


def is_proxy_running(port: int) -> bool:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(2)
    result = sock.connect_ex(("127.0.0.1", port))
    sock.close()
    return result == 0


def _find_cloud_sql_proxy() -> Optional[str]:
    path = shutil.which("cloud-sql-proxy")
    if path:
        return path
    for candidate in ["/usr/local/bin/cloud-sql-proxy", "./cloud-sql-proxy"]:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def _install_cloud_sql_proxy() -> Optional[str]:
    arch = platform.machine()
    if arch in ("x86_64", "amd64"):
        arch_suffix = "amd64"
    elif arch in ("aarch64", "arm64"):
        arch_suffix = "arm64"
    else:
        logger.error(f"  {c_red('x')} Unsupported architecture: {arch}")
        return None

    version = "v2.14.3"
    url = (
        f"https://storage.googleapis.com/cloud-sql-connectors/"
        f"cloud-sql-proxy/{version}/cloud-sql-proxy.linux.{arch_suffix}"
    )

    logger.info(f"  Downloading cloud-sql-proxy {version} ...")
    logger.info(f"    URL: {url}")

    tmp_path = "/tmp/cloud-sql-proxy"
    try:
        rc = subprocess.run(
            ["curl", "-fsSL", "-o", tmp_path, url],
            capture_output=True, text=True, timeout=60,
        )
        if rc.returncode != 0:
            logger.error(f"  {c_red('x')} Download failed: {rc.stderr.strip()}")
            return None

        os.chmod(tmp_path, 0o755)

        install_path = "/usr/local/bin/cloud-sql-proxy"
        try:
            result = subprocess.run(
                ["sudo", "mv", tmp_path, install_path],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode == 0:
                logger.info(f"  {c_green('ok')} Installed to {install_path}")
                return install_path
        except Exception:
            pass

        logger.info(f"  {c_yellow('!')} Could not install to {install_path}, using {tmp_path}")
        return tmp_path

    except subprocess.TimeoutExpired:
        logger.error(f"  {c_red('x')} Download timed out.")
        return None
    except Exception as e:
        logger.error(f"  {c_red('x')} Download error: {e}")
        return None


def ensure_cloud_sql_proxy(no_interactive: bool) -> str:
    path = _find_cloud_sql_proxy()
    if path:
        try:
            result = subprocess.run([path, "--version"], capture_output=True, text=True, timeout=5)
            version = result.stdout.strip() or result.stderr.strip()
            logger.info(f"  {c_green('ok')} {version}")
        except Exception:
            logger.info(f"  {c_green('ok')} cloud-sql-proxy found at {path}")
        return path

    logger.info(f"  {c_yellow('!')} cloud-sql-proxy not found.")

    if not no_interactive:
        do_install = confirm("Install cloud-sql-proxy automatically?", default_yes=True)
    else:
        do_install = True

    if do_install:
        installed = _install_cloud_sql_proxy()
        if installed:
            return installed

    logger.error(f"  {c_red('x')} cloud-sql-proxy is required but not available.")
    logger.error(f"  Install manually:")
    logger.error(f"    curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.3/cloud-sql-proxy.linux.amd64")
    logger.error(f"    chmod +x cloud-sql-proxy && sudo mv cloud-sql-proxy /usr/local/bin/")
    sys.exit(1)


def start_proxy(connection_name: str, port: int, proxy_binary: str = "cloud-sql-proxy") -> bool:
    global _proxy_process
    logger.info(f"  Starting Cloud SQL Proxy ...")
    logger.info(f"    Connection : {connection_name}")
    logger.info(f"    Port       : {port}")

    try:
        _proxy_process = subprocess.Popen(
            [proxy_binary, connection_name, f"--port={port}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError:
        logger.error(f"  {c_red('x')} cloud-sql-proxy not found at: {proxy_binary}")
        return False

    atexit.register(_cleanup_proxy)

    logger.info(f"  Waiting for proxy to accept connections ...")
    start = time.time()
    while time.time() - start < PROXY_STARTUP_TIMEOUT:
        if is_proxy_running(port):
            logger.info(f"  {c_green('ok')} Proxy is ready (pid {_proxy_process.pid}).")
            return True
        if _proxy_process.poll() is not None:
            _, stderr = _proxy_process.communicate()
            logger.error(f"  {c_red('x')} Proxy exited with code {_proxy_process.returncode}")
            logger.error(f"  Error: {stderr.decode().strip()}")
            _proxy_process = None
            return False
        time.sleep(1)

    logger.error(f"  {c_red('x')} Proxy did not become ready within {PROXY_STARTUP_TIMEOUT}s.")
    return False


# ---------------------------------------------------------------------------
# psql helpers
# ---------------------------------------------------------------------------
def run_psql(
    host: str, port: int, user: str, dbname: str, password: str,
    *, command: Optional[str] = None, timeout: int = 120,
) -> Tuple[int, str, str]:
    env = os.environ.copy()
    env["PGPASSWORD"] = password
    cmd = ["psql", "-h", host, "-p", str(port), "-U", user, "-d", dbname]
    if command:
        cmd += ["-c", command]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return 1, "", "Command timed out"
    except FileNotFoundError:
        return 127, "", "psql not found."


def check_psql_available() -> bool:
    try:
        result = subprocess.run(["psql", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            version = result.stdout.strip().split("\n")[0]
            logger.info(f"  {c_green('ok')} {version}")
            return True
    except FileNotFoundError:
        pass
    logger.error(f"  {c_red('x')} psql not found.")
    logger.error(f"  Install with: sudo apt-get install -y postgresql-client")
    return False


def test_connection(host: str, port: int, user: str, dbname: str, password: str) -> bool:
    logger.info(f"  Testing connection to {dbname}@{host}:{port} ...")
    rc, stdout, stderr = run_psql(host, port, user, dbname, password, command="SELECT 1;")
    if rc == 0:
        logger.info(f"  {c_green('ok')} Connection successful.")
        return True
    logger.error(f"  {c_red('x')} Connection failed.")
    if stderr:
        for line in stderr.split("\n"):
            logger.error(f"    {line}")
    return False


# ---------------------------------------------------------------------------
# seed_data section management
# ---------------------------------------------------------------------------
def check_seed_data_section(config: dict, env_path: str, project_root: str,
                            cfg: dict, no_interactive: bool) -> dict:
    """Check if seed_data section exists. If missing, offer to generate it."""
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Checking seed_data section')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    seed_data = config.get("seed_data")
    if seed_data:
        # Summarize what's configured
        groups = seed_data.get("chatbot_groups", [])
        agents = seed_data.get("chatbot_agents", [])
        assignments = seed_data.get("chatbot_group_agents", {})
        gg_agent = seed_data.get("google_group_agent_mappings", [])
        gg_corpus = seed_data.get("google_group_corpus_mappings", [])
        users = seed_data.get("users", [])

        logger.info(f"  {c_green('ok')} seed_data section found:")
        logger.info(f"    chatbot_groups             : {len(groups)}")
        logger.info(f"    chatbot_agents             : {len(agents)}")
        logger.info(f"    chatbot_group_agents       : {len(assignments)}")
        logger.info(f"    google_group_agent_mappings : {len(gg_agent)}")
        logger.info(f"    google_group_corpus_mappings: {len(gg_corpus)}")
        logger.info(f"    users                      : {len(users)}")
        return config

    # seed_data is missing — offer to generate it
    logger.info(f"  {c_yellow('!')} No 'seed_data' section found in environment YAML.")

    template_path = os.path.join(project_root, TEMPLATE_ENV_FILE)
    if not os.path.exists(template_path):
        logger.error(f"  {c_red('x')} Template not found: {template_path}")
        logger.error(f"  Add a 'seed_data:' section to {env_path} manually.")
        sys.exit(1)

    domain = cfg.get("organization_domain", "example.com") or "example.com"
    admin_email = cfg.get("iap_admin_user", "") or f"admin@{domain}"

    logger.info(f"  Template available: {template_path}")
    logger.info(f"  Domain will be set to: {c_cyan(domain)}")
    logger.info(f"  Admin user: {c_cyan(admin_email)}")

    if no_interactive:
        logger.error(f"  {c_red('x')} Cannot auto-generate seed_data in --no-interactive mode.")
        logger.error(f"  Add a 'seed_data:' section to {env_path} manually.")
        sys.exit(1)

    if not confirm("Generate and append seed_data section to environment YAML?", default_yes=True):
        logger.error(f"  {c_red('x')} seed_data section required. Add it manually to {env_path}")
        sys.exit(1)

    # Read template and extract seed_data section
    with open(template_path, "r") as f:
        template_lines = f.readlines()

    # Find the seed_data section start (includes comments above it)
    seed_start = None
    for i, line in enumerate(template_lines):
        # Start from the comment block before seed_data
        if "# ---- Seed Data" in line or "seed_data:" in line:
            # Look backwards for comment block start
            comment_start = i
            while comment_start > 0 and template_lines[comment_start - 1].startswith("#"):
                comment_start -= 1
            seed_start = comment_start
            break

    if seed_start is None:
        # Just find seed_data: line
        for i, line in enumerate(template_lines):
            if line.strip() == "seed_data:":
                seed_start = i
                break

    if seed_start is None:
        logger.error(f"  {c_red('x')} Could not find seed_data section in template.")
        sys.exit(1)

    seed_section = "".join(template_lines[seed_start:])

    # Replace example.com with actual domain
    seed_section = seed_section.replace("example.com", domain)

    # Replace admin user
    seed_section = seed_section.replace("admin@" + domain, admin_email)
    seed_section = seed_section.replace('"Admin User"', f'"{admin_email.split("@")[0].replace(".", " ").title()}"')

    # Preview
    logger.info(f"\n  {c_bold('Preview of seed_data section to append:')}\n")
    preview_lines = seed_section.strip().split("\n")
    for line in preview_lines[:30]:
        logger.info(f"    {line}")
    if len(preview_lines) > 30:
        logger.info(f"    ... ({len(preview_lines) - 30} more lines)")

    if not confirm("\nAppend this to the environment YAML?", default_yes=True):
        logger.error(f"  {c_red('x')} Aborted. Add seed_data section manually.")
        sys.exit(1)

    # Append to YAML
    abs_env = os.path.abspath(env_path)
    with open(abs_env, "a") as f:
        f.write("\n")
        f.write(seed_section)

    logger.info(f"  {c_green('ok')} seed_data section appended to {abs_env}")

    # Reload config
    with open(abs_env, "r") as f:
        config = yaml.safe_load(f)

    if not config.get("seed_data"):
        logger.error(f"  {c_red('x')} Failed to reload seed_data after appending. Check YAML syntax.")
        sys.exit(1)

    logger.info(f"  {c_green('ok')} Config reloaded with seed_data section.")
    return config


# ---------------------------------------------------------------------------
# Step 1/2: Run seed_data.py
# ---------------------------------------------------------------------------
def run_seed(
    env_path: str, password: str, project_root: str,
    dry_run: bool, force: bool, tracker: DeploymentTracker,
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 1/2  -  Seed Database')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    script = os.path.join(project_root, "backend", "seed_data.py")
    if not os.path.exists(script):
        logger.error(f"  {c_red('x')} Script not found: {script}")
        tracker.add_failed("seed_data.py not found")
        return False

    logger.info(f"  Script: {script}")
    logger.info(f"  Target: cloud")

    # Build command
    cmd = [sys.executable, script, "--env", os.path.abspath(env_path), "--target", "cloud", "--verbose"]
    if dry_run:
        cmd.append("--dry-run")
    if force:
        cmd.append("--force")

    if dry_run:
        logger.info(f"\n  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    DB_PASSWORD=****** \\")
        logger.info(f"    {' '.join(cmd)}")
        tracker.add_created("Seed data (chatbot groups, agents, mappings, users)")
        return True

    # Set DB_PASSWORD in env to bypass Secret Manager lookup
    env = os.environ.copy()
    env["DB_PASSWORD"] = password

    logger.info(f"\n  Running seed_data.py --target cloud ...")
    logger.info("")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            env=env,
            cwd=project_root,
        )
    except subprocess.TimeoutExpired:
        logger.error(f"  {c_red('x')} Script timed out.")
        tracker.add_failed("seed_data.py timed out")
        return False

    # Show output
    if result.stdout:
        for line in result.stdout.strip().split("\n"):
            logger.info(f"  {line}")
    if result.stderr:
        for line in result.stderr.strip().split("\n"):
            if "ERROR" in line.upper() or "Traceback" in line:
                logger.error(f"  {line}")
            else:
                logger.info(f"  {line}")

    if result.returncode == 0:
        logger.info(f"\n  {c_green('ok')} seed_data.py completed successfully.")
        tracker.add_created("Seed data (chatbot groups, agents, mappings, users)")
        return True
    else:
        logger.error(f"\n  {c_red('x')} seed_data.py exited with code {result.returncode}.")
        tracker.add_failed("seed_data.py failed")
        return False


# ---------------------------------------------------------------------------
# Step 2/2: Verify seeded data
# ---------------------------------------------------------------------------
def verify_seeded_data(
    host: str, port: int, user: str, dbname: str, password: str,
    dry_run: bool,
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 2/2  -  Verify Seeded Data')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    if dry_run:
        logger.info(f"  {c_yellow('[DRY RUN]')} Would query seeded tables for row counts.")
        return True

    query = """
SELECT 'chatbot_groups' AS table_name, COUNT(*)::text AS row_count FROM chatbot_groups
UNION ALL SELECT 'chatbot_agents', COUNT(*)::text FROM chatbot_agents
UNION ALL SELECT 'chatbot_group_agents', COUNT(*)::text FROM chatbot_group_agents
UNION ALL SELECT 'google_group_agent_mappings', COUNT(*)::text FROM google_group_agent_mappings
UNION ALL SELECT 'google_group_corpus_mappings', COUNT(*)::text FROM google_group_corpus_mappings
UNION ALL SELECT 'users', COUNT(*)::text FROM users
UNION ALL SELECT 'chatbot_users', COUNT(*)::text FROM chatbot_users;
"""

    rc, stdout, stderr = run_psql(host, port, user, dbname, password, command=query)

    if rc != 0:
        logger.error(f"  {c_red('x')} Could not query seeded tables.")
        if stderr:
            logger.error(f"    {stderr}")
        return False

    # Display raw psql table output
    if stdout:
        for line in stdout.split("\n"):
            logger.info(f"    {line}")

    # Also show groups and agents
    logger.info(f"\n  {c_bold('Chatbot Groups:')}")
    rc2, stdout2, _ = run_psql(host, port, user, dbname, password,
                                command="SELECT id, name, is_active FROM chatbot_groups ORDER BY id;")
    if rc2 == 0 and stdout2:
        for line in stdout2.split("\n"):
            logger.info(f"    {line}")

    logger.info(f"\n  {c_bold('Chatbot Agents:')}")
    rc3, stdout3, _ = run_psql(host, port, user, dbname, password,
                                command="SELECT id, name, agent_type, is_active FROM chatbot_agents ORDER BY id;")
    if rc3 == 0 and stdout3:
        for line in stdout3.split("\n"):
            logger.info(f"    {line}")

    logger.info(f"\n  {c_bold('Users:')}")
    rc4, stdout4, _ = run_psql(host, port, user, dbname, password,
                                command="SELECT id, email, auth_provider, is_active FROM users ORDER BY id;")
    if rc4 == 0 and stdout4:
        for line in stdout4.split("\n"):
            logger.info(f"    {line}")

    logger.info("")
    logger.info(f"  {c_green('ok')} Verification complete.")
    return True


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Seed Data — Phase 4 of ADK RAG Agent database deployment",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup-seed.py                                # interactive
  python setup-seed.py --env environments/usfs.yaml   # explicit YAML
  python setup-seed.py --dry-run                      # preview only
  python setup-seed.py --start-proxy                  # auto-start proxy
  python setup-seed.py --force                        # update existing records
""",
    )
    parser.add_argument("--env", default=DEFAULT_ENV_FILE,
                        help=f"Path to environment YAML (default: {DEFAULT_ENV_FILE})")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview commands without executing")
    parser.add_argument("--proxy-port", type=int, default=DEFAULT_PROXY_PORT,
                        help=f"Cloud SQL Proxy port (default: {DEFAULT_PROXY_PORT})")
    parser.add_argument("--start-proxy", action="store_true",
                        help="Auto-start Cloud SQL Proxy if not running")
    parser.add_argument("--force", action="store_true",
                        help="Update existing records instead of skipping")
    parser.add_argument("--no-interactive", action="store_true",
                        help="Exit with error instead of prompting for missing values")

    args = parser.parse_args()

    # --- Banner ---------------------------------------------------------------
    logger.info(f"\n{MAGENTA}{'=' * 64}{NC}")
    logger.info(f"  {c_bold('Seed Data  -  ADK RAG Agent')}")
    logger.info(f"  Phase 4: Seed Users, Groups, Agents & Mappings")
    if args.dry_run:
        logger.info(f"  {c_yellow('MODE: DRY RUN  (no changes will be made)')}")
    if args.force:
        logger.info(f"  {c_yellow('MODE: FORCE  (existing records will be updated)')}")
    logger.info(f"{MAGENTA}{'=' * 64}{NC}")

    # --- Load config ----------------------------------------------------------
    root = find_project_root()
    env_file = os.path.join(root, args.env) if not os.path.isabs(args.env) else args.env

    config = load_env_config(env_file)
    cfg = extract_db_config(config)
    cfg = validate_config(cfg, no_interactive=args.no_interactive)

    host = "127.0.0.1"
    port = args.proxy_port
    user = cfg["user_name"]
    dbname = cfg["database_name"]
    password = cfg["actual_password"]

    print_config_summary(cfg, port)

    # --- Check seed_data section ----------------------------------------------
    config = check_seed_data_section(config, env_file, root, cfg, args.no_interactive)

    # --- Check prerequisites --------------------------------------------------
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Pre-flight Checks')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    # psql available?
    psql_ok = check_psql_available()
    if not psql_ok:
        if args.dry_run:
            logger.info(f"  {c_yellow('[DRY RUN]')} psql not found — skipping (not needed for dry run).")
        else:
            sys.exit(1)

    # cloud-sql-proxy available?
    proxy_binary = "cloud-sql-proxy"
    if args.dry_run:
        path = _find_cloud_sql_proxy()
        if path:
            logger.info(f"  {c_green('ok')} cloud-sql-proxy found at {path}")
        else:
            logger.info(f"  {c_yellow('[DRY RUN]')} cloud-sql-proxy not found — skipping (not needed for dry run).")
    else:
        proxy_binary = ensure_cloud_sql_proxy(no_interactive=args.no_interactive)

    # Python deps (psycopg2 needed by seed_data.py)
    if not args.dry_run:
        try:
            import psycopg2
            logger.info(f"  {c_green('ok')} psycopg2")
        except ImportError:
            logger.error(f"  {c_red('x')} psycopg2 not found.")
            logger.error(f"  Install with: pip install psycopg2-binary")
            sys.exit(1)
    else:
        logger.info(f"  {c_yellow('[DRY RUN]')} Skipping Python dependency check.")

    # seed_data.py exists?
    seed_script = os.path.join(root, "backend", "seed_data.py")
    if os.path.exists(seed_script):
        logger.info(f"  {c_green('ok')} seed_data.py found")
    else:
        logger.error(f"  {c_red('x')} backend/seed_data.py not found")
        sys.exit(1)

    # Proxy running?
    if args.dry_run:
        proxy_ok = is_proxy_running(port)
        if proxy_ok:
            logger.info(f"  {c_green('ok')} Cloud SQL Proxy is running on port {port}.")
        else:
            logger.info(f"  {c_yellow('[DRY RUN]')} Proxy not running — skipping (not needed for dry run).")
    else:
        proxy_ok = is_proxy_running(port)
        if proxy_ok:
            logger.info(f"  {c_green('ok')} Cloud SQL Proxy is running on port {port}.")
        else:
            logger.info(f"  {c_yellow('!')} Cloud SQL Proxy is NOT running on port {port}.")
            if args.start_proxy:
                if not start_proxy(cfg["connection_name"], port, proxy_binary):
                    logger.error(f"  {c_red('x')} Could not start proxy.  Aborting.")
                    sys.exit(1)
            elif not args.no_interactive:
                if confirm("Start Cloud SQL Proxy automatically?", default_yes=True):
                    if not start_proxy(cfg["connection_name"], port, proxy_binary):
                        logger.error(f"  {c_red('x')} Could not start proxy.  Aborting.")
                        sys.exit(1)
                else:
                    logger.error(f"  {c_red('x')} Proxy required.  Start it manually:")
                    logger.error(f"    {proxy_binary} {cfg['connection_name']} --port={port}")
                    sys.exit(1)
            else:
                logger.error(f"  {c_red('x')} Proxy required.  Start it with --start-proxy or manually:")
                logger.error(f"    {proxy_binary} {cfg['connection_name']} --port={port}")
                sys.exit(1)

        # Test connection
        if not test_connection(host, port, user, dbname, password):
            logger.error(f"\n  {c_red('x')} Cannot connect to database.  Check:")
            logger.error(f"    1. Cloud SQL Proxy is running")
            logger.error(f"    2. Database '{dbname}' exists (run setup-cloudsql.py first)")
            logger.error(f"    3. Schema applied (run setup-schema.py first)")
            logger.error(f"    4. User '{user}' and password are correct")
            sys.exit(1)

    # --- Confirmation ---------------------------------------------------------
    if not args.dry_run and not args.no_interactive:
        if not confirm("Proceed with seeding database?", default_yes=True):
            logger.info(f"\n  {c_yellow('Aborted by user.')}")
            sys.exit(0)

    tracker = DeploymentTracker()

    # === STEP 1/2: Seed =======================================================
    ok = run_seed(env_file, password, root, args.dry_run, args.force, tracker)

    # === STEP 2/2: Verify =====================================================
    verify_seeded_data(host, port, user, dbname, password, args.dry_run)

    # === SUMMARY ==============================================================
    tracker.print_summary()

    # --- Next steps -----------------------------------------------------------
    if not args.dry_run and not tracker.failed:
        logger.info(f"\n{CYAN}{'_' * 64}{NC}")
        logger.info(f"  {c_bold('Next Steps')}")
        logger.info(f"{CYAN}{'_' * 64}{NC}")
        logger.info(f"")
        logger.info(f"  Phase 5: Deploy to Cloud Run")
        logger.info(f"    cd infrastructure && ./deploy-all.sh")
        logger.info(f"{CYAN}{'_' * 64}{NC}\n")

    sys.exit(0 if not tracker.failed else 1)


if __name__ == "__main__":
    main()
