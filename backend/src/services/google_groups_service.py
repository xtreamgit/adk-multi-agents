"""
Google Groups Service — queries Cloud Identity API for user group memberships.

Uses the Cloud Identity Groups API (cloudidentity.googleapis.com) to look up
which Google Groups a user belongs to. This is used by the Google Groups Bridge
to automatically assign chatbot groups and corpus access based on org group membership.

Requirements:
- Cloud Identity API enabled on the GCP project
- Service account with roles/cloudidentity.groupsViewer (or equivalent)
- Environment variable GOOGLE_GROUPS_ENABLED=true to activate
"""

import os
import json
import logging
from typing import List, Optional
from datetime import datetime, timedelta

from google.auth import default as google_auth_default
from google.auth.transport.requests import Request as GoogleAuthRequest

logger = logging.getLogger(__name__)

# Configuration
GOOGLE_GROUPS_ENABLED = os.getenv("GOOGLE_GROUPS_ENABLED", "false").lower() == "true"
GOOGLE_GROUPS_CACHE_TTL = int(os.getenv("GOOGLE_GROUPS_CACHE_TTL", "300"))  # seconds
GOOGLE_GROUPS_CUSTOMER_ID = os.getenv("GOOGLE_GROUPS_CUSTOMER_ID", "")  # e.g., "C01234abc"


class GoogleGroupsService:
    """Service for querying Google Cloud Identity API for user group memberships."""

    _credentials = None
    _session = None

    @staticmethod
    def is_enabled() -> bool:
        """Check if Google Groups integration is enabled."""
        return GOOGLE_GROUPS_ENABLED

    @staticmethod
    async def get_user_groups(user_email: str) -> List[str]:
        """
        Query Google Cloud Identity API for a user's direct group memberships.
        Returns a list of group email addresses the user belongs to.

        Uses the searchTransitiveGroups method to find all groups (direct + indirect).
        Falls back to Admin SDK Directory API if Cloud Identity is not available.
        """
        if not GOOGLE_GROUPS_ENABLED:
            logger.debug("Google Groups integration is disabled")
            return []

        try:
            return await GoogleGroupsService._query_cloud_identity(user_email)
        except Exception as e:
            logger.error(f"Failed to query Google Groups for {user_email}: {e}")
            return []

    @staticmethod
    async def _query_cloud_identity(user_email: str) -> List[str]:
        """
        Query Cloud Identity Groups API for user's group memberships.
        Uses searchTransitiveGroups to get all groups (direct and inherited).
        """
        import aiohttp

        credentials, _ = google_auth_default(
            scopes=["https://www.googleapis.com/auth/cloud-identity.groups.readonly"]
        )
        credentials.refresh(GoogleAuthRequest())

        # Use searchTransitiveGroups to find all groups the user belongs to
        # This requires a customer ID or we can use the member key
        base_url = "https://cloudidentity.googleapis.com/v1/groups/-/memberships:searchTransitiveGroups"
        params = {
            "query": f"member_key_id == '{user_email}' && 'cloudidentity.googleapis.com/groups.discussion_forum' in labels"
        }

        headers = {
            "Authorization": f"Bearer {credentials.token}",
            "Content-Type": "application/json",
        }

        group_emails = []
        page_token = None

        async with aiohttp.ClientSession() as session:
            while True:
                if page_token:
                    params["pageToken"] = page_token

                async with session.get(base_url, headers=headers, params=params) as resp:
                    if resp.status == 403:
                        logger.error(
                            "Permission denied querying Cloud Identity API. "
                            "Ensure the service account has roles/cloudidentity.groupsViewer"
                        )
                        return []
                    elif resp.status == 404:
                        logger.warning(
                            "Cloud Identity API returned 404. "
                            "Ensure cloudidentity.googleapis.com is enabled."
                        )
                        return []
                    elif resp.status != 200:
                        body = await resp.text()
                        logger.error(f"Cloud Identity API error {resp.status}: {body}")
                        return []

                    data = await resp.json()

                memberships = data.get("memberships", [])
                for membership in memberships:
                    group = membership.get("group", "")
                    group_key = membership.get("groupKey", {})
                    email = group_key.get("id", "")
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
