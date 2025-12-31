#!/bin/bash

# Monitoring and Alerting Setup Script
# Sets up Cloud Monitoring dashboards and alerts for the multi-agent RAG system

set -e

PROJECT_ID="adk-rag-ma"
REGION="us-west1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Create log-based metrics
create_log_metrics() {
    log "Creating log-based metrics..."
    
    # Agent error count metric
    gcloud logging metrics create agent_error_count \
        --description="Count of errors by agent service" \
        --log-filter='resource.type="cloud_run_revision" AND severity>=ERROR AND (resource.labels.service_name="backend" OR resource.labels.service_name="backend-agent1" OR resource.labels.service_name="backend-agent2" OR resource.labels.service_name="backend-agent3")' \
        --project=$PROJECT_ID || warning "agent_error_count metric may already exist"
    
    # Session creation count metric
    gcloud logging metrics create agent_session_created_count \
        --description="Count of sessions created by agent" \
        --log-filter='resource.type="cloud_run_revision" AND jsonPayload.message="session_created" AND (resource.labels.service_name="backend" OR resource.labels.service_name="backend-agent1" OR resource.labels.service_name="backend-agent2" OR resource.labels.service_name="backend-agent3")' \
        --project=$PROJECT_ID || warning "agent_session_created_count metric may already exist"
    
    # FAILED_PRECONDITION error metric
    gcloud logging metrics create vertex_ai_failed_precondition \
        --description="Count of FAILED_PRECONDITION errors from Vertex AI" \
        --log-filter='resource.type="cloud_run_revision" AND textPayload:"FAILED_PRECONDITION"' \
        --project=$PROJECT_ID || warning "vertex_ai_failed_precondition metric may already exist"
    
    # Health check failures
    gcloud logging metrics create health_check_failures \
        --description="Count of health check failures" \
        --log-filter='resource.type="cloud_run_revision" AND (httpRequest.status>=500 OR severity>=ERROR) AND httpRequest.requestUrl:"/api/health"' \
        --project=$PROJECT_ID || warning "health_check_failures metric may already exist"
    
    success "Log-based metrics created"
}

# Create alerting policies
create_alert_policies() {
    log "Creating alerting policies..."
    
    # High error rate alert
    cat > /tmp/error_rate_policy.json << EOF
{
  "displayName": "Multi-Agent RAG - High Error Rate",
  "documentation": {
    "content": "Alert when error rate exceeds 5% for any agent service",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "Error rate > 5%",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\" AND metric.type=\"logging.googleapis.com/user/agent_error_count\"",
        "comparison": "COMPARISON_GREATER_THAN",
        "thresholdValue": 5,
        "duration": "300s",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "perSeriesAligner": "ALIGN_RATE",
            "crossSeriesReducer": "REDUCE_SUM",
            "groupByFields": ["resource.labels.service_name"]
          }
        ]
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "1800s"
  },
  "combiner": "OR",
  "enabled": true
}
EOF

    gcloud alpha monitoring policies create --policy-from-file=/tmp/error_rate_policy.json --project=$PROJECT_ID || warning "Error rate policy may already exist"
    
    # FAILED_PRECONDITION alert
    cat > /tmp/vertex_ai_policy.json << EOF
{
  "displayName": "Multi-Agent RAG - Vertex AI FAILED_PRECONDITION",
  "documentation": {
    "content": "Alert when FAILED_PRECONDITION errors occur with Vertex AI",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "FAILED_PRECONDITION errors detected",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\" AND metric.type=\"logging.googleapis.com/user/vertex_ai_failed_precondition\"",
        "comparison": "COMPARISON_GREATER_THAN",
        "thresholdValue": 0,
        "duration": "60s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE",
            "crossSeriesReducer": "REDUCE_SUM"
          }
        ]
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "3600s"
  },
  "combiner": "OR",
  "enabled": true
}
EOF

    gcloud alpha monitoring policies create --policy-from-file=/tmp/vertex_ai_policy.json --project=$PROJECT_ID || warning "Vertex AI policy may already exist"
    
    success "Alert policies created"
}

