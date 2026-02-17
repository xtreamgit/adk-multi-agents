"""
Google Groups Service — queries Admin SDK Directory API for user group memberships.

Uses the Google Admin SDK Directory API (admin.googleapis.com) with domain-wide
delegation to look up which Google Groups a user belongs to. This is used by the
Google Groups Bridge to automatically assign chatbot groups and corpus access
based on org group membership.

Requirements:
- Admin SDK API enabled on the GCP project
- Service account with domain-wide delegation enabled in Google Admin Console
- Scopes authorized: https://www.googleapis.com/auth/admin.directory.group.readonly
- GOOGLE_GROUPS_ENABLED=true
- GOOGLE_GROUPS_ADMIN_EMAIL=<admin-user>@<domain> (user to impersonate for API calls)
"""

import os
import json
import logging
from typing import List, Optional
from datetime import datetime, timedelta

import google.auth
import google.auth.iam
import google.auth.transport.requests
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account

logger = logging.getLogger(__name__)

# Configuration
GOOGLE_GROUPS_ENABLED = os.getenv("GOOGLE_GROUPS_ENABLED", "false").lower() == "true"
GOOGLE_GROUPS_CACHE_TTL = int(os.getenv("GOOGLE_GROUPS_CACHE_TTL", "300"))  # seconds
GOOGLE_GROUPS_ADMIN_EMAIL = os.getenv("GOOGLE_GROUPS_ADMIN_EMAIL", "")  # admin user to impersonate

ADMIN_SDK_SCOPES = ["https://www.googleapis.com/auth/admin.directory.group.readonly"]


