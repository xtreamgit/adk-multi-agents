# Google Cloud IAM Integration Migration Plan
## From Application-Based Auth to Cloud IAM

**Project**: adk-multi-agents RAG System  
**Date**: January 16, 2026  
**Objective**: Migrate from application-managed authentication/authorization to Google Cloud IAM

---

## Executive Summary

This plan outlines the migration from the current application-based authentication system to Google Cloud IAM. The goal is to leverage Google Cloud's native identity and access management capabilities for secure, centralized, and organization-wide control of RAG application access.

### Current State
- **Authentication**: Dual-mode (IAP + Local username/password)
- **Authorization**: Application database (users → groups → roles → permissions)
- **Corpus Access**: Managed via `group_corpus_access` table
- **User Management**: Custom admin panel with database records

### Target State
- **Authentication**: Google Cloud IAM via Identity-Aware Proxy (IAP)
- **Authorization**: Cloud IAM roles and policies
- **Corpus Access**: IAM custom roles with resource-level permissions
- **User Management**: Google Cloud Console + Workspace Admin + IAM policies

---

## Architecture Overview

### Current Architecture
```
User Login → IAP/Local Auth → User DB Record → Group Membership → 
Group Roles → Role Permissions → Corpus Access Check → Allow/Deny
```

### Target Architecture
```
User Login → IAP → IAM Token → IAM Policy Evaluation → 
Custom IAM Roles → Resource Bindings → Allow/Deny
```

---

## Phase 1: IAM Foundation Setup

### 1.1 Define Custom IAM Roles

Google Cloud IAM will need custom roles to represent RAG-specific permissions:

**Custom Role: `rag.corpusReader`**
- **Title**: RAG Corpus Reader
- **Description**: Read access to RAG corpora and ability to query
- **Permissions**:
  - `rag.corpora.list`
  - `rag.corpora.get`
  - `rag.queries.create`
  - `rag.sessions.create`
  - `rag.sessions.read`

**Custom Role: `rag.corpusWriter`**
- **Title**: RAG Corpus Writer
- **Description**: Write access to upload documents to corpora
- **Permissions**:
  - All from `rag.corpusReader`
  - `rag.documents.upload`
  - `rag.documents.delete`
  - `rag.corpora.sync`

**Custom Role: `rag.corpusAdmin`**
- **Title**: RAG Corpus Administrator
- **Description**: Full administrative access to corpora
- **Permissions**:
  - All from `rag.corpusWriter`
  - `rag.corpora.create`
  - `rag.corpora.update`
  - `rag.corpora.delete`
  - `rag.access.manage`

**Custom Role: `rag.systemAdmin`**
- **Title**: RAG System Administrator
- **Description**: Full system administration
- **Permissions**:
  - All from `rag.corpusAdmin`
  - `rag.agents.manage`
  - `rag.users.manage`
  - `rag.settings.manage`

### 1.2 Create IAM Custom Roles

**Implementation Steps**:

1. **Create role definition files** (YAML format):

```yaml
# roles/rag-corpus-reader.yaml
title: "RAG Corpus Reader"
description: "Read access to RAG corpora and ability to query"
stage: "GA"
includedPermissions:
- rag.corpora.list
- rag.corpora.get
- rag.queries.create
- rag.sessions.create
- rag.sessions.read
```

2. **Deploy roles using gcloud**:
```bash
gcloud iam roles create ragCorpusReader \
  --project=adk-rag-ma \
  --file=roles/rag-corpus-reader.yaml

gcloud iam roles create ragCorpusWriter \
  --project=adk-rag-ma \
  --file=roles/rag-corpus-writer.yaml

gcloud iam roles create ragCorpusAdmin \
  --project=adk-rag-ma \
  --file=roles/rag-corpus-admin.yaml

gcloud iam roles create ragSystemAdmin \
  --project=adk-rag-ma \
  --file=roles/rag-system-admin.yaml
```

3. **Verify role creation**:
```bash
gcloud iam roles describe ragCorpusReader --project=adk-rag-ma
```

### 1.3 Set Up Google Groups for Access Management

Create Google Workspace/Cloud Identity groups:

- `rag-users@example.com` → `rag.corpusReader`
- `rag-contributors@example.com` → `rag.corpusWriter`
- `rag-admins@example.com` → `rag.corpusAdmin`
- `rag-system-admins@example.com` → `rag.systemAdmin`