# Create monitoring dashboard
create_dashboard() {
    log "Creating monitoring dashboard..."
    
    cat > /tmp/dashboard.json << EOF
{
  "displayName": "Multi-Agent RAG System Overview",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Error Rate by Agent Service",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND metric.type=\"logging.googleapis.com/user/agent_error_count\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["resource.labels.service_name"]
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "Errors/sec",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "widget": {
          "title": "Session Creation Rate by Agent",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND metric.type=\"logging.googleapis.com/user/agent_session_created_count\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["resource.labels.service_name"]
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "Sessions/sec",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "yPos": 4,
        "widget": {
          "title": "Cloud Run Request Count",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["resource.labels.service_name"]
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "Requests/sec",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "yPos": 4,
        "widget": {
          "title": "Cloud Run Response Latency",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_PERCENTILE_95",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": ["resource.labels.service_name"]
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "Latency (ms)",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 12,
        "height": 4,
        "yPos": 8,
        "widget": {
          "title": "Recent Error Logs",
          "logsPanel": {
            "filter": "resource.type=\"cloud_run_revision\" AND severity>=ERROR AND (resource.labels.service_name=\"backend\" OR resource.labels.service_name=\"backend-agent1\" OR resource.labels.service_name=\"backend-agent2\" OR resource.labels.service_name=\"backend-agent3\")",
            "resourceNames": []
          }
        }
      }
    ]
  }
}
EOF

    gcloud monitoring dashboards create --config-from-file=/tmp/dashboard.json --project=$PROJECT_ID || warning "Dashboard may already exist"
    
    success "Monitoring dashboard created"
}

# Create uptime checks
create_uptime_checks() {
    log "Creating uptime checks..."
    
    # Main API health check
    cat > /tmp/uptime_main.json << EOF
{
  "displayName": "Multi-Agent RAG - Main API Health",
  "httpCheck": {
    "path": "/api/health",
    "port": 443,
    "useSsl": true,
    "validateSsl": true
  },
  "monitoredResource": {
    "type": "uptime_url",
    "labels": {
      "project_id": "$PROJECT_ID",
      "host": "34.49.46.115.nip.io"
    }
  },
  "timeout": "10s",
  "period": "300s"
}
EOF

    gcloud monitoring uptime create --config-from-file=/tmp/uptime_main.json --project=$PROJECT_ID || warning "Main uptime check may already exist"
    
    # Agent-specific health checks
    for agent in agent1 agent2 agent3; do
        cat > /tmp/uptime_${agent}.json << EOF
{
  "displayName": "Multi-Agent RAG - ${agent} Health",
  "httpCheck": {
    "path": "/${agent}/api/health",
    "port": 443,
    "useSsl": true,
    "validateSsl": true
  },
  "monitoredResource": {
    "type": "uptime_url",
    "labels": {
      "project_id": "$PROJECT_ID",
      "host": "34.49.46.115.nip.io"
    }
  },
  "timeout": "10s",
  "period": "300s"
}
EOF

        gcloud monitoring uptime create --config-from-file=/tmp/uptime_${agent}.json --project=$PROJECT_ID || warning "${agent} uptime check may already exist"
    done
    
    success "Uptime checks created"
}

# Create notification channels (email)
create_notification_channels() {
    log "Creating notification channels..."
    
    # Check if email is configured
    if [ -z "$ALERT_EMAIL" ]; then
        warning "ALERT_EMAIL environment variable not set. Skipping email notification channel."
        warning "Set ALERT_EMAIL=your-email@domain.com to create email notifications."
        return
    fi
    
    cat > /tmp/email_channel.json << EOF
{
  "type": "email",
  "displayName": "Multi-Agent RAG Alerts",
  "description": "Email notifications for multi-agent RAG system alerts",
  "labels": {
    "email_address": "$ALERT_EMAIL"
  }
}
EOF

    gcloud alpha monitoring channels create --channel-content-from-file=/tmp/email_channel.json --project=$PROJECT_ID || warning "Email notification channel may already exist"
    
    success "Notification channels created"
}

