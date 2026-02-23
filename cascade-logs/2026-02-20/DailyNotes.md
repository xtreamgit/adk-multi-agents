---
**Author:** Hector  
**Date:** February 20, 2026  
**Purpose:** All the notes created during the day will be collected here. The notes could include temporary pieces of information, prompts used during the coding process, and other miscellaneous information about the project.

---

## Project Summary

**ADK Multi-Agents RAG System** is a multi-agent Retrieval-Augmented Generation (RAG) application built on Google Cloud Platform. The system enables intelligent document search and question-answering across multiple knowledge corpora using Vertex AI RAG.

**Key Components:**
- **Backend:** FastAPI-based Python server with PostgreSQL database
- **Frontend:** Next.js React application with TypeScript
- **AI/RAG:** Google Vertex AI RAG for document retrieval and semantic search
- **Authentication:** Identity-Aware Proxy (IAP) with local username/password fallback
- **Deployment:** Google Cloud Run (containerized microservices)
- **Infrastructure:** Terraform-managed GCP resources

**Core Features:**
- Multi-corpus document management and search
- Role-based access control (RBAC) for users, groups, and agents
- Multiple specialized AI agents with different capabilities
- Admin panel for managing users, groups, corpora, and agents
- Document upload, retrieval, and audit logging
- Real-time chat interface with RAG-powered responses

**Tech Stack:**
- Python 3.11, FastAPI, PostgreSQL, SQLAlchemy
- Next.js 15, React 19, TypeScript, TailwindCSS
- Google Cloud: Vertex AI, Cloud Run, Cloud SQL, IAP
- Docker, Terraform, GitHub Actions (CI/CD)

---

## Daily Notes

### [TIME] - Database Connection Information
command
docker exec -it <container_name> psql -U <user> -d <database>

docker exec -it <container_name> psql -U <user> -d <database>

adk-postgres-dev 
adk_dev_agent
adk_agents_db_dev

# Local Development Database Configuration
DB_HOST=localhost 
DB_PORT=5433 
DB_NAME=adk_agents_db_dev 
DB_USER=adk_dev_user 
DB_PASSWORD=dev_password_123 

Container Name: adk-postgres-dev
---
### [TIME] - Note Title
[Note content goes here...]
---

Prompt

Ok, in the Cloud Deployment, we found a discrepancy in the Corpus Access matrix. Currently the user contact has access to the design and management corpus. However, the contact user is only a member of the corpus design group. Please investigate what is the source of the information displayed in the matrix. 