**Benefits**:
- Centralized group management in Google Workspace
- Easier user on/offboarding
- Audit trail via Google Workspace logs
- Integration with existing organizational structure

---

## Phase 2: Backend Service Integration

### 2.1 Create IAM Authorization Service

Create new service: `backend/src/services/iam_service.py`

**Key Functions**:

```python
class IAMService:
    """Google Cloud IAM integration service."""
    
    @staticmethod
    def get_user_permissions(user_email: str) -> List[str]:
        """
        Fetch IAM permissions for a user from Cloud IAM.
        Uses IAM Policy API to check user's effective permissions.
        """
        
    @staticmethod
    def check_permission(user_email: str, permission: str, resource: str = None) -> bool:
        """
        Check if user has specific permission.
        Queries IAM testIamPermissions API.
        """
        
    @staticmethod
    def get_user_groups(user_email: str) -> List[str]:
        """
        Get Google Groups user belongs to.
        Uses Cloud Identity Groups API.
        """
        
    @staticmethod
    def get_corpus_bindings(corpus_name: str) -> Dict:
        """
        Get IAM policy bindings for a specific corpus resource.
        """
```

### 2.2 Update IAP Middleware

Modify `backend/src/middleware/iap_auth_middleware.py`:

**Changes**:
1. Extract user email from IAP JWT (already done)
2. Call `IAMService.get_user_permissions()` to fetch IAM permissions
3. Store permissions in user context/session
4. Cache permissions (5-15 minutes TTL) to reduce IAM API calls

**Example**:
```python
async def get_current_user_iap(request: Request) -> User:
    # Existing IAP JWT verification
    decoded_token = IAPService.verify_iap_jwt(iap_jwt)
    user_info = IAPService.extract_user_info(decoded_token)
    email = user_info['email']
    
    # NEW: Fetch IAM permissions
    permissions = await IAMService.get_user_permissions(email)
    groups = await IAMService.get_user_groups(email)
    
    # Store in user object
    user = UserService.get_or_create_user(email)
    user.iam_permissions = permissions
    user.iam_groups = groups
    
    return user
```

### 2.3 Update Authorization Middleware

Modify `backend/src/middleware/authorization_middleware.py`:

**Changes**:
1. Replace `GroupService.check_permission()` with `IAMService.check_permission()`
2. Update permission strings to match IAM custom role permissions
3. Add resource-level permission checks (e.g., specific corpus access)

**Example**:
```python
def require_permission(permission: str, resource: str = None) -> Callable:
    async def permission_checker(user: User = Depends(get_current_user_iap)) -> User:
        # Check IAM permission instead of database
        has_permission = await IAMService.check_permission(
            user.email, 
            permission,
            resource
        )
        
        if not has_permission:
            raise HTTPException(
                status_code=403,
                detail=f"Missing IAM permission: {permission}"
            )
        
        return user
    
    return permission_checker
```

### 2.4 Update Corpus Service

Modify `backend/src/services/corpus_service.py`:

**Changes**:
1. Replace `CorpusRepository.get_user_corpora()` with IAM policy checks
2. Query IAM bindings for corpus resources
3. Filter corpora based on IAM permissions instead of database

**Example**:
```python
@staticmethod
async def get_user_corpora(user_email: str) -> List[CorpusWithAccess]:
    """Get corpora user has IAM access to."""
    all_corpora = await CorpusRepository.get_all(active_only=True)
    
    accessible_corpora = []
    for corpus in all_corpora:
        # Check IAM permission for this corpus
        has_access = await IAMService.check_permission(
            user_email,
            'rag.corpora.get',
            resource=f'corpora/{corpus.name}'
        )
        
        if has_access:
            # Determine permission level
            permission = await IAMService.get_corpus_permission(
                user_email,
                corpus.name
            )
            accessible_corpora.append(
                CorpusWithAccess(**corpus.dict(), permission=permission)
            )
    
    return accessible_corpora
```

---

## Phase 3: IAM Resource Hierarchy

### 3.1 Define Resource Hierarchy

Organize RAG resources in a logical hierarchy:

