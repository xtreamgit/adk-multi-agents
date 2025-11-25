# Why the Load Balancer Backend Uses HTTP (Not HTTPS)

This document explains why, in the current architecture, the Google Cloud external HTTPS load balancer terminates TLS and forwards traffic to Cloud Run over HTTP.

## Summary
- **TLS termination happens at the Load Balancer** (target HTTPS proxy with SSL certificate).
- **Backend protocol should be HTTP** when using a serverless NEG to Cloud Run.
- Forcing **HTTPS on the backend service/NEG** often causes health check failures ("no healthy upstreams") and breaks IAP/OAuth redirects.

## Correct Architecture
- **TLS termination at LB**: Users connect over HTTPS to the external load balancer, which holds the SSL certificate.
- **HTTP to Cloud Run**: The LB forwards requests via HTTP to the serverless NEG that targets the Cloud Run service.
- **Cloud Run ingress**: Use `internal-and-cloud-load-balancing` and allow unauthenticated; IAP enforces authentication at the LB layer.
- **IAP on LB backend service**: Enable IAP and attach the proper OAuth client; requests are authenticated before reaching Cloud Run.

## Why HTTPS Backend Causes Problems
- **Health checks fail**: The load balancer’s health checks expect HTTP on the backend; switching to HTTPS leads to "no healthy upstreams".
- **IAP/OAuth issues**: Double TLS or protocol mismatches can cause redirect errors and failed handshakes through IAP.
- **Not needed**: The internal hop is within Google’s network. End-users still have end-to-end HTTPS to the LB.

## Security Considerations
- End-user connections are fully **HTTPS** to the load balancer.
- The LB-to-Cloud Run hop is internal to Google’s network and is the **recommended configuration** for this serverless NEG pattern.
- If you have a **hard requirement** for TLS all the way to the backend, a **different architecture** is needed (e.g., a TLS-terminating proxy or a custom backend with managed certs). That is outside the standard serverless NEG + IAP pattern and may introduce added complexity.

## References
- Cloud Run with External HTTPS Load Balancer (Serverless NEG) best practices
- IAP configuration on load balancer backend service with OAuth client
