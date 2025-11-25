# Changelog

All notable changes to the ADK RAG Agent project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] - develop branch

### Planned for v1.1.0
- Automated testing suite (unit, integration, performance)
- Secret Manager integration for secrets management
- Container vulnerability scanning (Trivy)
- Version tagging automation
- Infrastructure state management preparation

### Planned for v1.2.0
- Cloud Monitoring dashboards
- Cloud Logging aggregation
- Alerting policies
- Uptime checks
- Automated backup to Cloud SQL

### Planned for v2.0.0 (Breaking Changes)
- Terraform Infrastructure as Code migration
- Multi-environment support (dev, staging, production)
- GitOps workflow implementation
- Cloud SQL database (replacing SQLite)

---

## [1.0.0] - 2025-10-14

### Production Stable Release ✅

This release represents the first production-ready version with complete OAuth-protected deployment on Google Cloud Platform.

### Added
- **OAuth-Protected Access**: Google Identity-Aware Proxy (IAP) with organization restrictions
- **Load Balancer Architecture**: HTTPS/SSL with managed certificates
- **Cloud Armor Security**: SQL injection, XSS, and DDoS protection
- **JWT Authentication**: User authentication with SQLite backend
- **RAG Agent**: Vertex AI integration with corpus management
- **Simplified Deployment**: `deploy-all.sh` single-command deployment
- **Modular Infrastructure**: Library-based deployment scripts
  - `lib/prerequisites.sh` - API enablement and service accounts
  - `lib/oauth.sh` - OAuth consent screen and client management
  - `lib/infrastructure.sh` - Static IP, SSL, Artifact Registry
  - `lib/cloudrun.sh` - Container build and Cloud Run deployment
  - `lib/loadbalancer.sh` - Load Balancer with backend services
  - `lib/iap.sh` - IAP configuration and access control
  - `lib/finalize.sh` - Validation and summary
  - `lib/utils.sh` - Helper functions
- **Configuration Management**: Centralized `deployment.config` file
- **Comprehensive Documentation**:
  - Complete OAuth setup guide
  - Deployment checklist
  - Security architecture documentation
  - Troubleshooting guides
- **Validation Scripts**:
  - `validate-deployment.sh` - Deployment verification
  - `validate-security.sh` - Security testing
  - `validate-ingress-security.sh` - Ingress protection validation
  - `test-pipeline.sh` - Pipeline testing

### Changed
- Migrated from monolithic deployment script to modular library approach
- Improved error handling and validation throughout deployment
- Enhanced logging and user feedback
- Updated documentation for modular architecture

### Fixed
- IAP Error 52 (OAuth consent screen configuration)
- IAP Error 11 (OAuth redirect URI issues)
- IAP Error 9 (OAuth completion failures)
- HTTP 405 validation false positives
- Cloud Armor compatibility with CORS
- Deploy script verification false positives (adk-rag-hdtest pattern matching)
- SQLite database permissions in Cloud Run containers

### Security
- Two-layer authentication (IAP + JWT)
- Organization-restricted access (@develom.com domain)
- SSL/HTTPS encryption
- Cloud Armor protection rules:
  - Rule 100: SQL injection protection (deny-403)
  - Rule 200: XSS attack protection (deny-403)
  - Rule 300-400: File inclusion protection (deny-403)
  - Rule 500: Rate limiting (throttle, 100 req/min)
- IAM permissions with principle of least privilege
- Service account isolation

### Infrastructure
- **Project**: adk-rag-hdtest6
- **Region**: us-east4
- **Frontend**: Next.js on Cloud Run (https://frontend-*.a.run.app)
- **Backend**: FastAPI on Cloud Run (https://backend-*.a.run.app)
- **Load Balancer**: https://34.36.175.81.nip.io
- **Vertex AI**: Gemini models with RAG engine
- **Storage**: Google Cloud Storage for corpus documents

### Performance
- Optimized container images (multi-stage builds)
- Next.js standalone output for reduced size
- Proper caching strategies
- Rate limiting for API protection

### Known Issues
- SQLite database is not production-ready for multi-instance deployments
  - Recommendation: Migrate to Cloud SQL in v1.2.0
- Frontend tests are not implemented yet
  - Planned for v1.1.0
- Secrets management is manual (secrets.env file)
  - Will be automated with Secret Manager in v1.1.0

### Migration Notes
- No breaking changes from previous versions
- First tagged production release

---

## Previous Versions (Untagged)

### Pre-v1.0.0 Development
- Initial RAG agent implementation
- Basic Cloud Run deployment
- Manual OAuth configuration
- Prototype frontend/backend architecture
- Various deployment script iterations

### Historical Branches
- **cicd**: CI/CD improvements and deploy-all.sh simplification (merged to v1.0.0)
- **deploy**: Deployment script development (legacy)
- **network**: Network and security configuration (legacy)

---

## Version Comparison

### v1.0.0 vs Pre-release
- ✅ Modular deployment scripts (was: monolithic)
- ✅ One-command deployment (was: multi-step manual)
- ✅ Comprehensive validation (was: basic checks)
- ✅ Production-ready security (was: prototype)
- ✅ Complete documentation (was: scattered notes)

---

## Deployment History

| Version | Date | Environment | Status | Notes |
|---------|------|-------------|--------|-------|
| v1.0.0 | 2025-10-14 | adk-rag-hdtest6 | ✅ Active | Production stable |

---

## Contributing

When adding entries to this changelog:

1. **Group changes** by type:
   - `Added` for new features
   - `Changed` for changes in existing functionality
   - `Deprecated` for soon-to-be removed features
   - `Removed` for now removed features
   - `Fixed` for any bug fixes
   - `Security` for vulnerability fixes

2. **Reference issues/PRs** when applicable:
   - Example: `Fixed IAP authentication timeout (#123)`

3. **Keep Unreleased section** at the top for ongoing work

4. **Update on each release**:
   - Move Unreleased items to new version section
   - Update version number and date
   - Add deployment information

---

## Changelog Maintenance

This changelog is manually maintained and should be updated:
- Before each release
- When merging significant features to develop
- When fixing critical bugs
- When making breaking changes

**Last Updated**: October 14, 2025  
**Maintained By**: Hector DeJesus