```
Project: adk-rag-ma
├── Custom Roles
│   ├── rag.corpusReader
│   ├── rag.corpusWriter
│   ├── rag.corpusAdmin
│   └── rag.systemAdmin
├── Resources
│   ├── corpora/
│   │   ├── develom-general
│   │   ├── develom-tech
│   │   ├── design
│   │   └── management
│   ├── agents/
│   │   ├── agent1
│   │   ├── agent2
│   │   └── agent3
│   └── sessions/
│       └── user-sessions
└── IAM Bindings
    ├── Group: rag-users@example.com → rag.corpusReader
    ├── Group: rag-contributors@example.com → rag.corpusWriter
    └── Group: rag-admins@example.com → rag.corpusAdmin
```

### 3.2 Resource Naming Convention

Use consistent resource naming:

- **Corpora**: `projects/{project}/corpora/{corpus_name}`
- **Agents**: `projects/{project}/agents/{agent_name}`
- **Sessions**: `projects/{project}/sessions/{session_id}`

### 3.3 Implement Resource Conditions

Use IAM Conditions for fine-grained access control:

**Example - Time-based access**:
```yaml
condition:
  title: "Business hours only"
  expression: |
    request.time > timestamp("2024-01-01T09:00:00Z") &&
    request.time < timestamp("2024-01-01T17:00:00Z")
```

**Example - Corpus-specific access**:
```yaml
condition:
  title: "Design corpus only"
  expression: |
    resource.name.startsWith("projects/adk-rag-ma/corpora/design")
```

---

## Phase 4: Migration Strategy

### 4.1 Hybrid Mode (Transition Period)

Run both systems in parallel:

**Duration**: 2-4 weeks

**Implementation**:
1. Keep existing database tables (users, groups, roles)
2. Add IAM service alongside existing auth
3. Create feature flag: `USE_IAM_AUTH`
4. Log both permission checks for comparison
5. Alert on permission mismatches

```python
async def check_permission_hybrid(user: User, permission: str) -> bool:
    # Check both systems
    db_result = GroupService.check_permission(user.id, permission)
    iam_result = await IAMService.check_permission(user.email, permission)
    
    # Log mismatch
    if db_result != iam_result:
        logger.warning(
            f"Permission mismatch for {user.email}: "
            f"DB={db_result}, IAM={iam_result}"
        )
    
    # Use IAM if feature flag enabled, otherwise database
    return iam_result if USE_IAM_AUTH else db_result
```

### 4.2 User Migration

**Steps**:

1. **Export current users and groups**:
```bash
python backend/scripts/export_users_to_iam.py
```

2. **Create Google Groups** (if not exist):
```bash
gcloud identity groups create rag-users@example.com \
  --organization=example.com \
  --display-name="RAG Users"
```

3. **Add users to groups**:
```bash
gcloud identity groups memberships add \
  --group-email=rag-users@example.com \
  --member-email=user@example.com
```

4. **Bind groups to IAM roles**:
```bash
gcloud projects add-iam-policy-binding adk-rag-ma \
  --member=group:rag-users@example.com \
  --role=projects/adk-rag-ma/roles/ragCorpusReader
```

### 4.3 Permission Mapping

Map existing database permissions to IAM permissions:

| Database Permission | IAM Permission | IAM Role |
|---------------------|----------------|----------|
| `read:corpus` | `rag.corpora.get` | `ragCorpusReader` |
| `write:corpus` | `rag.documents.upload` | `ragCorpusWriter` |
| `manage:corpus_access` | `rag.access.manage` | `ragCorpusAdmin` |
| `create:corpus` | `rag.corpora.create` | `ragCorpusAdmin` |
| `manage:users` | `rag.users.manage` | `ragSystemAdmin` |
| `*` (wildcard) | All permissions | `ragSystemAdmin` |

### 4.4 Testing Phase

**Test Matrix**:

| User Type | Test Case | Expected Result |
|-----------|-----------|-----------------|
| Reader | List corpora | ✅ Success |
| Reader | Upload document | ❌ 403 Forbidden |
| Writer | Upload document | ✅ Success |
| Writer | Delete corpus | ❌ 403 Forbidden |
| Admin | Create corpus | ✅ Success |
| Admin | Manage users | ❌ 403 (System Admin only) |
| System Admin | All operations | ✅ Success |

### 4.5 Cutover Plan

**Go-Live Checklist**:

