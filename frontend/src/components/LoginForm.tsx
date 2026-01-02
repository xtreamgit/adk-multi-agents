"use client";

import { useState } from 'react';
import { User, apiClient } from '../lib/api-enhanced';
import Image from 'next/image';

interface LoginFormProps {
  onLoginSuccess: (user: User) => void;
}

export default function LoginForm({ onLoginSuccess }: LoginFormProps) {
  const [isLogin, setIsLogin] = useState(true);
  const [formData, setFormData] = useState({
    username: '',
    password: '',
    full_name: '',
    email: ''
  });
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData(prev => ({
      ...prev,
      [e.target.name]: e.target.value
    }));
    setError(''); // Clear error when user types
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    try {
      if (isLogin) {
        // Login flow
        const authToken = await apiClient.login({
          username: formData.username,
          password: formData.password
        });
        onLoginSuccess(authToken.user);
      } else {
        // Registration flow
        await apiClient.register({
          username: formData.username,
          password: formData.password,
          full_name: formData.full_name,
          email: formData.email
        });
        
        // Auto-login after registration
        const authToken = await apiClient.login({
          username: formData.username,
          password: formData.password
        });
        onLoginSuccess(authToken.user);
      }
    } catch (err: any) {
      setError(err.message || 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  const toggleMode = () => {
    setIsLogin(!isLogin);
    setError('');
    setFormData({
      username: '',
      password: '',
      full_name: '',
      email: ''
    });
  };

  return (
    <div className="bg-white dark:bg-gray-800 p-8 rounded-lg shadow-lg w-full max-w-md">
      {/* Logo and Title */}
      <div className="text-center mb-8">
        <div className="flex justify-center mb-4">
          <Image 
            src="/fs-logo.svg" 
            alt="USFS Logo" 
            width={60} 
            height={60}
            className="rounded"
          />
        </div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
          USFS-RAG
        </h1>
        <p className="text-gray-600 dark:text-gray-400">
          {isLogin ? 'Sign in to your account' : 'Create a new account'}
        </p>
      </div>

      {/* Error Message */}
      {error && (
        <div className="mb-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded-lg">
          {error}
        </div>
      )}

      {/* Form */}
      <form onSubmit={handleSubmit} className="space-y-4">
        {!isLogin && (
          <>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Full Name
              </label>
              <input
                type="text"
                name="full_name"
                value={formData.full_name}
                onChange={handleInputChange}
                required={!isLogin}
                className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 dark:bg-gray-700 dark:text-white"
                placeholder="Enter your full name"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Email
              </label>
              <input
                type="email"
                name="email"
                value={formData.email}
                onChange={handleInputChange}
                required={!isLogin}
                className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 dark:bg-gray-700 dark:text-white"
                placeholder="Enter your email"
              />
            </div>
          </>
        )}
        
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Username
          </label>
          <input
            type="text"
            name="username"
            value={formData.username}
            onChange={handleInputChange}
            required
            className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 dark:bg-gray-700 dark:text-white"
            placeholder="Enter your username"
          />
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Password
          </label>
          <input
            type="password"
            name="password"
            value={formData.password}
            onChange={handleInputChange}
            required
            className="w-full p-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 dark:bg-gray-700 dark:text-white"
            placeholder="Enter your password"
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          className="w-full bg-green-600 text-white py-3 px-4 rounded-lg hover:bg-green-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isLoading ? (
            <div className="flex items-center justify-center">
              <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
              {isLogin ? 'Signing in...' : 'Creating account...'}
            </div>
          ) : (
            isLogin ? 'Sign In' : 'Create Account'
          )}
        </button>
      </form>

      {/* Toggle Mode */}
      <div className="mt-6 text-center">
        <p className="text-gray-600 dark:text-gray-400">
          {isLogin ? "Don't have an account?" : "Already have an account?"}
          <button
            type="button"
            onClick={toggleMode}
            className="ml-2 text-green-600 hover:text-green-700 font-medium"
          >
            {isLogin ? 'Sign up' : 'Sign in'}
          </button>
        </p>
      </div>
    </div>
  );
}
