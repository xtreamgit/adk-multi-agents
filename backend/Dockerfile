# Backend API Dockerfile
FROM python:3.11-slim

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# Suppress pip root user warning (safe in isolated Docker containers)
ENV PIP_ROOT_USER_ACTION=ignore

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Upgrade pip to latest version
RUN pip install --upgrade pip

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY src/ ./src/
COPY config/ ./config/

# Create directory for SQLite database
RUN mkdir -p /app/data

# Set environment variables (only stable/non-sensitive defaults)
# Project-specific values should be set at deployment time via Cloud Run env vars
ENV PYTHONPATH=/app
ENV DATABASE_PATH=/app/data/users.db
ENV LOG_LEVEL=INFO
ENV ENVIRONMENT=production
# Note: PROJECT_ID, GOOGLE_CLOUD_LOCATION, VERTEXAI_PROJECT, VERTEXAI_LOCATION
# should be set via Cloud Run --set-env-vars during deployment
# Default values below are overridden by deployment configuration
ENV PROJECT_ID=adk-rag-ma
ENV GOOGLE_CLOUD_LOCATION=us-east4
ENV GOOGLE_GENAI_USE_VERTEXAI=true
ENV VERTEXAI_PROJECT=adk-rag-ma
ENV VERTEXAI_LOCATION=us-east4
ENV ACCOUNT_ENV=develom

# Expose port (Cloud Run will set PORT env var)
EXPOSE 8080

# Health check - use PORT env var or default to 8000
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/ || exit 1

# Run the application - let api_server.py handle PORT env var
CMD ["python", "src/api/server.py"]
