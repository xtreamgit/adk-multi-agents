#!/bin/bash
#
# loadbalancer.sh - Setup External HTTPS Load Balancer with SSL
#

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

setup_load_balancer() {
    if [[ "$SKIP_LOAD_BALANCER" == "true" ]]; then
        log_section "SECTION 5: Load Balancer Setup"
        log_warning "Skipping Load Balancer setup (--skip-load-balancer flag)"
        
        # Get existing static IP
        if gcloud compute addresses describe rag-agent-ip --global >/dev/null 2>&1; then
            STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --format="value(address)")
            export LOAD_BALANCER_URL="https://$STATIC_IP.nip.io"
            log_info "Using existing Load Balancer: $LOAD_BALANCER_URL"
        else
            log_error "Load Balancer static IP not found. Cannot skip setup."
            return 1
        fi
        return 0
    fi
    
    log_section "SECTION 5: Load Balancer Setup"
    
    create_static_ip
    create_ssl_certificate
    create_network_endpoint_groups
    create_backend_services
    create_url_map
    create_https_proxy
    create_forwarding_rule
    
    return 0
}

create_static_ip() {
    log_info "Creating static IP address..."
    if gcloud compute addresses describe rag-agent-ip --global >/dev/null 2>&1; then
        log_warning "Static IP already exists"
        STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --format="value(address)")
    else
        gcloud compute addresses create rag-agent-ip --global --quiet
        STATIC_IP=$(gcloud compute addresses describe rag-agent-ip --global --format="value(address)")
        log_success "Static IP created: $STATIC_IP"
    fi
    
    export LOAD_BALANCER_URL="https://$STATIC_IP.nip.io"
    log_info "Load Balancer URL: $LOAD_BALANCER_URL"
}

create_ssl_certificate() {
    log_info "Creating SSL certificate..."
    if gcloud compute ssl-certificates describe rag-agent-ssl-cert --global >/dev/null 2>&1; then
        log_warning "SSL certificate already exists"
    else
        gcloud compute ssl-certificates create rag-agent-ssl-cert \
            --domains="$STATIC_IP.nip.io" \
            --global \
            --quiet
        log_success "SSL certificate created (provisioning in progress)"
    fi
    
    SSL_STATUS=$(gcloud compute ssl-certificates describe rag-agent-ssl-cert --global --format="value(managed.status)")
    log_info "SSL Certificate Status: $SSL_STATUS"
    if [[ "$SSL_STATUS" != "ACTIVE" ]]; then
        log_warning "SSL certificate provisioning takes 10-15 minutes"
    fi
}

create_network_endpoint_groups() {
    log_info "Creating Network Endpoint Groups..."
    
    # Frontend NEG
    if gcloud compute network-endpoint-groups describe frontend-neg --region="$REGION" >/dev/null 2>&1; then
        echo "  ✓ Frontend NEG exists"
    else
        gcloud compute network-endpoint-groups create frontend-neg \
            --region="$REGION" \
            --network-endpoint-type=serverless \
            --cloud-run-service=frontend \
            --quiet
        echo "  ✓ Frontend NEG created"
    fi
    
    # Backend NEG (default agent)
    if gcloud compute network-endpoint-groups describe backend-neg --region="$REGION" >/dev/null 2>&1; then
        echo "  ✓ Backend NEG exists"
    else
        gcloud compute network-endpoint-groups create backend-neg \
            --region="$REGION" \
            --network-endpoint-type=serverless \
            --cloud-run-service=backend \
            --quiet
        echo "  ✓ Backend NEG created"
    fi

    # Backend NEGs for additional agents
    if gcloud compute network-endpoint-groups describe backend-agent1-neg --region="$REGION" >/dev/null 2>&1; then
        echo "  ✓ Backend Agent1 NEG exists"
    else
        gcloud compute network-endpoint-groups create backend-agent1-neg \
            --region="$REGION" \
            --network-endpoint-type=serverless \
            --cloud-run-service=backend-agent1 \
            --quiet
        echo "  ✓ Backend Agent1 NEG created"
    fi

    if gcloud compute network-endpoint-groups describe backend-agent2-neg --region="$REGION" >/dev/null 2>&1; then
        echo "  ✓ Backend Agent2 NEG exists"
    else
        gcloud compute network-endpoint-groups create backend-agent2-neg \
            --region="$REGION" \
            --network-endpoint-type=serverless \
            --cloud-run-service=backend-agent2 \
            --quiet
        echo "  ✓ Backend Agent2 NEG created"
    fi

    if gcloud compute network-endpoint-groups describe backend-agent3-neg --region="$REGION" >/dev/null 2>&1; then
        echo "  ✓ Backend Agent3 NEG exists"
    else
        gcloud compute network-endpoint-groups create backend-agent3-neg \
            --region="$REGION" \
            --network-endpoint-type=serverless \
            --cloud-run-service=backend-agent3 \
            --quiet
        echo "  ✓ Backend Agent3 NEG created"
    fi
    
    log_success "Network Endpoint Groups configured"
}

