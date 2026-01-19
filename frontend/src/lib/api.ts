export type Message = {
  text: string;
  sender: 'user' | 'agent';
  timestamp?: Date;
};

export type UserProfile = {
  name: string;
  preferences?: string;
};

export type User = {
  username: string;
  full_name: string;
  email: string;
  created_at: string;
  last_login?: string;
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

export type SessionInfo = {
  session_id: string;
  user_profile?: UserProfile;
  username?: string;
  created_at: string;
  last_activity: string;
};

export type AgentKey = 'default' | 'agent1' | 'agent2' | 'agent3';

// @ts-ignore
// Backend URL should be set via NEXT_PUBLIC_BACKEND_URL environment variable during build
// For Load Balancer deployments, this is set to the LB URL (no agent prefix).
const API_BASE_URL = process.env.NEXT_PUBLIC_BACKEND_URL || '';

// Per-agent path prefixes for multi-agent routing behind the same Load Balancer
const AGENT_PATH_PREFIX: Record<AgentKey, string> = {
  default: '',
  agent1: '/agent1',
  agent2: '/agent2',
  agent3: '/agent3',
};

class ApiClient {
  private sessionId: string | null = null;
  private token: string | null = null;
  private agent: AgentKey = 'default';

  constructor() {
    // Load token, agent, and session from localStorage on initialization
    if (typeof window !== 'undefined') {
      this.token = localStorage.getItem('auth_token');
      this.sessionId = localStorage.getItem('session_id');
      const storedAgent = localStorage.getItem('selected_agent') as AgentKey | null;
      if (storedAgent && AGENT_PATH_PREFIX[storedAgent] !== undefined) {
        this.agent = storedAgent;
      }
    }
  }

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
    const base = API_BASE_URL || '';
    const prefix = AGENT_PATH_PREFIX[this.agent] ?? '';
    return `${base}${prefix}${path}`;
  }

  setToken(token: string) {
    this.token = token;
    if (typeof window !== 'undefined') {
      localStorage.setItem('auth_token', token);
    }
  }

  clearToken() {
    this.token = null;
    if (typeof window !== 'undefined') {
      localStorage.removeItem('auth_token');
    }
  }

  isAuthenticated(): boolean {
    return !!this.token;
  }

  setAgent(agent: AgentKey) {
    this.agent = agent;
    if (typeof window !== 'undefined') {
      localStorage.setItem('selected_agent', agent);
    }
  }

  async login(loginData: LoginData): Promise<AuthToken> {
    const response = await fetch(this.buildUrl('/api/auth/login'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(loginData),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Login failed');
    }

    const authToken = await response.json();
    this.setToken(authToken.access_token);
    return authToken;
  }

  async register(registerData: RegisterData): Promise<User> {
    const response = await fetch(this.buildUrl('/api/auth/register'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(registerData),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Registration failed');
    }

    return await response.json();
  }

  async verifyToken(): Promise<User> {
    if (!this.token) {
      throw new Error('No token available');
    }

    const response = await fetch(this.buildUrl('/api/auth/verify'), {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      this.clearToken();
      throw new Error('Token verification failed');
    }

    return await response.json();
  }

  logout() {
    this.clearToken();
    this.resetSession();
  }

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

  async createSession(userProfile?: UserProfile): Promise<SessionInfo> {
    const response = await fetch(this.buildUrl('/api/sessions'), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(userProfile || {}),
    });

    if (!response.ok) {
      throw new Error(`Failed to create session: ${response.statusText}`);
    }

    const sessionInfo = await response.json();
    this.setSessionId(sessionInfo.session_id);
    return sessionInfo;
  }

  async updateUserProfile(userProfile: UserProfile): Promise<void> {
    if (!this.sessionId) {
      throw new Error('No active session');
    }

    const response = await fetch(this.buildUrl(`/api/sessions/${this.sessionId}/profile`), {
      method: 'PUT',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(userProfile),
    });

    if (!response.ok) {
      throw new Error(`Failed to update profile: ${response.statusText}`);
    }
  }

  async sendMessage(text: string, userProfile?: UserProfile): Promise<Message> {
    if (!this.sessionId) {
      // Create a session if none exists
      await this.createSession(userProfile);
    }

    const response = await fetch(this.buildUrl(`/api/sessions/${this.sessionId}/chat`), {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify({
        message: text,
        user_profile: userProfile,
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

  async listCorpora(): Promise<string> {
    const response = await fetch(this.buildUrl('/api/corpora'), {
      headers: this.getAuthHeaders(),
    });
    if (!response.ok) {
      throw new Error(`Failed to list corpora: ${response.statusText}`);
    }

    const data = await response.json();
    return data.corpora;
  }

  async createCorpus(name: string): Promise<string> {
    const response = await fetch(this.buildUrl(`/api/corpora?corpus_name=${encodeURIComponent(name)}`), {
      method: 'POST',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to create corpus: ${response.statusText}`);
    }

    const data = await response.json();
    return data.response;
  }

  async getAllUsers(): Promise<any> {
    const response = await fetch(this.buildUrl('/api/admin/users'), {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get users: ${response.statusText}`);
    }

    return await response.json();
  }

  async getUserStats(): Promise<any> {
    const response = await fetch(this.buildUrl('/api/admin/user-stats'), {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get user stats: ${response.statusText}`);
    }

    return await response.json();
  }

  async getAllSessions(): Promise<any> {
    const response = await fetch(this.buildUrl('/api/admin/sessions'), {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get sessions: ${response.statusText}`);
    }

    return await response.json();
  }

  async retrieveDocument(corpusId: number, documentName: string, generateSignedUrl: boolean = false): Promise<DocumentRetrievalResponse> {
    const params = new URLSearchParams({
      corpus_id: corpusId.toString(),
      document_name: documentName,
      generate_signed_url: generateSignedUrl.toString(),
    });

    const response = await fetch(this.buildUrl(`/api/documents/retrieve?${params}`), {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Failed to retrieve document');
    }

    return await response.json();
  }

  async getDocumentAccessLogs(limit: number = 50): Promise<DocumentAccessLog[]> {
    const response = await fetch(this.buildUrl(`/api/documents/access-logs?limit=${limit}`), {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Failed to get access logs: ${response.statusText}`);
    }

    const data = await response.json();
    return data.logs || [];
  }
}

export type DocumentRetrievalResponse = {
  status: string;
  document: {
    id: string;
    name: string;
    corpus_id: number;
    corpus_name: string;
    file_type: string;
    size_bytes?: number;
    created_at?: string;
    updated_at?: string;
  };
  access?: {
    url: string;
    expires_at: string;
    valid_for_seconds: number;
  };
};

export type DocumentAccessLog = {
  id: number;
  user_id: number;
  corpus_id: number;
  document_name: string;
  document_file_id?: string;
  access_type: string;
  success: boolean;
  error_message?: string;
  source_uri?: string;
  accessed_at: string;
};

export const apiClient = new ApiClient();
