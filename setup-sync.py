#!/usr/bin/env python3
"""
Corpus Sync Script for ADK RAG Agent
======================================
Automates Phase 3 of database deployment:

  1. Sync corpora from Vertex AI RAG Engine into the database
  2. Verify synced corpora

Requires Cloud SQL Proxy running on localhost (or use --start-proxy).
Requires Application Default Credentials for Vertex AI access.

Usage:
  python setup-sync.py                                # interactive
  python setup-sync.py --env environments/usfs.yaml   # explicit YAML
  python setup-sync.py --dry-run                      # preview only
  python setup-sync.py --start-proxy                  # auto-start proxy
"""

import argparse
import atexit
import getpass
import logging
import os
import platform
import shutil
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
logger = logging.getLogger("setup_sync")

# ---------------------------------------------------------------------------
# ANSI colours (matching setup-cloudsql.py / setup-schema.py)
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
# Deployment Tracker  (same pattern as setup-cloudsql.py / setup-schema.py)
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
        logger.info(f"  {c_bold('CORPUS SYNC SUMMARY')}")
        logger.info(f"{CYAN}{'=' * 64}{NC}")

        if self.created:
            logger.info(f"\n  {c_green('SYNCED')} ({len(self.created)}):")
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
            logger.info(f"  {c_yellow('RESULT: Nothing new synced.')}")
            return True
        else:
            logger.info(f"  {c_green('RESULT: Phase 3 completed successfully!')}")
            return True


