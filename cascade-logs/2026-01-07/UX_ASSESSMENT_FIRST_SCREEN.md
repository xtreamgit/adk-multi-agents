# UX Assessment: First Screen Strategy

**Date:** January 7, 2026  
**Topic:** Determining optimal first screen for ADK Multi-Agent RAG Application  
**Current State:** Auto guest login → Direct to chat interface

---

## Current Implementation Analysis

### What Happens Now
1. User opens app at `http://localhost:3000`
2. App checks authentication state
3. If no token → **Auto-creates guest user**
4. **Immediately shows chat interface** with:
   - Guest User (id: 0)
   - Default corpus: `ai-books`
   - Full chat functionality
5. Sign in option available but not prominent

### Problems with Current Approach
- **No onboarding**: Users land directly in chat with no context
- **Hidden value**: Features and capabilities not immediately clear
- **Unclear purpose**: What corpora are available? What can I ask?
- **Guest limitations unclear**: Users don't know what they're missing
- **No call-to-action**: No incentive to sign in vs staying as guest
- **Security ambiguity**: Is this a public demo or secure enterprise tool?

---

## Industry Best Practices Analysis

### 1. **Enterprise AI/RAG Tools** (ChatGPT Enterprise, Claude.ai, Perplexity Pro)

**Pattern:** **Authentication-First Approach**
- Landing page with clear value proposition
- Sign in required (no guest access)
- Onboarding after authentication
- Clear workspace/organization context

**Why:**
- Enterprise tools require user tracking for usage, billing, audit
- Need to enforce access control and data privacy
- User personalization (history, preferences, settings)

**Examples:**
- ChatGPT: Forces login, shows organization context
- Claude: Requires account, offers workspace selection
- Perplexity Pro: Requires sign-in for advanced features

---

### 2. **Demo/Public AI Tools** (HuggingFace Spaces, OpenAI Playground demos)

**Pattern:** **Instant Access with Optional Sign-In**
- No login required to start
- Limited functionality for anonymous users
- Clear upgrade/sign-in prompts
- Session persistence via browser storage

**Why:**
- Lower barrier to entry for evaluation
- Showcase capabilities immediately
- Convert users after they see value

**Examples:**
- HuggingFace Spaces: Instant access, sign-in for compute
- Gemini Playground: Immediate usage, sign-in for history
- Runway ML: Demo models without account, sign-in for features

---

### 3. **Hybrid Model** (Notion, Figma, Slack)

**Pattern:** **Landing Page → Choice → Experience**
- Marketing/feature landing page
- Clear "Try Demo" vs "Sign In" options
- Guest demo with limitations
- Progressive disclosure of premium features

**Why:**
- Balance between conversion and evaluation
- Clear value proposition before commitment
- Guided user journey

---

## UX Options for ADK Multi-Agent RAG

### **Option 1: Enterprise Authentication-First** ⭐ RECOMMENDED

**User Flow:**
```
Landing Page → Sign In Required → Authenticated App
```

**Landing Page Contains:**
- App name and tagline: "Multi-Corpus RAG Assistant"
- Key features list:
  * Query multiple knowledge bases simultaneously
  * Access AI Books, Design Docs, Management Resources
  * Multi-agent architecture for specialized queries
  * Secure, organization-restricted access
- "Sign In with Google" button (primary CTA)
- Optional: "Learn More" section

**After Sign In:**
- Onboarding tutorial (first-time users)
- Dashboard/Welcome screen showing:
  * Available corpora
  * Recent conversations
  * Quick start guide
- Then → Chat interface

**Pros:**
✅ Clear enterprise positioning  
✅ Proper access control from start  
✅ User tracking for audit/compliance  
✅ Personalized experience (history, preferences)  
✅ No confusion about capabilities  
✅ Aligns with production OAuth/IAP setup  

**Cons:**
❌ Higher barrier to entry  
❌ Can't evaluate before signing in  
❌ Requires Google account

**Best For:**
- Internal enterprise tools
- When data security is paramount
- Organization-restricted access
- User personalization is important

---

### **Option 2: Hybrid Landing Page with Guest Demo**

**User Flow:**
```
Landing Page → [Try Demo | Sign In] → Experience
```

**Landing Page Contains:**
- Hero section with value proposition
- Feature highlights with visuals
- Two clear CTAs:
  * "Try Demo" (guest mode, limited)
  * "Sign In" (full access)

**Guest Demo Limitations:**
- No conversation history (session only)
- Limited corpus access (1-2 public corpora)
- Cannot create/manage corpora
- Banner: "Sign in for full access"

**After Sign In:**
- Full feature access
- Persistent history
- All corpora available
- Admin features (if applicable)

**Pros:**
✅ Try before commit  
✅ Showcase value immediately  
✅ Lower barrier to entry  
✅ Clear upgrade path  
✅ Good for mixed audiences (internal + external demos)  

**Cons:**
❌ More complex implementation  
❌ Must maintain two UX paths  
❌ Guest sessions need cleanup  
❌ Potential security concerns if not properly limited

**Best For:**
- Tools with both internal and external users
- When you need to demo capabilities
- Marketing/evaluation scenarios
- Gradual user conversion

---

### **Option 3: Current Approach (Guest Auto-Login)** ❌ NOT RECOMMENDED

**User Flow:**
```
App Load → Auto Guest → Chat Interface
```

**Pros:**
✅ Zero friction  
✅ Immediate access  

