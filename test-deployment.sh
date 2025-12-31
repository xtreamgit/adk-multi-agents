#!/bin/bash
# Deployment Verification Script
# Tests the multi-agent application and checks for errors

set -e

PROJECT_ID="adk-rag-ma"
REGION="us-west1"
LB_URL="https://34.49.46.115.nip.io"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Multi-Agent RAG Application - Deployment Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Check Cloud Run Services
echo "📦 Checking Cloud Run Services..."
gcloud run services list \
  --project=$PROJECT_ID \
  --region=$REGION \
  --format='table(SERVICE,URL,LAST_DEPLOYED_BY,LAST_DEPLOYED)'
echo ""

# 2. Check Load Balancer
echo "🌐 Checking Load Balancer..."
echo "   URL: $LB_URL"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $LB_URL || echo "000")
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
  echo "   ✅ Load Balancer responding (HTTP $HTTP_CODE)"
else
  echo "   ⚠️  Load Balancer status: HTTP $HTTP_CODE"
fi
echo ""

# 3. Check for Recent Errors
echo "🔍 Checking for errors in last 30 minutes..."
ERROR_COUNT=$(gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --project=$PROJECT_ID \
  --limit=100 \
  --freshness=30m \
  --format='value(timestamp)' | wc -l | tr -d ' ')

if [ "$ERROR_COUNT" = "0" ]; then
  echo "   ✅ No errors found"
else
  echo "   ⚠️  Found $ERROR_COUNT error(s). Showing recent errors:"
  gcloud logging read \
    'resource.type="cloud_run_revision" AND severity>=ERROR' \
    --project=$PROJECT_ID \
    --limit=5 \
    --freshness=30m \
    --format='table(timestamp,resource.labels.service_name,textPayload.slice(0:80))'
fi
echo ""

# 4. Check Backend Environment Variables
echo "🔧 Checking Backend Configuration..."
for service in backend backend-agent1 backend-agent2 backend-agent3; do
  echo "   Service: $service"
  ACCOUNT_ENV=$(gcloud run services describe $service \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format='value(spec.template.spec.containers[0].env[?(@.name=="ACCOUNT_ENV")].value)' 2>/dev/null || echo "not set")
  LOCATION=$(gcloud run services describe $service \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format='value(spec.template.spec.containers[0].env[?(@.name=="VERTEXAI_LOCATION")].value)' 2>/dev/null || echo "not set")
  echo "      ACCOUNT_ENV: $ACCOUNT_ENV"
  echo "      VERTEXAI_LOCATION: $LOCATION"
done
echo ""

# 5. Test if we can query logs (check if services have started)
echo "📊 Checking if services have received requests..."
LOG_COUNT=$(gcloud logging read \
  'resource.type="cloud_run_revision"' \
  --project=$PROJECT_ID \
  --limit=10 \
  --freshness=30m \
  --format='value(timestamp)' | wc -l | tr -d ' ')

if [ "$LOG_COUNT" = "0" ]; then
  echo "   ℹ️  No logs yet - services are cold (haven't received requests)"
  echo "   💡 Try accessing the app at: $LB_URL"
else
  echo "   ✅ Found $LOG_COUNT log entries - services are active"
  
  # Check for agent logging
  echo ""
  echo "🏷️  Checking for agent context logging..."
  AGENT_LOG_COUNT=$(gcloud logging read \
    'resource.type="cloud_run_revision" AND textPayload:"[agent"' \
    --project=$PROJECT_ID \
    --limit=10 \
    --freshness=30m \
    --format='value(timestamp)' | wc -l | tr -d ' ')
  
  if [ "$AGENT_LOG_COUNT" = "0" ]; then
    echo "   ℹ️  No agent logs yet - perform some queries to test"
  else
    echo "   ✅ Found agent-tagged logs! Showing samples:"
    gcloud logging read \
      'resource.type="cloud_run_revision" AND textPayload:"[agent"' \
      --project=$PROJECT_ID \
      --limit=3 \
      --freshness=30m \
      --format='table(timestamp,resource.labels.service_name,textPayload.slice(0:100))'
  fi
fi
echo ""

# 6. Check Vertex AI Corpus
echo "🗃️  Checking Vertex AI Corpus..."
CORPUS_COUNT=$(gcloud ai index-endpoints list \
  --location=$REGION \
  --project=$PROJECT_ID \
  --format='value(name)' 2>/dev/null | wc -l | tr -d ' ' || echo "0")
echo "   Note: Corpus check requires Vertex AI API (may show 0 if not accessible via CLI)"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DEPLOYMENT CHECK COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next Steps:"
echo "   1. Open app: $LB_URL"
echo "   2. Login with IAP"
echo "   3. Select different agents and try queries"
echo "   4. Check logs for agent context: [agent1], [agent2], [agent3]"
echo ""
echo "📝 To view agent-specific logs:"
echo "   gcloud logging read 'textPayload:\"[agent1]\"' --project=$PROJECT_ID --limit=10"
echo ""
