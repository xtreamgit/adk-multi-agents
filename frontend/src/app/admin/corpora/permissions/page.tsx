'use client';

import { useState, useEffect } from 'react';
import { apiClient } from '@/lib/api-enhanced';

interface Group {
  id: number;
  name: string;
  description: string | null;
}

interface Corpus {
  id: number;
  name: string;
  display_name: string;
  is_active: boolean;
  groups_with_access: Array<{
    group_id: number;
    group_name: string;
    permission: string;
  }>;
}

export default function PermissionsMatrixPage() {
  const [corpora, setCorpora] = useState<Corpus[]>([]);
  const [groups, setGroups] = useState<Group[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [updating, setUpdating] = useState<string | null>(null);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const [corporaData, groupsData] = await Promise.all([
        apiClient.admin_getAllCorpora(false),
        apiClient.getAllGroups(),
      ]);
      setCorpora(corporaData);
      setGroups(groupsData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const hasAccess = (corpusId: number, groupId: number): boolean => {
    const corpus = corpora.find(c => c.id === corpusId);
    return corpus?.groups_with_access.some(g => g.group_id === groupId) || false;
  };

  const getPermission = (corpusId: number, groupId: number): string | null => {
    const corpus = corpora.find(c => c.id === corpusId);
    const access = corpus?.groups_with_access.find(g => g.group_id === groupId);
    return access?.permission || null;
  };

  const togglePermission = async (corpusId: number, groupId: number) => {
    const key = `${corpusId}-${groupId}`;
    setUpdating(key);
    
    try {
      const currentlyHasAccess = hasAccess(corpusId, groupId);
      
      if (currentlyHasAccess) {
        await apiClient.admin_revokePermission(corpusId, groupId);
      } else {
        await apiClient.admin_grantPermission(corpusId, groupId, 'read');
      }
      
      await loadData();
    } catch (err) {
      alert(`Failed to update permission: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setUpdating(null);
    }
  };

  if (loading) {
    return (
      <div className="p-8">
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Permission Matrix</h1>
        <p className="text-gray-600 mt-1">
          Manage which groups have access to which corpora. Click cells to toggle access.
        </p>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      {/* Legend */}
      <div className="bg-white rounded-lg shadow p-4 mb-6">
        <h3 className="font-semibold text-gray-900 mb-3">Legend</h3>
        <div className="flex space-x-6 text-sm">
          <div className="flex items-center">
            <div className="w-8 h-8 rounded bg-green-500 mr-2"></div>
            <span>Has Access</span>
          </div>
          <div className="flex items-center">
            <div className="w-8 h-8 rounded bg-gray-200 mr-2"></div>
            <span>No Access</span>
          </div>
        </div>
      </div>

      {/* Permission Matrix */}
      <div className="bg-white rounded-lg shadow overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr className="bg-gray-100 border-b">
              <th className="p-3 text-left font-semibold text-gray-700 sticky left-0 bg-gray-100 min-w-[200px]">
                Corpus
              </th>
              {groups.map((group) => (
                <th
                  key={group.id}
                  className="p-3 text-center font-semibold text-gray-700 min-w-[120px]"
                  title={group.description || undefined}
                >
                  <div className="text-sm">{group.name}</div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {corpora.map((corpus, idx) => (
              <tr key={corpus.id} className={idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                <td className="p-3 font-medium text-gray-900 sticky left-0 bg-inherit border-r">
                  <div className="flex items-center">
                    <div>
                      <div className="font-semibold">{corpus.display_name}</div>
                      <div className="text-xs text-gray-500">{corpus.name}</div>
                    </div>
                  </div>
                </td>
                {groups.map((group) => {
                  const access = hasAccess(corpus.id, group.id);
                  const permission = getPermission(corpus.id, group.id);
                  const key = `${corpus.id}-${group.id}`;
                  const isUpdating = updating === key;

                  return (
                    <td key={group.id} className="p-3 text-center">
                      <button
                        onClick={() => togglePermission(corpus.id, group.id)}
                        disabled={isUpdating}
                        className={`w-10 h-10 rounded transition-colors ${
                          access
                            ? 'bg-green-500 text-white hover:bg-green-600'
                            : 'bg-gray-200 text-gray-500 hover:bg-gray-300'
                        } ${isUpdating ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
                        title={access ? `${permission} access` : 'No access'}
                      >
                        {isUpdating ? (
                          <span className="animate-spin">⟳</span>
                        ) : access ? (
                          '✓'
                        ) : (
                          ''
                        )}
                      </button>
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>

        {corpora.length === 0 && (
          <div className="text-center py-12 text-gray-500">
            No active corpora found.
          </div>
        )}
      </div>

      {/* Summary */}
      <div className="mt-6 bg-white rounded-lg shadow p-6">
        <h3 className="font-semibold text-gray-900 mb-4">Access Summary</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-blue-600">{corpora.length}</div>
            <div className="text-sm text-gray-600">Active Corpora</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-purple-600">{groups.length}</div>
            <div className="text-sm text-gray-600">Groups</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-green-600">
              {corpora.reduce((sum, c) => sum + c.groups_with_access.length, 0)}
            </div>
            <div className="text-sm text-gray-600">Total Permissions</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-orange-600">
              {corpora.length * groups.length}
            </div>
            <div className="text-sm text-gray-600">Possible Combinations</div>
          </div>
        </div>
      </div>
    </div>
  );
}
