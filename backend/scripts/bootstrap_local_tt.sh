#!/bin/bash
# =============================================================================
# bootstrap_local_tt.sh — Local-dev-only post-seed bootstrap for the TechTrend (tt) account
# =============================================================================
# Run this AFTER:
#   1. docker compose -f backend/docker-compose.dev.yml up -d   (Postgres on :5433)
#   2. schema + numbered migrations applied
#   3. python backend/seed_data.py --env environments/tt.yaml --target local
#   4. Vertex ADC working + corpora synced (backend started once, or sync run)
#
# It fills three gaps that the documented local flow leaves empty — gaps the
# cloud doesn't have because its data was seeded historically:
#   1. Legacy `agents` table + user_agent_access  -> fixes UI "No agent assigned"
#   2. chatbot_corpus_access (admin-group -> corpora) -> fixes "no access to corpus"
#      (normally populated by the Google Groups Bridge, which is disabled locally)
#   3. corpus_metadata.document_count -> fixes UI "0 documents"
#
# Idempotent: safe to re-run. Operates ONLY on the local Docker Postgres.
# =============================================================================
set -euo pipefail

ADMIN_EMAIL="${IAP_DEV_USER_EMAIL:-hdejesus@techtrend.us}"
CONTAINER="adk-postgres-dev"
DB_USER="adk_dev_user"
DB_NAME="adk_agents_db_dev"
ADMIN_GROUP="admin-group"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"

psql_exec() { docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" "$@"; }

echo "==> [1/3] Seeding legacy 'agents' table + granting admin access"
psql_exec <<SQL
-- Legacy agent row; config_path='tt' makes AgentManager load backend/config/agent_instructions/tt.json
INSERT INTO agents (name, display_name, description, config_path, is_active, created_at)
VALUES ('tt-agent', 'TechTrend Admin Agent', 'TechTrend RAG agent', 'tt', TRUE, now())
ON CONFLICT (name) DO UPDATE SET config_path = EXCLUDED.config_path, is_active = TRUE;

-- Grant the bootstrap admin user access to it and make it their default
INSERT INTO user_agent_access (user_id, agent_id)
SELECT u.id, a.id
FROM users u, agents a
WHERE u.email = '${ADMIN_EMAIL}' AND a.name = 'tt-agent'
ON CONFLICT DO NOTHING;

UPDATE users
SET default_agent_id = (SELECT id FROM agents WHERE name = 'tt-agent')
WHERE email = '${ADMIN_EMAIL}';
SQL

echo "==> [2/3] Granting '${ADMIN_GROUP}' admin access to all corpora (Bridge substitute)"
psql_exec <<SQL
INSERT INTO chatbot_corpus_access (chatbot_group_id, corpus_id, permission)
SELECT (SELECT id FROM chatbot_groups WHERE name = '${ADMIN_GROUP}'), c.id, 'admin'
FROM corpora c
WHERE NOT EXISTS (
  SELECT 1 FROM chatbot_corpus_access x
  WHERE x.chatbot_group_id = (SELECT id FROM chatbot_groups WHERE name = '${ADMIN_GROUP}')
    AND x.corpus_id = c.id
);
SQL

echo "==> [3/3] Syncing corpus document counts from Vertex AI"
if [ -f "$BACKEND_DIR/.env.local" ]; then
  set -a; # shellcheck disable=SC1091
  source "$BACKEND_DIR/.env.local"; set +a
fi
( cd "$BACKEND_DIR" && ./.venv/bin/python sync_corpus_document_counts.py )

echo ""
echo "==> Done. Verifying:"
psql_exec -tAc "SELECT '  agent: '||display_name FROM agents WHERE name='tt-agent';"
psql_exec -tAc "SELECT '  corpus grants: '||count(*) FROM chatbot_corpus_access;"
psql_exec -tAc "SELECT '  '||c.name||' docs='||cm.document_count FROM corpus_metadata cm JOIN corpora c ON c.id=cm.corpus_id WHERE cm.document_count>0;"
echo "==> Refresh http://localhost:3000 to see the changes."
