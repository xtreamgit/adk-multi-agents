"""
Google Groups Bridge — syncs user access based on Google Group memberships.

Core logic that maps Google Groups → chatbot groups + corpus access.
Called during IAP authentication to automatically assign users to the correct
chatbot groups and grant corpus access based on their org group memberships.

Design:
- Dimension 1 (Agent type): Google Group → chatbot_group (via google_group_agent_mappings)
- Dimension 2 (Corpus access): Google Group → corpus + permission (via google_group_corpus_mappings)
- A user in multiple groups gets the highest-priority chatbot group and the union of all corpus access.
- Non-fatal: if sync fails, user retains their last-synced permissions.
"""

import logging
from typing import Dict, List, Optional

from database.connection import get_db_connection
from services.google_groups_service import GoogleGroupsService

logger = logging.getLogger(__name__)


class GoogleGroupsBridge:
    """Bridges Google Groups to chatbot groups and corpus access."""

    @staticmethod
    def is_enabled() -> bool:
        """Check if the Google Groups Bridge is enabled."""
        return GoogleGroupsService.is_enabled()

    @staticmethod
    async def sync_user_access(user_id: int, user_email: str) -> Dict:
        """
        Sync a user's chatbot group memberships and corpus access
        based on their Google Group memberships.

        Steps:
        1. Check cache — skip API call if fresh
        2. Query Cloud Identity API for user's Google Groups
        3. Ensure user exists in chatbot_users table
        4. Look up google_group_agent_mappings for matching groups
        5. Assign user to the highest-priority chatbot group
        6. Look up google_group_corpus_mappings for matching groups
        7. Sync chatbot_corpus_access for the user's chatbot group
        8. Update cache

        Returns:
            dict with sync results (groups_found, chatbot_group, corpora_synced, etc.)
        """
        result = {
            "user_id": user_id,
            "email": user_email,
            "google_groups": [],
            "chatbot_group": None,
            "corpora_synced": 0,
            "from_cache": False,
            "status": "skipped",
        }

        if not GoogleGroupsBridge.is_enabled():
            return result

        try:
            # Step 1: Check cache
            cached_groups = GoogleGroupsService.get_cached_groups(user_id)
            if cached_groups is not None:
                google_groups = cached_groups
                result["from_cache"] = True
                logger.debug(f"Using cached groups for {user_email}: {google_groups}")
            else:
                # Step 2: Query Cloud Identity API
                google_groups = await GoogleGroupsService.get_user_groups(user_email)
                # Update cache
                GoogleGroupsService.update_cache(user_id, google_groups, sync_source="login")

            result["google_groups"] = google_groups

            if not google_groups:
                logger.info(f"No Google Groups found for {user_email}, skipping sync")
                result["status"] = "no_groups"
                return result

            # Step 3: Ensure chatbot_users record exists
            chatbot_user_id = GoogleGroupsBridge._ensure_chatbot_user(user_id, user_email)
            if not chatbot_user_id:
                logger.warning(f"Could not find/create chatbot user for {user_email}")
                result["status"] = "error_chatbot_user"
                return result

            # Step 4-5: Sync chatbot group membership (agent type dimension)
            chatbot_group_name = GoogleGroupsBridge._sync_agent_group(
                chatbot_user_id, google_groups
            )
            result["chatbot_group"] = chatbot_group_name

            # Step 6-7: Sync corpus access
            corpora_count = GoogleGroupsBridge._sync_corpus_access(
                chatbot_user_id, google_groups
            )
            result["corpora_synced"] = corpora_count

            result["status"] = "synced"
            logger.info(
                f"Google Groups Bridge sync for {user_email}: "
                f"groups={len(google_groups)}, chatbot_group={chatbot_group_name}, "
                f"corpora={corpora_count}, cached={result['from_cache']}"
            )

        except Exception as e:
            logger.error(f"Google Groups Bridge sync failed for {user_email}: {e}")
            result["status"] = f"error: {str(e)}"

        return result

    @staticmethod
    def _ensure_chatbot_user(user_id: int, user_email: str) -> Optional[int]:
        """
        Ensure the app user has a corresponding chatbot_users record.
        The chatbot_users table is separate from the users table.
        Matches by username (derived from email) or email.
        Returns chatbot_user_id or None.
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()

                # Try to find existing chatbot user by email
                cursor.execute(
                    "SELECT id FROM chatbot_users WHERE email = %s",
                    (user_email,),
                )
                row = cursor.fetchone()
                if row:
                    return row["id"]

                # Try by username (email prefix)
                username = user_email.split("@")[0]
                cursor.execute(
                    "SELECT id FROM chatbot_users WHERE username = %s",
                    (username,),
                )
                row = cursor.fetchone()
                if row:
                    return row["id"]

                # Create a new chatbot user linked to the app user
                cursor.execute(
                    "SELECT username, email, full_name FROM users WHERE id = %s",
                    (user_id,),
                )
                app_user = cursor.fetchone()
                if not app_user:
                    logger.error(f"App user {user_id} not found")
                    return None

                cursor.execute(
                    """
                    INSERT INTO chatbot_users (username, email, full_name, is_active, created_by)
                    VALUES (%s, %s, %s, TRUE, %s)
                    ON CONFLICT (email) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
                    RETURNING id
                    """,
                    (app_user["username"], app_user["email"], app_user["full_name"], user_id),
                )
                new_row = cursor.fetchone()
                conn.commit()

                if new_row:
                    logger.info(f"Created chatbot user for {user_email}: id={new_row['id']}")
                    return new_row["id"]

                return None

        except Exception as e:
            logger.error(f"Failed to ensure chatbot user for {user_email}: {e}")
            return None

    @staticmethod
    def _sync_agent_group(chatbot_user_id: int, google_groups: List[str]) -> Optional[str]:
        """
        Sync chatbot group membership based on Google Group → chatbot_group mappings.

        Finds the highest-priority mapping that matches the user's Google Groups,
        assigns the user to that chatbot group, and removes them from other
        bridge-managed groups.

        Returns the name of the assigned chatbot group, or None.
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()

                # Find all active mappings that match the user's Google Groups
                placeholders = ",".join(["%s"] * len(google_groups))
                cursor.execute(
                    f"""
                    SELECT ggam.id, ggam.google_group_email, ggam.chatbot_group_id,
                           ggam.priority, cg.name as chatbot_group_name
                    FROM google_group_agent_mappings ggam
                    JOIN chatbot_groups cg ON ggam.chatbot_group_id = cg.id
                    WHERE ggam.google_group_email IN ({placeholders})
                      AND ggam.is_active = TRUE
                      AND cg.is_active = TRUE
                    ORDER BY ggam.priority DESC
                    """,
                    google_groups,
                )
                mappings = cursor.fetchall()

                if not mappings:
                    logger.debug(f"No agent group mappings found for chatbot user {chatbot_user_id}")
                    return None

                # Pick the highest-priority mapping
                best_mapping = mappings[0]
                target_group_id = best_mapping["chatbot_group_id"]
                target_group_name = best_mapping["chatbot_group_name"]

                # Get all bridge-managed group IDs (so we can remove stale memberships)
                cursor.execute(
                    "SELECT DISTINCT chatbot_group_id FROM google_group_agent_mappings WHERE is_active = TRUE"
                )
                bridge_group_ids = [row["chatbot_group_id"] for row in cursor.fetchall()]

                # Remove user from other bridge-managed groups
                if bridge_group_ids:
                    bridge_placeholders = ",".join(["%s"] * len(bridge_group_ids))
                    cursor.execute(
                        f"""
                        DELETE FROM chatbot_user_groups
                        WHERE chatbot_user_id = %s
                          AND chatbot_group_id IN ({bridge_placeholders})
                          AND chatbot_group_id != %s
                        """,
                        [chatbot_user_id] + bridge_group_ids + [target_group_id],
                    )

                # Add user to the target group
                cursor.execute(
                    """
                    INSERT INTO chatbot_user_groups (chatbot_user_id, chatbot_group_id)
                    VALUES (%s, %s)
                    ON CONFLICT (chatbot_user_id, chatbot_group_id) DO NOTHING
                    """,
                    (chatbot_user_id, target_group_id),
                )

                conn.commit()
                logger.debug(
                    f"Assigned chatbot user {chatbot_user_id} to group '{target_group_name}' "
                    f"(priority={best_mapping['priority']})"
                )
                return target_group_name

        except Exception as e:
            logger.error(f"Failed to sync agent group for chatbot user {chatbot_user_id}: {e}")
            return None

    @staticmethod
    def _sync_corpus_access(chatbot_user_id: int, google_groups: List[str]) -> int:
        """
        Sync corpus access based on Google Group → corpus mappings.

        For each corpus, takes the highest permission level across all matching groups.
        Updates chatbot_corpus_access for the user's chatbot groups.

        Returns the number of corpora synced.
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()

                # Find all active corpus mappings that match the user's Google Groups
                placeholders = ",".join(["%s"] * len(google_groups))
                cursor.execute(
                    f"""
                    SELECT ggcm.corpus_id, ggcm.permission, ggcm.google_group_email
                    FROM google_group_corpus_mappings ggcm
                    JOIN corpora c ON ggcm.corpus_id = c.id
                    WHERE ggcm.google_group_email IN ({placeholders})
                      AND ggcm.is_active = TRUE
                      AND c.is_active = TRUE
                    """,
                    google_groups,
                )
                corpus_mappings = cursor.fetchall()

                if not corpus_mappings:
                    logger.debug(f"No corpus mappings found for chatbot user {chatbot_user_id}")
                    return 0

                # Resolve highest permission per corpus
                # Permission hierarchy: admin > delete > upload > read > query
                permission_rank = {
                    "query": 1,
                    "read": 2,
                    "upload": 3,
                    "delete": 4,
                    "admin": 5,
                }

                corpus_permissions: Dict[int, str] = {}
                for mapping in corpus_mappings:
                    corpus_id = mapping["corpus_id"]
                    perm = mapping["permission"]
                    current = corpus_permissions.get(corpus_id)
                    if current is None or permission_rank.get(perm, 0) > permission_rank.get(current, 0):
                        corpus_permissions[corpus_id] = perm

                # Get the user's chatbot group IDs (bridge-managed)
                cursor.execute(
                    """
                    SELECT cug.chatbot_group_id
                    FROM chatbot_user_groups cug
                    WHERE cug.chatbot_user_id = %s
                    """,
                    (chatbot_user_id,),
                )
                user_group_rows = cursor.fetchall()

                if not user_group_rows:
                    logger.warning(
                        f"Chatbot user {chatbot_user_id} has no group memberships, "
                        "cannot sync corpus access"
                    )
                    return 0

                # Apply corpus access to all of the user's chatbot groups
                synced = 0
                for group_row in user_group_rows:
                    group_id = group_row["chatbot_group_id"]
                    for corpus_id, permission in corpus_permissions.items():
                        cursor.execute(
                            """
                            INSERT INTO chatbot_corpus_access
                                (chatbot_group_id, corpus_id, permission)
                            VALUES (%s, %s, %s)
                            ON CONFLICT (chatbot_group_id, corpus_id) DO UPDATE SET
                                permission = EXCLUDED.permission
                            """,
                            (group_id, corpus_id, permission),
                        )
                        synced += 1

                conn.commit()
                logger.debug(
                    f"Synced {synced} corpus access entries for chatbot user {chatbot_user_id}"
                )
                return len(corpus_permissions)

        except Exception as e:
            logger.error(f"Failed to sync corpus access for chatbot user {chatbot_user_id}: {e}")
            return 0

    @staticmethod
    async def force_sync_user(user_id: int, user_email: str) -> Dict:
        """
        Force a full re-sync for a user, bypassing the cache.
        Used by admin endpoints for manual sync.
        """
        if not GoogleGroupsBridge.is_enabled():
            return {"status": "disabled", "message": "Google Groups Bridge is not enabled"}

        # Clear cache first
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "DELETE FROM user_google_group_sync WHERE user_id = %s",
                    (user_id,),
                )
                conn.commit()
        except Exception as e:
            logger.warning(f"Failed to clear cache for user {user_id}: {e}")

        # Run full sync
        result = await GoogleGroupsBridge.sync_user_access(user_id, user_email)
        if result.get("status") == "synced":
            # Update cache with manual source
            google_groups = result.get("google_groups", [])
            GoogleGroupsService.update_cache(user_id, google_groups, sync_source="manual")

        return result

    @staticmethod
    def get_bridge_status() -> Dict:
        """Get the current status of the Google Groups Bridge."""
        status = {
            "enabled": GoogleGroupsBridge.is_enabled(),
            "cache_ttl_seconds": GoogleGroupsService.is_enabled() and int(
                __import__("os").getenv("GOOGLE_GROUPS_CACHE_TTL", "300")
            ),
            "agent_mappings_count": 0,
            "corpus_mappings_count": 0,
            "synced_users_count": 0,
            "last_sync": None,
        }

        if not GoogleGroupsBridge.is_enabled():
            return status

        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()

                cursor.execute(
                    "SELECT COUNT(*) as cnt FROM google_group_agent_mappings WHERE is_active = TRUE"
                )
                status["agent_mappings_count"] = cursor.fetchone()["cnt"]

                cursor.execute(
                    "SELECT COUNT(*) as cnt FROM google_group_corpus_mappings WHERE is_active = TRUE"
                )
                status["corpus_mappings_count"] = cursor.fetchone()["cnt"]

                cursor.execute("SELECT COUNT(*) as cnt FROM user_google_group_sync")
                status["synced_users_count"] = cursor.fetchone()["cnt"]

                cursor.execute(
                    "SELECT MAX(last_synced_at) as last_sync FROM user_google_group_sync"
                )
                row = cursor.fetchone()
                if row and row["last_sync"]:
                    status["last_sync"] = str(row["last_sync"])

        except Exception as e:
            logger.warning(f"Failed to get bridge status: {e}")

        return status
