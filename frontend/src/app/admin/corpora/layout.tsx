'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { apiClient } from '@/lib/api-enhanced';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkAdminAccess();
  }, []);

  const checkAdminAccess = async () => {
    try {
      if (!apiClient.isAuthenticated()) {
        setIsAdmin(false);
        setLoading(false);
        return;
      }

      const user = apiClient.getCurrentUser();
      if (user) {
        const groups = await apiClient.getUserGroups(user.id);
        const hasAdminAccess = groups.some((g: any) => g.name === 'admin-users');
        setIsAdmin(hasAdminAccess);
      }
    } catch (error) {
      console.error('Failed to check admin access:', error);
      setIsAdmin(false);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <h1 className="text-3xl font-bold text-gray-900 mb-4">Access Denied</h1>
          <p className="text-gray-600 mb-6">You do not have admin privileges to access this panel.</p>
          <Link
            href="/"
            className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 inline-block"
          >
            Back to Home
          </Link>
        </div>
      </div>
    );
  }

  const navItems = [
    { href: '/admin/corpora', label: 'Corpus Management', icon: '📚' },
    { href: '/admin/corpora/permissions', label: 'Permissions', icon: '🔐' },
    { href: '/admin/corpora/audit', label: 'Audit Log', icon: '📋' },
  ];

  return (
    <div className="min-h-screen flex bg-gray-50">
      {/* Sidebar */}
      <aside className="w-64 bg-gray-900 text-white flex-shrink-0">
        <div className="p-6">
          <h1 className="text-2xl font-bold">Admin Panel</h1>
          <p className="text-gray-400 text-sm mt-1">Corpus Management</p>
        </div>
        
        <nav className="mt-6">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`block px-6 py-3 text-sm transition-colors ${
                  isActive
                    ? 'bg-gray-800 text-white border-l-4 border-blue-500'
                    : 'text-gray-300 hover:bg-gray-800 hover:text-white border-l-4 border-transparent'
                }`}
              >
                <span className="mr-3">{item.icon}</span>
                {item.label}
              </Link>
            );
          })}
          
          <div className="mt-6 pt-6 border-t border-gray-800">
            <Link
              href="/"
              className="block px-6 py-3 text-sm text-gray-300 hover:bg-gray-800 hover:text-white border-l-4 border-transparent"
            >
              <span className="mr-3">←</span>
              Back to App
            </Link>
          </div>
        </nav>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-auto">
        {children}
      </main>
    </div>
  );
}
