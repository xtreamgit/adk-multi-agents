# Coding Session Summary - February 05, 2026
## Note for Hector - I had to re-create this file because the start alias command for this day failed.
## ⚠️ **Daily Startup Checklist**

Run these commands each morning to begin your coding session:

### 1. **Create Session Summary**
```bash
start
```
Creates today's session summary file automatically (alias for create-daily-summary.sh).

### 2. **Login to Google Cloud**
```bash
gcloud auth application-default login
```
Required for Vertex AI RAG access (document counts, corpus operations).

### 3. **Start Backend Server**
```bash
cd ~/github.com/xtreamgit/adk-multi-agents/backend
python -m uvicorn src.api.server:app --host 0.0.0.0 --port 8000 --reload
```
- Server: `http://localhost:8000`
- Keep terminal open or run in background

### 4. **Start Frontend Development Server** (new terminal)
```bash
cd ~/github.com/xtreamgit/adk-multi-agents/frontend
npm run dev
```
- Frontend: `http://localhost:3000`
- Keep terminal open

### 5. **Verify Everything is Running**
```bash
# Backend health check
curl http://localhost:8000/api/health

# Frontend: Open browser to http://localhost:3000
```
