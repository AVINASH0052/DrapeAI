import { Routes, Route, NavLink, Navigate, useLocation } from 'react-router-dom';
import Dashboard from './pages/Dashboard';
import Users from './pages/Users';
import UserDetail from './pages/UserDetail';
import Items from './pages/Items';
import Flagged from './pages/Flagged';
import Analytics from './pages/Analytics';
import Notifications from './pages/Notifications';
import Waitlist from './pages/Waitlist';
import SystemHealth from './pages/SystemHealth';
import Login from './pages/Login';
import { adminPath } from './services/api';

function ProtectedRoute({ children }) {
  const token = localStorage.getItem('admin_token');
  if (!token) return <Navigate to="/login" replace />;
  return children;
}

function NavSection({ label, children }) {
  return (
    <div className="nav-section">
      <div className="nav-section-label">{label}</div>
      {children}
    </div>
  );
}

function Sidebar() {
  const location = useLocation();
  const handleLogout = () => {
    localStorage.removeItem('admin_token');
    window.location.href = adminPath('/login');
  };

  const linkClass = ({ isActive }) => (isActive ? 'active' : '');

  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <img src={`${import.meta.env.BASE_URL}brand/sugatai-wordmark.svg`} alt="Sugatai" />
        <span>Admin Console</span>
      </div>

      <nav className="sidebar-nav">
        <NavSection label="Overview">
          <NavLink to="/" end className={linkClass}>
            <span className="nav-icon" aria-hidden="true">◆</span>
            <span>Dashboard</span>
          </NavLink>
        </NavSection>

        <NavSection label="Users">
          <NavLink to="/users" className={({ isActive }) => (isActive || location.pathname.startsWith('/users/') ? 'active' : '')}>
            <span className="nav-icon" aria-hidden="true">◎</span>
            <span>All users</span>
          </NavLink>
          <NavLink to="/waitlist" className={linkClass}>
            <span className="nav-icon" aria-hidden="true">◉</span>
            <span>Waitlist</span>
          </NavLink>
        </NavSection>

        <NavSection label="Content">
          <NavLink to="/items" className={linkClass}>
            <span className="nav-icon" aria-hidden="true">▢</span>
            <span>Items</span>
          </NavLink>
          <NavLink to="/flagged" className={linkClass}>
            <span className="nav-icon" aria-hidden="true">▣</span>
            <span>Flagged</span>
          </NavLink>
        </NavSection>

        <NavSection label="Insights">
          <NavLink to="/analytics" className={linkClass}>
            <span className="nav-icon" aria-hidden="true">▴</span>
            <span>Analytics</span>
          </NavLink>
        </NavSection>

        <NavSection label="Operations">
          <NavLink to="/notifications" className={linkClass}>
            <span className="nav-icon" aria-hidden="true">◈</span>
            <span>Notifications</span>
          </NavLink>
          <NavLink to="/system" className={linkClass}>
            <span className="nav-icon" aria-hidden="true">☰</span>
            <span>System Health</span>
          </NavLink>
        </NavSection>
      </nav>

      <div className="sidebar-footer">
        <button type="button" onClick={handleLogout}>Sign Out</button>
      </div>
    </aside>
  );
}

function AppLayout() {
  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/users" element={<Users />} />
          <Route path="/users/:userId" element={<UserDetail />} />
          <Route path="/waitlist" element={<Waitlist />} />
          <Route path="/items" element={<Items />} />
          <Route path="/flagged" element={<Flagged />} />
          <Route path="/analytics" element={<Analytics />} />
          <Route path="/notifications" element={<Notifications />} />
          <Route path="/system" element={<SystemHealth />} />
        </Routes>
      </main>
    </div>
  );
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/*"
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      />
    </Routes>
  );
}