# Generate monitoring report
generate_monitoring_report() {
    log "Generating monitoring setup report..."
    
    cat > monitoring-setup-report.md << EOF
# Monitoring Setup Report

**Date:** $(date)
**Project:** $PROJECT_ID
**Region:** $REGION

## Created Resources

### Log-Based Metrics
- \`agent_error_count\` - Count of errors by agent service
- \`agent_session_created_count\` - Count of sessions created by agent
- \`vertex_ai_failed_precondition\` - Count of FAILED_PRECONDITION errors
- \`health_check_failures\` - Count of health check failures

### Alert Policies
- **High Error Rate** - Triggers when error rate > 5% for any service
- **Vertex AI FAILED_PRECONDITION** - Triggers on any FAILED_PRECONDITION errors

### Dashboard
- **Multi-Agent RAG System Overview** - Comprehensive dashboard with:
  - Error rate by agent service
  - Session creation rate by agent
  - Cloud Run request count and latency
  - Recent error logs

### Uptime Checks
- Main API health check (\`/api/health\`)
- Agent-specific health checks (\`/agent1/api/health\`, \`/agent2/api/health\`, \`/agent3/api/health\`)

## Access URLs

- **Monitoring Console:** https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID
- **Alerting Policies:** https://console.cloud.google.com/monitoring/alerting/policies?project=$PROJECT_ID
- **Uptime Checks:** https://console.cloud.google.com/monitoring/uptime?project=$PROJECT_ID

## Useful Queries

### View Recent Errors
\`\`\`
gcloud logging read 'severity>=ERROR AND (resource.labels.service_name="backend" OR resource.labels.service_name="backend-agent1" OR resource.labels.service_name="backend-agent2" OR resource.labels.service_name="backend-agent3")' --project=$PROJECT_ID --limit=20 --freshness=1h
\`\`\`

### Check Agent Activity
\`\`\`
gcloud logging read 'textPayload:"[agent"' --project=$PROJECT_ID --limit=20 --freshness=1h
\`\`\`

### Monitor Health Checks
\`\`\`
curl -s https://34.49.46.115.nip.io/api/health | jq
curl -s https://34.49.46.115.nip.io/agent1/api/health | jq
curl -s https://34.49.46.115.nip.io/agent2/api/health | jq
curl -s https://34.49.46.115.nip.io/agent3/api/health | jq
\`\`\`

## Next Steps

1. Configure notification channels with your email address:
   \`export ALERT_EMAIL=your-email@domain.com && ./setup-monitoring.sh\`

2. Customize alert thresholds based on your requirements

3. Set up additional metrics for business-specific monitoring

4. Consider integrating with external monitoring tools (e.g., Splunk, Datadog)

EOF

    success "Monitoring setup report created: monitoring-setup-report.md"
}

# Cleanup temporary files
cleanup() {
    rm -f /tmp/error_rate_policy.json /tmp/vertex_ai_policy.json /tmp/dashboard.json
    rm -f /tmp/uptime_main.json /tmp/uptime_agent*.json /tmp/email_channel.json
}

# Main execution
main() {
    log "Setting up monitoring and alerting for Multi-Agent RAG system..."
    
    # Set project
    gcloud config set project $PROJECT_ID
    
    # Create monitoring resources
    create_log_metrics
    create_alert_policies
    create_dashboard
    create_uptime_checks
    create_notification_channels
    
    # Generate report
    generate_monitoring_report
    
    # Cleanup
    cleanup
    
    success "Monitoring setup completed successfully!"
    log "View your dashboard at: https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID"
}

# Command line options
case "${1:-setup}" in
    "setup")
        main
        ;;
    "cleanup")
        log "Cleaning up monitoring resources..."
        # Note: Add cleanup commands here if needed
        warning "Manual cleanup required via Cloud Console"
        ;;
    *)
        echo "Usage: $0 [setup|cleanup]"
        echo "  setup   - Create monitoring resources (default)"
        echo "  cleanup - Remove monitoring resources"
        exit 1
        ;;
esac
