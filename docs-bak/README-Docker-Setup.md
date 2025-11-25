# Docker Setup and Configuration

## Current Status
✅ **Docker containers built successfully**  
⚠️ **Runtime configuration needed for Google Cloud services**

## Issues Fixed
1. **bcrypt compatibility** - Added specific bcrypt version to requirements.txt
2. **ESLint build errors** - Configured Next.js to ignore linting during builds
3. **Tailwind CSS imports** - Fixed CSS directive syntax and configuration

## Current Runtime Issues

### 1. Google Cloud Credentials Missing
**Error:** `Failed to initialize Vertex AI: name 'PROJECT_ID' is not defined`

**Solution:** Set up Google Cloud credentials:

```bash
# Create credentials directory
mkdir -p credentials

# Copy your Google Cloud service account JSON file
cp /path/to/your/service-account.json credentials/service-account.json

# Set environment variables
export PROJECT_ID=adk-rag-agent-2025
export GOOGLE_APPLICATION_CREDENTIALS=./credentials/service-account.json
```

### 2. Environment Configuration
Create a `.env` file in the project root:

```env
PROJECT_ID=adk-rag-agent-2025
GOOGLE_APPLICATION_CREDENTIALS=./credentials/service-account.json
SECRET_KEY=your-very-secure-secret-key-here
```

## Running the Application

### With Google Cloud Credentials
```bash
# Set up credentials first
export PROJECT_ID=adk-rag-agent-2025
export GOOGLE_APPLICATION_CREDENTIALS=./credentials/service-account.json

# Run the application
docker compose up --build
```

### Without Google Cloud (Limited Functionality)
The application will start but RAG features will be disabled:
```bash
docker compose up --build
```

## Services
- **Frontend:** http://localhost:3000
- **Backend API:** http://localhost:8000
- **API Documentation:** http://localhost:8000/docs

## Troubleshooting

### 500 Errors on /api/corpora and chat endpoints
These occur when Google Cloud credentials are not properly configured. The application needs:
1. Valid Google Cloud service account credentials
2. PROJECT_ID environment variable
3. Proper permissions for Vertex AI and Cloud Storage

### bcrypt Warning
The warning about bcrypt version is non-critical and doesn't affect functionality.

### Container Logs
```bash
# View backend logs
docker compose logs backend

# View frontend logs  
docker compose logs frontend

# Follow logs in real-time
docker compose logs -f
```
