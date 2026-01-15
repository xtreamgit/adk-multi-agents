#!/bin/bash
set -e

echo "🔧 Running database migrations..."
python src/database/migrations/run_migrations.py

echo "🔧 Running admin tables migration (PostgreSQL)..."
python migrations/run_pg_admin_migration.py || echo "⚠️  Admin migration warning (may already exist)"

echo "🚀 Starting FastAPI server..."
exec python src/api/server.py
