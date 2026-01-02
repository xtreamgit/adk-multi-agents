# Frontend Integration Guide

**Date:** December 31, 2025  
**Status:** ✅ New Components Created - Ready for Integration

---

## 🎯 What Was Created

### New Files

1. **`frontend/src/lib/api-enhanced.ts`** - Enhanced API client
   - Complete TypeScript types for all API responses
   - Methods for authentication, users, agents, groups, corpora
   - Session management and token handling
   - localStorage persistence

2. **`frontend/src/components/AgentSwitcher.tsx`** - Agent selection component
   - Displays all accessible agents for the user
   - Allows switching between agents in a session
   - Set default agent
   - Visual indication of current/default agent

3. **`frontend/src/components/UserProfilePanel.tsx`** - User profile management
   - View user information (name, email, username)
   - Display groups and roles
   - Edit preferences (theme, language, timezone)
   - Admin badge for system admins

---

## 🔧 Integration Steps

### Step 1: Update Existing Components to Use Enhanced API

#### Option A: Replace the old API client

```bash
cd frontend/src/lib
mv api.ts api-old.ts
mv api-enhanced.ts api.ts
```

#### Option B: Gradually migrate (recommended)

Keep both files and update imports one component at a time:

```typescript
// In LoginForm.tsx, ChatInterface.tsx, etc.
// Change from:
import { apiClient } from '../lib/api';

// To:
import { apiClient } from '../lib/api-enhanced';
```

---

### Step 2: Add New Components to Your Layout

Create a dashboard or settings page that uses the new components:

**`frontend/src/app/dashboard/page.tsx`** (new file):

```typescript
"use client";

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiClient } from '../../lib/api-enhanced';
import AgentSwitcher from '../../components/AgentSwitcher';
import UserProfilePanel from '../../components/UserProfilePanel';

export default function DashboardPage() {
  const router = useRouter();
  const [sessionId, setSessionId] = useState<string | null>(null);

  useEffect(() => {
    if (!apiClient.isAuthenticated()) {
      router.push('/');
      return;
    }

    // Get or create session
    const existingSessionId = apiClient.getSessionId();
    if (existingSessionId) {
      setSessionId(existingSessionId);
    }
  }, [router]);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* User Profile - Left Column */}
          <div className="lg:col-span-1">
            <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
              <UserProfilePanel onProfileUpdate={() => {
                // Optionally reload some data
              }} />
            </div>
          </div>

          {/* Agent Switcher - Right Column */}
          <div className="lg:col-span-2">
            <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
              <AgentSwitcher
                sessionId={sessionId}
                onAgentChange={(agent) => {
                  console.log('Switched to agent:', agent.display_name);
                }}
              />
            </div>

            {/* Add corpus selector here if needed */}
          </div>
        </div>
      </div>
    </div>
  );
}
```

---

### Step 3: Add Navigation to Dashboard

Update your main page to include a link to the dashboard:

```typescript
// In your main chat interface or navigation
<button
  onClick={() => router.push('/dashboard')}
  className="px-4 py-2 bg-gray-200 dark:bg-gray-700 rounded-lg hover:bg-gray-300 dark:hover:bg-gray-600"
>
  Settings
</button>
```

---

### Step 4: Update Environment Variables

Make sure your `.env.local` file has the correct backend URL:

```bash
# frontend/.env.local
NEXT_PUBLIC_BACKEND_URL=http://localhost:8000
```

For production:
```bash
NEXT_PUBLIC_BACKEND_URL=https://your-backend-url.com
```

---

## 🧪 Testing the Frontend

### 1. Start the Backend Server

```bash
cd backend
source .venv/bin/activate
python src/api/server.py
```

Backend should be running on http://localhost:8000

### 2. Start the Frontend

```bash
cd frontend
npm install  # if you haven't already
npm run dev
```

Frontend should be running on http://localhost:3000

### 3. Test User Flow

1. **Register/Login**
   - Navigate to http://localhost:3000
   - Create an account or login with: `admin` / `password`

2. **Navigate to Dashboard**
   - Once logged in, go to http://localhost:3000/dashboard
   - You should see:
     - Your profile on the left
     - Agent switcher on the right

3. **Test Agent Switching**
   - Click on different agents
   - Set one as default
   - Verify the UI updates

