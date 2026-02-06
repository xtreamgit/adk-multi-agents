'use client';

import { useState, useEffect } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { Sidebar, Menu, MenuItem, SubMenu } from 'react-pro-sidebar';

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const [collapsed, setCollapsed] = useState(false);
  const [corporaMenuOpen, setCorporaMenuOpen] = useState(false);
  const [chatbotMenuOpen, setChatbotMenuOpen] = useState(false);
  const [appManagementMenuOpen, setAppManagementMenuOpen] = useState(false);
  
  const isActive = (path: string) => {
    if (path === '/admin') {
      return pathname === '/admin';
    }
    return pathname?.startsWith(path);
  };
  
  useEffect(() => {
    if (pathname?.startsWith('/admin/corpora')) {
      setCorporaMenuOpen(true);
    }
    if (pathname?.startsWith('/admin/chatbot')) {
      setChatbotMenuOpen(true);
    }
    // Open Application Management submenu for Dashboard, Users, Groups, Audit, Sessions
    if (pathname === '/admin' || 
        pathname?.startsWith('/admin/users') || 
        pathname?.startsWith('/admin/groups') ||
        pathname?.startsWith('/admin/audit') ||
        pathname?.startsWith('/admin/sessions')) {
      setAppManagementMenuOpen(true);
    }
  }, [pathname]);

  const handleMenuClick = (path: string) => {
    router.push(path);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="flex">
        {/* Sidebar */}
        <Sidebar
          collapsed={collapsed}
          width="280px"
          collapsedWidth="80px"
          backgroundColor="#ffffff"
          rootStyles={{
            borderRight: '1px solid #e5e7eb',
            minHeight: '100vh',
          }}
        >
          <div className="p-6 border-b border-gray-200">
            <h1 className="text-xl font-bold text-gray-900">
              {collapsed ? 'AP' : 'Admin Panel'}
            </h1>
            {!collapsed && (
              <p className="text-sm text-gray-500 mt-1">System Management</p>
            )}
          </div>

          <Menu
            menuItemStyles={{
              button: ({ level, active }) => {
                if (level === 0) {
                  return {
                    backgroundColor: 'transparent',
                    color: '#374151',
                    fontWeight: active ? '700' : '400',
                    padding: '12px 16px',
                    marginBottom: '4px',
                    borderRadius: '8px',
                    transition: 'all 0.3s ease',
                    '&:hover': {
                      backgroundColor: '#f3f4f6',
                      color: '#111827',
                    },
                  };
                }
                if (level === 1) {
                  return {
                    backgroundColor: 'transparent',
                    color: '#6b7280',
                    fontWeight: active ? '700' : '400',
                    padding: '10px 16px 10px 48px',
                    marginBottom: '2px',
                    borderRadius: '6px',
                    fontSize: '14px',
                    transition: 'all 0.2s ease',
                    '&:hover': {
                      backgroundColor: '#f9fafb',
                      color: '#374151',
                    },
                  };
                }
              },
              subMenuContent: {
                backgroundColor: '#fafafa',
                borderRadius: '8px',
                margin: '4px 8px',
                padding: '4px 0',
              },
            }}
          >
            {/* Chatbot Access SubMenu */}
            <SubMenu
              icon={<span className="text-xl">💬</span>}
              label="Chatbot Access"
              open={chatbotMenuOpen}
              onOpenChange={(open) => setChatbotMenuOpen(open)}
              rootStyles={{
                '& > .ps-menu-button': {
                  backgroundColor: 'transparent',
                  color: '#374151',
                  fontWeight: chatbotMenuOpen ? '700' : '400',
                },
              }}
            >
              <MenuItem
                icon={<span>👤</span>}
                active={isActive('/admin/chatbot-users')}
                onClick={() => handleMenuClick('/admin/chatbot-users')}
              >
                Chatbot Users
              </MenuItem>
              <MenuItem
                icon={<span>👥</span>}
                active={isActive('/admin/chatbot-groups')}
                onClick={() => handleMenuClick('/admin/chatbot-groups')}
              >
                Chatbot Groups
              </MenuItem>
              <MenuItem
                icon={<span>🎭</span>}
                active={isActive('/admin/agents')}
                onClick={() => handleMenuClick('/admin/agents')}
              >
                Agents
              </MenuItem>
              <MenuItem
                icon={<span>📚</span>}
                active={isActive('/admin/chatbot-corpora')}
                onClick={() => handleMenuClick('/admin/chatbot-corpora')}
              >
                Corpora Access
              </MenuItem>
              <MenuItem
                icon={<span>🤖</span>}
                active={isActive('/admin/chatbot-agents')}
                onClick={() => handleMenuClick('/admin/chatbot-agents')}
              >
                Agent Access
              </MenuItem>
            </SubMenu>

            {/* Corpora with SubMenu */}
            <SubMenu
              icon={<span className="text-xl">📚</span>}
              label="Corpora"
              open={corporaMenuOpen}
              onOpenChange={(open) => setCorporaMenuOpen(open)}
              rootStyles={{
                '& > .ps-menu-button': {
                  backgroundColor: 'transparent',
                  color: '#374151',
                  fontWeight: corporaMenuOpen ? '700' : '400',
                },
              }}
            >
              <MenuItem
                icon={<span>💎</span>}
                active={pathname === '/admin/corpora'}
                onClick={() => handleMenuClick('/admin/corpora')}
              >
                Corpus Management
              </MenuItem>
              <MenuItem
                icon={<span>📋</span>}
                active={isActive('/admin/corpora/audit')}
                onClick={() => handleMenuClick('/admin/corpora/audit')}
              >
                Audit Log
              </MenuItem>
              <MenuItem
                icon={<span>🔐</span>}
                active={isActive('/admin/corpora/access')}
                onClick={() => handleMenuClick('/admin/corpora/access')}
              >
                Group Access Matrix
              </MenuItem>
            </SubMenu>

            {/* Application Management SubMenu */}
            <SubMenu
              icon={<span className="text-xl">⚙️</span>}
              label="Application Management"
              open={appManagementMenuOpen}
              onOpenChange={(open) => setAppManagementMenuOpen(open)}
              rootStyles={{
                '& > .ps-menu-button': {
                  backgroundColor: 'transparent',
                  color: '#374151',
                  fontWeight: appManagementMenuOpen ? '700' : '400',
                },
              }}
            >
              <MenuItem
                icon={<span>📊</span>}
                active={pathname === '/admin'}
                onClick={() => handleMenuClick('/admin')}
              >
                Dashboard
              </MenuItem>
              <MenuItem
                icon={<span>👤</span>}
                active={isActive('/admin/users')}
                onClick={() => handleMenuClick('/admin/users')}
              >
                Users
              </MenuItem>
              <MenuItem
                icon={<span>🔐</span>}
                active={isActive('/admin/groups')}
                onClick={() => handleMenuClick('/admin/groups')}
              >
                Groups
              </MenuItem>
              <MenuItem
                icon={<span>📋</span>}
                active={isActive('/admin/audit')}
                onClick={() => handleMenuClick('/admin/audit')}
              >
                System Audit Logs
              </MenuItem>
              <MenuItem
                icon={<span>🔌</span>}
                active={isActive('/admin/sessions')}
                onClick={() => handleMenuClick('/admin/sessions')}
              >
                Sessions
              </MenuItem>
            </SubMenu>
          </Menu>

          {/* Navigation Links */}
          <div className="border-t border-gray-200 mt-4 pt-4 px-4">
            <button
              onClick={() => handleMenuClick('/open-document')}
              className="w-full flex items-center gap-3 px-4 py-3 text-left text-gray-700 hover:bg-gray-50 rounded-lg transition-colors mb-2"
            >
              <span className="text-2xl">📄</span>
              <span className="text-base font-normal">Open Document</span>
            </button>
            <button
              onClick={() => handleMenuClick('/')}
              className="w-full flex items-center gap-3 px-4 py-3 text-left text-gray-700 hover:bg-gray-50 rounded-lg transition-colors"
            >
              <span className="text-2xl">←</span>
              <span className="text-base font-normal">Back to App</span>
            </button>
          </div>

          {/* Toggle Button */}
          <div className="absolute bottom-4 right-4">
            <button
              onClick={() => setCollapsed(!collapsed)}
              className="p-2 rounded-lg bg-gray-100 hover:bg-gray-200 transition-colors"
              title={collapsed ? 'Expand Sidebar' : 'Collapse Sidebar'}
            >
              <span className="text-lg">{collapsed ? '→' : '←'}</span>
            </button>
          </div>
        </Sidebar>

        {/* Main Content */}
        <div className="flex-1 overflow-auto">
          {children}
        </div>
      </div>
    </div>
  );
}
