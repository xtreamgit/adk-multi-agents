'use client';

import { useState, useEffect } from 'react';

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || '';

interface Agent { id: number; name: string; display_name: string; description: string | null; is_active: boolean; }
interface ChatbotGroup { id: number; name: string; }
interface AgentAccess { id: number; chatbot_group_id: number; group_name: string; agent_id: number; agent_name: string; agent_display_name: string; can_use: boolean; can_configure: boolean; granted_at: string; }

export default function ChatbotAgentsPage() {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [groups, setGroups] = useState<ChatbotGroup[]>([]);
  const [access, setAccess] = useState<AgentAccess[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showGrantDialog, setShowGrantDialog] = useState(false);
  const [selectedAgent, setSelectedAgent] = useState<Agent | null>(null);
  const [grantForm, setGrantForm] = useState({ chatbot_group_id: 0, can_use: true, can_configure: false });

  useEffect(() => { loadData(); }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const [agentsData, groupsData, accessData] = await Promise.all([
        fetch(`${BACKEND_URL}/api/admin/chatbot/available-agents`, { headers: { 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` } }).then(r => r.json()),
        fetch(`${BACKEND_URL}/api/admin/chatbot/groups`, { headers: { 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` } }).then(r => r.json()),
        fetch(`${BACKEND_URL}/api/admin/chatbot/agent-access`, { headers: { 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` } }).then(r => r.json()),
      ]);
      setAgents(agentsData);
      setGroups(groupsData);
      setAccess(accessData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load');
    } finally {
      setLoading(false);
    }
  };

  const handleGrant = async () => {
    if (!selectedAgent || !grantForm.chatbot_group_id) { alert('Select a group'); return; }
    try {
      await fetch(`${BACKEND_URL}/api/admin/chatbot/agent-access`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` },
        body: JSON.stringify({ chatbot_group_id: grantForm.chatbot_group_id, agent_id: selectedAgent.id, can_use: grantForm.can_use, can_configure: grantForm.can_configure }),
      });
      setShowGrantDialog(false);
      await loadData();
    } catch { alert('Failed'); }
  };

  const handleRevoke = async (groupId: number, agentId: number) => {
    if (!confirm('Revoke access?')) return;
    try {
      await fetch(`${BACKEND_URL}/api/admin/chatbot/agent-access/${groupId}/${agentId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` },
      });
      await loadData();
    } catch { alert('Failed'); }
  };

  const openGrantDialog = (agent: Agent) => {
    setSelectedAgent(agent);
    setGrantForm({ chatbot_group_id: 0, can_use: true, can_configure: false });
    setShowGrantDialog(true);
  };

  const getAgentAccess = (agentId: number) => access.filter(a => a.agent_id === agentId);

  if (loading) return <div className="flex items-center justify-center min-h-screen"><div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div></div>;
  if (error) return <div className="flex items-center justify-center min-h-screen text-red-600">{error}</div>;

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Chatbot Agent Access</h1>
        <p className="text-gray-600">Manage which chatbot groups can use which agents</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {agents.length === 0 ? (
          <div className="col-span-full bg-white rounded-lg shadow p-8 text-center text-gray-500">No agents available.</div>
        ) : agents.map((agent) => {
          const agentAccess = getAgentAccess(agent.id);
          return (
            <div key={agent.id} className="bg-white rounded-lg shadow overflow-hidden">
              <div className="px-6 py-4 bg-green-50 border-b flex justify-between items-start">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900">🤖 {agent.display_name || agent.name}</h3>
                  <p className="text-sm text-gray-500">{agent.name}</p>
                </div>
                <button onClick={() => openGrantDialog(agent)} className="text-green-600 hover:text-green-800 text-sm font-medium">+ Grant</button>
              </div>
              <div className="p-4">
                <div className="text-xs text-gray-500 uppercase font-medium mb-2">Access ({agentAccess.length})</div>
                {agentAccess.length === 0 ? (
                  <p className="text-gray-400 italic text-sm">No access granted</p>
                ) : (
                  <div className="space-y-2">
                    {agentAccess.map((a) => (
                      <div key={a.id} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                        <div>
                          <span className="font-medium text-sm">{a.group_name}</span>
                          <div className="flex gap-1 mt-1">
                            {a.can_use && <span className="px-2 py-0.5 rounded text-xs bg-green-100 text-green-800">Use</span>}
                            {a.can_configure && <span className="px-2 py-0.5 rounded text-xs bg-purple-100 text-purple-800">Configure</span>}
                          </div>
                        </div>
                        <button onClick={() => handleRevoke(a.chatbot_group_id, a.agent_id)} className="text-red-600 hover:text-red-800 text-xs">Revoke</button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {showGrantDialog && selectedAgent && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">Grant Access: {selectedAgent.display_name || selectedAgent.name}</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">Group *</label>
                <select value={grantForm.chatbot_group_id} onChange={(e) => setGrantForm({...grantForm, chatbot_group_id: parseInt(e.target.value)})} className="w-full px-3 py-2 border rounded-md">
                  <option value={0}>Select...</option>
                  {groups.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}
                </select>
              </div>
              <div className="space-y-2">
                <label className="block text-sm font-medium">Permissions</label>
                <div className="flex items-center"><input type="checkbox" checked={grantForm.can_use} onChange={(e) => setGrantForm({...grantForm, can_use: e.target.checked})} className="mr-2" /><label className="text-sm">Can Use Agent</label></div>
                <div className="flex items-center"><input type="checkbox" checked={grantForm.can_configure} onChange={(e) => setGrantForm({...grantForm, can_configure: e.target.checked})} className="mr-2" /><label className="text-sm">Can Configure Agent</label></div>
              </div>
            </div>
            <div className="flex justify-end gap-2 mt-6">
              <button onClick={() => setShowGrantDialog(false)} className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded">Cancel</button>
              <button onClick={handleGrant} className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700">Grant</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
