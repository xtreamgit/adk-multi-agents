# Automatic Staging Deployment with GitHub Actions

Yes! **GitHub Actions** is the most common way to automatically deploy to staging. Let me explain how it works.

---

## 🎯 How Automatic Deployment Works

### **The Trigger: Git Push**

```bash
# Developer pushes to staging branch
git checkout staging
git merge develop --no-ff -m "Release candidate v1.1.0"
git push origin staging

# ↓ This push triggers GitHub Actions
# ↓ GitHub Actions automatically deploys to GCP
# ✅ Staging environment updated
```

---

## 📋 GitHub Actions Workflow File

You need to create a workflow file: `.github/workflows/deploy.yml`

### **Basic Example:**

```yaml
# .github/workflows/deploy.yml
name: Deploy to Environments

on:
  push:
    branches:
      - develop   # Auto-deploy to dev
      - staging   # Auto-deploy to staging
      - main      # Auto-deploy to production
    tags:
      - 'v*.*.*'  # Deploy on version tags

jobs:
  # ============================================
  # Deploy to Development Environment
  # ============================================
  deploy-dev:
    name: Deploy to Development
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY_DEV }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
      
      - name: Deploy to Dev Environment
        run: |
          chmod +x infrastructure/deploy-all.sh
          ./infrastructure/deploy-all.sh
        env:
          PROJECT_ID: adk-rag-dev
          REGION: us-east4
          ENVIRONMENT: dev

  # ============================================
  # Deploy to Staging Environment
  # ============================================
  deploy-staging:
    name: Deploy to Staging
    if: github.ref == 'refs/heads/staging'
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY_STAGING }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
      
      - name: Run tests before deployment
        run: |
          # Run your test suite
          pytest backend/tests/ -v
      
      - name: Deploy to Staging Environment
        run: |
          chmod +x infrastructure/deploy-all.sh
          ./infrastructure/deploy-all.sh
        env:
          PROJECT_ID: adk-rag-staging
          REGION: us-east4
          ENVIRONMENT: staging
      
      - name: Run smoke tests
        run: |
          chmod +x infrastructure/validate-deployment.sh
          ./infrastructure/validate-deployment.sh
      
      - name: Notify team
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Staging deployment complete: v${{ github.sha }}"
            }

  # ============================================
  # Deploy to Production Environment
  # ============================================
  deploy-production:
    name: Deploy to Production
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY_PROD }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
      
      - name: Deploy to Production
        run: |
          chmod +x infrastructure/deploy-all.sh
          ./infrastructure/deploy-all.sh
        env:
          PROJECT_ID: adk-rag-prod
          REGION: us-east4
          ENVIRONMENT: production
      
      - name: Create GitHub Release
        uses: actions/create-release@v1
        with:
          tag_name: ${{ github.ref }}
          release_name: Release ${{ github.ref }}
```

---

## 🔐 Setup: GitHub Secrets

For this to work, you need to configure **GitHub Secrets**:

### **1. Create GCP Service Account Keys**

```bash
# For each environment (dev, staging, prod)

# Create service account
gcloud iam service-accounts create github-actions-staging \
  --project=adk-rag-staging

# Grant necessary permissions
gcloud projects add-iam-policy-binding adk-rag-staging \
  --member="serviceAccount:github-actions-staging@adk-rag-staging.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding adk-rag-staging \
  --member="serviceAccount:github-actions-staging@adk-rag-staging.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Create key
gcloud iam service-accounts keys create key-staging.json \
  --iam-account=github-actions-staging@adk-rag-staging.iam.gserviceaccount.com
```

### **2. Add Secrets to GitHub**

1. Go to GitHub repository → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these secrets:

```
Name: GCP_SA_KEY_DEV
Value: <contents of key-dev.json>

Name: GCP_SA_KEY_STAGING
Value: <contents of key-staging.json>

Name: GCP_SA_KEY_PROD
Value: <contents of key-prod.json>
```

---

## 🚀 How It Works: Step-by-Step

### **Scenario: Deploy to Staging**

```bash
# 1. Developer merges develop to staging
git checkout staging
git merge develop --no-ff
git push origin staging

# 2. GitHub detects push to staging branch
# 3. GitHub Actions workflow starts
# 4. Workflow checks: if branch == staging
# 5. Spins up Ubuntu runner
# 6. Checks out your code
# 7. Authenticates to GCP using service account key
# 8. Runs your deployment script
# 9. Deployment script:
#    - Builds Docker images
#    - Pushes to Artifact Registry
#    - Deploys to Cloud Run (staging project)
#    - Configures Load Balancer
#    - Runs validation tests
# 10. Sends notification (Slack/email)
# ✅ Staging environment updated!
```

---

## 🎨 Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                 Automatic Staging Deployment                │
└─────────────────────────────────────────────────────────────┘

