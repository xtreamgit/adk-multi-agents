"use client";

import { useState, useEffect } from 'react';
import { UserProfile, User, apiClient, AgentKey } from '../lib/api';
import LoginForm from '../components/LoginForm';
import ChatInterface from '../components/ChatInterface';
import CorpusSelector from '../components/CorpusSelector';
import Image from 'next/image';

export default function Home() {
  const [user, setUser] = useState<User | null>(null);
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
  const [showProfileSetup, setShowProfileSetup] = useState(false);
  const [chatInputValue, setChatInputValue] = useState('');
  const [selectedCorpus, setSelectedCorpus] = useState<string | null>(null);
  const [showChatInterface, setShowChatInterface] = useState(false);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [wasInChatBeforeProfile, setWasInChatBeforeProfile] = useState(false);
  const [isReturningFromProfile, setIsReturningFromProfile] = useState(false);
  const [shouldAutoSubmit, setShouldAutoSubmit] = useState(false);
  const [isLoadingExistingSession, setIsLoadingExistingSession] = useState(false);
  const [savedChatState, setSavedChatState] = useState<{
    showChatInterface: boolean;
    chatInputValue: string;
    selectedCorpus: string | null;
    sessionId: string | null;
  } | null>(null);
  const [selectedAgent, setSelectedAgent] = useState<AgentKey>('default');

  const makeGuest = () => {
    const guest = {
      username: 'guest',
      full_name: 'Guest',
      email: 'guest@example.com',
      created_at: new Date().toISOString(),
      last_login: undefined,
    } as User;
    setUser(guest);
    setUserProfile({ name: guest.full_name, preferences: '' });
  };

  // Check for existing authentication on component mount; if none, default to guest
  useEffect(() => {
    const checkAuth = async () => {
      try {
        if (apiClient.isAuthenticated()) {
          const userData = await apiClient.verifyToken();
          setUser(userData);
          // Create a basic user profile from user data
          setUserProfile({
            name: userData.full_name,
            preferences: ''
          });
          
          // Check if there's an existing session
          const existingSessionId = apiClient.getSessionId();
          if (existingSessionId) {
            setSessionId(existingSessionId);
            setShowChatInterface(true);
            setIsLoadingExistingSession(true); // This ensures chat history is loaded
          }
        } else {
          // No token present: operate as guest by default
          makeGuest();
        }
      } catch (error) {
        console.error('Auth verification failed:', error);
        apiClient.clearToken();
        // Fall back to guest on verification failure
        makeGuest();
      } finally {
        setIsLoading(false);
      }
    };

    // Initialize agent selection from localStorage and sync to API client
    if (typeof window !== 'undefined') {
      const storedAgent = (localStorage.getItem('selected_agent') as AgentKey | null) || 'default';
      setSelectedAgent(storedAgent);
      apiClient.setAgent(storedAgent);
    }

    checkAuth();
  }, []);

  const handleAgentChange = (agent: AgentKey) => {
    setSelectedAgent(agent);
    apiClient.setAgent(agent);
  };

  const handleLoginSuccess = (userData: User) => {
    setUser(userData);
    // Create a basic user profile from user data
    setUserProfile({
      name: userData.full_name,
      preferences: ''
    });
  };

  const handleLogout = () => {
    apiClient.logout();
    // Keep user as guest instead of showing login
    makeGuest();
    setShowChatInterface(false);
    setChatInputValue('');
    setSelectedCorpus(null);
    setSessionId(null);
  };

  const handleProfileSubmit = (profile: UserProfile) => {
    setUserProfile(profile);
    setShowProfileSetup(false);
    
    // If there was a saved chat state, restore it completely
    if (savedChatState && savedChatState.sessionId) {
      setShowChatInterface(savedChatState.showChatInterface);
      setChatInputValue(savedChatState.chatInputValue);
      setSelectedCorpus(savedChatState.selectedCorpus);
      setSessionId(savedChatState.sessionId);
      setIsReturningFromProfile(true);
      setSavedChatState(null);
    }
  };

  const handleUpdateProfile = () => {
    if (showChatInterface) {
      // Save current chat state before switching to profile
      setSavedChatState({
        showChatInterface,
        chatInputValue,
        selectedCorpus,
        sessionId
      });
      setWasInChatBeforeProfile(true);
    }
    setShowProfileSetup(true);
  };

  // Reset auto-submit flag after it's been used
  useEffect(() => {
    if (shouldAutoSubmit && showChatInterface) {
      // Reset the flag after a short delay to allow the ChatInterface to process it
      const timer = setTimeout(() => {
        setShouldAutoSubmit(false);
      }, 200);
      return () => clearTimeout(timer);
    }
  }, [shouldAutoSubmit, showChatInterface]);

  const handleCancelEdit = () => {
    setShowProfileSetup(false);
    
    // If there was a saved chat state, restore it completely
    if (savedChatState && savedChatState.sessionId) {
      setShowChatInterface(savedChatState.showChatInterface);
      setChatInputValue(savedChatState.chatInputValue);
      setSelectedCorpus(savedChatState.selectedCorpus);
      setSessionId(savedChatState.sessionId);
      setIsReturningFromProfile(true);
      setSavedChatState(null);
    }
  };

  const handleStartChat = () => {
    if (chatInputValue.trim()) {
      setShouldAutoSubmit(true);
      setShowChatInterface(true);
    }
  };

  const handleNewChat = () => {
    setShowChatInterface(false);
    setChatInputValue('');
    setIsReturningFromProfile(false);
    setIsLoadingExistingSession(false);
    setShouldAutoSubmit(false);
    // Reset API client session for fresh chat
    import('../lib/api').then(({ apiClient }) => {
      apiClient.resetSession();
      setSessionId(null);
    });
  };

  // Poll for session ID updates
  useEffect(() => {
    const interval = setInterval(() => {
      import('../lib/api').then(({ apiClient }) => {
        const currentSessionId = apiClient.getSessionId();
        if (currentSessionId !== sessionId) {
          setSessionId(currentSessionId);
        }
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [sessionId]);

  // Show loading screen while checking authentication
  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-100 dark:bg-gray-900 flex items-center justify-center p-4">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-green-600 mx-auto mb-4"></div>
          <p className="text-gray-600 dark:text-gray-400">Loading...</p>
        </div>
      </div>
    );
  }

  // Show profile setup if user wants to edit profile
  if (showProfileSetup) {
    return (
      <div className="min-h-screen bg-gray-100 dark:bg-gray-900 flex items-center justify-center p-4">
        <div className="bg-white dark:bg-gray-800 p-8 rounded-lg shadow-lg w-full max-w-md">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">
            Update Profile
          </h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Display Name
              </label>
              <input
                type="text"
                value={userProfile?.name || ''}
                onChange={(e) => setUserProfile(prev => prev ? {...prev, name: e.target.value} : {name: e.target.value, preferences: ''})}
                className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 dark:bg-gray-700 dark:text-white"
                placeholder="Enter your display name"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Preferences (Optional)
              </label>
              <textarea
                value={userProfile?.preferences || ''}
                onChange={(e) => setUserProfile(prev => prev ? {...prev, preferences: e.target.value} : {name: '', preferences: e.target.value})}
                className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 dark:bg-gray-700 dark:text-white"
                placeholder="Tell us about your preferences..."
                rows={3}
              />
            </div>
            <div className="flex space-x-3">
              <button
                onClick={handleCancelEdit}
                className="flex-1 py-3 px-4 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => userProfile && handleProfileSubmit(userProfile)}
                className="flex-1 bg-green-600 text-white py-3 px-4 rounded-lg hover:bg-green-700 transition-colors"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Show chat interface if user has started chatting
  if (showChatInterface) {
    return (
      <div className="flex h-screen bg-gray-50">
        {/* Left Sidebar - Navigation and Corpus Selector */}
        <div className="w-80 bg-gray-100 border-r border-gray-200 flex flex-col">
          {/* USFS Logo and Title */}
          <div className="p-4 border-b border-gray-200">
            <div className="flex items-center space-x-3 mb-4">
              <Image 
                src="/fs-logo.svg" 
                alt="USDA Forest Service" 
                width={60} 
                height={40}
                className="h-10 w-auto"
              />
              <div>
                <h2 className="text-lg font-semibold text-gray-900">Forest Service</h2>
                <p className="text-sm text-gray-600">U.S. DEPARTMENT OF AGRICULTURE</p>
              </div>
            </div>
          </div>
          {/* Navigation Menu */}
          <div className="p-4 space-y-2">
            {/* Session ID Display */}
            <div className="px-3 py-2 bg-gray-50 rounded-lg border">
              <div className="text-xs text-gray-500 mb-1">Session ID:</div>
              <div className="text-xs font-mono text-gray-700 break-all">
                {sessionId || 'No active session'}
              </div>
            </div>
            
            <button 
              onClick={handleNewChat}
              className="w-full flex items-center space-x-3 p-3 text-left text-gray-700 hover:bg-gray-200 rounded-lg transition-colors"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
              </svg>
              <span className="font-medium">New Chat</span>
            </button>
            
            <button className="w-full flex items-center space-x-3 p-3 text-left text-gray-700 hover:bg-gray-200 rounded-lg transition-colors">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
              <span>Search Chats</span>
            </button>
            
            <button className="w-full flex items-center space-x-3 p-3 text-left text-gray-700 hover:bg-gray-200 rounded-lg transition-colors">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <span>List Documents</span>
            </button>
          </div>

          {/* Corpus Selector */}
          <div className="flex-1 p-4">
            <CorpusSelector 
              selectedCorpus={selectedCorpus}
              onCorpusSelect={setSelectedCorpus}
            />
          </div>

          {/* Agent Selector */}
          <div className="px-3 py-2 bg-gray-50 rounded-lg border">
            <div className="text-xs text-gray-500 mb-1">Agent:</div>
            <select
              value={selectedAgent}
              onChange={(e) => handleAgentChange(e.target.value as AgentKey)}
              className="w-full text-xs p-1 border border-gray-300 rounded"
            >
              <option value="default">Default</option>
              <option value="agent1">Agent 1</option>
              <option value="agent2">Agent 2</option>
              <option value="agent3">Agent 3</option>
            </select>
          </div>

          {/* Chats Section */}
          <div className="p-4 border-t border-gray-200">
            <button className="w-full flex items-center space-x-3 p-3 text-left text-gray-700 hover:bg-gray-200 rounded-lg transition-colors">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
              </svg>
              <span>Chats</span>
            </button>
          </div>

          {/* Profile Section */}
          <div className="p-4 border-t border-gray-200 bg-green-600 text-white">
            <button 
              onClick={handleUpdateProfile}
              className="w-full flex items-center space-x-3 p-3 text-left hover:bg-green-700 rounded-lg transition-colors mb-2"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
              <span className="font-medium">Profile</span>
            </button>
            <button 
              onClick={handleLogout}
              className="w-full flex items-center space-x-3 p-3 text-left hover:bg-green-700 rounded-lg transition-colors"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
              </svg>
              <span className="font-medium">Logout</span>
            </button>
          </div>
        </div>
        
        {/* Chat Interface */}
        <div className="flex-1">
          {userProfile && (
            <ChatInterface 
              userProfile={userProfile}
              onUpdateProfile={handleUpdateProfile}
              inputValue={chatInputValue}
              onInputChange={setChatInputValue}
              selectedCorpus={selectedCorpus}
              initialMessage={isReturningFromProfile ? '' : chatInputValue}
              shouldAutoSubmitInitial={shouldAutoSubmit && !isReturningFromProfile}
              onNewChat={handleNewChat}
              sessionId={sessionId}
              isReturningToSession={isReturningFromProfile || isLoadingExistingSession}
            />
          )}
        </div>
      </div>
    );
  }

  // Show landing page with USFS-RAG layout once profile is set
  return (
    <div className="flex h-screen bg-gray-50">
      {/* Left Sidebar - Navigation and Corpus Selector */}
      <div className="w-80 bg-gray-100 border-r border-gray-200 flex flex-col">
        {/* USFS Logo and Title */}
        <div className="p-4 border-b border-gray-200">
          <div className="flex items-center space-x-3 mb-4">
            <Image 
              src="/fs-logo.svg" 
              alt="USDA Forest Service" 
              width={60} 
              height={40}
              className="h-10 w-auto"
            />
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Forest Service</h2>
              <p className="text-sm text-gray-600">U.S. DEPARTMENT OF AGRICULTURE</p>
            </div>
          </div>
        </div>

        {/* Navigation Menu */}
        <div className="p-4 space-y-2">
          {/* Session ID Display */}
          <div className="px-3 py-2 bg-gray-50 rounded-lg border">
            <div className="text-xs text-gray-500 mb-1">Session ID:</div>
            <div className="text-xs font-mono text-gray-700 break-all">
              {sessionId || 'No active session'}
            </div>
          </div>
            
          <button 
            onClick={handleNewChat}
            className="w-full flex items-center space-x-3 p-3 text-left text-gray-700 hover:bg-gray-200 rounded-lg transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
            </svg>
            <span className="font-medium">New Chat</span>
          </button>
          
          <button className="w-full flex items-center space-x-3 p-3 text-left text-gray-700 hover:bg-gray-200 rounded-lg transition-colors">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <span>Search Chats</span>
          </button>
          
          <button className="w-full flex items-center space-x-3 p-3 text-left text-gray-700 hover:bg-gray-200 rounded-lg transition-colors">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <span>List Documents</span>
          </button>
        </div>

        {/* Corpus Selector */}
        <div className="flex-1 p-4">
          <CorpusSelector 
            selectedCorpus={selectedCorpus}
            onCorpusSelect={setSelectedCorpus}
          />
        </div>

        {/* Agent Selector */}
        <div className="px-3 py-2 bg-gray-50 rounded-lg border">
          <div className="text-xs text-gray-500 mb-1">Agent:</div>
          <select
            value={selectedAgent}
            onChange={(e) => handleAgentChange(e.target.value as AgentKey)}
            className="w-full text-xs p-1 border border-gray-300 rounded"
          >
            <option value="default">Default</option>
            <option value="agent1">Agent 1</option>
            <option value="agent2">Agent 2</option>
            <option value="agent3">Agent 3</option>
          </select>
        </div>

        {/* Chats Section */}
        <div className="p-4 border-t border-gray-200">
          <button className="w-full flex items-center space-x-3 p-3 text-left text-gray-700 hover:bg-gray-200 rounded-lg transition-colors">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
            <span>Chats</span>
          </button>
        </div>

        {/* Profile Section */}
        <div className="p-4 border-t border-gray-200 bg-green-600 text-white">
          <button 
            onClick={handleUpdateProfile}
            className="w-full flex items-center space-x-3 p-3 text-left hover:bg-green-700 rounded-lg transition-colors mb-2"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
            <span className="font-medium">Profile</span>
          </button>
          <button 
            onClick={handleLogout}
            className="w-full flex items-center space-x-3 p-3 text-left hover:bg-green-700 rounded-lg transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
            <span className="font-medium">Logout</span>
          </button>
        </div>
      </div>
      
      {/* Main Content Area */}
      <div className="flex-1 flex flex-col">
        {/* Top Header with USDA Forest Service Logo */}
        <header className="bg-white border-b border-gray-200 p-4 flex justify-between items-center">
          <div className="flex items-center space-x-4">
            <div>
              <h2 className="text-lg font-semibold text-gray-900"><strong>USFS Retrieval Augmented Generation (RAG)</strong></h2>
            </div>
          </div>
          <div className="flex items-center space-x-4">
            <span className="text-sm text-gray-600">Hello, {user?.full_name || 'Guest'}!</span>
            {selectedCorpus && (
              <span className="px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm font-medium">
                Corpus: {selectedCorpus}
              </span>
            )}
            <span className="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-medium">
              Agent: {selectedAgent}
            </span>
          </div>
        </header>

        {/* Main Chat Area */}
        <div className="flex-1 flex flex-col justify-center items-center p-8">
          <div className="max-w-2xl w-full text-center">
            <h1 className="text-3xl font-bold text-gray-900 mb-8">
              What would you like to research today?
            </h1>
            
            <div className="relative">
              <input
                type="text"
                value={chatInputValue}
                onChange={(e) => setChatInputValue(e.target.value)}
                placeholder="Ask your question"
                className="w-full p-4 pr-24 text-lg border border-gray-300 rounded-full focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && chatInputValue.trim()) {
                    handleStartChat();
                  }
                }}
              />
              <button 
                onClick={handleStartChat}
                disabled={!chatInputValue.trim()}
                className="absolute right-2 top-1/2 transform -translate-y-1/2 bg-green-600 text-white px-6 py-2 rounded-full hover:bg-green-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Ask
              </button>
            </div>
          </div>
        </div>

        {/* Footer */}
        <footer className="bg-gray-200 p-4 text-center">
          <div className="flex items-center justify-center space-x-2">
            <Image 
              src="/fs-logo.svg" 
              alt="USDA Forest Service" 
              width={20} 
              height={16}
              className="h-4 w-auto"
            />
            <p className="text-sm text-gray-600">
              USFS-RAG can make mistakes. Always check important info.
            </p>
          </div>
        </footer>
      </div>
    </div>
  );
}
