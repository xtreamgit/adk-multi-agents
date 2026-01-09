Enabling IAP with OAuth client...
Using OAuth Client ID: 965537996595-oo6omqp06vlimbfbhluvnahkfda8b0d9.apps.googleusercontent.com
  Enabling IAP on frontend backend service...
WARNING: IAP only protects requests that go through the Cloud Load Balancer. See the IAP documentation for important security best practices: https://cloud.google.com/iap/
WARNING: IAP has been enabled for a backend service that does not use HTTPS. Data sent from the Load Balancer to your VM will not be encrypted.
Updated [https://www.googleapis.com/compute/v1/projects/adk-rag-hdtest6/global/backendServices/frontend-backend-service].
  Enabling IAP on backend backend service...
WARNING: IAP only protects requests that go through the Cloud Load Balancer. See the IAP documentation for important security best practices: https://cloud.google.com/iap/
WARNING: IAP has been enabled for a backend service that does not use HTTPS. Data sent from the Load Balancer to your VM will not be encrypted.
Updated [https://www.googleapis.com/compute/v1/projects/adk-rag-hdtest6/global/backendServices/backend-backend-service].



5. Checking Cloud Run Authentication Configuration
❌ Backend allows unauthenticated access (security risk)
✅ Frontend requires authentication (no allUsers access)

📋 6. Checking Cloud Run Access Permissions
✅ hector@develom.com has backend access
✅ hector@develom.com has frontend access

📋 7. Testing HTTP Security
  Testing Frontend authentication requirement... ✅ (HTTP 403 - authentication required)
  Testing Backend API authentication requirement... ❌ (HTTP 405 - may allow unauthenticated access)



Please inspect, very carefully, the deploy-secure-v0.2.sh and deploy-complete-oauth-v0.2.sh to identify duplicated functions and logic. The purpose of this is to consolidate these two scripts into one to make the deployment easier and faster. Ensure the code is divided in sections or modules so that they are easy to edit later on. 