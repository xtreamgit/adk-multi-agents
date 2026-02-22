'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { apiClient } from '@/lib/api-enhanced';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
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

      // Check admin access by hitting the admin corpora endpoint directly.
      // The backend enforces admin via require_admin dependency — a 200 means access granted.
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL || ''}/api/admin/corpora`,
        { credentials: 'include', headers: { 'Content-Type': 'application/json' } }
      );
      setIsAdmin(response.ok);
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

  return <>{children}</>;
}
