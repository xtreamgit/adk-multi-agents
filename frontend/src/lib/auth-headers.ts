/**
 * Shared auth headers utility for admin pages and direct fetch calls.
 * Supports both Bearer token (local login) and IAP (load balancer) authentication.
 * 
 * When behind IAP, the load balancer injects X-Goog-IAP-JWT-Assertion automatically.
 * No Bearer token is needed — just include credentials: 'include' on fetch calls.
 */

/**
 * Get authorization headers for API requests.
 * Returns Bearer token header if available, otherwise empty headers
 * (IAP authentication is handled by the load balancer automatically).
 */
export function getAuthHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('auth_token');
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
  }

  return headers;
}

/**
 * Get authorization headers without Content-Type (for non-JSON requests).
 */
export function getAuthHeadersOnly(): Record<string, string> {
  const headers: Record<string, string> = {};

  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('auth_token');
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
  }

  return headers;
}
