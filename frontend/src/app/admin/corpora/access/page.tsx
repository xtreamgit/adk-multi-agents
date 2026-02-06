'use client';

import { useState, useEffect } from 'react';

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || '';

interface Corpus {
  id: number;
  name: string;
  display_name: string;
  description: string | null;
  is_active: boolean;
}

interface ChatbotGroup {
  id: number;
  name: string;
}

interface CorpusAccess {
  id: number;
  chatbot_group_id: number;
  group_name: string;
  corpus_id: number;
  corpus_name: string;
  corpus_display_name: string;
  permission: string;
  granted_at: string;
}

export default function CorporaGroupAccessPage() {
  const [corpora, setCorpora] = useState<Corpus[]>([]);
  const [groups, setGroups] = useState<ChatbotGroup[]>([]);
  const [access, setAccess] = useState<CorpusAccess[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const targetGroups = ['admin-group', 'content-manager-group', 'contributor-group', 'viewer-group'];

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const [corporaData, groupsData, accessData] = await Promise.all([
        fetch(`${BACKEND_URL}/api/admin/chatbot/available-corpora`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` }
        }).then(r => r.json()),
        fetch(`${BACKEND_URL}/api/admin/chatbot/groups`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` }
        }).then(r => r.json()),
        fetch(`${BACKEND_URL}/api/admin/chatbot/corpus-access`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` }
        }).then(r => r.json()),
      ]);
      setCorpora(corporaData);
      setGroups(groupsData);
      setAccess(accessData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const hasAccess = (corpusId: number, groupName: string): boolean => {
    return access.some(a => a.corpus_id === corpusId && a.group_name === groupName);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen text-red-600">
        {error}
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Corpora to Group Access</h1>
        <p className="text-gray-600">View corpus access permissions across chatbot groups</p>
      </div>

      {/* Legend */}
      <div className="mb-6 bg-white rounded-lg shadow p-4">
        <h3 className="text-sm font-semibold text-gray-700 mb-3">Legend</h3>
        <div className="flex gap-6">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-emerald-700 rounded flex items-center justify-center">
              <span className="text-white text-sm">✓</span>
            </div>
            <span className="text-sm text-gray-700">Has Access</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-gray-200 rounded"></div>
            <span className="text-sm text-gray-700">No Access</span>
          </div>
        </div>
      </div>

      {/* Access Matrix Table */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-4 text-left text-sm font-semibold text-gray-700 sticky left-0 bg-gray-50 z-10">
                  Corpus
                </th>
                {targetGroups.map(groupName => (
                  <th key={groupName} className="px-6 py-4 text-center text-sm font-semibold text-gray-700">
                    {groupName}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {corpora.length === 0 ? (
                <tr>
                  <td colSpan={targetGroups.length + 1} className="px-6 py-8 text-center text-gray-500">
                    No corpora available
                  </td>
                </tr>
              ) : (
                corpora.map((corpus) => (
                  <tr key={corpus.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 sticky left-0 bg-white z-10">
                      <div>
                        <div className="text-sm font-semibold text-gray-900">
                          {corpus.display_name || corpus.name}
                        </div>
                        <div className="text-xs text-gray-500">{corpus.name}</div>
                      </div>
                    </td>
                    {targetGroups.map(groupName => {
                      const hasGroupAccess = hasAccess(corpus.id, groupName);
                      return (
                        <td key={groupName} className="px-6 py-4 text-center">
                          <div className="flex justify-center">
                            {hasGroupAccess ? (
                              <div className="w-10 h-10 bg-emerald-700 rounded flex items-center justify-center">
                                <span className="text-white font-bold">✓</span>
                              </div>
                            ) : (
                              <div className="w-10 h-10 bg-gray-200 rounded"></div>
                            )}
                          </div>
                        </td>
                      );
                    })}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
