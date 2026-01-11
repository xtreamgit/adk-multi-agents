#!/bin/bash
set -e

echo "🔧 Running database migrations..."
python src/database/migrations/run_migrations.py

echo "🚀 Starting FastAPI server..."
exec python src/api/server.py
