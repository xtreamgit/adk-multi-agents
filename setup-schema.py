#!/usr/bin/env python3
"""
Schema Setup Script for ADK RAG Agent
=======================================
Automates Phase 2 of database deployment:

  1. Apply base schema  (init_postgresql_schema.sql)
  2. Run all SQL migrations
  3. Add missing columns to corpus_metadata

Requires Cloud SQL Proxy running on localhost (or use --start-proxy).

Usage:
  python setup-schema.py                                # interactive
  python setup-schema.py --env environments/usfs.yaml   # explicit YAML
  python setup-schema.py --dry-run                      # preview only
  python setup-schema.py --start-proxy                  # auto-start proxy
"""

import argparse
import atexit
import getpass
import logging
import os
import signal
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
logger = logging.getLogger("setup_schema")

# ---------------------------------------------------------------------------
# ANSI colours (matching setup-cloudsql.py / deploy_env_config.py)
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
DEFAULT_PROXY_PORT = 5434
PROXY_STARTUP_TIMEOUT = 15  # seconds


# ---------------------------------------------------------------------------
# Deployment Tracker  (same pattern as setup-cloudsql.py)
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
        logger.info(f"  {c_bold('SCHEMA DEPLOYMENT SUMMARY')}")
        logger.info(f"{CYAN}{'=' * 64}{NC}")

        if self.created:
            logger.info(f"\n  {c_green('APPLIED')} ({len(self.created)}):")
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
            logger.info(f"  {c_yellow('RESULT: Nothing new applied.')}")
            return True
        else:
            logger.info(f"  {c_green('RESULT: Phase 2 completed successfully!')}")
            return True


# ---------------------------------------------------------------------------
# Config loading  (reused from setup-cloudsql.py)
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
        "instance_name": db.get("cloud_sql_instance", ""),
        "connection_name": db.get("cloud_sql_connection", ""),
        "database_name": db.get("name", ""),
        "user_name": db.get("user", ""),
        "password": db.get("password", ""),
        "password_secret_value": db.get("password_secret_name", ""),
    }


def resolve_password(cfg: dict, no_interactive: bool) -> str:
    """Resolve the database password from config or prompt."""
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
    """Ensure required values exist; prompt for missing ones."""
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
    logger.info(f"  Connection     : {cfg.get('connection_name', 'N/A')}")
    logger.info(f"{CYAN}{'_' * 64}{NC}\n")


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
# Cloud SQL Proxy management
# ---------------------------------------------------------------------------
_proxy_process: Optional[subprocess.Popen] = None


