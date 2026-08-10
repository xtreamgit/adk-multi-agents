#!/usr/bin/env python3
"""
Pre-Deployment Preparation Script for ADK RAG Agent
=====================================================
Automates Phase 5 of database deployment:

  1. Load and validate environment config
  2. Resolve missing values (PROJECT_NUMBER, IAP_ADMIN_USER)
  3. Regenerate deployment.config
  4. Validate secrets.env
  5. Fix hardcoded bucket names in infrastructure.sh
  6. Pre-flight checks (gcloud auth, required files)
  7. Optionally invoke deploy-all.sh

Requires gcloud CLI authenticated and configured.

Usage:
  python setup-deploy.py                                # prepare only (interactive)
  python setup-deploy.py --env environments/usfs.yaml   # explicit YAML
  python setup-deploy.py --dry-run                      # preview only
  python setup-deploy.py --deploy                       # prepare + deploy
  python setup-deploy.py --deploy --skip-apis           # deploy with skip flags
  python setup-deploy.py --run-check                    # run pre-deploy-check.sh
"""

import argparse
import logging
import os
import re
import secrets as secrets_mod
import shutil
import subprocess
import sys
import textwrap
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import yaml

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("setup_deploy")

# ---------------------------------------------------------------------------
# ANSI colours (matching setup-cloudsql.py / setup-schema.py / setup-sync.py)
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
# Deployment Tracker (matching other setup scripts)
# ---------------------------------------------------------------------------
class DeploymentTracker:
    """Track deployment steps with pass/fail status."""

    def __init__(self):
        self.steps: List[Tuple[str, str, str]] = []  # (step, status, detail)
        self.start_time = datetime.now()

    def add(self, step: str, status: str, detail: str = ""):
        self.steps.append((step, status, detail))

    def ok(self, step: str, detail: str = ""):
        self.add(step, "OK", detail)
        logger.info(f"  {c_green('OK')}  {step}" + (f" — {detail}" if detail else ""))

    def skip(self, step: str, detail: str = ""):
        self.add(step, "SKIP", detail)
        logger.info(
            f"  {c_yellow('SKIP')}  {step}" + (f" — {detail}" if detail else "")
        )

    def fail(self, step: str, detail: str = ""):
        self.add(step, "FAIL", detail)
        logger.info(
            f"  {c_red('FAIL')}  {step}" + (f" — {detail}" if detail else "")
        )

    def print_summary(self):
        elapsed = (datetime.now() - self.start_time).total_seconds()
        ok_count = sum(1 for _, s, _ in self.steps if s == "OK")
        fail_count = sum(1 for _, s, _ in self.steps if s == "FAIL")
        skip_count = sum(1 for _, s, _ in self.steps if s == "SKIP")

        logger.info("")
        logger.info(f"{CYAN}{'=' * 70}{NC}")
        logger.info(f"{CYAN}  Pre-Deployment Preparation Summary{NC}")
        logger.info(f"{CYAN}{'=' * 70}{NC}")

        for step, status, detail in self.steps:
            if status == "OK":
                icon = c_green("OK")
            elif status == "FAIL":
                icon = c_red("FAIL")
            else:
                icon = c_yellow("SKIP")
            suffix = f" — {detail}" if detail else ""
            logger.info(f"  {icon:>20s}  {step}{suffix}")

        logger.info(f"{CYAN}{'=' * 70}{NC}")
        logger.info(
            f"  {c_green(f'{ok_count} passed')}  "
            f"{c_red(f'{fail_count} failed')}  "
            f"{c_yellow(f'{skip_count} skipped')}  "
            f"({elapsed:.1f}s)"
        )
        logger.info(f"{CYAN}{'=' * 70}{NC}")

        return fail_count == 0


# ---------------------------------------------------------------------------
# Project root detection
# ---------------------------------------------------------------------------
def find_project_root() -> str:
    """Find the project root (contains infrastructure/ and backend/)."""
    current = os.path.dirname(os.path.abspath(__file__))
    for _ in range(5):
        if os.path.isdir(os.path.join(current, "infrastructure")) and os.path.isdir(
            os.path.join(current, "backend")
        ):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    return os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------------------
