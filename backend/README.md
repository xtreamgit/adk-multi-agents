# RAG Agent Backend

This is the backend service for the USFS RAG Agent application, built with FastAPI and Google ADK.

## Structure

```
backend/
├── src/
│   ├── api/
│   │   ├── server.py          # Main FastAPI application
│   │   ├── routes/            # API route modules
│   │   └── middleware/        # Custom middleware
│   ├── rag_agent/
│   │   ├── agent.py           # ADK agent configuration
│   │   ├── config.py          # Configuration settings
│   │   └── tools/             # RAG tools (query, corpus management)
│   └── database/
│       └── models.py          # Database models
├── tests/                     # Unit and integration tests
├── Dockerfile                 # Container configuration
├── requirements.txt           # Python dependencies
├── cloudbuild.yaml           # Google Cloud Build configuration
└── README.md                 # This file
```

## Environment Variables

- `PROJECT_ID`: Google Cloud project ID
- `GOOGLE_CLOUD_LOCATION`: Vertex AI location (e.g., us-central1)
- `GOOGLE_GENAI_USE_VERTEXAI`: Set to "true" to use Vertex AI
- `VERTEXAI_PROJECT`: Vertex AI project ID
- `VERTEXAI_LOCATION`: Vertex AI location
- `DATABASE_PATH`: SQLite database path
- `LOG_LEVEL`: Logging level (INFO, DEBUG, etc.)

## Development

1. Install dependencies: `pip install -r requirements.txt`
2. Set environment variables (copy from `.env.example`)
3. Run the server: `python src/api/server.py`

## Deployment

The backend is deployed to Google Cloud Run using the deployment script in `infrastructure/deploy.sh`.