def _cleanup_proxy():
    """Terminate proxy on script exit if we started it."""
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
    """Check if something is listening on the proxy port."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(2)
    result = sock.connect_ex(("127.0.0.1", port))
    sock.close()
    return result == 0


def _find_cloud_sql_proxy() -> Optional[str]:
    """Find cloud-sql-proxy binary, or return None."""
    import shutil
    path = shutil.which("cloud-sql-proxy")
    if path:
        return path
    # Check common locations
    for candidate in ["/usr/local/bin/cloud-sql-proxy", "./cloud-sql-proxy"]:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def _install_cloud_sql_proxy() -> Optional[str]:
    """Download and install cloud-sql-proxy. Returns path on success, None on failure."""
    import platform
    import shutil

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

        # Try to install to /usr/local/bin, fall back to current directory
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

        # Fallback: keep in /tmp
        logger.info(f"  {c_yellow('!')} Could not install to {install_path}, using {tmp_path}")
        return tmp_path

    except subprocess.TimeoutExpired:
        logger.error(f"  {c_red('x')} Download timed out.")
        return None
    except Exception as e:
        logger.error(f"  {c_red('x')} Download error: {e}")
        return None


def ensure_cloud_sql_proxy(no_interactive: bool) -> str:
    """Ensure cloud-sql-proxy is available. Install if missing. Returns binary path."""
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
        do_install = True  # auto-install in non-interactive mode

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
    """Start Cloud SQL Proxy in the background."""
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

    # Wait for proxy to become ready
    logger.info(f"  Waiting for proxy to accept connections ...")
    start = time.time()
    while time.time() - start < PROXY_STARTUP_TIMEOUT:
        if is_proxy_running(port):
            logger.info(f"  {c_green('ok')} Proxy is ready (pid {_proxy_process.pid}).")
            return True
        # Check if process died
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
    host: str,
    port: int,
    user: str,
    dbname: str,
    password: str,
    *,
    command: Optional[str] = None,
    file_path: Optional[str] = None,
    timeout: int = 120,
) -> Tuple[int, str, str]:
    """Run a psql command and return (returncode, stdout, stderr)."""
    env = os.environ.copy()
    env["PGPASSWORD"] = password

    cmd = ["psql", "-h", host, "-p", str(port), "-U", user, "-d", dbname]

    if command:
        cmd += ["-c", command]
    elif file_path:
        cmd += ["-f", file_path]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return 1, "", "Command timed out"
    except FileNotFoundError:
        return 127, "", "psql not found. Install PostgreSQL client tools."


def check_psql_available() -> bool:
    """Verify psql is installed."""
    try:
        result = subprocess.run(["psql", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            version = result.stdout.strip().split("\n")[0]
            logger.info(f"  {c_green('ok')} {version}")
            return True
    except FileNotFoundError:
        pass
    logger.error(f"  {c_red('x')} psql not found. Install PostgreSQL client tools.")
    return False


def test_connection(host: str, port: int, user: str, dbname: str, password: str) -> bool:
    """Verify we can connect to the database via psql."""
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
# Step 1: Apply base schema
# ---------------------------------------------------------------------------
def apply_base_schema(
    host: str, port: int, user: str, dbname: str, password: str,
    schema_file: str, dry_run: bool,
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 1/3  -  Apply Base Schema')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")
    logger.info(f"  File: {schema_file}")

    if not os.path.exists(schema_file):
        logger.error(f"  {c_red('x')} Schema file not found: {schema_file}")
        return False

    if dry_run:
        logger.info(f"\n  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    PGPASSWORD=****** psql -h {host} -p {port} -U {user} -d {dbname} \\")
        logger.info(f"      -f {schema_file}")
        return True

    logger.info(f"  Applying schema ...")
    rc, stdout, stderr = run_psql(host, port, user, dbname, password, file_path=schema_file,
                                  timeout=120)

    if rc != 0:
        logger.error(f"\n  {c_red('x')} Schema apply failed.")
        if stderr:
            for line in stderr.split("\n"):
                logger.error(f"    {line}")
        return False

    # Count "CREATE TABLE" notices in output
    creates = sum(1 for line in (stdout + stderr).split("\n")
                  if "CREATE TABLE" in line or "CREATE INDEX" in line)
    already = sum(1 for line in stderr.split("\n")
                  if "already exists" in line.lower())

    logger.info(f"  {c_green('ok')} Base schema applied.")
    if creates:
        logger.info(f"    Created: {creates} objects")
    if already:
        logger.info(f"    Already existed: {already} objects (idempotent)")
    return True


# ---------------------------------------------------------------------------
# Step 2: Run migrations
# ---------------------------------------------------------------------------
def discover_migrations(migrations_dir: str) -> List[Path]:
    """Find and sort all migration SQL files."""
    mdir = Path(migrations_dir)
    if not mdir.exists():
        logger.error(f"  {c_red('x')} Migrations directory not found: {migrations_dir}")
        return []

    files = sorted(mdir.glob("*.sql"))
    return files


def run_migrations(
    host: str, port: int, user: str, dbname: str, password: str,
    migrations_dir: str, dry_run: bool, tracker: DeploymentTracker,
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 2/3  -  Run Migrations')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    files = discover_migrations(migrations_dir)
    if not files:
        logger.info(f"  {c_yellow('!')} No migration files found.")
        return True

    logger.info(f"  Found {len(files)} migration files:\n")
    for f in files:
        logger.info(f"    {f.name}")
    logger.info("")

    if dry_run:
        logger.info(f"  {c_yellow('[DRY RUN]')} Would apply all {len(files)} migrations via psql.")
        for f in files:
            tracker.add_created(f"Migration: {f.name}")
        return True

    succeeded = 0
    failed_list = []

    for i, mfile in enumerate(files, 1):
        label = f"[{i}/{len(files)}]"
        logger.info(f"  {label} {mfile.name} ...")

        rc, stdout, stderr = run_psql(
            host, port, user, dbname, password,
            file_path=str(mfile),
            timeout=60,
        )

        # Treat "already exists" / "duplicate" errors as success
        error_lines = [l for l in stderr.split("\n") if l.strip()] if stderr else []
        real_errors = [
            l for l in error_lines
            if "ERROR:" in l
            and "already exists" not in l.lower()
            and "duplicate" not in l.lower()
        ]

        if rc == 0 or not real_errors:
            if real_errors:
                # Shouldn't happen but just in case
                logger.info(f"    {c_yellow('!')} Completed with warnings")
            else:
                already = any("already exists" in l.lower() for l in error_lines)
                if already:
                    logger.info(f"    {c_green('ok')} Already applied (idempotent)")
                else:
                    logger.info(f"    {c_green('ok')} Applied")
            succeeded += 1
            tracker.add_created(f"Migration: {mfile.name}")
        else:
            logger.error(f"    {c_red('x')} Failed")
            for line in real_errors:
                logger.error(f"      {line}")
            failed_list.append(mfile.name)
            tracker.add_failed(f"Migration: {mfile.name}")

    logger.info(f"\n  Migrations: {succeeded} succeeded, {len(failed_list)} failed")

    if failed_list:
        logger.error(f"\n  {c_red('!')} Failed migrations:")
        for f in failed_list:
            logger.error(f"    - {f}")
        return False
    return True


# ---------------------------------------------------------------------------
# Step 3: Add missing columns
# ---------------------------------------------------------------------------
def run_add_missing_columns(
    host: str, port: int, user: str, dbname: str, password: str,
    project_root: str, dry_run: bool,
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 3/3  -  Add Missing Columns')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    script = os.path.join(project_root, "backend", "add_missing_columns.py")
    if not os.path.exists(script):
        logger.error(f"  {c_red('x')} Script not found: {script}")
        return False

    logger.info(f"  Script: {script}")

    if dry_run:
        logger.info(f"\n  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    DB_HOST={host} DB_PORT={port} DB_NAME={dbname} \\")
        logger.info(f"    DB_USER={user} DB_PASSWORD=****** \\")
        logger.info(f"    python {script}")
        return True

    # Build env overriding DB_* vars to point at the proxy
    env = os.environ.copy()
    env["DB_HOST"] = host
    env["DB_PORT"] = str(port)
    env["DB_NAME"] = dbname
    env["DB_USER"] = user
    env["DB_PASSWORD"] = password

    logger.info(f"  Running add_missing_columns.py ...")
    try:
        result = subprocess.run(
            [sys.executable, script],
            capture_output=True,
            text=True,
            timeout=60,
            env=env,
            cwd=os.path.join(project_root, "backend"),
        )
    except subprocess.TimeoutExpired:
        logger.error(f"  {c_red('x')} Script timed out.")
        return False

    # Show output
    if result.stdout:
        for line in result.stdout.strip().split("\n"):
            logger.info(f"    {line}")
    if result.stderr:
        for line in result.stderr.strip().split("\n"):
            if "ERROR" in line.upper():
                logger.error(f"    {line}")
            else:
                logger.info(f"    {line}")

    if result.returncode == 0:
        logger.info(f"  {c_green('ok')} Missing columns step completed.")
        return True
    else:
        logger.error(f"  {c_red('x')} Script exited with code {result.returncode}.")
        return False


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
def verify_schema(
    host: str, port: int, user: str, dbname: str, password: str,
) -> Optional[int]:
    """Count and list tables in the public schema."""
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Verification  -  Table Inventory')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    rc, stdout, stderr = run_psql(
        host, port, user, dbname, password,
        command=(
            "SELECT table_name FROM information_schema.tables "
            "WHERE table_schema='public' ORDER BY table_name;"
        ),
    )

    if rc != 0:
        logger.error(f"  {c_red('x')} Could not query tables.")
        if stderr:
            logger.error(f"    {stderr}")
        return None

    # Parse psql output — skip header rows and footer
    lines = [l.strip() for l in stdout.split("\n") if l.strip()]
    # psql tabular output: header, separator (----), data rows, footer (N rows)
    tables = []
    in_data = False
    for line in lines:
        if line.startswith("---"):
            in_data = True
            continue
        if in_data:
            if line.startswith("(") and "row" in line:
                break
            tables.append(line)

    count = len(tables)
    logger.info(f"  Tables in '{dbname}': {c_bold(str(count))}\n")

    for t in tables:
        logger.info(f"    - {t}")

    logger.info("")
    if count >= 25:
        logger.info(f"  {c_green('ok')} Table count looks healthy ({count} tables).")
    elif count > 0:
        logger.info(f"  {c_yellow('!')} Only {count} tables — some migrations may have failed.")
    else:
        logger.info(f"  {c_red('x')} No tables found — schema may not have been applied.")

    return count


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Schema Setup — Phase 2 of ADK RAG Agent database deployment",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup-schema.py                                # interactive
  python setup-schema.py --env environments/usfs.yaml   # explicit YAML
  python setup-schema.py --dry-run                      # preview only
  python setup-schema.py --start-proxy                  # auto-start proxy
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
    parser.add_argument("--no-interactive", action="store_true",
                        help="Exit with error instead of prompting for missing values")

    args = parser.parse_args()

    # --- Banner ---------------------------------------------------------------
    logger.info(f"\n{MAGENTA}{'=' * 64}{NC}")
    logger.info(f"  {c_bold('Schema Setup  -  ADK RAG Agent')}")
    logger.info(f"  Phase 2: Apply Schema, Migrations & Column Fixes")
    if args.dry_run:
        logger.info(f"  {c_yellow('MODE: DRY RUN  (no changes will be made)')}")
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

    # --- Check prerequisites --------------------------------------------------
    logger.info(f"{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Pre-flight Checks')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    # psql available?
    psql_ok = check_psql_available()
    if not psql_ok:
        if args.dry_run:
            logger.info(f"  {c_yellow('[DRY RUN]')} psql not found — skipping (not needed for dry run).")
        else:
            logger.error(f"  Install with: sudo apt-get install -y postgresql-client")
            sys.exit(1)

    # cloud-sql-proxy available? (check early, install if needed)
    proxy_binary = "cloud-sql-proxy"  # default
    if args.dry_run:
        path = _find_cloud_sql_proxy()
        if path:
            logger.info(f"  {c_green('ok')} cloud-sql-proxy found at {path}")
        else:
            logger.info(f"  {c_yellow('[DRY RUN]')} cloud-sql-proxy not found — skipping (not needed for dry run).")
    else:
        proxy_binary = ensure_cloud_sql_proxy(no_interactive=args.no_interactive)

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
            logger.error(f"    3. User '{user}' and password are correct")
            sys.exit(1)

    # --- Confirmation ---------------------------------------------------------
    if not args.dry_run and not args.no_interactive:
        if not confirm("Proceed with schema setup?", default_yes=True):
            logger.info(f"\n  {c_yellow('Aborted by user.')}")
            sys.exit(0)

    tracker = DeploymentTracker()

    # === STEP 1: Base Schema ==================================================
    schema_file = os.path.join(root, "backend", "init_postgresql_schema.sql")
    ok = apply_base_schema(host, port, user, dbname, password, schema_file, args.dry_run)
    if ok:
        tracker.add_created("Base schema (init_postgresql_schema.sql)")
    else:
        tracker.add_failed("Base schema (init_postgresql_schema.sql)")
        tracker.print_summary()
        sys.exit(1)

    # === STEP 2: Migrations ===================================================
    migrations_dir = os.path.join(root, "backend", "src", "database", "migrations")
    ok = run_migrations(host, port, user, dbname, password, migrations_dir, args.dry_run, tracker)
    if not ok:
        logger.error(f"\n  {c_yellow('!')} Some migrations failed.  Continuing to Step 3 ...")

    # === STEP 3: Add Missing Columns ==========================================
    ok = run_add_missing_columns(host, port, user, dbname, password, root, args.dry_run)
    if ok:
        tracker.add_created("Add missing columns (corpus_metadata)")
    else:
        tracker.add_failed("Add missing columns (corpus_metadata)")

    # === VERIFICATION =========================================================
    if not args.dry_run:
        verify_schema(host, port, user, dbname, password)

    # === SUMMARY ==============================================================
    tracker.print_summary()

    # --- Next steps -----------------------------------------------------------
    if not args.dry_run and tracker.created:
        conn = cfg["connection_name"]
        logger.info(f"\n{CYAN}{'_' * 64}{NC}")
        logger.info(f"  {c_bold('Next Steps')}")
        logger.info(f"{CYAN}{'_' * 64}{NC}")
        logger.info(f"")
        logger.info(f"  Phase 3: Sync corpora from Vertex AI")
        logger.info(f"    cd backend")
        logger.info(f"    export PROJECT_ID=\"{cfg['project_id']}\"")
        logger.info(f"    export GOOGLE_CLOUD_LOCATION=\"{cfg['region']}\"")
        logger.info(f"    export DB_HOST=127.0.0.1  DB_PORT={port}")
        logger.info(f"    export DB_NAME={dbname}  DB_USER={user}")
        logger.info(f"    export DB_PASSWORD=\"<password>\"")
        logger.info(f"    python sync_corpora_from_vertex.py")
        logger.info(f"")
        logger.info(f"  Phase 4: Seed users, groups & permissions")
        logger.info(f"    python seed_data.py --env ../environments/usfs.yaml --target cloud")
        logger.info(f"")
        logger.info(f"  Phase 5: Deploy to Cloud Run")
        logger.info(f"    cd ../infrastructure && ./deploy-all.sh")
        logger.info(f"{CYAN}{'_' * 64}{NC}\n")

    sys.exit(0 if not tracker.failed else 1)


if __name__ == "__main__":
    main()
