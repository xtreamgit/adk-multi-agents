/**
 * Enhanced API Client for new authentication, user management, agents, groups, and corpora
 * Integrates with the new backend API routes
 */

// ============================================================================
// Type Definitions
// ============================================================================

export type Message = {
  text: string;
  sender: 'user' | 'agent';
  timestamp?: Date;
};

export type User = {
  id: number;
  username: string;
  email: string;
  full_name: string;
  is_active: boolean;
  default_agent_id: number | null;
  created_at: string;
  updated_at: string;
  last_login: string | null;
};

export type UserProfile = {
  id: number;
  user_id: number;
  theme: string;
  language: string;
  timezone: string;
  preferences: Record<string, any> | null;
};

export type UserWithProfile = User & {
  profile: UserProfile;
};

export type Agent = {
  id: number;
  name: string;
  display_name: string;
  description: string;
  config_path: string;
  is_active: boolean;
  created_at: string;
  has_access?: boolean;
  is_default?: boolean;
};

export type Corpus = {
  id: number;
  name: string;
  display_name: string;
  description: string;
  gcs_bucket: string;
  vertex_corpus_id: string | null;
  is_active: boolean;
  created_at: string;
  has_access?: boolean;
  permission?: 'read' | 'write' | 'admin';
  is_active_in_session?: boolean;
  document_count?: number;
};

export type Group = {
  id: number;
  name: string;
  description: string;
  is_active: boolean;
  created_at: string;
};

export type Role = {
  id: number;
  name: string;
  description: string;
  permissions: string[];
  created_at: string;
};

export type LoginData = {
  username: string;
  password: string;
};

export type RegisterData = {
  username: string;
  password: string;
  full_name: string;
  email: string;
};

export type AuthToken = {
  access_token: string;
  token_type: string;
  user: User;
};

export type UpdateProfileData = {
  theme?: string;
  language?: string;
  timezone?: string;
  preferences?: Record<string, any>;
};

export type SessionInfo = {
  session_id: string;
  user_profile?: UserProfile;
  username?: string;
  created_at: string;
  last_activity: string;
};

// ============================================================================
// API Client Class
// ============================================================================

class EnhancedApiClient {
  private token: string | null = null;
  private sessionId: string | null = null;
  private currentUser: User | null = null;
  private baseUrl: string;

  constructor() {
    // Use relative URLs when behind load balancer (production), localhost for development
    this.baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || '';
    
    // Load from localStorage if available
    if (typeof window !== 'undefined') {
      this.token = localStorage.getItem('auth_token');
      this.sessionId = localStorage.getItem('session_id');
      const userStr = localStorage.getItem('current_user');
      if (userStr) {
        try {
          this.currentUser = JSON.parse(userStr);
        } catch (e) {
          console.error('Failed to parse stored user:', e);
        }
      }
    }
  }

  // ========== Helper Methods ==========