Developer's Computer:
  git push origin staging
         │
         ▼
  ┌─────────────┐
  │   GitHub    │
  │ Repository  │
  └──────┬──────┘
         │ Detects push to staging branch
         ▼
  ┌─────────────┐
  │   GitHub    │
  │   Actions   │
  └──────┬──────┘
         │ Triggers workflow
         ▼
  ┌─────────────────────────────────┐
  │   Ubuntu Runner (Cloud VM)      │
  ├─────────────────────────────────┤
  │ 1. Checkout code                │
  │ 2. Authenticate to GCP          │
  │ 3. Run deployment script        │
  └──────┬──────────────────────────┘
         │
         ▼
  ┌─────────────────────────────────┐
  │   Google Cloud Platform         │
  │   (adk-rag-staging project)     │
  ├─────────────────────────────────┤
  │ 1. Build Docker images          │
  │ 2. Push to Artifact Registry    │
  │ 3. Deploy to Cloud Run          │
  │ 4. Configure Load Balancer      │
  │ 5. Run smoke tests              │
  └──────┬──────────────────────────┘
         │
         ▼
  ✅ Staging Environment Updated
         │
         ▼
  📧 Notification sent to team
```

---

## 📝 Complete Workflow Example

Here's a production-ready example with all best practices:

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging

on:
  push:
    branches:
      - staging

env:
  PROJECT_ID: adk-rag-staging
  REGION: us-east4
  FRONTEND_IMAGE: us-east4-docker.pkg.dev/adk-rag-staging/cloud-run-repo/frontend
  BACKEND_IMAGE: us-east4-docker.pkg.dev/adk-rag-staging/cloud-run-repo/backend

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt
      
      - name: Run backend tests
        run: |
          pytest backend/tests/ -v --cov --cov-fail-under=80
      
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
      
      - name: Install frontend dependencies
        run: |
          cd frontend
          npm ci
      
      - name: Run frontend tests
        run: |
          cd frontend
          npm run build

  deploy:
    name: Deploy to Staging
    needs: test  # Only deploy if tests pass
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY_STAGING }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
      
      - name: Configure Docker for Artifact Registry
        run: |
          gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev
      
      - name: Build and push backend image
        run: |
          cd backend
          docker build -t ${{ env.BACKEND_IMAGE }}:${{ github.sha }} .
          docker push ${{ env.BACKEND_IMAGE }}:${{ github.sha }}
      
      - name: Build and push frontend image
        run: |
          cd frontend
          docker build -t ${{ env.FRONTEND_IMAGE }}:${{ github.sha }} .
          docker push ${{ env.FRONTEND_IMAGE }}:${{ github.sha }}
      
      - name: Deploy to Cloud Run
        run: |
          # Deploy backend
          gcloud run deploy backend \
            --image=${{ env.BACKEND_IMAGE }}:${{ github.sha }} \
            --region=${{ env.REGION }} \
            --platform=managed \
            --project=${{ env.PROJECT_ID }}
          
          # Deploy frontend
          gcloud run deploy frontend \
            --image=${{ env.FRONTEND_IMAGE }}:${{ github.sha }} \
            --region=${{ env.REGION }} \
            --platform=managed \
            --project=${{ env.PROJECT_ID }}
      
      - name: Run smoke tests
        run: |
          chmod +x infrastructure/validate-deployment.sh
          ./infrastructure/validate-deployment.sh --env=staging
      
      - name: Notify on success
        if: success()
        run: |
          echo "✅ Staging deployment successful!"
          # Add Slack/email notification here
      
      - name: Notify on failure
        if: failure()
        run: |
          echo "❌ Staging deployment failed!"
          # Add Slack/email notification here
```

---

## 🛠️ Alternative: Manual Approval for Staging

If you want **manual approval** before deploying to staging:

```yaml
deploy-staging:
  name: Deploy to Staging
  runs-on: ubuntu-latest
  environment:
    name: staging
    url: https://staging.yourdomain.com
  
  steps:
    # ... deployment steps ...
```

Then in GitHub:
1. **Settings** → **Environments** → **New environment** → "staging"
2. Check **Required reviewers**
3. Add team members who must approve

Now when you push to staging:
- GitHub Actions **pauses** and waits
- Sends notification to reviewers
- Reviewer clicks **Approve**
- Deployment proceeds

---

## 🔄 Complete CI/CD Pipeline

```yaml
# .github/workflows/cicd.yml
name: Complete CI/CD Pipeline

on:
  push:
    branches: [develop, staging, main]
  pull_request:
    branches: [main, staging]

jobs:
  # Stage 1: Test everything
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run all tests
        run: pytest -v

  # Stage 2: Security scan
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run security scan
        run: |
          pip install bandit safety
          bandit -r backend/
          safety check

  # Stage 3: Build images
  build:
    needs: [test, security]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker images
        run: docker build -t myapp:${{ github.sha }} .

  # Stage 4: Deploy to appropriate environment
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to dev
        run: ./infrastructure/deploy-all.sh --env=dev

  deploy-staging:
    if: github.ref == 'refs/heads/staging'
    needs: build
    runs-on: ubuntu-latest
    environment: staging  # Requires approval
    steps:
      - name: Deploy to staging
        run: ./infrastructure/deploy-all.sh --env=staging

  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: build
    runs-on: ubuntu-latest
    environment: production  # Requires approval
    steps:
      - name: Deploy to production
        run: ./infrastructure/deploy-all.sh --env=prod
```

