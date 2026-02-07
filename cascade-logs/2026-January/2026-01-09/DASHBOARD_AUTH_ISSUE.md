# Dashboard Authentication Issue

**Date:** January 9, 2026  
**Issue:** Admin dashboard shows "Error Loading Database - Failed to get user stats: Internal Server Error"

---

## Root Cause: Authentication Required

The admin dashboard is failing with a **403 Forbidden** error, not a 500 Internal Server Error.

### What's Happening:
1. Frontend makes request to `/api/admin/user-stats`
2. Backend returns **403 Forbidden** (not 500)
3. Frontend shows generic "Internal Server Error" message
4. This happens because **no authentication token** is being sent

### Diagnosis:
```bash
# Test without token
curl -X GET http://localhost:8000/api/admin/user-stats
# Returns: 403 Forbidden

# The admin endpoints require authentication via require_admin() dependency
# User must be logged in AND be a member of 'admin-users' group
```

---

## Solution: Login First

### Step 1: Login to the Frontend Application
You need to **login to the main application** before accessing the admin panel.

**Login Page:** `http://localhost:3000/landing` or `http://localhost:3000`

**Admin User Credentials:**
- Username: `alice`
- Password: (whatever alice's password is in your database)

### Step 2: After Login, Access Admin Panel
Once logged in successfully:
- Navigate to `http://localhost:3000/admin`
- Dashboard should load with stats

---

## How Authentication Works

1. **Login** → Frontend receives JWT token
2. **Token stored** in localStorage as 'auth_token'
3. **apiClient** reads token from localStorage
4. **All API requests** include `Authorization: Bearer <token>` header
5. **Backend validates** token and checks admin group membership

---

## Alternative: Add Authentication Check to Admin Layout

We could enhance the admin layout to check for authentication and redirect to login if needed.

**File:** `frontend/src/app/admin/layout.tsx`

```typescript
'use client';

import { useEffect, useState } from 'use';
import { useRouter } from 'next/navigation';
import { apiClient } from '@/lib/api';

export default function AdminLayout({ children }) {
  const router = useRouter();
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        // Check if user is authenticated
        await apiClient.verifyToken();
        setIsAuthenticated(true);
      } catch (error) {
        // Not authenticated, redirect to login
        router.push('/landing?redirect=/admin');
      } finally {
        setIsLoading(false);
      }
    };

    checkAuth();
  }, [router]);

  if (isLoading) {
    return <div>Loading...</div>;
  }

  if (!isAuthenticated) {
    return null; // Will redirect
  }

  return (
    // existing layout code
  );
}
```

---

## Immediate Action Required

**Please login to the frontend first:**
1. Go to `http://localhost:3000/landing`
2. Login with alice's credentials
3. Then navigate to `http://localhost:3000/admin`

The dashboard should then load successfully.

---

## Backend Logs Confirmation

The backend is working correctly and returning proper 403 errors for unauthenticated requests. The issue is purely on the frontend side - no authentication token present.