- [ ] All custom IAM roles created
- [ ] All Google Groups created and populated
- [ ] IAM policy bindings configured
- [ ] IAM service implemented and tested
- [ ] Authorization middleware updated
- [ ] Integration tests passing
- [ ] Performance tests completed (IAM API latency)
- [ ] Monitoring and alerts configured
- [ ] Rollback plan documented
- [ ] User communication sent

**Cutover Steps**:

1. **Enable IAM mode** (flip feature flag)
2. **Monitor error rates** (15 minutes)
3. **Verify user access** (sample users)
4. **Check permission logs** (no errors)
5. **Run smoke tests** (critical paths)
6. **Announce completion**

**Rollback Trigger**:
- Error rate > 5%
- Critical permission failures
- IAM API unavailable
- User lockouts

---

## Phase 5: Database Schema Changes

### 5.1 Deprecate Old Tables

Tables to deprecate (keep for audit/rollback):

- `groups` - Replaced by Google Groups
- `roles` - Replaced by IAM Custom Roles
- `user_groups` - Replaced by Group Memberships
- `group_roles` - Replaced by IAM Bindings
- `group_corpus_access` - Replaced by IAM Resource Policies

### 5.2 Add IAM Tracking Tables

New tables for caching and audit:

```sql
-- Cache IAM permissions (reduce API calls)
CREATE TABLE iam_permission_cache (
    id SERIAL PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    permission VARCHAR(255) NOT NULL,
    resource VARCHAR(500),
    has_permission BOOLEAN NOT NULL,
    cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    INDEX idx_cache_lookup (user_email, permission, resource, expires_at)
);

-- Audit IAM permission checks
CREATE TABLE iam_permission_audit (
    id SERIAL PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    permission VARCHAR(255) NOT NULL,
    resource VARCHAR(500),
    granted BOOLEAN NOT NULL,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    request_ip VARCHAR(45),
    user_agent TEXT,
    INDEX idx_audit_user (user_email, checked_at),
    INDEX idx_audit_permission (permission, checked_at)
);

-- Sync Google Groups to local cache
CREATE TABLE google_groups_cache (
    id SERIAL PRIMARY KEY,
    group_email VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    member_count INTEGER DEFAULT 0,
    synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_group_sync (synced_at)
);

-- Track group memberships
CREATE TABLE google_group_members_cache (
    id SERIAL PRIMARY KEY,
    group_email VARCHAR(255) NOT NULL,
    member_email VARCHAR(255) NOT NULL,
    role VARCHAR(50), -- MEMBER, MANAGER, OWNER
    synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(group_email, member_email),
    INDEX idx_member_lookup (member_email, synced_at)
);
```

### 5.3 Migration Script

Create migration: `backend/migrations/migrate_to_iam.py`

---

## Phase 6: Security Considerations

### 6.1 IAM Best Practices

**Principle of Least Privilege**:
- Grant minimum permissions required
- Use time-bound access when possible
- Regularly audit and revoke unused permissions

**Separation of Duties**:
- System admins ≠ Corpus admins
- Read-only roles for most users
- Admin operations require elevation

**Defense in Depth**:
- IAP for authentication
- IAM for authorization
- Application-level validation
- VPC Service Controls

### 6.2 Service Account Security

**Application Service Account**:
```yaml
# Service account for backend application
name: rag-backend@adk-rag-ma.iam.gserviceaccount.com
roles:
  - roles/iam.serviceAccountTokenCreator  # Create tokens
  - roles/cloudidentity.groupsViewer      # Read groups
  - roles/iam.securityReviewer            # Check permissions
  - projects/adk-rag-ma/roles/ragSystemAdmin  # App admin
```

**Workload Identity**:
- Use Workload Identity for Cloud Run
- Bind Kubernetes Service Account to Google Service Account
- Avoid service account key files

### 6.3 Audit Logging

Enable Cloud Audit Logs:

```bash
gcloud projects add-iam-policy-binding adk-rag-ma \
  --member=serviceAccount:cloud-logs@system.gserviceaccount.com \
  --role=roles/logging.logWriter
```

**Log Types**:
- Admin Activity (always on)
- Data Access (enable for IAM)
- System Events
- Policy Denied

### 6.4 Access Transparency

Monitor IAM permission checks:

```python
def log_permission_check(user_email: str, permission: str, granted: bool):
    logger.info(
        "IAM permission check",
        extra={
            "user": user_email,
            "permission": permission,
            "granted": granted,
            "timestamp": datetime.utcnow().isoformat()
        }
    )
```