create_backend_services() {
    log_info "Creating backend services..."
    
    # Frontend backend service
    if gcloud compute backend-services describe frontend-backend-service --global >/dev/null 2>&1; then
        echo "  ✓ Frontend backend service exists"
    else
        gcloud compute backend-services create frontend-backend-service \
            --global \
            --load-balancing-scheme=EXTERNAL_MANAGED \
            --protocol=HTTP \
            --port-name=http \
            --quiet
        echo "  ✓ Frontend backend service created"
    fi
    
    # Ensure backend is attached (idempotent - will skip if already attached)
    gcloud compute backend-services add-backend frontend-backend-service \
        --global \
        --network-endpoint-group=frontend-neg \
        --network-endpoint-group-region="$REGION" \
        --quiet 2>/dev/null || echo "  ✓ Frontend backend already attached"
    
    # Backend backend service (default agent)
    if gcloud compute backend-services describe backend-backend-service --global >/dev/null 2>&1; then
        echo "  ✓ Backend backend service exists"
    else
        gcloud compute backend-services create backend-backend-service \
            --global \
            --load-balancing-scheme=EXTERNAL_MANAGED \
            --protocol=HTTP \
            --port-name=http \
            --quiet
        echo "  ✓ Backend backend service created"
    fi
    
    # Ensure backend is attached (idempotent - will skip if already attached)
    gcloud compute backend-services add-backend backend-backend-service \
        --global \
        --network-endpoint-group=backend-neg \
        --network-endpoint-group-region="$REGION" \
        --quiet 2>/dev/null || echo "  ✓ Backend backend already attached"

    # Backend services for additional agents
    for agent in agent1 agent2 agent3; do
        local svc_name="backend-${agent}-backend-service"
        local neg_name="backend-${agent}-neg"

        if gcloud compute backend-services describe "$svc_name" --global >/dev/null 2>&1; then
            echo "  ✓ $svc_name exists"
        else
            gcloud compute backend-services create "$svc_name" \
                --global \
                --load-balancing-scheme=EXTERNAL_MANAGED \
                --protocol=HTTP \
                --port-name=http \
                --quiet
            echo "  ✓ $svc_name created"
        fi

        gcloud compute backend-services add-backend "$svc_name" \
            --global \
            --network-endpoint-group="$neg_name" \
            --network-endpoint-group-region="$REGION" \
            --quiet 2>/dev/null || echo "  ✓ $svc_name already attached"
    done
    
    log_success "Backend services configured"
}

create_url_map() {
    log_info "Creating URL map for routing..."
    if gcloud compute url-maps describe rag-agent-url-map --global >/dev/null 2>&1; then
        log_warning "URL map already exists"
    else
        gcloud compute url-maps create rag-agent-url-map \
            --default-service=frontend-backend-service \
            --global \
            --quiet
        log_success "URL map created"
    fi
    
    log_info "Configuring path-based routing (/api/* and /agentX/api/* → backends)..."
    gcloud compute url-maps add-path-matcher rag-agent-url-map \
        --path-matcher-name=api-matcher \
        --default-service=frontend-backend-service \
        --path-rules="/api/*=backend-backend-service,/agent1/api/*=backend-agent1-backend-service,/agent2/api/*=backend-agent2-backend-service,/agent3/api/*=backend-agent3-backend-service" \
        --global \
        --quiet 2>/dev/null || log_warning "Path matcher may already exist"
    
    log_success "URL map configured (/ → frontend, /api/* → backend, /agentX/api/* → backend-agentX)"
}

create_https_proxy() {
    log_info "Creating HTTPS proxy..."
    if gcloud compute target-https-proxies describe rag-agent-https-proxy --global >/dev/null 2>&1; then
        log_warning "HTTPS proxy already exists"
    else
        gcloud compute target-https-proxies create rag-agent-https-proxy \
            --ssl-certificates=rag-agent-ssl-cert \
            --url-map=rag-agent-url-map \
            --global \
            --quiet
        log_success "HTTPS proxy created"
    fi
}

create_forwarding_rule() {
    log_info "Creating forwarding rule..."
    if gcloud compute forwarding-rules describe rag-agent-forwarding-rule --global >/dev/null 2>&1; then
        log_warning "Forwarding rule already exists"
    else
        gcloud compute forwarding-rules create rag-agent-forwarding-rule \
            --address=rag-agent-ip \
            --target-https-proxy=rag-agent-https-proxy \
            --global \
            --ports=443 \
            --quiet
        log_success "Forwarding rule created"
    fi
    
    log_success "Load Balancer infrastructure complete"
}