# Config loader
# ---------------------------------------------------------------------------
def load_config(env_path: str) -> dict:
    """Load client environment YAML."""
    abs_path = os.path.abspath(env_path)
    if not os.path.exists(abs_path):
        logger.error(f"{c_red('ERROR')} Environment file not found: {abs_path}")
        sys.exit(1)

    with open(abs_path, "r") as f:
        config = yaml.safe_load(f)

    required = ["client_name", "project_id", "region", "organization_domain"]
    missing = [k for k in required if not config.get(k)]
    if missing:
        logger.error(f"{c_red('ERROR')} Missing required fields: {', '.join(missing)}")
        sys.exit(1)

    return config


# ---------------------------------------------------------------------------
# Helper: run shell command
# ---------------------------------------------------------------------------
def run_cmd(
    cmd: str, capture: bool = True, check: bool = True, timeout: int = 120
) -> subprocess.CompletedProcess:
    """Run a shell command and return result."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=capture,
            text=True,
            timeout=timeout,
        )
        if check and result.returncode != 0:
            return result
        return result
    except subprocess.TimeoutExpired:
        logger.error(f"{c_red('ERROR')} Command timed out: {cmd}")
        return subprocess.CompletedProcess(cmd, 1, "", "Timeout")


# ---------------------------------------------------------------------------
# Helper: update YAML field
# ---------------------------------------------------------------------------
def update_yaml_field(yaml_path: str, field: str, value: str, dry_run: bool = False):
    """Update a top-level field in the YAML file, preserving formatting."""
    with open(yaml_path, "r") as f:
        content = f.read()

    # Match the field line — handles quoted and unquoted, empty and non-empty values
    # Pattern: field: "value" or field: value or field: "" or field:
    pattern = rf'^({re.escape(field)}:\s*).*$'
    # Check if value needs quoting
    quoted_value = f'"{value}"' if value else '""'
    replacement = rf'\g<1>{quoted_value}'

    new_content, count = re.subn(pattern, replacement, content, count=1, flags=re.MULTILINE)

    if count == 0:
        logger.warning(f"  {c_yellow('WARNING')} Field '{field}' not found in {yaml_path}")
        return False

    if dry_run:
        logger.info(f"  {c_yellow('[DRY RUN]')} Would set {field}: {quoted_value}")
        return True

    with open(yaml_path, "w") as f:
        f.write(new_content)
    return True


# ---------------------------------------------------------------------------
# Step 1: Load & validate config
# ---------------------------------------------------------------------------
def step_load_config(args, tracker: DeploymentTracker) -> dict:
    """Load and validate environment config."""
    logger.info("")
    logger.info(f"{CYAN}{'=' * 70}{NC}")
    logger.info(f"{CYAN}  Phase 5: Pre-Deployment Preparation{NC}")
    logger.info(f"{CYAN}{'=' * 70}{NC}")
    logger.info("")

    config = load_config(args.env)
    logger.info(f"  Client:       {c_blue(config['client_name'])}")
    logger.info(f"  Project:      {c_blue(config['project_id'])}")
    logger.info(f"  Region:       {c_blue(config['region'])}")
    logger.info(f"  Domain:       {c_blue(config['organization_domain'])}")
    logger.info(f"  IAP Admin:    {c_blue(config.get('iap_admin_user') or '<not set>')}")
    logger.info(f"  Project #:    {c_blue(config.get('project_number') or '<not set>')}")
    logger.info("")

    tracker.ok("Load config", config["client_name"])
    return config


# ---------------------------------------------------------------------------
# Step 2: Resolve missing values
# ---------------------------------------------------------------------------
def step_resolve_missing(
    args, config: dict, tracker: DeploymentTracker, project_root: str
) -> dict:
    """Resolve PROJECT_NUMBER and IAP_ADMIN_USER if empty."""
    logger.info(f"{BLUE}Step 2: Resolve Missing Values{NC}")
    logger.info(f"{BLUE}{'─' * 50}{NC}")

    yaml_path = os.path.abspath(args.env)
    yaml_modified = False

    # --- PROJECT_NUMBER ---
    project_number = config.get("project_number") or ""
    if not project_number.strip():
        logger.info("  Resolving PROJECT_NUMBER from gcloud...")
        result = run_cmd(
            f"gcloud projects describe {config['project_id']} --format='value(projectNumber)' 2>/dev/null",
            check=False,
        )
        if result.returncode == 0 and result.stdout.strip():
            project_number = result.stdout.strip()
            logger.info(f"  {c_green('Found')}: PROJECT_NUMBER = {project_number}")
            config["project_number"] = project_number
            if update_yaml_field(yaml_path, "project_number", project_number, dry_run=args.dry_run):
                yaml_modified = True
            tracker.ok("Resolve PROJECT_NUMBER", project_number)
        else:
            logger.warning(
                f"  {c_yellow('WARNING')} Could not auto-derive PROJECT_NUMBER"
            )
            tracker.fail("Resolve PROJECT_NUMBER", "gcloud lookup failed")
    else:
        logger.info(f"  PROJECT_NUMBER already set: {project_number}")
        tracker.ok("Resolve PROJECT_NUMBER", f"already set: {project_number}")

    # --- IAP_ADMIN_USER ---
    iap_admin = config.get("iap_admin_user") or ""
    if not iap_admin.strip():
        if args.no_interactive:
            logger.error(
                f"  {c_red('ERROR')} IAP_ADMIN_USER is empty and --no-interactive is set"
            )
            tracker.fail("Resolve IAP_ADMIN_USER", "empty + non-interactive")
        else:
            domain = config.get("organization_domain", "example.com")
            default_admin = f"admin@{domain}"
            logger.info(f"  IAP_ADMIN_USER is not set.")
            logger.info(
                f"  This is the email for the initial IAP admin (OAuth consent screen contact)."
            )
            try:
                user_input = input(
                    f"  Enter IAP admin email [{default_admin}]: "
                ).strip()
            except (EOFError, KeyboardInterrupt):
                user_input = ""
            iap_admin = user_input if user_input else default_admin

            config["iap_admin_user"] = iap_admin
            if update_yaml_field(yaml_path, "iap_admin_user", iap_admin, dry_run=args.dry_run):
                yaml_modified = True

            if args.dry_run:
                tracker.ok("Resolve IAP_ADMIN_USER", f"[DRY RUN] would set: {iap_admin}")
            else:
                tracker.ok("Resolve IAP_ADMIN_USER", iap_admin)
    else:
        logger.info(f"  IAP_ADMIN_USER already set: {iap_admin}")
        tracker.ok("Resolve IAP_ADMIN_USER", f"already set: {iap_admin}")

    if yaml_modified and not args.dry_run:
        logger.info(f"  {c_green('Updated')}: {yaml_path}")

    logger.info("")
    return config


# ---------------------------------------------------------------------------
# Step 3: Regenerate deployment.config
# ---------------------------------------------------------------------------
def step_regenerate_config(
    args, config: dict, tracker: DeploymentTracker, project_root: str
):
    """Regenerate deployment.config via deploy_env_config.py."""
    logger.info(f"{BLUE}Step 3: Regenerate deployment.config{NC}")
    logger.info(f"{BLUE}{'─' * 50}{NC}")

    deploy_env_script = os.path.join(project_root, "backend", "deploy_env_config.py")
    if not os.path.exists(deploy_env_script):
        tracker.fail("Regenerate deployment.config", "deploy_env_config.py not found")
        logger.info("")
        return

    cmd = f"python {deploy_env_script} --env {os.path.abspath(args.env)}"
    if args.dry_run:
        cmd += " --dry-run"

    logger.info(f"  Running: {cmd}")
    result = run_cmd(cmd, check=False, timeout=30)

    if result.returncode == 0:
        # Verify the generated file
        config_path = os.path.join(project_root, "deployment.config")
        if os.path.exists(config_path) and not args.dry_run:
            with open(config_path, "r") as f:
                content = f.read()
            pn_match = re.search(r'PROJECT_NUMBER="([^"]*)"', content)
            iap_match = re.search(r'IAP_ADMIN_USER="([^"]*)"', content)
            pn_val = pn_match.group(1) if pn_match else ""
            iap_val = iap_match.group(1) if iap_match else ""

            issues = []
            if not pn_val:
                issues.append("PROJECT_NUMBER still empty")
            if not iap_val:
                issues.append("IAP_ADMIN_USER still empty")

            if issues:
                tracker.fail(
                    "Regenerate deployment.config", "; ".join(issues)
                )
            else:
                tracker.ok(
                    "Regenerate deployment.config",
                    f"PN={pn_val}, IAP={iap_val}",
                )
        else:
            mode = "[DRY RUN]" if args.dry_run else ""
            tracker.ok("Regenerate deployment.config", mode)
    else:
        tracker.fail(
            "Regenerate deployment.config",
            result.stderr.strip()[:100] if result.stderr else "unknown error",
        )

    # Print relevant output lines
    if result.stdout:
        for line in result.stdout.strip().split("\n"):
            if "Generated" in line or "DRY RUN" in line or "✓" in line:
                logger.info(f"  {line.strip()}")

    logger.info("")


# ---------------------------------------------------------------------------
# Step 4: Validate secrets.env
# ---------------------------------------------------------------------------
def step_validate_secrets(
    args, tracker: DeploymentTracker, project_root: str
):
    """Validate secrets.env exists and has SECRET_KEY."""
    logger.info(f"{BLUE}Step 4: Validate secrets.env{NC}")
    logger.info(f"{BLUE}{'─' * 50}{NC}")

    secrets_path = os.path.join(project_root, "secrets.env")

    if os.path.exists(secrets_path):
        with open(secrets_path, "r") as f:
            content = f.read()
        match = re.search(r"^SECRET_KEY=(.+)$", content, re.MULTILINE)
        if match and match.group(1).strip():
            key_preview = match.group(1).strip()[:8] + "..."
            logger.info(f"  {c_green('OK')} secrets.env exists with SECRET_KEY={key_preview}")
            tracker.ok("Validate secrets.env", "SECRET_KEY present")
        else:
            # SECRET_KEY missing or empty — generate one
            new_key = secrets_mod.token_urlsafe(32)
            if args.dry_run:
                logger.info(
                    f"  {c_yellow('[DRY RUN]')} Would generate SECRET_KEY"
                )
                tracker.ok("Validate secrets.env", "[DRY RUN] would generate key")
            else:
                with open(secrets_path, "w") as f:
                    f.write(f"SECRET_KEY={new_key}\n")
                logger.info(f"  {c_green('Generated')} SECRET_KEY in secrets.env")
                tracker.ok("Validate secrets.env", "generated new SECRET_KEY")
    else:
        # Create secrets.env with generated key
        new_key = secrets_mod.token_urlsafe(32)
        if args.dry_run:
            logger.info(
                f"  {c_yellow('[DRY RUN]')} Would create secrets.env with SECRET_KEY"
            )
            tracker.ok("Validate secrets.env", "[DRY RUN] would create file")
        else:
            with open(secrets_path, "w") as f:
                f.write(f"SECRET_KEY={new_key}\n")
            logger.info(f"  {c_green('Created')} secrets.env with SECRET_KEY")
            tracker.ok("Validate secrets.env", "created with new SECRET_KEY")

    logger.info("")


# ---------------------------------------------------------------------------
# Step 5: Fix hardcoded bucket names in infrastructure.sh
# ---------------------------------------------------------------------------
def step_fix_bucket_names(
    args, config: dict, tracker: DeploymentTracker, project_root: str
):
    """Replace hardcoded bucket names in infrastructure.sh with YAML config values."""
    logger.info(f"{BLUE}Step 5: Fix Bucket Names in infrastructure.sh{NC}")
    logger.info(f"{BLUE}{'─' * 50}{NC}")

    infra_path = os.path.join(
        project_root, "infrastructure", "lib", "infrastructure.sh"
    )
    if not os.path.exists(infra_path):
        tracker.fail("Fix bucket names", "infrastructure.sh not found")
        logger.info("")
        return

    with open(infra_path, "r") as f:
        content = f.read()

    # Get bucket names from corpus_to_bucket_mapping
    bucket_mapping = config.get("corpus_to_bucket_mapping", {})
    if not bucket_mapping:
        logger.info("  No corpus_to_bucket_mapping in YAML — skipping bucket fix")
        tracker.skip("Fix bucket names", "no corpus_to_bucket_mapping in YAML")
        logger.info("")
        return

    bucket_names = list(bucket_mapping.values())
    logger.info(f"  Buckets from YAML: {', '.join(bucket_names)}")

    # Check if the old hardcoded bucket names are still present
    old_buckets = ["ipad-book-collection", "develom-documents"]
    has_old = any(b in content for b in old_buckets)
    has_new = all(b in content for b in bucket_names)

    if has_new and not has_old:
        logger.info(f"  {c_green('OK')} Bucket names already updated")
        tracker.ok("Fix bucket names", "already up to date")
        logger.info("")
        return

    if not has_old:
        logger.info(f"  Old bucket names not found — checking for any bucket references")
        # Try to detect any existing bucket section
        if "CORPUS_BUCKETS=" in content:
            logger.info(f"  {c_green('OK')} CORPUS_BUCKETS already configured")
            tracker.ok("Fix bucket names", "CORPUS_BUCKETS already present")
            logger.info("")
            return

    # Build the replacement section
    bucket_list_str = " ".join(f'"{b}"' for b in bucket_names)
    bucket_comment = ", ".join(bucket_names)

    new_bucket_section = f"""    # Bucket-level IAM for corpus GCS buckets (from environments/*.yaml corpus_to_bucket_mapping)
    # Buckets: {bucket_comment}
    CORPUS_BUCKETS=({bucket_list_str})
    for bucket in "${{CORPUS_BUCKETS[@]}}"; do
        for sa in "$RAG_AGENT_SA" "$RAG_AGENT1_SA" "$RAG_AGENT2_SA" "$RAG_AGENT3_SA"; do
            echo "  Granting storage.objectViewer on gs://$bucket to $sa..."
            gcloud storage buckets add-iam-policy-binding "gs://$bucket" \\
                --member="serviceAccount:${{sa}}" \\
                --role="roles/storage.objectViewer" \\
                --quiet 2>/dev/null || true
        done
    done"""

    # Find the old bucket sections to replace
    # Pattern: from the first "Bucket-level IAM" comment to just before "Basic permissions for Backend SA"
    old_pattern = re.compile(
        r'(    # Bucket-level IAM for ai-books.*?(?=\n    # Basic permissions for Backend SA))',
        re.DOTALL,
    )

    match = old_pattern.search(content)
    if match:
        old_section = match.group(1)
        # Show diff preview
        logger.info(f"\n  {c_yellow('Replacing bucket IAM section:')}")
        logger.info(f"  {c_red('--- OLD (removed):')}")
        for line in old_section.strip().split("\n")[:6]:
            logger.info(f"    {c_red(line.rstrip())}")
        if old_section.strip().count("\n") > 5:
            logger.info(f"    {c_red('...')}")
        logger.info(f"  {c_green('+++ NEW (added):')}")
        for line in new_bucket_section.strip().split("\n")[:6]:
            logger.info(f"    {c_green(line.rstrip())}")
        if new_bucket_section.strip().count("\n") > 5:
            logger.info(f"    {c_green('...')}")
        logger.info("")

        if args.dry_run:
            logger.info(f"  {c_yellow('[DRY RUN]')} Would update infrastructure.sh")
            tracker.ok("Fix bucket names", f"[DRY RUN] {len(bucket_names)} buckets")
        else:
            new_content = content[:match.start(1)] + new_bucket_section + "\n\n" + content[match.end(1):]
            with open(infra_path, "w") as f:
                f.write(new_content)
            logger.info(f"  {c_green('Updated')}: {infra_path}")
            tracker.ok("Fix bucket names", f"{len(bucket_names)} buckets configured")
    else:
        # Fallback: try a simpler replacement approach — replace individual bucket names
        # This handles cases where the section structure doesn't match the expected pattern
        logger.info("  Section pattern not matched — trying individual bucket replacement")

        if has_old:
            if args.dry_run:
                logger.info(f"  {c_yellow('[DRY RUN]')} Would replace old bucket references")
                tracker.ok("Fix bucket names", "[DRY RUN] would replace")
            else:
                # Replace the two old hardcoded bucket sections with the new generic section
                # Find from first old bucket reference to the line before "Basic permissions"
                lines = content.split("\n")
                start_idx = None
                end_idx = None
                for i, line in enumerate(lines):
                    if "ipad-book-collection" in line and start_idx is None:
                        # Go back to find the comment line
                        for j in range(i, max(i - 3, -1), -1):
                            if "Bucket-level IAM" in lines[j]:
                                start_idx = j
                                break
                        if start_idx is None:
                            start_idx = i
                    if "Basic permissions for Backend SA" in line and start_idx is not None:
                        end_idx = i
                        break

                if start_idx is not None and end_idx is not None:
                    new_lines = (
                        lines[:start_idx]
                        + new_bucket_section.split("\n")
                        + [""]
                        + lines[end_idx:]
                    )
                    with open(infra_path, "w") as f:
                        f.write("\n".join(new_lines))
                    logger.info(f"  {c_green('Updated')}: {infra_path}")
                    tracker.ok("Fix bucket names", f"{len(bucket_names)} buckets configured")
                else:
                    logger.warning(
                        f"  {c_yellow('WARNING')} Could not locate bucket section boundaries"
                    )
                    tracker.fail("Fix bucket names", "section boundaries not found")
        else:
            tracker.skip("Fix bucket names", "no old bucket references found")

    logger.info("")


# ---------------------------------------------------------------------------
# Step 6: Pre-flight checks
# ---------------------------------------------------------------------------
def step_preflight_checks(
    args, config: dict, tracker: DeploymentTracker, project_root: str
):
    """Run pre-flight checks for deployment."""
    logger.info(f"{BLUE}Step 6: Pre-flight Checks{NC}")
    logger.info(f"{BLUE}{'─' * 50}{NC}")

    all_ok = True

    # Check gcloud auth
    result = run_cmd(
        "gcloud auth list --filter=status=ACTIVE --format='value(account)' 2>/dev/null",
        check=False,
    )
    if result.returncode == 0 and "@" in (result.stdout or ""):
        account = result.stdout.strip().split("\n")[0]
        logger.info(f"  {c_green('OK')} gcloud authenticated as {account}")
    else:
        logger.info(f"  {c_red('FAIL')} gcloud not authenticated — run: gcloud auth login")
        all_ok = False

    # Check ADC
    result = run_cmd(
        "gcloud auth application-default print-access-token 2>/dev/null",
        check=False,
    )
    if result.returncode == 0 and result.stdout.strip():
        logger.info(f"  {c_green('OK')} Application Default Credentials configured")
    else:
        logger.info(
            f"  {c_red('FAIL')} ADC not configured — run: gcloud auth application-default login"
        )
        all_ok = False

    # Check required files
    required_files = [
        ("backend/cloudbuild.yaml", "Backend Cloud Build config"),
        ("frontend/cloudbuild.yaml", "Frontend Cloud Build config"),
        ("backend/Dockerfile", "Backend Dockerfile"),
        ("frontend/Dockerfile", "Frontend Dockerfile"),
        ("deployment.config", "Deployment config"),
        ("secrets.env", "Secrets file"),
    ]

    for rel_path, description in required_files:
        full_path = os.path.join(project_root, rel_path)
        if os.path.exists(full_path):
            logger.info(f"  {c_green('OK')} {description} ({rel_path})")
        else:
            logger.info(f"  {c_red('MISSING')} {description} ({rel_path})")
            all_ok = False

    # Check deployment.config has required values
    config_path = os.path.join(project_root, "deployment.config")
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            dc_content = f.read()
        required_vars = [
            "PROJECT_ID",
            "REGION",
            "ORGANIZATION_DOMAIN",
            "IAP_ADMIN_USER",
            "REPO",
        ]
        for var in required_vars:
            match = re.search(rf'^{var}="([^"]*)"', dc_content, re.MULTILINE)
            if match and match.group(1).strip():
                pass  # ok
            else:
                logger.info(
                    f"  {c_yellow('WARNING')} {var} is empty in deployment.config"
                )

    if all_ok:
        tracker.ok("Pre-flight checks", "all passed")
    else:
        tracker.fail("Pre-flight checks", "some checks failed")

    # Optional: run pre-deploy-check.sh
    if args.run_check:
        logger.info("")
        logger.info(f"  Running pre-deploy-check.sh...")
        check_script = os.path.join(
            project_root, "infrastructure", "pre-deploy-check.sh"
        )
        if os.path.exists(check_script):
            result = run_cmd(
                f"bash {check_script}",
                capture=False,
                check=False,
                timeout=300,
            )
            if result.returncode == 0:
                tracker.ok("Pre-deploy check", "passed")
            else:
                tracker.fail("Pre-deploy check", f"exit code {result.returncode}")
        else:
            tracker.fail("Pre-deploy check", "script not found")

    logger.info("")


# ---------------------------------------------------------------------------
# Step 7: Deploy or print instructions
# ---------------------------------------------------------------------------
def step_deploy_or_instructions(
    args, config: dict, tracker: DeploymentTracker, project_root: str
):
    """Launch deploy-all.sh or print manual instructions."""
    logger.info(f"{BLUE}Step 7: Deployment{NC}")
    logger.info(f"{BLUE}{'─' * 50}{NC}")

    deploy_script = os.path.join(project_root, "infrastructure", "deploy-all.sh")

    if not os.path.exists(deploy_script):
        tracker.fail("Deploy", "deploy-all.sh not found")
        logger.info("")
        return

    if args.deploy and not args.dry_run:
        # Build command with skip flags
        cmd_parts = [f"bash {deploy_script}"]
        if args.skip_apis:
            cmd_parts.append("--skip-apis")
        if args.skip_cloud_run:
            cmd_parts.append("--skip-cloud-run")
        if args.skip_load_balancer:
            cmd_parts.append("--skip-load-balancer")
        if args.skip_iap:
            cmd_parts.append("--skip-iap")
        if args.skip_oauth:
            cmd_parts.append("--skip-oauth")

        cmd = " ".join(cmd_parts)
        logger.info(f"  Launching: {cmd}")
        logger.info("")
        logger.info(
            f"  {c_yellow('NOTE')}: deploy-all.sh has interactive prompts."
        )
        logger.info(
            f"  {c_yellow('NOTE')}: OAuth consent screen setup requires manual steps."
        )
        logger.info("")

        # Run deploy-all.sh with pass-through I/O
        # Set TERM so that `clear` and other terminal commands work
        env = os.environ.copy()
        env.setdefault("TERM", "xterm")
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=project_root,
            env=env,
            timeout=1800,  # 30 min timeout
        )

        if result.returncode == 0:
            tracker.ok("Deploy", "deploy-all.sh completed")
        else:
            tracker.fail("Deploy", f"exit code {result.returncode}")
    else:
        if args.dry_run:
            logger.info(f"  {c_yellow('[DRY RUN]')} Would launch deploy-all.sh")
            tracker.ok("Deploy", "[DRY RUN]")
        else:
            # Print instructions
            logger.info(f"  {c_cyan('Ready to deploy!')} Run the following command:")
            logger.info("")
            logger.info(f"    cd {project_root}")
            logger.info(f"    ./infrastructure/deploy-all.sh")
            logger.info("")
            logger.info(f"  {c_cyan('With skip flags (re-deployment):')}")
            logger.info(
                f"    ./infrastructure/deploy-all.sh --skip-apis --skip-load-balancer"
            )
            logger.info("")
            logger.info(f"  {c_cyan('Or use this script with --deploy:')}")
            logger.info(f"    python setup-deploy.py --deploy")
            logger.info(f"    python setup-deploy.py --deploy --skip-apis")
            logger.info("")

            logger.info(f"  {c_yellow('Interactive steps during deployment:')}")
            logger.info(f"    1. Confirm deployment (y/N)")
            logger.info(
                f"    2. OAuth consent screen — manual setup in Google Cloud Console"
            )
            logger.info(
                f"    3. Redirect URIs — manual step in Google Cloud Console"
            )
            logger.info(
                f"    4. Security posture detection (auto)"
            )
            logger.info("")
            tracker.skip("Deploy", "use --deploy to run")

    logger.info("")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Pre-deployment preparation and launch for ADK RAG Agent",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Examples:
              python setup-deploy.py                        # prepare only (interactive)
              python setup-deploy.py --dry-run              # preview changes
              python setup-deploy.py --run-check            # prepare + pre-deploy check
              python setup-deploy.py --deploy               # prepare + deploy
              python setup-deploy.py --deploy --skip-apis   # deploy with skip flags
        """),
    )

    parser.add_argument(
        "--env",
        default="environments/usfs.yaml",
        help="Path to environment YAML (default: environments/usfs.yaml)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview all changes without writing",
    )
    parser.add_argument(
        "--deploy",
        action="store_true",
        help="After preparation, invoke deploy-all.sh",
    )
    parser.add_argument(
        "--run-check",
        action="store_true",
        help="Run pre-deploy-check.sh during validation",
    )
    parser.add_argument(
        "--no-interactive",
        action="store_true",
        help="Fail instead of prompting for missing values",
    )

    # Skip flags (forwarded to deploy-all.sh)
    parser.add_argument("--skip-apis", action="store_true", help="Skip API enablement")
    parser.add_argument(
        "--skip-cloud-run", action="store_true", help="Skip Cloud Run deployment"
    )
    parser.add_argument(
        "--skip-load-balancer",
        action="store_true",
        help="Skip Load Balancer creation",
    )
    parser.add_argument(
        "--skip-iap", action="store_true", help="Skip IAP configuration"
    )
    parser.add_argument(
        "--skip-oauth", action="store_true", help="Skip OAuth client creation"
    )

    args = parser.parse_args()

    project_root = find_project_root()
    os.chdir(project_root)

    tracker = DeploymentTracker()

    # Banner
    logger.info(f"{MAGENTA}")
    logger.info("=" * 70)
    logger.info("  ADK RAG AGENT — PRE-DEPLOYMENT PREPARATION (Phase 5)")
    logger.info("=" * 70)
    logger.info(f"{NC}")

    if args.dry_run:
        logger.info(f"  {c_yellow('DRY RUN MODE — no files will be modified')}")
        logger.info("")

    # Step 1: Load config
    config = step_load_config(args, tracker)

    # Step 2: Resolve missing values
    config = step_resolve_missing(args, config, tracker, project_root)

    # Step 3: Regenerate deployment.config
    step_regenerate_config(args, config, tracker, project_root)

    # Step 4: Validate secrets.env
    step_validate_secrets(args, tracker, project_root)

    # Step 5: Fix hardcoded bucket names
    step_fix_bucket_names(args, config, tracker, project_root)

    # Step 6: Pre-flight checks
    step_preflight_checks(args, config, tracker, project_root)

    # Summary so far
    success = tracker.print_summary()

    if not success:
        logger.info("")
        logger.info(
            f"  {c_red('Some steps failed.')} Fix the issues above before deploying."
        )
        logger.info("")
        sys.exit(1)

    # Step 7: Deploy or instructions
    logger.info("")
    step_deploy_or_instructions(args, config, tracker, project_root)


if __name__ == "__main__":
    main()