**Cons:**
❌ No value proposition  
❌ Confusing user state  
❌ Unclear limitations  
❌ No onboarding  
❌ Security ambiguity  
❌ Poor enterprise positioning  
❌ Doesn't align with OAuth/IAP production setup  
❌ No incentive to authenticate

**Verdict:** Poor UX for enterprise tools

---

## Recommendation: Option 1 (Enterprise Authentication-First)

### Why This Makes Sense for Your App

**1. Your Production Architecture Requires Auth**
- OAuth with IAP in production
- Organization domain restrictions (`@develom.com`)
- No public access path in deployment
- Mismatch between dev (guest) and prod (OAuth) is confusing

**2. Enterprise Use Case**
- Multi-corpus RAG is for knowledge workers
- Need audit trails and usage tracking
- Access control per corpus (you have group-based permissions)
- User preferences and history matter

**3. Security and Compliance**
- Guest users bypass entire auth system
- Unclear data access boundaries
- Cannot enforce corpus-level permissions
- No audit trail for queries

**4. Better User Experience**
- Clear purpose and positioning
- Proper onboarding flow
- Personalized experience from start
- Consistent dev and prod experience

**5. Existing Infrastructure Ready**
- Authentication system already built
- User management in place
- Profile and preferences system exists
- Just need to enforce it from start

---

## Implementation Plan

### Phase 1: Create Landing Page (1-2 days)

**New Route:** `/landing` or update `/` to landing

**Components:**
1. **Hero Section**
   - App name: "ADK Multi-Corpus RAG Assistant"
   - Tagline: "Query multiple knowledge bases with AI-powered intelligence"
   - Primary CTA: "Sign In with Google"

2. **Feature Grid** (3-4 key features)
   - Multi-corpus querying
   - Parallel agent execution
   - Secure access control
   - Conversation history

3. **Visual Element**
   - Screenshot or animated demo
   - Shows chat interface in action

4. **Footer**
   - Documentation link
   - Support contact
   - Version info

**Tech Stack:**
- Next.js page component
- TailwindCSS styling
- Reuse existing LoginForm component

---

### Phase 2: Update Authentication Flow (1 day)

**Changes to `/app/page.tsx`:**

```typescript
// Remove auto guest creation
// Add route protection

useEffect(() => {
  const checkAuth = async () => {
    if (apiClient.isAuthenticated()) {
      // Load user and proceed to app
      const userData = await apiClient.verifyToken();
      setUser(userData);
      setShowApp(true);
    } else {
      // Redirect to landing
      router.push('/landing');
    }
  };
  checkAuth();
}, []);
```

**Authentication States:**
- Not authenticated → Show landing page
- Authenticated → Show chat app
- Auth expired → Redirect to landing with message

---

### Phase 3: Add Onboarding (Optional, 1 day)

**First-Time User Flow:**

1. **Welcome Modal** (after first sign-in)
   - "Welcome to ADK RAG Assistant"
   - Key features overview
   - "Let's get started" button

2. **Quick Tour** (optional, dismissible)
   - Corpus selector intro
   - Chat input demo
   - Feature highlights
   - "Skip tour" option

3. **Starter Prompt Suggestions**
   - Show example queries
   - Pre-populate based on available corpora
   - "Try these queries" cards

---

### Phase 4: Update Session Summary (1 hour)

**Document decision and implementation:**
- Why authentication-first chosen
- User flow diagrams
- Implementation commits
- Testing plan

---

## Alternative: Quick Fix (If Keeping Guest)

If you want to **keep guest access temporarily** but improve UX:

### Minimal Changes:

1. **Add Welcome Banner** (5 minutes)
   ```typescript
   {user?.username === 'guest' && (
     <div className="bg-blue-50 border-l-4 border-blue-400 p-4">
       <p className="text-sm">
         👋 You're using a guest session. 
         <button onClick={() => setShowLogin(true)}>
           Sign in
         </button> for full access.
       </p>
     </div>
   )}
   ```

2. **Add Feature Highlight Modal** (30 minutes)
   - Show on first load
   - Explain available corpora
   - List key features
   - "Got it" to dismiss

3. **Make Sign In Prominent** (15 minutes)
   - Add "Sign In" button to top navigation
   - Show persistent banner for guests

**Pros:** Quick, keeps current flow  
**Cons:** Still poor UX, doesn't solve fundamental issues

---

## Measurement and Success Criteria

### Metrics to Track (Post-Implementation):

**User Flow:**
- % of landing page visitors who sign in
- Time to first authentication
- Bounce rate on landing page

**Engagement:**
- % of authenticated users who complete first query
- Average session length (authed vs guest if keeping guest)
- Repeat visit rate

**Feature Discovery:**
- % of users who try multiple corpora
- % who view onboarding tutorial
- Feature usage across user segments

---

## Next Steps

**Decision Required:**
1. **Which option do you prefer?**
   - Option 1: Authentication-First (Recommended)
   - Option 2: Hybrid with Guest Demo
   - Option 3: Quick fixes to current guest approach

2. **Timeline:**
   - Urgent (2-3 days): Landing page + auth enforcement
   - Standard (1 week): Full implementation with onboarding
   - Quick fix (1-2 hours): Improve current guest experience

3. **Scope:**
   - Minimum viable: Landing page + sign-in requirement
   - Enhanced: Add onboarding and feature discovery
   - Full: Analytics, A/B testing, progressive onboarding

**Recommendation:** Go with **Option 1** for a clean, professional enterprise experience that matches your production deployment.
