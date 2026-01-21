"use client";

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiClient } from '../../lib/api-enhanced';
import LoginForm from '../../components/LoginForm';

export default function LandingPage() {
  const router = useRouter();
  const [showLogin, setShowLogin] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  // Check if already authenticated
  useEffect(() => {
    const checkAuth = async () => {
      try {
        if (apiClient.isAuthenticated()) {
          const userData = await apiClient.verifyToken();
          if (userData && userData.username !== 'guest') {
            // Redirect authenticated users to main app
            router.push('/');
            return;
          }
        }
      } catch (error) {
        console.error('Auth check failed:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    checkAuth();
  }, [router]);

  const handleLoginSuccess = () => {
    router.push('/');
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-green-50 flex items-center justify-center">
        <div className="text-gray-600">Loading...</div>
      </div>
    );
  }

  if (showLogin) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-green-50 flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-white rounded-lg shadow-xl p-8">
          <button
            onClick={() => setShowLogin(false)}
            className="mb-4 text-sm text-gray-600 hover:text-gray-900 flex items-center"
          >
            ← Back to Home
          </button>
          <LoginForm onLoginSuccess={handleLoginSuccess} />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-green-50">
      {/* Navigation */}
      <nav className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <div className="flex items-center space-x-2">
              <svg className="w-8 h-8" style={{ color: '#005440' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
              <span className="text-xl font-bold text-gray-900">ADK RAG Assistant</span>
            </div>
            <button
              onClick={() => setShowLogin(true)}
              className="px-4 py-2 text-white rounded-lg transition-colors"
              style={{ backgroundColor: '#005440' }}
              onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#004030'}
              onMouseLeave={(e) => e.currentTarget.style.backgroundColor = '#005440'}
            >
              Sign In
            </button>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <div className="text-center">
          <h1 className="text-5xl font-bold text-gray-900 mb-6">
            Multi-Corpus RAG Assistant
          </h1>
          <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
            Query multiple knowledge bases simultaneously with AI-powered intelligence.
            Secure, enterprise-grade retrieval augmented generation for your organization.
          </p>
          <button
            onClick={() => setShowLogin(true)}
            className="px-8 py-4 text-white text-lg font-semibold rounded-lg transition-colors shadow-lg"
            style={{ backgroundColor: '#005440' }}
            onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#004030'}
            onMouseLeave={(e) => e.currentTarget.style.backgroundColor = '#005440'}
          >
            Get Started →
          </button>
        </div>

        {/* Features Grid */}
        <div className="mt-20 grid md:grid-cols-2 lg:grid-cols-4 gap-8">
          {/* Feature 1 */}
          <div className="bg-white p-6 rounded-lg shadow-md">
            <div className="w-12 h-12 rounded-lg flex items-center justify-center mb-4" style={{ backgroundColor: '#f0f9f6' }}>
              <svg className="w-6 h-6" style={{ color: '#005440' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Multi-Corpus Access</h3>
            <p className="text-gray-600">
              Query across multiple knowledge bases including AI Books, Design Docs, and Management Resources simultaneously.
            </p>
          </div>

          {/* Feature 2 */}
          <div className="bg-white p-6 rounded-lg shadow-md">
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mb-4">
              <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Parallel Execution</h3>
            <p className="text-gray-600">
              Multi-agent architecture executes queries in parallel for faster, more comprehensive results.
            </p>
          </div>

          {/* Feature 3 */}
          <div className="bg-white p-6 rounded-lg shadow-md">
            <div className="w-12 h-12 rounded-lg flex items-center justify-center mb-4" style={{ backgroundColor: '#f0f9f6' }}>
              <svg className="w-6 h-6" style={{ color: '#005440' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Secure Access Control</h3>
            <p className="text-gray-600">
              Organization-restricted access with OAuth authentication and granular corpus-level permissions.
            </p>
          </div>

          {/* Feature 4 */}
          <div className="bg-white p-6 rounded-lg shadow-md">
            <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center mb-4">
              <svg className="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Conversation History</h3>
            <p className="text-gray-600">
              Persistent chat history and session management. Pick up where you left off across devices.
            </p>
          </div>
        </div>

        {/* Key Benefits Section */}
        <div className="mt-20 bg-white rounded-lg shadow-lg p-10">
          <h2 className="text-3xl font-bold text-gray-900 mb-6 text-center">
            Built for Enterprise Knowledge Workers
          </h2>
          <div className="grid md:grid-cols-3 gap-8">
            <div className="text-center">
              <div className="text-4xl font-bold mb-2" style={{ color: '#005440' }}>4+</div>
              <div className="text-gray-600">Knowledge Bases</div>
            </div>
            <div className="text-center">
              <div className="text-4xl font-bold mb-2" style={{ color: '#005440' }}>Multi-Agent</div>
              <div className="text-gray-600">Architecture</div>
            </div>
            <div className="text-center">
              <div className="text-4xl font-bold mb-2" style={{ color: '#005440' }}>Secure</div>
              <div className="text-gray-600">OAuth Protected</div>
            </div>
          </div>
        </div>

        {/* CTA Section */}
        <div className="mt-20 text-center">
          <h2 className="text-3xl font-bold text-gray-900 mb-4">
            Ready to get started?
          </h2>
          <p className="text-xl text-gray-600 mb-8">
            Sign in with your organization account to access all features.
          </p>
          <button
            onClick={() => setShowLogin(true)}
            className="px-8 py-4 text-white text-lg font-semibold rounded-lg transition-colors shadow-lg"
            style={{ backgroundColor: '#005440' }}
            onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#004030'}
            onMouseLeave={(e) => e.currentTarget.style.backgroundColor = '#005440'}
          >
            Sign In with Google →
          </button>
        </div>
      </div>

      {/* Footer */}
      <footer className="bg-white border-t border-gray-200 mt-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex justify-between items-center text-sm text-gray-500">
            <div>© 2026 ADK Multi-Agent RAG. All rights reserved.</div>
            <div className="flex space-x-6">
              <a href="#" className="hover:text-gray-700">Documentation</a>
              <a href="#" className="hover:text-gray-700">Support</a>
              <a href="#" className="hover:text-gray-700">Privacy</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
