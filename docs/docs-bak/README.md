# Vertex AI RAG Agent with Web UI

This repository contains a Google Agent Development Kit (ADK) implementation of a Retrieval Augmented Generation (RAG) agent using Google Cloud Vertex AI, with a modern web interface deployed on Google Cloud Run.

## Overview

The application provides a user-friendly chat interface to interact with the RAG agent. It allows you to:

- **Query Documents**: Ask natural language questions and receive answers from your document corpora.
- **Manage Corpora**: Use the agent's underlying tools to list, create, add data to, and delete corpora.
- **User Authentication**: Secure login system with JWT tokens.
- **Admin Dashboard**: Monitor user sessions and system statistics.

## Prerequisites

- A Google Cloud account with billing enabled.
- A Google Cloud project with the **Vertex AI API** enabled.
- **Google Cloud CLI** installed and authenticated.
- **Node.js** and **Python 3.11+** for local development.

## Quick Start - Cloud Deployment

### 1. Setup Authentication
```bash
gcloud init
gcloud auth application-default login
gcloud config set project adk-rag-agent-2025
```

### 2. Generate Secret Key
```bash
python3 generate_secret_key.py
```

### 3. Create Secrets File
```bash
echo "SECRET_KEY=your-generated-key-from-step-2" > secrets.env
```

### 4. Deploy to Cloud Run
```bash
chmod +x infrastructure/deploy-with-secrets.sh
./infrastructure/deploy-with-secrets.sh
```

The deployment script will:
- Build and push Docker images to Artifact Registry
- Deploy backend and frontend to Cloud Run
- Configure IAM permissions with minimal required roles
- Set up CORS between frontend and backend

## Local Development

### Backend Setup
```bash
cd backend
pip install -r requirements.txt
python src/api/server.py
```

### Frontend Setup
```bash
cd frontend
npm install
npm run dev
```

## Agent Capabilities

The agent is equipped with a powerful set of tools to manage your RAG corpora:

- **Query Documents**: Ask questions like `"What are the main features of product X?" from corpus my_product_docs`.
- **List Corpora**: `list corpora`
- **Create Corpus**: `create a new corpus named my_new_corpus`
- **Add Data**: `add the data from GCS path gs://my-bucket/my-doc.pdf to corpus my_new_corpus`
- **Get Corpus Info**: `get information for corpus my_new_corpus`
- **Delete Corpus**: `delete the corpus my_new_corpus`

## Security Management

### Secret Key Management
The application uses JWT tokens for authentication. The `SECRET_KEY` is managed securely:

- **Generate new key**: `python3 generate_secret_key.py`
- **Update secrets**: Edit `secrets.env` file (not tracked in git)
- **Rotate key**: Generate new key and redeploy

### IAM Permissions
The deployment uses minimal required permissions:
- `roles/aiplatform.user` - For Vertex AI access
- `roles/storage.objectViewer` - For reading corpus data

### Remove Excessive Permissions
If you previously had admin roles assigned:
```bash
./remove_excessive_permissions.sh
```

## Useful Commands

### Check Deployment Status
```bash
gcloud run services list --region=us-central1
```

### View Logs
```bash
# Backend logs
gcloud logs read --service=backend --region=us-central1

# Frontend logs  
gcloud logs read --service=frontend --region=us-central1
```

### Update Environment Variables
```bash
gcloud run services update backend \
  --region=us-central1 \
  --set-env-vars="LOG_LEVEL=DEBUG"
```

### Redeploy After Changes
```bash
./infrastructure/deploy-with-secrets.sh
```

## Troubleshooting

### Common Issues

**1. "Missing key inputs argument" error**
- Ensure `GOOGLE_GENAI_USE_VERTEXAI=true` is set in Dockerfile
- Verify Vertex AI APIs are enabled

**2. Authentication errors**
- Check service account permissions
- Verify `gcloud auth application-default login`

**3. Secret key errors**
- Ensure `secrets.env` uses `=` not `:`
- Regenerate key if corrupted

**4. Build failures**
- Check Docker is running
- Verify gcloud CLI is authenticated

## Additional Resources

- [Vertex AI RAG Documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/rag-overview)
- [Google Agent Development Kit (ADK) Documentation](https://github.com/google/agents-framework)
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Build Documentation](https://cloud.google.com/build/docs)