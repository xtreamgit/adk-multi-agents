'use client';

import { useState, useEffect } from 'react';
import { Check, Info, RefreshCw } from 'lucide-react';

interface User {
  chatbot_user_id: number;
  email: string;
  full_name: string;
  chatbot_group_name: string;
  chatbot_group_id: number;
}

interface Agent {
  id: number;
  name: string;
  display_name: string;
  description: string;
}

interface Corpus {
  id: number;
  name: string;
  display_name: string;
  description: string;
}

interface AccessMatrixData {
  users: User[];
  agents: Agent[];
  corpora: Corpus[];
  agent_assignments: Record<number, number>; // chatbot_user_id -> agent_id
  corpus_access: Record<number, number[]>; // chatbot_user_id -> corpus_ids[]
}

export default function AccessMatrixPage() {
  const [data, setData] = useState<AccessMatrixData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await fetch('http://localhost:8000/api/admin/access-matrix', {
        credentials: 'include',
      });
      
      if (!response.ok) {
        throw new Error(`Failed to load access matrix: ${response.statusText}`);
      }
      
      const result = await response.json();
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load access matrix');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading access matrix...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <p className="text-red-600 mb-4">{error}</p>
          <button
            onClick={loadData}
            className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  if (!data) {
    return null;
  }

  const hasAgentAccess = (userId: number, agentId: number): boolean => {
    return data.agent_assignments[userId] === agentId;
  };

  const hasCorpusAccess = (userId: number, corpusId: number): boolean => {
    return data.corpus_access[userId]?.includes(corpusId) || false;
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-[1600px] mx-auto">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Access Matrix</h1>
              <p className="text-gray-600 mt-1">
                View agent assignments and corpus access for all chatbot users
              </p>
            </div>
            <button
              onClick={loadData}
              className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
            >
              <RefreshCw className="w-4 h-4" />
              Refresh
            </button>
          </div>
          
          <div className="bg-blue-50 border-l-4 border-blue-400 p-4">
            <div className="flex">
              <Info className="h-5 w-5 text-blue-400 mr-3 flex-shrink-0 mt-0.5" />
              <div className="text-sm text-blue-700">
                <p className="font-medium mb-1">Read-Only View</p>
                <p>
                  Access is managed through Google Workspace Groups and synced via the Google Groups Bridge.
                  To modify access, update group memberships in Google Workspace Admin Console.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Agent Assignments Matrix */}
        <div className="bg-white rounded-lg shadow-lg p-6 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">Agent Assignments</h2>
          <p className="text-gray-600 mb-6">
            Shows which agent each user is assigned to based on their chatbot group membership.
          </p>
          
          <div className="overflow-x-auto">
            <table className="w-full border-collapse">
              <thead>
                <tr>
                  <th className="border border-gray-300 bg-gray-100 p-3 text-left font-semibold text-gray-900 sticky left-0 z-10">
                    Agent
                  </th>
                  {data.users.map((user) => (
                    <th
                      key={user.chatbot_user_id}
                      className="border border-gray-300 bg-gray-100 p-3 text-center font-medium text-gray-900 min-w-[120px]"
                    >
                      <div className="text-sm">{user.full_name || user.email}</div>
                      <div className="text-xs text-gray-500 mt-1">{user.chatbot_group_name}</div>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {data.agents.map((agent) => (
                  <tr key={agent.id}>
                    <td className="border border-gray-300 p-3 font-medium text-gray-900 bg-gray-50 sticky left-0 z-10">
                      <div>{agent.display_name}</div>
                      <div className="text-xs text-gray-500 mt-1">{agent.name}</div>
                    </td>
                    {data.users.map((user) => (
                      <td
                        key={user.chatbot_user_id}
                        className="border border-gray-300 p-3 text-center"
                      >
                        {hasAgentAccess(user.chatbot_user_id, agent.id) && (
                          <Check className="w-5 h-5 text-green-600 mx-auto" />
                        )}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          
          {data.agents.length === 0 && (
            <p className="text-gray-500 text-center py-8">No agents available</p>
          )}
        </div>

        {/* Corpus Access Matrix */}
        <div className="bg-white rounded-lg shadow-lg p-6">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">Corpus Access</h2>
          <p className="text-gray-600 mb-6">
            Shows which corpora each user has access to based on their chatbot group membership.
          </p>
          
          <div className="overflow-x-auto">
            <table className="w-full border-collapse">
              <thead>
                <tr>
                  <th className="border border-gray-300 bg-gray-100 p-3 text-left font-semibold text-gray-900 sticky left-0 z-10">
                    Corpus
                  </th>
                  {data.users.map((user) => (
                    <th
                      key={user.chatbot_user_id}
                      className="border border-gray-300 bg-gray-100 p-3 text-center font-medium text-gray-900 min-w-[120px]"
                    >
                      <div className="text-sm">{user.full_name || user.email}</div>
                      <div className="text-xs text-gray-500 mt-1">{user.chatbot_group_name}</div>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {data.corpora.map((corpus) => (
                  <tr key={corpus.id}>
                    <td className="border border-gray-300 p-3 font-medium text-gray-900 bg-gray-50 sticky left-0 z-10">
                      <div>{corpus.display_name}</div>
                      <div className="text-xs text-gray-500 mt-1">{corpus.name}</div>
                    </td>
                    {data.users.map((user) => (
                      <td
                        key={user.chatbot_user_id}
                        className="border border-gray-300 p-3 text-center"
                      >
                        {hasCorpusAccess(user.chatbot_user_id, corpus.id) && (
                          <Check className="w-5 h-5 text-green-600 mx-auto" />
                        )}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          
          {data.corpora.length === 0 && (
            <p className="text-gray-500 text-center py-8">No corpora available</p>
          )}
        </div>

        {/* Summary Stats */}
        <div className="mt-8 grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-2xl font-bold text-gray-900">{data.users.length}</div>
            <div className="text-gray-600">Active Chatbot Users</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-2xl font-bold text-gray-900">{data.agents.length}</div>
            <div className="text-gray-600">Available Agents</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-2xl font-bold text-gray-900">{data.corpora.length}</div>
            <div className="text-gray-600">Active Corpora</div>
          </div>
        </div>
      </div>
    </div>
  );
}