---

## Phase 7: Performance Optimization

### 7.1 Permission Caching

**Strategy**:
- Cache IAM permissions for 5-15 minutes
- Use Redis for distributed cache
- Invalidate on policy changes

**Implementation**:
```python
class IAMPermissionCache:
    def __init__(self, redis_client, ttl=300):
        self.redis = redis_client
        self.ttl = ttl
    
    def get(self, user_email: str, permission: str, resource: str = None):
        key = f"iam:{user_email}:{permission}:{resource or 'global'}"
        return self.redis.get(key)
    
    def set(self, user_email: str, permission: str, has_permission: bool, resource: str = None):
        key = f"iam:{user_email}:{permission}:{resource or 'global'}"
        self.redis.setex(key, self.ttl, str(has_permission))
```

### 7.2 Batch Permission Checks

Check multiple permissions in one API call:

```python
async def check_permissions_batch(
    user_email: str, 
    permissions: List[str],
    resource: str = None
) -> Dict[str, bool]:
    """Check multiple permissions in single API call."""
    response = await iam_client.test_iam_permissions(
        resource=resource,
        permissions=permissions
    )
    return {p: p in response.permissions for p in permissions}
```

### 7.3 Async IAM Calls

Use async/await for IAM API calls:

```python
import asyncio
from google.cloud import iam_admin_v1

async def get_user_permissions_async(user_email: str):
    # Use async IAM client
    async with iam_admin_v1.IAMAsyncClient() as client:
        request = iam_admin_v1.TestIamPermissionsRequest(...)
        response = await client.test_iam_permissions(request)
        return response.permissions
```

---

## Phase 8: Monitoring and Alerting

### 8.1 Key Metrics

**IAM Performance Metrics**:
- `iam_permission_check_latency_ms` - P50, P95, P99
- `iam_api_call_count` - Rate per minute
- `iam_cache_hit_rate` - Percentage
- `iam_permission_denied_count` - Rate per minute

**User Access Metrics**:
- `user_login_count` - Daily active users
- `corpus_access_count` - Per corpus
- `permission_denied_by_user` - Failed access attempts

### 8.2 Alerts

**Critical Alerts**:
```yaml
# IAM API failure
- name: iam_api_failure_rate_high
  condition: error_rate > 5%
  duration: 5m
  severity: CRITICAL
  action: Page on-call, rollback to database auth

# Permission denied spike
- name: permission_denied_spike
  condition: denied_rate > 10% above baseline
  duration: 10m
  severity: WARNING
  action: Investigate IAM policy changes
```

### 8.3 Dashboards

Create Cloud Monitoring dashboard:

**Panels**:
1. IAM API Latency (line chart)
2. Permission Check Rate (rate)
3. Cache Hit Rate (gauge)
4. Top Denied Permissions (table)
5. User Activity Heatmap (heatmap)
6. Error Rate by Permission (stacked area)

---

## Phase 9: Documentation and Training

### 9.1 Admin Documentation

Create guide: `docs/IAM_ADMINISTRATION_GUIDE.md`

**Topics**:
- How to add/remove users from Google Groups
- How to grant corpus-specific access
- How to create temporary access
- How to audit user permissions
- How to troubleshoot access issues

### 9.2 User Documentation

Create guide: `docs/IAM_USER_GUIDE.md`

**Topics**:
- How to request access
- How to view your permissions
- How to report access issues
- FAQs

### 9.3 Developer Documentation

Create guide: `docs/IAM_DEVELOPER_GUIDE.md`

**Topics**:
- IAM service API reference
- How to add new permissions
- How to create new roles
- Testing with IAM emulator
- Local development setup

### 9.4 Runbook

Create operational guide: `docs/IAM_RUNBOOK.md`

**Sections**:
- Common issues and solutions
- Emergency rollback procedure
- Permission debugging
- IAM API quota management
- Incident response playbook

---

## Implementation Timeline

### Week 1-2: Foundation
- [ ] Create custom IAM roles
- [ ] Set up Google Groups
- [ ] Implement IAMService
- [ ] Add permission caching
- [ ] Write unit tests