  private getAuthHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    
    return headers;
  }

  private buildUrl(path: string): string {
    return `${this.baseUrl}${path}`;
  }

  private setToken(token: string) {
    this.token = token;
    if (typeof window !== 'undefined') {
      localStorage.setItem('auth_token', token);
    }
  }

  public clearToken(): void {
    this.token = null;
    if (typeof window !== 'undefined') {
      localStorage.removeItem('auth_token');
      localStorage.removeItem('current_user');
    }
  }

  private setCurrentUser(user: User) {
    this.currentUser = user;
    if (typeof window !== 'undefined') {
      localStorage.setItem('current_user', JSON.stringify(user));
    }
  }

  isAuthenticated(): boolean {
    return !!this.token;
  }

  getCurrentUser(): User | null {
    return this.currentUser;
  }

  // ========== Authentication Endpoints ==========

  async register(data: RegisterData): Promise<User> {
    const response = await fetch(this.buildUrl('/api/auth/register'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      // Handle FastAPI validation errors (422) which return an array
      if (Array.isArray(error.detail)) {
        const messages = error.detail.map((err: any) => err.msg).join(', ');
        throw new Error(messages || 'Registration failed');
      }
      throw new Error(error.detail || 'Registration failed');
    }

    return await response.json();
  }

  async login(data: LoginData): Promise<AuthToken> {
    const response = await fetch(this.buildUrl('/api/auth/login'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Login failed');
    }

    const authToken: AuthToken = await response.json();
    this.setToken(authToken.access_token);
    this.setCurrentUser(authToken.user);
    return authToken;
  }

  async refreshToken(): Promise<AuthToken> {
    const response = await fetch(this.buildUrl('/api/auth/refresh'), {
      method: 'POST',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      this.clearToken();
      throw new Error('Token refresh failed');
    }

    const authToken: AuthToken = await response.json();
    this.setToken(authToken.access_token);
    return authToken;
  }

  async getCurrentUserInfo(): Promise<User> {
    const response = await fetch(this.buildUrl('/api/auth/me'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to get user info');
    }

    const user: User = await response.json();
    this.setCurrentUser(user);
    return user;
  }

  logout(): void {
    this.clearToken();
    this.currentUser = null;
    this.resetSession();
  }

  // Verify current token and get user data
  async verifyToken(): Promise<User> {
    const response = await fetch(this.buildUrl('/api/users/me'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      this.clearToken();
      throw new Error('Token verification failed');
    }

    return await response.json();
  }

  // Agent selection (placeholder - can be enhanced later)
  setAgent(agent: string): void {
    // Store agent preference if needed
    if (typeof window !== 'undefined') {
      localStorage.setItem('selected_agent', agent);
    }
  }

  // ========== User Profile Endpoints ==========

  async getMyProfile(): Promise<UserWithProfile> {
    const response = await fetch(this.buildUrl('/api/users/me'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to get profile');
    }

    return await response.json();
  }

  async updateProfile(data: UpdateProfileData): Promise<UserProfile> {
    const response = await fetch(this.buildUrl('/api/users/me/preferences'), {
      method: 'PUT',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      throw new Error('Failed to update profile');
    }

    return await response.json();
  }

  async getMyRoles(): Promise<Role[]> {
    const response = await fetch(this.buildUrl('/api/users/me/roles'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to get roles');
    }

    return await response.json();
  }

  async setDefaultAgent(agentId: number): Promise<void> {
    const response = await fetch(this.buildUrl(`/api/users/me/default-agent/${agentId}`), {
      method: 'PUT',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to set default agent');
    }
  }

  // ========== Agent Endpoints ==========

  async getAllAgents(): Promise<Agent[]> {
    const response = await fetch(this.buildUrl('/api/agents/'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to get agents');
    }

    return await response.json();
  }

  async getMyAgents(): Promise<Agent[]> {
    const response = await fetch(this.buildUrl('/api/agents/me'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to get accessible agents');
    }

    return await response.json();
  }

  async switchAgent(sessionId: string, agentId: number): Promise<void> {
    const response = await fetch(this.buildUrl(`/api/agents/session/${sessionId}/switch/${agentId}`), {
      method: 'POST',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to switch agent');
    }
  }

  // ========== Corpus Endpoints ==========

  async getMyCorpora(): Promise<Corpus[]> {
    const response = await fetch(this.buildUrl('/api/corpora/'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Corpora fetch failed:', response.status, errorText);
      throw new Error(`Failed to get corpora: ${response.status} ${errorText}`);
    }

    return await response.json();
  }

  async getAllCorporaWithAccess(): Promise<Corpus[]> {
    const response = await fetch(this.buildUrl('/api/corpora/all-with-access'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('All corpora fetch failed:', response.status, errorText);
      throw new Error(`Failed to get all corpora: ${response.status} ${errorText}`);
    }

    return await response.json();
  }

  async selectSessionCorpora(sessionId: string, corpusIds: number[]): Promise<void> {
    const response = await fetch(this.buildUrl(`/api/corpora/session/${sessionId}/select`), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify({ corpus_ids: corpusIds }),
    });

    if (!response.ok) {
      throw new Error('Failed to select corpora');
    }
  }

  // ========== Group Endpoints ==========

  async getMyGroups(): Promise<Group[]> {
    const response = await fetch(this.buildUrl('/api/groups/me'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to get groups');
    }

    return await response.json();
  }

  async getAllGroups(): Promise<Group[]> {
    const response = await fetch(this.buildUrl('/api/groups/'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('Failed to get all groups');
    }

    return await response.json();
  }

  async createGroup(groupData: { name: string; description: string }): Promise<any> {
    const response = await fetch(this.buildUrl('/api/groups/'), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(groupData),
    });

    if (!response.ok) {
      let errorMessage = `Failed to create group: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async updateGroup(groupId: number, groupData: { name?: string; description?: string }): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/groups/${groupId}`), {
      method: 'PUT',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(groupData),
    });

    if (!response.ok) {
      let errorMessage = `Failed to update group: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async deleteGroup(groupId: number): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/groups/${groupId}`), {
      method: 'DELETE',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      let errorMessage = `Failed to delete group: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async getGroupUsers(groupId: number): Promise<any[]> {
    const response = await fetch(this.buildUrl(`/api/groups/${groupId}/users`), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get group users: ${response.statusText}`);
    }

    return response.json();
  }

  async addUserToGroupViaGroupAPI(groupId: number, userId: number): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/groups/${groupId}/users/${userId}`), {
      method: 'PUT',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      let errorMessage = `Failed to add user to group: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async removeUserFromGroupViaGroupAPI(groupId: number, userId: number): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/groups/${groupId}/users/${userId}`), {
      method: 'DELETE',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      let errorMessage = `Failed to remove user from group: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  // ========== Role Management APIs ==========

  async getAllRoles(): Promise<any[]> {
    const response = await fetch(this.buildUrl('/api/groups/roles/'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get roles: ${response.statusText}`);
    }

    return response.json();
  }

  async createRole(roleData: { name: string; permissions: string[] }): Promise<any> {
    const response = await fetch(this.buildUrl('/api/groups/roles/'), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(roleData),
    });

    if (!response.ok) {
      let errorMessage = `Failed to create role: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async assignRoleToGroup(groupId: number, roleId: number): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/groups/${groupId}/roles/${roleId}`), {
      method: 'PUT',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      let errorMessage = `Failed to assign role: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async removeRoleFromGroup(groupId: number, roleId: number): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/groups/${groupId}/roles/${roleId}`), {
      method: 'DELETE',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      let errorMessage = `Failed to remove role: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  // ========== Session/Chat Endpoints (Legacy compatibility) ==========

  resetSession() {
    this.sessionId = null;
    if (typeof window !== 'undefined') {
      localStorage.removeItem('session_id');
    }
  }

  startNewChat() {
    this.resetSession();
  }

  getSessionId(): string | null {
    return this.sessionId;
  }

  private setSessionId(sessionId: string) {
    this.sessionId = sessionId;
    if (typeof window !== 'undefined') {
      localStorage.setItem('session_id', sessionId);
    }
  }

  async createSession(userProfile?: any): Promise<SessionInfo> {
    const response = await fetch(this.buildUrl('/api/sessions'), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: userProfile ? JSON.stringify(userProfile) : JSON.stringify(null),
    });

    if (!response.ok) {
      throw new Error(`Failed to create session: ${response.statusText}`);
    }

    const sessionInfo = await response.json();
    this.setSessionId(sessionInfo.session_id);
    return sessionInfo;
  }

  async sendMessage(text: string, userProfile?: any, selectedCorpora?: string[]): Promise<Message> {
    if (!this.sessionId) {
      await this.createSession(userProfile);
    }

    console.log('[API DEBUG] Sending message with corpora:', selectedCorpora);
    
    const response = await fetch(this.buildUrl(`/api/sessions/${this.sessionId}/chat`), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify({
        message: text,
        user_profile: userProfile,
        corpora: selectedCorpora || [],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`API request failed: ${errorText}`);
    }

    const responseData = await response.json();
    return {
      text: responseData.response,
      sender: 'agent',
      timestamp: new Date(responseData.timestamp),
    };
  }

  async getChatHistory(): Promise<any[]> {
    if (!this.sessionId) {
      return [];
    }

    const response = await fetch(this.buildUrl(`/api/sessions/${this.sessionId}/history`), {
      headers: this.getAuthHeaders(),
    });
    
    if (!response.ok) {
      throw new Error(`Failed to get chat history: ${response.statusText}`);
    }

    const data = await response.json();
    return data.chat_history || [];
  }

  // ========== Admin Panel APIs ==========

  async admin_getAllCorpora(includeInactive: boolean = false): Promise<any[]> {
    const response = await fetch(
      this.buildUrl(`/api/admin/corpora?include_inactive=${includeInactive}`),
      {
        headers: this.getAuthHeaders(),
      }
    );

    if (!response.ok) {
      throw new Error(`Failed to get admin corpora: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_getCorpusDetail(corpusId: number): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/admin/corpora/${corpusId}`), {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get corpus detail: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_updateCorpusMetadata(
    corpusId: number,
    metadata: { tags?: string; notes?: string; sync_status?: string }
  ): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/admin/corpora/${corpusId}/metadata`), {
      method: 'PUT',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(metadata),
    });

    if (!response.ok) {
      throw new Error(`Failed to update metadata: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_updateCorpusStatus(corpusId: number, isActive: boolean): Promise<any> {
    const response = await fetch(
      this.buildUrl(`/api/admin/corpora/${corpusId}/status?is_active=${isActive}`),
      {
        method: 'PUT',
        headers: this.getAuthHeaders(),
      }
    );

    if (!response.ok) {
      throw new Error(`Failed to update status: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_grantPermission(
    corpusId: number,
    groupId: number,
    permission: string = 'read'
  ): Promise<any> {
    const response = await fetch(
      this.buildUrl(`/api/admin/corpora/${corpusId}/permissions/grant`),
      {
        method: 'POST',
        headers: this.getAuthHeaders(),
        body: JSON.stringify({ group_id: groupId, permission }),
      }
    );

    if (!response.ok) {
      throw new Error(`Failed to grant permission: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_revokePermission(corpusId: number, groupId: number): Promise<any> {
    const response = await fetch(
      this.buildUrl(`/api/admin/corpora/${corpusId}/permissions/${groupId}`),
      {
        method: 'DELETE',
        headers: this.getAuthHeaders(),
      }
    );

    if (!response.ok) {
      throw new Error(`Failed to revoke permission: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_bulkGrantAccess(
    corpusIds: number[],
    groupId: number,
    permission: string = 'read'
  ): Promise<any> {
    const response = await fetch(this.buildUrl('/api/admin/corpora/bulk/grant-access'), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify({ corpus_ids: corpusIds, group_id: groupId, permission }),
    });

    if (!response.ok) {
      throw new Error(`Failed to bulk grant access: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_bulkUpdateStatus(corpusIds: number[], isActive: boolean): Promise<any> {
    const response = await fetch(this.buildUrl('/api/admin/corpora/bulk/update-status'), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify({ corpus_ids: corpusIds, is_active: isActive }),
    });

    if (!response.ok) {
      throw new Error(`Failed to bulk update status: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_getAuditLog(filters?: {
    corpus_id?: number;
    user_id?: number;
    action?: string;
    limit?: number;
    offset?: number;
  }): Promise<any[]> {
    const params = new URLSearchParams();
    if (filters?.corpus_id) params.append('corpus_id', filters.corpus_id.toString());
    if (filters?.user_id) params.append('user_id', filters.user_id.toString());
    if (filters?.action) params.append('action', filters.action);
    if (filters?.limit) params.append('limit', filters.limit.toString());
    if (filters?.offset) params.append('offset', filters.offset.toString());

    const response = await fetch(this.buildUrl(`/api/admin/audit?${params.toString()}`), {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get audit log: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_syncCorpora(): Promise<any> {
    const response = await fetch(this.buildUrl('/api/admin/corpora/sync'), {
      method: 'POST',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to sync corpora: ${response.statusText}`);
    }

    return response.json();
  }

  // ========== Admin User Management APIs ==========

  async admin_getAllUsers(): Promise<any[]> {
    const response = await fetch(this.buildUrl('/api/admin/users'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get users: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_createUser(userData: {
    username: string;
    email: string;
    full_name: string;
    password: string;
    group_ids?: number[];
  }): Promise<any> {
    const response = await fetch(this.buildUrl('/api/admin/users'), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(userData),
    });

    if (!response.ok) {
      let errorMessage = `Failed to create user: ${response.statusText}`;
      try {
        const error = await response.json();
        // Handle FastAPI validation errors (422)
        if (typeof error.detail === 'string') {
          errorMessage = error.detail;
        } else if (Array.isArray(error.detail)) {
          // Pydantic validation errors are arrays
          errorMessage = `Validation error: ${error.detail.map((e: any) => `${e.loc?.join('.')} - ${e.msg}`).join(', ')}`;
        } else if (typeof error.detail === 'object') {
          errorMessage = `Failed to create user: ${JSON.stringify(error.detail)}`;
        } else {
          errorMessage = error.detail || errorMessage;
        }
      } catch (e) {
        // Response is not JSON, use status text
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async admin_updateUser(userId: number, userData: {
    email?: string;
    full_name?: string;
    is_active?: boolean;
    password?: string;
  }): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/admin/users/${userId}`), {
      method: 'PUT',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(userData),
    });

    if (!response.ok) {
      let errorMessage = `Failed to update user: ${response.statusText}`;
      try {
        const error = await response.json();
        // Handle FastAPI validation errors (422)
        if (typeof error.detail === 'string') {
          errorMessage = error.detail;
        } else if (Array.isArray(error.detail)) {
          // Pydantic validation errors are arrays
          errorMessage = `Validation error: ${error.detail.map((e: any) => `${e.loc?.join('.')} - ${e.msg}`).join(', ')}`;
        } else if (typeof error.detail === 'object') {
          errorMessage = `Failed to update user: ${JSON.stringify(error.detail)}`;
        } else {
          errorMessage = error.detail || errorMessage;
        }
      } catch (e) {
        // Response is not JSON, use status text
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async admin_deleteUser(userId: number): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/admin/users/${userId}`), {
      method: 'DELETE',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      let errorMessage = `Failed to delete user: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON, use status text
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async admin_assignUserToGroup(userId: number, groupId: number): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/admin/users/${userId}/groups/${groupId}`), {
      method: 'POST',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      let errorMessage = `Failed to assign user to group: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON, use status text
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async admin_removeUserFromGroup(userId: number, groupId: number): Promise<any> {
    const response = await fetch(this.buildUrl(`/api/admin/users/${userId}/groups/${groupId}`), {
      method: 'DELETE',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      let errorMessage = `Failed to remove user from group: ${response.statusText}`;
      try {
        const error = await response.json();
        errorMessage = error.detail || errorMessage;
      } catch (e) {
        // Response is not JSON, use status text
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async admin_getUserStats(): Promise<any> {
    const response = await fetch(this.buildUrl('/api/admin/user-stats'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get user stats: ${response.statusText}`);
    }

    return response.json();
  }

  async admin_getAllSessions(): Promise<any[]> {
    const response = await fetch(this.buildUrl('/api/admin/sessions'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get sessions: ${response.statusText}`);
    }

    return response.json();
  }
}

// Export singleton instance
export const apiClient = new EnhancedApiClient();