---

## 📊 GitHub Actions Dashboard

After setup, you'll see:

```
GitHub Repository → Actions Tab

┌─────────────────────────────────────────────────────────┐
│  Workflows                                              │
├─────────────────────────────────────────────────────────┤
│  ✅ Deploy to Staging - 2m 34s ago                      │
│     Triggered by: push to staging                       │
│     Commit: abc1234 "Release candidate v1.1.0"          │
│                                                          │
│  ✅ Deploy to Development - 1h ago                      │
│     Triggered by: push to develop                       │
│     Commit: def5678 "Add monitoring feature"            │
│                                                          │
│  ❌ Deploy to Production - 2h ago (Failed)              │
│     Triggered by: tag v1.0.5                            │
│     Error: Tests failed                                 │
└─────────────────────────────────────────────────────────┘
```

---

## 🔍 Monitoring & Debugging

### **View Workflow Logs**

```bash
# In GitHub UI:
Repository → Actions → Click on workflow run → View logs

# Logs show:
Run Checkout code
✓ Checkout code (2s)

Run Authenticate to Google Cloud
✓ Authenticate to Google Cloud (5s)

Run Deploy to Staging Environment
✓ Build Docker images (1m 23s)
✓ Push to Artifact Registry (45s)
✓ Deploy to Cloud Run (32s)
✓ Run validation tests (18s)
```

### **Debugging Failed Workflows**

```yaml
- name: Debug information
  if: failure()
  run: |
    echo "Workflow failed!"
    echo "Branch: ${{ github.ref }}"
    echo "Commit: ${{ github.sha }}"
    echo "Project: ${{ env.PROJECT_ID }}"
    gcloud run services list
```

---

## 🎯 Best Practices

### **DO:**
- ✅ Run tests before deployment
- ✅ Use environment-specific secrets
- ✅ Add manual approval for production
- ✅ Send notifications on success/failure
- ✅ Use semantic versioning for tags
- ✅ Cache dependencies to speed up builds
- ✅ Run smoke tests after deployment

### **DON'T:**
- ❌ Don't hardcode secrets in workflow files
- ❌ Don't deploy to production without approval
- ❌ Don't skip tests in CI/CD
- ❌ Don't use same service account for all environments
- ❌ Don't ignore failed deployments

---

## 🚦 Environment Protection Rules

In GitHub repository settings:

```
Settings → Environments

┌─────────────────────────────────────────┐
│ Development                             │
│ ✓ No protection rules                   │
│ ✓ Auto-deploy on push                   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Staging                                 │
│ ☑ Required reviewers: @team-lead        │
│ ☑ Wait timer: 0 minutes                 │
│ ☑ Branch restrictions: staging only     │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Production                              │
│ ☑ Required reviewers: @devops-team      │
│ ☑ Wait timer: 5 minutes                 │
│ ☑ Branch restrictions: main only        │
│ ☑ Required tags: v*.*.*                 │
└─────────────────────────────────────────┘
```

---

## 📧 Notification Examples

### **Slack Notification**

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "🚀 Staging Deployment",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Staging Deployment Complete*\n\n*Project:* adk-rag-staging\n*Commit:* ${{ github.sha }}\n*Branch:* ${{ github.ref }}\n*Status:* ✅ Success"
            }
          }
        ]
      }
```

### **Email Notification**

```yaml
- name: Send email notification
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 465
    username: ${{ secrets.EMAIL_USERNAME }}
    password: ${{ secrets.EMAIL_PASSWORD }}
    subject: Staging Deployment Complete
    to: team@company.com
    from: GitHub Actions
    body: |
      Staging deployment completed successfully!
      
      Commit: ${{ github.sha }}
      Branch: ${{ github.ref }}
      Time: ${{ github.event.head_commit.timestamp }}
```

---

## 🔧 Advanced: Matrix Builds

Deploy to multiple regions:

```yaml
deploy:
  strategy:
    matrix:
      region: [us-east4, us-west1, europe-west1]
  runs-on: ubuntu-latest
  steps:
    - name: Deploy to ${{ matrix.region }}
      run: |
        ./infrastructure/deploy-all.sh --region=${{ matrix.region }}
```

---

## ✅ Summary

**Yes, automatic staging deployment is done with GitHub Actions:**

1. **Create** `.github/workflows/deploy.yml`
2. **Configure** trigger on `staging` branch push
3. **Add** GCP service account keys to GitHub Secrets
4. **Push** to staging branch → automatic deployment
5. **Optional**: Add manual approval gates

**The flow:**
```
git push origin staging
    ↓
GitHub Actions detects push
    ↓
Runs workflow (build, test, deploy)
    ↓
Deploys to adk-rag-staging (GCP)
    ↓
✅ Staging updated automatically
```

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Google Cloud GitHub Actions](https://github.com/google-github-actions)
- [Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [Environment Protection Rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)

---

**Next Steps:**
1. Create `.github/workflows/` directory
2. Add workflow files
3. Configure GitHub Secrets
4. Test with a push to staging
5. Monitor in GitHub Actions dashboard