class GoogleGroupsService:
    """Service for querying Admin SDK Directory API for user group memberships."""

    _credentials = None

    @staticmethod
    def is_enabled() -> bool:
        """Check if Google Groups integration is enabled."""
        return GOOGLE_GROUPS_ENABLED

    @staticmethod
    async def get_user_groups(user_email: str) -> List[str]:
        """
        Query Admin SDK Directory API for a user's group memberships.
        Returns a list of group email addresses the user belongs to.

        Uses domain-wide delegation to impersonate an admin user.
        """
        if not GOOGLE_GROUPS_ENABLED:
            logger.debug("Google Groups integration is disabled")
            return []

        if not GOOGLE_GROUPS_ADMIN_EMAIL:
            logger.error(
                "GOOGLE_GROUPS_ADMIN_EMAIL not set. "
                "Set this to a Workspace admin email for domain-wide delegation."
            )
            return []

        try:
            return await GoogleGroupsService._query_admin_sdk(user_email)
        except Exception as e:
            logger.error(f"Failed to query Google Groups for {user_email}: {e}")
            return []

    @staticmethod
    def _get_delegated_credentials():
        """
        Get credentials with domain-wide delegation.
        The SA impersonates GOOGLE_GROUPS_ADMIN_EMAIL to call Admin SDK.

        On Cloud Run, google.auth.default() returns compute_engine.Credentials
        which lack a .signer. We use google.auth.iam.Signer to sign JWTs
        via the IAM signBlob API instead.
        """
        if GoogleGroupsService._credentials and GoogleGroupsService._credentials.valid:
            return GoogleGroupsService._credentials

        # Get the default SA credentials
        source_credentials, _ = google.auth.default()

        # Refresh so we have a valid token for IAM signing
        request = GoogleAuthRequest()
        if not source_credentials.valid:
            source_credentials.refresh(request)

        # Get the SA email — works for both local SA key and Cloud Run metadata
        sa_email = getattr(source_credentials, "service_account_email", None)
        if not sa_email:
            sa_email = source_credentials.signer_email if hasattr(source_credentials, "signer_email") else None
        if not sa_email:
            # Fallback: query metadata server
            import requests as http_req
            resp = http_req.get(
                "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email",
                headers={"Metadata-Flavor": "Google"}, timeout=5
            )
            sa_email = resp.text

        # Use IAM-based signer (works on Cloud Run without a local key file)
        iam_signer = google.auth.iam.Signer(
            request=request,
            credentials=source_credentials,
            service_account_email=sa_email,
        )

        # Create delegated credentials that impersonate the admin user
        delegated = service_account.Credentials(
            signer=iam_signer,
            service_account_email=sa_email,
            token_uri="https://oauth2.googleapis.com/token",
            scopes=ADMIN_SDK_SCOPES,
            subject=GOOGLE_GROUPS_ADMIN_EMAIL,
        )
        delegated.refresh(request)
        GoogleGroupsService._credentials = delegated
        return delegated

    @staticmethod
    async def _query_admin_sdk(user_email: str) -> List[str]:
        """
        Query Admin SDK Directory API for user's group memberships.
        Uses domain-wide delegation to impersonate an admin user.

        API: GET https://admin.googleapis.com/admin/directory/v1/groups?userKey={email}
        """
        import aiohttp

        credentials = GoogleGroupsService._get_delegated_credentials()

        base_url = "https://admin.googleapis.com/admin/directory/v1/groups"
        params = {"userKey": user_email}

        headers = {
            "Authorization": f"Bearer {credentials.token}",
        }

        group_emails = []
        page_token = None

        async with aiohttp.ClientSession() as session:
            while True:
                if page_token:
                    params["pageToken"] = page_token

                async with session.get(base_url, headers=headers, params=params) as resp:
                    if resp.status == 403:
                        body = await resp.text()
                        logger.error(
                            f"Admin SDK 403 for {user_email}. "
                            f"SA={credentials.service_account_email}, "
                            f"subject={GOOGLE_GROUPS_ADMIN_EMAIL}. "
                            f"Body: {body[:2000]}"
                        )
                        return []
                    elif resp.status == 400:
                        body = await resp.text()
                        logger.error(f"Admin SDK bad request for {user_email}: {body[:500]}")
                        return []
                    elif resp.status != 200:
                        body = await resp.text()
                        logger.error(f"Admin SDK error {resp.status}: {body[:500]}")
                        return []

                    data = await resp.json()

                groups = data.get("groups", [])
                for group in groups:
                    email = group.get("email", "")
                    if email:
                        group_emails.append(email)

                page_token = data.get("nextPageToken")
                if not page_token:
                    break

        logger.info(f"Found {len(group_emails)} Google Groups for {user_email}: {group_emails}")
        return group_emails

    @staticmethod
    def get_cached_groups(user_id: int) -> Optional[List[str]]:
        """
        Get cached Google Groups for a user if the cache is still fresh.
        Returns None if cache is stale or doesn't exist.
        """
        from database.connection import get_db_connection

        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    SELECT google_groups, last_synced_at
                    FROM user_google_group_sync
                    WHERE user_id = %s
                    """,
                    (user_id,),
                )
                row = cursor.fetchone()

                if not row:
                    return None

                last_synced = row["last_synced_at"]
                if isinstance(last_synced, str):
                    last_synced = datetime.fromisoformat(last_synced)

                cache_age = (datetime.utcnow() - last_synced).total_seconds()
                if cache_age > GOOGLE_GROUPS_CACHE_TTL:
                    logger.debug(f"Cache expired for user {user_id} (age: {cache_age:.0f}s)")
                    return None

                groups = row["google_groups"]
                if isinstance(groups, str):
                    groups = json.loads(groups)
                return groups

        except Exception as e:
            logger.warning(f"Failed to read group cache for user {user_id}: {e}")
            return None

    @staticmethod
    def update_cache(user_id: int, google_groups: List[str], sync_source: str = "login"):
        """Update the cached Google Groups for a user."""
        from database.connection import get_db_connection

        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    INSERT INTO user_google_group_sync (user_id, google_groups, last_synced_at, sync_source)
                    VALUES (%s, %s, CURRENT_TIMESTAMP, %s)
                    ON CONFLICT (user_id) DO UPDATE SET
                        google_groups = EXCLUDED.google_groups,
                        last_synced_at = CURRENT_TIMESTAMP,
                        sync_source = EXCLUDED.sync_source
                    """,
                    (user_id, json.dumps(google_groups), sync_source),
                )
                conn.commit()
                logger.debug(f"Updated group cache for user {user_id}: {google_groups}")
        except Exception as e:
            logger.warning(f"Failed to update group cache for user {user_id}: {e}")
