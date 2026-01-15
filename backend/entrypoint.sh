#!/bin/bash
set -e

echo "🔧 Running database migrations..."
python src/database/migrations/run_migrations.py

echo "🔧 Adding missing columns to corpus_metadata..."
python add_missing_columns.py

echo "🚀 Starting FastAPI server..."
exec python src/api/server.py
