# ADK RAG Agent - Architecture Diagrams

This directory contains PlantUML architecture diagrams for the ADK RAG Agent system.

## Available Diagrams

### 1. **architecture.puml** - Complete Architecture
**Comprehensive end-to-end architecture** showing all layers:
- Deployment configuration layer
- Multi-account configuration system
- Google Cloud infrastructure
- Backend RAG agent system
- Frontend Next.js application
- User flow and relationships

**Best for:** Understanding the complete system architecture and how all components interact.

### 2. **architecture-runtime.puml** - Runtime Architecture & User Flow
**Simplified runtime flow** focusing on:
- User request path through Load Balancer and IAP
- Frontend and Backend Cloud Run services
- Multi-account configuration loading
- RAG query execution flow
- Corpus management operations
- Vertex AI integration

**Best for:** Understanding how requests flow through the system and how the RAG agent processes queries.

### 3. **architecture-deployment.puml** - Deployment Pipeline
**Step-by-step deployment process** showing:
- Configuration reading
- Prerequisites and API enablement
- Infrastructure setup
- Cloud Run deployment with environment variables
- OAuth and IAP configuration
- Load Balancer setup
- CORS and finalization
- Validation steps

**Best for:** Understanding the deployment process and what each script does.

## Viewing the Diagrams

### Option 1: Online PlantUML Viewer
1. Go to [PlantUML Web Server](http://www.plantuml.com/plantuml/uml/)
2. Copy the contents of any `.puml` file
3. Paste into the text area
4. View the rendered diagram

### Option 2: VS Code Extension
1. Install the **PlantUML** extension by jebbs
2. Open any `.puml` file
3. Press `Alt+D` (Windows/Linux) or `Option+D` (Mac) to preview

### Option 3: IntelliJ/PyCharm Plugin
1. Install the **PlantUML integration** plugin
2. Open any `.puml` file
3. The diagram will render automatically in the editor

### Option 4: Command Line (requires GraphViz)
```bash
# Install PlantUML and GraphViz
brew install plantuml graphviz  # macOS
# or
sudo apt-get install plantuml graphviz  # Linux

# Generate PNG
plantuml architecture.puml
plantuml architecture-runtime.puml
plantuml architecture-deployment.puml

# Output: architecture.png, architecture-runtime.png, architecture-deployment.png
```

## Key Architecture Highlights

### Multi-Account Support
The system supports multiple accounts (clients) from a single codebase:
- **develom** → Develom project (`adk-rag-hdtest6`)
- **usfs** → USFS project (`usfs-rag-agent`)
- **tt** → TechTrend project (`adk-rag-tt`)

The `ACCOUNT_ENV` environment variable (set during deployment) determines which configuration to load.

### Security Layers
1. **IAP (Identity-Aware Proxy)** - Google OAuth authentication at infrastructure level
2. **JWT Authentication** - Application-level user authentication
3. **Service Account Permissions** - Fine-grained IAM permissions for GCP resources

### Request Flow
```
User → HTTPS (443) → Static IP → SSL → IAP → Load Balancer → Cloud Run Services
├── / paths → Frontend (Next.js)
└── /api/* paths → Backend (FastAPI + RAG Agent)
```

### RAG Agent Architecture
- **Configuration Loader** - Dynamically loads account-specific settings
- **Agent** - Google ADK Agent with Gemini 2.5 Flash
- **Tools** - 7 RAG tools (query, list, create, add, info, delete corpus/doc)
- **Vertex AI** - RAG corpora (vector store), embeddings, LLM

### Deployment Modules
```
deploy-all.sh
├── lib/prerequisites.sh    - API enablement
├── lib/infrastructure.sh   - Service accounts, Artifact Registry
├── lib/cloudrun.sh         - Build & deploy containers
├── lib/oauth.sh            - OAuth client setup
├── lib/loadbalancer.sh     - HTTPS Load Balancer
├── lib/iap.sh              - Enable IAP security
└── lib/finalize.sh         - CORS, frontend rebuild, verification
```

## File Locations

```
docs/
├── ARCHITECTURE-DIAGRAMS.md          (this file)
├── architecture.puml                 (complete architecture)
├── architecture-runtime.puml         (runtime flow)
└── architecture-deployment.puml      (deployment pipeline)
```

## Updating the Diagrams

When the architecture changes:

1. **Edit the `.puml` files** directly
2. **Validate syntax** using a PlantUML viewer
3. **Regenerate images** (optional, for documentation)
4. **Commit changes** to version control

## Additional Resources

- [PlantUML Documentation](https://plantuml.com/)
- [PlantUML Component Diagram](https://plantuml.com/component-diagram)
- [PlantUML Activity Diagram](https://plantuml.com/activity-diagram-beta)
- [PlantUML Deployment Diagram](https://plantuml.com/deployment-diagram)

## Questions?

For architecture questions or diagram updates, refer to:
- `README.md` - Project overview
- `backend/config/README.md` - Multi-account configuration
- `infrastructure/deploy-all.sh` - Deployment script with inline documentation