### Week 3-4: Integration
- [ ] Update IAP middleware
- [ ] Update authorization middleware
- [ ] Update corpus service
- [ ] Add audit logging
- [ ] Integration tests

### Week 5-6: Migration
- [ ] Enable hybrid mode
- [ ] Migrate users to Google Groups
- [ ] Configure IAM bindings
- [ ] Performance testing
- [ ] Security review

### Week 7: Testing
- [ ] User acceptance testing
- [ ] Load testing
- [ ] Security testing
- [ ] Documentation review
- [ ] Training sessions

### Week 8: Go-Live
- [ ] Cutover to IAM mode
- [ ] Monitor closely (24h)
- [ ] Fix issues
- [ ] Stabilize
- [ ] Deprecate old tables

---

## Rollback Plan

### Trigger Conditions
- IAM API unavailable > 5 minutes
- Error rate > 10%
- Multiple user lockouts
- Security incident

### Rollback Steps

1. **Immediate** (< 1 minute):
   ```python
   # Flip feature flag back
   os.environ['USE_IAM_AUTH'] = 'false'
   ```

2. **Verify** (2 minutes):
   - Check error rates drop
   - Verify users can login
   - Test sample operations

3. **Communicate** (5 minutes):
   - Alert team
   - Update status page
   - Notify affected users

4. **Post-mortem** (24 hours):
   - Document what went wrong
   - Create fix plan
   - Schedule retry

---

## Cost Considerations

### IAM API Costs
- Free tier: 1M requests/month
- Beyond: $0.005 per 1,000 requests
- Estimated: 100K requests/day = $15/month

### Cloud Identity Costs
- Free: Cloud Identity Free
- Paid: $6/user/month (Enterprise features)

### Monitoring Costs
- Cloud Logging: ~$0.50/GB
- Cloud Monitoring: ~$0.25/MB
- Estimated: $50/month

**Total Estimated Cost**: $65-80/month

---

## Success Criteria

### Functional Requirements
- ✅ All users can authenticate via IAP
- ✅ Permissions correctly enforced via IAM
- ✅ Corpus access controlled by IAM roles
- ✅ Admin operations require appropriate roles
- ✅ Audit logs capture all permission checks

### Non-Functional Requirements
- ✅ P95 latency < 100ms (with caching)
- ✅ 99.9% availability
- ✅ Zero data breaches
- ✅ Zero unauthorized access
- ✅ 100% audit coverage

### Business Requirements
- ✅ Centralized user management
- ✅ Integration with Google Workspace
- ✅ Reduced admin overhead
- ✅ Improved security posture
- ✅ Better compliance reporting

---

## Appendix

### A. Required GCP APIs

Enable these APIs:
```bash
gcloud services enable iam.googleapis.com
gcloud services enable cloudidentity.googleapis.com
gcloud services enable iap.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
```

### B. Service Account Permissions

Required for backend service account:
- `iam.serviceAccounts.signBlob`
- `iam.serviceAccounts.getAccessToken`
- `cloudidentity.groups.get`
- `cloudidentity.memberships.list`
- `resourcemanager.projects.getIamPolicy`
- `logging.logEntries.create`

### C. Testing Checklist

- [ ] Unit tests for IAMService
- [ ] Integration tests for IAP + IAM
- [ ] E2E tests for user flows
- [ ] Load tests for IAM API
- [ ] Security tests for unauthorized access
- [ ] Failover tests for IAM unavailability
- [ ] Performance tests for cache effectiveness

### D. References

- [Google Cloud IAM Documentation](https://cloud.google.com/iam/docs)
- [Identity-Aware Proxy](https://cloud.google.com/iap/docs)
- [Cloud Identity Groups](https://cloud.google.com/identity/docs/groups)
- [IAM Custom Roles](https://cloud.google.com/iam/docs/creating-custom-roles)
- [IAM Best Practices](https://cloud.google.com/iam/docs/using-iam-securely)

---

## Next Steps

1. **Review this plan** with stakeholders
2. **Get approval** for timeline and approach
3. **Provision resources** (groups, roles, service accounts)
4. **Begin Phase 1** implementation
5. **Schedule regular check-ins** (weekly)

**Questions to Address**:
- [ ] Which Google Workspace domain to use?
- [ ] Who are the initial system admins?
- [ ] What is the rollout schedule?
- [ ] What are the approval gates?
- [ ] Who handles Google Groups management?