# ---------------------------------------------------------------------------
# Config loading  (reused from setup-schema.py)
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
    vai = config.get("vertex_ai", {})
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
        "vertex_location": vai.get("location", config.get("region", "")),
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
        ("vertex_location", "Vertex AI location"),
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
    logger.info(f"  Vertex AI      : {cfg['project_id']} / {cfg['vertex_location']}")
    logger.info(f"  Account        : {cfg.get('account_env', 'N/A')}")
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
    path = shutil.which("cloud-sql-proxy")
    if path:
        return path
    for candidate in ["/usr/local/bin/cloud-sql-proxy", "./cloud-sql-proxy"]:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def _install_cloud_sql_proxy() -> Optional[str]:
    """Download and install cloud-sql-proxy. Returns path on success, None on failure."""
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
    logger.error(f"  {c_red('x')} psql not found.")
    logger.error(f"  Install with: sudo apt-get install -y postgresql-client")
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
# Pre-flight: ADC check
# ---------------------------------------------------------------------------
def check_adc_credentials() -> bool:
    """Check if Application Default Credentials are configured."""
    try:
        result = subprocess.run(
            ["gcloud", "auth", "application-default", "print-access-token"],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode == 0 and result.stdout.strip():
            token_preview = result.stdout.strip()[:12] + "..."
            logger.info(f"  {c_green('ok')} Application Default Credentials configured (token: {token_preview})")
            return True
    except FileNotFoundError:
        logger.error(f"  {c_red('x')} gcloud CLI not found.")
        return False
    except subprocess.TimeoutExpired:
        logger.error(f"  {c_red('x')} gcloud auth check timed out.")
        return False

    logger.error(f"  {c_red('x')} Application Default Credentials not configured.")
    logger.error(f"  Run: gcloud auth application-default login")
    return False


# ---------------------------------------------------------------------------
# Pre-flight: Python dependency check
# ---------------------------------------------------------------------------
def check_python_deps() -> bool:
    """Check that required Python packages are importable."""
    missing = []
    deps = [
        ("vertexai", "google-cloud-aiplatform"),
        ("google.auth", "google-auth"),
        ("psycopg2", "psycopg2-binary"),
    ]

    for module_name, pip_name in deps:
        try:
            __import__(module_name)
            logger.info(f"  {c_green('ok')} {module_name}")
        except ImportError:
            logger.error(f"  {c_red('x')} {module_name} not found (pip install {pip_name})")
            missing.append(pip_name)

    if missing:
        logger.error(f"\n  {c_red('x')} Missing Python dependencies.")
        logger.error(f"  Install with: pip install {' '.join(missing)}")
        logger.error(f"  Or: pip install -r backend/requirements.txt")
        return False
    return True


# ---------------------------------------------------------------------------
# Step 1/2: Sync corpora from Vertex AI
# ---------------------------------------------------------------------------
def run_sync(
    project_id: str,
    location: str,
    host: str,
    port: int,
    user: str,
    dbname: str,
    password: str,
    account_env: str,
    project_root: str,
    dry_run: bool,
    tracker: DeploymentTracker,
) -> bool:
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 1/2  -  Sync Corpora from Vertex AI')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    logger.info(f"  Project  : {project_id}")
    logger.info(f"  Location : {location}")
    logger.info(f"  Database : {dbname}@{host}:{port}")
    logger.info(f"  Account  : {account_env}")

    if dry_run:
        logger.info(f"\n  {c_yellow('[DRY RUN]')} Would run:")
        logger.info(f"    Set environment variables:")
        logger.info(f"      DB_HOST={host}  DB_PORT={port}  DB_NAME={dbname}")
        logger.info(f"      DB_USER={user}  DB_PASSWORD=******")
        logger.info(f"      PROJECT_ID={project_id}")
        logger.info(f"      GOOGLE_CLOUD_LOCATION={location}")
        logger.info(f"      VERTEXAI_PROJECT={project_id}")
        logger.info(f"      VERTEXAI_LOCATION={location}")
        logger.info(f"      ACCOUNT_ENV={account_env}")
        logger.info(f"    Import CorpusSyncService from backend/src/services/")
        logger.info(f"    Call CorpusSyncService.sync_from_vertex('{project_id}', '{location}')")
        tracker.add_created("Corpus sync (Vertex AI -> database)")
        return True

    # Set environment variables BEFORE importing backend modules.
    # This is critical because database.connection reads DB_* at module level.
    os.environ["DB_HOST"] = host
    os.environ["DB_PORT"] = str(port)
    os.environ["DB_NAME"] = dbname
    os.environ["DB_USER"] = user
    os.environ["DB_PASSWORD"] = password
    os.environ["PROJECT_ID"] = project_id
    os.environ["GOOGLE_CLOUD_LOCATION"] = location
    os.environ["VERTEXAI_PROJECT"] = project_id
    os.environ["VERTEXAI_LOCATION"] = location
    os.environ["ACCOUNT_ENV"] = account_env

    # Add backend/src to sys.path for imports
    backend_src = os.path.join(project_root, "backend", "src")
    if backend_src not in sys.path:
        sys.path.insert(0, backend_src)

    logger.info(f"\n  Importing CorpusSyncService ...")
    try:
        from services.corpus_sync_service import CorpusSyncService
    except ImportError as e:
        logger.error(f"  {c_red('x')} Failed to import CorpusSyncService: {e}")
        logger.error(f"  Ensure backend dependencies are installed: pip install -r backend/requirements.txt")
        tracker.add_failed("Corpus sync (import error)")
        return False

    logger.info(f"  {c_green('ok')} CorpusSyncService imported.")
    logger.info(f"\n  Running sync ...")
    logger.info(f"  (This connects to Vertex AI and the database — may take a moment)\n")

    try:
        result = CorpusSyncService.sync_from_vertex(project_id, location)
    except Exception as e:
        logger.error(f"  {c_red('x')} Sync failed with exception: {e}")
        tracker.add_failed("Corpus sync (exception)")
        return False

    # Display results
    status = result.get("status", "unknown")
    vertex_count = result.get("vertex_count", 0)
    db_active = result.get("db_active_count", 0)
    added = result.get("added", 0)
    updated = result.get("updated", 0)
    deactivated = result.get("deactivated", 0)
    errors = result.get("errors", [])

    logger.info(f"  {c_bold('Sync Results:')}")
    logger.info(f"    Status              : {_format_status(status)}")
    logger.info(f"    Vertex AI corpora   : {vertex_count}")
    logger.info(f"    DB active corpora   : {db_active}")
    logger.info(f"    Added               : {c_green(str(added)) if added else '0'}")
    logger.info(f"    Updated             : {c_cyan(str(updated)) if updated else '0'}")
    logger.info(f"    Deactivated         : {c_yellow(str(deactivated)) if deactivated else '0'}")

    if errors:
        logger.info(f"    Errors              : {c_red(str(len(errors)))}")
        for err in errors:
            logger.error(f"      - {err}")

    # Update tracker
    if added > 0:
        tracker.add_created(f"Added {added} new corpora from Vertex AI")
    if updated > 0:
        tracker.add_created(f"Updated {updated} existing corpora")
    if deactivated > 0:
        tracker.add_created(f"Deactivated {deactivated} removed corpora")
    if added == 0 and updated == 0 and deactivated == 0 and status != "error":
        tracker.add_skipped("No changes needed (database already in sync)")

    if status == "error":
        tracker.add_failed("Corpus sync failed")
        return False
    elif status == "partial":
        tracker.add_created("Corpus sync (partial — some errors)")
        return True  # partial success is still a success
    else:
        if not errors:
            tracker.add_created("Corpus sync completed")
        return True


def _format_status(status: str) -> str:
    """Format sync status with color."""
    s = status.upper()
    if status == "success":
        return c_green(s)
    elif status == "partial":
        return c_yellow(s)
    elif status == "error":
        return c_red(s)
    return s


# ---------------------------------------------------------------------------
# Step 2/2: Verify synced corpora
# ---------------------------------------------------------------------------
def verify_corpora(
    host: str, port: int, user: str, dbname: str, password: str,
    dry_run: bool,
) -> Optional[int]:
    """Query and list corpora in the database."""
    logger.info(f"\n{BLUE}{'_' * 64}{NC}")
    logger.info(f"  {c_bold('Step 2/2  -  Verify Synced Corpora')}")
    logger.info(f"{BLUE}{'_' * 64}{NC}\n")

    if dry_run:
        logger.info(f"  {c_yellow('[DRY RUN]')} Would query:")
        logger.info(f"    SELECT id, name, display_name, is_active, vertex_corpus_id, gcs_bucket")
        logger.info(f"    FROM corpora ORDER BY name;")
        return None

    query = (
        "SELECT id, name, display_name, is_active, "
        "COALESCE(SUBSTRING(vertex_corpus_id FROM '.*/([^/]+)$'), 'N/A') AS corpus_id_short, "
        "COALESCE(gcs_bucket, 'N/A') AS gcs_bucket "
        "FROM corpora ORDER BY name;"
    )

    rc, stdout, stderr = run_psql(host, port, user, dbname, password, command=query)

    if rc != 0:
        logger.error(f"  {c_red('x')} Could not query corpora table.")
        if stderr:
            logger.error(f"    {stderr}")
        return None

    # Display raw psql output (it formats nicely as a table)
    if stdout:
        for line in stdout.split("\n"):
            logger.info(f"    {line}")
    else:
        logger.info(f"  {c_yellow('!')} No corpora found in database.")

    # Count active corpora
    count_query = "SELECT COUNT(*) as cnt FROM corpora WHERE is_active = true;"
    rc2, stdout2, stderr2 = run_psql(host, port, user, dbname, password, command=count_query)

    count = 0
    if rc2 == 0 and stdout2:
        # Parse psql output for count
        for line in stdout2.split("\n"):
            line = line.strip()
            if line.isdigit():
                count = int(line)
                break

    logger.info(f"\n  Active corpora: {c_bold(str(count))}")

    if count > 0:
        logger.info(f"  {c_green('ok')} Corpora synced successfully.")
    else:
        logger.info(f"  {c_yellow('!')} No active corpora — check if Vertex AI corpora exist in the project.")

    return count


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Corpus Sync — Phase 3 of ADK RAG Agent database deployment",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup-sync.py                                # interactive
  python setup-sync.py --env environments/usfs.yaml   # explicit YAML
  python setup-sync.py --dry-run                      # preview only
  python setup-sync.py --start-proxy                  # auto-start proxy
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
    logger.info(f"  {c_bold('Corpus Sync  -  ADK RAG Agent')}")
    logger.info(f"  Phase 3: Sync Corpora from Vertex AI")
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
    project_id = cfg["project_id"]
    location = cfg["vertex_location"]
    account_env = cfg["account_env"]

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

    # ADC credentials?
    adc_ok = check_adc_credentials()
    if not adc_ok:
        if args.dry_run:
            logger.info(f"  {c_yellow('[DRY RUN]')} ADC not configured — skipping (not needed for dry run).")
        else:
            logger.error(f"\n  {c_red('x')} Application Default Credentials required for Vertex AI access.")
            logger.error(f"  Run: gcloud auth application-default login")
            sys.exit(1)

    # Python dependencies?
    if not args.dry_run:
        deps_ok = check_python_deps()
        if not deps_ok:
            sys.exit(1)
    else:
        logger.info(f"  {c_yellow('[DRY RUN]')} Skipping Python dependency check.")

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
        if not confirm("Proceed with corpus sync?", default_yes=True):
            logger.info(f"\n  {c_yellow('Aborted by user.')}")
            sys.exit(0)

    tracker = DeploymentTracker()

    # === STEP 1/2: Sync ======================================================
    ok = run_sync(
        project_id, location, host, port, user, dbname, password,
        account_env, root, args.dry_run, tracker,
    )

    # === STEP 2/2: Verify =====================================================
    verify_corpora(host, port, user, dbname, password, args.dry_run)

    # === SUMMARY ==============================================================
    tracker.print_summary()

    # --- Next steps -----------------------------------------------------------
    if not args.dry_run and not tracker.failed:
        logger.info(f"\n{CYAN}{'_' * 64}{NC}")
        logger.info(f"  {c_bold('Next Steps')}")
        logger.info(f"{CYAN}{'_' * 64}{NC}")
        logger.info(f"")
        logger.info(f"  Phase 4: Seed users, groups & permissions")
        logger.info(f"    python seed_data.py --env environments/usfs.yaml --target cloud")
        logger.info(f"")
        logger.info(f"  Phase 5: Deploy to Cloud Run")
        logger.info(f"    cd infrastructure && ./deploy-all.sh")
        logger.info(f"{CYAN}{'_' * 64}{NC}\n")

    sys.exit(0 if not tracker.failed else 1)


if __name__ == "__main__":
    main()
