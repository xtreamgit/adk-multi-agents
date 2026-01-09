'use client';

import { useState, useEffect } from 'react';
import { apiClient } from '@/lib/api-enhanced';

interface Group {
  id: number;
  name: string;
  description?: string;
}

interface User {
  id: number;
  username: string;
  email: string;
  full_name: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  last_login: string | null;
  groups: Group[];
}

interface AllGroup {
  id: number;
  name: string;
  description: string | null;
  created_at: string;
}

export default function AdminUsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [allGroups, setAllGroups] = useState<AllGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showEditDialog, setShowEditDialog] = useState(false);
  const [showGroupDialog, setShowGroupDialog] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [createForm, setCreateForm] = useState({
    username: '',
    email: '',
    full_name: '',
    password: '',
    group_ids: [] as number[],
  });
  const [editForm, setEditForm] = useState({
    email: '',
    full_name: '',
    is_active: true,
    password: '',
  });

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const [usersData, groupsData] = await Promise.all([
        apiClient.admin_getAllUsers(),
        apiClient.getAllGroups(),
      ]);
      setUsers(usersData);
      setAllGroups(groupsData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateUser = async () => {
    if (!createForm.username || !createForm.email || !createForm.full_name || !createForm.password) {
      alert('Please fill in all required fields');
      return;
    }

    try {
      await apiClient.admin_createUser(createForm);
      setShowCreateDialog(false);
      setCreateForm({
        username: '',
        email: '',
        full_name: '',
        password: '',
        group_ids: [],
      });
      await loadData();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('Create user error:', err);
      alert(`Failed to create user: ${errorMessage}`);
    }
  };

  const handleEditUser = async () => {
    if (!selectedUser) return;

    try {
      const updates: any = {};
      if (editForm.email && editForm.email !== selectedUser.email) {
        updates.email = editForm.email;
      }
      if (editForm.full_name && editForm.full_name !== selectedUser.full_name) {
        updates.full_name = editForm.full_name;
      }
      if (editForm.is_active !== selectedUser.is_active) {
        updates.is_active = editForm.is_active;
      }
      if (editForm.password) {
        updates.password = editForm.password;
      }

      if (Object.keys(updates).length > 0) {
        await apiClient.admin_updateUser(selectedUser.id, updates);
      }

      setShowEditDialog(false);
      setSelectedUser(null);
      await loadData();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('Update user error:', err);
      alert(`Failed to update user: ${errorMessage}`);
    }
  };

  const handleDeleteUser = async (userId: number, username: string) => {
    if (!confirm(`Are you sure you want to deactivate user "${username}"?`)) {
      return;
    }

    try {
      await apiClient.admin_deleteUser(userId);
      await loadData();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('Delete user error:', err);
      alert(`Failed to delete user: ${errorMessage}`);
    }
  };

  const handleAssignGroup = async (groupId: number) => {
    if (!selectedUser) return;

    try {
      await apiClient.admin_assignUserToGroup(selectedUser.id, groupId);
      await loadData();
      const updatedUser = users.find(u => u.id === selectedUser.id);
      if (updatedUser) {
        setSelectedUser(updatedUser);
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('Assign group error:', err);
      alert(`Failed to assign group: ${errorMessage}`);
    }
  };

  const handleRemoveGroup = async (groupId: number) => {
    if (!selectedUser) return;

    if (!confirm('Remove user from this group?')) {
      return;
    }

    try {
      await apiClient.admin_removeUserFromGroup(selectedUser.id, groupId);
      await loadData();
      const updatedUser = users.find(u => u.id === selectedUser.id);
      if (updatedUser) {
        setSelectedUser(updatedUser);
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('Remove group error:', err);
      alert(`Failed to remove group: ${errorMessage}`);
    }
  };

  const openEditDialog = (user: User) => {
    setSelectedUser(user);
    setEditForm({
      email: user.email,
      full_name: user.full_name,
      is_active: user.is_active,
      password: '',
    });
    setShowEditDialog(true);
  };

  const openGroupDialog = (user: User) => {
    setSelectedUser(user);
    setShowGroupDialog(true);
  };

  const formatDate = (dateString: string | null) => {
    if (!dateString) return 'Never';
    return new Date(dateString).toLocaleString();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading users...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="text-red-600 text-xl mb-4">Error</div>
          <p className="text-gray-600 mb-4">{error}</p>
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

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">User Management</h1>
          <p className="text-gray-600">Manage users and their group memberships</p>
        </div>
        <button
          onClick={() => setShowCreateDialog(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
        >
          + Create User
        </button>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Username
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Full Name
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Email
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Groups
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Last Login
              </th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {users.map((user) => (
              <tr key={user.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {user.username}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {user.full_name}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {user.email}
                </td>
                <td className="px-6 py-4 text-sm text-gray-900">
                  <div className="flex flex-wrap gap-1">
                    {user.groups.map((group) => (
                      <span
                        key={group.id}
                        className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
                      >
                        {group.name}
                      </span>
                    ))}
                    {user.groups.length === 0 && (
                      <span className="text-gray-400 italic">No groups</span>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span
                    className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                      user.is_active
                        ? 'bg-green-100 text-green-800'
                        : 'bg-red-100 text-red-800'
                    }`}
                  >
                    {user.is_active ? 'Active' : 'Inactive'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatDate(user.last_login)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button
                    onClick={() => openGroupDialog(user)}
                    className="text-blue-600 hover:text-blue-900 mr-3"
                  >
                    Groups
                  </button>
                  <button
                    onClick={() => openEditDialog(user)}
                    className="text-indigo-600 hover:text-indigo-900 mr-3"
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => handleDeleteUser(user.id, user.username)}
                    className="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Create User Dialog */}
      {showCreateDialog && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">Create New User</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Username *
                </label>
                <input
                  type="text"
                  value={createForm.username}
                  onChange={(e) => setCreateForm({ ...createForm, username: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email *
                </label>
                <input
                  type="email"
                  value={createForm.email}
                  onChange={(e) => setCreateForm({ ...createForm, email: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Full Name *
                </label>
                <input
                  type="text"
                  value={createForm.full_name}
                  onChange={(e) => setCreateForm({ ...createForm, full_name: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Password *
                </label>
                <input
                  type="password"
                  value={createForm.password}
                  onChange={(e) => setCreateForm({ ...createForm, password: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Initial Groups (optional)
                </label>
                <select
                  multiple
                  value={createForm.group_ids.map(String)}
                  onChange={(e) => {
                    const selected = Array.from(e.target.selectedOptions, option => parseInt(option.value));
                    setCreateForm({ ...createForm, group_ids: selected });
                  }}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md"
                  size={4}
                >
                  {allGroups.map((group) => (
                    <option key={group.id} value={group.id}>
                      {group.name}
                    </option>
                  ))}
                </select>
                <p className="text-xs text-gray-500 mt-1">Hold Ctrl/Cmd to select multiple</p>
              </div>
            </div>
            <div className="flex justify-end gap-2 mt-6">
              <button
                onClick={() => setShowCreateDialog(false)}
                className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded"
              >
                Cancel
              </button>
              <button
                onClick={handleCreateUser}
                className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
              >
                Create User
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit User Dialog */}
      {showEditDialog && selectedUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">Edit User: {selectedUser.username}</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input
                  type="email"
                  value={editForm.email}
                  onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                <input
                  type="text"
                  value={editForm.full_name}
                  onChange={(e) => setEditForm({ ...editForm, full_name: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  New Password (leave blank to keep current)
                </label>
                <input
                  type="password"
                  value={editForm.password}
                  onChange={(e) => setEditForm({ ...editForm, password: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md"
                />
              </div>
              <div className="flex items-center">
                <input
                  type="checkbox"
                  checked={editForm.is_active}
                  onChange={(e) => setEditForm({ ...editForm, is_active: e.target.checked })}
                  className="mr-2"
                />
                <label className="text-sm font-medium text-gray-700">Active</label>
              </div>
            </div>
            <div className="flex justify-end gap-2 mt-6">
              <button
                onClick={() => setShowEditDialog(false)}
                className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded"
              >
                Cancel
              </button>
              <button
                onClick={handleEditUser}
                className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Group Management Dialog */}
      {showGroupDialog && selectedUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-2xl">
            <h2 className="text-xl font-bold mb-4">
              Manage Groups: {selectedUser.username}
            </h2>
            
            <div className="grid grid-cols-2 gap-6">
              {/* Current Groups */}
              <div>
                <h3 className="font-semibold mb-2">Current Groups</h3>
                <div className="space-y-2">
                  {selectedUser.groups.length === 0 ? (
                    <p className="text-gray-400 italic">No groups assigned</p>
                  ) : (
                    selectedUser.groups.map((group) => (
                      <div
                        key={group.id}
                        className="flex items-center justify-between p-2 bg-gray-50 rounded"
                      >
                        <span>{group.name}</span>
                        <button
                          onClick={() => handleRemoveGroup(group.id)}
                          className="text-red-600 hover:text-red-800 text-sm"
                        >
                          Remove
                        </button>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Available Groups */}
              <div>
                <h3 className="font-semibold mb-2">Available Groups</h3>
                <div className="space-y-2">
                  {allGroups
                    .filter((g) => !selectedUser.groups.find((ug) => ug.id === g.id))
                    .map((group) => (
                      <div
                        key={group.id}
                        className="flex items-center justify-between p-2 bg-gray-50 rounded"
                      >
                        <span>{group.name}</span>
                        <button
                          onClick={() => handleAssignGroup(group.id)}
                          className="text-blue-600 hover:text-blue-800 text-sm"
                        >
                          Add
                        </button>
                      </div>
                    ))}
                  {allGroups.filter((g) => !selectedUser.groups.find((ug) => ug.id === g.id))
                    .length === 0 && (
                    <p className="text-gray-400 italic">All groups assigned</p>
                  )}
                </div>
              </div>
            </div>

            <div className="flex justify-end mt-6">
              <button
                onClick={() => setShowGroupDialog(false)}
                className="px-4 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
