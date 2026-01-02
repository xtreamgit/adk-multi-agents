"use client";

import { useState, useEffect } from 'react';
import { Agent, apiClient } from '../lib/api-enhanced';

interface AgentSwitcherProps {
  sessionId?: string | null;
  onAgentChange?: (agent: Agent) => void;
}

export default function AgentSwitcher({ sessionId, onAgentChange }: AgentSwitcherProps) {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [selectedAgent, setSelectedAgent] = useState<Agent | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadAgents();
  }, []);

  const loadAgents = async () => {
    try {
      const myAgents = await apiClient.getMyAgents();
      setAgents(myAgents);
      
      // Set the default agent
      const defaultAgent = myAgents.find(a => a.is_default);
      if (defaultAgent) {
        setSelectedAgent(defaultAgent);
        // Notify parent component of the default agent
        if (onAgentChange) {
          onAgentChange(defaultAgent);
        }
      } else if (myAgents.length > 0) {
        setSelectedAgent(myAgents[0]);
        // Notify parent component
        if (onAgentChange) {
          onAgentChange(myAgents[0]);
        }
      }
    } catch (err: any) {
      console.error('Failed to load agents:', err);
      setError(err.message);
    }
  };

  const handleAgentSwitch = async (agent: Agent) => {
    if (!sessionId) {
      setError('No active session. Please start a chat first.');
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      await apiClient.switchAgent(sessionId, agent.id);
      setSelectedAgent(agent);
      if (onAgentChange) {
        onAgentChange(agent);
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSetDefault = async (agent: Agent) => {
    try {
      await apiClient.setDefaultAgent(agent.id);
      // Reload agents to update the default flag
      await loadAgents();
    } catch (err: any) {
      setError(err.message);
    }
  };

  if (agents.length === 0) {
    return (
      <div className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-4">
        <p className="text-yellow-800 dark:text-yellow-200 text-sm">
          No agents available. Contact your administrator for access.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
          Select Agent
        </h3>
        {selectedAgent && (
          <span className="text-sm text-gray-600 dark:text-gray-400">
            Current: <span className="font-medium text-gray-900 dark:text-white">{selectedAgent.display_name}</span>
          </span>
        )}
      </div>

      {error && (
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-3">
          <p className="text-red-800 dark:text-red-200 text-sm">{error}</p>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        {agents.map((agent) => (
          <div
            key={agent.id}
            className={`
              relative border-2 rounded-lg p-4 cursor-pointer transition-all
              ${selectedAgent?.id === agent.id
                ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20'
                : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600'
              }
              ${isLoading ? 'opacity-50 cursor-not-allowed' : ''}
            `}
            onClick={() => !isLoading && handleAgentSwitch(agent)}
          >
            {agent.is_default && (
              <div className="absolute top-2 right-2">
                <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400">
                  Default
                </span>
              </div>
            )}

            <div className="space-y-2">
              <h4 className="font-medium text-gray-900 dark:text-white">
                {agent.display_name}
              </h4>
              <p className="text-sm text-gray-600 dark:text-gray-400 line-clamp-2">
                {agent.description}
              </p>
              
              {!agent.is_default && selectedAgent?.id === agent.id && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    handleSetDefault(agent);
                  }}
                  className="text-xs text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300"
                >
                  Set as default
                </button>
              )}
            </div>

            {selectedAgent?.id === agent.id && (
              <div className="absolute bottom-2 right-2">
                <svg className="w-5 h-5 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
              </div>
            )}
          </div>
        ))}
      </div>

      {agents.length > 0 && (
        <p className="text-xs text-gray-500 dark:text-gray-400">
          You have access to {agents.length} agent{agents.length !== 1 ? 's' : ''}. 
          Click an agent to switch, or set one as your default.
        </p>
      )}
    </div>
  );
}