4. **Test Profile Editing**
   - Click "Edit" in the profile panel
   - Change theme/language/timezone
   - Click "Save Changes"
   - Verify the changes persist on reload

---

## 📦 Component API Reference

### AgentSwitcher

**Props:**
- `sessionId` (string | null) - Current session ID (required for switching)
- `onAgentChange` ((agent: Agent) => void) - Callback when agent is switched

**Features:**
- Displays all accessible agents
- Visual indication of selected agent
- "Set as default" functionality
- Handles "no access" gracefully

**Usage:**
```typescript
<AgentSwitcher
  sessionId={sessionId}
  onAgentChange={(agent) => {
    console.log('Now using:', agent.display_name);
  }}
/>
```

---

### UserProfilePanel

**Props:**
- `onProfileUpdate` (() => void) - Callback after successful profile update

**Features:**
- Displays user info (name, email, username)
- Shows groups and roles
- Edit preferences (theme, language, timezone)
- Admin badge for system admins

**Usage:**
```typescript
<UserProfilePanel
  onProfileUpdate={() => {
    // Refresh related data
  }}
/>
```

---

## 🎨 Customization

### Styling

All components use Tailwind CSS and support dark mode. Customize by:

1. **Colors** - Update the color classes in component files
2. **Layout** - Adjust grid/flex layouts
3. **Spacing** - Modify padding/margin classes

Example:
```typescript
// Change agent card border color
className="border-blue-500"  // Change to border-purple-500
```

### API Endpoints

The enhanced API client uses these base endpoints:

```typescript
// Authentication
/api/auth/register
/api/auth/login
/api/auth/me
/api/auth/refresh

// Users
/api/users/me
/api/users/me/preferences
/api/users/me/roles
/api/users/me/default-agent/{id}

// Agents
/api/agents/
/api/agents/me
/api/agents/session/{session_id}/switch/{agent_id}

// Groups
/api/groups/me

// Corpora
/api/corpora/
/api/corpora/session/{session_id}/select
```

---

## 🐛 Troubleshooting

### Issue: "Failed to load agents"

**Cause:** User hasn't been granted access to any agents

**Solution:**
```bash
# As admin, grant access
curl -X PUT http://localhost:8000/api/agents/1/grant/{user_id} \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### Issue: "Not authenticated" error

**Cause:** Token expired or invalid

**Solution:**
- Clear localStorage and re-login
- Or implement token refresh in your app

```typescript
// Add to your app
useEffect(() => {
  const refreshToken = async () => {
    try {
      await apiClient.refreshToken();
    } catch {
      apiClient.logout();
      router.push('/');
    }
  };
  
  // Refresh every 25 days (before 30-day expiry)
  const interval = setInterval(refreshToken, 25 * 24 * 60 * 60 * 1000);
  return () => clearInterval(interval);
}, []);
```

### Issue: CORS errors

**Cause:** Backend CORS not configured for your frontend URL

**Solution:**
Update backend CORS configuration in `server.py`:
```python
allowed_origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "https://your-production-domain.com"  # Add your domain
]
```

---

## 📝 Next Steps

### Essential
1. ✅ Test login and registration
2. ✅ Test agent switching
3. ✅ Test profile updates
4. ⬜ Add error boundaries
5. ⬜ Add loading states
6. ⬜ Add success notifications

### Optional Enhancements
- [ ] Create CorpusSelector component (similar to AgentSwitcher)
- [ ] Add user avatar upload
- [ ] Add activity history
- [ ] Add admin panel for user management
- [ ] Add real-time notifications
- [ ] Add keyboard shortcuts

### Production Ready
- [ ] Add automated tests (Jest, React Testing Library)
- [ ] Set up error tracking (Sentry)
- [ ] Optimize bundle size
- [ ] Add analytics
- [ ] Deploy to production

---

## 📚 Additional Resources

- **Backend API Docs:** http://localhost:8000/docs
- **Architecture:** `FEATURE-ARCHITECTURE.md`
- **Backend Integration:** `INTEGRATION-SUCCESS.md`
- **Quick Start:** `QUICK-START.md`

---

**Status:** ✅ Components ready for integration  
**Next:** Run `npm run dev` and test the new features!
